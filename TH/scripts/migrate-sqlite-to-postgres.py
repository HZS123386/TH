"""Import and compare a verified SQLite business backup with the PostgreSQL schema."""

import argparse
from collections import Counter
from contextlib import closing
import json
import os
from pathlib import Path
import sqlite3

from dotenv import load_dotenv
import psycopg
from psycopg import sql


SEQUENCE_TABLE = "life_simulated_payment_sequence"
TARGET_REVISION = "20261116_postgres"
IDENTITIES = {"messages": "seq", "report_model_usage": "id", "h5_request_failures": "id"}


def source_tables(db):
    # The original creation order places referenced tables before their dependents.
    return [name for name, in db.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY rowid"
    )]


def sqlite_name(name):
    return '"' + name.replace('"', '""') + '"'


def columns_and_rows(source, target, table):
    cursor = source.execute("SELECT * FROM " + sqlite_name(table))
    columns = [field[0] for field in cursor.description]
    actual_columns = target.execute(
        "SELECT column_name FROM information_schema.columns WHERE table_schema=current_schema() AND table_name=%s",
        (table,),
    )
    if set(columns) != {name for name, in actual_columns}:
        raise ValueError(f"Column mismatch: {table}")
    return columns, cursor.fetchall()


def copy_and_compare(source, target, verify_only):
    revision = target.execute("SELECT version_num FROM alembic_version").fetchone()
    if revision != (TARGET_REVISION,):
        raise ValueError("Apply the baseline FATE PostgreSQL migration before importing")
    tables = source_tables(source)
    target_tables = {name for name, in target.execute(
        "SELECT table_name FROM information_schema.tables "
        "WHERE table_schema=current_schema() AND table_type='BASE TABLE' AND table_name<>'alembic_version'"
    )}
    if set(tables) != target_tables or SEQUENCE_TABLE not in target_tables:
        raise ValueError("Source and target business tables differ")

    if not verify_only:
        target.execute(sql.SQL("LOCK TABLE {} IN ACCESS EXCLUSIVE MODE").format(
            sql.SQL(", ").join(map(sql.Identifier, sorted(tables)))))
        for table in tables:
            existing = target.execute(sql.SQL("SELECT * FROM {} LIMIT 2").format(sql.Identifier(table))).fetchall()
            if existing != ([(0,)] if table == SEQUENCE_TABLE else []):
                raise ValueError(f"Import requires an empty migrated target: {table}")
        target.execute("DELETE FROM life_simulated_payment_sequence")

    results = {}
    for table in tables:
        columns, rows = columns_and_rows(source, target, table)
        if table == SEQUENCE_TABLE and (len(rows) != 1 or rows[0][0] < 0):
            raise ValueError("Invalid source order counter")
        names = sql.SQL(", ").join(map(sql.Identifier, columns))
        relation = sql.Identifier(table)
        if rows and not verify_only:
            with target.cursor() as cursor:
                cursor.executemany(sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
                    relation, names, sql.SQL(", ").join(sql.Placeholder() for _ in columns)
                ), rows)
        copied = target.execute(sql.SQL("SELECT {} FROM {}").format(names, relation)).fetchall()
        if Counter(rows) != Counter(copied):
            raise ValueError(f"Row content differs: {table}")
        results[table] = len(rows)

    if not verify_only:
        old_sequences = dict(source.execute("SELECT name,seq FROM sqlite_sequence")) if source.execute(
            "SELECT 1 FROM sqlite_master WHERE name='sqlite_sequence'"
        ).fetchone() else {}
        for table, key in IDENTITIES.items():
            highest, = target.execute(sql.SQL("SELECT COALESCE(MAX({}),0) FROM {}").format(
                sql.Identifier(key), sql.Identifier(table))).fetchone()
            next_value = max(highest, old_sequences.get(table, 0)) + 1
            target.execute(sql.SQL("ALTER TABLE {} ALTER COLUMN {} RESTART WITH {}").format(
                sql.Identifier(table), sql.Identifier(key), sql.Literal(next_value)))
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Path of the consistent SQLite backup")
    parser.add_argument("--verify-only", action="store_true", help="Compare source and target without writing either")
    options = parser.parse_args()
    load_dotenv(Path(__file__).resolve().parents[1] / ".env")
    url = os.environ.get("DATABASE_URL", "")
    if not url.startswith(("postgresql://", "postgres://")):
        parser.error("DATABASE_URL must point to the migrated PostgreSQL target")
    if not options.source.is_file():
        parser.error("Source SQLite backup does not exist")

    try:
        with closing(sqlite3.connect(options.source.resolve().as_uri() + "?mode=ro", uri=True, timeout=3)) as source:
            source.execute("PRAGMA query_only=ON")
            source.execute("BEGIN")
            if source.execute("PRAGMA integrity_check").fetchall() != [("ok",)] or source.execute("PRAGMA foreign_key_check").fetchone():
                raise ValueError("Source SQLite integrity or foreign-key check failed")
            with psycopg.connect(url, connect_timeout=5) as target:
                if options.verify_only:
                    target.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY")
                target.execute("SET LOCAL lock_timeout = '5s'")
                sizes = copy_and_compare(source, target, options.verify_only)
                settlement = target.execute(
                    "SELECT COUNT(*) FILTER (WHERE provider_order IS NOT NULL), "
                    "COUNT(*) FILTER (WHERE sunlands_order::jsonb ->> 'paymentStatus'='PAID'), "
                    "COUNT(*) FILTER (WHERE sunlands_order::jsonb ->> 'paidAt' IS NOT NULL) FROM life_card_payments"
                ).fetchone()
                unlocked, = target.execute("SELECT COUNT(*) FROM life_reports WHERE unlocked=1").fetchone()
    except ValueError as error:
        raise SystemExit(str(error)) from None
    except (sqlite3.Error, psycopg.Error) as error:
        raise SystemExit(f"Database operation failed: {type(error).__name__}") from None
    print(json.dumps({
        "verified_tables": len(sizes), "verified_rows": sum(sizes.values()),
        "payment_rows": sizes["life_card_payments"], "recorded_receipts": settlement[0],
        "sunlands_paid": settlement[1], "sunlands_with_paid_time": settlement[2],
        "life_reports": sizes["life_reports"], "unlocked_life_reports": unlocked, "tables": sizes,
    }, indent=2))


if __name__ == "__main__":
    main()

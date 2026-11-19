"""A clean PostgreSQL schema for tests and synthetic evaluations."""

from contextlib import contextmanager
import os
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit
from uuid import uuid4

from alembic import command
from alembic.config import Config
from dotenv import dotenv_values
import psycopg
from psycopg import sql


ROOT = Path(__file__).resolve().parents[2]


@contextmanager
def isolated_database():
    url = os.environ.get("FATE_TEST_DATABASE_URL") or dotenv_values(ROOT / "data/.postgres-test.env").get("FATE_TEST_DATABASE_URL")
    if not url or not url.startswith(("postgresql://", "postgres://")):
        raise RuntimeError("Set FATE_TEST_DATABASE_URL to a dedicated PostgreSQL test database.")
    schema = "test_" + uuid4().hex
    parts = urlsplit(url)
    params = dict(parse_qsl(parts.query))
    params["options"] = (params.get("options", "") + f" -csearch_path={schema}").strip()
    test_url = parts._replace(query=urlencode(params)).geturl()
    with psycopg.connect(url, autocommit=True, connect_timeout=5) as db:
        name, = db.execute("SELECT current_database()").fetchone()
        if name != "fate_test" and not name.startswith("fate_test_"):
            raise RuntimeError("Test schemas require a dedicated fate_test PostgreSQL database.")
        db.execute(sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(schema)))
        try:
            config = Config(str(ROOT / "backend/alembic.ini"))
            config.attributes["database_url"] = test_url
            command.upgrade(config, "head")
            yield test_url
        finally:
            db.execute(sql.SQL("DROP SCHEMA {} CASCADE").format(sql.Identifier(schema)))

"""Read the existing H5 funnel without exposing device keys or report content."""
import argparse
import json
import sqlite3
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", type=Path)
    parser.add_argument("--days", type=int, default=30, choices=range(1, 31), metavar="1..30")
    args = parser.parse_args()
    uri = args.database.resolve().as_uri() + "?mode=ro"
    with sqlite3.connect(uri, uri=True) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute("""
            SELECT source, campaign, COUNT(*) visits,
                   SUM(submitted_at IS NOT NULL) submitted,
                   SUM(seen_at IS NOT NULL) seen
            FROM landing_visits WHERE visited_at>=?
            GROUP BY source, campaign ORDER BY visits DESC
        """, (time.time() - args.days * 86400,)).fetchall()
    print(json.dumps({"days": args.days, "channels": [dict(row) for row in rows]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

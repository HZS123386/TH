"""Read the existing H5 funnel without exposing device keys or report content."""
import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.app.config import Settings
from backend.app.storage import Storage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=30, choices=range(1, 31), metavar="1..30")
    args = parser.parse_args()
    store = Storage(Settings.from_env().database_url)
    with store.connect() as db:
        db.execute("SET TRANSACTION READ ONLY")
        rows = db.execute("""
            SELECT source, campaign, COUNT(*) visits,
                   COUNT(DISTINCT owner) visitors,
                   COUNT(submitted_at) submitted,
                   COUNT(seen_at) seen
            FROM landing_visits WHERE visited_at>=%s
            GROUP BY source, campaign ORDER BY visitors DESC, visits DESC, source, campaign
        """, (time.time() - args.days * 86400,)).fetchall()
    print(json.dumps({"days": args.days, "channels": [dict(row) for row in rows]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

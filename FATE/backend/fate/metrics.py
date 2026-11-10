import argparse
import json
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select

from .db import Session, Visit


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Count H5 sessions by UTM source and campaign.")
    parser.add_argument("--days", type=int, choices=range(1, 31), default=7, metavar="1-30")
    args = parser.parse_args()
    since = datetime.now(UTC) - timedelta(days=args.days)
    with Session() as db:
        rows = db.execute(select(
            Visit.source, Visit.campaign, func.count(Visit.id).label("visits"),
            func.count(Visit.submitted_at).label("submitted"), func.count(Visit.seen_at).label("seen"),
        ).where(Visit.visited_at >= since).group_by(Visit.source, Visit.campaign)
            .order_by(func.count(Visit.id).desc()))
        print(json.dumps([dict(row._mapping) for row in rows], indent=2))

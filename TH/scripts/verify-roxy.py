"""Synthetic BaZi checks. Real API calls require an explicit --live flag."""
import argparse
import asyncio
from dataclasses import replace
from datetime import datetime
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from backend.app.bazi_testing import generate_bazi_test
from backend.app.config import Settings
from backend.app.roxy import RoxyBazi
from backend.app.schemas import BaziTestInput
from backend.app.storage import Storage


CASES = {
    "standard": {"birth_date": "1995-08-17", "birth_time": "10:30", "timezone": "Asia/Shanghai"},
    "late-zi": {"birth_date": "1990-06-15", "birth_time": "23:30", "timezone": "Asia/Shanghai"},
    "timezone": {"birth_date": "1995-08-17", "birth_time": "09:30", "timezone": "Asia/Bangkok"},
}


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", help="Call Roxy with synthetic births; uses API credits.")
    parser.add_argument("--case", action="append", choices=CASES, dest="cases")
    parser.add_argument("--all-topics", action="store_true", help="Also call strength, luck and annual operations for each case.")
    args = parser.parse_args()
    settings = Settings.from_env()
    if args.live and not (settings.roxy_enabled and settings.roxy_api_key):
        parser.error("Configure ROXY_ENABLED and ROXY_API_KEY on the server first.")
    folder = ROOT / "data/roxy-evals"
    folder.mkdir(parents=True, exist_ok=True)
    store = Storage(str(folder / "usage.db"))
    roxy = RoxyBazi(replace(settings, database_path=store.path), store)
    reports = []
    for name in args.cases or list(CASES):
        body = BaziTestInput(profile={**CASES[name], "display_name": "Synthetic evaluation", "language": "zh"},
                             source="compare" if args.live else "github", clock="beijing" if name == "timezone" else "local",
                             topics=["chart", "strength", "luck", "annual"] if args.all_topics and args.live else ["chart"], gender="female", year=2026)
        value = await generate_bazi_test(body, roxy, "synthetic-evaluation", "synthetic-evaluation-network")
        reports.append({"case": name, **value})
        source = value["sources"].get("roxy", {})
        print(json.dumps({"case": name, "mode": "live" if args.live else "local-only", "comparison": value["comparison"]["status"],
                          "github_pillars": value["sources"]["github"]["chart"]["pillars"], "roxy_errors": source.get("errors", {}),
                          "operations": list(source.get("details", {}))}, ensure_ascii=False))
    output = folder / ("bazi-" + ("live-" if args.live else "local-") + datetime.now().strftime("%Y%m%d-%H%M%S") + ".json")
    output.write_text(json.dumps({"live": args.live, "reports": reports, "prediction_accuracy": "not-established"}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(str(output))
    if args.live and any(row["comparison"]["status"] != "match" or row["sources"]["roxy"]["errors"] for row in reports):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))

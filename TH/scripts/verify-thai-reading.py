"""Exercise real Thai calculations and configured writing through the local API."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import sys
import time

import httpx

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from backend.app.bazi_reports import language_matches  # noqa: E402
from backend.app.thai_readings import VERSION, calculation_in_prose, plain_language_problem, title_language_matches  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--quick", action="store_true")
    args = parser.parse_args()
    profile = {"display_name": "", "birth_date": "1995-08-17", "birth_time": "09:30", "timezone": "Asia/Bangkok", "birthplace": "Bangkok", "language": "zh"}
    cases = [("work", "zh", None)] if args.quick else [(topic, "zh", None) for topic in ("overview", "annual", "money", "love", "work", "family")] + [("work", language, None) for language in ("en", "th", "vi")] + [("work", "zh", "15:30")]
    records = []
    with httpx.Client(timeout=120) as client:
        for index, (reading, language, clock) in enumerate(cases):
            body = {"profile": {**profile, "language": language, "birth_time": clock or profile["birth_time"]}, "reading": reading, "year": 2026}
            start = time.monotonic()
            response = client.post(args.base_url.rstrip("/") + "/api/thai-reading", json=body, headers={"Accept-Language": language})
            result = response.json()
            ok = response.status_code == 200 and result.get("natal", {}).get("status") == "ready" and result.get("report", {}).get("generation", {}).get("state") == "ready"
            if ok:
                report = result["report"]
                points = [item for section in report["sections"] for item in section["items"]]
                advice = next(section["items"] for section in report["sections"] if section["id"] == "advice")
                watches = next(section["items"] for section in report["sections"] if section["id"] == "opportunities")
                texts = [report["summary"], *(item["title"] + " " + item["text"] for item in points), *(text for item in advice for text in [*item.get("steps", []), item.get("example", ""), item.get("pitfall", ""), item.get("check", "")]), *(text for item in watches for text in [*item.get("signals", []), item.get("response", ""), item.get("example", "")])]
                ok = report["generation"]["version"] == VERSION and len(points) == 9 and all(language_matches(text, language) and not calculation_in_prose(text) for text in texts)
                ok = ok and not plain_language_problem(report["summary"], language, summary=True) and all(not plain_language_problem(item["text"], language, detailed=index >= 2) for index, item in enumerate(points))
                ok = ok and all(title_language_matches(item["title"], language) and language_matches(item["text"], language) for item in points)
                ok = ok and len(advice) == 4 and all(len(item.get("steps", [])) == 4 and all(len(item.get(key, "")) >= 12 for key in ("example", "pitfall", "check")) for item in advice)
                ok = ok and len(watches) == 3 and all(len(item.get("signals", [])) == 2 and all(len(item.get(key, "")) >= 12 for key in ("response", "example")) for item in watches)
                if reading == "annual":
                    ok = ok and all(item["period"] and item["period"]["year"] == body["year"] for item in points) and {(item["period"]["month"] - 1) // 4 for item in points} == {0, 1, 2}
            records.append({"input": body, "http_status": response.status_code, "passed": ok, "seconds": round(time.monotonic() - start, 2), "result": result})
            print(json.dumps({"case": index + 1, "reading": reading, "language": language, "passed": ok, "generation": result.get("report", {}).get("generation")}), flush=True)
            if len(cases) > 6 and index == 5 and sum(record["result"].get("report", {}).get("generation", {}).get("attempts", 0) > 0 for record in records) >= 6:
                # Keep acceptance traffic within the configured writing-minute budget.
                remaining = 61 - sum(record["seconds"] for record in records)
                if remaining > 0:
                    time.sleep(min(remaining, 59))
    destination = ROOT / "data/thai-evals" / ("thai-reading-" + datetime.now().strftime("%Y%m%d-%H%M%S") + ".json")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"output": str(destination), "passed": sum(record["passed"] for record in records), "total": len(records)}), flush=True)
    return 0 if all(record["passed"] for record in records) else 1


if __name__ == "__main__":
    raise SystemExit(main())

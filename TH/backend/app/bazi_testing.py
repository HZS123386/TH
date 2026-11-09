"""Bazi reading reports and independent comparisons; never changes saved profiles."""
import asyncio
from datetime import datetime
from functools import lru_cache
import hashlib
import json
from pathlib import Path
from zoneinfo import ZoneInfo

from .bazi import calculate
from .roxy import POSITIONS, RoxyBazi, RoxyError, calculation_instant, chart_for_app, request_body
from .schemas import BaziTestInput
from .bazi_reports import VERSION, grounding, reading_for
from .bazi_localization import fact_summary


@lru_cache(maxsize=4)
def copy_for(language):
    return json.loads((Path(__file__).resolve().parents[2] / "src/content/bazi-test.json").read_text(encoding="utf-8"))[language]


async def generate_bazi_test(body: BaziTestInput, roxy: RoxyBazi, owner: str, network: str, *, reports=None):
    profile = body.profile
    instant = calculation_instant(profile, body.clock)
    copy = copy_for(profile.language)
    sources = {}
    details, failures = {}, {}
    local = await asyncio.to_thread(calculate, body.profile, body.clock)
    if body.source != "roxy":
        sources["github"] = {"status": "ready" if profile.birth_time else "partial", "chart": local}
    if body.source != "github":
        if not profile.birth_time:
            failures["chart"] = "bazi_time_required"
        else:
            birth = request_body(profile, instant)
            operations = list(dict.fromkeys(["chart", *body.topics]))

            async def run(operation):
                params = {**birth}
                if operation == "luck":
                    params.update(gender=body.gender, count=8)
                if operation == "annual":
                    params["year"] = body.year
                try:
                    details[operation] = await roxy.request(operation, params, profile.language, owner, network)
                except RoxyError as error:
                    failures[operation] = error.code

            await asyncio.gather(*(run(operation) for operation in operations))
        chart = details.get("chart", {}).get("data")
        sources["roxy"] = {"status": "ready" if details and not failures else "partial" if details else "unavailable",
                           "chart": chart_for_app(profile, chart, instant=instant) if chart else None,
                           "details": details, "errors": failures}
    rows = []
    for pillar in POSITIONS:
        left = local["pillars"].get(pillar)
        right = (sources.get("roxy", {}).get("chart") or {}).get("pillars", {}).get(pillar)
        rows.append({"pillar": pillar, "github": left, "roxy": right, "match": left == right if left and right else None})
    status = "partial" if any(row["match"] is None for row in rows) else "match" if all(row["match"] for row in rows) else "different"
    sections, translations = [], {}
    generation = {"state": "unconfigured"}
    if not profile.birth_time:
        generation = {"state": "time_required"}
    elif body.source != "github" and (failures or not details.get("chart")):
        generation = {"state": "calculation_unavailable"}
    elif body.source == "github":
        generation = {"state": "unconfigured"}
    elif body.source != "github" and status == "different":
        generation = {"state": "conflict"}
    elif reports is not None:
        bundle = grounding(body, sources, local)
        generation = await reports.generate(bundle, owner, network)
        story = generation.pop("story", None)
        if story:
            translations = story["translations"]
            for kind in ("interpretation", "opportunities", "advice"):
                sections.append({"id": kind, "title": copy["reportSections"][kind], "source": "calculated-reading",
                                 "paragraphs": [fact_summary(bundle, row["evidence_ids"], profile.language, translations, copy) + row["text"] for row in story[kind]], "language": profile.language,
                                 "evidence_ids": [row["evidence_ids"] for row in story[kind]]})
    public_input = body.model_dump(mode="json")
    return {
        "report_id": hashlib.sha256(json.dumps([public_input, owner], sort_keys=True).encode()).hexdigest()[:16],
        "generated_at": datetime.now(ZoneInfo("Asia/Shanghai")).isoformat(), "input": public_input,
        "calculation_input": {"birth_date": instant.date().isoformat() if instant else profile.birth_date.isoformat(),
                              "birth_time": instant.strftime("%H:%M:%S") if instant else None,
                              "timezone": str(instant.tzinfo) if instant else profile.timezone,
                              "utc_datetime": instant.astimezone(ZoneInfo("UTC")).isoformat() if instant else None,
                              "utc_offset_seconds": str(int(instant.utcoffset().total_seconds())) if instant else None,
                              "selected_clock": body.clock, "solar_terms_reference": "UTC+08:00 instants",
                              "unknown_time_scope": "original birth civil day; converted interval retained" if not profile.birth_time else None,
                              "day_boundary": "split-zi", "year_boundary": "li-chun", "hour_clock": "clock"},
        "sources": sources, "comparison": {"status": status, "rows": rows, "scope": "four-pillars-only"},
        "report": {"title": copy["category"] + " · " + copy["readings"][reading_for(body)]["title"],
                   "language": profile.language, "sections": sections, "translations": translations,
                   "generation": {**generation, "version": VERSION}},
    }

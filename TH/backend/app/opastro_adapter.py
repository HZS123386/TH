"""OpAstro's MIT event selection fed only by native Suriyayatra facts.

Ranking is editorial relevance, not a prediction score or a Thai master rulebook.
No Swiss Ephemeris imports, Western exact aspects, assumed birth times or nodes.
"""
from collections import defaultdict
from datetime import datetime
from hashlib import sha256
import json

from ..vendor.opastro.aggregation import _dedupe_period_events, _event_priority, _section_bias
from ..vendor.opastro.models import Period, PeriodEvent

VERSION = "wanjai-opastro-thai-1"
UPSTREAM = "49276a01831060283f7a991218287e4bc72538e0"
BODIES = {"sun": "Sun", "moon": "Moon", "mars": "Mars", "mercury": "Mercury", "jupiter": "Jupiter", "venus": "Venus", "saturn": "Saturn", "uranus": "Uranus"}
PERIODS = {"today": Period.DAILY, "week": Period.WEEKLY, "month": Period.MONTHLY}
# Local relevance adjustments: distinguish short-lived mood from slower trends.
PACE = {
    "today": {"moon": 1.8, "mercury": 1.3, "venus": 1.2},
    "week": {"moon": 0.7, "sun": 1.2, "mercury": 1.4, "venus": 1.3, "mars": 1.3},
    "month": {"moon": 0.25, "sun": 1.3, "mars": 1.35, "jupiter": 1.55, "saturn": 1.55},
}
TOPIC_PLANETS = {"love": "venus", "money": "jupiter", "family": "moon", "work": "mercury"}


def digest(value):
    return sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def analyze(value: dict, samples: list[dict]):
    period = value["period"]
    references = value["birth"]["reference_signs"]
    factors, events = {}, []

    def add(kind, bodies, start, end, details, multiplier=1.0):
        body1, body2 = (BODIES.get(body, body) for body in (bodies + [None, None])[:2])
        priority = _event_priority("ingress" if kind == "sign_change" else kind, body1, body2, None)
        pace = max(PACE[period].get(body, 1) for body in bodies)
        if kind == "sign_relationship" and "moon" in bodies and period != "today":
            pace *= 0.45 if period == "month" else 0.7
        bias = _section_bias(kind, body1, body2)
        topic_bias = {
            "love": max(bias.get("love_singles", 0), bias.get("love_couples", 0)),
            "money": bias.get("money", 0),
            "work": bias.get("career", 0) + bias.get("communication", 0) / 2,
            # Family is a WANJAI extension, not an upstream OpAstro section.
            "family": sum({"moon": 1, "venus": 0.3, "saturn": 0.3}.get(body, 0) for body in bodies),
        }
        fact = {"kind": kind, "bodies": bodies, "start": start, "end": end, **details}
        fact_id = "f_" + digest(fact)[:14]
        rank = round(priority * pace * multiplier, 3)
        factors[fact_id] = {"id": fact_id, **fact, "relevance": rank, "topic_relevance": topic_bias}
        events.append(PeriodEvent(
            timestamp=datetime.fromisoformat(start + "+07:00"), event_type=kind,
            body1=body1, body2=body2, sign=str(details.get("sign", "")),
            aspect=details.get("relationship"), narrative_priority=rank,
            section_bias=bias, description=fact_id,
        ))

    # Contiguous sign occupancy, with all alternative natal references retained.
    for body in samples[0]["points"]:
        groups = []
        for sample in samples:
            point = sample["points"][body]
            stamp = sample["date"] + "T" + sample["time"]
            if not groups or groups[-1]["sign"] != point["sign"]:
                groups.append({"sign": point["sign"], "start": stamp, "end": stamp, "count": 0})
            groups[-1]["end"] = stamp
            groups[-1]["count"] += 1
        for index, group in enumerate(groups):
            positions = [{"reference_sign": ref, "position": (group["sign"] - ref + 12) % 12 + 1} for ref in references]
            add("placement", [body], group["start"], group["end"], {
                "sign": group["sign"], "positions": positions,
                "sample_count": group["count"], "total_samples": len(samples),
            }, 0.8 + group["count"] / len(samples) * 0.5)
            if index:
                # Sampling brackets the change; it does not find an exact ingress.
                add("sign_change", [body], groups[index - 1]["end"], group["start"], {
                    "sign": group["sign"], "from_sign": groups[index - 1]["sign"],
                    "positions": positions, "timing": "between-samples",
                }, 1.35)

    # Count native sign relationships; never label them degree-exact aspects.
    relationships = defaultdict(list)
    for sample in samples:
        for row in sample["relationships"]:
            relationships[(row["from"], row["to"], row["kind"])].append(sample)
    for (body1, body2, kind), observed in relationships.items():
        first, last = observed[0], observed[-1]
        add("sign_relationship", [body1, body2], first["date"] + "T" + first["time"], last["date"] + "T" + last["time"], {
            "relationship": kind, "sample_count": len(observed), "total_samples": len(samples),
            "observed_dates": sorted({item["date"] for item in observed}),
        }, 0.7 + len(observed) / len(samples) * 0.4)

    selected = [factors[event.description] for event in _dedupe_period_events(PERIODS[period], events)]
    selected.sort(key=lambda item: (-item["relevance"], item["id"]))
    # Always cover each topic planet; otherwise a slow Moon could disappear in a month.
    must = []
    for body in TOPIC_PLANETS.values():
        placement = next(item for item in selected if item["kind"] == "placement" and item["bodies"] == [body])
        must.append(placement)
    changes = [item for item in selected if item["kind"] == "sign_change"]
    chosen = {item["id"]: item for item in [*must, *changes[:6], *selected[:12]]}
    chosen = sorted(chosen.values(), key=lambda item: (-item["relevance"], item["id"]))[:22]
    topic_factors = {}
    for topic, body in TOPIC_PLANETS.items():
        ranked = sorted(chosen, key=lambda item: (body not in item["bodies"], -item["topic_relevance"][topic] * item["relevance"]))
        topic_factors[topic] = [item["id"] for item in ranked[:3]]
    timeline = []
    indices = sorted({0, (len(samples) - 1) // 2, len(samples) - 1})
    for index in indices:
        sample = samples[index]
        timeline.append({
            "date": sample["date"], "time": sample["time"], "lunar": sample["lunar"],
            "positions": {body: {"sign": sample["points"][body]["sign"], "relative_positions": [(sample["points"][body]["sign"] - ref + 12) % 12 + 1 for ref in references]} for body in TOPIC_PLANETS.values()},
        })
    return {
        "adapter_version": VERSION, "upstream": "opastro@0.1.9", "upstream_commit": UPSTREAM,
        "calculation": "native-thai-suriyayatra", "ranking": "editorial-relevance-not-probability",
        "sampling": {"count": len(samples), "method": "six-hourly-with-day-end" if period == "today" else "daily-noon"},
        "factors": chosen, "topic_factors": topic_factors, "timeline": timeline,
        "signature": digest({"version": VERSION, "period": period, "birth": {key: value["birth"][key] for key in ("date", "basis", "reference_signs", "time_known", "zone_known")}, "samples": samples}),
        "limits": ["native-sign-relationships-not-exact-aspects", "sample-bracket-not-exact-ingress", "editorial-symbolism-not-validated-prediction"],
    }

"""Pure aggregation functions extracted from dakidarts/opastro (MIT).
Copyright (c) 2026 Dakidarts. See LICENSE and UPSTREAM.json.
Functions/constants below are unchanged; only imports use minimal local models.
Swiss Ephemeris, Western positions, premium content and defaults are not loaded.
"""
from datetime import datetime
from typing import Dict, List, Optional, Tuple

from .models import Period, PeriodEvent

BODY_IMPORTANCE = {
    "Sun": 1.20,
    "Moon": 1.05,
    "Mercury": 1.10,
    "Venus": 1.10,
    "Mars": 1.15,
    "Jupiter": 1.35,
    "Saturn": 1.35,
    "Uranus": 1.20,
    "Neptune": 1.20,
    "Pluto": 1.20,
    "Chiron": 1.15,
    "North Node": 1.25,
    "South Node": 1.15,
}


SECTION_BIAS_BY_BODY = {
    "Sun": {"general": 0.9, "career": 0.5, "lifestyle": 0.5},
    "Moon": {
        "general": 0.8,
        "love_singles": 0.4,
        "love_couples": 0.4,
        "friendship": 0.3,
        "health": 0.3,
    },
    "Mercury": {"communication": 0.9, "career": 0.4, "friendship": 0.3},
    "Venus": {
        "love_singles": 0.9,
        "love_couples": 1.0,
        "money": 0.5,
        "friendship": 0.4,
    },
    "Mars": {"career": 0.8, "health": 0.6, "love_singles": 0.3},
    "Jupiter": {"career": 0.8, "money": 0.8, "general": 0.5, "lifestyle": 0.4},
    "Saturn": {"career": 0.8, "health": 0.5, "money": 0.5, "general": 0.4},
    "Uranus": {"lifestyle": 0.7, "communication": 0.4, "general": 0.4},
    "Neptune": {"health": 0.5, "lifestyle": 0.6, "general": 0.4},
    "Pluto": {"general": 0.6, "career": 0.5, "love_couples": 0.4},
    "Chiron": {"health": 0.8, "love_couples": 0.4, "general": 0.4},
    "North Node": {"general": 0.8, "career": 0.4, "love_singles": 0.3},
    "South Node": {"general": 0.7, "lifestyle": 0.4, "friendship": 0.3},
}


def _section_bias(
    event_type: str, body1: Optional[str], body2: Optional[str]
) -> Dict[str, float]:
    bias: Dict[str, float] = {"general": 0.6}
    for body in (body1, body2):
        if not body:
            continue
        for section, weight in SECTION_BIAS_BY_BODY.get(body, {}).items():
            bias[section] = bias.get(section, 0.0) + weight

    if event_type in ("eclipse", "lunation"):
        bias["general"] = bias.get("general", 0.0) + 0.6
        bias["love_singles"] = bias.get("love_singles", 0.0) + 0.2
        bias["love_couples"] = bias.get("love_couples", 0.0) + 0.2
    return bias


def _event_priority(
    event_type: str,
    body1: Optional[str],
    body2: Optional[str],
    exactness: Optional[float],
) -> float:
    base = {
        "ingress": 1.15,
        "station": 1.35,
        "lunation": 1.55,
        "eclipse": 1.80,
        "exact_aspect": 1.10,
        "retrograde_emphasis": 0.90,
    }.get(event_type, 1.0)
    body_weight = max(
        BODY_IMPORTANCE.get(body1 or "", 1.0), BODY_IMPORTANCE.get(body2 or "", 1.0)
    )
    exact_bonus = 0.0
    if exactness is not None:
        exact_bonus = max(0.0, 1.0 - min(1.0, exactness / 8.0)) * 0.4
    return round(base * body_weight + exact_bonus, 3)


def _event_key(
    event: PeriodEvent,
) -> Tuple[str, Optional[str], Optional[str], Optional[str], Optional[str], str]:
    return (
        event.event_type,
        event.body1,
        event.body2,
        event.sign,
        event.aspect,
        event.timestamp.date().isoformat(),
    )


def _cluster_window_days(period: Period) -> int:
    if period == Period.DAILY:
        return 1
    if period == Period.WEEKLY:
        return 7
    if period == Period.MONTHLY:
        return 14
    return 45


def _event_signature(
    event: PeriodEvent,
) -> Tuple[str, Tuple[str, ...], Optional[str], Optional[str], Optional[str]]:
    bodies = tuple(sorted([body for body in (event.body1, event.body2) if body]))
    station_state = None
    if event.event_type == "station":
        lower = event.description.lower()
        if "retrograde" in lower:
            station_state = "retrograde"
        elif "direct" in lower:
            station_state = "direct"
    return (
        event.event_type,
        bodies,
        event.aspect,
        event.sign,
        station_state,
    )


def _event_rank(event: PeriodEvent) -> Tuple[int, float, float, datetime]:
    has_exactness = 0 if event.exactness is not None else 1
    exactness = event.exactness if event.exactness is not None else 999.0
    return (has_exactness, exactness, -event.narrative_priority, event.timestamp)


def _dedupe_period_events(
    period: Period, period_events: List[PeriodEvent]
) -> List[PeriodEvent]:
    # First pass: remove strict duplicates by event_type/body/sign/aspect/date.
    strict: List[PeriodEvent] = []
    seen_keys = set()
    for event in sorted(
        period_events, key=lambda e: (e.timestamp, -e.narrative_priority)
    ):
        key = _event_key(event)
        if key in seen_keys:
            continue
        seen_keys.add(key)
        strict.append(event)

    # Second pass: cluster repeated windows (exact aspects/lunations/eclipses and similar repeated signatures).
    window_days = _cluster_window_days(period)
    clustered: Dict[
        Tuple[str, Tuple[str, ...], Optional[str], Optional[str], Optional[str]],
        List[PeriodEvent],
    ] = {}

    for event in strict:
        signature = _event_signature(event)
        bucket = clustered.setdefault(signature, [])
        merged = False
        for idx, existing in enumerate(bucket):
            delta_days = (
                abs((event.timestamp - existing.timestamp).total_seconds()) / 86400.0
            )
            if delta_days <= window_days:
                if _event_rank(event) < _event_rank(existing):
                    bucket[idx] = event
                merged = True
                break
        if not merged:
            bucket.append(event)

    flattened: List[PeriodEvent] = []
    for events in clustered.values():
        flattened.extend(events)
    return sorted(flattened, key=lambda e: (e.timestamp, -e.narrative_priority))

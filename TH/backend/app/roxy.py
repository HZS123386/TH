"""Server-only Roxy BaZi adapter with explicit conventions and bounded paid calls."""
import asyncio
from collections import OrderedDict
from copy import deepcopy
from datetime import datetime, time
import hashlib
import json
import math
from time import monotonic
from zoneinfo import ZoneInfo

import httpx

from .bazi import ELEMENTS, localize, pillars_at
from .config import Settings
from .schemas import ProfileInput
from .storage import Storage

BASE_URL = "https://roxyapi.com/api/v2"
PATHS = {"chart": "chart", "strength": "day-master", "luck": "luck-pillars", "annual": "annual-forecast"}
CONVENTIONS = {"dayBoundary": "split-zi", "yearBoundary": "li-chun", "hourClock": "clock"}
POSITIONS = ("year", "month", "day", "hour")


def finite_number(value):
    try:
        return type(value) in (int, float) and math.isfinite(value)
    except OverflowError:
        return False


def validate_json(value, depth=0):
    if depth > 24 or isinstance(value, float) and not math.isfinite(value):
        raise RoxyError("roxy_invalid_response")
    if isinstance(value, dict):
        for item in value.values():
            validate_json(item, depth + 1)
    elif isinstance(value, list):
        for item in value:
            validate_json(item, depth + 1)


def validate_pillar(row):
    if not isinstance(row, dict):
        raise RoxyError("roxy_invalid_response")
    stem, branch = row.get("stem", {}).get("chinese"), row.get("branch", {}).get("chinese")
    god = row.get("tenGod", {})
    if (not isinstance(stem, str) or len(stem) != 1 or stem not in "甲乙丙丁戊己庚辛壬癸"
            or not isinstance(branch, str) or len(branch) != 1 or branch not in "子丑寅卯辰巳午未申酉戌亥"
            or not isinstance(god, dict) or any(not isinstance(god[k], str) for k in ("category", "keynote", "chinese", "name", "nameLocalized") if k in god)):
        raise RoxyError("roxy_invalid_response")


def validate_day_master(value, stem):
    master = value.get("dayMaster")
    if master is None:
        return
    english = dict(zip("木火土金水", ("Wood", "Fire", "Earth", "Metal", "Water")))
    if (not isinstance(master, dict) or master.get("chinese") != stem
            or "element" in master and master["element"] != english[ELEMENTS[stem]]
            or "elementLocalized" in master and master["elementLocalized"] not in (ELEMENTS[stem], english[ELEMENTS[stem]])):
        raise RoxyError("roxy_invalid_response")


class RoxyError(Exception):
    def __init__(self, code: str):
        self.code = code
        super().__init__(code)


def calculation_instant(profile: ProfileInput, clock: str):
    if not profile.birth_time:
        return None
    local = localize(datetime.combine(profile.birth_date, time.fromisoformat(profile.birth_time)), ZoneInfo(profile.timezone))
    if clock == "beijing":
        local = local.astimezone(ZoneInfo("Asia/Shanghai"))
    return local


def request_body(profile: ProfileInput, instant: datetime | None = None):
    if not profile.birth_time:
        raise RoxyError("bazi_time_required")
    # Reject ambiguous/nonexistent times locally rather than accepting upstream coercion.
    instant = instant or calculation_instant(profile, "local")
    # Python has already resolved the original IANA zone. A numeric offset keeps
    # converted DST folds and historical second-resolution offsets unambiguous.
    return {"date": instant.date().isoformat(), "time": instant.strftime("%H:%M:%S"),
            "timezone": instant.utcoffset().total_seconds() / 3600, **CONVENTIONS}


def validate_result(operation: str, value: dict, body: dict):
    validate_json(value)
    if not isinstance(value, dict) or not isinstance(value.get("summary"), str) or not value["summary"].strip():
        raise RoxyError("roxy_invalid_response")
    birth = value.get("birthData", {})
    expected_time = time.fromisoformat(body["time"])
    try:
        returned_time = time.fromisoformat(birth.get("time", ""))
    except (TypeError, ValueError):
        raise RoxyError("roxy_invalid_response") from None
    expected_offset = (localize(datetime.combine(datetime.fromisoformat(body["date"]).date(), expected_time), ZoneInfo(body["timezone"])).utcoffset().total_seconds() / 3600
                       if isinstance(body["timezone"], str) else body["timezone"])
    offset = birth.get("timezone")
    if (birth.get("date") != body["date"] or returned_time != expected_time
            or not finite_number(offset) or not finite_number(expected_offset)
            or abs(offset - expected_offset) > 1e-8
            or value.get("conventions") != CONVENTIONS):
        raise RoxyError("roxy_invalid_response")
    if operation == "chart":
        pillars = value.get("pillars")
        if not isinstance(pillars, list) or len(pillars) != 4 or {p.get("position") for p in pillars if isinstance(p, dict)} != set(POSITIONS):
            raise RoxyError("roxy_invalid_response")
        for row in pillars:
            validate_pillar(row)
        validate_day_master(value, next(row["stem"]["chinese"] for row in pillars if row["position"] == "day"))
    elif operation == "strength":
        civil = datetime.fromisoformat(body["date"] + "T" + body["time"]).replace(tzinfo=ZoneInfo("UTC"))
        validate_day_master(value, pillars_at(civil, "local")["day"][0])
        score, factors = value.get("score"), value.get("factors")
        if not finite_number(score) or not isinstance(factors, list) or len(factors) != 3:
            raise RoxyError("roxy_invalid_response")
        band = "very-weak" if score < -3 else "weak" if score < -1 else "balanced" if score < 1 else "strong" if score < 3 else "very-strong"
        if (value.get("verdict") != band or any(not isinstance(factor, dict) or not finite_number(factor.get("contribution")) or not isinstance(factor.get("detail"), str) for factor in factors)
                or abs(sum(factor["contribution"] for factor in factors) - score) > 1e-6):
            raise RoxyError("roxy_invalid_response")
        for key in ("favorableElements", "unfavorableElements"):
            if key in value and (not isinstance(value[key], list) or any(element not in ("Wood", "Fire", "Earth", "Metal", "Water") for element in value[key])):
                raise RoxyError("roxy_invalid_response")
    elif operation == "luck":
        if value.get("gender") != body["gender"] or not isinstance(value.get("luckPillars"), list) or not value["luckPillars"]:
            raise RoxyError("roxy_invalid_response")
        if not finite_number(value.get("startAge")):
            raise RoxyError("roxy_invalid_response")
        for row in value["luckPillars"]:
            validate_pillar(row)
            if (any(not finite_number(row.get(key)) for key in ("startAge", "endAge", "startYear", "endYear"))
                    or row["startAge"] > row["endAge"] or row["startYear"] > row["endYear"]):
                raise RoxyError("roxy_invalid_response")
    elif operation == "annual":
        if value.get("year") != body["year"]:
            raise RoxyError("roxy_invalid_response")
        validate_pillar(value.get("annualPillar"))
        if "yearBranchRelationMeaning" in value and not isinstance(value["yearBranchRelationMeaning"], str):
            raise RoxyError("roxy_invalid_response")


def chart_for_app(profile: ProfileInput, raw: dict | None, status="ready", instant: datetime | None = None):
    pillars = {row["position"]: row["stem"]["chinese"] + row["branch"]["chinese"] for row in raw["pillars"]} if raw else dict.fromkeys(POSITIONS)
    counts = dict.fromkeys("木火土金水", 0)
    for pillar in pillars.values():
        for char in pillar or "":
            counts[ELEMENTS[char]] += 1
    instant = instant or calculation_instant(profile, "local")
    return {
        "method": "Chinese Four Pillars", "engine": "RoxyAPI", "engine_version": "v2",
        "calculation_version": "roxy-bazi-1", "status": status,
        "time_convention": (str(instant.tzinfo) if instant else profile.timezone) + " / split-zi / li-chun / civil time",
        "calculation_time": instant.isoformat() if instant else None,
        "time_known": bool(profile.birth_time), "pillars": pillars, "visible_element_counts": counts,
        "source": "https://roxyapi.com/docs/guides/chinese-astrology",
        "notes": ["RoxyAPI实际返回的四柱；五行数量只统计可见干支。"] if raw else ["RoxyAPI完整八字需要准确时分；未补造四柱。"],
    }


class RoxyBazi:
    def __init__(self, settings: Settings, store: Storage):
        self.settings, self.store = settings, store
        self.cache = OrderedDict()
        self.inflight = {}
        self.failures = OrderedDict()
        self.slots = asyncio.Semaphore(4)

    @property
    def enabled(self):
        return bool(self.settings.roxy_enabled and self.settings.roxy_api_key)

    def public(self):
        return {"enabled": self.enabled, "bazi_provider": self.settings.bazi_provider,
                "operations": list(PATHS), "per_minute": self.settings.roxy_per_minute, "per_day": self.settings.roxy_per_day}

    async def request(self, operation: str, body: dict, language: str, owner: str, network: str):
        if not self.enabled:
            raise RoxyError("roxy_unconfigured")
        if operation not in PATHS:
            raise RoxyError("validation_failed")
        lang = "zh-Hans" if language == "zh" else "en"
        signature = json.dumps([operation, body, lang, owner], sort_keys=True)
        key = hashlib.sha256(signature.encode()).hexdigest()
        cached = self.cache.get(key)
        if cached and cached[0] > monotonic():
            self.cache.move_to_end(key)
            return {"data": deepcopy(cached[1]), "cached": True, "language": lang}
        failure = self.failures.get(key)
        if failure and failure[0] > monotonic():
            raise RoxyError(failure[1])
        task = self.inflight.get(key)
        if task is None:
            task = asyncio.create_task(self._fetch(key, operation, body, lang, owner, network))
            self.inflight[key] = task
            task.add_done_callback(lambda completed: (self.inflight.pop(key, None), completed.exception() if not completed.cancelled() else None))
        return await asyncio.shield(task)

    async def _fetch(self, key, operation, body, lang, owner, network):
        try:
            if not self.store.reserve_roxy([owner, network], self.settings.roxy_per_minute, self.settings.roxy_per_day):
                raise RoxyError("roxy_local_limit")
            async with asyncio.timeout(30), self.slots:
                async with httpx.AsyncClient(timeout=25, follow_redirects=False) as client:
                    async with client.stream("POST", BASE_URL + "/chinese-astrology/bazi/" + PATHS[operation],
                                             headers={"X-API-Key": self.settings.roxy_api_key}, params={"lang": lang}, json=body) as response:
                        if response.status_code != 200:
                            code = {401: "roxy_auth_failed", 403: "roxy_auth_failed", 429: "roxy_quota", 400: "roxy_input_rejected", 422: "roxy_input_rejected"}.get(response.status_code, "roxy_unavailable")
                            raise RoxyError(code)
                        content = bytearray()
                        async for chunk in response.aiter_bytes():
                            content.extend(chunk)
                            if len(content) > 524288:
                                raise RoxyError("roxy_invalid_response")
                if self.settings.roxy_api_key.encode() in content:
                    raise RoxyError("roxy_invalid_response")
                value = json.loads(content)
                validate_result(operation, value, body)
            self.cache[key] = (monotonic() + 86400, value)
            while len(self.cache) > 128:
                self.cache.popitem(last=False)
            return {"data": deepcopy(value), "cached": False, "language": lang}
        except (httpx.HTTPError, TimeoutError):
            error = RoxyError("roxy_unavailable")
        except (ValueError, TypeError, KeyError, AttributeError, RecursionError, OverflowError):
            error = RoxyError("roxy_invalid_response")
        except RoxyError as caught:
            error = caught
        self.failures[key] = (monotonic() + 30, error.code)
        while len(self.failures) > 128:
            self.failures.popitem(last=False)
        raise error

    async def profile_chart(self, profile: ProfileInput, owner: str, network: str):
        instant = calculation_instant(profile, "beijing")
        if not profile.birth_time:
            return chart_for_app(profile, None, "time-required")
        result = await self.request("chart", request_body(profile, instant), profile.language, owner, network)
        return chart_for_app(profile, result["data"], instant=instant)

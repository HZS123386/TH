"""Versioned, local Suriyayatra adapter. Birth data never leaves this computer."""
import hashlib
import json
import shutil
import subprocess
from datetime import datetime, time, timedelta, timezone
from functools import lru_cache
from pathlib import Path
from zoneinfo import ZoneInfo

from .bazi import localize
from .opastro_adapter import analyze

ROOT = Path(__file__).resolve().parents[2]
ENGINE_VERSION = "thai-astrology@0.3.2/wanjai-suriyayatra-1/input-audit-2"


def _run(payload: dict):
    node = shutil.which("node")
    if not node:
        raise RuntimeError("thai_engine_unavailable")
    try:
        process = subprocess.run([node, str(ROOT / "scripts" / "thai-engine.mjs")], input=json.dumps(payload), text=True, encoding="utf-8", capture_output=True, timeout=12, cwd=ROOT, check=True)
        return json.loads(process.stdout)
    except (subprocess.SubprocessError, ValueError, OSError):
        raise RuntimeError("thai_calculation_failed") from None


def fingerprint(profile: dict):
    return hashlib.sha256((ENGINE_VERSION + json.dumps(profile, sort_keys=True)).encode()).hexdigest()


def offset_for(profile: dict):
    if not profile.get("birth_time"):
        return None
    value = datetime.combine(datetime.fromisoformat(profile["birth_date"]).date(), time.fromisoformat(profile["birth_time"]))
    return int(localize(value, ZoneInfo(profile["timezone"])).utcoffset().total_seconds())


def natal(profile: dict):
    offset = offset_for(profile)
    result = _run({"operation": "natal", "profile": profile, "offset_seconds": offset})
    if result["status"] == "ready":
        local = localize(datetime.combine(datetime.fromisoformat(profile["birth_date"]).date(), time.fromisoformat(profile["birth_time"])), ZoneInfo(profile["timezone"]))
        result["calculation_input"] = {
            "local_datetime": local.isoformat(timespec="minutes"),
            "utc_datetime": local.astimezone(timezone.utc).isoformat(timespec="minutes"),
            "utc_offset_seconds": offset,
            "time_zone": profile["timezone"],
            "zodiac_model": "suriyayatra-classical-longitudes",
            "ascendant_model": "sunrise-fixed-anto",
            "house_system": "whole-sign",
            "relationship_model": "sign-based",
        }
    return result


def transits(profile: dict):
    now = datetime.now(ZoneInfo("Asia/Bangkok"))
    return _run({"operation": "transits", "profile": profile, "offset_seconds": offset_for(profile), "now": {"date": now.date().isoformat(), "time": now.strftime("%H:%M"), "iso": now.isoformat()}})


def annual(year: int, ascendant: int):
    return _run({"operation": "annual", "year": year, "ascendant": ascendant})


@lru_cache(maxsize=128)
def career_window(start: str, ascendant: int):
    return _run({"operation": "career-window", "start": start, "ascendant": ascendant})


def civil_day_window(profile: dict):
    """Retain the first and last real civil minutes, including DST fold bounds."""
    zone = ZoneInfo(profile["timezone"])
    midnight = datetime.fromisoformat(profile["birth_date"])

    def endpoint(minutes, earliest):
        for minute in minutes:
            local = midnight + timedelta(minutes=minute)
            candidates = [local.replace(tzinfo=zone, fold=fold) for fold in (0, 1)]
            valid = [value for value in candidates if value.astimezone(timezone.utc).astimezone(zone).replace(tzinfo=None) == local]
            if valid:
                choose = min if earliest else max
                value = choose(valid, key=lambda value: value.astimezone(timezone.utc))
                return {"time": value.strftime("%H:%M"), "offset_seconds": int(value.utcoffset().total_seconds())}
        raise ValueError("birth_date_does_not_exist_in_timezone")

    return [endpoint(range(1440), True), endpoint(range(1439, -1, -1), False)]


def fortune(profile: dict, period: str, now: datetime | None = None):
    now = (now or datetime.now(ZoneInfo("Asia/Bangkok"))).astimezone(ZoneInfo("Asia/Bangkok"))
    zone_known = bool(profile.get("birthplace") or profile.get("location_id") or profile.get("latitude") is not None)
    if zone_known:
        window = [{"time": profile["birth_time"], "offset_seconds": offset_for(profile)}] if profile.get("birth_time") else civil_day_window(profile)
    else:
        # Preserve the full possible UTC interval instead of assuming Bangkok
        # when the user only supplied a local date (and perhaps a clock time).
        window = [{"time": profile.get("birth_time") or "00:00", "offset_seconds": 50400}, {"time": profile.get("birth_time") or "23:59", "offset_seconds": -43200}]
    result = _run({"operation": "fortune", "profile": profile, "period": period, "birth_window": window, "zone_known": zone_known, "now": {"date": now.date().isoformat(), "time": now.strftime("%H:%M"), "iso": now.isoformat()}})
    result["analysis"] = analyze(result, result.pop("analysis_samples"))
    return result


@lru_cache(maxsize=256)
def locations(country: str, query: str, offset: int, level: str = "city", province: str = ""):
    return _run({"operation": "locations", "country": country, "query": query, "offset": offset, "level": level, "province": province})


def compact(result: dict):
    chart = result.get("chart")
    return {"engine": result["engine"], "status": result["status"], "calendar": result["calendar"], "taksa": result["taksa"], "location": result.get("location"), "points": {key: {field: point[field] for field in ("nameThai", "number", "sign", "signName", "degrees", "minutes", "house", "dignities", "rerk")} for key, point in chart["points"].items()} if chart else None, "houses": chart["houses"] if chart else None, "factors": chart["factors"] if chart else None}

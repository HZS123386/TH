from datetime import datetime, time, timedelta, timezone
from importlib.metadata import version
from zoneinfo import ZoneInfo

from lunar_python import Solar
from lunar_python.util import LunarUtil

from .schemas import ProfileInput

ELEMENTS = dict(zip("甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥", "木木火火土土金金水水水土木木土火火土金金土水"))
GOD_CATEGORIES = {"比肩": "peer", "劫财": "peer", "食神": "output", "伤官": "output", "正财": "wealth", "偏财": "wealth", "正官": "influence", "七杀": "influence", "正印": "resource", "偏印": "resource"}


def ten_god(day_stem, other_stem):
    name = LunarUtil.SHI_SHEN[day_stem + other_stem]
    return {"chinese": name, "category": GOD_CATEGORIES[name]}


def structure(chart):
    """Derive the day master, Ten Gods and hidden stems from verified pillars."""
    day = chart["pillars"]["day"][0]
    rows = []
    for position, pillar in chart["pillars"].items():
        if pillar:
            rows.append({"position": position, "pillar": pillar,
                         "tenGod": {"chinese": "日主", "category": "self"} if position == "day" else ten_god(day, pillar[0]),
                         "hiddenStems": [{"stem": stem, "tenGod": ten_god(day, stem)} for stem in LunarUtil.ZHI_HIDE_GAN[pillar[1]]]})
    return {"dayMaster": {"chinese": day, "element": ELEMENTS[day]}, "pillars": rows}


def localize(value: datetime, zone: ZoneInfo) -> datetime:
    candidates = []
    for fold in (0, 1):
        aware = value.replace(tzinfo=zone, fold=fold)
        if aware.astimezone(timezone.utc).astimezone(zone).replace(tzinfo=None) == value:
            if not candidates or candidates[0].utcoffset() != aware.utcoffset():
                candidates.append(aware)
    if len(candidates) != 1:
        raise ValueError("birth_time_invalid")
    return candidates[0]


def pillars_at(value: datetime, clock: str = "beijing") -> dict:
    converted = value.astimezone(ZoneInfo("Asia/Shanghai")) if clock == "beijing" else value
    eight = Solar.fromYmdHms(converted.year, converted.month, converted.day, converted.hour, converted.minute, converted.second).getLunar().getEightChar()
    eight.setSect(2)
    # Solar-term timestamps published by this library use fixed UTC+08:00.
    # Year/month follow the actual instant; day/hour follow the chosen clock.
    term_time = value.astimezone(timezone(timedelta(hours=8)))
    terms = Solar.fromYmdHms(term_time.year, term_time.month, term_time.day, term_time.hour, term_time.minute, term_time.second).getLunar().getEightChar()
    return {"year": terms.getYear(), "month": terms.getMonth(), "day": eight.getDay(), "hour": eight.getTime()}


def calculate(profile: ProfileInput, clock: str = "beijing") -> dict:
    zone = ZoneInfo(profile.timezone)
    notes = ["按出生地民用时间转换为北京时间；日柱采用 sect=2，未校正真太阳时。", "五行只统计可见干支，不代表旺衰、喜用神或运势评分。"]
    calculation_time = None
    if profile.birth_time:
        local = localize(datetime.combine(profile.birth_date, time.fromisoformat(profile.birth_time)), zone)
        pillars = pillars_at(local, clock)
        calculation_time = (local.astimezone(ZoneInfo("Asia/Shanghai")) if clock == "beijing" else local).isoformat()
    else:
        start = localize(datetime.combine(profile.birth_date, time.min), zone)
        end = localize(datetime.combine(profile.birth_date + timedelta(days=1), time.min), zone) - timedelta(seconds=1)
        # Within one civil day these three pillars cannot change and cycle back.
        variants = [pillars_at(start, clock), pillars_at(end, clock)]
        pillars = {key: value if all(row[key] == value for row in variants) else None for key, value in variants[0].items()}
        pillars["hour"] = None
        notes.append("出生时间未知：仅保留当日稳定的柱，不假设中午或补全时柱。")
    counts = {key: 0 for key in "木火土金水"}
    for pillar in pillars.values():
        if pillar:
            for character in pillar:
                counts[ELEMENTS[character]] += 1
    return {
        "method": "Chinese Four Pillars",
        "engine": "lunar-python",
        "engine_version": version("lunar-python"),
        "calculation_version": "sabai-2",
        "time_convention": ("Asia/Shanghai" if clock == "beijing" else profile.timezone) + " / sect=2 / civil time",
        "calculation_time": calculation_time,
        "time_known": profile.birth_time is not None,
        "pillars": pillars,
        "visible_element_counts": counts,
        "notes": notes if clock == "beijing" else ["出生地当地民用时间；sect=2，未校正真太阳时。", *notes[1:]],
        "source": "https://github.com/6tail/lunar-python",
    }

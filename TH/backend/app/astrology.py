"""Western astrology domain adapter: Roxy calculates, the report writer interprets."""
import asyncio
from datetime import datetime, time
from zoneinfo import ZoneInfo

from . import thai
from .bazi import localize
from .roxy import RoxyClient, RoxyError, finite_number, validate_json

VERSION = "roxy-western-compact-1"
CHAPTERS = ("natal", "career", "wealth", "love", "risk")
TITLES = {
    "zh": ("本命解读", "事业解读", "财运解读", "感情姻缘", "风险预警", "行动建议"),
    "th": ("พื้นดวง", "การงาน", "การเงิน", "ความรักและคู่ครอง", "เรื่องที่ควรระวัง", "คำแนะนำลงมือทำ"),
}
QUESTIONS = {
    "zh": ("怎样发挥长处，做出适合自己的选择", "什么工作方式与协作环境更适合我", "怎样管理收入、支出与共同资源", "如何表达需要、处理关系中的分歧", "哪些行为模式需要提前调整"),
    "th": ("ใช้จุดแข็งและตัดสินใจอย่างเหมาะกับตัวเอง", "รูปแบบงานและสภาพแวดล้อมแบบไหนเหมาะกับฉัน", "วางแผนรายรับรายจ่ายและทรัพยากรร่วมกันอย่างไร", "บอกความต้องการและจัดการความเห็นต่างอย่างไร", "พฤติกรรมใดควรสังเกตและค่อย ๆ ปรับ"),
}
SCOPES = {
    "natal": "identity, emotional needs, strengths and decisions; no repetition of the free preview",
    "career": "work style, collaboration, suitable working conditions and skill development; no invented job offers or dates",
    "wealth": "earning habits, spending boundaries and resource planning; no investment advice or promised wealth",
    "love": "attraction, emotional needs, communication and relationship boundaries; no assumptions about relationship status or a partner's chart",
    "risk": "modifiable patterns of overcommitment, conflict or avoidance; no illness, disaster, death, doom or guaranteed events",
}
TOPIC_PLANETS = {
    "overview": ("sun", "mercury", "venus", "saturn"),
    "natal": ("sun", "moon", "mercury"),
    "career": ("sun", "mercury", "mars", "saturn", "midheaven"),
    "wealth": ("venus", "jupiter", "saturn"),
    "love": ("venus", "moon", "mars"),
    "risk": ("mars", "saturn", "neptune", "pluto"),
}
TOPIC_HOUSES = {"overview": (1, 5, 7, 10), "natal": (1, 5), "career": (6, 10), "wealth": (2, 8, 11), "love": (5, 7), "risk": (6, 12)}
TRAIT_PLANETS = {"strength": ("sun", "jupiter"), "decisions": ("mercury", "saturn"), "relationships": ("venus", "mars")}
PLANETS = {
    "Sun": ("太阳", "อาทิตย์"), "Moon": ("月亮", "จันทร์"),
    "Mercury": ("水星", "พุธ"), "Venus": ("金星", "ศุกร์"),
    "Mars": ("火星", "อังคาร"), "Jupiter": ("木星", "พฤหัสบดี"),
    "Saturn": ("土星", "เสาร์"), "Uranus": ("天王星", "ยูเรนัส"),
    "Neptune": ("海王星", "เนปจูน"), "Pluto": ("冥王星", "พลูโต"),
    "North Node": ("北交点", "โหนดเหนือ"), "South Node": ("南交点", "โหนดใต้"),
    "Chiron": ("凯龙星", "ไครอน"), "Black Moon Lilith": ("莉莉丝", "ลิลิธ"),
}
SIGNS = ("Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces")
SIGN_LABELS = {
    "zh": ("白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座", "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"),
    "th": ("เมษ", "พฤษภ", "เมถุน", "กรกฎ", "สิงห์", "กันย์", "ตุล", "พิจิก", "ธนู", "มกร", "กุมภ์", "มีน"),
}
ASPECTS = {"CONJUNCTION": ("合相", "กุม"), "OPPOSITION": ("对分相", "เล็ง"), "TRINE": ("三分相", "ตรีโกณ"), "SQUARE": ("四分相", "ฉาก"), "SEXTILE": ("六分相", "โยค")}
ASPECT_ANGLES = {"CONJUNCTION": 0, "SEXTILE": 60, "SQUARE": 90, "TRINE": 120, "OPPOSITION": 180}


def point_id(name):
    return name.lower().replace(" ", "_")


def western(chart):
    return chart.get("provider") == "roxy" and chart.get("domain") == "astrology"


def validate_natal(operation, value, body):
    validate_json(value)
    def require(condition):
        if not condition:
            raise RoxyError("roxy_invalid_response")
    def position(row):
        require(isinstance(row, dict))
        lon, degree = row.get("longitude"), row.get("degree")
        require(finite_number(lon) and 0 <= lon < 360 and finite_number(degree) and 0 <= degree < 30)
        require(row.get("sign") == SIGNS[int(lon // 30)] and abs(degree - lon % 30) < 1e-6)
    require(isinstance(value, dict) and value.get("houseSystem") == body["houseSystem"])
    birth = value.get("birthDetails", {})
    instant = localize(datetime.fromisoformat(body["date"] + "T" + body["time"]), ZoneInfo(body["timezone"]))
    require(birth.get("date") == body["date"] and birth.get("time") == body["time"])
    for key, expected in (("latitude", body["latitude"]), ("longitude", body["longitude"]), ("timezone", instant.utcoffset().total_seconds() / 3600)):
        require(finite_number(birth.get(key)) and abs(birth[key] - expected) < 1e-6)
    require(birth.get("nodeType", body["nodeType"]) == body["nodeType"])
    planets, houses, aspects = value.get("planets"), value.get("houses"), value.get("aspects")
    require(isinstance(planets, list) and 10 <= len(planets) <= 32)
    names = [row.get("name") for row in planets if isinstance(row, dict)]
    require(len(names) == len(planets) == len(set(names)) and set(list(PLANETS)[:10]) <= set(names) and set(names) <= set(PLANETS))
    for row in planets:
        position(row)
        require(type(row.get("house")) is int and 1 <= row["house"] <= 12 and type(row.get("isRetrograde")) is bool)
        if "speed" in row:
            require(finite_number(row["speed"]) and (row["speed"] < 0) == row["isRetrograde"])
        interpretation = row.get("interpretation", {})
        require(isinstance(interpretation, dict) and all(isinstance(interpretation.get(key, ""), str)
                and len(interpretation.get(key, "")) <= 16000 for key in ("summary", "detailed")))
    require(isinstance(houses, list) and len(houses) == 12 and {row.get("number") for row in houses if isinstance(row, dict)} == set(range(1, 13)))
    for row in houses:
        position(row)
    for key in ("ascendant", "midheaven"):
        position(value.get(key))
    require(isinstance(aspects, list) and len(aspects) <= 512)
    for row in aspects:
        require(isinstance(row, dict) and row.get("planet1") in names and row.get("planet2") in names and row["planet1"] != row["planet2"])
        require(isinstance(row.get("type"), str) and finite_number(row.get("orb")) and 0 <= row["orb"] <= 30)
        if row["type"] in ASPECT_ANGLES:
            by_name = {planet["name"]: planet["longitude"] for planet in planets}
            separation = abs((by_name[row["planet1"]] - by_name[row["planet2"]] + 180) % 360 - 180)
            require(row.get("angle") == ASPECT_ANGLES[row["type"]]
                    and abs(abs(separation - row["angle"]) - row["orb"]) < 0.02)


class RoxyAstrology(RoxyClient):
    domain = "astrology"

    def __init__(self, settings, store):
        super().__init__(settings, store, paths={"natal": "/astrology/natal-chart"}, validator=validate_natal)

    async def resolve_place(self, profile):
        if profile.latitude is not None:
            place = {"latitude": profile.latitude, "longitude": profile.longitude, "timeZone": profile.timezone,
                     "nameEnglish": profile.birthplace, "country": profile.country_code}
        else:
            # Reuse the existing geographic directory, without calling the Thai chart engine.
            result = await asyncio.to_thread(thai.locations, profile.country_code or "",
                                             profile.location_id or profile.birthplace, 0,
                                             "detail" if profile.location_id else "auto")
            place = result.get("resolved")
            if not place:
                raise RoxyError("roxy_input_rejected")
        zone = place.get("timeZone") or profile.timezone
        if zone != profile.timezone:
            raise RoxyError("roxy_input_rejected")
        return place

    async def calculate(self, profile, owner, network):
        place = await self.resolve_place(profile)
        zone = profile.timezone
        clock = profile.birth_time or "12:00"
        try:
            localize(datetime.combine(profile.birth_date, time.fromisoformat(clock)), ZoneInfo(zone))
        except ValueError:
            raise RoxyError("roxy_input_rejected") from None
        body = {"date": profile.birth_date.isoformat(), "time": clock + ":00", "latitude": place["latitude"],
                "longitude": place["longitude"], "timezone": zone, "houseSystem": "placidus", "nodeType": "true"}
        # Western Chinese coverage can fall back to English; Thai/Vietnamese are
        # unsupported upstream. Keep one canonical source language for the writer.
        result = await self.request("natal", body, "en", owner, network)
        return {"provider": "roxy", "domain": self.domain, "version": VERSION, "status": "ready",
                "location": place, "time_known": bool(profile.birth_time), "calculation_input": body,
                "source": "https://roxyapi.com/docs/guides/astrology", "raw": result["data"]}

    @staticmethod
    def chart_view(chart, language):
        known, raw = chart["time_known"], chart["raw"]
        column = 0 if language == "zh" else 1
        def point(row, name=None):
            name = name or row["name"]
            label = (PLANETS[name][column] if name in PLANETS else
                     ("本命上升" if language == "zh" else "ลัคนา") if name == "Ascendant" else
                     ("天顶" if language == "zh" else "จุดยอดฟ้า"))
            return {"id": point_id(name), "label": label, "sign_index": SIGNS.index(row["sign"]),
                    "sign_name": SIGN_LABELS[language][SIGNS.index(row["sign"])], "longitude": row["longitude"],
                    "degree": row["degree"], "house": row.get("house") if known else None}
        planets = [point(row) for row in raw["planets"] if known or row["name"] != "Moon"]
        if known:
            planets.extend((point(raw["ascendant"], "Ascendant"), point(raw["midheaven"], "Midheaven")))
        return {"precision": "exact" if known else "estimated", "engine": "RoxyAPI Western Astrology",
                "relationship_model": "degree-orb", "planets": planets,
                "houses": [{"number": row["number"], "longitude": row["longitude"]} for row in raw["houses"]] if known else [],
                "aspects": [{"planet1": point_id(row["planet1"]), "planet2": point_id(row["planet2"]),
                             "type": row["type"].lower(), "orb": row["orb"]}
                            for row in raw["aspects"] if known and row["type"] in ASPECTS and row["orb"] <= 6]}

    @classmethod
    def bundle(cls, body, chart, reading):
        language, known = body.profile.language, chart["time_known"]
        zh, column = language == "zh", 0 if language == "zh" else 1
        view = cls.chart_view(chart, language)
        facts = {}
        raw_planets = {point_id(row["name"]): row for row in chart["raw"]["planets"]}
        for row in view["planets"]:
            # Noon cannot support a reliable Moon placement, angles, houses or their interpretations.
            if not known and row["id"] == "moon":
                continue
            detail = f"{row['sign_name']} {row['degree']:.2f}°"
            if known and row["house"]:
                detail += f" · 第{row['house']}宫" if zh else f" · เรือนที่ {row['house']}"
            if not known:
                detail += "（当地12:00估算）" if zh else " (ประมาณเวลา 12:00 ท้องถิ่น)"
            fact = {"type": "planet", "key": row["id"], "sign": row["sign_index"], "longitude": row["longitude"],
                    "house": row["house"], "title": row["label"], "detail": detail, "provider": "roxy"}
            source = raw_planets.get(row["id"], {})
            if source:
                fact["retrograde"] = source["isRetrograde"]
                if source["isRetrograde"]:
                    fact["detail"] += " · 逆行" if zh else " · ถอยหลัง"
                if source.get("dignity") in ("domicile", "exaltation", "detriment", "fall", "peregrine"):
                    fact["dignity"] = source["dignity"]
            interpretation = source.get("interpretation", {})
            if known and isinstance(interpretation, dict):
                fact["interpretation"] = {key: interpretation[key][:1600] for key in ("summary", "detailed") if isinstance(interpretation.get(key), str)}
            facts["P_" + row["id"]] = fact
        for row in chart["raw"]["houses"] if known else []:
            facts[f"H{row['number']}"] = {"type": "house", "number": row["number"], "longitude": row["longitude"],
                "title": f"第{row['number']}宫" if zh else f"เรือนที่ {row['number']}",
                "detail": f"{SIGN_LABELS[language][SIGNS.index(row['sign'])]} {row['degree']:.2f}° · Placidus", "provider": "roxy"}
        for index, row in enumerate(sorted(chart["raw"]["aspects"], key=lambda row: row["orb"]) if known else []):
            if row["type"] not in ASPECTS or row["orb"] > 6 or "Node" in row["planet1"] or "Node" in row["planet2"]:
                continue
            facts[f"A{index}"] = {"type": "aspect", "planet1": point_id(row["planet1"]), "planet2": point_id(row["planet2"]),
                "aspect": row["type"], "orb": row["orb"], "title": f"{PLANETS[row['planet1']][column]} · {PLANETS[row['planet2']][column]}",
                "detail": f"{ASPECTS[row['type']][column]} · {row['orb']:.2f}°", "provider": "roxy"}
        topic = reading if reading in TOPIC_PLANETS else "overview"
        selected = ["P_" + key for key in TOPIC_PLANETS[topic] if "P_" + key in facts]
        selected.extend(f"H{number}" for number in TOPIC_HOUSES[topic] if f"H{number}" in facts)
        aspect_ids = [key for key, fact in facts.items() if fact["type"] == "aspect" and
                      (fact["aspect"] in ("SQUARE", "OPPOSITION") if topic == "risk" else
                       bool({fact["planet1"], fact["planet2"]} & set(TOPIC_PLANETS[topic])))]
        selected.extend(aspect_ids[:5])
        # Keep the writer's context small and domain-specific, while retaining actual supporting positions.
        facts = {key: fact for key, fact in facts.items() if key in selected or fact["type"] == "planet"}
        return {"format": VERSION, "domain": "astrology", "stage": "chapter", "reading": reading, "language": language,
                "method": {"name": "Western tropical astrology", "provider": "RoxyAPI", "api_version": "v2", "house_system": "placidus", "node_type": "true"},
                "evidence": facts, "topic_evidence": selected,
                "citation_rules": {"topic_ids": selected,
                    "supporting_natal_ids": [key for key, fact in facts.items() if fact["type"] == "planet"],
                    "trait_ids": {key: ["P_" + item for item in values] for key, values in TRAIT_PLANETS.items()}},
                "birth_time_basis": {"mode": "exact" if known else "estimated", "assumed_local_time": None if known else "12:00",
                                     "excluded": [] if known else ["ascendant", "midheaven", "houses", "moon", "aspects", "timing_predictions"]},
                "scope": SCOPES.get(reading, "personality, decision style and relationship needs"),
                "translation_fields": {}, "fixed_translations": {}}

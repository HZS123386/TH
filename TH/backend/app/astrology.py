"""Western astrology domain adapter: Roxy calculates, the report writer interprets."""
import asyncio
import hashlib
import json
import logging
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from . import thai
from .bazi import localize
from .roxy import RoxyClient, RoxyError, finite_number, validate_json
from .report_languages import REGIONAL_LANGUAGES

VERSION = "roxy-western-compact-1"
CHAPTERS = ("natal", "career", "wealth", "love", "risk")
TITLES = {
    "en": ("Personal patterns", "Career", "Money", "Love and partnership", "Patterns to watch", "Practical suggestions"),
    "vi": ("Đặc điểm cá nhân", "Sự nghiệp", "Tài chính", "Tình yêu và gắn bó", "Điều cần chú ý", "Gợi ý hành động"),
    "zh": ("本命解读", "事业解读", "财运解读", "感情姻缘", "风险预警", "行动建议"),
    "th": ("พื้นดวง", "การงาน", "การเงิน", "ความรักและคู่ครอง", "เรื่องที่ควรระวัง", "คำแนะนำลงมือทำ"),
}
QUESTIONS = {
    "en": ("How can I use my strengths and make suitable choices?", "Which work styles and collaborative environments suit me?", "How do I approach income, spending and shared resources?", "How can I express needs and handle differences?", "Which personal patterns might benefit from adjustment?"),
    "vi": ("Phát huy điểm mạnh và lựa chọn phù hợp thế nào?", "Cách làm việc và môi trường hợp tác nào phù hợp?", "Quản lý thu nhập, chi tiêu và nguồn lực chung ra sao?", "Bày tỏ nhu cầu và xử lý khác biệt thế nào?", "Những thói quen nào cần được điều chỉnh?"),
    "zh": ("怎样发挥长处，做出适合自己的选择", "什么工作方式与协作环境更适合我", "怎样管理收入、支出与共同资源", "如何表达需要、处理关系中的分歧", "哪些行为模式需要提前调整"),
    "th": ("ใช้จุดแข็งและตัดสินใจอย่างเหมาะกับตัวเอง", "รูปแบบงานและสภาพแวดล้อมแบบไหนเหมาะกับฉัน", "วางแผนรายรับรายจ่ายและทรัพยากรร่วมกันอย่างไร", "บอกความต้องการและจัดการความเห็นต่างอย่างไร", "พฤติกรรมใดควรสังเกตและค่อย ๆ ปรับ"),
}
SCOPES = {
    "natal": "identity, emotional needs, strengths, activities that may suit the reader's abilities, and ways to develop strengths and adjust limitations; deepen rather than repeat the free preview",
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
    "Sun": ("太阳", "อาทิตย์", "Sun", "Mặt Trời"), "Moon": ("月亮", "จันทร์", "Moon", "Mặt Trăng"),
    "Mercury": ("水星", "พุธ", "Mercury", "Sao Thủy"), "Venus": ("金星", "ศุกร์", "Venus", "Sao Kim"),
    "Mars": ("火星", "อังคาร", "Mars", "Sao Hỏa"), "Jupiter": ("木星", "พฤหัสบดี", "Jupiter", "Sao Mộc"),
    "Saturn": ("土星", "เสาร์", "Saturn", "Sao Thổ"), "Uranus": ("天王星", "ยูเรนัส", "Uranus", "Sao Thiên Vương"),
    "Neptune": ("海王星", "เนปจูน", "Neptune", "Sao Hải Vương"), "Pluto": ("冥王星", "พลูโต", "Pluto", "Sao Diêm Vương"),
    "North Node": ("北交点", "โหนดเหนือ", "North Node", "Nút Bắc"), "South Node": ("南交点", "โหนดใต้", "South Node", "Nút Nam"),
    "Chiron": ("凯龙星", "ไครอน", "Chiron", "Chiron"), "Black Moon Lilith": ("莉莉丝", "ลิลิธ", "Black Moon Lilith", "Lilith"),
}
SIGNS = ("Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces")
SIGN_LABELS = {
    "en": SIGNS,
    "vi": ("Bạch Dương", "Kim Ngưu", "Song Tử", "Cự Giải", "Sư Tử", "Xử Nữ", "Thiên Bình", "Bọ Cạp", "Nhân Mã", "Ma Kết", "Bảo Bình", "Song Ngư"),
    "zh": ("白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座", "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"),
    "th": ("เมษ", "พฤษภ", "เมถุน", "กรกฎ", "สิงห์", "กันย์", "ตุล", "พิจิก", "ธนู", "มกร", "กุมภ์", "มีน"),
}
ASPECTS = {"CONJUNCTION": ("合相", "กุม", "Conjunction", "Trùng tụ"), "OPPOSITION": ("对分相", "เล็ง", "Opposition", "Đối đỉnh"), "TRINE": ("三分相", "ตรีโกณ", "Trine", "Tam hợp"), "SQUARE": ("四分相", "ฉาก", "Square", "Vuông góc"), "SEXTILE": ("六分相", "โยค", "Sextile", "Lục hợp")}
ASPECT_ANGLES = {"CONJUNCTION": 0, "SEXTILE": 60, "SQUARE": 90, "TRINE": 120, "OPPOSITION": 180}
FORECAST_VERSION = "roxy-western-transits-2"
FORECAST_DAYS = 90
FORECAST_EVENT_TYPES = {"transit-aspect", "sign-ingress", "retrograde-station", "eclipse", "lunar-phase"}
FORECAST_REPORT_PLANETS = set(list(PLANETS)[:10])
logger = logging.getLogger(__name__)

# Extend the existing label tables in their established column order.
LANGUAGE_COLUMNS = {code: index for index, code in enumerate(("zh", "th", "en", "vi", *REGIONAL_LANGUAGES))}
for code, copy in REGIONAL_LANGUAGES.items():
    TITLES[code] = tuple(copy["western_titles"])
    QUESTIONS[code] = tuple(copy["western_questions"])
    SIGN_LABELS[code] = tuple(copy["reading"]["signs"])
    for name in PLANETS:
        key = name.lower().replace(" ", "_")
        label = copy["reading"]["planets"][key] if key in copy["reading"]["planets"] else copy["extra_planets"][name]
        PLANETS[name] += (label,)
    for name in ASPECTS:
        ASPECTS[name] += (copy["aspects"][name],)


def point_id(name):
    return name.lower().replace(" ", "_")


def house_label(number, language):
    if language in REGIONAL_LANGUAGES:
        return REGIONAL_LANGUAGES[language]["house"].replace("{number}", str(number))
    return {"zh": f"第{number}宫", "th": f"เรือนที่ {number}", "en": f"House {number}", "vi": f"Nhà {number}"}[language]


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


def validate_forecast(value, body):
    """Accept dated Western events only inside the provider's resolved window."""
    validate_json(value)
    if not isinstance(value, dict):
        raise RoxyError("roxy_invalid_response")
    birth = value.get("birthData", {})
    expected = body["birthData"]
    if (not isinstance(birth, dict) or birth.get("date") != expected["date"]
            or birth.get("time") != expected["time"]):
        raise RoxyError("roxy_invalid_response")
    instant = datetime.fromisoformat(expected["date"] + "T" + expected["time"]).replace(tzinfo=ZoneInfo(expected["timezone"]))
    offset = instant.utcoffset().total_seconds() / 3600
    if birth.get("timezone") != expected["timezone"] and (
            not finite_number(birth.get("timezone")) or birth["timezone"] != offset):
        raise RoxyError("roxy_invalid_response")
    start, end = date.fromisoformat(value["startDate"]), date.fromisoformat(value["endDate"])
    if (start.isoformat() != body["startDate"] or not start <= end <= date.fromisoformat(body["endDate"])
            or (end - start).days > FORECAST_DAYS):
        raise RoxyError("roxy_invalid_response")
    events = value.get("events")
    if (not isinstance(events, list) or len(events) > 1000 or type(value.get("count")) is not int
            or value["count"] != len(events)):
        raise RoxyError("roxy_invalid_response")
    for event in events:
        if not isinstance(event, dict):
            raise RoxyError("roxy_invalid_response")
        day = date.fromisoformat(event["date"])
        at = datetime.fromisoformat(event["datetime"].replace("Z", "+00:00"))
        if (not start <= day <= end or at.utcoffset() != timedelta(0) or at.date() != day
                or event.get("domain") != "western" or event.get("type") not in FORECAST_EVENT_TYPES
                or event.get("body") not in PLANETS or not finite_number(event.get("significance"))
                or not 0 <= event["significance"] <= 100 or not isinstance(event.get("description"), str)
                or len(event["description"]) > 4096):
            raise RoxyError("roxy_invalid_response")
        if event["type"] == "transit-aspect" and (
                event.get("target") not in PLANETS or not isinstance(event.get("aspect"), str)
                or event["aspect"].upper() not in ASPECTS
                or not finite_number(event.get("orb")) or not 0 <= event["orb"] <= 180):
            raise RoxyError("roxy_invalid_response")
        if event["type"] in ("sign-ingress", "lunar-phase") and event.get("target") not in SIGNS:
            raise RoxyError("roxy_invalid_response")
        if event["type"] == "retrograde-station" and event.get("station") not in ("retrograde", "direct"):
            raise RoxyError("roxy_invalid_response")
        if event["type"] == "lunar-phase" and (event["body"] != "Moon" or event.get("phase") not in ("new-moon", "full-moon")):
            raise RoxyError("roxy_invalid_response")
        if event["type"] == "eclipse":
            kinds = {"Sun": {"partial", "annular", "total"}, "Moon": {"penumbral", "partial", "total"}}
            if event.get("kind") not in kinds.get(event["body"], set()):
                raise RoxyError("roxy_invalid_response")
            if "obscuration" in event and (not finite_number(event["obscuration"]) or not 0 <= event["obscuration"] <= 1):
                raise RoxyError("roxy_invalid_response")


def validate_astrology(operation, value, body):
    if operation == "transits":
        validate_forecast(value, body)
    else:
        validate_natal(operation, value, body)


class RoxyAstrology(RoxyClient):
    domain = "astrology"

    def __init__(self, settings, store):
        super().__init__(settings, store, paths={"natal": "/astrology/natal-chart", "transits": "/forecast/transits"},
                         validator=validate_astrology)

    async def forecast(self, profile, owner, network, *, refresh=False):
        start = datetime.now(timezone.utc).date()
        window = {"version": FORECAST_VERSION, "start": start.isoformat(),
                  "end": (start + timedelta(days=FORECAST_DAYS - 1)).isoformat(), "timezone": "UTC"}
        if not profile.birth_time:
            return {**window, "state": "time_unknown", "events": []}
        body = {"birthData": {"date": profile.birth_date.isoformat(), "time": profile.birth_time + ":00",
                              "timezone": profile.timezone},
                "startDate": window["start"], "endDate": window["end"], "minSignificance": 0}
        if refresh:
            # Retry only this subject's failed/empty forecast, retaining all other request caches and quotas.
            key = hashlib.sha256(json.dumps(["transits", body, "en", owner], sort_keys=True).encode()).hexdigest()
            self.cache.pop(key, None)
            self.failures.pop(key, None)
        try:
            response = await self.request("transits", body, "en", owner, network)
        except RoxyError as error:
            logger.warning("Western forecast unavailable (%s)", error.code)
            return {**window, "state": "unavailable", "failure_code": error.code, "events": []}
        raw = response["data"]
        # An exact transit marks a point within this seven-day observation window,
        # not a prediction that its effect lasts for all seven days.
        return {**window, "end": raw["endDate"], "state": "ready",
                # Other valid event types remain outside the supported report-evidence model.
                "events": sorted((row for row in raw["events"] if row["type"] == "transit-aspect"
                                  and row["body"] in FORECAST_REPORT_PLANETS and row["target"] in FORECAST_REPORT_PLANETS
                                  and row["orb"] <= 6 and row["aspect"].upper() in ASPECTS),
                                 key=lambda row: (-row["significance"], row["datetime"], row["body"], row["target"]))}

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

    async def calculate(self, profile, owner, network, *, include_forecast=False):
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
        if include_forecast:
            # The two validated calculations are independent; keep their existing cache and quota checks.
            tasks = [asyncio.create_task(self.request("natal", body, "en", owner, network)),
                     asyncio.create_task(self.forecast(profile, owner, network))]
            try:
                result, forecast = await asyncio.gather(*tasks)
            finally:
                for task in tasks:
                    if not task.done():
                        task.cancel()
                await asyncio.gather(*tasks, return_exceptions=True)
        else:
            result = await self.request("natal", body, "en", owner, network)
        return {"provider": "roxy", "domain": self.domain, "version": VERSION, "status": "ready",
                "location": place, "time_known": bool(profile.birth_time), "calculation_input": body,
                "source": "https://roxyapi.com/docs/guides/astrology", "raw": result["data"],
                **({"forecast": forecast} if include_forecast else {})}

    @staticmethod
    def chart_view(chart, language):
        known, raw = chart["time_known"], chart["raw"]
        column = LANGUAGE_COLUMNS[language]
        def point(row, name=None):
            name = name or row["name"]
            label = (PLANETS[name][column] if name in PLANETS else
                     REGIONAL_LANGUAGES[language]["reading"]["planets"][point_id(name)] if language in REGIONAL_LANGUAGES else
                     {"zh": "本命上升", "th": "ลัคนา", "en": "Ascendant", "vi": "Cung Mọc"}[language] if name == "Ascendant" else
                     {"zh": "天顶", "th": "จุดยอดฟ้า", "en": "Midheaven", "vi": "Thiên Đỉnh"}[language])
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
        column = LANGUAGE_COLUMNS[language]
        view = cls.chart_view(chart, language)
        facts = {}
        raw_planets = {point_id(row["name"]): row for row in chart["raw"]["planets"]}
        for row in view["planets"]:
            # Noon cannot support a reliable Moon placement, angles, houses or their interpretations.
            if not known and row["id"] == "moon":
                continue
            detail = f"{row['sign_name']} {row['degree']:.2f}°"
            if known and row["house"]:
                detail += " · " + house_label(row['house'], language)
            if not known:
                detail += (" (" + REGIONAL_LANGUAGES[language]["estimated"] + ")" if language in REGIONAL_LANGUAGES else
                           {"zh": "（当地12:00估算）", "th": " (ประมาณเวลา 12:00 ท้องถิ่น)", "en": " (estimated at local 12:00)", "vi": " (ước tính 12:00 địa phương)"}[language])
            fact = {"type": "planet", "key": row["id"], "sign": row["sign_index"], "longitude": row["longitude"],
                    "house": row["house"], "title": row["label"], "detail": detail, "provider": "roxy"}
            source = raw_planets.get(row["id"], {})
            if source:
                fact["retrograde"] = source["isRetrograde"]
                if source["isRetrograde"]:
                    fact["detail"] += (" · " + REGIONAL_LANGUAGES[language]["retrograde"] if language in REGIONAL_LANGUAGES else
                                       {"zh": " · 逆行", "th": " · ถอยหลัง", "en": " · Retrograde", "vi": " · Nghịch hành"}[language])
                if source.get("dignity") in ("domicile", "exaltation", "detriment", "fall", "peregrine"):
                    fact["dignity"] = source["dignity"]
            interpretation = source.get("interpretation", {})
            if known and isinstance(interpretation, dict):
                fact["interpretation"] = {key: interpretation[key][:1600] for key in ("summary", "detailed") if isinstance(interpretation.get(key), str)}
            facts["P_" + row["id"]] = fact
        for row in chart["raw"]["houses"] if known else []:
            facts[f"H{row['number']}"] = {"type": "house", "number": row["number"], "longitude": row["longitude"],
                "title": house_label(row['number'], language),
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
        forecast = chart.get("forecast", {})
        timing_ids = []
        if known and forecast.get("state") == "ready":
            start, end = date.fromisoformat(forecast["start"]), date.fromisoformat(forecast["end"])
            candidates = [event for event in forecast["events"] if point_id(event["target"]) in TOPIC_PLANETS[topic]]
            if topic == "overview":
                candidates.sort(key=lambda event: (event["date"], -event["significance"]))
            weeks = set()
            for event in candidates:
                day = date.fromisoformat(event["date"])
                first = start + timedelta(days=((day - start).days // 7) * 7)
                if first in weeks:
                    continue
                weeks.add(first)
                aspect = event["aspect"].upper()
                identifier = "T_" + hashlib.sha256(
                    f"{event['datetime']}|{event['body']}|{event['target']}|{aspect}".encode()).hexdigest()[:12]
                facts[identifier] = {"type": "transit", "provider": "roxy", "start": first.isoformat(),
                    "end": min(first + timedelta(days=6), end).isoformat(), "timezone": "UTC",
                    "event_date": event["date"], "datetime": event["datetime"],
                    "planet": point_id(event["body"]), "target": point_id(event["target"]),
                    "aspect": aspect, "orb": event["orb"],
                    "title": f"{event['date']} · {PLANETS[event['body']][column]} · {PLANETS[event['target']][column]}",
                    "detail": f"{ASPECTS[aspect][column]} · {event['orb']:.2f}° · UTC",
                    "interpretation": event["description"]}
                timing_ids.append(identifier)
                if len(timing_ids) == (1 if topic == "overview" else 2):
                    break
            selected.extend(timing_ids)
        # Keep the writer's context small and domain-specific, while retaining actual supporting positions.
        facts = {key: fact for key, fact in facts.items() if key in selected or fact["type"] == "planet"}
        return {"format": VERSION, "domain": "astrology", "stage": "chapter", "reading": reading, "language": language,
                "method": {"name": "Western tropical astrology", "provider": "RoxyAPI", "api_version": "v2", "house_system": "placidus", "node_type": "true"},
                "evidence": facts, "topic_evidence": selected,
                "citation_rules": {"topic_ids": selected,
                    "timing_ids": timing_ids,
                    "supporting_natal_ids": [key for key, fact in facts.items() if fact["type"] == "planet"],
                    "trait_ids": {key: ["P_" + item for item in values] for key, values in TRAIT_PLANETS.items()}},
                "birth_time_basis": {"mode": "exact" if known else "estimated", "assumed_local_time": None if known else "12:00",
                                     "excluded": [] if known else ["ascendant", "midheaven", "houses", "moon", "aspects", "timing_predictions"]},
                "scope": SCOPES.get(reading, "personality, decision style and relationship needs"),
                "forecast": {key: forecast[key] for key in ("state", "start", "end", "timezone") if key in forecast},
                "translation_fields": {}, "fixed_translations": {}}

    @staticmethod
    def personal_events(chart):
        if not chart.get("time_known") or chart.get("forecast", {}).get("state") != "ready":
            return []
        candidates = [event for event in chart["forecast"]["events"]
                      if event.get("type") == "transit-aspect" and event.get("aspect", "").upper() in ("TRINE", "SEXTILE")
                      and finite_number(event.get("orb")) and 0 <= event["orb"] <= 6
                      and event.get("body") in FORECAST_REPORT_PLANETS and event.get("target") in FORECAST_REPORT_PLANETS
                      and ({event["body"], event["target"]} & {"Sun", "Mercury", "Venus", "Jupiter"})]
        chosen = {}
        for event in sorted(candidates, key=lambda item: (item["date"], -item["significance"], item["datetime"], item["body"], item["target"])):
            chosen.setdefault(event["date"][:7], event)
        return [chosen[month] for month in sorted(chosen)[:3]]

    @classmethod
    def personal_bundle(cls, body, chart, *, full=False):
        bundle = cls.bundle(body, chart, "natal")
        language, known = body.profile.language, chart["time_known"]
        facts = {key: value for key, value in bundle["evidence"].items() if value["type"] != "transit"}
        signs = {}
        for name, identifier, point in (("sun", "P_sun", next(row for row in chart["raw"]["planets"] if row["name"] == "Sun")),
                                        ("ascendant", "P_ascendant", chart["raw"]["ascendant"] if known else None)):
            signs[name] = ({"evidence_id": identifier, "sign": point["sign"],
                            "label": SIGN_LABELS[language][SIGNS.index(point["sign"])]} if point else None)
        months = []
        if full:
            for event in cls.personal_events(chart):
                aspect = event["aspect"].upper()
                identifier = "T_" + hashlib.sha256(f"{event['datetime']}|{event['body']}|{event['target']}|{aspect}".encode()).hexdigest()[:12]
                facts[identifier] = {"type": "transit", "provider": "roxy", "start": event["date"], "end": event["date"],
                    "event_date": event["date"], "datetime": event["datetime"], "timezone": "UTC",
                    "planet": point_id(event["body"]), "target": point_id(event["target"]), "aspect": aspect, "orb": event["orb"],
                    "title": f"{event['date']} · {PLANETS[event['body']][LANGUAGE_COLUMNS[language]]} · {PLANETS[event['target']][LANGUAGE_COLUMNS[language]]}",
                    "detail": f"{ASPECTS[aspect][LANGUAGE_COLUMNS[language]]} · {event['orb']:.2f}° · UTC", "interpretation": event["description"]}
                months.append({"month": event["date"][:7], "transit_id": identifier,
                               "supporting_natal_ids": ["P_" + point_id(event["target"])]})
        bundle.update(stage="personal_full" if full else "personal_preview", reading="personal-full" if full else "personal-preview",
                      evidence=facts, personal_signs=signs, forecast={"state": chart.get("forecast", {}).get("state", "unavailable")})
        bundle["topic_evidence"] = [key for key in bundle["topic_evidence"] if key in facts]
        bundle["citation_rules"].update(topic_ids=bundle["topic_evidence"], timing_ids=[item["transit_id"] for item in months], months=months)
        return bundle

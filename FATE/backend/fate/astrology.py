import logging
import math
from datetime import UTC, date, datetime, time
from zoneinfo import ZoneInfo

import httpx

from .config import settings
from .locations import Place

log = logging.getLogger(__name__)
ENGINE = "roxy-western-tropical-whole-sign-v1"
PLANETS = {
    "Sun": "อาทิตย์", "Moon": "จันทร์", "Mercury": "พุธ", "Venus": "ศุกร์", "Mars": "อังคาร",
    "Jupiter": "พฤหัสบดี", "Saturn": "เสาร์", "Uranus": "ยูเรนัส", "Neptune": "เนปจูน", "Pluto": "พลูโต",
}
SIGNS = {
    "Aries": ("เมษ", "เริ่มต้นและตัดสินใจด้วยตัวเอง", "เลือกสิ่งเล็ก ๆ ที่ลงมือทำได้ทันที"),
    "Taurus": ("พฤษภ", "ค่อย ๆ สร้างความมั่นคง", "ให้เวลากับกิจวัตรที่ทำให้รู้สึกมั่นคง"),
    "Gemini": ("เมถุน", "เรียนรู้ผ่านคำถามและการสนทนา", "ลองจดคำถามหนึ่งข้อก่อนเริ่มวัน"),
    "Cancer": ("กรกฎ", "สร้างความผูกพันและดูแลสิ่งที่สำคัญ", "พักในที่ที่สบายใจแล้วคุยกับคนที่ไว้ใจ"),
    "Leo": ("สิงห์", "แสดงออกและสร้างสรรค์ในแบบของตัวเอง", "แบ่งเวลาให้สิ่งที่อยากทำเพื่อความสนุก"),
    "Virgo": ("กันย์", "สังเกตรายละเอียดและปรับให้ดีขึ้น", "เลือกแก้เพียงเรื่องเดียวก่อน"),
    "Libra": ("ตุล", "หาความสมดุลระหว่างความต้องการของแต่ละฝ่าย", "บอกความต้องการของตัวเองให้ชัดหนึ่งเรื่อง"),
    "Scorpio": ("พิจิก", "มองลึกถึงเหตุผลและความรู้สึก", "ให้เวลาตัวเองทบทวนก่อนตอบเรื่องสำคัญ"),
    "Sagittarius": ("ธนู", "เปิดรับประสบการณ์และมองภาพกว้าง", "ลองเรียนรู้สิ่งใหม่ในขนาดที่จัดการได้"),
    "Capricorn": ("มังกร", "จัดลำดับเป้าหมายและรับผิดชอบงานที่เลือก", "แบ่งเป้าหมายให้เหลือขั้นแรกที่ทำได้วันนี้"),
    "Aquarius": ("กุมภ์", "คิดจากมุมใหม่และให้พื้นที่กับความแตกต่าง", "ลองฟังมุมมองที่ต่างจากของตัวเอง"),
    "Pisces": ("มีน", "รับรู้บรรยากาศและใช้จินตนาการ", "จัดเวลาสั้น ๆ ให้กับการพักหรือสร้างสรรค์"),
}
TOPICS = {
    "Sun": ("ตัวตนและแรงขับ", "ลองใช้มุมมองเรื่องการ"),
    "Moon": ("อารมณ์และการพักใจ", "เมื่อต้องการดูแลใจ ลองให้พื้นที่กับการ"),
    "Mercury": ("การคิดและการสื่อสาร", "เวลาคิดหรือคุยเรื่องสำคัญ ลองใช้แนวทางการ"),
    "Venus": ("ความสัมพันธ์และสิ่งที่ให้คุณค่า", "เมื่อต้องทบทวนความสัมพันธ์ ลองสังเกตความสำคัญของการ"),
    "Mars": ("พลังและการลงมือ", "เมื่อต้องตัดสินใจลงมือ ลองเริ่มจากการ"),
}
MAJOR_ASPECTS = {"conjunction": "ร่วม", "opposition": "เล็ง", "trine": "ตรีโกณ", "square": "ฉาก", "sextile": "โยค"}


class ChartError(Exception):
    def __init__(self, code: str, retryable: bool = False):
        super().__init__(code)
        self.code = code
        self.retryable = retryable


def local_offsets(day: date, clock: time, place: Place) -> list[float]:
    local = datetime.combine(day, clock)
    zone = ZoneInfo(place.timezone)
    candidates = {}
    for fold in (0, 1):
        aware = local.replace(tzinfo=zone, fold=fold)
        utc = aware.astimezone(UTC)
        if utc.astimezone(zone).replace(tzinfo=None) == local:
            candidates[utc] = aware.utcoffset().total_seconds() / 3600
    return [candidates[utc] for utc in sorted(candidates)]


def birth_offset(day: date, clock: time, place: Place) -> float:
    offsets = local_offsets(day, clock, place)
    if len(offsets) != 1:
        raise ChartError("ambiguous_local_time")
    return offsets[0]


def day_boundary(day: date, place: Place, end: bool) -> tuple[time, float]:
    # Some zones move their clocks at midnight, so use the first or last valid local minute.
    for minute in (range(1439, -1, -1) if end else range(1440)):
        clock = time(minute // 60, minute % 60, 59 if end else 0)
        offsets = local_offsets(day, clock, place)
        if offsets:
            return clock, offsets[-1] if end else offsets[0]
    raise ChartError("ambiguous_local_time")


def request_chart(client: httpx.Client, day: date, clock: time, place: Place, offset: float) -> dict:
    payload = {
        "date": day.isoformat(), "time": clock.isoformat(timespec="seconds"),
        "latitude": place.latitude, "longitude": place.longitude,
        "timezone": offset, "houseSystem": "whole-sign",
    }
    try:
        reply = client.post(settings.roxy_base_url + "/natal-chart", json=payload)
    except httpx.RequestError:
        raise ChartError("calculation_unavailable", retryable=True) from None
    if reply.status_code >= 400:
        log.warning("Roxy returned HTTP %s", reply.status_code)
        raise ChartError("calculation_unavailable", retryable=reply.status_code == 429 or reply.status_code >= 500)
    try:
        return reply.json()
    except ValueError:
        raise ChartError("invalid_calculation") from None


def longitude(value: object) -> float:
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 360:
        raise ValueError("invalid longitude")
    return value % 360


def read_planets(raw: dict) -> dict[str, dict]:
    planets = {planet["name"]: planet for planet in raw["planets"] if planet["name"] in PLANETS}
    if set(planets) != set(PLANETS) or any(planet["sign"] not in SIGNS for planet in planets.values()):
        raise ValueError("incomplete planets")
    return planets


def normalized_body(name: str, raw: dict, exact: bool) -> dict:
    sign = raw["sign"]
    position = longitude(raw["longitude"]) if exact else None
    house = raw["house"] if exact and name != "Ascendant" else None
    if house is not None and (type(house) not in (int, float) or house not in range(1, 13)):
        raise ValueError("invalid house")
    return {
        "id": name, "label": PLANETS.get(name, "ลัคนา"), "sign": sign,
        "sign_name": SIGNS[sign][0], "longitude": position,
        "degree": round(position % 30, 2) if position is not None else None,
        "house": int(house) if house is not None else None,
    }


def short_reading(bodies: list[dict]) -> list[dict]:
    cards = []
    for planet in bodies:
        if planet["id"] not in TOPICS:
            continue
        title, intro = TOPICS[planet["id"]]
        _, theme, action = SIGNS[planet["sign"]]
        basis = planet["label"] + "ในราศี" + planet["sign_name"]
        if planet["house"] is not None:
            basis += " · เรือน " + str(int(planet["house"]))
        cards.append({"id": planet["id"], "title": title, "basis": basis, "text": intro + theme + " วันนี้" + action})
    return cards


def calculate(inputs: dict) -> dict:
    place = Place.model_validate(inputs["place"])
    day = date.fromisoformat(inputs["birth_date"])
    exact = inputs["birth_time"] is not None
    if exact:
        clock = time.fromisoformat(inputs["birth_time"])
        offset = birth_offset(day, clock, place)
        last = None
    else:
        clock, offset = day_boundary(day, place, end=False)
        last = day_boundary(day, place, end=True)
    with httpx.Client(timeout=httpx.Timeout(12, connect=4), headers={"X-API-Key": settings.roxy_api_key}) as client:
        raw = request_chart(client, day, clock, place, offset)
        end = request_chart(client, day, last[0], place, last[1]) if last else None

    try:
        start_planets = read_planets(raw)
        if exact:
            bodies = [normalized_body(name, start_planets[name], True) for name in PLANETS]
            bodies.append(normalized_body("Ascendant", raw["ascendant"], True))
            houses = [{"number": int(house["number"]), "longitude": longitude(house["longitude"])}
                      for house in raw["houses"]]
            if len(houses) != 12 or {house["number"] for house in houses} != set(range(1, 13)):
                raise ValueError("incomplete houses")
            aspects = [{"from": aspect["planet1"], "to": aspect["planet2"],
                        "type": aspect["type"].lower(), "label": MAJOR_ASPECTS[aspect["type"].lower()]}
                       for aspect in raw["aspects"]
                       if aspect["type"].lower() in MAJOR_ASPECTS
                       and aspect["planet1"] in PLANETS and aspect["planet2"] in PLANETS]
        else:
            end_planets = read_planets(end)
            # Date-only results show only solar/lunar signs that agree at both ends of the local day.
            bodies = [normalized_body(name, start_planets[name], False) for name in ("Sun", "Moon")
                      if start_planets[name]["sign"] == end_planets[name]["sign"]]
            houses, aspects = [], []
    except (ValueError, TypeError, KeyError, AttributeError, OverflowError):
        raise ChartError("invalid_calculation") from None

    return {
        "precision": "exact" if exact else "date_only", "engine": ENGINE,
        "place": place.name_th, "planets": bodies, "houses": houses,
        "aspects": aspects, "reading": short_reading(bodies),
    }

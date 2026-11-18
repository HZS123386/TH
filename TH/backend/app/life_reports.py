"""Persisted life-report snapshots, access, and generation."""
import asyncio
from contextlib import asynccontextmanager
from copy import deepcopy
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone
import hashlib
import json
import logging
import secrets
import time
from typing import Annotated, Literal
from urllib.parse import parse_qs
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Header, HTTPException, Request
from fastapi.responses import JSONResponse, PlainTextResponse, Response
from pydantic import Field, model_validator

from . import thai
from .astrology import CHAPTERS as WESTERN_CHAPTERS, FORECAST_VERSION, QUESTIONS as WESTERN_QUESTIONS, TITLES as WESTERN_TITLES, VERSION as WESTERN_VERSION, RoxyAstrology, western
from .bazi_reports import report_progress_context, report_usage_context
from .life_card_payments import CARD_AMOUNT, SIMULATED_AMOUNT, SIMULATED_MERCHANT, SUNLANDS_AMOUNT, LifeCardPayments
from .life_report_content import (
    CAREER_COPY, CAREER_VERSION, CHAPTERS, FORTUNE_CHAPTERS, FORTUNE_TOPICS, FORTUNE_VERSION,
    PERSONAL_LOVE_FIELDS, PERSONAL_WRITING_VERSION, QUESTIONS, RELATIONSHIP_COPY, RELATIONSHIP_KEYS,
    RELATIONSHIP_WRITING_VERSION, TITLES, TRAIT_HOUSES, VERSION, WESTERN_WRITING_VERSION,
    LifeWriter, career_report_content, personal_writing_progress,
    preview_writing_progress, writing_progress,
)
from .schemas import Input, ProfileInput, ThaiReadingInput
from .report_languages import REGIONAL_LANGUAGES
from .thai_readings import HOUSES, copy_for, grounding

logger = logging.getLogger(__name__)
PERSONAL_CATALOG = {
    "zh": ("天赋与发展方向", "机会节点一", "机会节点二", "机会节点三"),
    "th": ("พรสวรรค์และแนวทางพัฒนา", "จังหวะโอกาสที่หนึ่ง", "จังหวะโอกาสที่สอง", "จังหวะโอกาสที่สาม"),
    "en": ("Talents and directions", "Opportunity one", "Opportunity two", "Opportunity three"),
    "vi": ("Năng khiếu và hướng phát triển", "Cơ hội thứ nhất", "Cơ hội thứ hai", "Cơ hội thứ ba"),
    "my": ("စွမ်းရည်နှင့် ဖွံ့ဖြိုးရေးလမ်းကြောင်း", "အခွင့်အလမ်းတစ်", "အခွင့်အလမ်းနှစ်", "အခွင့်အလမ်းသုံး"),
    "km": ("ទេពកោសល្យ និងទិសដៅអភិវឌ្ឍ", "ឱកាសទីមួយ", "ឱកាសទីពីរ", "ឱកាសទីបី"),
    "lo": ("ພອນສະຫວັນ ແລະແນວທາງພັດທະນາ", "ໂອກາດທີໜຶ່ງ", "ໂອກາດທີສອງ", "ໂອກາດທີສາມ"),
    "ms": ("Bakat dan arah perkembangan", "Peluang pertama", "Peluang kedua", "Peluang ketiga"),
    "id": ("Bakat dan arah pengembangan", "Peluang pertama", "Peluang kedua", "Peluang ketiga"),
}
PERSONAL_ACTION_TITLES = {"zh": "行动建议", "th": "คำแนะนำที่นำไปใช้ได้", "en": "Actionable advice",
    "vi": "Gợi ý hành động", "my": "လက်တွေ့လုပ်ဆောင်ရန် အကြံပြုချက်များ", "km": "ការណែនាំសម្រាប់អនុវត្ត",
    "lo": "ຄຳແນະນຳທີ່ນຳໄປໃຊ້ໄດ້", "ms": "Cadangan tindakan", "id": "Saran tindakan"}


def personal_chart(chart):
    return western(chart) and chart.get("presentation") in ("western-personal", "western-relationship")


def relationship_chart(chart):
    return chart.get("presentation") == "western-relationship"


class ReportLeaseLost(Exception):
    pass


class CareerInput(Input):
    stage: Literal["unspecified", "considering", "searching", "offer"]
    start: date
    focus: Literal["decision", "stay", "move", "next"] | None = None

    @model_validator(mode="after")
    def supported_start(self):
        if not date(1901, 1, 1) <= self.start <= datetime.now(ZoneInfo("Asia/Bangkok")).date():
            raise ValueError("career_start_invalid")
        return self


class LifeProfile(ProfileInput):
    language: Literal["zh", "th", "en", "vi", "my", "km", "lo", "ms", "id"] = "zh"


class RelationshipInput(Input):
    status: Literal["unspecified", "single", "dating", "partnered", "separated", "other"] = "unspecified"
    roles: str | None = Field(default=None, min_length=1, max_length=120, pattern=r"^[^\x00-\x1f\x7f]+$")
    event: str | None = Field(default=None, min_length=1, max_length=900, pattern=r"^[^\x00-\x08\x0b\x0c\x0e-\x1f\x7f]+$")
    source: Literal["unspecified", "direct", "told", "reported", "guess"] = "unspecified"


class LifeInput(Input):
    profile: LifeProfile
    year: int = Field(ge=1901, le=2100)
    report_kind: Literal["life", "fortune"] = "life"
    career: CareerInput | None = None
    career_question: CareerInput | None = None
    user_question: str | None = Field(default=None, min_length=1, max_length=120, pattern=r"^[^\x00-\x1f\x7f]+$")
    relationship: RelationshipInput | None = None

    @model_validator(mode="after")
    def supported_input(self):
        # The separate legacy transit-decision flow retains its original languages.
        if (self.career or self.career_question) and self.profile.language not in ("zh", "th"):
            raise ValueError("language_invalid")
        if sum(value is not None for value in (self.career, self.career_question, self.user_question)) > 1:
            raise ValueError("career_input_conflict")
        if (self.career and self.report_kind == "fortune") or (self.relationship and (self.career or self.career_question)):
            raise ValueError("career_input_conflict")
        career = self.career_question or self.career
        if career and career.start.year != self.year:
            raise ValueError("career_year_mismatch")
        return self


class Feedback(Input):
    rating: Literal["close", "partly", "different"]


class SimulatedPayment(Input):
    reference: str = Field(pattern=r"^[0-9]{12}$")


class PaymentContact(Input):
    mobile: str = Field(default="", max_length=32)
    nationCode: str = Field(default="", max_length=4)


def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def stamp(value):
    return datetime.fromtimestamp(value, timezone.utc).isoformat()


def explain(identifier, fact, language):
    if fact.get("provider") == "roxy":
        return {"id": identifier, "title": fact["title"], "detail": fact["detail"]}
    labels = copy_for(language)
    planets = labels["planets"]
    def planet(key):
        return planets.get(key, key)
    def sign(index):
        return labels["signs"][index % 12]
    zh = language == "zh"
    if language in REGIONAL_LANGUAGES:
        copy = REGIONAL_LANGUAGES[language]
        def house(number):
            return copy["house"].replace("{number}", str(number))
        if fact["type"] == "house":
            title = house(fact["number"])
            detail = " · ".join([sign(fact["sign"]), planet(fact["ruler"]), house(fact["ruler_house"]), *(planet(key) for key in fact["occupants"])])
        elif fact["type"] == "planet":
            title, detail = planet(fact["key"]), f"{sign(fact['sign'])} · {house(fact['house'])}"
        elif fact["type"] == "ascendant":
            title, detail = planet("ascendant"), sign(fact["sign"])
        else:
            key, states = next(iter(fact["states"].items()))
            title = f"{fact['month']}/{fact['year']} · {planet(key)}"
            detail = "; ".join(f"{sign(row['sign'])} · {house(row['house'])}" for row in states)
        if fact.get("time_estimated"):
            detail += " (" + copy["estimated"] + ")"
        return {"id": identifier, "title": title, "detail": detail}
    if language in ("en", "vi"):
        def house(number):
            return f"House {number}" if language == "en" else f"Nhà {number}"
        if fact["type"] == "house":
            title = house(fact["number"])
            occupants = ", ".join(planet(key) for key in fact["occupants"])
            empty = "No recorded occupants" if language == "en" else "Không ghi nhận hành tinh trong nhà"
            ruler = "Ruler" if language == "en" else "Hành tinh chủ quản"
            detail = f"{sign(fact['sign'])} · {ruler}: {planet(fact['ruler'])} · {house(fact['ruler_house'])} · {occupants or empty}"
        elif fact["type"] == "planet":
            title = planet(fact["key"])
            detail = f"{sign(fact['sign'])} · {house(fact['house'])}"
        elif fact["type"] == "ascendant":
            title = "Ascendant" if language == "en" else "Cung Mọc"
            detail = sign(fact["sign"])
        elif fact["type"] == "career_window":
            period = fact["start"] if fact["start"] == fact["end"] else f"{fact['start']} – {fact['end']}"
            title = f"{period} · {planet(fact['key'])}"
            detail = f"{sign(fact['sign'])} · {house(fact['house'])}"
        else:
            key, states = next(iter(fact["states"].items()))
            title = f"{fact['month']}/{fact['year']} · {planet(key)}"
            detail = "; ".join(f"{sign(row['sign'])} · {house(row['house'])} · {row['samples']} " + ("days" if language == "en" else "ngày") for row in states)
        if fact.get("time_estimated"):
            detail += " (estimated local 12:00)" if language == "en" else " (ước tính 12:00 địa phương)"
        return {"id": identifier, "title": title, "detail": detail}
    if fact["type"] == "house":
        title = f"第{fact['number']}宫" if zh else f"เรือนที่ {fact['number']}"
        occupants = "、".join(planet(key) for key in fact["occupants"]) or ("未记录宫内星体" if zh else "ไม่มีดาวอยู่ในเรือนนี้")
        detail = (f"{sign(fact['sign'])}；宫主星{planet(fact['ruler'])}落第{fact['ruler_house']}宫；{occupants}" if zh
                  else f"{sign(fact['sign'])} ดาวเจ้าเรือน{planet(fact['ruler'])}อยู่เรือนที่ {fact['ruler_house']} ดาวในเรือน {occupants}")
    elif fact["type"] == "planet":
        title = planet(fact["key"])
        detail = f"{sign(fact['sign'])} · 第{fact['house']}宫" if zh else f"{sign(fact['sign'])} · เรือนที่ {fact['house']}"
    elif fact["type"] == "ascendant":
        title = "本命上升" if zh else "ลัคนากำเนิด"
        detail = sign(fact["sign"])
    elif fact["type"] == "career_window":
        period = fact["start"] if fact["start"] == fact["end"] else f"{fact['start']} – {fact['end']}"
        title = f"{period} · {planet(fact['key'])}"
        detail = (f"{sign(fact['sign'])} · 本命第{fact['house']}宫 · 曼谷当地每日正午取样"
                  if zh else f"{sign(fact['sign'])} · เรือนกำเนิดที่ {fact['house']} · คำนวณจากเวลาเที่ยงวันกรุงเทพฯ")
    else:
        key, states = next(iter(fact["states"].items()))
        title = f"{fact['year']}年{fact['month']}月 · {planet(key)}" if zh else f"{fact['month']}/{fact['year']} · {planet(key)}"
        detail = "；".join((f"{sign(row['sign'])}，本命第{row['house']}宫，采样{row['samples']}天" if zh
                           else f"{sign(row['sign'])} เรือนกำเนิดที่ {row['house']} พบ {row['samples']} วัน") for row in states)
    if fact.get("time_estimated"):
        detail += "（出生时间未知，按当地12:00估算）" if zh else " (ไม่ทราบเวลาเกิด ประมาณจากเวลา 12:00 ท้องถิ่น)"
    return {"id": identifier, "title": title, "detail": detail}


def public_point(row, facts, language):
    identifiers = row["evidence_ids"]
    month = next((facts[key] for key in identifiers if facts[key]["type"] == "month"), None)
    transit = next((facts[key] for key in identifiers if facts[key]["type"] == "transit"), None)
    return {**{key: value for key, value in row.items() if key != "evidence_ids"},
            **({"window": {key: transit[key] for key in ("start", "end", "event_date", "timezone")}} if transit else {}),
            "period": {"year": month["year"], "month": month["month"]} if month else None,
            "evidence": [explain(key, facts[key], language) for key in identifiers]}


class LifeReports:
    chapter_concurrency = 3
    lease_seconds = 180
    heartbeat_seconds = 30

    def __init__(self, store, settings, model_slots, calculation_slots):
        self.store, self.calculation_slots = store, calculation_slots
        self.development = settings.app_env == "development"
        self.settings = settings
        if settings.life_astrology_provider not in ("thai", "roxy"):
            raise ValueError("invalid LIFE_ASTROLOGY_PROVIDER")
        # Domain adapters own calculations/evidence; report access and generation remain here.
        self.adapters = {"astrology": RoxyAstrology(settings, store)}
        self.writer = LifeWriter(store, settings, model_slots)
        self.fast_preview_writer = self.writer
        primary = settings.providers.get(settings.fortune_provider)
        if (settings.life_astrology_provider == "roxy" and settings.fortune_provider == "openai"
                and settings.life_preview_openai_model and primary):
            preview_config = replace(
                primary, model=settings.life_preview_openai_model,
                reasoning_effort=settings.life_preview_openai_reasoning_effort or primary.reasoning_effort,
            )
            if preview_config != primary:
                preview_settings = replace(settings, providers={**settings.providers, "openai": preview_config})
                self.fast_preview_writer = LifeWriter(store, preview_settings, model_slots)
        self.parts_writer = LifeWriter(store, settings, model_slots, charge=False, availability=self.writer.availability)
        # Production has four shared model slots; paid work leaves capacity for a free preview.
        self.parts_writer.request_slots = asyncio.Semaphore(self.chapter_concurrency)
        if self.parts_writer.fallback_writer:
            self.parts_writer.fallback_writer.request_slots = self.parts_writer.request_slots
        self.tasks = {}
        self.preview_tasks = {}
        with store.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS life_reports(
                    id TEXT PRIMARY KEY,owner TEXT NOT NULL,fingerprint TEXT NOT NULL,
                    input TEXT NOT NULL,chart TEXT NOT NULL,created REAL NOT NULL,
                    preview TEXT,preview_state TEXT NOT NULL DEFAULT 'pending',
                    chapters TEXT NOT NULL DEFAULT '{}',plan TEXT,unlocked INTEGER NOT NULL DEFAULT 0,
                    full_state TEXT NOT NULL DEFAULT 'not_started',lease TEXT NOT NULL DEFAULT '',
                    lease_until REAL NOT NULL DEFAULT 0,feedback TEXT,
                    UNIQUE(owner,fingerprint)
                );
                CREATE INDEX IF NOT EXISTS life_reports_owner ON life_reports(owner,created);
            """)
            if "generation_progress" not in {row["name"] for row in db.execute("PRAGMA table_info(life_reports)")}:
                db.execute("ALTER TABLE life_reports ADD COLUMN generation_progress TEXT NOT NULL DEFAULT '{}'")
        self.card_payments = LifeCardPayments(store, settings)

    def row(self, report_id, owner):
        with self.store.connect() as db:
            result = db.execute("SELECT * FROM life_reports WHERE id=? AND owner=?", (report_id, owner)).fetchone()
        if not result:
            raise HTTPException(404, "life_report_not_found")
        return dict(result)

    def update(self, report_id, *, expected_lease=None, **values):
        allowed = {"chart", "preview", "preview_state", "chapters", "plan", "unlocked", "full_state", "lease", "lease_until", "feedback", "generation_progress"}
        if not values or not set(values) <= allowed:
            raise ValueError("invalid report update")
        with self.store.connect() as db:
            condition = " AND lease=?" if expected_lease is not None else ""
            cursor = db.execute("UPDATE life_reports SET " + ",".join(f"{key}=?" for key in values) + " WHERE id=?" + condition,
                                [*values.values(), report_id, *([expected_lease] if expected_lease is not None else [])])
            if expected_lease is not None and not cursor.rowcount:
                raise ReportLeaseLost()

    def bundle(self, body, chart, reading, months=None):
        if western(chart):
            return self.adapters["astrology"].bundle(body, chart, reading)
        topic = FORTUNE_TOPICS.get(reading) if body.report_kind == "fortune" else None
        result = grounding(ThaiReadingInput(profile=body.profile, year=body.year, reading="overview" if topic else reading),
                           chart, months or [], houses=topic["houses"] if topic else None)
        result["reading"] = reading
        if body.report_kind == "fortune":
            result["report_kind"] = "fortune"
        if not body.profile.birth_time:
            result["birth_time_basis"] = {"mode": "estimated", "assumed_local_time": "12:00"}
            for fact in result["evidence"].values():
                fact["time_estimated"] = True
        result["citation_rules"] = {
            "topic_ids": result["topic_evidence"],
            "supporting_natal_ids": [key for key, item in result["evidence"].items() if item["type"] in ("planet", "ascendant")],
        }
        if reading == "annual":
            result["citation_rules"]["required_month_groups"] = {"beginning": [1, 2, 3, 4], "middle": [5, 6, 7, 8], "end": [9, 10, 11, 12]}
        return result

    def personal_availability(self, chart):
        if relationship_chart(chart):
            return {"full_report": True, "reason": "ready"}
        reason = ("time_unknown" if not chart.get("time_known") else
                  "not_started" if "forecast" not in chart else
                  "unavailable" if chart.get("forecast", {}).get("state") != "ready" else
                  "insufficient_periods" if len(self.adapters["astrology"].personal_events(chart)) != 3 else "ready")
        return {"full_report": reason in ("not_started", "ready"), "reason": reason}

    def require_personal_full(self, row):
        chart = json.loads(row["chart"])
        if personal_chart(chart):
            availability = self.personal_availability(chart)
            if availability["reason"] != "ready":
                raise HTTPException(422 if availability["reason"] == "time_unknown" else 409,
                                    "life_personal_time_required" if availability["reason"] == "time_unknown" else "life_personal_periods_unavailable")

    async def prepare_personal_full(self, row, owner, network, *, lease=None):
        chart = json.loads(row["chart"])
        if not personal_chart(chart) or relationship_chart(chart):
            return row
        if not chart.get("time_known"):
            self.require_personal_full(row)
        if self.personal_availability(chart)["reason"] != "ready":
            # Paid timing is prepared only on a checkout attempt, never while reading the free report.
            async with self.calculation_slots:
                row = self.row(row["id"], owner)
                chart = json.loads(row["chart"])
                if self.personal_availability(chart)["reason"] != "ready":
                    profile = LifeInput.model_validate_json(row["input"]).profile
                    chart["forecast"] = await self.adapters["astrology"].forecast(
                        profile, owner, network, **({"refresh": True} if "forecast" in chart else {}))
                    self.update(row["id"], expected_lease=lease, chart=encoded(chart))
                    row = self.row(row["id"], owner)
        self.require_personal_full(row)
        return row

    def preview_writer_for(self, language):
        languages = self.settings.life_preview_openai_languages
        return self.fast_preview_writer if not languages or language in languages else self.writer

    async def create(self, body, owner, network, *, wait=True):
        profile = body.profile.model_dump(mode="json")
        snapshot = body.model_dump(mode="json", exclude=None if body.career else {"career"})
        if body.report_kind == "life":
            snapshot.pop("report_kind")
        if body.career_question is None:
            snapshot.pop("career_question")
        if body.user_question is None:
            snapshot.pop("user_question")
        if body.relationship is None:
            snapshot.pop("relationship")
        if body.career and body.career.focus is None:
            snapshot["career"].pop("focus")
        use_roxy = self.settings.life_astrology_provider == "roxy" and not body.career
        if body.relationship and not use_roxy:
            raise HTTPException(503, "life_astrology_unavailable")
        # New writing settings create a fresh report; saved report IDs retain their original content.
        writing = RELATIONSHIP_WRITING_VERSION if body.relationship else PERSONAL_WRITING_VERSION
        version = f"{WESTERN_VERSION}:{writing}" if use_roxy else CAREER_VERSION if body.career else FORTUNE_VERSION if body.report_kind == "fortune" else VERSION
        identity = [version, snapshot]
        if use_roxy:
            identity.append(["forecast", FORECAST_VERSION, datetime.now(timezone.utc).date().isoformat()])
        if not body.career:
            writer = self.preview_writer_for(body.profile.language) if use_roxy else self.writer
            config = writer.config
            identity.append([writer.provider, config.base_url if config else None, config.model if config else None,
                             config.reasoning_effort if config else None])
            if writer.fallback_writer:
                fallback = writer.fallback_writer
                config = fallback.config
                identity.append([fallback.provider, config.base_url if config else None, config.model if config else None,
                                 config.reasoning_effort if config else None])
        fingerprint = hashlib.sha256(encoded(identity).encode()).hexdigest()
        with self.store.connect() as db:
            existing = db.execute("SELECT id FROM life_reports WHERE owner=? AND fingerprint=?", (owner, fingerprint)).fetchone()
        if existing:
            row = self.row(existing["id"], owner)
            if row["preview"]:
                return self.public(self.row(row["id"], owner))
        else:
            async with self.calculation_slots:
                # Keep the submitted time unknown; only this report's calculation uses an explicit noon estimate.
                chart = (await self.adapters["astrology"].calculate(body.profile, owner, network) if use_roxy else
                         await asyncio.to_thread(thai.natal, {**profile, "birth_time": profile["birth_time"] or "12:00"}))
            if chart["status"] != "ready":
                raise HTTPException(422, "thai_reading_details_required")
            if use_roxy:
                chart["presentation"] = "western-relationship" if body.relationship else "western-personal"
            if not profile["birth_time"] and not use_roxy:
                chart["time_known"] = False
                chart["calculation_input"]["time_precision"] = "estimated-noon"
            report_id = secrets.token_hex(16)
            with self.store.connect() as db:
                db.execute("INSERT OR IGNORE INTO life_reports(id,owner,fingerprint,input,chart,created) VALUES (?,?,?,?,?,?)",
                           (report_id, owner, fingerprint, encoded(snapshot), encoded(chart), time.time()))
                report_id = db.execute("SELECT id FROM life_reports WHERE owner=? AND fingerprint=?", (owner, fingerprint)).fetchone()["id"]
            row = self.row(report_id, owner)
        task = self.preview_tasks.get(row["id"])
        if task is None and not row["preview"]:
            lease = secrets.token_hex(16)
            with self.store.connect() as db:
                claimed = db.execute("UPDATE life_reports SET preview_state='generating',lease=?,lease_until=? "
                                     "WHERE id=? AND preview IS NULL AND lease_until<?",
                                     (lease, time.time() + self.lease_seconds, row["id"], time.time()))
            if claimed.rowcount:
                task = asyncio.create_task(self.generate_preview(row, body, owner, network, lease))
                self.preview_tasks[row["id"]] = task
                task.add_done_callback(lambda finished: self.preview_tasks.pop(row["id"], None))
        if wait and task is not None:
            await asyncio.shield(task)
        return self.get(row["id"], owner)

    async def generate_preview(self, row, body, owner, network, lease):
        heartbeat = asyncio.create_task(self.keep_lease(row["id"], lease))
        usage_token = report_usage_context.set((row["id"], "preview"))
        chart = json.loads(row["chart"])
        four_questions = western(chart)
        def record_preview(raw):
            if personal_chart(chart):
                percent = personal_writing_progress(raw, "personal_preview")
                changes = {key: percent for key in ("preview_summary", "preview_strength", "preview_decisions", "preview_relationships")}
            else:
                changes = preview_writing_progress(raw, body.profile.language, four_questions=four_questions)
            self.record_progress(row["id"], lease, changes)
        progress_token = report_progress_context.set(record_preview)
        try:
            await self.write_preview(row, body, owner, network, lease)
        except ReportLeaseLost:
            pass
        except asyncio.CancelledError:
            self.fail_preview(row["id"], lease)
            raise
        except Exception:
            logger.exception("Life preview generation failed: %s", row["id"])
            self.fail_preview(row["id"], lease)
        finally:
            heartbeat.cancel()
            await asyncio.gather(heartbeat, return_exceptions=True)
            report_progress_context.reset(progress_token)
            report_usage_context.reset(usage_token)

    async def career_preview(self, question, chart, profile, *, direct_question=False):
        async with self.calculation_slots:
            windows = await asyncio.to_thread(thai.career_window, question.start.isoformat(),
                                              chart["chart"]["points"]["ascendant"]["sign"])
        content = career_report_content(question.stage, windows, profile.language,
                                        estimated=not profile.birth_time, focus=question.focus, direct_question=direct_question)
        return {**content, "windows": windows}

    async def write_preview(self, row, body, owner, network, lease):
        chart = json.loads(row["chart"])
        if body.career:
            preview = await self.career_preview(body.career, chart, body.profile)
            # Save calculated windows with the preview so a later unlock uses the same dates.
            self.update(row["id"], expected_lease=lease, preview=encoded(preview),
                        preview_state="ready", lease="", lease_until=0)
            return
        if personal_chart(chart):
            bundle = self.adapters["astrology"].personal_bundle(body, chart)
            if body.user_question:
                bundle["user_question"] = body.user_question
            if relationship_chart(chart):
                bundle["relationship_context"] = body.relationship.model_dump(mode="json")
                bundle["relationship_aspect_label"] = ""
            generated = await self.preview_writer_for(body.profile.language).generate(bundle, owner, network)
            values = {"preview_state": generated["state"], "lease": "", "lease_until": 0}
            if generated["state"] == "ready" and generated.get("story"):
                values["preview"] = encoded({"presentation": chart["presentation"],
                                             "version": RELATIONSHIP_WRITING_VERSION if relationship_chart(chart) else PERSONAL_WRITING_VERSION,
                                             "story": generated["story"], "evidence": bundle["evidence"],
                                             "relationship_aspect_label": bundle["relationship_aspect_label"]})
            elif generated["state"] == "ready":
                values["preview_state"] = "unavailable"
            self.update(row["id"], expected_lease=lease, **values)
            return
        if western(chart) and "forecast" not in chart:
            chart["forecast"] = await self.adapters["astrology"].forecast(body.profile, owner, network)
            self.update(row["id"], expected_lease=lease, chart=encoded(chart))
        bundle = self.bundle(body, chart, "overview")
        if western(chart):
            sample = self.bundle(body, chart, "career")
            timing = sample["citation_rules"]["timing_ids"][:1]
            bundle["evidence"] = {key: fact for key, fact in {**bundle["evidence"], **sample["evidence"]}.items()
                                  if fact["type"] != "transit" or key in timing}
            # Share the career factors and one paid calculation window with the free excerpt.
            # Keep other career windows out of the free writer's context entirely.
            bundle["evidence"] = {key: fact for key, fact in bundle["evidence"].items() if fact["type"] != "transit"}
            bundle["evidence"].update({key: fact for key, fact in sample["evidence"].items() if fact["type"] != "transit" or key in timing})
            identifiers = list(dict.fromkeys([*bundle["topic_evidence"], *sample["topic_evidence"]]))
            bundle["topic_evidence"] = [key for key in identifiers if key in bundle["evidence"]]
            bundle["citation_rules"].update(topic_ids=bundle["topic_evidence"], timing_ids=timing,
                sample_ids=[key for key in sample["topic_evidence"] if key in bundle["evidence"] and bundle["evidence"][key]["type"] != "transit"])
            bundle["preview_topic"] = "career"
        if not western(chart):
            topics = ("love", "work", "money") if body.user_question else ("love",)
            for topic in topics:
                related = self.bundle(body, chart, topic)
                bundle["evidence"].update(related["evidence"])
                bundle["topic_evidence"] = list(dict.fromkeys([*bundle["topic_evidence"], *related["topic_evidence"]]))
            bundle["citation_rules"] = {"trait_house_ids": TRAIT_HOUSES,
                                        "summary_house_ids": bundle["topic_evidence"],
                                        "supporting_natal_ids": [key for key, item in bundle["evidence"].items() if item["type"] in ("planet", "ascendant")]}
        bundle.update(stage="preview", reading="life-preview")
        if western(chart):
            bundle["preview_layout"] = "four-questions"
        if body.user_question:
            bundle["user_question"] = body.user_question
        elif body.career_question and western(chart):
            bundle["user_question"] = {"subject": "career decision", **body.career_question.model_dump(mode="json")}
        result = await self.writer.generate(bundle, owner, network)
        values = {"preview_state": result["state"], "lease": "", "lease_until": 0}
        if result.get("story"):
            preview = {"story": result["story"], "evidence": bundle["evidence"]}
            if bundle.get("preview_topic"):
                preview["sample_topic"] = bundle["preview_topic"]
                preview["free_excerpt_origin"] = {"version": 1, "topic": bundle["preview_topic"]}
            if body.career_question and not western(chart):
                answer = await self.career_preview(body.career_question, chart, body.profile,
                                                   direct_question=body.career_question.focus is None)
                preview["career_answer"] = answer["story"]["summary"]
                preview["evidence"].update(answer["evidence"])
            values["preview"] = encoded(preview)
        self.update(row["id"], expected_lease=lease, **values)

    def record_progress(self, report_id, lease, updates):
        with self.store.connect() as db:
            row = db.execute("SELECT generation_progress FROM life_reports WHERE id=? AND lease=?", (report_id, lease)).fetchone()
            if not row:
                return
            marks = json.loads(row["generation_progress"])
            changes = {key: percent for key, percent in updates.items() if percent > marks.get(key, 0)}
            if not changes:
                return
            marks.update(changes)
            db.execute("UPDATE life_reports SET generation_progress=? WHERE id=? AND lease=?", (encoded(marks), report_id, lease))

    async def write_part(self, report_id, lease, bundle, owner, network):
        key = "personal_full" if bundle["stage"] in ("personal_full", "relationship_full") else "plan" if bundle["stage"] == "plan" else bundle["reading"]
        token = report_progress_context.set(lambda raw: self.record_progress(report_id, lease, {key: writing_progress(raw, bundle["stage"], compact=bundle.get("format") == WESTERN_VERSION)}))
        try:
            result = await self.parts_writer.generate(bundle, owner, network)
            if (result.get("story") and bundle.get("free_excerpt")
                    and bundle.get("format") == WESTERN_VERSION and bundle["stage"] == "chapter" and bundle["reading"] == "career"):
                # Frozen, already grounded preview text is reused even when this stage hits its cache.
                story = deepcopy(result["story"])
                excerpt = bundle["free_excerpt"]
                for source, target in (("favorable", story["insights"][0]), ("unfavorable", story["watchpoints"][0])):
                    target.update(deepcopy(excerpt[source]))
                if excerpt.get("recent"):
                    story["summary"] = deepcopy(excerpt["recent"])
                result = {**result, "story": self.parts_writer.validate(encoded(story), bundle)}
            return result
        finally:
            report_progress_context.reset(token)

    @staticmethod
    def relationship_sections(story, evidence, context, language):
        copy = RELATIONSHIP_COPY[language]
        source = copy["sources"][context["source"]]
        who = [paragraph for person in story["people"] for paragraph in (
            f"{person['role']} · {person['explanation']}", f"{source} · “{person['event_excerpt']}”",
        )]
        if not who:
            portrait = story.get("portrait")
            who = [portrait["text"] if portrait else story["uncertainty"]]
        patterns = []
        for pattern in story["patterns"]:
            identifier = pattern["evidence_id"]
            fact = explain(identifier, evidence[identifier], language)
            patterns.extend([f"{fact['title']} · {fact['detail']}", pattern["symbolism"], pattern["behavior"]])
        return {
            "who": who,
            "impact": [story["impact"]],
            "pattern": patterns,
            "assessment": [story["assessment"]],
            "decision": [story["continue_when"], story["reconsider_when"]],
            "next_steps": [story["verify"], story["question"], story["observe"]],
        }

    def chart_view(self, chart, time_known, language="zh"):
        """Reuse this report's calculated positions for JY's native chart view."""
        if western(chart):
            return self.adapters["astrology"].chart_view(chart, language)
        source = chart.get("chart") or {}
        points = source.get("points") or {}
        return {
            "precision": "exact" if time_known else "estimated",
            "engine": "Thai Suriyayatra", "relationship_model": "sign-based",
            "planets": [{"id": key, "label": point["nameThai"], "sign_index": point["sign"],
                         "sign_name": point["signName"], "longitude": point["longitudeDegrees"],
                         "degree": point["degrees"] + point["minutes"] / 60,
                         "house": point["house"] if time_known else None}
                        for key, point in points.items() if time_known or key != "ascendant"],
            "houses": [{"number": house["number"], "longitude": house["sign"] * 30}
                       for house in source.get("houses", [])] if time_known else [],
            # The local model uses sign relationships, not Western degree-orb aspects.
            "aspects": [],
        }

    def public(self, row):
        body = json.loads(row["input"])
        language = body["profile"]["language"]
        career = body.get("career")
        fortune = body.get("report_kind") == "fortune"
        labels = CAREER_COPY[language] if career else None
        chart = json.loads(row["chart"])
        is_western = western(chart)
        is_personal = personal_chart(chart)
        is_relationship = relationship_chart(chart)
        records = json.loads(row["chapters"])
        preview = json.loads(row["preview"]) if row["preview"] else None
        title = (REGIONAL_LANGUAGES[language]["report_title" if fortune else "life_title"] if language in REGIONAL_LANGUAGES else ({"zh": "运程解析", "th": "วิเคราะห์ดวงชะตา", "en": "Personal reading", "vi": "Luận giải cá nhân"} if fortune else
                 {"zh": "人生报告", "th": "รายงานชีวิต", "en": "Life report", "vi": "Báo cáo cuộc sống"})[language])
        version = chart["version"] if is_western else FORTUNE_VERSION if fortune else VERSION
        if career:
            title = preview["story"].get("title", labels["title"]) if preview else labels["title"]
            version = preview.get("version", "career-decision-1") if preview else CAREER_VERSION
        marks = json.loads(row.get("generation_progress", "{}"))
        preview_sections = [{"key": key, "percent": 100 if preview else min(99, marks.get(key, 0))}
                            for key in ("preview_summary", "preview_strength", "preview_decisions", "preview_relationships")]
        chapter_keys = WESTERN_CHAPTERS if is_western else FORTUNE_CHAPTERS if fortune else CHAPTERS
        parts = {key: 100 if key in records else min(99, marks.get(key, 0)) for key in chapter_keys}
        sections = ([{"key": key, "percent": parts[key]} for key in chapter_keys] + [
            {"key": "plan", "percent": 100 if row["plan"] else min(99, marks.get("plan", 0))},
        ]) if fortune or is_western else [
            {"key": "work", "percent": parts["work"]}, {"key": "money", "percent": parts["money"]},
            {"key": "relationships", "percent": (parts["love"] + parts["family"]) / 2},
            {"key": "annual", "percent": parts["annual"]},
            {"key": "plan", "percent": 100 if row["plan"] else min(99, marks.get("plan", 0))},
        ]
        completed = (sum(key in records for key in chapter_keys) + bool(row["plan"])) if fortune or is_western else (
            sum(key in records for key in ("work", "money", "annual")) + ("love" in records and "family" in records) + bool(row["plan"]))
        if career:
            sections = [{"key": "work", "percent": parts["work"]}]
            completed = int("work" in records)
            chapter_keys = ("work",)
        titles = [labels["chapter"]] if labels else TITLES[language]
        questions = [list(labels["paid_titles"])] if labels else QUESTIONS[language]
        if is_western:
            titles = list(WESTERN_TITLES[language][:5])
            questions = [[question] for question in WESTERN_QUESTIONS[language]]
        elif fortune:
            titles = [FORTUNE_TOPICS[key][language]["title"] for key in chapter_keys]
            titles[0] = (REGIONAL_LANGUAGES[language]["annual_title"].replace("{year}", str(body["year"])) if language in REGIONAL_LANGUAGES else {"zh": f"{body['year']}年运程", "th": f"ดวงปี {body['year']}", "en": f"{body['year']} yearly themes", "vi": f"Chủ đề năm {body['year']}"}[language])
            questions = [FORTUNE_TOPICS[key][language]["questions"] for key in chapter_keys]
        if is_personal:
            saved_personal = records.get("personal", {}).get("story", {})
            # Saved four-part reports remain readable; new writing always supplies all six subjects.
            six_themes = not saved_personal or "themes" in saved_personal
            chapter_keys = (*WESTERN_CHAPTERS, "plan") if six_themes else ("talent", "node-1", "node-2", "node-3")
            titles = (*WESTERN_TITLES[language], PERSONAL_ACTION_TITLES[language]) if six_themes else PERSONAL_CATALOG[language]
            if is_relationship:
                copy = RELATIONSHIP_COPY[language]
                chapter_keys = RELATIONSHIP_KEYS
                titles = [copy["sections"][key] for key in chapter_keys]
                if row["unlocked"] and saved_personal.get("portrait"):
                    titles[0] = copy["portrait"]
                if body["relationship"]["status"] == "single":
                    titles[chapter_keys.index("decision")] = copy["singleDecision"]
                title = copy["title"]
            questions = [[] for _ in chapter_keys]
            ready = row["full_state"] == "ready" and "personal" in records
            completed = len(chapter_keys) if ready else 0
            sections = [{"key": key, "percent": 100 if ready else min(99, marks.get("personal_full", 0))} for key in chapter_keys]
            writing = RELATIONSHIP_WRITING_VERSION if is_relationship else PERSONAL_WRITING_VERSION
            version = preview.get("version", writing) if preview else writing
        percent = int(sum(section["percent"] for section in sections) / len(sections))
        percent = min(percent, 100 if row["full_state"] == "ready" else 99)
        simulation = self.can_simulate_payment(career)
        amount = 9900 if career else CARD_AMOUNT
        if self.card_payments.order_only:
            amount = SUNLANDS_AMOUNT
        if simulation:
            order = self.card_payments.order_for(row["id"]) if preview and not row["unlocked"] else None
            amount = order["amount"] if order and order["merchant"] == SIMULATED_MERCHANT else SIMULATED_AMOUNT
        result = {
            "id": row["id"], "version": version, "title": title,
            "input": body, "created_at": stamp(row["created"]), "location": chart["location"],
            "method": ({"name": "RoxyAPI Western Astrology", "house_system": "placidus", "version": "v2",
                        "zodiac": "tropical", "node_type": "true", "source": chart["source"]} if is_western else
                       {"name": "Thai Suriyayatra", "house_system": "whole-sign", "version": thai.ENGINE_VERSION}),
            "format": "western-personal" if is_personal else "western-compact" if is_western else "legacy",
            "chart": self.chart_view(chart, bool(body["profile"].get("birth_time")), language),
            "time_accuracy": {"mode": "exact" if body["profile"]["birth_time"] else "estimated",
                              "assumed_local_time": None if body["profile"]["birth_time"] else "12:00"},
            "price": {"amount": amount, "currency": "THB", "display": f"฿{amount // 100}",
                      "mode": "sunlands_order_only" if self.card_payments.order_only else
                      "payso_test" if self.card_payments.enabled and not career else "direct"},
            "payment_simulation": simulation,
            "preview_state": row["preview_state"], "access": "full" if row["unlocked"] else "preview",
            "full_state": row["full_state"], "progress": {"completed": completed, "total": len(sections)},
            "generation_progress": {"percent": percent, "sections": sections},
            "preview_generation_progress": {"percent": int(sum(section["percent"] for section in preview_sections) / 4), "sections": preview_sections},
            "feedback": row["feedback"],
            "catalog": [{"key": key, "title": titles[index], "questions": questions[index],
                         "houses": [] if is_western else FORTUNE_TOPICS[key]["houses"] if fortune else list(HOUSES[key]),
                         "ready": bool(row["unlocked"] and row["full_state"] == "ready") if is_personal else key in records} for index, key in enumerate(chapter_keys)],
            "preview": {"summary": public_point(preview["story"]["summary"], preview["evidence"], language),
                        "traits": [public_point(item, preview["evidence"], language) for item in preview["story"]["traits"]]} if preview and not is_personal else None,
            "chapters": [], "plan": None,
        }
        if is_personal:
            signs = self.adapters["astrology"].personal_signs(chart, language)
            record = records.get("personal") if row["unlocked"] else None
            story = record["story"] if record else {}
            relationship = None
            if preview and (love := preview["story"].get("relationship")):
                relationship = {"text": love["text"] + preview.get("relationship_aspect_label", ""),
                                "action": love["action"],
                                "evidence": [explain(key, preview["evidence"][key], language) for key in love["evidence_ids"]]}
            result["outlook"] = {"state": chart.get("forecast", {}).get("state", "not_started" if chart.get("time_known") else "time_unknown")}
            result["personal"] = {"free_lines": preview["story"]["free_lines"] if preview else [],
                "relationship": relationship,
                "traits": preview["story"].get("traits", []) if preview else [],
                "opportunity_action": preview["story"].get("opportunity_action", "") if preview else "",
                "sun_sign": signs["sun"]["label"], "ascendant_sign": signs["ascendant"]["label"] if signs["ascendant"] else None,
                "availability": self.personal_availability(chart),
                "talent": story.get("talent"),
                "themes": {key: {"text": "\n\n".join([item["text"], *(item[field] for field in PERSONAL_LOVE_FIELDS if field in item)]),
                    "evidence": [explain(identifier, record["evidence"][identifier], language) for identifier in item["evidence_ids"]]}
                    for key, item in story["themes"].items()} if "themes" in story else None,
                "nodes": [{**{key: item[key] for key in ("month", "theme", "benefit", "caution", "action")},
                           "evidence": [explain(key, record["evidence"][key], language) for key in item["evidence_ids"]]}
                          for item in story.get("nodes", [])]}
            if is_relationship:
                result["personal"]["relationship_sections"] = (
                    self.relationship_sections(story, record["evidence"], body["relationship"], language)
                    if record and ready else None)
            return result
        if career:
            result["reference_period"] = {"start": career["start"], "end": (date.fromisoformat(career["start"]) + timedelta(days=29)).isoformat()}
        if preview and "career_answer" in preview:
            result["preview"]["career_answer"] = public_point(preview["career_answer"], preview["evidence"], language)
        if is_western:
            forecast = chart.get("forecast", {})
            result["outlook"] = {key: forecast[key] for key in ("state", "start", "end", "timezone") if key in forecast}
            if preview:
                for key in ("environment", "favorable", "unfavorable", "recent", "response"):
                    if preview["story"].get(key):
                        result["preview"][key] = public_point(preview["story"][key], preview["evidence"], language)
                if preview.get("sample_topic"):
                    result["preview"]["sample_topic"] = preview["sample_topic"]
        if row["unlocked"]:
            for index, key in enumerate(chapter_keys):
                if key not in records:
                    continue
                record = records[key]
                story, facts = record["story"], record["evidence"]
                result["chapters"].append({"key": key, "title": titles[index],
                    "summary": public_point(story["summary"], facts, language),
                    **{kind: [public_point(item, facts, language) for item in story[kind]] for kind in ("insights", "watchpoints", "actions")}})
            if row["plan"]:
                plan = json.loads(row["plan"])
                # Resolve stored references from their source records, independently of visible chapter grouping.
                actions = {f"{key}:{index}": {"chapter": key, "index": index, **public_point(action, record["evidence"], language)}
                           for key, record in records.items() for index, action in enumerate(record["story"]["actions"])}
                result["plan"] = {"phases": [{**{key: item[key] for key in ("key", "title", "text")},
                    "actions": [actions[key] for key in item["action_ids"]]} for item in plan["phases"]]}
        return result

    def get(self, report_id, owner):
        row = self.row(report_id, owner)
        if not row["preview"] and row["preview_state"] == "generating" and row["lease_until"] < time.time():
            with self.store.connect() as db:
                db.execute("UPDATE life_reports SET preview_state='unavailable',lease='',lease_until=0 "
                           "WHERE id=? AND lease=? AND preview IS NULL AND preview_state='generating' AND lease_until<?",
                           (report_id, row["lease"], time.time()))
            row = self.row(report_id, owner)
        if row["full_state"] == "generating" and row["lease_until"] < time.time():
            with self.store.connect() as db:
                db.execute("UPDATE life_reports SET full_state='unavailable',lease='',lease_until=0 "
                           "WHERE id=? AND owner=? AND full_state='generating' AND lease_until<?", (report_id, owner, time.time()))
            row = self.row(report_id, owner)
        return self.public(row)

    def list(self, owner):
        with self.store.connect() as db:
            rows = db.execute("SELECT id,input,created,unlocked,full_state FROM life_reports WHERE owner=? ORDER BY created DESC LIMIT 30", (owner,)).fetchall()
        return [{"id": row["id"], "input": json.loads(row["input"]), "created_at": stamp(row["created"]),
                 "access": "full" if row["unlocked"] else "preview", "full_state": row["full_state"]} for row in rows]

    def delete(self, report_id, owner):
        # Verify ownership and generation state inside the same write transaction.
        with self.store.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT * FROM life_reports WHERE id=? AND owner=?", (report_id, owner)).fetchone()
            if row is None:
                raise HTTPException(404, "life_report_not_found")
            payment = db.execute("SELECT merchant FROM life_card_payments WHERE report_id=?", (report_id,)).fetchone()
            if payment and payment["merchant"].startswith("sunlands:"):
                raise HTTPException(409, "life_order_needs_review")
            active_task = any(task is not None and not task.done()
                              for task in (self.preview_tasks.get(report_id), self.tasks.get(report_id)))
            claimed = (row["preview_state"] in ("pending", "generating") or row["full_state"] == "generating")
            if active_task or (claimed and row["lease_until"] > time.time()):
                raise HTTPException(409, "life_report_generating")
            db.execute("DELETE FROM life_card_payments WHERE report_id=?", (report_id,))
            db.execute("DELETE FROM life_reports WHERE id=? AND owner=?", (report_id, owner))

    async def unlock(self, report_id, owner, network):
        row = self.row(report_id, owner)
        if not row["preview"]:
            raise HTTPException(409, "life_preview_required")
        if not row["unlocked"]:
            career = json.loads(row["input"]).get("career")
            if (self.card_payments.order_only or self.can_simulate_payment(career) or self.card_payments.order_for(report_id)
                    or (self.card_payments.enabled and not career)):
                raise HTTPException(402, "life_payment_required")
            await self.prepare_personal_full(row, owner, network)
            self.update(report_id, unlocked=1)
        await self.start_full_generation(report_id, owner, network)
        return self.get(report_id, owner)

    def can_simulate_payment(self, career):
        return not self.card_payments.order_only and self.development and (bool(career) or not self.card_payments.enabled)

    async def create_card_order(self, report_id, owner, network, contact=None):
        row = self.row(report_id, owner)
        body = json.loads(row["input"])
        if row["unlocked"]:
            raise HTTPException(409, "life_payment_unavailable")
        if not row["preview"]:
            raise HTTPException(409, "life_preview_required")
        career = body.get("career")
        if not (self.card_payments.order_only or self.can_simulate_payment(career) or self.card_payments.enabled and not career):
            raise HTTPException(409, "life_payment_unavailable")
        row = await self.prepare_personal_full(row, owner, network)
        if row["unlocked"]:
            raise HTTPException(409, "life_payment_unavailable")
        if self.card_payments.order_only:
            return await self.card_payments.create_sunlands(
                report_id, network, contact.mobile if contact else "", contact.nationCode if contact else "")
        if self.can_simulate_payment(career):
            return self.card_payments.create_simulated(report_id, network)
        return self.card_payments.create(report_id, network, body["profile"]["language"])

    async def simulate_payment(self, report_id, owner, network, reference):
        row = self.row(report_id, owner)
        if not self.can_simulate_payment(json.loads(row["input"]).get("career")):
            raise HTTPException(404, "life_payment_unavailable")
        if not self.card_payments.confirm_simulated(report_id, reference):
            raise HTTPException(409, "life_payment_required")
        await self.start_full_generation(report_id, owner, network)
        return {"paid": True}

    async def confirm_card_order(self, order, owner, notification=None):
        if order and order["merchant"].startswith("sunlands:"):
            paid = await self.card_payments.confirm_sunlands(order, notification)
        else:
            paid = await self.card_payments.confirm(order)
        if not paid:
            return False
        await self.start_full_generation(order["report_id"], owner, order["network"])
        return True

    async def start_full_generation(self, report_id, owner, network):
        row = self.row(report_id, owner)
        if not row["preview"] or not row["unlocked"]:
            return
        if row["full_state"] == "ready" or report_id in self.tasks:
            return
        lease = secrets.token_hex(16)
        with self.store.connect() as db:
            cursor = db.execute("UPDATE life_reports SET full_state='generating',lease=?,lease_until=? "
                                "WHERE id=? AND owner=? AND unlocked=1 AND lease_until<? AND full_state<>'ready'", (lease, time.time() + self.lease_seconds, report_id, owner, time.time()))
        if cursor.rowcount:
            if not json.loads(row["input"]).get("career") and self.writer.enabled and not self.writer.reserve_run(owner, network):
                self.update(report_id, expected_lease=lease, full_state="limited", lease="", lease_until=0)
                return
            task = asyncio.create_task(self.complete(report_id, owner, network, lease))
            self.tasks[report_id] = task
            task.add_done_callback(lambda finished: self.tasks.pop(report_id, None))

    async def complete(self, report_id, owner, network, lease):
        usage_token = report_usage_context.set((report_id, "full"))
        heartbeat = asyncio.create_task(self.keep_lease(report_id, lease))
        try:
            row = self.row(report_id, owner)
            body = LifeInput.model_validate_json(row["input"])
            if body.career:
                chapter = career_report_content(body.career.stage, json.loads(row["preview"])["windows"],
                                                body.profile.language, estimated=not body.profile.birth_time, full=True)
                self.update(report_id, expected_lease=lease, chapters=encoded({"work": chapter}),
                            full_state="ready", lease="", lease_until=0)
                return
            chart, preview_record = json.loads(row["chart"]), json.loads(row["preview"])
            if personal_chart(chart):
                free_story = preview_record["story"]
                if relationship_chart(chart):
                    bundle = self.adapters["astrology"].bundle(body, chart, "love")
                    natal_ids = [key for key in bundle["topic_evidence"] if bundle["evidence"][key]["type"] != "transit"]
                    bundle.update(stage="relationship_full", reading="relationship-full",
                                  relationship_context=body.relationship.model_dump(mode="json"),
                                  evidence={key: bundle["evidence"][key] for key in natal_ids},
                                  citation_rules={"topic_ids": natal_ids})
                    if body.user_question:
                        bundle["user_question"] = body.user_question
                else:
                    row = await self.prepare_personal_full(row, owner, network, lease=lease)
                    chart = json.loads(row["chart"])
                    bundle = self.adapters["astrology"].personal_bundle(body, chart, full=True)
                    bundle["previous_points"] = [*free_story["free_lines"],
                        *(item["text"] for item in free_story.get("traits", [])), free_story.get("opportunity_action", "")]
                    if relationship := free_story.get("relationship"):
                        allowed = bundle["citation_rules"]["themes"]["love"]
                        aspect = next((key for key in relationship.get("evidence_ids", ())
                                       if key in allowed and bundle["evidence"][key]["type"] == "aspect"), None)
                        bundle["relationship_preview"] = {"text": relationship["text"], "action": relationship["action"],
                                                          "natal_aspect_id": aspect}
                    bundle["free_lines"] = free_story["free_lines"]
                generated = await self.write_part(report_id, lease, bundle, owner, network)
                values = {"full_state": generated["state"], "lease": "", "lease_until": 0}
                if generated["state"] == "ready" and generated.get("story"):
                    story = self.parts_writer.validate(encoded(generated["story"]), bundle)
                    values["chapters"] = encoded({"personal": {"story": story, "evidence": bundle["evidence"]}})
                    values["full_state"] = "ready"
                    self.record_progress(report_id, lease, {"personal_full": 100})
                elif generated["state"] == "ready":
                    values["full_state"] = "unavailable"
                self.update(report_id, expected_lease=lease, **values)
                return
            preview = preview_record["story"]
            # Carry the preview's meaning without leaking its citations into another topic.
            preview_context = {"summary": preview["summary"]["text"],
                               "traits": [{key: item[key] for key in ("key", "title", "text")} for item in preview["traits"]]}
            preview_context.update({key: preview[key]["text"] for key in ("environment", "favorable", "unfavorable", "recent", "response") if preview.get(key)})
            records = json.loads(row["chapters"])
            chapter_keys = WESTERN_CHAPTERS if western(chart) else FORTUNE_CHAPTERS if body.report_kind == "fortune" else CHAPTERS
            slots = asyncio.Semaphore(self.chapter_concurrency)

            async def chapter(reading):
                async with slots:
                    self.update(report_id, expected_lease=lease, lease_until=time.time() + self.lease_seconds)
                    months = []
                    if reading == "annual":
                        async with self.calculation_slots:
                            months = await asyncio.to_thread(thai.annual, body.year, chart["chart"]["points"]["ascendant"]["sign"])
                    bundle = self.bundle(body, chart, reading, months)
                    previous = [text for key, record in records.items() if key in chapter_keys for kind in ("insights", "watchpoints", "actions")
                                for point in record["story"][kind] for text in (point["title"], point["text"])]
                    bundle.update(stage="chapter", preview=preview_context, previous_points=previous)
                    if (western(chart) and reading == "career"
                            and preview_record.get("free_excerpt_origin") == {"version": 1, "topic": "career"}):
                        bundle["free_excerpt"] = {
                            key: {field: deepcopy(preview[key][field]) for field in ("text", "evidence_ids")}
                            if preview.get(key) else None
                            for key in ("favorable", "unfavorable", "recent")
                        }
                    generated = await self.write_part(report_id, lease, bundle, owner, network)
                    if generated.get("story"):
                        # No await between merging and saving, so concurrent completions cannot overwrite each other.
                        records[reading] = {"story": generated["story"], "evidence": bundle["evidence"]}
                        self.update(report_id, expected_lease=lease, chapters=encoded(records), lease_until=time.time() + self.lease_seconds)
                        self.record_progress(report_id, lease, {reading: 100})
                    return generated["state"]

            # Independent topics share the preview; a failed topic does not discard or block its siblings.
            async with asyncio.TaskGroup() as group:
                jobs = [group.create_task(chapter(reading)) for reading in chapter_keys if reading not in records]
            failures = [job.result() for job in jobs if job.result() != "ready"]
            if failures:
                self.update(report_id, expected_lease=lease, full_state=failures[0], lease="", lease_until=0)
                return
            # The editor selects existing actions from concise excerpts; full details stay in the snapshot.
            actions = {f"{reading}:{index}": {"title": item["title"], "text": item["text"], "first_step": item["steps"][0], "check": item["check"]}
                       for reading in chapter_keys for index, item in enumerate(records[reading]["story"]["actions"])}
            bundle = {"stage": "plan", "reading": "life-plan", "language": body.profile.language, "preview": preview_context,
                      "source_actions": actions, "translation_fields": {}, "fixed_translations": {}}
            if western(chart):
                bundle["format"] = WESTERN_VERSION
            if not body.profile.birth_time:
                bundle["birth_time_basis"] = {"mode": "estimated", "assumed_local_time": "12:00"}
            generated = await self.write_part(report_id, lease, bundle, owner, network)
            if generated.get("story"):
                self.update(report_id, expected_lease=lease, plan=encoded(generated["story"]), full_state="ready", lease="", lease_until=0)
            else:
                self.update(report_id, expected_lease=lease, full_state=generated["state"], lease="", lease_until=0)
        except ReportLeaseLost:
            return
        except asyncio.CancelledError:
            self.fail_lease(report_id, lease)
            raise
        except Exception:
            logger.exception("Life report generation failed: %s", report_id)
            self.fail_lease(report_id, lease)
        finally:
            heartbeat.cancel()
            await asyncio.gather(heartbeat, return_exceptions=True)
            report_usage_context.reset(usage_token)

    async def keep_lease(self, report_id, lease):
        while True:
            await asyncio.sleep(self.heartbeat_seconds)
            try:
                self.update(report_id, expected_lease=lease, lease_until=time.time() + self.lease_seconds)
            except ReportLeaseLost:
                return

    def fail_lease(self, report_id, lease):
        with self.store.connect() as db:
            db.execute("UPDATE life_reports SET full_state='unavailable',lease='',lease_until=0 WHERE id=? AND lease=?", (report_id, lease))

    def fail_preview(self, report_id, lease):
        with self.store.connect() as db:
            db.execute("UPDATE life_reports SET preview_state='unavailable',lease='',lease_until=0 WHERE id=? AND lease=? AND preview IS NULL", (report_id, lease))

    async def close(self):
        tasks = [*self.tasks.values(), *self.preview_tasks.values()]
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)


def life_report_router(service):
    @asynccontextmanager
    async def lifespan(app):
        yield
        await service.close()
    router = APIRouter(prefix="/api/life-reports", lifespan=lifespan)
    key_header = Annotated[str, Header(alias="X-Report-Key", min_length=32, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")]

    def scopes(key, request):
        return "life:" + hashlib.sha256(key.encode()).hexdigest(), "network:" + service.store.hash(request.client.host if request.client else "unknown")

    @router.post("")
    async def create(body: LifeInput, request: Request, key: key_header, wait: bool = True):
        owner, network = scopes(key, request)
        try:
            return await service.create(body, owner, network, wait=wait)
        except RuntimeError as error:
            raise HTTPException(503, str(error)) from None

    @router.get("")
    async def listing(request: Request, key: key_header):
        return {"items": service.list(scopes(key, request)[0])}

    @router.get("/{report_id}")
    async def get(report_id: str, request: Request, key: key_header, wait_preview: bool = False):
        owner = scopes(key, request)[0]
        result = service.get(report_id, owner)
        task = service.preview_tasks.get(report_id)
        if wait_preview and result["preview_state"] == "generating" and task and not task.done():
            # Return as soon as the saved preview is ready; a disconnected reader must not cancel its generation.
            await asyncio.wait({task}, timeout=3)
            result = service.get(report_id, owner)
        return result

    @router.delete("/{report_id}", status_code=204)
    async def delete(report_id: str, request: Request, key: key_header):
        service.delete(report_id, scopes(key, request)[0])

    @router.post("/{report_id}/unlock")
    async def unlock(report_id: str, request: Request, key: key_header):
        owner, network = scopes(key, request)
        return await service.unlock(report_id, owner, network)

    @router.get("/{report_id}/payment")
    async def existing_payment(report_id: str, request: Request, key: key_header):
        service.row(report_id, scopes(key, request)[0])
        order = service.card_payments.existing_sunlands(report_id)
        return order if order is not None else Response(status_code=204)

    @router.post("/{report_id}/payment")
    async def create_payment(report_id: str, request: Request, key: key_header, body: PaymentContact | None = None):
        return await service.create_card_order(report_id, *scopes(key, request), contact=body)

    @router.post("/{report_id}/payment/check")
    async def check_payment(report_id: str, request: Request, key: key_header):
        owner, network = scopes(key, request)
        row = service.row(report_id, owner)
        if row["unlocked"]:
            await service.start_full_generation(report_id, owner, network)
            return {"paid": True}
        return {"paid": await service.confirm_card_order(service.card_payments.order_for(report_id), owner)}

    @router.post("/{report_id}/payment/simulate")
    async def simulate_payment(report_id: str, body: SimulatedPayment, request: Request, key: key_header):
        owner, network = scopes(key, request)
        return await service.simulate_payment(report_id, owner, network, body.reference)

    @router.post("/payment/payso/postback")
    async def payso_postback(request: Request):
        if not service.card_payments.enabled:
            raise HTTPException(404)
        params = parse_qs((await request.body()).decode("utf-8", errors="replace"))
        reference = params.get("refno", [""])[0]
        order = service.card_payments.from_reference(reference)
        if not order or not await service.confirm_card_order(order, order["owner"]):
            raise HTTPException(409, "life_payment_required")
        return PlainTextResponse("OK")

    @router.post("/payment/sunlands/notify")
    async def sunlands_notify(request: Request):
        if not service.card_payments.order_only:
            return JSONResponse({"code": 0, "msg": "unavailable"}, status_code=404)
        try:
            if request.headers.get("content-type", "").split(";", 1)[0].strip().lower() != "application/x-www-form-urlencoded":
                raise HTTPException(415, "invalid_content_type")
            params = parse_qs((await request.body()).decode("utf-8"), keep_blank_values=True, max_num_fields=32)
            if any(len(values) != 1 for values in params.values()):
                raise ValueError("duplicate_fields")
            notice = {key: values[0] for key, values in params.items()}
            order = service.card_payments.from_sunlands_number(notice.get("orderNumber", ""))
            if not order:
                raise HTTPException(404, "order_not_found")
            # The documented callback is a signal; only an authenticated server inquiry can grant access.
            if not await service.confirm_card_order(order, order["owner"], notice):
                raise HTTPException(409, "life_payment_required")
        except (ValueError, UnicodeError):
            return JSONResponse({"code": 0, "msg": "invalid_form"}, status_code=400)
        except HTTPException as error:
            return JSONResponse({"code": 0, "msg": error.detail}, status_code=error.status_code)
        return {"code": 1, "msg": "success"}

    @router.post("/{report_id}/feedback")
    async def feedback(report_id: str, body: Feedback, request: Request, key: key_header):
        owner, _ = scopes(key, request)
        service.row(report_id, owner)
        service.update(report_id, feedback=body.rating)
        return {"rating": body.rating}
    return router

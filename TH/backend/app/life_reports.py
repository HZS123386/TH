"""Persisted life-report snapshots, access, and generation."""
import asyncio
from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta, timezone
import hashlib
import json
import logging
import secrets
import time
from typing import Annotated, Literal
from urllib.parse import parse_qs
from zoneinfo import ZoneInfo

import psycopg
from fastapi import APIRouter, Header, HTTPException, Request
from fastapi.responses import JSONResponse, PlainTextResponse, Response
from pydantic import Field, model_validator

from . import thai
from .astrology import CHAPTERS as WESTERN_CHAPTERS, QUESTIONS as WESTERN_QUESTIONS, TITLES as WESTERN_TITLES, VERSION as WESTERN_VERSION, RoxyAstrology, western
from .bazi_reports import report_progress_context, report_usage_context
from .landing_features import VisitInput, record_submission, record_visit
from .life_card_payments import CARD_AMOUNT, SIMULATED_AMOUNT, SIMULATED_MERCHANT, SUNLANDS_AMOUNT, LifeCardPayments
from .life_report_content import CAREER_COPY, CAREER_VERSION, CHAPTERS, FORTUNE_CHAPTERS, FORTUNE_TOPICS, FORTUNE_VERSION, QUESTIONS, TITLES, TRAIT_HOUSES, VERSION, LifeWriter, career_report_content, preview_writing_progress, writing_progress
from .schemas import Input, ProfileInput, ThaiReadingInput
from .thai_readings import HOUSES, copy_for, grounding

logger = logging.getLogger(__name__)


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


class LifeInput(Input):
    profile: ProfileInput
    year: int = Field(ge=1901, le=2100)
    report_kind: Literal["life", "fortune"] = "life"
    career: CareerInput | None = None
    career_question: CareerInput | None = None
    user_question: str | None = Field(default=None, min_length=1, max_length=120, pattern=r"^[^\x00-\x1f\x7f]+$")
    landing_visit: VisitInput | None = Field(default=None, exclude=True)

    @model_validator(mode="after")
    def supported_input(self):
        if self.profile.language not in ("zh", "th"):
            raise ValueError("language_invalid")
        if sum(value is not None for value in (self.career, self.career_question, self.user_question)) > 1:
            raise ValueError("career_input_conflict")
        if self.career and self.report_kind == "fortune":
            raise ValueError("career_input_conflict")
        career = self.career_question or self.career
        if career and career.start.year != self.year:
            raise ValueError("career_year_mismatch")
        return self


class Feedback(Input):
    rating: Literal["close", "partly", "different"]


class SimulatedPayment(Input):
    reference: str = Field(pattern=r"^[0-9]{12}$")


class SunlandsPayment(Input):
    method: str = Field(max_length=64, pattern=r"^FM_[A-Z0-9_]+$")


def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def stamp(value):
    return datetime.fromtimestamp(value, timezone.utc).isoformat()


def explain(identifier, fact, language):
    labels = copy_for(language)
    planets = labels["planets"]
    def planet(key):
        return planets.get(key, key)
    def sign(index):
        return labels["signs"][index % 12]
    zh = language == "zh"
    if fact.get("provider") == "roxy":
        return {"id": identifier, "title": fact["title"], "detail": fact["detail"]}
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
    return {**{key: value for key, value in row.items() if key != "evidence_ids"},
            "period": {"year": month["year"], "month": month["month"]} if month else None,
            "evidence": [explain(key, facts[key], language) for key in identifiers]}


class LifeReports:
    chapter_concurrency = 3
    full_concurrency = 10
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
        self.parts_writer = LifeWriter(store, settings, model_slots, charge=False)
        self.tasks = {}
        self.preview_tasks = {}
        self.dispatcher = None
        self.queue_wakeup = asyncio.Event()
        self.queue_closing = False
        self.chart_slots = asyncio.Semaphore(settings.life_chart_concurrency)
        self.card_payments = LifeCardPayments(store, settings)

    def row(self, report_id, owner):
        with self.store.connect() as db:
            result = db.execute("SELECT * FROM life_reports WHERE id=%s AND owner=%s", (report_id, owner)).fetchone()
        if not result:
            raise HTTPException(404, "life_report_not_found")
        return dict(result)

    def update(self, report_id, *, expected_lease=None, **values):
        allowed = {"chart", "preview", "preview_state", "chapters", "plan", "unlocked", "full_state", "lease", "lease_until", "feedback", "generation_progress"}
        if not values or not set(values) <= allowed:
            raise ValueError("invalid report update")
        with self.store.connect() as db:
            condition = " AND lease=%s" if expected_lease is not None else ""
            cursor = db.execute("UPDATE life_reports SET " + ",".join(f"{key}=%s" for key in values) + " WHERE id=%s" + condition,
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

    async def create(self, body, owner, network, *, wait=True):
        snapshot = body.model_dump(mode="json", exclude=None if body.career else {"career"})
        if body.report_kind == "life":
            snapshot.pop("report_kind")
        if body.career_question is None:
            snapshot.pop("career_question")
        if body.user_question is None:
            snapshot.pop("user_question")
        if body.career and body.career.focus is None:
            snapshot["career"].pop("focus")
        use_roxy = self.settings.life_astrology_provider == "roxy" and not body.career
        version = WESTERN_VERSION if use_roxy else CAREER_VERSION if body.career else FORTUNE_VERSION if body.report_kind == "fortune" else VERSION
        fingerprint = hashlib.sha256(encoded([version, snapshot]).encode()).hexdigest()
        with self.store.connect() as db:
            existing = db.execute("SELECT id FROM life_reports WHERE owner=%s AND fingerprint=%s", (owner, fingerprint)).fetchone()
            visit_id, attribution = None, {}
            if body.landing_visit is not None:
                try:
                    with db.transaction():
                        record_visit(db, body.landing_visit, owner)
                        if not existing:
                            attribution = db.execute("""
                                SELECT visitor_number,first_source,first_campaign,region_code
                                FROM landing_visitors WHERE owner=%s
                            """, (owner,)).fetchone() or {}
                    visit_id = str(body.landing_visit.id)
                except (psycopg.Error, HTTPException):
                    logger.warning("H5 attribution was unavailable during report creation")
            if existing:
                report_id = existing["id"]
            else:
                # Save the job before any external calculation; no chart positions are fabricated.
                chart = {"status": "queued", "provider": "roxy" if use_roxy else "thai",
                         "domain": "astrology", "version": version}
                # Retry code collisions while reusing a report inserted by a concurrent submission.
                for _ in range(8):
                    report_id = secrets.token_hex(16)
                    inserted = db.execute("""
                        INSERT INTO life_reports(id,owner,fingerprint,input,chart,created,preview_state,preview_network,
                                                 landing_visitor_number,landing_source,landing_campaign,landing_region)
                        VALUES (%s,%s,%s,%s,%s,%s,'queued',%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING RETURNING id
                    """, (report_id, owner, fingerprint, encoded(snapshot), encoded(chart), time.time(), network,
                          attribution.get("visitor_number"), attribution.get("first_source"),
                          attribution.get("first_campaign"), attribution.get("region_code"))).fetchone()
                    if inserted:
                        break
                    existing = db.execute("SELECT id FROM life_reports WHERE owner=%s AND fingerprint=%s",
                                          (owner, fingerprint)).fetchone()
                    if existing:
                        report_id = existing["id"]
                        break
                else:
                    raise HTTPException(503, "life_report_create_unavailable")
            if visit_id is not None:
                try:
                    with db.transaction():
                        record_submission(db, visit_id, report_id, owner)
                except psycopg.Error:
                    logger.warning("H5 submission tracking was unavailable during report creation")
        row = self.row(report_id, owner)
        if existing and row["preview"]:
            return self.public(self.row(row["id"], owner))
        return await self.start_preview_generation(row, body, owner, network, wait=wait)

    async def start_preview_generation(self, row, body, owner, network, *, wait=False):
        # Retries reuse the persisted input/chart and cannot duplicate an active job.
        with self.store.connect() as db:
            db.execute("UPDATE life_reports SET preview_state='queued',preview_network=%s,lease='',lease_until=0 "
                       "WHERE id=%s AND preview IS NULL AND lease_until<%s AND "
                       "(preview_state NOT IN ('queued','generating') OR "
                       "(preview_state='generating' AND preview_network=''))",
                       (network, row["id"], time.time()))
        self.wake_dispatcher()
        if wait:
            while self.row(row["id"], owner)["preview_state"] in ("queued", "generating"):
                await asyncio.sleep(0.05)
        return self.get(row["id"], owner)

    def start(self):
        if self.dispatcher is None or self.dispatcher.done():
            self.queue_closing = False
            self.dispatcher = asyncio.create_task(self.dispatch_generation())

    def wake_dispatcher(self):
        self.start()
        self.queue_wakeup.set()

    def job_finished(self, jobs, report_id, task):
        if jobs.get(report_id) is task:
            jobs.pop(report_id)
        if not task.cancelled() and task.exception():
            logger.error("Report worker failed: %s", report_id, exc_info=task.exception())
        self.queue_wakeup.set()

    async def dispatch_generation(self):
        while not self.queue_closing:
            self.queue_wakeup.clear()
            for dispatch in (self.dispatch_full_reports, self.dispatch_previews):
                try:
                    dispatch()
                except Exception:
                    logger.exception("Report queue dispatch failed: %s", dispatch.__name__)
            try:
                await asyncio.wait_for(self.queue_wakeup.wait(), timeout=1)
            except TimeoutError:
                pass

    def dispatch_previews(self):
        now = time.time()
        with self.store.connect() as db:
            # Expired leases recover after a crash; old failed reports remain available for manual retry.
            db.execute("UPDATE life_reports SET preview_state='queued',lease='',lease_until=0 "
                       "WHERE preview IS NULL AND preview_state='generating' AND lease_until<%s "
                       "AND preview_network<>'' AND id<>ALL(%s)", (now, list(self.preview_tasks)))
            rows = db.execute("SELECT * FROM life_reports WHERE preview IS NULL AND preview_state='queued' "
                              "AND lease_until<%s AND id<>ALL(%s) ORDER BY created,id LIMIT %s",
                              (now, list(self.preview_tasks),
                               max(0, self.settings.life_generation_concurrency - len(self.preview_tasks)))).fetchall()
        for row in rows:
            body = LifeInput.model_validate_json(row["input"])
            lease = secrets.token_hex(16)
            with self.store.connect() as db:
                claimed = db.execute("UPDATE life_reports SET preview_state='generating',lease=%s,lease_until=%s "
                                     "WHERE id=%s AND preview IS NULL AND preview_state='queued' AND lease_until<%s",
                                     (lease, now + self.lease_seconds, row["id"], now))
            if claimed.rowcount:
                task = asyncio.create_task(self.generate_preview(row, body, row["owner"], row["preview_network"], lease))
                self.preview_tasks[row["id"]] = task
                task.add_done_callback(lambda done, report_id=row["id"]: self.job_finished(self.preview_tasks, report_id, done))

    def dispatch_full_reports(self):
        now = time.time()
        active = list(self.tasks)
        available = self.full_concurrency - len(active)
        if available <= 0:
            return
        claimed = []
        with self.store.connect() as db:
            # A pending report has already consumed its generation admission.
            db.execute("UPDATE life_reports SET full_state='pending',lease='',lease_until=0 "
                       "WHERE (unlocked=1 OR line_confirmed_at IS NOT NULL) AND preview IS NOT NULL AND full_state='generating' "
                       "AND lease_until<%s AND id<>ALL(%s)", (now, active))
            rows = db.execute("""
                SELECT r.id,r.owner,r.input,r.full_state,COALESCE(p.network,NULLIF(r.preview_network,''),r.owner) network
                FROM life_reports r LEFT JOIN life_card_payments p ON p.report_id=r.id
                WHERE (r.unlocked=1 OR r.line_confirmed_at IS NOT NULL)
                  AND r.preview IS NOT NULL AND r.lease_until<%s AND r.id<>ALL(%s)
                  AND (r.full_state IN ('queued','pending') OR (
                    r.full_state='not_started' AND p.provider_order IS NOT NULL
                    AND (NOT starts_with(p.merchant,'sunlands:') OR (
                        p.sunlands_order::jsonb ->> 'paymentStatus'='PAID'
                        AND p.provider_order=p.sunlands_gateway||'/'||p.sunlands_order_number
                    ))
                  ))
                ORDER BY r.created,r.id LIMIT %s FOR UPDATE OF r SKIP LOCKED
            """, (now, active, available)).fetchall()
            for row in rows:
                if row["full_state"] != "pending" and not self.admit_full(db, row, row["network"]):
                    db.execute("UPDATE life_reports SET full_state='limited',lease='',lease_until=0 WHERE id=%s", (row["id"],))
                    continue
                lease = secrets.token_hex(16)
                db.execute("UPDATE life_reports SET full_state='generating',lease=%s,lease_until=%s WHERE id=%s",
                           (lease, time.time() + self.lease_seconds, row["id"]))
                claimed.append((row, lease))
        for row, lease in claimed:
            report_id = row["id"]
            task = asyncio.create_task(self.complete(report_id, row["owner"], row["network"], lease))
            self.tasks[report_id] = task
            task.add_done_callback(lambda done, report_id=report_id: self.job_finished(self.tasks, report_id, done))

    async def generate_preview(self, row, body, owner, network, lease):
        heartbeat = asyncio.create_task(self.keep_lease(row["id"], lease))
        usage_token = report_usage_context.set((row["id"], "preview"))
        progress_token = report_progress_context.set(lambda raw: self.record_progress(row["id"], lease, preview_writing_progress(raw, body.profile.language)))
        try:
            chart = json.loads(row["chart"])
            if chart.get("status") != "ready":
                profile = body.profile.model_dump(mode="json")
                use_roxy = western(chart)
                async with self.chart_slots if use_roxy else self.calculation_slots:
                    chart = (await self.adapters["astrology"].calculate(body.profile, owner, network) if use_roxy else
                             await asyncio.to_thread(thai.natal, {**profile, "birth_time": profile["birth_time"] or "12:00"}))
                if chart["status"] != "ready":
                    raise ValueError("chart_unavailable")
                if not profile["birth_time"] and not use_roxy:
                    chart["time_known"] = False
                    chart["calculation_input"]["time_precision"] = "estimated-noon"
                row["chart"] = encoded(chart)
                self.update(row["id"], expected_lease=lease, chart=row["chart"])
            await self.write_preview(row, body, owner, network, lease)
        except ReportLeaseLost:
            pass
        except asyncio.CancelledError:
            self.update(row["id"], expected_lease=lease, preview_state="queued", lease="", lease_until=time.time() + 21)
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
        bundle = self.bundle(body, chart, "overview")
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
        if body.user_question:
            bundle["user_question"] = body.user_question
        elif body.career_question and western(chart):
            bundle["user_question"] = {"subject": "career decision", **body.career_question.model_dump(mode="json")}
        result = await self.writer.generate(bundle, owner, network)
        values = {"preview_state": result["state"], "lease": "", "lease_until": 0}
        if result["state"] == "pending":
            values.update(preview_state="queued", lease_until=time.time() + 2)
        if result.get("story"):
            preview = {"story": result["story"], "evidence": bundle["evidence"]}
            if body.career_question and not western(chart):
                answer = await self.career_preview(body.career_question, chart, body.profile,
                                                   direct_question=body.career_question.focus is None)
                preview["career_answer"] = answer["story"]["summary"]
                preview["evidence"].update(answer["evidence"])
            values["preview"] = encoded(preview)
        self.update(row["id"], expected_lease=lease, **values)

    def record_progress(self, report_id, lease, updates):
        with self.store.connect() as db:
            row = db.execute("SELECT generation_progress FROM life_reports WHERE id=%s AND lease=%s", (report_id, lease)).fetchone()
            if not row:
                return
            marks = json.loads(row["generation_progress"])
            changes = {key: percent for key, percent in updates.items() if percent > marks.get(key, 0)}
            if not changes:
                return
            marks.update(changes)
            db.execute("UPDATE life_reports SET generation_progress=%s WHERE id=%s AND lease=%s", (encoded(marks), report_id, lease))

    async def write_part(self, report_id, lease, bundle, owner, network):
        key = "plan" if bundle["stage"] == "plan" else bundle["reading"]
        last_progress = 0

        def progress(raw):
            nonlocal last_progress
            percent = writing_progress(raw, bundle["stage"], compact=bundle.get("format") == WESTERN_VERSION)
            # Stream fragments only hit the database when visible progress advances.
            if percent >= last_progress + 5:
                self.record_progress(report_id, lease, {key: percent})
                last_progress = percent

        token = report_progress_context.set(progress)
        try:
            return await self.parts_writer.generate(bundle, owner, network)
        finally:
            report_progress_context.reset(token)

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

    def public(self, row, *, line_delivery=False):
        full_access = bool(row["unlocked"]) or (line_delivery and row["line_confirmed_at"] is not None
                                                and row["full_state"] == "ready")
        full_state = row["full_state"] if full_access else "not_started"
        plan_ready = full_access and bool(row["plan"])
        body = json.loads(row["input"])
        language = body["profile"]["language"]
        career = body.get("career")
        fortune = body.get("report_kind") == "fortune"
        labels = CAREER_COPY[language] if career else None
        chart = json.loads(row["chart"])
        is_western = western(chart)
        records = json.loads(row["chapters"]) if full_access else {}
        preview = json.loads(row["preview"]) if row["preview"] else None
        title = ("运程解析" if language == "zh" else "วิเคราะห์ดวงชะตา") if fortune else ("人生报告" if language == "zh" else "รายงานชีวิต")
        version = chart["version"] if is_western else FORTUNE_VERSION if fortune else VERSION
        if career:
            title = preview["story"].get("title", labels["title"]) if preview else labels["title"]
            version = preview.get("version", "career-decision-1") if preview else CAREER_VERSION
        marks = json.loads(row.get("generation_progress", "{}"))
        preview_sections = [{"key": key, "percent": 100 if preview else min(99, marks.get(key, 0))}
                            for key in ("preview_summary", "preview_strength", "preview_decisions", "preview_relationships")]
        chapter_keys = WESTERN_CHAPTERS if is_western else FORTUNE_CHAPTERS if fortune else CHAPTERS
        full_marks = marks if full_access else {}
        parts = {key: 100 if key in records else min(99, full_marks.get(key, 0)) for key in chapter_keys}
        plan_percent = 100 if plan_ready else min(99, full_marks.get("plan", 0))
        sections = ([{"key": key, "percent": parts[key]} for key in chapter_keys] + [
            {"key": "plan", "percent": plan_percent},
        ]) if fortune or is_western else [
            {"key": "work", "percent": parts["work"]}, {"key": "money", "percent": parts["money"]},
            {"key": "relationships", "percent": (parts["love"] + parts["family"]) / 2},
            {"key": "annual", "percent": parts["annual"]},
            {"key": "plan", "percent": plan_percent},
        ]
        completed = (sum(key in records for key in chapter_keys) + plan_ready) if fortune or is_western else (
            sum(key in records for key in ("work", "money", "annual")) + ("love" in records and "family" in records) + plan_ready)
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
            titles[0] = f"{body['year']}年运程" if language == "zh" else f"ดวงปี {body['year']}"
            questions = [FORTUNE_TOPICS[key][language]["questions"] for key in chapter_keys]
        percent = int(sum(section["percent"] for section in sections) / len(sections))
        percent = min(percent, 100 if full_state == "ready" else 99)
        simulation = self.can_simulate_payment(career)
        amount = 9900 if career else CARD_AMOUNT
        merchant = None
        if self.card_payments.order_only:
            amount = SUNLANDS_AMOUNT
            merchant = "sunlands:" + self.card_payments.settings.sunlands_app_key
        elif simulation:
            amount, merchant = SIMULATED_AMOUNT, SIMULATED_MERCHANT
        if merchant and preview and not full_access:
            order = self.card_payments.order_for(row["id"])
            if order and order["merchant"] == merchant:
                amount = order["amount"]
        result = {
            "id": row["id"], "claim_code": str(row["claim_code"]), "version": version, "title": title,
            "input": body, "created_at": stamp(row["created"]), "location": chart.get("location"),
            "method": ({"name": "RoxyAPI Western Astrology", "house_system": "placidus", "version": "v2",
                        "zodiac": "tropical", "node_type": "true", "source": chart.get("source")} if is_western else
                       {"name": "Thai Suriyayatra", "house_system": "whole-sign", "version": thai.ENGINE_VERSION}),
            "format": "western-compact" if is_western else "legacy",
            "chart": self.chart_view(chart, bool(body["profile"].get("birth_time")), language) if chart.get("status") == "ready" else None,
            "time_accuracy": {"mode": "exact" if body["profile"]["birth_time"] else "estimated",
                              "assumed_local_time": None if body["profile"]["birth_time"] else "12:00"},
            "price": {"amount": amount, "currency": "THB", "display": f"฿{amount // 100}",
                      "mode": "sunlands_order_only" if self.card_payments.order_only else
                      "payso_test" if self.card_payments.enabled and not career else "direct"},
            "payment_simulation": simulation,
            "preview_state": row["preview_state"], "access": "full" if full_access else "preview",
            "full_state": "queued" if full_state == "pending" else full_state,
            "progress": {"completed": completed, "total": len(sections)},
            "generation_progress": {"percent": percent, "sections": sections},
            "preview_generation_progress": {"percent": int(sum(section["percent"] for section in preview_sections) / 4), "sections": preview_sections},
            "feedback": row["feedback"],
            "catalog": [{"key": key, "title": titles[index], "questions": questions[index],
                         "houses": [] if is_western else FORTUNE_TOPICS[key]["houses"] if fortune else list(HOUSES[key]), "ready": key in records} for index, key in enumerate(chapter_keys)],
            "preview": {"summary": public_point(preview["story"]["summary"], preview["evidence"], language),
                        "traits": [public_point(item, preview["evidence"], language) for item in preview["story"]["traits"]]} if preview else None,
            "chapters": [], "plan": None,
        }
        position = 0
        if row["preview_state"] == "queued":
            with self.store.connect() as db:
                position = db.execute("SELECT COUNT(*) AS total FROM life_reports WHERE preview_state='queued' "
                                      "AND (created<%s OR (created=%s AND id<=%s))",
                                      (row["created"], row["created"], row["id"])).fetchone()["total"]
        result["generation_queue"] = {"state": "calculating" if row["preview_state"] == "generating" and chart.get("status") != "ready"
                                      else row["preview_state"], "position": position}
        if career:
            result["reference_period"] = {"start": career["start"], "end": (date.fromisoformat(career["start"]) + timedelta(days=29)).isoformat()}
        if preview and "career_answer" in preview:
            result["preview"]["career_answer"] = public_point(preview["career_answer"], preview["evidence"], language)
        if full_access:
            for index, key in enumerate(chapter_keys):
                if key not in records:
                    continue
                record = records[key]
                story, facts = record["story"], record["evidence"]
                result["chapters"].append({"key": key, "title": titles[index],
                    "summary": public_point(story["summary"], facts, language),
                    **{kind: [public_point(item, facts, language) for item in story[kind]] for kind in ("insights", "watchpoints", "actions")}})
            if plan_ready:
                plan = json.loads(row["plan"])
                # Resolve stored references from their source records, independently of visible chapter grouping.
                actions = {f"{key}:{index}": {"chapter": key, "index": index, **public_point(action, record["evidence"], language)}
                           for key, record in records.items() for index, action in enumerate(record["story"]["actions"])}
                result["plan"] = {"phases": [{**{key: item[key] for key in ("key", "title", "text")},
                    "actions": [actions[key] for key in item["action_ids"]]} for item in plan["phases"]]}
        return result

    def get(self, report_id, owner):
        row = self.row(report_id, owner)
        if not row["preview"] and not row.get("preview_network") and row["preview_state"] == "generating" and row["lease_until"] < time.time():
            with self.store.connect() as db:
                db.execute("UPDATE life_reports SET preview_state='unavailable',lease='',lease_until=0 "
                           "WHERE id=%s AND lease=%s AND preview IS NULL AND preview_state='generating' AND lease_until<%s",
                           (report_id, row["lease"], time.time()))
            row = self.row(report_id, owner)
        return self.public(row)

    def _history_rows(self, owner, limit, before=None):
        cursor_filter = "AND (created,id)<(%s,%s)" if before is not None else ""
        params = (owner, *before, limit) if before is not None else (owner, limit)
        with self.store.connect() as db:
            return db.execute(
                f"SELECT id,input,created,unlocked,preview_state,full_state FROM life_reports "
                f"WHERE owner=%s {cursor_filter} ORDER BY created DESC,id DESC LIMIT %s", params,
            ).fetchall()

    @staticmethod
    def _history_item(row):
        full_state = row["full_state"] if row["unlocked"] else "not_started"
        return {"id": row["id"], "input": json.loads(row["input"]), "created_at": stamp(row["created"]),
                "access": "full" if row["unlocked"] else "preview", "preview_state": row["preview_state"],
                "full_state": "queued" if full_state == "pending" else full_state}

    def list(self, owner):
        return [self._history_item(row) for row in self._history_rows(owner, 30)]

    def history_page(self, owner, before=None):
        rows = self._history_rows(owner, 31, before)
        page = rows[:30]
        next_cursor = {"created": page[-1]["created"], "id": page[-1]["id"]} if len(rows) > 30 else None
        return {"items": [self._history_item(row) for row in page], "next_cursor": next_cursor}

    def delete(self, report_id, owner):
        # Verify ownership and generation state inside the same write transaction.
        with self.store.connect() as db:
            db.execute("LOCK TABLE life_card_payments IN SHARE ROW EXCLUSIVE MODE")
            row = db.execute("SELECT * FROM life_reports WHERE id=%s AND owner=%s FOR UPDATE", (report_id, owner)).fetchone()
            if row is None:
                raise HTTPException(404, "life_report_not_found")
            payment = db.execute("SELECT merchant FROM life_card_payments WHERE report_id=%s", (report_id,)).fetchone()
            if payment and payment["merchant"].startswith("sunlands:"):
                raise HTTPException(409, "life_order_needs_review")
            active_task = any(task is not None and not task.done()
                              for task in (self.preview_tasks.get(report_id), self.tasks.get(report_id)))
            claimed = (row["preview_state"] in ("pending", "generating") or row["full_state"] == "generating")
            if active_task or row["full_state"] in ("queued", "pending") or (claimed and row["lease_until"] > time.time()):
                raise HTTPException(409, "life_report_generating")
            db.execute("DELETE FROM life_card_payments WHERE report_id=%s", (report_id,))
            db.execute("DELETE FROM life_reports WHERE id=%s AND owner=%s", (report_id, owner))

    async def unlock(self, report_id, owner, network):
        row = self.row(report_id, owner)
        if not row["preview"]:
            raise HTTPException(409, "life_preview_required")
        if not row["unlocked"]:
            career = json.loads(row["input"]).get("career")
            if (self.card_payments.order_only or self.can_simulate_payment(career) or self.card_payments.order_for(report_id)
                    or (self.card_payments.enabled and not career)):
                raise HTTPException(402, "life_payment_required")
            with self.store.connect() as db:
                # A LINE request grants staff delivery only, even under legacy direct unlock.
                updated = db.execute("UPDATE life_reports SET unlocked=1 WHERE id=%s AND owner=%s "
                                     "AND line_confirmed_at IS NULL", (report_id, owner))
                if not updated.rowcount:
                    raise HTTPException(402, "life_payment_required")
        await self.start_full_generation(report_id, owner, network)
        return self.get(report_id, owner)

    def can_simulate_payment(self, career):
        return not self.card_payments.order_only and self.development and (bool(career) or not self.card_payments.enabled)

    async def create_card_order(self, report_id, owner, network, *, visit_id=None, origin=None):
        row = self.row(report_id, owner)
        body = json.loads(row["input"])
        if row["unlocked"]:
            raise HTTPException(409, "life_payment_unavailable")
        if not row["preview"]:
            raise HTTPException(409, "life_preview_required")
        career = body.get("career")
        if self.card_payments.order_only:
            return_url = self.card_payments.report_return_url(report_id, body["profile"]["language"], origin)
            return await self.card_payments.create_sunlands(report_id, network, visit_id=visit_id, return_url=return_url)
        if self.can_simulate_payment(career):
            return self.card_payments.create_simulated(report_id, network, visit_id=visit_id)
        if not self.card_payments.enabled or career:
            raise HTTPException(409, "life_payment_unavailable")
        return self.card_payments.create(report_id, network, body["profile"]["language"], visit_id=visit_id)

    def sunlands_checkout_language(self, report_id, owner):
        row = self.row(report_id, owner)
        if not self.card_payments.order_only:
            raise HTTPException(409, "life_payment_unavailable")
        if row["unlocked"]:
            return None
        if not row["preview"]:
            raise HTTPException(409, "life_preview_required")
        return "th-TH" if json.loads(row["input"])["profile"]["language"] == "th" else "zh-CN"

    async def simulate_payment(self, report_id, owner, reference):
        row = self.row(report_id, owner)
        if not self.can_simulate_payment(json.loads(row["input"]).get("career")):
            raise HTTPException(404, "life_payment_unavailable")
        if not self.card_payments.confirm_simulated(report_id, reference):
            raise HTTPException(409, "life_payment_required")
        self.wake_dispatcher()
        return {"paid": True}

    async def confirm_card_order(self, order, owner, notification=None):
        if order:
            self.row(order["report_id"], owner)
        if order and order["merchant"].startswith("sunlands:"):
            paid = await self.card_payments.confirm_sunlands(order, notification)
        else:
            paid = await self.card_payments.confirm(order)
        if not paid:
            return False
        self.wake_dispatcher()
        return True

    def admit_full(self, db, row, network):
        return (bool(json.loads(row["input"]).get("career")) or not self.writer.enabled
                or self.writer.reserve_run(row["owner"], network, db=db))

    def queue_full_generation(self, db, row, network):
        state = row["full_state"]
        if state not in ("queued", "pending", "generating", "ready") and row["lease_until"] < time.time():
            state = "pending" if self.admit_full(db, row, network) else "limited"
            db.execute("UPDATE life_reports SET full_state=%s,lease='',lease_until=0 WHERE id=%s", (state, row["id"]))
        return state

    async def start_full_generation(self, report_id, owner, network):
        with self.store.connect() as db:
            row = db.execute("SELECT * FROM life_reports WHERE id=%s AND owner=%s FOR UPDATE", (report_id, owner)).fetchone()
            if not row:
                raise HTTPException(404, "life_report_not_found")
            if not row["unlocked"] or not row["preview"]:
                return
            self.queue_full_generation(db, row, network)
        self.wake_dispatcher()

    def finish_full_attempt(self, report_id, lease, state):
        self.update(report_id, expected_lease=lease, full_state=state, lease="",
                    lease_until=time.time() + 2 if state == "pending" else 0)

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
            chart, preview = json.loads(row["chart"]), json.loads(row["preview"])["story"]
            # Carry the preview's meaning without leaking its citations into another topic.
            preview_context = {"summary": preview["summary"]["text"],
                               "traits": [{key: item[key] for key in ("key", "title", "text")} for item in preview["traits"]]}
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
                state = next((failure for failure in failures if failure != "pending"), "pending")
                self.finish_full_attempt(report_id, lease, state)
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
                self.finish_full_attempt(report_id, lease, generated["state"])
        except ReportLeaseLost:
            return
        except asyncio.CancelledError:
            try:
                self.update(report_id, expected_lease=lease, full_state="pending", lease="", lease_until=time.time() + 21)
            except ReportLeaseLost:
                pass
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
            db.execute("UPDATE life_reports SET full_state='unavailable',lease='',lease_until=0 WHERE id=%s AND lease=%s", (report_id, lease))

    def fail_preview(self, report_id, lease):
        with self.store.connect() as db:
            db.execute("UPDATE life_reports SET preview_state='unavailable',lease='',lease_until=0 WHERE id=%s AND lease=%s AND preview IS NULL", (report_id, lease))

    async def close(self):
        self.queue_closing = True
        if self.dispatcher:
            self.dispatcher.cancel()
            await asyncio.gather(self.dispatcher, return_exceptions=True)
        tasks = [*self.tasks.values(), *self.preview_tasks.values(), *self.writer.inflight.values(), *self.parts_writer.inflight.values()]
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)


def life_report_router(service):
    @asynccontextmanager
    async def lifespan(app):
        service.start()
        try:
            yield
        finally:
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
    async def get(report_id: str, request: Request, key: key_header):
        return service.get(report_id, scopes(key, request)[0])

    @router.post("/{report_id}/app-login-code")
    def app_login_code(report_id: str, request: Request, key: key_header):
        owner, _ = scopes(key, request)
        service.row(report_id, owner)
        result = service.store.issue_h5_login_code(owner)
        if result is None:
            raise HTTPException(503, "h5_login_code_unavailable")
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
    async def create_payment(report_id: str, request: Request, key: key_header):
        return await service.create_card_order(
            report_id, *scopes(key, request), visit_id=request.headers.get("X-Visit-Id"),
            origin=request.headers.get("origin"))

    @router.get("/{report_id}/payment/methods")
    async def payment_methods(report_id: str, request: Request, key: key_header):
        language = service.sunlands_checkout_language(report_id, scopes(key, request)[0])
        if language is None:
            return {"methods": [], "check_payment": True}
        return await service.card_payments.sunlands_methods(report_id, language)

    @router.post("/{report_id}/payment/start")
    async def start_payment(report_id: str, body: SunlandsPayment, request: Request, key: key_header):
        language = service.sunlands_checkout_language(report_id, scopes(key, request)[0])
        if language is None:
            return {"redirect_url": None}
        return await service.card_payments.start_sunlands_payment(
            report_id, body.method, language, origin=request.headers.get("origin"))

    @router.post("/{report_id}/payment/check")
    async def check_payment(report_id: str, request: Request, key: key_header):
        owner, _ = scopes(key, request)
        row = service.row(report_id, owner)
        if row["unlocked"]:
            return {"paid": True}
        return {"paid": await service.confirm_card_order(service.card_payments.order_for(report_id), owner)}

    @router.post("/{report_id}/payment/simulate")
    async def simulate_payment(report_id: str, body: SimulatedPayment, request: Request, key: key_header):
        owner, _ = scopes(key, request)
        return await service.simulate_payment(report_id, owner, body.reference)

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

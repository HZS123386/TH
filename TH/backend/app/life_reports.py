"""Persisted life-report snapshots and the explicitly requested direct unlock."""
import asyncio
from contextlib import asynccontextmanager
from datetime import date, datetime, timedelta, timezone
import hashlib
import json
import logging
import secrets
import time
from typing import Annotated, Literal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import Field, model_validator

from . import thai
from .bazi_reports import report_progress_context, report_usage_context
from .life_report_content import CAREER_COPY, CAREER_VERSION, CHAPTERS, QUESTIONS, TITLES, TRAIT_HOUSES, VERSION, LifeWriter, career_report_content, preview_writing_progress, writing_progress
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
    career: CareerInput | None = None
    career_question: CareerInput | None = None
    user_question: str | None = Field(default=None, min_length=1, max_length=120, pattern=r"^[^\x00-\x1f\x7f]+$")

    @model_validator(mode="after")
    def supported_input(self):
        if self.profile.language not in ("zh", "th"):
            raise ValueError("language_invalid")
        if sum(value is not None for value in (self.career, self.career_question, self.user_question)) > 1:
            raise ValueError("career_input_conflict")
        career = self.career_question or self.career
        if career and career.start.year != self.year:
            raise ValueError("career_year_mismatch")
        return self


class Feedback(Input):
    rating: Literal["close", "partly", "different"]


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
    lease_seconds = 180
    heartbeat_seconds = 30

    def __init__(self, store, settings, model_slots, calculation_slots):
        self.store, self.calculation_slots = store, calculation_slots
        self.writer = LifeWriter(store, settings, model_slots)
        self.parts_writer = LifeWriter(store, settings, model_slots, charge=False)
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

    def row(self, report_id, owner):
        with self.store.connect() as db:
            result = db.execute("SELECT * FROM life_reports WHERE id=? AND owner=?", (report_id, owner)).fetchone()
        if not result:
            raise HTTPException(404, "life_report_not_found")
        return dict(result)

    def update(self, report_id, *, expected_lease=None, **values):
        allowed = {"preview", "preview_state", "chapters", "plan", "unlocked", "full_state", "lease", "lease_until", "feedback", "generation_progress"}
        if not values or not set(values) <= allowed:
            raise ValueError("invalid report update")
        with self.store.connect() as db:
            condition = " AND lease=?" if expected_lease is not None else ""
            cursor = db.execute("UPDATE life_reports SET " + ",".join(f"{key}=?" for key in values) + " WHERE id=?" + condition,
                                [*values.values(), report_id, *([expected_lease] if expected_lease is not None else [])])
            if expected_lease is not None and not cursor.rowcount:
                raise ReportLeaseLost()

    def bundle(self, body, chart, reading, months=None):
        result = grounding(ThaiReadingInput(profile=body.profile, year=body.year, reading=reading), chart, months or [])
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
        profile = body.profile.model_dump(mode="json")
        snapshot = body.model_dump(mode="json", exclude=None if body.career else {"career"})
        if body.career_question is None:
            snapshot.pop("career_question")
        if body.user_question is None:
            snapshot.pop("user_question")
        if body.career and body.career.focus is None:
            snapshot["career"].pop("focus")
        fingerprint = hashlib.sha256(encoded([CAREER_VERSION if body.career else VERSION, snapshot]).encode()).hexdigest()
        with self.store.connect() as db:
            existing = db.execute("SELECT id FROM life_reports WHERE owner=? AND fingerprint=?", (owner, fingerprint)).fetchone()
        if existing:
            row = self.row(existing["id"], owner)
            if row["preview"]:
                return self.public(self.row(row["id"], owner))
        else:
            async with self.calculation_slots:
                # Keep the submitted time unknown; only this report's calculation uses an explicit noon estimate.
                chart = await asyncio.to_thread(thai.natal, {**profile, "birth_time": profile["birth_time"] or "12:00"})
            if chart["status"] != "ready":
                raise HTTPException(422, "thai_reading_details_required")
            if not profile["birth_time"]:
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
        progress_token = report_progress_context.set(lambda raw: self.record_progress(row["id"], lease, preview_writing_progress(raw, body.profile.language)))
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
        bundle = self.bundle(body, chart, "overview")
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
        result = await self.writer.generate(bundle, owner, network)
        values = {"preview_state": result["state"], "lease": "", "lease_until": 0}
        if result.get("story"):
            preview = {"story": result["story"], "evidence": bundle["evidence"]}
            if body.career_question:
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
        key = "plan" if bundle["stage"] == "plan" else bundle["reading"]
        token = report_progress_context.set(lambda raw: self.record_progress(report_id, lease, {key: writing_progress(raw, bundle["stage"])}))
        try:
            return await self.parts_writer.generate(bundle, owner, network)
        finally:
            report_progress_context.reset(token)

    def public(self, row):
        body = json.loads(row["input"])
        language = body["profile"]["language"]
        career = body.get("career")
        labels = CAREER_COPY[language] if career else None
        chart = json.loads(row["chart"])
        records = json.loads(row["chapters"])
        preview = json.loads(row["preview"]) if row["preview"] else None
        title = "人生报告" if language == "zh" else "รายงานชีวิต"
        version = VERSION
        if career:
            title = preview["story"].get("title", labels["title"]) if preview else labels["title"]
            version = preview.get("version", "career-decision-1") if preview else CAREER_VERSION
        marks = json.loads(row.get("generation_progress", "{}"))
        preview_sections = [{"key": key, "percent": 100 if preview else min(99, marks.get(key, 0))}
                            for key in ("preview_summary", "preview_strength", "preview_decisions", "preview_relationships")]
        parts = {key: 100 if key in records else min(99, marks.get(key, 0)) for key in CHAPTERS}
        sections = [
            {"key": "work", "percent": parts["work"]}, {"key": "money", "percent": parts["money"]},
            {"key": "relationships", "percent": (parts["love"] + parts["family"]) / 2},
            {"key": "annual", "percent": parts["annual"]},
            {"key": "plan", "percent": 100 if row["plan"] else min(99, marks.get("plan", 0))},
        ]
        completed = sum(key in records for key in ("work", "money", "annual")) + ("love" in records and "family" in records) + bool(row["plan"])
        chapter_keys = CHAPTERS
        if career:
            sections = [{"key": "work", "percent": parts["work"]}]
            completed = int("work" in records)
            chapter_keys = ("work",)
        titles = [labels["chapter"]] if labels else TITLES[language]
        questions = [list(labels["paid_titles"])] if labels else QUESTIONS[language]
        percent = int(sum(section["percent"] for section in sections) / len(sections))
        percent = min(percent, 100 if row["full_state"] == "ready" else 99)
        result = {
            "id": row["id"], "version": version, "title": title,
            "input": body, "created_at": stamp(row["created"]), "location": chart["location"],
            "method": {"name": "Thai Suriyayatra", "house_system": "whole-sign", "version": thai.ENGINE_VERSION},
            "time_accuracy": {"mode": "exact" if body["profile"]["birth_time"] else "estimated",
                              "assumed_local_time": None if body["profile"]["birth_time"] else "12:00"},
            "price": {"amount": 9900, "currency": "THB", "display": "฿99", "mode": "direct"} if career
                     else {"amount": 5000, "currency": "THB", "display": "฿50", "mode": "direct"},
            "preview_state": row["preview_state"], "access": "full" if row["unlocked"] else "preview",
            "full_state": row["full_state"], "progress": {"completed": completed, "total": len(sections)},
            "generation_progress": {"percent": percent, "sections": sections},
            "preview_generation_progress": {"percent": int(sum(section["percent"] for section in preview_sections) / 4), "sections": preview_sections},
            "feedback": row["feedback"],
            "catalog": [{"key": key, "title": titles[index], "questions": questions[index],
                         "houses": list(HOUSES[key]), "ready": key in records} for index, key in enumerate(chapter_keys)],
            "preview": {"summary": public_point(preview["story"]["summary"], preview["evidence"], language),
                        "traits": [public_point(item, preview["evidence"], language) for item in preview["story"]["traits"]]} if preview else None,
            "chapters": [], "plan": None,
        }
        if career:
            result["reference_period"] = {"start": career["start"], "end": (date.fromisoformat(career["start"]) + timedelta(days=29)).isoformat()}
        if preview and "career_answer" in preview:
            result["preview"]["career_answer"] = public_point(preview["career_answer"], preview["evidence"], language)
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

    async def unlock(self, report_id, owner, network):
        row = self.row(report_id, owner)
        if not row["preview"]:
            raise HTTPException(409, "life_preview_required")
        self.update(report_id, unlocked=1)
        await self.start_full_generation(report_id, owner, network)
        return self.get(report_id, owner)

    async def start_full_generation(self, report_id, owner, network):
        row = self.row(report_id, owner)
        if not row["preview"]:
            return
        if row["full_state"] == "ready" or report_id in self.tasks:
            return
        lease = secrets.token_hex(16)
        with self.store.connect() as db:
            cursor = db.execute("UPDATE life_reports SET full_state='generating',lease=?,lease_until=? "
                                "WHERE id=? AND owner=? AND lease_until<? AND full_state<>'ready'", (lease, time.time() + self.lease_seconds, report_id, owner, time.time()))
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
            chart, preview = json.loads(row["chart"]), json.loads(row["preview"])["story"]
            # Carry the preview's meaning without leaking its citations into another topic.
            preview_context = {"summary": preview["summary"]["text"],
                               "traits": [{key: item[key] for key in ("key", "title", "text")} for item in preview["traits"]]}
            records = json.loads(row["chapters"])
            slots = asyncio.Semaphore(self.chapter_concurrency)

            async def chapter(reading):
                async with slots:
                    self.update(report_id, expected_lease=lease, lease_until=time.time() + self.lease_seconds)
                    months = []
                    if reading == "annual":
                        async with self.calculation_slots:
                            months = await asyncio.to_thread(thai.annual, body.year, chart["chart"]["points"]["ascendant"]["sign"])
                    bundle = self.bundle(body, chart, reading, months)
                    previous = [text for key, record in records.items() if key in CHAPTERS for kind in ("insights", "watchpoints", "actions")
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
                jobs = [group.create_task(chapter(reading)) for reading in CHAPTERS if reading not in records]
            failures = [job.result() for job in jobs if job.result() != "ready"]
            if failures:
                self.update(report_id, expected_lease=lease, full_state=failures[0], lease="", lease_until=0)
                return
            # The editor selects existing actions from concise excerpts; full details stay in the snapshot.
            actions = {f"{reading}:{index}": {"title": item["title"], "text": item["text"], "first_step": item["steps"][0], "check": item["check"]}
                       for reading in CHAPTERS for index, item in enumerate(records[reading]["story"]["actions"])}
            bundle = {"stage": "plan", "reading": "life-plan", "language": body.profile.language, "preview": preview_context,
                      "source_actions": actions, "translation_fields": {}, "fixed_translations": {}}
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
    async def get(report_id: str, request: Request, key: key_header):
        return service.get(report_id, scopes(key, request)[0])

    @router.post("/{report_id}/unlock")
    async def unlock(report_id: str, request: Request, key: key_header):
        owner, network = scopes(key, request)
        return await service.unlock(report_id, owner, network)

    @router.post("/{report_id}/feedback")
    async def feedback(report_id: str, body: Feedback, request: Request, key: key_header):
        owner, _ = scopes(key, request)
        service.row(report_id, owner)
        service.update(report_id, feedback=body.rating)
        return {"rating": body.rating}
    return router

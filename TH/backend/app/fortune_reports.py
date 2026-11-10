"""Grounded period writing, durable deduplication and bounded paid generation."""
import asyncio
from datetime import datetime, timedelta
import json
import math
import re
import secrets
import time
from zoneinfo import ZoneInfo

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from .config import Settings
from .fortune_narrative import content, narrative
from .opastro_adapter import digest
from .storage import Storage

VERSION = "wanjai-grounded-fortune-3"
BANGKOK = ZoneInfo("Asia/Bangkok")
TOPICS = ("love", "money", "family", "work")
SYSTEM = """为泰国本地占星陪伴产品写简洁、有具体内容的生活解读，仅依据输入的泰式Suriyayatra因素。OpAstro负责编辑筛选，不是经验证的预测规则或认证。
language: zh简体中文，th自然泰语，vi越南语，en美国英语。用日常语言，避免“能量场、宇宙安排、宏大力量”等空话，不反复说“边界、慢慢调整、记录开销”。温柔、尊重选择，不预设用户有伴侣、家庭纠纷、财务或心理困难；不保证事件、收益、健康结果，不要求捐款或消费。
程序直接展示计算事实：生成的所有自然语言只写可能的生活倾向、具体感受及温和建议。严禁在a/t/o中输出星体名、星座名、宫位、相位、逆行、数字、具体日期或时刻；不要复述或重算星象，不用Markdown/HTML，不显示代码、姓名、生日、模型名。可使用周初/周中/周末、月初/中旬/月末等阶段词。
输入factors用F1等短编号。placement为星座停留，positions是依次相对birth.reference_signs的位置；只有basis=ascendant才是本命宫，其余仅太阳参考，多个参考均需保留，不能挑一个当确定值。位置象征：1自我2资源3沟通4家宅5创造6日常7合作8共同责任9学习10事业11社交12休整。sign_relationship仅为按星座的关系，days是实际观测日的闭区间，不等于度数精确相位。sign_change的between仅为换座取样范围。罗睺/计都不等于西洋南北交点；样本次数不是吉凶概率。
三周期写不同重点：today用当天月亮、快星与日历，写2段当日感受和方向；week用整周变化写3段周初/中/末节奏；month优先太阳/火星/木星/土星写3段整月主线与阶段方向，不放大短暂月亮变化。没有变化就说主线持续，不虚构转折。每段围绕不同依据，不要各周期复制同一句。
长度：zh正文共180~240字，各主题t约35~55字、o约15~25字；th正文约400~650泰文字符，各主题t约100~160字符、o约50~90字符；vi/en正文约110~160词，各主题t约25~40词、o约10~18词。保留实质内容，减少铺垫与重复。
只返回JSON，缩写字段：a=一句寄语，p=正文段落，s=四主题；t=文字，o=建议，e=依据短编号。格式：{"a":"...","p":[{"t":"...","e":["F1"]},{"t":"...","e":["F2"]}],"s":{"love":{"t":"...","o":"...","e":["F3"]},"money":同结构,"family":同结构,"work":同结构}}。
每段和每个主题必须引用输入中存在的编号，每段1~2个即可；正文总共至少两个不同编号。每个主题至少引用topic_factors对应列表中的一个编号。编号只放e，计算事实只由界面呈现，不写入a/t/o。
"""


class Paragraph(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True, populate_by_name=True)
    text: str = Field(alias="t", min_length=12, max_length=1500)
    evidence_ids: list[str] = Field(alias="e", min_length=1, max_length=6)


class TopicStory(Paragraph):
    outlook: str = Field(alias="o", min_length=5, max_length=600)


class Story(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True, populate_by_name=True)
    affirmation: str = Field(alias="a", min_length=4, max_length=220)
    paragraphs: list[Paragraph] = Field(alias="p", min_length=2, max_length=4)
    topics: dict[str, TopicStory] = Field(alias="s")


class InvalidReport(Exception):
    pass


def contains_calculation_claim(text, language):
    """Fail closed on common factual astronomy labels; render those from code.

    This is a vocabulary boundary, not a semantic truth or prediction validator.
    """
    _, signs = content(language)
    local_bodies = {
        "zh": ["太阳", "月亮", "水星", "金星", "火星", "木星", "土星", "罗睺", "计都", "天王星", "上升", "宫位", "相位", "逆行"],
        "th": ["ดวงอาทิตย์", "ดวงจันทร์", "ดาวอาทิตย์", "ดาวจันทร์", "ดาวพุธ", "ดาวศุกร์", "ดาวอังคาร", "ดาวพฤหัส", "ดาวเสาร์", "ราหู", "เกตุ", "ดาวมฤตยู", "ลัคนา", "เรือน", "ภพ", "ย้ายราศี"],
        "vi": ["Mặt Trời", "Mặt Trăng", "Sao Thủy", "Sao Kim", "Sao Hỏa", "Sao Mộc", "Sao Thổ", "Sao Thiên Vương", "Rahu", "Ketu", "cung mọc", "nghịch hành", "nhà thứ", "cung thứ"],
        "en": ["Sun", "Moon", "Mercury", "Venus", "Mars", "Jupiter", "Saturn", "Uranus", "Rahu", "Ketu", "ascendant", "zodiac", "retrograde", "house", "houses", "trine", "sextile", "conjunction", "opposition"],
    }
    # Also reject English labels inside otherwise localized prose.
    terms = local_bodies[language] + [row["name"] for row in signs] + ["Neptune", "Pluto", "Chiron", "North Node", "South Node"]
    if language != "en":
        terms += local_bodies["en"]
    patterns = [re.escape(term) if language in ("zh", "th") else r"(?<!\w)" + re.escape(term) + r"(?!\w)" for term in terms]
    return bool(re.search("|".join(patterns), text, re.IGNORECASE) or re.search(r"\d|第[^，。\s]{0,8}宫|[一二三四五六七八九十]宫", text))


def grounding(value: dict, language: str):
    _, signs = content(language)
    analysis = value["analysis"]
    # No names, raw DOB, city text, messages or saved memories go to this writer.
    aliases = {factor["id"]: f"F{index + 1}" for index, factor in enumerate(analysis["factors"])}

    def day_ranges(dates):
        intervals = []
        for day in dates:
            if intervals and (datetime.fromisoformat(day) - datetime.fromisoformat(intervals[-1][1])).days == 1:
                intervals[-1][1] = day
            else:
                intervals.append([day, day])
        return [[start[5:], end[5:]] for start, end in intervals]

    factors = {}
    for factor in analysis["factors"]:
        projected = {key: factor[key] for key in ("kind", "bodies")}
        if factor["kind"] == "placement":
            projected.update(sign=factor["sign"], positions=[row["position"] for row in factor["positions"]], samples=factor["sample_count"], span=[factor["start"][5:], factor["end"][5:]])
        elif factor["kind"] == "sign_change":
            projected.update(from_sign=factor["from_sign"], sign=factor["sign"], positions=[row["position"] for row in factor["positions"]], between=[factor["start"][5:], factor["end"][5:]])
        else:
            projected.update(relationship=factor["relationship"], days=day_ranges(factor["observed_dates"]))
        factors[aliases[factor["id"]]] = projected
    return {
        "language": language, "period": value["period"],
        "period_start": value["period_start"], "period_end": value["period_end"], "time_zone": "Asia/Bangkok",
        "birth": {key: value["birth"][key] for key in ("basis", "reference_signs", "time_known", "zone_known")},
        "sign_names": {index: row["name"] for index, row in enumerate(signs)},
        "sampling": analysis["sampling"], "timeline": analysis["timeline"],
        "factors": factors,
        "topic_factors": {topic: [aliases[factor_id] for factor_id in ids] for topic, ids in analysis["topic_factors"].items()},
    }


def expand_model_story(raw: str, value: dict):
    if len(raw) > 40000:
        raise InvalidReport("oversized")
    try:
        story = Story.model_validate_json(raw)
        aliases = {f"F{index + 1}": factor["id"] for index, factor in enumerate(value["analysis"]["factors"])}
        for row in [*story.paragraphs, *story.topics.values()]:
            row.evidence_ids = [aliases[factor_id] for factor_id in row.evidence_ids]
        return story.model_dump_json()
    except (ValidationError, KeyError):
        raise InvalidReport("schema_or_evidence") from None


def validate_story(raw: str, value: dict, language: str):
    if len(raw) > 40000:
        raise InvalidReport("oversized")
    try:
        story = Story.model_validate_json(raw)
    except ValidationError:
        raise InvalidReport("schema") from None
    if set(story.topics) != set(TOPICS):
        raise InvalidReport("topics")
    allowed = {factor["id"] for factor in value["analysis"]["factors"]}
    rows = [*story.paragraphs, *story.topics.values()]
    if any(not set(row.evidence_ids) <= allowed for row in rows):
        raise InvalidReport("unknown_evidence")
    if len({item for row in story.paragraphs for item in row.evidence_ids}) < 2:
        raise InvalidReport("thin_evidence")
    if any(not set(story.topics[topic].evidence_ids) & set(value["analysis"]["topic_factors"][topic]) for topic in TOPICS):
        raise InvalidReport("topic_evidence")
    text = " ".join([story.affirmation, *(row.text for row in rows), *(row.outlook for row in story.topics.values())])
    if "<" in text or "```" in text or re.search(r"[\x00-\x08\x0b-\x1f]", text):
        raise InvalidReport("format")
    if contains_calculation_claim(text, language):
        raise InvalidReport("calculation_in_prose")
    # Cheap script checks catch an upstream language switch; meaning still needs review.
    if language == "th" and len(re.findall(r"[\u0e00-\u0e7f]", text)) < 30:
        raise InvalidReport("language")
    if language == "zh" and len(re.findall(r"[\u4e00-\u9fff]", text)) < 30:
        raise InvalidReport("language")
    if language in ("vi", "en") and len(re.findall(r"[a-zA-Z]", text)) < 80:
        raise InvalidReport("language")
    return {
        "version": VERSION, "source": "ai", "language": language,
        "date": value["period_start"], "affirmation": story.affirmation,
        "paragraphs": [row.text for row in story.paragraphs],
        "paragraph_evidence": [row.evidence_ids for row in story.paragraphs],
        "topics": {key: row.model_dump() for key, row in story.topics.items()},
    }


class FortuneReports:
    def __init__(self, store: Storage, settings: Settings, slots: asyncio.Semaphore):
        self.store, self.settings, self.slots = store, settings, slots
        with store.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS fortune_reports(cache_key TEXT PRIMARY KEY, expires REAL NOT NULL, pending_until REAL NOT NULL DEFAULT 0, retry_after REAL NOT NULL DEFAULT 0, lease TEXT NOT NULL DEFAULT '', payload TEXT);
                CREATE INDEX IF NOT EXISTS fortune_reports_expiry ON fortune_reports(expires);
                CREATE TABLE IF NOT EXISTS fortune_usage(scope TEXT NOT NULL, created REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS fortune_usage_scope_created ON fortune_usage(scope,created);
            """)

    @property
    def provider(self):
        return self.settings.fortune_provider

    @property
    def config(self):
        return self.settings.providers.get(self.provider)

    @property
    def enabled(self):
        return bool(self.config and self.config.enabled)

    def key(self, value, profile, owner):
        # Cache identity ignores free-form names/city, current minute and current
        # weekday for week/month. The entire fixed analysis period is fingerprinted.
        birth = {key: profile.get(key) for key in ("birth_date", "birth_time", "timezone", "country_code", "location_id", "latitude", "longitude")}
        return digest({"writer": VERSION, "engine": value["engine"], "guidance": value["guidance_version"], "analysis": value["analysis"]["signature"], "birth": birth, "language": profile["language"], "owner": owner, "provider": self.provider, "model": self.config.model if self.config else None, "host": self.config.base_url if self.config else None})

    def expiry(self, value):
        return (datetime.fromisoformat(value["period_end"]).replace(tzinfo=BANGKOK) + timedelta(days=1)).timestamp()

    def cached(self, key):
        with self.store.connect() as db:
            row = db.execute("SELECT payload FROM fortune_reports WHERE cache_key=? AND expires>? AND payload IS NOT NULL", (key, time.time())).fetchone()
        return json.loads(row["payload"]) if row else None

    def preview(self, value, profile, owner):
        story = self.cached(self.key(value, profile, owner))
        return {
            **value, "narrative": story or {**narrative(value, profile["language"]), "source": "rules"},
            "generation": {"available": self.enabled, "state": "ready" if story else "rules", "cached": bool(story)},
        }

    def claim(self, key, owner, network, expires):
        now, lease = time.time(), secrets.token_hex(12)
        with self.store.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("DELETE FROM fortune_reports WHERE rowid IN (SELECT rowid FROM fortune_reports WHERE expires<? LIMIT 512)", (now,))
            db.execute("DELETE FROM fortune_reports WHERE cache_key=? AND expires<=?", (key, now))
            db.execute("DELETE FROM fortune_usage WHERE created<?", (now - 86400,))
            row = db.execute("SELECT payload,pending_until,retry_after FROM fortune_reports WHERE cache_key=?", (key,)).fetchone()
            if row and row["payload"]:
                return "cached", "", {}
            if row and row["pending_until"] > now:
                return "pending", "", {"retry_after": max(1, math.ceil(row["pending_until"] - now))}
            if row and row["retry_after"] > now:
                return "cooldown", "", {"retry_after": max(1, math.ceil(row["retry_after"] - now))}
            limits = [(owner, self.settings.fortune_per_minute, self.settings.fortune_per_day), (network, 15, self.settings.fortune_network_per_day)]
            for scope, minute_limit, day_limit in limits:
                minute, day = db.execute("SELECT COALESCE(SUM(created>=?),0),COUNT(*) FROM fortune_usage WHERE scope=? AND created>=?", (now - 60, scope, now - 86400)).fetchone()
                if minute >= minute_limit or day >= day_limit:
                    window, limit = (86400, day_limit) if day >= day_limit else (60, minute_limit)
                    # A rolling limit frees a slot when the corresponding usage row expires.
                    oldest = db.execute(
                        "SELECT created FROM fortune_usage WHERE scope=? AND created>=? ORDER BY created LIMIT 1 OFFSET ?",
                        (scope, now - window, max(0, (day if window == 86400 else minute) - limit)),
                    ).fetchone()
                    wait = max(1, math.ceil(oldest[0] + window - now)) if oldest else window
                    personal = scope == owner and owner.startswith("account:")
                    return "limited", "", {"limit_scope": "personal" if personal else "network", "retry_after": wait}
            db.executemany("INSERT INTO fortune_usage VALUES (?,?)", [(owner, now), (network, now)])
            db.execute("INSERT INTO fortune_reports(cache_key,expires,pending_until,lease) VALUES (?,?,?,?) ON CONFLICT(cache_key) DO UPDATE SET expires=excluded.expires,pending_until=excluded.pending_until,lease=excluded.lease", (key, expires, now + 45, lease))
        return "claimed", lease, {}

    def finish(self, key, lease, story=None):
        with self.store.connect() as db:
            db.execute("UPDATE fortune_reports SET payload=?,pending_until=0,retry_after=? WHERE cache_key=? AND lease=?", (json.dumps(story, ensure_ascii=False) if story else None, 0 if story else time.time() + 45, key, lease))

    async def write(self, value, language):
        config = self.config
        payload = {
            "model": config.model, "messages": [{"role": "system", "content": SYSTEM}, {"role": "user", "content": json.dumps(grounding(value, language), ensure_ascii=False, separators=(",", ":"))}],
            "response_format": {"type": "json_object"}, "stream": False,
            "max_tokens": 2800, "temperature": 0.75,
        }
        if self.provider == "qwen":
            payload["enable_thinking"] = False
        if self.provider == "openai":
            payload["max_completion_tokens"] = payload.pop("max_tokens")
        if self.provider == "kimi" and config.model.startswith("kimi-k"):
            payload["reasoning_effort"] = "low"
        async with httpx.AsyncClient(timeout=httpx.Timeout(27, connect=5)) as client:
            response = await client.post(config.base_url.rstrip("/") + "/chat/completions", headers={"Authorization": f"Bearer {config.key}"}, json=payload)
            if response.status_code != 200 or len(response.content) > 250000:
                raise InvalidReport("upstream")
            try:
                choice = response.json()["choices"][0]
                if not isinstance(choice, dict):
                    raise InvalidReport("protocol")
                if choice.get("finish_reason") != "stop":
                    raise InvalidReport("incomplete")
                raw = choice["message"]["content"]
                if not isinstance(raw, str):
                    raise InvalidReport("content")
            except (KeyError, IndexError, ValueError, TypeError):
                raise InvalidReport("protocol") from None
        story = validate_story(expand_model_story(raw, value), value, language)
        return {**story, "generated_at": datetime.now(BANGKOK).isoformat(), "provider": self.provider, "model": config.model, "analysis_version": value["analysis"]["adapter_version"]}

    async def generate(self, value, profile, owner, network):
        key = self.key(value, profile, owner)
        cached = self.cached(key)
        if cached:
            return {"narrative": cached, "generation": {"available": self.enabled, "state": "ready", "cached": True}}
        fallback = {**narrative(value, profile["language"]), "source": "rules"}
        state, lease, retry = self.claim(key, owner, network, self.expiry(value)) if self.enabled else ("unconfigured", "", {})
        if state == "cached":
            return {"narrative": self.cached(key) or fallback, "generation": {"available": self.enabled, "state": "ready", "cached": True}}
        if state == "claimed":
            try:
                async with asyncio.timeout(32):
                    async with self.slots:
                        story = await self.write(value, profile["language"])
                self.finish(key, lease, story)
                return {"narrative": story, "generation": {"available": True, "state": "ready", "cached": False}}
            except asyncio.CancelledError:
                self.finish(key, lease)
                raise
            except (InvalidReport, httpx.HTTPError, TimeoutError):
                self.finish(key, lease)
                state = "unavailable"
                retry = {"retry_after": 45}
        return {"narrative": fallback, "generation": {"available": self.enabled, "state": "fallback", "reason": state, "cached": False, **retry}}

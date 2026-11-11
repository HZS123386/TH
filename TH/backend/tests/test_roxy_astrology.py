"""Contract and report-flow checks using a real Roxy response for a synthetic birth."""
import asyncio
from copy import deepcopy
from datetime import datetime
import json
from pathlib import Path
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.astrology import CHAPTERS, VERSION, RoxyAstrology, validate_natal
from backend.app.bazi_reports import InvalidBaziReport
from backend.app.config import ProviderConfig, Settings
from backend.app.life_report_content import LifeWriter, writing_progress
from backend.app.life_reports import LifeInput
from backend.app.main import create_app
from backend.app.roxy import RoxyError
from backend.app.storage import Storage

GOLDEN = json.loads((Path(__file__).parent / "fixtures/roxy-western-natal.json").read_text(encoding="utf-8"))
PROFILE = {"birth_date": "1992-04-15", "birth_time": "07:15", "timezone": "Asia/Bangkok", "birthplace": "Bangkok",
           "country_code": "TH", "latitude": 13.7563, "longitude": 100.5018, "language": "zh"}
HEADERS = {"X-Report-Key": "synthetic-roxy-report-contract-owner"}
TEXT = "你做决定时往往先确认自己能够承担什么，再逐步增加投入。遇到不同意见时，可以把理由和需要的支持讲清楚，留出根据实际反馈调整的空间。"
DETAIL = "先把需要确认的条件写清楚，再与对方核对。"


def draft(bundle):
    base = {"language": bundle["language"], "reading": bundle["reading"]}
    if bundle["stage"] == "plan":
        ids = list(bundle["source_actions"])
        return {**base, "phases": [{"key": key, "title": title, "text": TEXT,
                                   "action_ids": ids[index * 2:index * 2 + 2]}
                                  for index, (key, title) in enumerate(zip(("observe", "adjust", "review"), ("观察做法", "调整顺序", "检视结果")))]}
    def ids(topic=None):
        first = (bundle["citation_rules"]["trait_ids"][topic] if topic else bundle["topic_evidence"])[0]
        second = next(key for key in bundle["citation_rules"]["supporting_natal_ids"] if key != first)
        return [first, second]
    summary = {"text": DETAIL, "evidence_ids": ids()}
    if bundle["stage"] == "preview":
        return {**base, "summary": summary, "traits": [{"key": key, "title": title,
                "text": TEXT + "例如面对临时安排，可以先问清楚目标和完成标准，决定从一个可检查的小范围开始。这样既能保留自己的判断，也给双方留下沟通和调整的余地。",
                "evidence_ids": ids(key)} for key, title in zip(("strength", "decisions", "relationships"), ("发挥长处", "判断选择", "表达需要"))]}
    def point(title):
        topic = {"natal": "本命", "career": "工作", "wealth": "财务", "love": "相处", "risk": "提醒"}[bundle["reading"]]
        return {"title": topic + title, "text": topic + title + TEXT, "evidence_ids": ids()}
    return {**base, "summary": summary,
            "insights": [{**point("主动确认"), "example": DETAIL, "response": DETAIL}],
            "watchpoints": [{**point("留出余地"), "signals": [DETAIL], "response": DETAIL, "example": DETAIL}],
            "actions": [{**point(title), "steps": [DETAIL, "完成后对照原先约定，记录还需要调整的地方。"],
                         "example": DETAIL, "pitfall": DETAIL, "check": DETAIL} for title in ("核对条件", "检视反馈")]}


@pytest.fixture
def transport(monkeypatch):
    calls = []
    mode = {"status": 200}
    real_client = httpx.AsyncClient
    def handle(request):
        assert request.url.path == "/api/v2/astrology/natal-chart"
        assert request.headers["X-API-Key"] == "roxy-server-test-key"
        assert request.url.params["lang"] in ("zh-Hans", "en")
        body = json.loads(request.content)
        calls.append(body)
        result = deepcopy(GOLDEN)
        instant = datetime.fromisoformat(body["date"] + "T" + body["time"]).replace(tzinfo=ZoneInfo(body["timezone"]))
        result["birthDetails"].update({key: body[key] for key in ("date", "time", "latitude", "longitude")},
                                     timezone=instant.utcoffset().total_seconds() / 3600)
        return httpx.Response(mode["status"], json=result)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(**kwargs, transport=httpx.MockTransport(handle)))
    return calls, mode


def settings(tmp_path):
    return Settings(database_path=str(tmp_path / "roxy.db"), life_astrology_provider="roxy", roxy_enabled=True,
                    roxy_api_key="roxy-server-test-key", providers={"qwen": ProviderConfig("writer-test-key", "https://model.example/v1", "qwen3.7-plus")},
                    bazi_reports_per_minute=100, bazi_reports_per_day=100)


@pytest.mark.parametrize("known", [True, False])
def test_natal_contract_is_reused_and_unknown_time_excludes_sensitive_factors(tmp_path, transport, known):
    config = settings(tmp_path)
    adapter = RoxyAstrology(config, Storage(config.database_path))
    profile = {**PROFILE, "birth_time": PROFILE["birth_time"] if known else None}
    body = LifeInput.model_validate({"profile": profile, "year": 2026, "report_kind": "fortune"})
    async def calculate():
        return await asyncio.gather(*(adapter.calculate(body.profile, "owner", "network") for _ in range(2)))
    charts = asyncio.run(calculate())
    assert len(transport[0]) == 1
    assert transport[0][0]["time"] == ("07:15:00" if known else "12:00:00")
    assert transport[0][0]["timezone"] == "Asia/Bangkok"
    assert transport[0][0]["houseSystem"] == "placidus"
    assert charts[0]["raw"]["planets"][0]["longitude"] == pytest.approx(25.2890491562)
    bundle = adapter.bundle(body, charts[0], "career")
    assert bundle["evidence"]["P_jupiter"]["retrograde"] is True
    view = adapter.chart_view(charts[0], "zh")
    if known:
        assert len(view["houses"]) == 12 and view["aspects"]
        assert bundle["evidence"]["P_sun"]["interpretation"]
    else:
        assert not view["houses"] and not view["aspects"]
        assert all(p["house"] is None and p["id"] not in ("moon", "ascendant", "midheaven") for p in view["planets"])
        assert {f["type"] for f in bundle["evidence"].values()} == {"planet"}
        assert all("interpretation" not in f for f in bundle["evidence"].values())


@pytest.mark.parametrize("country,identifier,zone,latitude,longitude", [
    ("CN", "geonames:1816670", "Asia/Shanghai", 39.9075, 116.39723),
    ("TH", "geonames:1609350", "Asia/Bangkok", 13.75398, 100.50144),
])
def test_selected_city_supplies_coordinates_and_original_local_timezone(tmp_path, transport, country, identifier, zone, latitude, longitude):
    config = settings(tmp_path)
    adapter = RoxyAstrology(config, Storage(config.database_path))
    profile = {key: value for key, value in PROFILE.items() if key not in ("latitude", "longitude")}
    profile.update(country_code=country, location_id=identifier, timezone=zone)
    body = LifeInput.model_validate({"profile": profile, "year": 2026})
    asyncio.run(adapter.calculate(body.profile, "owner", "network"))
    request = transport[0][0]
    assert request["latitude"] == latitude and request["longitude"] == longitude
    assert request["timezone"] == zone and request["time"] == "07:15:00"


@pytest.mark.parametrize("change", ["coordinates", "houses", "longitude", "system"])
def test_natal_response_rejects_mismatched_or_invalid_calculations(change):
    result = deepcopy(GOLDEN)
    body = {**PROFILE, "date": PROFILE["birth_date"], "time": "07:15:00", "houseSystem": "placidus", "nodeType": "true"}
    if change == "coordinates":
        result["birthDetails"]["latitude"] = 0
    elif change == "houses":
        result["houses"].pop()
    elif change == "longitude":
        result["planets"][0]["longitude"] = float("nan")
    else:
        result["houseSystem"] = "whole-sign"
    with pytest.raises(RoxyError, match="roxy_invalid_response"):
        validate_natal("natal", result, body)


def test_report_unlock_contains_all_six_topics_without_recalculating(tmp_path, monkeypatch, transport):
    calls = []
    async def write(self, bundle, **kwargs):
        calls.append(deepcopy(bundle))
        return self.validate(json.dumps(draft(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    config = settings(tmp_path)
    with TestClient(create_app(config)) as client:
        body = {"profile": PROFILE, "year": 2026, "report_kind": "fortune"}
        response = client.post("/api/life-reports", json=body, headers=HEADERS)
        assert response.status_code == 200, response.text
        preview = response.json()
        assert preview["preview_state"] == "ready", preview
        assert preview["format"] == "western-compact" and preview["method"]["house_system"] == "placidus"
        assert not preview["chapters"] and preview["plan"] is None
        assert len(calls) == 1 and len(transport[0]) == 1
        path = "/api/life-reports/" + preview["id"]
        assert client.get(path, headers={"X-Report-Key": "another-synthetic-report-contract-owner"}).status_code == 404
        client.post(path + "/unlock", headers=HEADERS)
        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        full = client.get(path, headers=HEADERS).json()
        assert full["full_state"] == "ready", full
        assert [c["key"] for c in full["chapters"]] == list(CHAPTERS)
        assert len(full["plan"]["phases"]) == 3 and full["progress"] == {"completed": 6, "total": 6}
        assert full["generation_progress"]["percent"] == 100
        assert len(transport[0]) == 1 and len(calls) == 7  # One free + five topics + one action plan.
        assert all(b["format"] == VERSION for b in calls)
        # Changing configuration cannot rewrite a previously calculated report's source.
        config.life_astrology_provider = "thai"
        assert client.get(path, headers=HEADERS).json()["method"]["name"] == "RoxyAPI Western Astrology"
        for b in calls:
            if b["stage"] == "chapter":
                assert 90 <= writing_progress(json.dumps(draft(b), ensure_ascii=False), "chapter", compact=True) < 100


def test_roxy_failure_does_not_fall_back_to_thai_or_call_writer(tmp_path, monkeypatch, transport):
    transport[1]["status"] = 503
    async def forbidden(*args, **kwargs):
        pytest.fail("the writer must not run without calculated evidence")
    monkeypatch.setattr(LifeWriter, "write", forbidden)
    with TestClient(create_app(settings(tmp_path))) as client:
        response = client.post("/api/life-reports", json={"profile": PROFILE, "year": 2026}, headers=HEADERS)
        assert response.status_code == 503 and "roxy_unavailable" in response.text


def test_compact_writer_rejects_foreign_evidence_and_excessive_text():
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN}
    bundle = RoxyAstrology.bundle(body, chart, "natal")
    valid = draft(bundle)
    LifeWriter.validate(json.dumps(valid, ensure_ascii=False), bundle)
    valid["insights"][0]["evidence_ids"] = ["M1_sun", "H99"]
    with pytest.raises(InvalidBaziReport):
        LifeWriter.validate(json.dumps(valid, ensure_ascii=False), bundle)
    valid = draft(bundle)
    valid["actions"][0]["text"] = TEXT * 3
    with pytest.raises(InvalidBaziReport, match="compact"):
        LifeWriter.validate(json.dumps(valid, ensure_ascii=False), bundle)

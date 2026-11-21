"""Contract and report-flow checks using a real Roxy response for a synthetic birth."""
import asyncio
from copy import deepcopy
from datetime import date, datetime, timedelta
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
from backend.app.report_languages import REGIONAL_LANGUAGES

GOLDEN = json.loads((Path(__file__).parent / "fixtures/roxy-western-natal.json").read_text(encoding="utf-8"))
PROFILE = {"birth_date": "1992-04-15", "birth_time": "07:15", "timezone": "Asia/Bangkok", "birthplace": "Bangkok",
           "country_code": "TH", "latitude": 13.7563, "longitude": 100.5018, "language": "zh"}
HEADERS = {"X-Report-Key": "synthetic-roxy-report-contract-owner"}
TEXT = "你做决定时往往先确认自己能够承担什么，再逐步增加投入。遇到不同意见时，可以把理由和需要的支持讲清楚，留出根据实际反馈调整的空间。"
DETAIL = "先把需要确认的条件写清楚，再与对方核对。"


@pytest.fixture(autouse=True)
def legacy_report_contract(monkeypatch):
    # This module preserves the existing six-topic contract; personal flows have their own tests.
    monkeypatch.setattr("backend.app.life_reports.personal_chart", lambda chart: False)


def unlock_after_simulated_payment(client, path):
    assert client.post(path + "/unlock", headers=HEADERS).status_code == 402
    order = client.post(path + "/payment", json={}, headers=HEADERS)
    assert order.status_code == 200, order.text
    paid = client.post(path + "/payment/simulate", json={"reference": order.json()["reference"]}, headers=HEADERS)
    assert paid.status_code == 200 and paid.json()["paid"] is True
    assert client.post(path + "/unlock", headers=HEADERS).status_code == 200


def forecast_fixture(body):
    start = date.fromisoformat(body["startDate"])
    birth = dict(body["birthData"])
    instant = datetime.fromisoformat(birth["date"] + "T" + birth["time"]).replace(tzinfo=ZoneInfo(birth["timezone"]))
    birth["timezone"] = instant.utcoffset().total_seconds() / 3600
    events = []
    for index, target in enumerate(("Sun", "Mercury", "Venus", "Mars")):
        day = (start + timedelta(days=7 + index * 14)).isoformat()
        events.append({"date": day, "datetime": day + "T12:00:00Z", "domain": "western", "type": "transit-aspect",
                       "body": "Jupiter" if index % 2 == 0 else "Saturn", "target": target,
                       "aspect": "TRINE" if index % 2 == 0 else "SQUARE", "orb": .1,
                       "description": "A calculated transit for a synthetic test subject.", "significance": 90 - index})
    return {"birthData": birth, "startDate": body["startDate"], "endDate": body["endDate"], "count": len(events), "events": events}


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
    timing = bundle["citation_rules"].get("timing_ids", [])
    summary = {"text": DETAIL, "evidence_ids": [timing[0], ids()[1]] if timing and bundle["stage"] == "chapter" else ids()}
    if bundle["stage"] == "preview":
        summary["text"] = "你重视清楚踏实的选择，也愿意通过交流了解自己。"
        identity = (
            "你习惯先说清自己的想法，再认真理解不同意见。目标明确时，你更容易稳定投入，也能让合作顺畅。",
            "面对不同选择，你愿意先看清方向再行动。条件变化时，可以先试一个小范围，再按反馈调整。",
            "在亲近关系里，你重视坦诚，也愿意回应对方。当想法不同时，说清在意之处会比急着求同更舒服。",
        )
        result = {**base, "summary": summary, "traits": [{"key": key, "title": title,
                "text": text, "evidence_ids": ids(key)}
                for key, title, text in zip(("strength", "decisions", "relationships"), ("发挥长处", "判断选择", "表达需要"), identity)]}
        if bundle.get("preview_layout") == "four-questions":
            sample = [bundle["citation_rules"].get("sample_ids", bundle["topic_evidence"])[0], ids()[1]]
            result.update(
                environment={"text": "你更适合目标清楚、能够交流想法的环境。有人愿意听完你的意见，再一起确定分工时，你的投入往往更稳定，也更容易看见自己的长处。", "evidence_ids": ids()},
                favorable={"text": "在工作协作中，先理解目标再表达想法，让你更容易发挥长处。遇到意见不同的情境，可以把在意的标准讲清楚，再听对方怎样安排，让讨论有一个共同的起点。", "evidence_ids": sample},
                unfavorable={"text": "当每个人对结果的期待不同时，你可能会花时间反复确认。若等到所有疑问都有答案，事情容易迟迟无法开始。先约定能试做的小范围，再按实际反馈调整。", "evidence_ids": sample},
                response={"text": "先选一个正在考虑的工作问题，把最在意的条件说清楚。", "evidence_ids": sample},
                recent={"text": "接下来可以留意工作沟通中的节奏与边界。有人提出新安排时，先听清双方最看重的结果，再选一个能核对的小步骤。", "evidence_ids": [timing[0], ids()[1]]} if timing else None)
        return result
    def point(title, timing_index=None):
        topic = {"natal": "本命", "career": "工作", "wealth": "财务", "love": "相处", "risk": "提醒"}[bundle["reading"]]
        citations = [timing[min(timing_index, len(timing) - 1)], ids()[1]] if timing and timing_index is not None else ids()
        return {"title": topic + title, "text": topic + title + TEXT, "evidence_ids": citations}
    result = {**base, "summary": summary,
            "insights": [{**point("主动确认"), "example": DETAIL, "response": DETAIL}],
            "watchpoints": [{**point("留出余地"), "signals": [DETAIL], "response": DETAIL, "example": DETAIL}],
            "actions": [{**point(title, index), "steps": [DETAIL, "完成后对照原先约定，记录还需要调整的地方。"],
                         "example": DETAIL, "pitfall": DETAIL, "check": DETAIL} for index, title in enumerate(("核对条件", "检视反馈"))]}
    if bundle["reading"] == "career":
        for key, target in (("favorable", result["insights"][0]), ("unfavorable", result["watchpoints"][0]), ("recent", result["summary"])):
            if source := bundle.get("free_excerpt", {}).get(key):
                target.update(deepcopy(source))
    return result


@pytest.fixture
def transport(monkeypatch):
    calls = []
    mode = {"status": 200}
    real_client = httpx.AsyncClient
    def handle(request):
        if request.url.path == "/api/v2/forecast/transits":
            return httpx.Response(mode["status"], json=forecast_fixture(json.loads(request.content)))
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


def settings(postgres_url):
    return Settings(database_url=postgres_url, life_astrology_provider="roxy", roxy_enabled=True,
                    roxy_api_key="roxy-server-test-key", providers={"qwen": ProviderConfig("writer-test-key", "https://model.example/v1", "qwen3.7-plus")},
                    bazi_reports_per_minute=100, bazi_reports_per_day=100)


@pytest.fixture
def openai_transport(monkeypatch):
    calls, calculations = [], []
    mode = {"status": 200, "proxies": []}
    real_client = httpx.AsyncClient

    def handle(request):
        if request.url.path == "/api/v2/forecast/transits":
            return httpx.Response(200, json=forecast_fixture(json.loads(request.content)))
        if request.url.path == "/api/v2/astrology/natal-chart":
            assert request.headers["X-API-Key"] == "roxy-server-test-key"
            body = json.loads(request.content)
            calculations.append(body)
            result = deepcopy(GOLDEN)
            instant = datetime.fromisoformat(body["date"] + "T" + body["time"]).replace(tzinfo=ZoneInfo(body["timezone"]))
            result["birthDetails"].update({key: body[key] for key in ("date", "time", "latitude", "longitude")},
                                         timezone=instant.utcoffset().total_seconds() / 3600)
            return httpx.Response(200, json=result)

        # Any attempted Qwen fallback or unexpected external destination fails the test.
        assert str(request.url) == "https://openai.example/v1/chat/completions"
        assert request.headers["Authorization"] == "Bearer synthetic-openai-key"
        payload = json.loads(request.content)
        assert payload["model"] == "test-gpt" and payload["stream"] is True
        assert payload["max_completion_tokens"] == 9000 and "max_tokens" not in payload
        assert payload["stream_options"] == {"include_usage": True}
        assert payload["reasoning_effort"] == "low" and "enable_thinking" not in payload
        assert payload["response_format"]["type"] == "json_schema"
        bundle = json.loads(payload["messages"][1]["content"])
        calls.append(bundle)
        if mode["status"] != 200:
            return httpx.Response(mode["status"], json={"error": {"message": "private upstream account details"}})
        if bundle["stage"] != "plan":
            assert bundle["method"]["provider"] == "RoxyAPI"
            assert bundle["evidence"]["P_sun"]["interpretation"]
            assert "birth_date" not in bundle
        raw = json.dumps(draft(bundle), ensure_ascii=False)
        identifier = f"synthetic-openai-{len(calls)}"
        packets = [{"id": identifier, "choices": [{"delta": {"content": raw[index:index + 32]}, "finish_reason": None}]}
                   for index in range(0, len(raw), 32)]
        packets += [
            {"id": identifier, "choices": [{"delta": {}, "finish_reason": "stop"}]},
            {"id": identifier, "choices": [], "usage": {"prompt_tokens": 100, "completion_tokens": 50,
                                                           "prompt_tokens_details": {"cached_tokens": 20}}},
        ]
        return httpx.Response(200, headers={"content-type": "text/event-stream"},
                              text="".join("data: " + json.dumps(packet, ensure_ascii=False) + "\n\n" for packet in packets) + "data: [DONE]\n\n")

    def client(**kwargs):
        # Record proxy routing without allowing test requests to reach a real proxy.
        mode["proxies"].append(kwargs.pop("proxy", None))
        return real_client(transport=httpx.MockTransport(handle), **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", client)
    return calls, calculations, mode


def test_openai_stream_writes_free_preview_and_all_six_roxy_topics_with_usage(postgres_url, openai_transport):
    config = settings(postgres_url)
    config.fortune_provider = "openai"
    config.providers["openai"] = ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt",
                                                reasoning_effort="low", proxy_url="http://synthetic-user:synthetic-password@127.0.0.1:18080")
    calls, calculations, mode = openai_transport
    with TestClient(create_app(config)) as client:
        body = {"profile": PROFILE, "year": 2026, "report_kind": "fortune"}
        response = client.post("/api/life-reports", json=body, headers=HEADERS)
        assert response.status_code == 200, response.text
        preview = response.json()
        assert preview["preview_state"] == "ready" and preview["format"] == "western-compact"
        assert not preview["chapters"] and preview["plan"] is None
        assert len(calls) == len(calculations) == 1
        path = "/api/life-reports/" + preview["id"]
        unlock_after_simulated_payment(client, path)

        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        full = client.get(path, headers=HEADERS).json()
        assert full["full_state"] == "ready" and full["preview"] == preview["preview"]
        assert [row["key"] for row in full["chapters"]] == list(CHAPTERS)
        assert len(full["plan"]["phases"]) == 3
        assert full["progress"] == {"completed": 6, "total": 6}
        assert full["generation_progress"]["percent"] == 100
        assert len(calculations) == 1 and len(calls) == 7
        assert [bundle["stage"] for bundle in calls].count("chapter") == 5
        assert calls[-1]["stage"] == "plan"
        assert mode["proxies"].count(config.providers["openai"].proxy_url) == 7
        assert mode["proxies"].count(None) == 2  # Natal and transit calls keep their independent configuration.
        assert "synthetic-openai-key" not in repr(config.providers["openai"])
        assert "synthetic-password" not in repr(config.providers["openai"])
        with client.app.state.store.connect() as db:
            usage = db.execute("SELECT * FROM report_model_usage WHERE report_id=%s ORDER BY id", (preview["id"],)).fetchall()
        assert len(usage) == 7
        assert [row["phase"] for row in usage] == ["preview"] + ["full"] * 6
        assert all(row["provider"] == "openai" and row["model"] == "test-gpt" and row["validated"] for row in usage)
        assert all((row["prompt_tokens"], row["completion_tokens"], row["cached_tokens"], row["usage_received"]) == (100, 50, 20, 1)
                   for row in usage)
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == preview["id"]
        assert client.get(path, headers=HEADERS).json() == full
        assert len(calls) == 7


def test_openai_auth_failure_keeps_report_unavailable_without_qwen_fallback(postgres_url, openai_transport):
    config = settings(postgres_url)
    config.fortune_provider = "openai"
    config.providers["openai"] = ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt",
                                                reasoning_effort="low")
    calls, calculations, mode = openai_transport
    mode["status"] = 401
    with TestClient(create_app(config)) as client:
        response = client.post("/api/life-reports", json={"profile": PROFILE, "year": 2026}, headers=HEADERS)
        assert response.status_code == 200
        result = response.json()
        assert result["preview_state"] == "unavailable" and result["preview"] is None
        assert not result["chapters"] and result["plan"] is None
        assert "private upstream account details" not in response.text
        assert len(calls) == len(calculations) == 1


@pytest.mark.parametrize("known", [True, False])
def test_natal_contract_is_reused_and_unknown_time_excludes_sensitive_factors(postgres_url, transport, known):
    config = settings(postgres_url)
    adapter = RoxyAstrology(config, Storage(config.database_url))
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
def test_selected_city_supplies_coordinates_and_original_local_timezone(postgres_url, transport, country, identifier, zone, latitude, longitude):
    config = settings(postgres_url)
    adapter = RoxyAstrology(config, Storage(config.database_url))
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


def test_report_unlock_contains_all_six_topics_without_recalculating(postgres_url, monkeypatch, transport):
    calls = []
    async def write(self, bundle, **kwargs):
        calls.append(deepcopy(bundle))
        return self.validate(json.dumps(draft(bundle), ensure_ascii=False), bundle)
    monkeypatch.setattr(LifeWriter, "write", write)
    config = settings(postgres_url)
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
        assert client.post(path + "/unlock", headers=HEADERS).status_code == 402
        created = client.post(path + "/payment", headers=HEADERS)
        assert created.status_code == 200, created.text
        order = created.json()
        confirmed = client.post(path + "/payment/simulate", headers=HEADERS, json={"reference": order["reference"]})
        assert confirmed.json() == {"paid": True}
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


def test_roxy_failure_does_not_fall_back_to_thai_or_call_writer(postgres_url, monkeypatch, transport):
    transport[1]["status"] = 503
    async def forbidden(*args, **kwargs):
        pytest.fail("the writer must not run without calculated evidence")
    monkeypatch.setattr(LifeWriter, "write", forbidden)
    with TestClient(create_app(settings(postgres_url))) as client:
        response = client.post("/api/life-reports", json={"profile": PROFILE, "year": 2026}, headers=HEADERS)
        assert response.status_code == 503 and "roxy_unavailable" in response.text


@pytest.mark.parametrize("language", ["en", "vi", "my", "km", "lo", "ms", "id"])
def test_landing_languages_generate_and_restore_complete_western_reports(postgres_url, monkeypatch, transport, language):
    regional = json.loads((Path(__file__).parent / "fixtures/regional-writing.json").read_text(encoding="utf-8"))
    detail = {
        "en": "Ask what matters most to each person, then choose one small change you can comfortably try.",
        "vi": "Bạn có thể hỏi điều mỗi người coi trọng, rồi chọn một thay đổi nhỏ để thử trong hoàn cảnh phù hợp.",
        **{code: copy["detail"] for code, copy in regional.items()},
    }[language]
    paragraph = {
        "en": "When different expectations compete for your attention, you may feel more comfortable after a clear conversation. Sharing what matters to you can make a choice feel more manageable, while leaving room to adapt if new information emerges.",
        "vi": "Khi nhiều mong đợi cùng xuất hiện, bạn có thể thấy dễ chịu hơn sau một cuộc trao đổi rõ ràng. Nói điều mình coi trọng giúp lựa chọn bớt nặng nề, đồng thời chừa chỗ điều chỉnh khi có thông tin mới.",
        **{code: copy["paragraph"] for code, copy in regional.items()},
    }[language]
    titles = {
        "en": ["A comfortable rhythm", "Room to adjust", "Sharing your needs", "Trying a small change"],
        "vi": ["Tìm nhịp phù hợp", "Chừa chỗ điều chỉnh", "Bày tỏ nhu cầu", "Thử một thay đổi"],
        **{code: copy["titles"] for code, copy in regional.items()},
    }[language]
    seen = []

    async def write(self, bundle, **kwargs):
        seen.append(bundle)
        assert "vi=natural Vietnamese" in self.prompt(bundle)
        story = draft(bundle)
        def sample_text(low, high, *, alternate=False):
            value = detail + " " + paragraph if alternate else paragraph
            while len(value) < low:
                value += " " + detail
            return value[:high].rstrip()
        if "summary" in story:
            story["summary"]["text"] = sample_text(60, 85) if bundle["stage"] == "preview" else detail
        for key in ("environment", "favorable", "unfavorable", "recent", "response"):
            if story.get(key):
                bounds = {"environment": (140, 170), "favorable": (180, 195), "unfavorable": (180, 195), "recent": (110, 140), "response": (60, 85)}[key]
                story[key]["text"] = sample_text(*bounds, alternate=key == "unfavorable")
        rows = story.get("traits", []) + story.get("insights", []) + story.get("watchpoints", []) + story.get("actions", []) + story.get("phases", [])
        topic = {
            "en": {"natal": "Personal", "career": "Work", "wealth": "Money", "love": "Relationships", "risk": "Pressures"},
            "vi": {"natal": "Cá nhân", "career": "Công việc", "wealth": "Tiền bạc", "love": "Gắn bó", "risk": "Áp lực"},
            **{code: dict(zip(CHAPTERS, copy["western_titles"])) for code, copy in REGIONAL_LANGUAGES.items()},
        }[language].get(bundle["reading"], "Next" if language == "en" else "Tiếp theo")
        if language in REGIONAL_LANGUAGES and bundle["reading"] not in CHAPTERS:
            topic = REGIONAL_LANGUAGES[language]["report_title"]
        for index, point in enumerate(rows):
            point["title"] = topic + ": " + titles[index]
            point["text"] = sample_text(110, 135) if bundle["stage"] == "preview" else point["title"] + ". " + (paragraph if bundle["stage"] != "plan" else detail)
            for field in ("example", "response", "pitfall", "check"):
                if field in point:
                    point[field] = detail
            for field in ("signals", "steps"):
                if field in point:
                    point[field] = [detail] * len(point[field])
        if bundle["reading"] == "career":
            for key, target in (("favorable", story["insights"][0]), ("unfavorable", story["watchpoints"][0]), ("recent", story["summary"])):
                if source := bundle.get("free_excerpt", {}).get(key):
                    target.update(deepcopy(source))
        return self.validate(json.dumps(story, ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(postgres_url))) as client:
        body = {"profile": {**PROFILE, "language": language}, "year": 2026, "report_kind": "fortune"}
        response = client.post("/api/life-reports", json=body, headers=HEADERS)
        assert response.status_code == 200, response.text
        preview = response.json()
        assert preview["preview_state"] == "ready", preview
        assert preview["input"]["profile"]["language"] == language
        assert preview["chart"]["planets"][0]["label"] == ({"en": "Sun", "vi": "Mặt Trời", **{code: copy["reading"]["planets"]["sun"] for code, copy in REGIONAL_LANGUAGES.items()}}[language])
        path = "/api/life-reports/" + preview["id"]
        unlock_after_simulated_payment(client, path)

        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        result = client.get(path, headers=HEADERS).json()
        assert result["full_state"] == "ready", result
        assert [row["key"] for row in result["chapters"]] == list(CHAPTERS)
        assert result["generation_progress"]["percent"] == 100
        assert len(result["plan"]["phases"]) == 3
        assert all(bundle["language"] == language for bundle in seen)
        assert len(seen) == 7 and len(transport[0]) == 1
        assert client.get(path, headers={"X-Report-Key": "another-synthetic-language-owner"}).status_code == 404


def test_writing_revision_creates_fresh_content_and_preserves_saved_reports(postgres_url, monkeypatch, transport):
    writes = []

    async def write(self, bundle, **kwargs):
        writes.append(bundle["stage"])
        story = draft(bundle)
        if len(writes) > 1:
            story["summary"]["text"] = "你也愿意理解自己的感受，给重要选择留些调整余地。"
        return self.validate(json.dumps(story, ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(postgres_url))) as client:
        body = {"profile": PROFILE, "year": 2026, "report_kind": "fortune"}
        original = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert original["preview_state"] == "ready"
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == original["id"]
        assert writes == ["preview"]

        monkeypatch.setattr("backend.app.life_reports.PERSONAL_WRITING_VERSION", "test-next-writing-version")
        monkeypatch.setattr("backend.app.life_report_content.WESTERN_WRITING_VERSION", "test-next-writing-version")
        revised = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert revised["id"] != original["id"] and revised["preview_state"] == "ready"
        assert revised["preview"]["summary"]["text"] != original["preview"]["summary"]["text"]
        assert revised["chart"] == original["chart"] and revised["method"] == original["method"]
        assert writes == ["preview", "preview"] and len(transport[0]) == 1

        saved = client.get("/api/life-reports/" + original["id"], headers=HEADERS).json()
        assert saved["preview"] == original["preview"] and saved["input"] == original["input"]
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == revised["id"]
        assert writes == ["preview", "preview"]


@pytest.mark.parametrize("change", ["provider", "model", "base_url", "reasoning_effort"])
def test_changing_writer_creates_new_report_without_rewriting_saved_preview(postgres_url, monkeypatch, transport, change):
    config = settings(postgres_url)
    config.providers["openai"] = ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt",
                                                reasoning_effort="low")
    config.fortune_provider = "qwen" if change == "provider" else "openai"
    calls = []

    async def write(self, bundle, **kwargs):
        calls.append((self.provider, self.config.base_url, self.config.model, self.config.reasoning_effort))
        story = draft(bundle)
        if len(calls) > 1:
            story["summary"]["text"] = "你也愿意理解自己的感受，给重要选择留些调整余地。"
        return self.validate(json.dumps(story, ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(config)) as client:
        body = {"profile": PROFILE, "year": 2026, "report_kind": "fortune"}
        original = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert original["preview_state"] == "ready"
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == original["id"]
        assert len(calls) == 1

        if change == "provider":
            config.fortune_provider = "openai"
        else:
            setattr(config.providers["openai"], change, {"model": "another-test-gpt",
                                                       "base_url": "https://another-openai.example/v1",
                                                       "reasoning_effort": "medium"}[change])
        revised = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert revised["preview_state"] == "ready" and revised["id"] != original["id"]
        assert revised["preview"] != original["preview"] and calls[0] != calls[1]
        assert revised["chart"] == original["chart"] and revised["method"] == original["method"]
        assert client.get("/api/life-reports/" + original["id"], headers=HEADERS).json() == original
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == revised["id"]
        assert len(calls) == 2 and len(transport[0]) == 1


@pytest.mark.parametrize("provider", ["qwen", "openai"])
@pytest.mark.parametrize("language", ["zh", "th"])
def test_compact_provider_bounds_paragraphs_separately_from_summary(postgres_url, language, provider):
    config = settings(postgres_url)
    config.fortune_provider = provider
    if provider == "openai":
        config.providers[provider] = ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt")
    writer = LifeWriter(Storage(config.database_url), config, asyncio.Semaphore(1))
    body = LifeInput.model_validate({"profile": {**PROFILE, "language": language}, "year": 2026})
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN}
    bundle = RoxyAstrology.bundle(body, chart, "risk")
    schema = writer.response_format(bundle)["json_schema"]["schema"]
    definitions = schema["$defs"]
    assert schema["properties"]["language"]["const"] == language
    assert "translations" not in schema["properties"]
    for node in [schema, *definitions.values()]:
        if "properties" in node:
            assert node["additionalProperties"] is False
            assert set(node["required"]) == set(node["properties"])
    for name in ("Insight", "CompactWatch", "CompactAdvice"):
        text = definitions[name]["properties"]["text"]
        assert text["minLength"] >= (35 if language == "zh" else 100)
        assert text["minLength"] < text["maxLength"] <= (100 if language == "zh" else 320)
    assert definitions["ReadingSummary"]["properties"]["text"]["maxLength"] == 240


@pytest.mark.parametrize("provider", ["qwen", "openai"])
@pytest.mark.parametrize("reading", ["love", "risk"])
def test_actions_follow_their_assigned_timing_evidence_in_schema_prompt_and_correction(postgres_url, provider, reading):
    config = settings(postgres_url)
    config.fortune_provider = provider
    config.providers.setdefault("openai", ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt"))
    writer = LifeWriter(Storage(config.database_url), config, asyncio.Semaphore(1))
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    forecast = forecast_fixture({"birthData": {"date": PROFILE["birth_date"], "time": PROFILE["birth_time"] + ":00", "timezone": PROFILE["timezone"]},
                                 "startDate": "2026-11-16", "endDate": "2027-02-13"})
    forecast["events"].append({**forecast["events"][0], "target": "Saturn"})
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN,
             "forecast": {"state": "ready", "start": "2026-11-16", "end": "2027-02-13", "events": forecast["events"]}}
    bundle = RoxyAstrology.bundle(body, chart, reading)
    identifiers = bundle["citation_rules"]["timing_ids"]
    assert len(identifiers) == 2
    story = draft(bundle)
    original = deepcopy(story)
    assert writer.validate(json.dumps(story, ensure_ascii=False), bundle)["actions"] == original["actions"]
    properties = writer.response_format(bundle)["json_schema"]["schema"]["$defs"]["CompactAdvice"]["properties"]
    assert set(properties["evidence_ids"]["items"]["enum"]) == set(identifiers + bundle["citation_rules"]["supporting_natal_ids"])
    prompt = writer.prompt(bundle)
    assert "EVERY insight, watchpoint and action" not in prompt
    for index, identifier in enumerate(identifiers):
        assert f'"actions[{index}]": ["{identifier}"]' in prompt
        assert f"actions[{index}] requires {identifier}" in properties["evidence_ids"]["description"]
        invalid = deepcopy(story)
        invalid["actions"][index]["evidence_ids"][0] = identifiers[1 - index]
        with pytest.raises(InvalidBaziReport, match=f"MUST cite {identifier}") as failure:
            writer.validate(json.dumps(invalid, ensure_ascii=False), bundle)
        assert bundle["evidence"][identifier]["start"] in str(failure.value)
        assert '"required_timing_id": "' + identifier + '"' in failure.value.feedback
        assert "without rewriting unsupported prose" in failure.value.feedback
        assert story == original  # Citation errors never patch or relabel existing prose.


@pytest.mark.parametrize("provider", ["qwen", "openai"])
def test_career_excerpt_schema_and_validation_preserve_exact_free_content(postgres_url, provider):
    config = settings(postgres_url)
    config.fortune_provider = provider
    config.providers.setdefault("openai", ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt"))
    writer = LifeWriter(Storage(config.database_url), config, asyncio.Semaphore(1))
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    forecast = forecast_fixture({"birthData": {"date": PROFILE["birth_date"], "time": PROFILE["birth_time"] + ":00", "timezone": PROFILE["timezone"]},
                                 "startDate": "2026-11-16", "endDate": "2027-02-13"})
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN,
             "forecast": {"state": "ready", "start": "2026-11-16", "end": "2027-02-13", "events": forecast["events"]}}
    bundle = RoxyAstrology.bundle(body, chart, "career")
    free_bundle = {**bundle, "stage": "preview", "reading": "life-preview", "preview_layout": "four-questions"}
    preview = writer.validate(json.dumps(draft(free_bundle), ensure_ascii=False), free_bundle)
    bundle["free_excerpt"] = {key: deepcopy(preview[key]) for key in ("favorable", "unfavorable", "recent")}
    story = draft(bundle)
    writer.validate(json.dumps(story, ensure_ascii=False), bundle)
    definitions = writer.response_format(bundle)["json_schema"]["schema"]["$defs"]
    for source, definition, target in (("favorable", "Insight", story["insights"][0]),
                                       ("unfavorable", "CompactWatch", story["watchpoints"][0]),
                                       ("recent", "ReadingSummary", story["summary"])):
        properties = definitions[definition]["properties"]
        assert properties["text"]["const"] == preview[source]["text"]
        assert properties["evidence_ids"]["items"]["enum"] == preview[source]["evidence_ids"]
        assert "const" not in properties["evidence_ids"]
        original = target["text"]
        target["text"] = "你" + original[1:]
        with pytest.raises(InvalidBaziReport, match="frozen free_excerpt"):
            writer.validate(json.dumps(story, ensure_ascii=False), bundle)
        target["text"] = original


@pytest.mark.parametrize("provider", ["qwen", "openai"])
@pytest.mark.parametrize("language", ["zh", "th"])
@pytest.mark.parametrize("timed", [True, False])
def test_western_preview_has_three_complete_bounded_paragraphs(postgres_url, provider, language, timed):
    config = settings(postgres_url)
    config.fortune_provider = provider
    config.providers.setdefault("openai", ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt"))
    writer = LifeWriter(Storage(config.database_url), config, asyncio.Semaphore(1))
    body = LifeInput.model_validate({"profile": {**PROFILE, "language": language}, "year": 2026})
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN}
    if timed:
        data = forecast_fixture({"birthData": {"date": PROFILE["birth_date"], "time": PROFILE["birth_time"] + ":00", "timezone": PROFILE["timezone"]},
                                 "startDate": "2026-11-16", "endDate": "2027-02-13"})
        chart["forecast"] = {"state": "ready", "start": "2026-11-16", "end": "2027-02-13", "events": data["events"]}
    bundle = RoxyAstrology.bundle(body, chart, "overview")
    bundle.update(stage="preview", reading="life-preview", preview_layout="four-questions")
    story = draft(bundle)
    char = "稳" if language == "zh" else "ก"
    bounds = ({"summary": (20, 25), "traits": (35, 45), "environment": (50, 60), "favorable": (60, 65), "unfavorable": (60, 65), "recent": (40, 55), "response": (20, 25)} if language == "zh" else
              {"summary": (60, 90), "traits": (110, 140), "environment": (140, 180), "favorable": (180, 200), "unfavorable": (180, 200), "recent": (110, 150), "response": (60, 90)})
    total_bounds = ((355, 430) if timed else (315, 375)) if language == "zh" else ((1060, 1330) if timed else (950, 1180))
    if language == "th":
        for point, title in zip(story["traits"], ("จุดแข็งของคุณ", "แนวทางการเลือก", "การอยู่ร่วมกัน")):
            point["title"] = title
    for index in (0, 1):
        for key, limits in bounds.items():
            if key != "traits" and story.get(key) is not None:
                story[key]["text"] = char * limits[index]
        for trait in story["traits"]:
            trait["text"] = char * bounds["traits"][index]
        valid = writer.validate(json.dumps(story, ensure_ascii=False), bundle)
        points = [valid["summary"], *valid["traits"], *(valid[key] for key in ("environment", "favorable", "unfavorable", "recent", "response") if valid[key] is not None)]
        total = sum(len(point["text"]) for point in points)
        assert total == total_bounds[index]
        assert bool(valid["recent"]) is timed
    for key, limits in bounds.items():
        if key == "recent" and not timed:
            continue
        for outside in (limits[0] - 1, limits[1] + 1):
            invalid = deepcopy(story)
            point = invalid["traits"][0] if key == "traits" else invalid[key]
            point["text"] = char * outside
            with pytest.raises(InvalidBaziReport, match="preview|schema"):
                writer.validate(json.dumps(invalid, ensure_ascii=False), bundle)
    schema = writer.response_format(bundle)["json_schema"]["schema"]
    for key, limits in bounds.items():
        if key == "traits":
            text = schema["$defs"]["Trait"]["properties"]["text"]
            punctuation = 12 if language == "zh" else 0
        else:
            point = schema["properties"][key]
            point = point["anyOf"][0] if "anyOf" in point else point
            text = point["properties"]["text"]
            punctuation = 20 if language == "zh" else 0
        assert (text["minLength"], text["maxLength"]) == (limits[0], limits[1] + punctuation)
    # Non-preview/legacy summaries keep their existing model contract.
    assert schema["$defs"]["ReadingSummary"]["properties"]["text"]["maxLength"] == 240
    for language in ("zh", "th", "en", "vi", "my", "km", "lo", "ms", "id"):
        prompt = writer.prompt({**bundle, "language": language})
        assert "about 400 Chinese Han characters" in prompt
        assert "THREE natural paragraphs" in prompt and "1060-1330" in prompt
        assert "about 100 Chinese" not in prompt and "only the short identity" not in prompt
        assert "preview traits 180-600" not in prompt and "đặc điểm 180-600" not in prompt


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

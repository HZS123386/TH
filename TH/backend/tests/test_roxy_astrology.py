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
from backend.app.report_languages import REGIONAL_LANGUAGES

GOLDEN = json.loads((Path(__file__).parent / "fixtures/roxy-western-natal.json").read_text(encoding="utf-8"))
PROFILE = {"birth_date": "1992-04-15", "birth_time": "07:15", "timezone": "Asia/Bangkok", "birthplace": "Bangkok",
           "country_code": "TH", "latitude": 13.7563, "longitude": 100.5018, "language": "zh"}
HEADERS = {"X-Report-Key": "synthetic-roxy-report-contract-owner"}
TEXT = "你做决定时往往先确认自己能够承担什么，再逐步增加投入。遇到不同意见时，可以把理由和需要的支持讲清楚，留出根据实际反馈调整的空间。"
DETAIL = "先把需要确认的条件写清楚，再与对方核对。"


def unlock_after_simulated_payment(client, path):
    assert client.post(path + "/unlock", headers=HEADERS).status_code == 402
    order = client.post(path + "/payment", json={}, headers=HEADERS)
    assert order.status_code == 200, order.text
    paid = client.post(path + "/payment/simulate", json={"reference": order.json()["reference"]}, headers=HEADERS)
    assert paid.status_code == 200 and paid.json()["paid"] is True
    assert client.post(path + "/unlock", headers=HEADERS).status_code == 200


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


@pytest.fixture
def openai_transport(monkeypatch):
    calls, calculations = [], []
    mode = {"status": 200, "proxies": []}
    real_client = httpx.AsyncClient

    def handle(request):
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


def test_openai_stream_writes_free_preview_and_all_six_roxy_topics_with_usage(tmp_path, openai_transport):
    config = settings(tmp_path)
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
        assert mode["proxies"].count(None) == 1  # Roxy keeps its independent request configuration.
        assert "synthetic-openai-key" not in repr(config.providers["openai"])
        assert "synthetic-password" not in repr(config.providers["openai"])
        with client.app.state.store.connect() as db:
            usage = db.execute("SELECT * FROM report_model_usage WHERE report_id=? ORDER BY id", (preview["id"],)).fetchall()
        assert len(usage) == 7
        assert [row["phase"] for row in usage] == ["preview"] + ["full"] * 6
        assert all(row["provider"] == "openai" and row["model"] == "test-gpt" and row["validated"] for row in usage)
        assert all((row["prompt_tokens"], row["completion_tokens"], row["cached_tokens"], row["usage_received"]) == (100, 50, 20, 1)
                   for row in usage)
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == preview["id"]
        assert client.get(path, headers=HEADERS).json() == full
        assert len(calls) == 7


def test_openai_auth_failure_keeps_report_unavailable_without_qwen_fallback(tmp_path, openai_transport):
    config = settings(tmp_path)
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


def test_roxy_failure_does_not_fall_back_to_thai_or_call_writer(tmp_path, monkeypatch, transport):
    transport[1]["status"] = 503
    async def forbidden(*args, **kwargs):
        pytest.fail("the writer must not run without calculated evidence")
    monkeypatch.setattr(LifeWriter, "write", forbidden)
    with TestClient(create_app(settings(tmp_path))) as client:
        response = client.post("/api/life-reports", json={"profile": PROFILE, "year": 2026}, headers=HEADERS)
        assert response.status_code == 503 and "roxy_unavailable" in response.text


@pytest.mark.parametrize("language", ["en", "vi", "my", "km", "lo", "ms", "id"])
def test_landing_languages_generate_and_restore_complete_western_reports(tmp_path, monkeypatch, transport, language):
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
        if "summary" in story:
            story["summary"]["text"] = detail
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
            point["text"] = point["title"] + ". " + (paragraph if bundle["stage"] != "plan" else detail)
            for field in ("example", "response", "pitfall", "check"):
                if field in point:
                    point[field] = detail
            for field in ("signals", "steps"):
                if field in point:
                    point[field] = [detail] * len(point[field])
        return self.validate(json.dumps(story, ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(tmp_path))) as client:
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


def test_writing_revision_creates_fresh_content_and_preserves_saved_reports(tmp_path, monkeypatch, transport):
    writes = []

    async def write(self, bundle, **kwargs):
        writes.append(bundle["stage"])
        story = draft(bundle)
        if len(writes) > 1:
            story["summary"]["text"] = "你愿意认真理解眼前的感受，也可以给自己留下选择的余地。"
        return self.validate(json.dumps(story, ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    with TestClient(create_app(settings(tmp_path))) as client:
        body = {"profile": PROFILE, "year": 2026, "report_kind": "fortune"}
        original = client.post("/api/life-reports", json=body, headers=HEADERS).json()
        assert original["preview_state"] == "ready"
        assert client.post("/api/life-reports", json=body, headers=HEADERS).json()["id"] == original["id"]
        assert writes == ["preview"]

        monkeypatch.setattr("backend.app.life_reports.WESTERN_WRITING_VERSION", "test-next-writing-version")
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
def test_changing_writer_creates_new_report_without_rewriting_saved_preview(tmp_path, monkeypatch, transport, change):
    config = settings(tmp_path)
    config.providers["openai"] = ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt",
                                                reasoning_effort="low")
    config.fortune_provider = "qwen" if change == "provider" else "openai"
    calls = []

    async def write(self, bundle, **kwargs):
        calls.append((self.provider, self.config.base_url, self.config.model, self.config.reasoning_effort))
        story = draft(bundle)
        if len(calls) > 1:
            story["summary"]["text"] = "你可以先理解眼前的感受，再为接下来的选择留下调整的余地。"
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
def test_compact_provider_bounds_paragraphs_separately_from_summary(tmp_path, language, provider):
    config = settings(tmp_path)
    config.fortune_provider = provider
    if provider == "openai":
        config.providers[provider] = ProviderConfig("synthetic-openai-key", "https://openai.example/v1", "test-gpt")
    writer = LifeWriter(Storage(config.database_path), config, asyncio.Semaphore(1))
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

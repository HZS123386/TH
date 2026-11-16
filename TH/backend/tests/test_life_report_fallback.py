"""Service-failure fallback keeps the existing Roxy report contract and access limits."""
import asyncio
from copy import deepcopy
from datetime import datetime
import json
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.astrology import CHAPTERS, RoxyAstrology
from backend.app.bazi_reports import BaziReports
from backend.app.config import ProviderConfig
from backend.app.life_report_content import LifeWriter
from backend.app.life_reports import LifeInput
from backend.app.main import create_app
from backend.app.storage import Storage
from backend.tests.test_roxy_astrology import GOLDEN, HEADERS, PROFILE, draft, forecast_fixture, settings, unlock_after_simulated_payment


def fallback_settings(tmp_path):
    config = settings(tmp_path)
    config.fortune_provider = "openai"
    config.fortune_fallback_provider = "qwen"
    config.providers = {
        "openai": ProviderConfig("primary-test-key", "https://primary.example/v1", "gpt-6.1-sol", reasoning_effort="low"),
        "qwen": ProviderConfig("fallback-test-key", "https://fallback.example/v1", "qwen3.7-plus"),
    }
    return config


@pytest.fixture
def model_transport(monkeypatch):
    mode = {"primary": "401", "fallback": "success"}
    calls = []
    calculations = []
    original_client = httpx.AsyncClient

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
        assert request.url.path == "/v1/chat/completions"
        provider = {"primary.example": "openai", "fallback.example": "qwen"}[request.url.host]
        payload = json.loads(request.content)
        bundle = json.loads(payload["messages"][1]["content"])
        calls.append((provider, bundle))
        assert payload["stream"] and payload["stream_options"] == {"include_usage": True}
        if provider == "openai":
            assert request.headers["Authorization"] == "Bearer primary-test-key"
            assert payload["model"] == "gpt-6.1-sol" and payload["reasoning_effort"] == "low"
            assert payload["max_completion_tokens"] == 9000 and "enable_thinking" not in payload
        else:
            assert request.headers["Authorization"] == "Bearer fallback-test-key"
            assert payload["model"] == "qwen3.7-plus" and payload["enable_thinking"] is False
            assert "reasoning_effort" not in payload
        outcome = mode["primary" if provider == "openai" else "fallback"]
        if outcome == "network":
            raise httpx.ConnectError("private upstream connection details", request=request)
        if outcome == "timeout":
            raise httpx.ReadTimeout("private upstream timeout details", request=request)
        if outcome == "quota":
            return httpx.Response(429, headers={"retry-after": "1"}, json={
                "error": {"type": "insufficient_quota", "code": "credit_balance_exhausted", "message": "private upstream billing details"}})
        if outcome.isdigit():
            return httpx.Response(int(outcome), json={"error": {"message": "private upstream account details"}})
        story = draft(bundle)
        if outcome == "invalid_evidence":
            story["traits"][0]["evidence_ids"] = ["H99", "invented-source"]
        identifier = f"synthetic-{provider}-{len(calls)}"
        raw = json.dumps(story, ensure_ascii=False)
        packets = [
            {"id": identifier, "choices": [{"delta": {"content": raw}, "finish_reason": "stop"}]},
            {"id": identifier, "choices": [], "usage": {"prompt_tokens": 100, "completion_tokens": 50,
                                                           "prompt_tokens_details": {"cached_tokens": 20}}},
        ]
        if outcome == "refusal":
            packets[0]["choices"][0]["delta"] = {"refusal": "private upstream refusal details"}
        elif outcome == "content_filter":
            packets[0]["choices"][0]["finish_reason"] = "content_filter"
        return httpx.Response(200, headers={"content-type": "text/event-stream"},
                              text="".join("data: " + json.dumps(packet, ensure_ascii=False) + "\n\n" for packet in packets) + "data: [DONE]\n\n")

    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: original_client(transport=httpx.MockTransport(handle), **kwargs))
    return mode, calls, calculations


def create_preview(client):
    response = client.post("/api/life-reports", json={"profile": PROFILE, "year": 2026, "report_kind": "fortune"}, headers=HEADERS)
    assert response.status_code == 200, response.text
    assert not any(secret in response.text for secret in ("primary-test-key", "fallback-test-key", "private upstream"))
    return response.json()


@pytest.mark.parametrize("failure", ["401", "quota", "503", "network", "timeout"])
def test_primary_service_failure_uses_qwen_for_free_and_all_six_roxy_parts(tmp_path, model_transport, failure):
    mode, calls, calculations = model_transport
    mode["primary"] = failure
    with TestClient(create_app(fallback_settings(tmp_path))) as client:
        preview = create_preview(client)
        assert preview["preview_state"] == "ready" and not preview["chapters"]
        path = "/api/life-reports/" + preview["id"]
        unlock_after_simulated_payment(client, path)

        async def finish():
            await asyncio.gather(*client.app.state.life_reports.tasks.values())
        client.portal.call(finish)
        full = client.get(path, headers=HEADERS).json()
        assert full["full_state"] == "ready" and full["preview"] == preview["preview"]
        assert [chapter["key"] for chapter in full["chapters"]] == list(CHAPTERS)
        assert len(full["plan"]["phases"]) == 3
        assert full["progress"] == {"completed": 6, "total": 6}
        assert full["generation_progress"]["percent"] == 100
        assert [provider for provider, _ in calls] == ["openai"] + ["qwen"] * 7
        assert len(calculations) == 1
        with client.app.state.store.connect() as db:
            rows = db.execute("SELECT * FROM report_model_usage WHERE report_id=? ORDER BY id", (preview["id"],)).fetchall()
        assert len(rows) == 8
        assert rows[0]["provider"] == "openai" and not rows[0]["validated"]
        assert all(row["provider"] == "qwen" and row["model"] == "qwen3.7-plus" and row["validated"] for row in rows[1:])
        assert all((row["prompt_tokens"], row["completion_tokens"], row["usage_received"]) == (100, 50, 1) for row in rows[1:])
        assert [row["phase"] for row in rows[1:]] == ["preview"] + ["full"] * 6
        assert client.get(path, headers=HEADERS).json() == full
        assert len(calls) == 8


def test_successful_primary_never_uses_qwen(tmp_path, model_transport):
    mode, calls, calculations = model_transport
    mode["primary"] = "success"
    with TestClient(create_app(fallback_settings(tmp_path))) as client:
        assert create_preview(client)["preview_state"] == "ready"
        assert [provider for provider, _ in calls] == ["openai"] and len(calculations) == 1


@pytest.mark.parametrize("fallback", ["", "qwen"])
def test_unavailable_fallback_does_not_fabricate_report(tmp_path, model_transport, fallback):
    mode, calls, _ = model_transport
    mode["fallback"] = "503"
    config = fallback_settings(tmp_path)
    config.fortune_fallback_provider = fallback
    with TestClient(create_app(config)) as client:
        result = create_preview(client)
        assert result["preview_state"] == "unavailable" and result["preview"] is None
        assert not result["chapters"] and result["plan"] is None
        assert [provider for provider, _ in calls] == (["openai", "qwen"] if fallback else ["openai"])


def test_primary_unconfigured_still_allows_configured_qwen(tmp_path, model_transport):
    _, calls, calculations = model_transport
    config = fallback_settings(tmp_path)
    config.providers["openai"].key = ""
    with TestClient(create_app(config)) as client:
        assert create_preview(client)["preview_state"] == "ready"
        assert [provider for provider, _ in calls] == ["qwen"] and len(calculations) == 1


def test_invalid_primary_citations_cannot_be_overridden_by_qwen(tmp_path, model_transport):
    mode, calls, _ = model_transport
    mode["primary"] = "invalid_evidence"
    with TestClient(create_app(fallback_settings(tmp_path))) as client:
        result = create_preview(client)
        assert result["preview_state"] == "unavailable" and result["preview"] is None
        assert [provider for provider, _ in calls] == ["openai"] * LifeWriter.max_attempts
        assert not client.app.state.life_reports.writer.availability["retry_at"]


@pytest.mark.parametrize("rejection", ["refusal", "content_filter"])
def test_primary_safety_rejection_cannot_be_overridden_by_qwen(tmp_path, model_transport, rejection):
    mode, calls, _ = model_transport
    mode["primary"] = rejection
    with TestClient(create_app(fallback_settings(tmp_path))) as client:
        result = create_preview(client)
        assert result["preview_state"] == "unavailable" and result["preview"] is None
        assert calls and all(provider == "openai" for provider, _ in calls)
        assert len(calls) <= LifeWriter.max_attempts
        assert not client.app.state.life_reports.writer.availability["retry_at"]


@pytest.mark.parametrize("state", ["limited", "pending", "cancelled"])
def test_fallback_does_not_bypass_admission_or_cancellation(tmp_path, monkeypatch, state):
    config = fallback_settings(tmp_path)
    writer = LifeWriter(Storage(config.database_path), config, asyncio.Semaphore(1))
    calls = []

    async def generate(self, bundle, owner, network):
        calls.append(self.provider)
        if state == "cancelled":
            raise asyncio.CancelledError()
        return {"state": state}
    monkeypatch.setattr(BaziReports, "generate", generate)
    if state == "cancelled":
        with pytest.raises(asyncio.CancelledError):
            asyncio.run(writer.generate({}, "owner", "network"))
    else:
        assert asyncio.run(writer.generate({}, "owner", "network"))["state"] == state
    assert calls == ["openai"] and not writer.availability["retry_at"]


def test_primary_recovers_after_shared_service_cooldown(tmp_path, model_transport):
    mode, calls, _ = model_transport
    config = fallback_settings(tmp_path)
    writer = LifeWriter(Storage(config.database_path), config, asyncio.Semaphore(1))
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN}
    bundle = RoxyAstrology.bundle(body, chart, "overview")
    bundle.update(stage="preview", reading="life-preview")

    async def run():
        first = await writer.generate(bundle, "first", "network")
        assert first["state"] == "ready" and first["fallback_from"] == "openai"
        assert writer.availability["retry_at"] > 0
        second = await writer.generate(bundle, "second", "network")
        assert second["state"] == "ready" and second["fallback_from"] == "openai"
        assert [provider for provider, _ in calls] == ["openai", "qwen", "qwen"]
        mode["primary"] = "success"
        writer.availability["retry_at"] = 0
        third = await writer.generate(bundle, "third", "network")
        assert third["state"] == "ready" and "fallback_from" not in third
        assert [provider for provider, _ in calls] == ["openai", "qwen", "qwen", "openai"]
    asyncio.run(run())


@pytest.mark.parametrize("primary_configured", [True, False])
def test_fallback_preview_uses_one_admission_and_cached_hits_do_not_bypass_caps(tmp_path, model_transport, primary_configured):
    _, calls, _ = model_transport
    config = fallback_settings(tmp_path)
    config.bazi_reports_per_minute = 1
    if not primary_configured:
        config.providers["openai"].key = ""
    store = Storage(config.database_path)
    writer = LifeWriter(store, config, asyncio.Semaphore(1))
    body = LifeInput.model_validate({"profile": PROFILE, "year": 2026})
    chart = {"provider": "roxy", "domain": "astrology", "time_known": True, "raw": GOLDEN}
    bundle = RoxyAstrology.bundle(body, chart, "overview")
    bundle.update(stage="preview", reading="life-preview")

    async def run():
        first = await writer.generate(bundle, "owner", "network")
        assert first["state"] == "ready" and first["fallback_from"] == "openai"
        expected = ["openai", "qwen"] if primary_configured else ["qwen"]
        assert [provider for provider, _ in calls] == expected
        second = await writer.generate(bundle, "owner", "network")
        assert second["state"] == "ready" and second["cached"] is True
        assert [provider for provider, _ in calls] == expected
        fresh = {**bundle, "user_question": "我想进一步了解自己的工作方式。"}
        limited = await writer.generate(fresh, "owner", "network")
        assert limited["state"] == "limited"
        assert [provider for provider, _ in calls] == expected
        with store.connect() as db:
            assert db.execute("SELECT COUNT(*) FROM bazi_report_usage WHERE scope='owner'").fetchone()[0] == 1
            assert db.execute("SELECT COUNT(*) FROM bazi_report_usage WHERE scope='network'").fetchone()[0] == 1
    asyncio.run(run())

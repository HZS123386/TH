import asyncio
import json

import httpx
import pytest
from fastapi.testclient import TestClient

from backend.app.companion_models import CompanionModels
from backend.app.config import ProviderConfig, Settings
from backend.app.main import create_app
from backend.app.providers import ProviderError, ProviderRegistry
from backend.tests.test_app import PROFILE, login
from backend.tests.test_providers import mock_transport


def registry():
    return ProviderRegistry(Settings(providers={
        "qwen": ProviderConfig("qwen-private", "https://qwen.test/v1", "qwen3.7-plus"),
        "kimi": ProviderConfig("kimi-private", "https://kimi.test/v1", "kimi-k3.1-pro"),
    }))


async def answer(models, trace, profile=None, notes=None):
    return "".join([part async for part in models.stream(profile or {"profile": PROFILE, "revision": 1, "chart": {}}, notes or [], [], "How can I start?", trace)])


def test_both_models_use_the_same_birth_notes_question_and_only_refined_answer_is_returned(monkeypatch):
    requests = []

    def handler(request):
        body = json.loads(request.content)
        requests.append(body)
        reference = body["messages"][1]["content"].split("\nHistorical conversation data", 1)[0]
        data = json.loads(reference.split("\n", 1)[1])
        assert data["profile"]["profile"]["birth_date"] == PROFILE["birth_date"]
        assert data["user_confirmed_memories"] == ["Find another job before leaving"]
        assert body["messages"][-1]["content"] == "How can I start?"
        if request.url.host == "kimi.test":
            assert "private draft" in body["messages"][1]["content"]
            assert "初稿不是事实来源" in body["messages"][0]["content"]
        result = "private draft" if request.url.host == "qwen.test" else "one final answer"
        return httpx.Response(200, text='data: ' + json.dumps({"choices": [{"delta": {"content": result}, "finish_reason": "stop"}]}) + '\n\ndata: [DONE]\n\n')

    mock_transport(monkeypatch, handler)
    models, trace = CompanionModels(registry()), {}
    assert asyncio.run(answer(models, trace, notes=[{"content": "Find another job before leaving"}])) == "one final answer"
    assert len(requests) == 2 and trace["reviewed"] is True
    assert trace["response_provider"] == "kimi"
    assert [row["status"] for row in trace["steps"]] == ["completed", "completed"]
    assert "private draft" not in json.dumps(trace) and "private" not in json.dumps(models.public())


@pytest.mark.parametrize("failure", ["access", "partial", "empty", "timeout"])
def test_failed_review_uses_complete_qwen_reply_and_does_not_retry_every_turn(failure):
    transport, calls = registry(), []

    async def generate(name, profile, notes, history, question, **kwargs):
        calls.append(name)
        if name == "qwen":
            yield "complete Qwen answer"
            return
        if failure == "empty":
            return
        if failure == "partial":
            yield "discard this unfinished rewrite"
        if failure == "timeout":
            raise TimeoutError
        raise ProviderError("model_not_found" if failure == "access" else "upstream_interrupted")

    transport.stream = generate
    models, first, second = CompanionModels(transport), {}, {}
    assert asyncio.run(answer(models, first)) == "complete Qwen answer"
    assert asyncio.run(answer(models, second)) == "complete Qwen answer"
    assert calls == ["qwen", "kimi", "qwen"]
    assert first["reviewed"] is False and first["steps"][-1]["status"] == "failed"
    assert second["steps"][-1]["status"] == "skipped"


def test_kimi_can_answer_when_qwen_fails_without_receiving_an_incomplete_draft():
    transport = registry()

    async def generate(name, profile, notes, history, question, **kwargs):
        if name == "qwen":
            yield "unfinished Qwen text"
            raise ProviderError("upstream_interrupted")
        assert kwargs == {}
        yield "complete Kimi answer"

    transport.stream = generate
    trace = {}
    assert asyncio.run(answer(CompanionModels(transport), trace)) == "complete Kimi answer"
    assert trace["response_provider"] == "kimi" and trace["reviewed"] is False


def test_unconfigured_mode_is_disabled_and_cancellation_never_starts_a_second_model():
    empty = CompanionModels(ProviderRegistry(Settings()))
    assert empty.public()["enabled"] is False
    with pytest.raises(ProviderError, match="provider_unconfigured"):
        empty.model()
    transport, calls, closed = registry(), [], []

    async def generate(name, *args, **kwargs):
        calls.append(name)
        try:
            await asyncio.sleep(1)
            yield "late"
        finally:
            closed.append(name)

    transport.stream = generate

    async def cancel():
        async with asyncio.timeout(0.01):
            await answer(CompanionModels(transport), {})

    with pytest.raises(TimeoutError):
        asyncio.run(cancel())
    assert calls == ["qwen"]
    assert closed == ["qwen"]


def test_concurrent_turns_never_share_candidate_answers_or_personal_notes():
    transport = registry()

    async def generate(name, profile, notes, history, question, **kwargs):
        person = profile["profile"]["display_name"]
        assert notes == [{"content": f"{person}-private"}]
        await asyncio.sleep(0)
        if name == "qwen":
            yield f"{person}-draft"
        else:
            assert kwargs["draft"] == f"{person}-draft"
            yield f"{person}-final"

    transport.stream = generate
    models = CompanionModels(transport)

    async def together():
        return await asyncio.gather(*[answer(models, {}, {"profile": {**PROFILE, "display_name": person}}, [{"content": f"{person}-private"}]) for person in ("Alice", "Bob")])

    assert asyncio.run(together()) == ["Alice-final", "Bob-final"]


@pytest.mark.parametrize("both_fail", [False, True])
def test_api_persists_only_one_final_pair_with_truthful_workflow_evidence(tmp_path, both_fail):
    settings = registry().settings
    settings.database_path = str(tmp_path / "cooperative.db")
    with TestClient(create_app(settings)) as client:
        headers = login(client)
        client.put("/api/profile", headers=headers, json=PROFILE).raise_for_status()

        async def generate(name, *args, **kwargs):
            if name == "qwen" and not both_fail:
                yield "one complete reply"
                return
            yield "partial text that must never be stored"
            raise ProviderError("upstream_interrupted")

        client.app.state.registry.stream = generate
        response = client.post("/api/chat", headers=headers, json={"provider": "companion", "message": "你好"})
        rows = client.get("/api/history", headers=headers).json()
        if both_fail:
            assert 'event: error' in response.text and 'event: done' not in response.text
            assert rows == [] and "partial text" not in response.text
        else:
            assert 'event: done' in response.text and len(rows) == 2
            assert rows[-1]["content"] == "one complete reply"
            trace = rows[-1]["evidence"]["generation"]
            assert trace["response_provider"] == "qwen" and trace["reviewed"] is False
            assert [row["status"] for row in trace["steps"]] == ["completed", "failed"]
            assert "partial text" not in response.text

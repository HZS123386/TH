import asyncio
import json
from concurrent.futures import ThreadPoolExecutor

import httpx
import pytest
from fastapi.testclient import TestClient

from backend.app.companion_context import requested_periods
from backend.app.companion_memory import CompanionMemory, vector
from backend.app.config import ProviderConfig, Settings
from backend.app.main import create_app
from backend.app.providers import ProviderError, context
from backend.app.storage import Storage
from backend.tests.test_app import PROFILE, login
from backend.tests.test_providers import mock_transport


@pytest.fixture
def client(tmp_path):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "companion.db")))) as client:
        yield client


def prepare(client, name="Nok"):
    headers = login(client)
    assert client.put("/api/profile", headers=headers, json={**PROFILE, "display_name": name}).status_code == 200
    return headers


def packets(response, name):
    return [json.loads(frame.split("data: ", 1)[1]) for frame in response.text.split("\n\n") if frame.startswith(f"event: {name}\n")]


def test_period_router_uses_question_before_selected_period_in_four_languages():
    for question in ("今天本周本月运势", "today this week this month", "วันนี้ สัปดาห์นี้ เดือนนี้", "hôm nay tuần này tháng này"):
        assert requested_periods(question, None) == ["today", "week", "month"]
    assert requested_periods("本月怎么样", "week") == ["month"]
    assert requested_periods("你好", "today") == ["today"]
    assert requested_periods("你好", None) == []


def test_real_birth_fortunes_and_selected_situation_reach_the_model(client):
    headers = prepare(client)
    client.post("/api/memories", headers=headers, json={"content": "我正在准备转行"})
    client.put("/api/companion", headers=headers, json={"concern": "work_change", "option": "a", "topic": "work", "mood": "tired", "wish": "先找到合适工作，再离职。", "taste": {"style": "cool", "category": "crystal", "budget": 500}})
    captured = []

    async def capture(provider, profile, memories, history, question):
        captured.append((profile, memories))
        yield "reply"

    client.app.state.registry.stream = capture
    response = client.post("/api/chat", headers=headers, json={"message": "本周适合怎么推进工作？", "period": "today"})
    assert packets(response, "done")
    profile, notes = captured[0]
    fortune = profile["thai_fortunes"][0]
    assert fortune["period"] == "week"
    assert fortune["birth"]["date"] == PROFILE["birth_date"]
    assert fortune["sampling"]["count"] == 7
    work = fortune["readings"]["work"]
    assert work["localized_guidance"]["action"] == fortune["narrative"]["topics"]["work"]["outlook"]
    assert work["localized_guidance"]["interpretation"] == fortune["narrative"]["topics"]["work"]["text"]
    assert "evidence" not in fortune["readings"]["work"]["alternatives"][0]
    assert profile["selected_situation"]["concern_id"] == "work_change"
    assert profile["current_preferences"]["wish"] == "先找到合适工作，再离职。"
    assert profile["current_preferences"]["accessory_budget_thb"] == 500
    assert "demo_orders" not in profile["current_preferences"]
    assert notes[0]["content"] == "我正在准备转行"
    messages = context(profile, notes, [], "工作")
    assert "Roxy" not in messages[0]["content"]  # Product voice, not supplier advertising.
    assert "Never invent a memory" in messages[0]["content"]
    model_data = json.loads(messages[1]["content"].split("\n", 1)[1])["profile"]
    assert model_data["current_preferences"] == profile["current_preferences"]
    model_work = model_data["thai_fortunes"][0]["readings"]["work"]
    assert "localized_guidance" in model_work and "code" not in model_work
    assert "points" not in model_data["thai_calculation"]
    assert "code" in profile["thai_fortunes"][0]["readings"]["work"]  # Audit record is untouched.
    evidence = packets(response, "metadata")[0]["evidence"]
    assert evidence["fortunes"][0]["period"] == "week"
    assert evidence["recall"]["confirmed_count"] == 1
    assert client.get("/api/history", headers=headers).json()[-1]["evidence"] == evidence


def test_different_accounts_keep_birth_notes_history_and_recall_separate_under_concurrency(client):
    a, b = prepare(client, "Alice"), prepare(client, "Bob")
    client.put("/api/profile", headers=b, json={**PROFILE, "display_name": "Bob", "birth_date": "1999-02-20"})
    client.post("/api/memories", headers=a, json={"content": "A_ONLY_PRIVATE"})
    client.post("/api/memories", headers=b, json={"content": "B_ONLY_PRIVATE"})
    seen = {}

    async def capture(provider, profile, notes, history, question):
        await asyncio.sleep(0.02)
        seen[profile["profile"]["display_name"]] = json.dumps([profile, notes, history])
        yield profile["profile"]["display_name"]

    client.app.state.registry.stream = capture
    def ask(headers):
        return client.post("/api/chat", headers=headers, json={"message": "Remember my situation"})
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(ask, [a, b]))
    assert all(packets(response, "done") for response in responses)
    assert "A_ONLY_PRIVATE" in seen["Alice"] and "B_ONLY_PRIVATE" not in seen["Alice"]
    assert "B_ONLY_PRIVATE" in seen["Bob"] and "A_ONLY_PRIVATE" not in seen["Bob"]
    for headers, owner, other in [(a, "Alice", "Bob"), (b, "Bob", "Alice")]:
        response = ask(headers)
        assert packets(response, "metadata")[0]["evidence"]["recall"]["count"] == 1
        assert other not in json.dumps(client.get("/api/history", headers=headers).json())


def test_confirmed_note_edit_delete_and_cross_account_denials(client):
    owner, other = prepare(client), prepare(client)
    note = client.post("/api/memories", headers=owner, json={"content": "old preference"}).json()
    assert client.put(f"/api/memories/{note['id']}", headers=other, json={"content": "attack"}).status_code == 404
    assert client.delete(f"/api/memories/{note['id']}", headers=other).status_code == 404
    assert client.put(f"/api/memories/{note['id']}", headers=owner, json={"content": "new preference"}).json()["content"] == "new preference"
    assert client.delete(f"/api/memories/{note['id']}", headers=owner).status_code == 204
    assert client.get("/api/memories", headers=owner).json() == []


def test_clear_or_changed_profile_removes_archive_vectors_but_keeps_confirmed_notes(client):
    headers = prepare(client)
    owner = client.get("/api/auth/me", headers=headers).json()["user_id"]
    client.post("/api/memories", headers=headers, json={"content": "keep this confirmed note"})
    async def capture(*args):
        yield "old reply"
    client.app.state.registry.stream = capture
    for action in ("clear", "profile"):
        response = client.post("/api/chat", headers=headers, json={"message": "old private question"})
        message_id = packets(response, "done")[0]["message_id"]
        store = client.app.state.store
        store.index_reading(owner, message_id, "test", [1, 0])
        assert store.recall_readings(owner, "test")[0]["embedding"]
        if action == "clear":
            assert client.delete("/api/history", headers=headers).status_code == 204
        else:
            assert client.put("/api/profile", headers=headers, json={**PROFILE, "birth_date": "1999-02-20"}).status_code == 200
        assert store.recall_readings(owner, "test") == []
        store.index_reading(owner, message_id, "test", [0, 1])  # A late task cannot resurrect it.
        assert store.recall_readings(owner, "test") == []
        assert len(client.get("/api/memories", headers=headers).json()) == 1


def test_model_failure_does_not_save_partial_reply_or_memory(client):
    headers = prepare(client)
    async def failing(*args):
        yield "partial"
        raise ProviderError("upstream_interrupted")
    client.app.state.registry.stream = failing
    result = client.post("/api/chat", headers=headers, json={"message": "hello"})
    assert packets(result, "error")[0]["saved"] is False
    assert not packets(result, "done")
    owner = client.get("/api/auth/me", headers=headers).json()["user_id"]
    assert client.app.state.store.recall_readings(owner, "") == []
    assert client.get("/api/history", headers=headers).json() == []


def test_embedding_semantic_recall_and_safe_fallback(monkeypatch, tmp_path):
    store = Storage(str(tmp_path / "memory.db"))
    owner = store.login(1)["user_id"]
    other = store.login(1)["user_id"]
    memory = CompanionMemory(store, ProviderConfig("private-key", "https://example.test/v1", "embedding-model"))
    older = memory.remember(owner, "I want to move to Chiang Mai", "We discussed relocation", "mock", {})
    newer = memory.remember(owner, "A different subject", "Unrelated reply", "mock", {})
    private = memory.remember(other, "other user", "secret", "mock", {})
    store.index_reading(owner, older, memory.signature, [1, 0])
    store.index_reading(owner, newer, memory.signature, [0, 1])
    store.index_reading(other, private, memory.signature, [1, 0])
    def handler(request):
        assert request.headers["authorization"] == "Bearer private-key"
        assert json.loads(request.content)["model"] == "embedding-model"
        return httpx.Response(200, json={"data": [{"embedding": [1, 0]}]})
    mock_transport(monkeypatch, handler)
    result = asyncio.run(memory.recall(owner, "What about moving?", 1))
    assert result["mode"] == "semantic"
    assert result["items"][0]["id"] == older
    assert private not in json.dumps(result)
    async def unavailable(text):
        raise httpx.ConnectError("SECRET should never be exposed")
    monkeypatch.setattr(memory, "embed", unavailable)
    result = asyncio.run(memory.recall(owner, "hello", 1))
    assert result["mode"] == "recent-unavailable" and result["items"][0]["id"] == newer
    asyncio.run(memory.index(owner, newer))  # Index failure does not delete a delivered reading.
    assert store.reading(owner, newer)


def test_recall_survives_new_service_instance_and_model_change(tmp_path):
    path = str(tmp_path / "reopen.db")
    store = Storage(path)
    owner = store.login(1)["user_id"]
    one = CompanionMemory(store, ProviderConfig())
    message_id = one.remember(owner, "my old concern", "an old interpretation", "mock", {})
    reopened = CompanionMemory(Storage(path), ProviderConfig())
    result = asyncio.run(reopened.recall(owner, "previous concern"))
    assert result["items"][0]["id"] == message_id
    assert result["mode"] == "recent"


@pytest.mark.parametrize("value", [[], [0, 0], [float('nan')], [float('inf')], [True], ["bad"], [10**1000]])
def test_rejects_invalid_provider_vectors(value):
    with pytest.raises(ValueError):
        vector(value)


def test_spend_limits_are_atomic_per_user_and_survive_new_storage_instances(tmp_path):
    path = str(tmp_path / "quota.db")
    store = Storage(path)
    owner, other = store.login(1)["user_id"], store.login(1)["user_id"]
    with ThreadPoolExecutor(max_workers=6) as pool:
        outcomes = list(pool.map(lambda _: Storage(path).reserve_chat(owner, 2, 10), range(6)))
    assert outcomes.count(None) == 2
    assert outcomes.count("chat_minute_limit") == 4
    assert Storage(path).reserve_chat(other, 2, 10) is None
    store.clear_history(owner)
    assert store.reserve_chat(owner, 2, 10) == "chat_minute_limit"
    assert store.reserve_chat(other, 0, 10) == "chat_minute_limit"
    assert store.reserve_chat(other, 8, 0) == "chat_daily_limit"

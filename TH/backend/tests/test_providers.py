import asyncio
import json

import httpx
import pytest

from backend.app.config import ProviderConfig, Settings
from backend.app.providers import ProviderError, ProviderRegistry
from backend.tests.test_app import PROFILE


def mock_transport(monkeypatch, handler):
    original = httpx.AsyncClient
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: original(transport=httpx.MockTransport(handler), **kwargs))


async def collect(registry, name, history=None):
    return "".join([part async for part in registry.stream(name, {"profile": PROFILE, "revision": 1, "chart": {}}, [], history or [], "hello")])


@pytest.mark.parametrize("name", ["openai", "deepseek", "qwen", "kimi"])
def test_compatible_stream_protocol_and_private_credentials(monkeypatch, name):
    def handler(request):
        assert str(request.url) == "https://example.test/v1/chat/completions"
        assert request.headers["authorization"] == "Bearer test-secret"
        body = json.loads(request.content)
        assert body["model"] == "test-model" and body["stream"] is True
        assert body["max_completion_tokens" if name == "openai" else "max_tokens"] == (4096 if name == "kimi" else 1200)
        return httpx.Response(
            200,
            text='data: {"choices":[{"delta":{"content":"你好"},"finish_reason":null}]}\n\ndata: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n',
        )

    mock_transport(monkeypatch, handler)
    registry = ProviderRegistry(Settings(providers={name: ProviderConfig("test-secret", "https://example.test/v1", "test-model")}))
    assert asyncio.run(collect(registry, name)) == "你好"
    assert "test-secret" not in json.dumps(registry.public())


@pytest.mark.parametrize(
    "body",
    [
        'data: {"choices":[{"delta":{"content":"half"},"finish_reason":"length"}]}\n\n',
        'data: {"choices":[{"delta":{"content":"half"}}]}\n\ndata: [DONE]\n\n',
        "data: invalid-json\n\n",
        'data: {"error":{"message":"private details"}}\n\n',
    ],
)
def test_bad_or_incomplete_upstream_stream_is_rejected(monkeypatch, body):
    mock_transport(monkeypatch, lambda request: httpx.Response(200, text=body))
    registry = ProviderRegistry(Settings(providers={"openai": ProviderConfig("key", "https://example.test", "model")}))
    with pytest.raises(ProviderError):
        asyncio.run(collect(registry, "openai"))


def test_upstream_error_body_is_not_exposed(monkeypatch):
    mock_transport(monkeypatch, lambda request: httpx.Response(401, text="sensitive upstream body"))
    registry = ProviderRegistry(Settings(providers={"openai": ProviderConfig("key", "https://example.test", "model")}))
    with pytest.raises(ProviderError) as error:
        asyncio.run(collect(registry, "openai"))
    assert "sensitive" not in str(error.value)


@pytest.mark.parametrize("name,model", [("qwen", "qwen3.7-plus"), ("kimi", "kimi-k3.1-pro"), ("kimi", "kimi-k2.6")])
def test_provider_specific_parameters_and_reasoning_never_leak_to_users(monkeypatch, name, model):
    def handler(request):
        payload = json.loads(request.content)
        if name == "qwen":
            assert payload["enable_thinking"] is False
        elif model.startswith("kimi-k3"):
            assert payload["max_completion_tokens"] == 4096
            assert "max_tokens" not in payload
            assert payload["reasoning_effort"] == "low"
        else:
            assert payload["thinking"] == {"type": "disabled"}
        if name == "kimi":
            assert not any(message["role"] == "assistant" for message in payload["messages"])
            assert "Historical conversation data" in payload["messages"][1]["content"]
            assert "earlier final answer" in payload["messages"][1]["content"]
        return httpx.Response(200, text='data: {"choices":[{"delta":{"reasoning_content":"private reasoning"},"finish_reason":null}]}\n\ndata: {"choices":[{"delta":{"content":"visible answer"},"finish_reason":"stop"}]}\n\ndata: [DONE]\n\n')
    mock_transport(monkeypatch, handler)
    registry = ProviderRegistry(Settings(providers={name: ProviderConfig("key", "https://example.test/v1", model)}))
    assert asyncio.run(collect(registry, name, [{"role": "user", "content": "earlier question"}, {"role": "assistant", "content": "earlier final answer"}])) == "visible answer"


@pytest.mark.parametrize("status,code", [(401, "model_auth_failed"), (403, "model_access_denied"), (404, "model_not_found"), (429, "model_rate_limit")])
def test_upstream_access_and_quota_errors_have_safe_actionable_codes(monkeypatch, status, code):
    mock_transport(monkeypatch, lambda request: httpx.Response(status, json={"error": {"message": "never expose private upstream body"}}))
    registry = ProviderRegistry(Settings(providers={"qwen": ProviderConfig("key", "https://example.test", "model")}))
    with pytest.raises(ProviderError, match=code):
        asyncio.run(collect(registry, "qwen"))

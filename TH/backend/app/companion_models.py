"""Two-model answering over the existing Roxy-adapted memory/tool context."""
import asyncio
import time
from contextlib import aclosing

from .providers import ProviderError, ProviderRegistry


class CompanionModels:
    def __init__(self, registry: ProviderRegistry):
        self.registry = registry
        self.kimi_retry_at = 0.0

    def enabled(self, name: str):
        config = self.registry.settings.providers.get(name)
        return bool(config and config.enabled)

    def model(self):
        models = [self.registry.model(name) for name in ("qwen", "kimi") if self.enabled(name)]
        if not models:
            raise ProviderError("provider_unconfigured")
        return " → ".join(models)

    def public(self):
        enabled = any(self.enabled(name) for name in ("qwen", "kimi"))
        return {"id": "companion", "name": "Companion", "enabled": enabled, "model": self.model() if enabled else ""}

    async def stream(self, profile: dict, memories: list, history: list, question: str, trace: dict):
        self.model()
        trace.update(mode="companion", reviewed=False, response_provider=None, steps=[])

        async def attempt(name: str, role: str, draft: str | None = None):
            step = {"provider": name, "model": self.registry.model(name), "role": role, "status": "pending"}
            trace["steps"].append(step)
            try:
                answer = ""
                async with asyncio.timeout(22):
                    options = {"draft": draft} if draft is not None else {}
                    async with aclosing(self.registry.stream(name, profile, memories, history, question, **options)) as output:
                        async for fragment in output:
                            answer += fragment
                            if len(answer) > 24000:
                                raise ProviderError("reply_too_long")
                if not answer.strip():
                    raise ProviderError("empty_reply")
            except (ProviderError, TimeoutError) as error:
                step["status"] = "failed"
                if name == "kimi":
                    access_error = str(error) in ("model_not_found", "model_auth_failed", "model_access_denied")
                    self.kimi_retry_at = time.monotonic() + (300 if access_error else 30)
                raise
            step["status"] = "completed"
            if name == "kimi":
                self.kimi_retry_at = 0.0
            trace["response_provider"] = name
            return answer

        kimi_available = self.enabled("kimi") and time.monotonic() >= self.kimi_retry_at
        if self.enabled("qwen"):
            try:
                answer = await attempt("qwen", "draft")
            except (ProviderError, TimeoutError):
                if not kimi_available:
                    raise
                answer = await attempt("kimi", "answer")
            else:
                if kimi_available:
                    try:
                        answer = await attempt("kimi", "refine", answer)
                        trace["reviewed"] = True
                    except (ProviderError, TimeoutError):
                        # Both candidate streams are buffered: a failed refinement
                        # can never be appended to the complete Qwen draft.
                        pass
                else:
                    trace["steps"].append({"provider": "kimi", "role": "refine", "status": "skipped"})
        elif kimi_available:
            answer = await attempt("kimi", "answer")
        else:
            raise ProviderError("upstream_unavailable")

        # Only the final complete answer leaves this module or enters memory.
        for start in range(0, len(answer), 80):
            yield answer[start:start + 80]

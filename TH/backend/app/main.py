import asyncio
import json
import logging
import mimetypes
import time
from collections import defaultdict, deque
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from starlette.background import BackgroundTask
from starlette.exceptions import HTTPException as StarletteHTTPException

from .bazi import calculate
from .config import Settings
from .i18n import LOCALES, MESSAGES, message, request_language
from .modules import MODULES
from .providers import ProviderError, ProviderRegistry, route_tools
from .schemas import AccountInput, BaziTestInput, ChatInput, CompanionInput, FortuneInput, FortuneNarrativeInput, LanguageInput, MemoryInput, ProfileInput, ThaiReadingInput
from .storage import Storage
from .companion_memory import CompanionMemory
from .companion_models import CompanionModels
from .fortune_reports import FortuneReports
from .fortune_calculations import FortuneCalculations
from .companion_context import compact_fortune, evidence, recalled_context, requested_periods, situation, preferences
from . import thai as thai_engine
from .roxy import RoxyBazi, RoxyError
from .bazi_testing import generate_bazi_test
from .bazi_reports import BaziReports
from .thai_readings import ThaiReports, generate_reading
from .life_reports import LifeReports, life_report_router
from .landing_features import LandingFeatures, landing_router

logger = logging.getLogger(__name__)


def event(name: str, data: dict) -> str:
    return f"event: {name}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def create_app(settings: Settings | None = None):
    # Minimal Linux images may lack the MIME entries needed by web fonts and image decoders.
    for extension, kind in (('.otf', 'font/otf'), ('.ttf', 'font/ttf'), ('.woff2', 'font/woff2'), ('.webp', 'image/webp')):
        mimetypes.add_type(kind, extension)
    settings = settings or Settings.from_env()
    if settings.app_env not in ("development", "production"):
        raise RuntimeError("APP_ENV must be development or production")
    if settings.bazi_provider not in ("github", "roxy"):
        raise RuntimeError("BAZI_PROVIDER must be github or roxy")
    app = FastAPI(title="Sabai API", version="0.1.0")
    store, registry = Storage(settings.database_path), ProviderRegistry(settings)
    models = CompanionModels(registry)
    roxy = RoxyBazi(settings, store)
    app.state.roxy = roxy
    def module_catalog():
        return [{**module, **({"method": "RoxyAPI / split-zi / li-chun / civil time", "calculation_version": "roxy-bazi-1"}
                             if module["id"] == "bazi" and settings.bazi_provider == "roxy" else {})} for module in MODULES]
    memory = CompanionMemory(store, settings.embeddings)
    app.state.memory = memory
    app.state.store, app.state.registry = store, registry
    app.state.companion_models = models
    busy: set[str] = set()
    account_slots = asyncio.Semaphore(2)
    thai_slots = asyncio.Semaphore(2)
    fortune_calculations = FortuneCalculations(thai_slots)
    model_slots = asyncio.Semaphore(4)
    reports = FortuneReports(store, settings, model_slots)
    bazi_reports = BaziReports(store, settings, model_slots)
    thai_reports = ThaiReports(store, settings, model_slots)
    app.state.thai_reports = thai_reports
    app.state.bazi_reports = bazi_reports
    app.state.fortune_reports = reports
    life_reports = LifeReports(store, settings, model_slots, thai_slots)
    app.state.life_reports = life_reports
    app.include_router(life_report_router(life_reports))
    app.include_router(landing_router(LandingFeatures(store, settings, life_reports)))

    async def load_thai(user_id: str, current: dict):
        profile = current["profile"]
        key = thai_engine.fingerprint(profile)
        cached = store.thai_chart(user_id, key)
        if cached is not None:
            return {**cached, "profile_revision": current["revision"]}
        async with thai_slots:
            cached = store.thai_chart(user_id, key)
            if cached is not None:
                return {**cached, "profile_revision": current["revision"]}
            result = await asyncio.to_thread(thai_engine.natal, profile)
            result["profile_revision"] = current["revision"]
            return store.save_thai_chart(user_id, key, result)

    rates: dict[tuple[str, str], deque] = defaultdict(deque)

    def error_response(code: str, status: int, request: Request):
        language = request_language(request)
        return JSONResponse({"detail": message(code, language), "code": code}, status_code=status, headers={"Content-Language": LOCALES[language]})

    @app.exception_handler(StarletteHTTPException)
    async def http_error(request: Request, error: StarletteHTTPException):
        return error_response(str(error.detail), error.status_code, request)

    @app.exception_handler(RoxyError)
    async def roxy_error(request: Request, error: RoxyError):
        return error_response(error.code, 429 if error.code in ("roxy_quota", "roxy_local_limit") else 503, request)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, error: RequestValidationError):
        first = error.errors()[0]
        reason = str(first.get("ctx", {}).get("error", ""))
        field = str(first.get("loc", [""])[-1])
        code = (
            reason
            if reason in MESSAGES
            else {
                "username": "username_invalid",
                "password": "password_invalid",
                "birth_date": "birthdate_invalid",
                "birth_time": "birth_time_invalid",
                "timezone": "timezone_invalid",
                "message": "message_invalid",
                "content": "content_invalid",
                "language": "language_invalid",
            }.get(field, "validation_failed")
        )
        return error_response(code, 422, request)

    @app.middleware("http")
    async def boundaries(request: Request, call_next):
        if request.url.path.startswith("/api/"):
            # Read a bounded body before validation, including chunked requests.
            body = bytearray()
            async for chunk in request.stream():
                body.extend(chunk)
                if len(body) > 65536:
                    return error_response("request_too_large", 413, request)
            request._body = bytes(body)
            key = (request.client.host if request.client else "unknown", request.url.path)
            now = time.monotonic()
            # Keep the prototype limiter bounded, including arbitrary requested paths.
            for stale in [key for key, times in rates.items() if not times or times[-1] < now - 60]:
                del rates[stale]
            if len(rates) >= 2000 and key not in rates:
                response = error_response("busy", 429, request)
                response.headers["Retry-After"] = "60"
                return response
            bucket = rates[key]
            while bucket and bucket[0] < now - 60:
                bucket.popleft()
            if len(bucket) >= 30:
                response = error_response("too_many_requests", 429, request)
                response.headers["Retry-After"] = str(max(1, int(bucket[0] + 60 - now) + 1))
                return response
            bucket.append(now)
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "same-origin"
        response.headers["Content-Language"] = LOCALES[request_language(request)]
        return response

    def token_value(authorization: str | None):
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(401, "login_required")
        return authorization[7:]

    def user(authorization: str | None = Header(default=None)):
        if settings.app_env == "production":
            raise HTTPException(403, "production_disabled")
        user_id = store.authenticate(token_value(authorization))
        if not user_id:
            raise HTTPException(401, "session_expired")
        return user_id

    def require_idle(user_id: str):
        if user_id in busy:
            raise HTTPException(409, "chat_in_progress")

    def fortune_scopes(request: Request, authorization: str | None):
        # Do not trust forwarding headers in the standalone development server.
        network = "network:" + store.hash(request.client.host if request.client else "unknown")
        owner = "account:" + store.hash(user(authorization)) if authorization else "guest:" + network
        return owner, network

    async def calculate_fortune(body: FortuneInput, owner: str):
        try:
            return await fortune_calculations.get(body.profile.model_dump(mode="json"), body.period, owner)
        except ValueError as error:
            raise HTTPException(422, str(error)) from None
        except RuntimeError as error:
            raise HTTPException(503, str(error)) from None

    @app.get("/health")
    async def health():
        return {"status": "ok", "version": "0.1.0"}

    @app.get("/api/config")
    async def config():
        return {
            "providers": [models.public(), *registry.public()],
            "default_provider": settings.default_provider,
            "demo_login": settings.app_env == "development",
            "account_login": settings.app_env == "development",
            "liff_id": None,
            "modules": module_catalog(),
            "roxy": roxy.public(),
            "companion": {
                "source": "RoxyAPI/ai-spiritual-companion",
                "commit": "3b313e6972b92aecf94dad2aecbe822e1599fa4a",
                "recall": "semantic" if settings.embeddings.enabled else "recent",
                "real_model_ready": any(item["enabled"] for item in registry.public() if item["id"] != "mock"),
            },
        }

    @app.get("/api/modules")
    async def modules():
        return module_catalog()

    @app.post("/api/bazi/test")
    async def bazi_test(body: BaziTestInput, request: Request, authorization: str | None = Header(default=None)):
        owner, network = fortune_scopes(request, authorization)
        try:
            return await generate_bazi_test(body, roxy, owner, network, reports=bazi_reports)
        except ValueError as error:
            raise HTTPException(422, str(error)) from None

    @app.post("/api/thai-reading")
    async def thai_reading(body: ThaiReadingInput, request: Request, authorization: str | None = Header(default=None)):
        owner, network = fortune_scopes(request, authorization)
        try:
            return await generate_reading(body, thai_reports, thai_slots, owner, network)
        except ValueError as error:
            raise HTTPException(422, str(error)) from None
        except RuntimeError as error:
            raise HTTPException(503, str(error)) from None

    @app.post("/api/auth/demo")
    async def demo():
        if settings.app_env != "development":
            raise HTTPException(403, "production_disabled")
        return store.login(settings.session_hours)

    @app.post("/api/auth/logout", status_code=204)
    async def logout(authorization: str | None = Header(default=None), user_id: str = Depends(user)):
        require_idle(user_id)
        store.logout(token_value(authorization))

    @app.get("/api/auth/me")
    async def me(user_id: str = Depends(user)):
        return store.account(user_id)

    @app.post("/api/auth/register", status_code=201)
    async def register(body: AccountInput, authorization: str | None = Header(default=None)):
        if settings.app_env != "development":
            raise HTTPException(403, "production_disabled")
        existing_user = store.authenticate(token_value(authorization)) if authorization else None
        try:
            async with account_slots:
                return await asyncio.to_thread(store.register, body.username, body.password, settings.session_hours, existing_user)
        except ValueError as error:
            raise HTTPException(409, str(error)) from None

    @app.post("/api/auth/login")
    async def account_login(body: AccountInput):
        if settings.app_env != "development":
            raise HTTPException(403, "production_disabled")
        async with account_slots:
            result = await asyncio.to_thread(store.account_login, body.username, body.password, settings.session_hours)
        if not result:
            raise HTTPException(401, "credentials_invalid")
        return result

    @app.get("/api/profile")
    async def profile(user_id: str = Depends(user)):
        return store.profile(user_id)

    @app.get("/api/thai-locations")
    async def thai_locations(
        country: str = Query(default="TH", pattern=r"^([A-Z]{2})?$"), query: str = Query(default="", max_length=80), offset: int = Query(default=0, ge=0, le=2000000),
        level: str = Query(default="city", pattern=r"^(city|province|auto|locality|detail)$"),
        province: str = Query(default="", pattern=r"^(geonames:[1-9][0-9]{0,10})?$"),
    ):
        try:
            async with thai_slots:
                return await asyncio.to_thread(thai_engine.locations, country, query, offset, level, province)
        except RuntimeError as error:
            raise HTTPException(503, str(error)) from None

    @app.get("/api/thai-chart")
    async def thai_chart(user_id: str = Depends(user)):
        current = store.profile(user_id)
        if not current:
            raise HTTPException(422, "profile_required")
        try:
            return await load_thai(user_id, current)
        except RuntimeError as error:
            raise HTTPException(503, str(error)) from None

    @app.post("/api/thai-chart/preview")
    async def preview_thai(body: ProfileInput):
        try:
            async with thai_slots:
                result = await asyncio.to_thread(thai_engine.natal, body.model_dump(mode="json"))
            return {**result, "profile_revision": 0}
        except ValueError as error:
            raise HTTPException(422, str(error)) from None
        except RuntimeError as error:
            raise HTTPException(503, str(error)) from None

    @app.post("/api/thai-transits/preview")
    async def preview_transits(body: ProfileInput):
        async with thai_slots:
            try:
                return await asyncio.to_thread(thai_engine.transits, body.model_dump(mode="json"))
            except ValueError as error:
                raise HTTPException(422, str(error)) from None
            except RuntimeError as error:
                raise HTTPException(503, str(error)) from None

    @app.post("/api/fortune")
    async def fortune(body: FortuneInput, request: Request, authorization: str | None = Header(default=None)):
        owner, _ = fortune_scopes(request, authorization)
        value = await calculate_fortune(body, owner)
        return reports.preview(value, body.profile.model_dump(mode="json"), owner)

    @app.post("/api/fortune/narrative")
    async def fortune_report(body: FortuneNarrativeInput, request: Request, authorization: str | None = Header(default=None)):
        owner, network = fortune_scopes(request, authorization)
        # Reject stale page requests before a paid call, including past/future dates.
        if body.for_date != datetime.now(ZoneInfo("Asia/Bangkok")).date():
            raise HTTPException(409, "validation_failed")
        value = await calculate_fortune(body, owner)
        if value["calendar"]["date"] != body.for_date.isoformat():
            raise HTTPException(409, "validation_failed")
        result = await reports.generate(value, body.profile.model_dump(mode="json"), owner, network)
        return {**result, "period": value["period"], "period_start": value["period_start"], "period_end": value["period_end"], "for_date": body.for_date.isoformat(), "analysis_signature": value["analysis"]["signature"]}

    @app.get("/api/thai-transits")
    async def thai_transits(user_id: str = Depends(user)):
        current = store.profile(user_id)
        if not current:
            raise HTTPException(422, "profile_required")
        try:
            async with thai_slots:
                return await asyncio.to_thread(thai_engine.transits, current["profile"])
        except RuntimeError as error:
            raise HTTPException(503, str(error)) from None

    @app.put("/api/preferences/language")
    async def set_language(body: LanguageInput, user_id: str = Depends(user)):
        return store.set_language(user_id, body.language)

    @app.get("/api/companion")
    async def companion(user_id: str = Depends(user)):
        return store.companion(user_id)

    @app.put("/api/companion")
    async def save_companion(body: CompanionInput, user_id: str = Depends(user)):
        return store.save_companion(user_id, body.model_dump(mode="json"))

    @app.put("/api/profile")
    async def save_profile(body: ProfileInput, request: Request, user_id: str = Depends(user)):
        require_idle(user_id)
        busy.add(user_id)
        try:
            chart = (await roxy.profile_chart(body, "account:" + store.hash(user_id), "network:" + store.hash(request.client.host if request.client else "unknown"))
                     if settings.bazi_provider == "roxy" else calculate(body))
            payload = body.model_dump(mode="json")
            for field in ("country_code", "location_id", "latitude", "longitude"):
                if payload[field] is None:
                    payload.pop(field)
            return store.save_profile(user_id, payload, chart)
        except ValueError as error:
            raise HTTPException(422, str(error)) from None
        finally:
            busy.discard(user_id)

    @app.get("/api/history")
    async def history(user_id: str = Depends(user)):
        return store.history(user_id)

    @app.delete("/api/history", status_code=204)
    async def clear_history(user_id: str = Depends(user)):
        require_idle(user_id)
        store.clear_history(user_id)

    @app.get("/api/memories")
    async def memories(user_id: str = Depends(user)):
        return store.memories(user_id)

    @app.post("/api/memories", status_code=201)
    async def remember(body: MemoryInput, user_id: str = Depends(user)):
        require_idle(user_id)
        try:
            return store.add_memory(user_id, body.content)
        except ValueError as error:
            raise HTTPException(409, str(error)) from None

    @app.put("/api/memories/{memory_id}")
    async def edit_memory(memory_id: str, body: MemoryInput, user_id: str = Depends(user)):
        require_idle(user_id)
        result = store.update_memory(user_id, memory_id, body.content)
        if result is None:
            raise HTTPException(404, "memory_not_found")
        return result

    @app.delete("/api/memories/{memory_id}", status_code=204)
    async def forget(memory_id: str, user_id: str = Depends(user)):
        require_idle(user_id)
        if not store.delete_memory(user_id, memory_id):
            raise HTTPException(404, "memory_not_found")

    @app.post("/api/chat")
    async def chat(body: ChatInput, request: Request, user_id: str = Depends(user)):
        require_idle(user_id)
        current = store.profile(user_id)
        if not current:
            raise HTTPException(422, "profile_required")
        language = request_language(request) if request.headers.get("accept-language") else current["profile"]["language"]
        current["profile"]["language"] = language
        if body.context:
            current["current_situation"] = body.context
        try:
            model = models.model() if body.provider == "companion" else registry.model(body.provider)
        except ProviderError as error:
            raise HTTPException(503, str(error)) from None
        limit = store.reserve_chat(user_id, settings.chat_per_minute, settings.chat_per_day)
        if limit:
            raise HTTPException(429, limit)
        # Reserve this account before awaiting a calculation: profile changes and
        # another chat must not race the tool's input snapshot.
        busy.add(user_id)
        try:
            route = route_tools(body.message)
            current["astrology_system"] = "bazi" if route == "bazi" else "thai-suriyayatra"
            if route == "bazi" and settings.bazi_provider == "roxy":
                current["chart"] = await roxy.profile_chart(ProfileInput(**current["profile"]), "account:" + store.hash(user_id), "network:" + store.hash(request.client.host if request.client else "unknown"))
            if route != "bazi":
                try:
                    current["thai_calculation"] = thai_engine.compact(await load_thai(user_id, current))
                    if route == "thai-transits":
                        async with thai_slots:
                            transit = await asyncio.to_thread(thai_engine.transits, current["profile"])
                        current["thai_transits"] = {key: transit[key] for key in ("status", "calculated_at", "comparison") if key in transit}
                except RuntimeError:
                    current.setdefault("thai_calculation", {"status": "unavailable"})
                    if route == "thai-transits":
                        current["thai_transits"] = {"status": "unavailable"}
                current["thai_fortunes"] = []
                for period in requested_periods(body.message, body.period):
                    try:
                        async with thai_slots:
                            result = await asyncio.to_thread(thai_engine.fortune, current["profile"], period)
                        report = reports.preview(result, {**current["profile"], "language": language}, "account:" + store.hash(user_id))
                        current["thai_fortunes"].append(compact_fortune(result, language, report["narrative"]))
                    except (RuntimeError, ValueError):
                        current["thai_fortunes"].append({"period": period, "status": "unavailable"})
            companion_state = store.companion(user_id)
            current["selected_situation"] = situation(companion_state, language)
            current["current_preferences"] = preferences(companion_state, language)
            recent, confirmed = store.history(user_id, 12), store.memories(user_id)
            recalled = await memory.recall(user_id, body.message)
            current["recalled_history"] = recalled_context(recalled)
            grounding = evidence(current, recalled, confirmed)
            if body.provider == "companion":
                grounding["generation"] = {"mode": "companion", "reviewed": False, "response_provider": None, "steps": []}
        except BaseException:
            busy.discard(user_id)
            raise

        saved_message_id = None

        async def stream():
            nonlocal saved_message_id
            try:
                yield event("metadata", {"provider": body.provider, "model": model, "profile_revision": current["revision"], "evidence": grounding})
                answer = ""
                async with asyncio.timeout(50), model_slots:
                    output = (
                        models.stream(current, confirmed, recent, body.message, grounding["generation"])
                        if body.provider == "companion"
                        else registry.stream(body.provider, current, confirmed, recent, body.message)
                    )
                    async for fragment in output:
                        if await request.is_disconnected():
                            return
                        if not answer and body.provider == "companion":
                            yield event("metadata", {"provider": body.provider, "model": model, "profile_revision": current["revision"], "evidence": grounding})
                        answer += fragment
                        if len(answer) > 24000:
                            raise ProviderError("reply_too_long")
                        yield event("token", {"text": fragment})
                if not answer.strip():
                    raise ProviderError("empty_reply")
                if await request.is_disconnected():
                    return
                message_id = memory.remember(user_id, body.message, answer, body.provider, grounding)
                saved_message_id = message_id
                yield event("done", {"message_id": message_id, "provider": body.provider})
            except (ProviderError, TimeoutError) as error:
                code = (
                    str(error)
                    if isinstance(error, ProviderError) and str(error) in MESSAGES
                    else "reply_timeout"
                    if isinstance(error, TimeoutError)
                    else "request_failed"
                )
                yield event("error", {"message": message(code, language), "code": code, "saved": False})
            except Exception:
                logger.exception("Chat failed")
                yield event("error", {"message": message("request_failed", language), "saved": False})
            finally:
                busy.discard(user_id)

        async def finish():
            busy.discard(user_id)
            # The response is closed before optional indexing. Only successful saved turns exist.
            if saved_message_id is not None:
                await memory.index(user_id, saved_message_id)

        return StreamingResponse(
            stream(),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
            background=BackgroundTask(finish),
        )

    # Serve the landing build alongside its existing calculation API, on one origin.
    if settings.thai_landing_dir and Path(settings.thai_landing_dir).is_dir():
        app.mount("/thai-landing", StaticFiles(directory=settings.thai_landing_dir, html=True), name="thai-landing")
    dist = Path(__file__).resolve().parents[2] / "dist"
    if dist.is_dir():
        app.mount("/", StaticFiles(directory=dist, html=True), name="web")
    return app

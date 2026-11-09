import asyncio
from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import json
from threading import Event

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.config import Settings
from backend.app.bazi import calculate
from backend.app.main import create_app
from backend.app.roxy import CONVENTIONS, RoxyBazi, RoxyError, calculation_instant, request_body
from backend.app.schemas import ProfileInput
from backend.app.storage import Storage

PROFILE = {"display_name": "Synthetic", "birth_date": "1995-08-17", "birth_time": "10:30", "timezone": "Asia/Shanghai", "birthplace": "Beijing", "language": "zh"}
EXPECTED = {"year": "乙亥", "month": "甲申", "day": "庚辰", "hour": "辛巳"}


def fixture_for(operation, body):
    value = {"birthData": {"date": body["date"], "time": body["time"], "timezone": 8}, "conventions": dict(CONVENTIONS), "summary": "实际计算依据的测试解读，不代表未来事件发生概率。"}
    if operation == "chart":
        value.update(pillars=[{"position": position, "stem": {"chinese": chars[0]}, "branch": {"chinese": chars[1]}, "tenGod": {"category": "wealth", "keynote": "资源与安排"}} for position, chars in EXPECTED.items()])
    elif operation == "day-master":
        value.update(verdict="very-strong", score=4.9, factors=[{"chinese": "月令", "contribution": 3, "detail": "测试因素"}, {"chinese": "根气", "contribution": 2.5, "detail": "测试因素"}, {"chinese": "同党", "contribution": -0.6, "detail": "测试因素"}], favorableElements=["Fire"], unfavorableElements=["Metal"])
    elif operation == "luck-pillars":
        value.update(gender=body["gender"], direction="forward", startAge=6, luckPillars=[{"index": 1, "startAge": 6, "endAge": 16, "startYear": 2001, "endYear": 2011, "stem": {"chinese": "乙"}, "branch": {"chinese": "酉"}}])
    elif operation == "annual-forecast":
        value.update(year=body["year"], annualPillar={"stem": {"chinese": "丙"}, "branch": {"chinese": "午"}}, benMingNian=False)
    return value


@pytest.fixture
def roxy_client(tmp_path, monkeypatch):
    requests = []
    real_client = httpx.AsyncClient

    def handler(request):
        requests.append(request)
        body = json.loads(request.content)
        assert request.url.host == "roxyapi.com"
        assert request.headers["x-api-key"] == "private-test-secret"
        assert "display_name" not in body and "birthplace" not in body
        return httpx.Response(200, json=fixture_for(request.url.path.rsplit("/", 1)[-1], body))

    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    settings = Settings(database_path=str(tmp_path / "test.db"), roxy_api_key="private-test-secret", roxy_enabled=True)
    with TestClient(create_app(settings)) as client:
        yield client, requests


def test_same_convention_comparison_report_and_all_selected_topics(roxy_client):
    client, requests = roxy_client
    body = {"profile": PROFILE, "source": "compare", "topics": ["chart", "strength", "luck", "annual"], "gender": "female", "year": 2026, "focus": "money"}
    response = client.post("/api/bazi/test", json=body)
    assert response.status_code == 200
    result = response.json()
    assert result["comparison"]["status"] == "match"
    assert result["sources"]["github"]["chart"]["pillars"] == EXPECTED
    assert result["sources"]["roxy"]["chart"]["pillars"] == EXPECTED
    assert len(requests) == 4
    assert result["report"]["generation"]["state"] == "unconfigured"
    assert result["report"]["sections"] == []  # Never pretend a generic prompt is a personal reading.
    assert "private-test-secret" not in response.text
    repeated = client.post("/api/bazi/test", json=body).json()
    assert len(requests) == 4
    assert all(value["cached"] for value in repeated["sources"]["roxy"]["details"].values())


def test_test_birth_never_changes_saved_account_profile(roxy_client):
    client, _ = roxy_client
    token = client.post("/api/auth/demo").json()["token"]
    headers = {"Authorization": "Bearer " + token}
    client.put("/api/profile", headers=headers, json=PROFILE)
    before = client.get("/api/profile", headers=headers).json()
    body = {"profile": {**PROFILE, "birth_date": "1990-01-15"}, "source": "github"}
    assert client.post("/api/bazi/test", headers=headers, json=body).status_code == 200
    assert client.get("/api/profile", headers=headers).json() == before


def test_unknown_time_and_local_only_make_no_paid_calls(roxy_client):
    client, requests = roxy_client
    result = client.post("/api/bazi/test", json={"profile": {**PROFILE, "birth_time": None}}).json()
    assert result["sources"]["roxy"]["errors"] == {"chart": "bazi_time_required"}
    assert result["sources"]["github"]["chart"]["pillars"]["hour"] is None
    assert result["comparison"]["status"] == "partial"
    assert not requests
    assert client.post("/api/bazi/test", json={"profile": PROFILE, "source": "github"}).status_code == 200
    assert not requests


def test_unknown_time_keeps_original_civil_day_when_beijing_clock_selected(roxy_client):
    client, requests = roxy_client
    profile = {**PROFILE, "timezone": "Asia/Bangkok", "birth_time": None}
    result = client.post("/api/bazi/test", json={"profile": profile, "clock": "beijing"}).json()
    assert result["sources"]["github"]["chart"]["pillars"]["day"] is None
    assert result["comparison"]["status"] == "partial"
    assert not requests


def test_local_year_and_month_follow_actual_solar_term_instant():
    before = calculate(ProfileInput(**{**PROFILE, "birth_date": "2024-02-04", "birth_time": "02:00", "timezone": "America/New_York"}), "local")
    after = calculate(ProfileInput(**{**PROFILE, "birth_date": "2024-02-04", "birth_time": "12:00", "timezone": "America/New_York"}), "local")
    assert before["pillars"]["year"] == "癸卯"
    assert after["pillars"]["year"] == "甲辰"
    assert after["pillars"]["month"] == "丙寅"


def test_beijing_conversion_preserves_resolved_fold():
    profile = ProfileInput(**{**PROFILE, "birth_date": "1990-09-15", "birth_time": "17:30", "timezone": "UTC"})
    body = request_body(profile, calculation_instant(profile, "beijing"))
    assert body["date"] == "1990-09-16"
    assert body["time"] == "01:30:00"
    assert body["timezone"] == 8


def test_request_body_preserves_seconds_and_explicit_historical_offset():
    # A supplied resolved instant is stable even when IANA history is revised.
    profile = ProfileInput(**{**PROFILE, "birth_date": "1901-01-01", "birth_time": "00:00", "timezone": "UTC"})
    instant = datetime(1901, 1, 1, 8, 5, 43, tzinfo=timezone(timedelta(seconds=29143)))
    body = request_body(profile, instant)
    assert body["time"] == "08:05:43"
    assert body["timezone"] == pytest.approx(29143 / 3600)


def test_invalid_selection_and_foreign_session_rejected_before_calls(roxy_client):
    client, requests = roxy_client
    assert client.post("/api/bazi/test", json={"profile": PROFILE, "topics": ["luck"]}).status_code == 422
    assert client.post("/api/bazi/test", json={"profile": PROFILE, "topics": ["chart", "chart"]}).status_code == 422
    assert client.post("/api/bazi/test", headers={"Authorization": "Bearer invalid"}, json={"profile": PROFILE}).status_code == 401
    assert not requests


def test_both_engines_receive_same_beijing_conversion(roxy_client):
    client, requests = roxy_client
    local = {**PROFILE, "timezone": "Asia/Bangkok", "birth_time": "09:30"}
    result = client.post("/api/bazi/test", json={"profile": local, "clock": "beijing"}).json()
    assert result["comparison"]["status"] == "match"
    assert result["calculation_input"]["birth_time"] == "10:30:00"
    assert json.loads(requests[0].content)["timezone"] == 8
    assert result["input"]["profile"]["birth_time"] == "09:30"


def test_public_config_exposes_capability_but_no_key(roxy_client):
    client, _ = roxy_client
    response = client.get("/api/config")
    assert response.json()["roxy"]["enabled"]
    assert "private-test-secret" not in response.text
    assert "roxy_api_key" not in response.text


@pytest.mark.parametrize("status,code", [(401, "roxy_auth_failed"), (429, "roxy_quota"), (500, "roxy_unavailable"), (400, "roxy_input_rejected")])
def test_upstream_error_details_are_not_exposed(tmp_path, monkeypatch, status, code):
    real_client = httpx.AsyncClient
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(lambda req: httpx.Response(status, text="private upstream content")), **kwargs))
    client = RoxyBazi(Settings(roxy_api_key="secret", roxy_enabled=True), Storage(str(tmp_path / "test.db")))
    async def run():
        with pytest.raises(RoxyError, match=code):
            await client.request("chart", {"date": "1995-08-17", "time": "10:30:00", "timezone": "Asia/Shanghai", **CONVENTIONS}, "zh", "one", "network")
    asyncio.run(run())


def test_wrong_birth_or_malformed_pillars_cannot_become_successful_report(tmp_path, monkeypatch):
    real_client = httpx.AsyncClient
    def handler(req):
        data = fixture_for("chart", json.loads(req.content))
        data["pillars"][0]["stem"]["chinese"] = ""
        return httpx.Response(200, json=data)
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    with TestClient(create_app(Settings(database_path=str(tmp_path / "test.db"), roxy_api_key="secret", roxy_enabled=True))) as client:
        result = client.post("/api/bazi/test", json={"profile": PROFILE}).json()
        assert result["sources"]["roxy"]["errors"]["chart"] == "roxy_invalid_response"
        assert result["sources"]["roxy"]["chart"] is None
        assert result["comparison"]["status"] == "partial"


@pytest.mark.parametrize("bad", ["keynote", "nan", "seconds", "huge-offset"])
def test_malformed_nested_or_nonfinite_results_are_not_reported(tmp_path, monkeypatch, bad):
    real_client = httpx.AsyncClient
    def handler(req):
        data = fixture_for("chart", json.loads(req.content))
        if bad == "keynote":
            data["pillars"][0]["tenGod"]["keynote"] = {"unexpected": "object"}
        elif bad == "nan":
            data["extra"] = float("nan")
        elif bad == "seconds":
            data["birthData"]["time"] = "10:30:59"
        else:
            data["birthData"]["timezone"] = 10 ** 400
        return httpx.Response(200, content=json.dumps(data).encode())
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    with TestClient(create_app(Settings(database_path=str(tmp_path / "test.db"), roxy_api_key="secret", roxy_enabled=True))) as client:
        response = client.post("/api/bazi/test", json={"profile": PROFILE, "focus": "money"})
        assert response.status_code == 200
        assert response.json()["sources"]["roxy"]["errors"] == {"chart": "roxy_invalid_response"}


def test_async_roxy_profile_save_reserves_the_account_until_commit(tmp_path, monkeypatch):
    entered, release = Event(), Event()
    real_client = httpx.AsyncClient
    async def handler(req):
        entered.set()
        await asyncio.to_thread(release.wait, 5)
        return httpx.Response(200, json=fixture_for("chart", json.loads(req.content)))
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    settings = Settings(database_path=str(tmp_path / "race.db"), roxy_api_key="secret", roxy_enabled=True)
    with TestClient(create_app(settings)) as client:
        headers = {"Authorization": "Bearer " + client.post("/api/auth/demo").json()["token"]}
        assert client.put("/api/profile", json=PROFILE, headers=headers).status_code == 200
        settings.bazi_provider = "roxy"
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(client.put, "/api/profile", json=PROFILE, headers=headers)
            assert entered.wait(5)
            try:
                assert client.put("/api/profile", json=PROFILE, headers=headers).status_code == 409
                assert client.post("/api/chat", json={"message": "八字"}, headers=headers).status_code == 409
            finally:
                release.set()
            assert future.result(timeout=10).status_code == 200


def test_concurrent_calls_coalesce_and_caches_are_owner_isolated_with_network_quota(tmp_path, monkeypatch):
    calls = []
    real_client = httpx.AsyncClient
    def handler(req):
        calls.append(req)
        return httpx.Response(200, json=fixture_for("chart", json.loads(req.content)))
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: real_client(transport=httpx.MockTransport(handler), **kwargs))
    service = RoxyBazi(Settings(roxy_api_key="secret", roxy_enabled=True, roxy_per_day=2), Storage(str(tmp_path / "test.db")))
    body = {"date": "1995-08-17", "time": "10:30:00", "timezone": "Asia/Shanghai", **CONVENTIONS}
    async def run():
        await asyncio.gather(*(service.request("chart", deepcopy(body), "zh", "one", "network") for _ in range(3)))
        assert len(calls) == 1
        await service.request("chart", body, "zh", "two", "network")
        assert len(calls) == 2
        with pytest.raises(RoxyError, match="roxy_local_limit"):
            await service.request("chart", body, "zh", "three", "network")
    asyncio.run(run())

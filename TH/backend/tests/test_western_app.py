import copy
import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from backend.app.astrology import RoxyError, validate_natal
from backend.app import thai
from backend.app.config import ProviderConfig, Settings
from backend.app.main import create_app
from backend.app.western_app import NOTICE, TOPICS, WesternWriter, report_bundle, snapshot
from backend.app.bazi_reports import InvalidBaziReport


RAW = json.loads((Path(__file__).parent / "fixtures/roxy-western-natal.json").read_text(encoding="utf-8"))
BIRTH = {"system": "western_natal", "birth_date": "1992-04-15", "birth_time": "07:15",
         "timezone": "Asia/Bangkok", "birthplace": "Bangkok", "latitude": 13.7563,
         "longitude": 100.5018, "language": "en"}


def chart(known=True):
    return {"time_known": known, "raw": copy.deepcopy(RAW)}


def story(bundle):
    sections = []
    for key in TOPICS:
        sections.append({"key": key,
                         "interpretation": f"For {key}, your chart suggests a preference for clear arrangements. If this fits your experience, use that preference to define a manageable responsibility before accepting more work.",
                         "example": f"In a situation involving {key}, you might prefer checking the details before committing to a shared plan.",
                         "advice": [f"For {key}, write down the part you can realistically complete and discuss this boundary with the people involved.",
                                    f"For {key}, review how that arrangement worked and adjust the next step using your actual experience."],
                         "evidence_ids": bundle["topic_ids"][key][:2]})
    return {"language": "en", "reading": "natal", "summary": "Your chart points to a practical approach to commitments. Start with a clear boundary, then review what works in your own experience.", "sections": sections}


@pytest.fixture
def app(tmp_path):
    settings = Settings(database_path=str(tmp_path / "app.db"), roxy_enabled=True, roxy_api_key="test-not-a-real-key",
                        providers={"qwen": ProviderConfig("test-key", "https://example.com/v1", "test-model")})
    return create_app(settings)


def login(client):
    return {"Authorization": "Bearer " + client.post("/api/auth/demo").json()["token"]}


def save(client, headers, **extra):
    response = client.put("/api/profile", headers=headers, json={**BIRTH, **extra})
    assert response.status_code == 200, response.text
    return response.json()


def test_roxy_response_checks_signs_orbs_and_retrograde():
    body = {**RAW["birthDetails"], "timezone": "Asia/Bangkok", "houseSystem": "placidus", "nodeType": "true"}
    validate_natal("natal", RAW, body)
    for mutate in (lambda raw: raw["planets"][0].update(sign="Taurus"),
                   lambda raw: raw["planets"][0].update(isRetrograde=True),
                   lambda raw: raw["aspects"][0].update(orb=5)):
        raw = copy.deepcopy(RAW)
        mutate(raw)
        with pytest.raises(RoxyError):
            validate_natal("natal", raw, body)


def test_place_id_without_country_uses_the_global_geographic_lookup(app, monkeypatch):
    calls = []
    def locations(country, query, offset, level):
        calls.append((country, query, level))
        return {"resolved": {"latitude": 13.75398, "longitude": 100.50144, "timeZone": "Asia/Bangkok"}}
    monkeypatch.setattr(thai, "locations", locations)
    with TestClient(app) as client:
        headers = login(client)
        birth = {key: value for key, value in BIRTH.items() if key not in ("latitude", "longitude")}
        response = client.put("/api/profile", headers=headers, json={**birth, "location_id": "geonames:1609350"})
        assert response.status_code == 200, response.text
        assert calls == [("", "geonames:1609350", "detail")]
        assert response.json()["profile"]["latitude"] == 13.75398


def test_date_only_omits_unreliable_facts_and_house_interpretations():
    raw = chart(False)
    raw["raw"]["planets"][0].update(longitude=29.9, degree=29.9)
    result = snapshot(raw, "c1")
    assert result["status"] == "partial"
    assert {row["kind"] for row in result["facts"]} == {"planet"}
    assert all(row["value"]["key"] not in ("moon", "sun") and "house" not in row["value"] for row in result["facts"])
    bundle = report_bundle(result, raw, "th")
    assert not any("roxy_interpretation" in fact for fact in bundle["evidence"].values())
    assert {"moon", "sun", "houses", "aspects"} <= set(result["missing_fields"])


def test_account_chart_cache_revision_and_no_bazi_calculation(app, monkeypatch):
    calls = []
    async def calculate(profile, owner, network):
        calls.append(profile)
        return chart(profile.birth_time is not None)
    monkeypatch.setattr(app.state.western_app.adapter, "calculate", calculate)
    with TestClient(app) as client:
        headers = login(client)
        profile = save(client, headers)
        assert profile["chart"] == {"system": "western_natal", "status": "not_calculated"}
        request = {"system": "western_natal", "profile_id": profile["profile_id"], "profile_revision": profile["revision"]}
        result = client.post("/api/calculations", headers=headers, json=request)
        assert result.status_code == 200, result.text
        value = result.json()
        assert sum(row["kind"] == "planet" for row in value["facts"]) == 10
        assert sum(row["kind"] == "house" for row in value["facts"]) == 12
        assert client.post("/api/calculations", headers=headers, json=request).json() == value
        assert len(calls) == 1
        assert client.put("/api/profile", headers=headers, json=BIRTH).status_code == 409
        save(client, headers, expected_revision=1, birth_time="08:15")
        assert client.post("/api/calculations", headers=headers, json=request).status_code == 409
        assert client.post("/api/calculations", json=request).status_code == 401


def test_western_report_is_bound_to_consent_owner_revision_and_locale(app, monkeypatch):
    async def calculate(*args):
        return chart()
    async def generate(bundle, *args):
        return {"state": "ready", "story": WesternWriter.validate(json.dumps(story(bundle)), bundle)}
    monkeypatch.setattr(app.state.western_app.adapter, "calculate", calculate)
    monkeypatch.setattr(app.state.western_app.writer, "generate", generate)
    with TestClient(app) as client:
        headers = login(client)
        p = save(client, headers)
        c = client.post("/api/calculations", headers=headers, json={"system": "western_natal", "profile_id": p["profile_id"], "profile_revision": 1}).json()
        body = {"profile_revision": 1, "calculation_result_id": c["result_id"], "topic": "natal", "locale": "en"}
        assert client.post("/api/western/reports", headers=headers, json=body).status_code == 403
        assert client.post("/api/privacy/consents", headers=headers, json={"purpose": "ai_reading", "notice_version": NOTICE, "granted": True}).status_code == 204
        response = client.post("/api/western/reports", headers=headers, json=body)
        assert response.status_code == 202, response.text
        identifier = response.json()["report_id"]
        value = client.get("/api/western/reports/" + identifier, headers=headers).json()
        assert value["preview_state"] == "ready"
        assert value["locale"] == "en" and value["calculation_result_id"] == c["result_id"]
        assert value["access_reason"] == "development_preview"
        assert len(value["preview"]) == 1 and len(value["sections"]) == 5
        saved = client.get("/api/western/reports", headers=headers).json()["items"][0]
        assert saved["report_id"] == identifier and saved["profile_revision"] == 1
        assert client.post("/api/western/reports", headers=headers, json=body).json()["report_id"] == identifier
        other = login(client)
        assert client.get("/api/western/reports/" + identifier, headers=other).status_code == 404
        assert client.post("/api/western/reports", headers=other, json=body).status_code == 422
        service = app.state.western_app
        service.settings.app_env = "production"
        restricted = service.report(identifier, app.state.store.authenticate(headers["Authorization"][7:]))
        assert restricted["access"] == "preview" and restricted["sections"] == []


def test_report_validation_rejects_wrong_language_and_cross_topic_citations():
    bundle = report_bundle(snapshot(chart(), "c1"), chart(), "en")
    value = story(bundle)
    assert WesternWriter.validate(json.dumps(value), bundle)["language"] == "en"
    value["language"] = "th"
    with pytest.raises(InvalidBaziReport):
        WesternWriter.validate(json.dumps(value), bundle)
    value = story(bundle)
    value["sections"][0]["evidence_ids"] = ["h_8", "h_12"]
    with pytest.raises(InvalidBaziReport):
        WesternWriter.validate(json.dumps(value), bundle)


def test_guest_can_read_own_report_and_explicit_registration_keeps_ownership(app, monkeypatch):
    async def calculate(*args):
        return chart()
    async def generate(bundle, *args):
        return {"state": "ready", "story": story(bundle)}
    monkeypatch.setattr(app.state.western_app.adapter, "calculate", calculate)
    monkeypatch.setattr(app.state.western_app.writer, "generate", generate)
    with TestClient(app) as client:
        response = client.post("/api/auth/guest")
        assert response.status_code == 201
        identity = response.json()
        headers = {"Authorization": "Bearer " + identity["token"]}
        assert client.get("/api/auth/me", headers=headers).json()["kind"] == "guest"
        with app.state.store.connect() as db:
            assert db.execute("SELECT COUNT(*) FROM accounts").fetchone()[0] == 0
        profile = save(client, headers)
        result = client.post("/api/calculations", headers=headers, json={
            "system": "western_natal", "profile_id": profile["profile_id"], "profile_revision": 1}).json()
        client.post("/api/privacy/consents", headers=headers,
                    json={"purpose": "ai_reading", "notice_version": NOTICE, "granted": True})
        body = {"profile_revision": 1, "calculation_result_id": result["result_id"], "locale": "en"}
        created = client.post("/api/western/reports", headers=headers, json=body)
        assert created.status_code == 202, created.text
        identifier = created.json()["report_id"]
        report = client.get("/api/western/reports/" + identifier, headers=headers).json()
        assert report["preview_state"] == "ready" and report["access"] == "full"
        assert len(report["sections"]) == 5
        other = {"Authorization": "Bearer " + client.post("/api/auth/guest").json()["token"]}
        assert client.get("/api/profile", headers=other).json() is None
        assert client.get("/api/western/reports/" + identifier, headers=other).status_code == 404
        save(client, other)
        assert client.post("/api/western/reports", headers=other, json=body).status_code == 404
        registered = client.post("/api/auth/register", headers=headers,
                                 json={"username": "guest_upgrade", "password": "test-password-123"})
        assert registered.status_code == 201, registered.text
        assert registered.json()["user_id"] == identity["user_id"]
        account_headers = {"Authorization": "Bearer " + registered.json()["token"]}
        assert client.get("/api/auth/me", headers=account_headers).json()["kind"] == "account"
        assert client.get("/api/western/reports/" + identifier, headers=account_headers).status_code == 200
        assert client.get("/api/western/reports/" + identifier, headers=headers).status_code == 401


def test_plain_language_repair_identifies_terms_across_all_public_fields():
    bundle = report_bundle(snapshot(chart(), "c1"), chart(), "zh")
    value = story(bundle)
    value["language"] = "zh"
    base = "如果你在安排任务时遇到这样的情况，可以先写下需要完成的事情，再与相关的人商量时间和分工，根据实际结果调整下一步。"
    value["summary"] = "你可以留意自己的能量。" + base
    for index, section in enumerate(value["sections"]):
        number = "一二三四五六"[index]
        section["interpretation"] = "第" + number + "部分的特点。" + base
        section["example"] = "第" + number + "部分的生活例子。" + base
        section["advice"] = ["第" + number + "部分的第一条建议。" + base,
                             "第" + number + "部分的第二条建议。" + base]
    value["sections"][-1]["advice"][-1] += "将想法转化成行动。"
    with pytest.raises(InvalidBaziReport, match="western_plain_language") as error:
        WesternWriter.validate(json.dumps(value, ensure_ascii=False), bundle)
    assert "能量" in error.value.feedback and "转化" in error.value.feedback


def test_guest_session_in_production_does_not_enable_legacy_development_features(app):
    app.state.western_app.settings.app_env = "production"
    with TestClient(app) as client:
        response = client.post("/api/auth/guest")
        assert response.status_code == 201
        headers = {"Authorization": "Bearer " + response.json()["token"]}
        assert client.get("/api/auth/me", headers=headers).json()["kind"] == "guest"
        save(client, headers)
        assert client.get("/api/profile", headers=headers).status_code == 200
        assert client.post("/api/auth/demo").status_code == 403
        assert client.get("/api/history", headers=headers).status_code == 403
        assert client.put("/api/profile", headers=headers,
                          json={k: v for k, v in BIRTH.items() if k != "system"}).status_code == 403


@pytest.mark.parametrize("claim", [
    "Transfer 30 percent of your income to savings every month before considering other financial commitments.",
    "Your family wealth provides a reliable foundation, so you can depend on relatives to support your spending.",
])
def test_money_advice_cannot_invent_family_wealth_or_prescribe_income_ratios(claim):
    bundle = report_bundle(snapshot(chart(), "c1"), chart(), "en")
    value = story(bundle)
    value["sections"][2]["advice"][0] = claim
    with pytest.raises(InvalidBaziReport, match="western_money_assumptions"):
        WesternWriter.validate(json.dumps(value), bundle)

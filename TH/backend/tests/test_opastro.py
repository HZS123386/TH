import asyncio
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
import json
from pathlib import Path
from zoneinfo import ZoneInfo

import httpx
import pytest
from fastapi.testclient import TestClient

from backend.app import thai
from backend.app.config import ProviderConfig, Settings
from backend.app.fortune_reports import FortuneReports, InvalidReport, Story, expand_model_story, grounding, validate_story
from backend.app.main import create_app
from backend.app.storage import Storage
from backend.tests.test_app import login
from backend.tests.test_fortune import DATE_ONLY, NOW
from backend.tests.test_providers import mock_transport
from backend.vendor.opastro.aggregation import _dedupe_period_events, _event_priority, _section_bias
from backend.vendor.opastro.models import Period, PeriodEvent


@pytest.fixture(scope="module")
def values():
    return {period: thai.fortune(DATE_ONLY, period, NOW) for period in ("today", "week", "month")}


def configured(tmp_path, **kwargs):
    return Settings(database_path=str(tmp_path / "reports.db"), providers={"qwen": ProviderConfig("private-test-key", "https://example.test/v1", "qwen3.7-plus")}, **kwargs)


def sample_story(value, language="en"):
    factors = value["analysis"]["factors"]
    sentences = {
        "zh": "当前的星位提供了一个观察生活节奏的角度，给交流留一点空间，也照顾眼前真实的需要。",
        "th": "ตำแหน่งดาวเป็นมุมมองให้สังเกตจังหวะชีวิต ลองเปิดพื้นที่ให้การสื่อสารและดูแลความต้องการของตัวเองอย่างอ่อนโยน",
        "vi": "Vị trí các sao là một góc nhìn để quan sát nhịp sống và dành không gian cho giao tiếp một cách nhẹ nhàng.",
        "en": "The calculated positions offer a perspective on your current rhythm. Make room for a clear conversation while considering your own needs.",
    }
    text = sentences[language]
    return json.dumps({
        "affirmation": text,
        "paragraphs": [{"text": text, "evidence_ids": [factor["id"]]} for factor in factors[:2]],
        "topics": {topic: {"text": text, "outlook": text, "evidence_ids": ids[:1]} for topic, ids in value["analysis"]["topic_factors"].items()},
    }, ensure_ascii=False)


def model_story(value, language="en"):
    story = Story.model_validate_json(sample_story(value, language))
    aliases = {factor["id"]: f"F{index + 1}" for index, factor in enumerate(value["analysis"]["factors"])}
    for row in [*story.paragraphs, *story.topics.values()]:
        row.evidence_ids = [aliases[factor_id] for factor_id in row.evidence_ids]
    return story.model_dump_json(by_alias=True)


def test_upstream_priority_and_deduplication_match_fixed_reference_cases():
    assert _event_priority("ingress", "Jupiter", None, None) == 1.552
    assert _event_priority("exact_aspect", "Sun", "Moon", 2) == 1.62
    assert _section_bias("placement", "Mercury", None) == {"general": 0.6, "communication": 0.9, "career": 0.4, "friendship": 0.3}
    # Thai Ketu is deliberately an unmapped body, not Western South Node.
    assert _event_priority("ingress", "ketu", None, None) == 1.15
    first = PeriodEvent(NOW, "sign_relationship", "Sun", "Mars", aspect="trine", narrative_priority=1)
    duplicate = PeriodEvent(NOW + timedelta(days=2), "sign_relationship", "Sun", "Mars", aspect="trine", narrative_priority=2)
    different = PeriodEvent(NOW + timedelta(days=4), "sign_relationship", "Sun", "Mars", aspect="square", narrative_priority=1)
    assert _dedupe_period_events(Period.WEEKLY, [first, duplicate, different]) == [duplicate, different]
    manifest = json.loads(Path("backend/vendor/opastro/UPSTREAM.json").read_text())
    assert manifest["commit"] == "49276a01831060283f7a991218287e4bc72538e0"
    assert Path("backend/vendor/opastro/LICENSE").read_text() == Path("public/licenses/opastro-MIT.txt").read_text()


def test_period_selection_covers_full_range_and_preserves_unknown_birth(values):
    assert [values[period]["analysis"]["sampling"]["count"] for period in values] == [5, 7, 30]
    for value in values.values():
        assert "analysis_samples" not in value  # Large raw snapshots stay inside the adapter.
        analysis = value["analysis"]
        assert analysis["calculation"] == "native-thai-suriyayatra"
        assert value["birth"]["basis"] != "ascendant"
        assert not value["limits"]["natal_houses_used"]
        ids = {factor["id"] for factor in analysis["factors"]}
        assert all(set(topic_ids) <= ids for topic_ids in analysis["topic_factors"].values())
        for factor in analysis["factors"]:
            for position in factor.get("positions", []):
                assert position["position"] == (factor["sign"] - position["reference_sign"] + 12) % 12 + 1
            assert not {"exactness", "speed", "retrograde", "orb"} & factor.keys()
    assert values["today"]["analysis"]["factors"][0]["bodies"] == ["moon"]
    assert values["month"]["analysis"]["factors"][0]["bodies"] == ["jupiter"]
    assert any(row["kind"] == "sign_change" and row["bodies"] == ["sun"] for row in values["month"]["analysis"]["factors"])


def test_fixed_periods_do_not_change_with_refresh_minute_but_daily_changes_at_midnight(values):
    for period in values:
        later = thai.fortune(DATE_ONLY, period, NOW + timedelta(minutes=45))
        assert later["analysis"]["signature"] == values[period]["analysis"]["signature"]
    next_day = thai.fortune(DATE_ONLY, "today", NOW + timedelta(days=1))
    same_week = thai.fortune(DATE_ONLY, "week", NOW + timedelta(days=1))
    assert next_day["analysis"]["signature"] != values["today"]["analysis"]["signature"]
    assert same_week["analysis"]["signature"] == values["week"]["analysis"]["signature"]
    changed = thai.fortune({**DATE_ONLY, "birth_date": "1999-02-20"}, "week", NOW)
    assert changed["analysis"]["signature"] != values["week"]["analysis"]["signature"]
    boundary = thai.fortune({**DATE_ONLY, "birth_date": "1999-04-14"}, "today", NOW)
    assert len(boundary["birth"]["reference_signs"]) == 2
    assert all(len(factor["positions"]) == 2 for factor in boundary["analysis"]["factors"] if "positions" in factor)


@pytest.mark.parametrize("language", ["zh", "th", "vi", "en"])
def test_structured_report_language_evidence_and_minimal_personal_data(values, language):
    value = values["today"]
    report = validate_story(sample_story(value, language), value, language)
    assert report["language"] == language and report["source"] == "ai"
    payload = json.dumps(grounding(value, language), ensure_ascii=False)
    assert DATE_ONLY["birth_date"] not in payload
    assert DATE_ONLY["display_name"] not in payload
    assert not {"profile", "messages", "memories", "birth_date", "birthplace"} & grounding(value, language).keys()
    assert grounding(value, language)["birth"]["basis"] == value["birth"]["basis"]


def test_compact_protocol_round_trips_to_original_evidence_and_rejects_unknown_aliases(values):
    for value in values.values():
        original = validate_story(sample_story(value), value, "en")
        decoded = expand_model_story(model_story(value), value)
        assert validate_story(decoded, value, "en") == original
        assert len(grounding(value, "en")["factors"]) == len(value["analysis"]["factors"])
        bad = json.loads(model_story(value))
        bad["p"][0]["e"] = ["F999"]
        with pytest.raises(InvalidReport):
            expand_model_story(json.dumps(bad), value)
        for ids in grounding(value, "en")["topic_factors"].values():
            assert set(ids) <= grounding(value, "en")["factors"].keys()


@pytest.mark.parametrize("fault", ["unknown_id", "wrong_topic", "missing_topic", "html", "wrong_language", "not_json", "missing_evidence", "fabricated_house"])
def test_rejects_ungrounded_or_invalid_generated_content(values, fault):
    value = values["today"]
    story = json.loads(sample_story(value))
    if fault == "unknown_id":
        story["paragraphs"][0]["evidence_ids"] = ["made-up-id"]
    elif fault == "wrong_topic":
        story["topics"]["family"]["evidence_ids"] = [next(row["id"] for row in value["analysis"]["factors"] if row["id"] not in value["analysis"]["topic_factors"]["family"])]
    elif fault == "missing_topic":
        story["topics"].pop("love")
    elif fault == "html":
        story["affirmation"] = "<script>bad</script>"
    elif fault == "missing_evidence":
        story["paragraphs"][0].pop("evidence_ids")
    elif fault == "fabricated_house":
        story["paragraphs"][0]["text"] = "The Sun is in your fourth house throughout November."
    with pytest.raises(InvalidReport):
        validate_story("not-json" if fault == "not_json" else json.dumps(story), value, "th" if fault == "wrong_language" else "en")


@pytest.mark.parametrize("language,claim", [
    ("zh", "太阳位于本命第四宫，可以带来很明显的变化。"),
    ("th", "ดาวพุธอยู่ในเรือนที่สองและทำให้เกิดการเปลี่ยนแปลงในช่วงเวลานี้"),
    ("vi", "Sao Thủy đang ở nhà thứ tư và cho thấy sự thay đổi rõ rệt trong cuộc sống."),
    ("en", "The Sun enters your fourth house and will change your daily routine."),
])
def test_each_language_rejects_model_written_positions_even_with_valid_evidence(values, language, claim):
    story = json.loads(sample_story(values["today"], language))
    story["paragraphs"][0]["text"] = claim
    with pytest.raises(InvalidReport, match="calculation_in_prose"):
        validate_story(json.dumps(story), values["today"], language)


def test_cache_identity_is_account_birth_language_period_model_and_rules_scoped(tmp_path, values):
    settings = configured(tmp_path)
    reports = FortuneReports(Storage(settings.database_path), settings, asyncio.Semaphore(1))
    base = reports.key(values["today"], DATE_ONLY, "account:a")
    assert base != reports.key(values["today"], DATE_ONLY, "account:b")
    assert base != reports.key(values["today"], {**DATE_ONLY, "language": "th"}, "account:a")
    assert base != reports.key(values["week"], DATE_ONLY, "account:a")
    assert base != reports.key(values["today"], {**DATE_ONLY, "birth_time": "10:15"}, "account:a")
    assert base == reports.key(values["today"], {**DATE_ONLY, "display_name": "new name", "birthplace": "new free text"}, "account:a")
    settings.providers["qwen"].model = "different-model"
    assert base != reports.key(values["today"], DATE_ONLY, "account:a")
    expiry = datetime.fromtimestamp(reports.expiry(values["today"]), ZoneInfo("Asia/Bangkok"))
    assert expiry.isoformat().startswith("2026-11-06T00:00:00")


def test_atomic_lease_deduplicates_parallel_calls_and_failed_calls_cool_down(tmp_path):
    settings = configured(tmp_path)
    store = Storage(settings.database_path)
    reports = FortuneReports(store, settings, asyncio.Semaphore(1))
    expiry = datetime.now().timestamp() + 3600
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda _: reports.claim("same", "account:a", "network:a", expiry), range(8)))
    assert [state for state, _ in results].count("claimed") == 1
    assert [state for state, _ in results].count("pending") == 7
    lease = next(lease for state, lease in results if state == "claimed")
    reports.finish("same", "wrong-lease", {"source": "wrong"})
    assert reports.cached("same") is None
    reports.finish("same", lease)
    assert reports.claim("same", "account:a", "network:a", expiry)[0] == "cooldown"
    with store.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM fortune_usage WHERE scope='account:a'").fetchone()[0] == 1


def test_cache_expiry_account_limit_and_shared_network_limit_are_enforced(tmp_path, monkeypatch):
    settings = configured(tmp_path, fortune_per_day=1, fortune_network_per_day=2)
    reports = FortuneReports(Storage(settings.database_path), settings, asyncio.Semaphore(1))
    monkeypatch.setattr("backend.app.fortune_reports.time.time", lambda: 10000)
    state, lease = reports.claim("a", "account:a", "network:shared", 10010)
    assert state == "claimed"
    reports.finish("a", lease, {"source": "ai"})
    assert reports.claim("a", "account:a", "network:shared", 10010)[0] == "cached"
    assert reports.claim("new-a", "account:a", "network:shared", 20000)[0] == "limited"
    assert reports.claim("b", "account:b", "network:shared", 20000)[0] == "claimed"
    assert reports.claim("c", "account:c", "network:shared", 20000)[0] == "limited"
    monkeypatch.setattr("backend.app.fortune_reports.time.time", lambda: 10011)
    assert reports.cached("a") is None


def test_model_api_protocol_cache_reuse_and_no_profile_or_history_leak(tmp_path, monkeypatch):
    settings = configured(tmp_path)
    value = thai.fortune(DATE_ONLY, "today")
    calls = []

    def handler(request):
        payload = json.loads(request.content)
        assert request.headers["authorization"] == "Bearer private-test-key"
        assert payload["response_format"] == {"type": "json_object"}
        assert payload["enable_thinking"] is False and payload["stream"] is False
        assert DATE_ONLY["birth_date"] not in json.dumps(payload)
        assert DATE_ONLY["display_name"] not in json.dumps(payload)
        calls.append(payload)
        return httpx.Response(200, json={"choices": [{"finish_reason": "stop", "message": {"content": model_story(value, "zh")}}]})

    mock_transport(monkeypatch, handler)
    with TestClient(create_app(settings)) as client:
        body = {"profile": DATE_ONLY, "period": "today"}
        first = client.post("/api/fortune", json=body).json()
        assert first["generation"]["available"] and first["narrative"]["source"] == "rules"
        assert not calls
        request = {**body, "for_date": first["calendar"]["date"]}
        written = client.post("/api/fortune/narrative", json=request)
        assert written.status_code == 200
        assert written.json()["narrative"]["source"] == "ai"
        cached = client.post("/api/fortune/narrative", json=request).json()
        assert cached["generation"]["cached"] and len(calls) == 1
        assert client.post("/api/fortune", json=body).json()["narrative"] == cached["narrative"]
        headers = login(client)
        assert client.post("/api/fortune", headers=headers, json=body).json()["narrative"]["source"] == "rules"
        stale = client.post("/api/fortune/narrative", json={**request, "for_date": "2026-01-01"})
        assert stale.status_code == 409 and len(calls) == 1
        invalid = client.post("/api/fortune/narrative", headers={"Authorization": "Bearer invalid"}, json=request)
        assert invalid.status_code == 401 and len(calls) == 1
        with client.app.state.store.connect() as db:
            assert db.execute("SELECT COUNT(*) FROM profiles").fetchone()[0] == 0
        assert "private-test-key" not in written.text


def test_chat_reuses_only_the_same_account_cached_report_and_native_factors(tmp_path):
    settings = configured(tmp_path)
    with TestClient(create_app(settings)) as client:
        first, second = login(client), login(client)
        for headers in (first, second):
            assert client.put("/api/profile", headers=headers, json=DATE_ONLY).status_code == 200
        value = client.post("/api/fortune", headers=first, json={"profile": DATE_ONLY, "period": "week"}).json()
        reports = client.app.state.fortune_reports
        owner = "account:" + client.app.state.store.hash(client.get("/api/auth/me", headers=first).json()["user_id"])
        key = reports.key(value, DATE_ONLY, owner)
        _, lease = reports.claim(key, owner, "test-network", reports.expiry(value))
        written = validate_story(sample_story(value, "zh"), value, "zh")
        reports.finish(key, lease, written)
        captured = []

        async def stream(name, profile, *args, **kwargs):
            captured.append(profile)
            yield "A complete test answer"

        client.app.state.registry.stream = stream
        for headers in (first, second):
            response = client.post("/api/chat", headers=headers, json={"provider": "mock", "message": "本周工作运势如何？", "period": "week"})
            assert response.status_code == 200
        own, other = [item["thai_fortunes"][0] for item in captured]
        assert own["narrative"] == written
        assert other["narrative"].get("source") != "ai"
        assert own["analysis"]["calculation"] == "native-thai-suriyayatra"
        assert own["analysis"]["ranking"] == "editorial-relevance-not-probability"
        assert own["readings"]["work"]["localized_guidance"]["interpretation"] == written["topics"]["work"]["text"]


@pytest.mark.parametrize("failure", ["status", "truncated", "malformed", "timeout"])
def test_paid_failure_keeps_reading_available_without_repeated_billing(tmp_path, monkeypatch, values, failure):
    monkeypatch.setattr("backend.app.fortune_reports.time.time", lambda: NOW.timestamp())
    settings = configured(tmp_path)
    reports = FortuneReports(Storage(settings.database_path), settings, asyncio.Semaphore(1))
    calls = []

    def handler(request):
        calls.append(True)
        if failure == "timeout":
            raise httpx.ReadTimeout("secret upstream details")
        return httpx.Response(503 if failure == "status" else 200, json={"choices": [{"finish_reason": "length" if failure == "truncated" else "stop", "message": {"content": "invalid"}}]})

    mock_transport(monkeypatch, handler)
    result = asyncio.run(reports.generate(values["today"], DATE_ONLY, "owner", "network"))
    assert result["narrative"]["source"] == "rules"
    assert result["generation"]["reason"] == "unavailable"
    retry = asyncio.run(reports.generate(values["today"], DATE_ONLY, "owner", "network"))
    assert retry["generation"]["reason"] == "cooldown" and len(calls) == 1

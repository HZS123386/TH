import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from backend.app import thai
from backend.app.config import Settings
from backend.app.main import create_app
from backend.app.providers import context, route_tools
from backend.tests.test_app import PROFILE, login


@pytest.fixture
def client(tmp_path):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "thai.db")))) as client:
        yield client


def save(client, headers, **patch):
    response = client.put("/api/profile", headers=headers, json={**PROFILE, **patch})
    assert response.status_code == 200
    return response.json()


def test_actual_thai_chart_is_authenticated_account_scoped_and_cached(client, monkeypatch):
    assert client.get("/api/thai-chart").status_code == 401
    first, other = login(client), login(client)
    assert client.get("/api/thai-chart", headers=first).status_code == 422
    save(client, first, birth_date="2024-09-15", birth_time="08:30", birthplace="Chiang Mai")
    chart = client.get("/api/thai-chart", headers=first).json()
    assert chart["status"] == "ready"
    assert chart["chart"]["points"]["ascendant"]["signName"] == "กันย์"
    assert chart["chart"]["points"]["sun"]["signName"] == "สิงห์"
    assert chart["chart"]["charts"]["rasi"]["channels"]["thai"][5] == "ลั๖"
    assert chart["engine"]["version"] == "0.3.2"
    assert client.get("/api/thai-chart", headers=other).status_code == 422

    def cannot_recompute(*args):
        raise AssertionError("Expected persisted cache")

    monkeypatch.setattr(thai, "natal", cannot_recompute)
    assert client.get("/api/thai-chart", headers=first).json() == chart
    save(client, first, birth_date="2024-09-15", birth_time="08:30", birthplace="Chiang Mai")
    assert client.get("/api/thai-chart", headers=first).json()["profile_revision"] == 2


def test_changed_birth_data_invalidates_thai_cache(client):
    headers = login(client)
    save(client, headers)
    before = client.get("/api/thai-chart", headers=headers).json()
    save(client, headers, birth_time="15:30")
    after = client.get("/api/thai-chart", headers=headers).json()
    assert after["profile_revision"] == 2
    assert before["chart"]["points"]["ascendant"] != after["chart"]["points"]["ascendant"]


def test_unknown_time_keeps_calendar_without_inferred_planets_or_taksa(client):
    headers = login(client)
    save(client, headers, birth_time=None)
    result = client.get("/api/thai-chart", headers=headers).json()
    assert result["status"] == "time-unknown"
    assert result["chart"] is None and result["taksa"] is None
    assert result["calendar"]["civilWeekday"] == 5
    assert result["calendar"]["astrologicalWeekday"] is None
    assert client.get("/api/thai-transits", headers=headers).json()["status"] == "time-unknown"


def test_catalog_coordinates_and_explicit_offset_are_used(client):
    rows = client.get("/api/thai-locations?country=TH").json()
    assert len([row for row in rows["items"] if row["coordinateKind"] == "province-seat"]) == 77
    place = next(row for row in rows["items"] if row["nameEnglish"] == "Chiang Mai")
    headers = login(client)
    save(client, headers, birthplace="user label", country_code="TH", location_id=place["id"])
    chart = client.get("/api/thai-chart", headers=headers).json()
    assert chart["location"]["id"] == place["id"]
    assert chart["chart"]["input"]["ascendantReference"]["latitude"] == place["latitude"]
    assert chart["chart"]["input"]["planetaryTimeReference"] == {"civilUtcOffsetSeconds": 25200, "referenceUtcOffsetSeconds": 24124}
    save(client, headers, birthplace="custom", latitude=13.76, longitude=100.50)
    chart = client.get("/api/thai-chart", headers=headers).json()
    assert chart["location"]["coordinateKind"] == "user-supplied"
    assert chart["chart"]["input"]["ascendantReference"]["latitude"] == 13.76


def test_unknown_city_never_falls_back_to_bangkok(client):
    headers = login(client)
    save(client, headers, birthplace="Unknown village")
    result = client.get("/api/thai-chart", headers=headers).json()
    assert result["status"] == "location-required" and result["chart"] is None
    assert result["taksa"]["method"] == "weekday-0600"


@pytest.mark.parametrize("patch", [{"latitude": 13.7}, {"longitude": 100.5}, {"latitude": 91, "longitude": 0}, {"latitude": 0, "longitude": 181}, {"location_id": "../../secret"}])
def test_invalid_spatial_inputs_are_rejected(client, patch):
    headers = login(client)
    assert client.put("/api/profile", headers=headers, json={**PROFILE, **patch}).status_code == 422


def test_current_transits_are_real_timestamped_and_located_in_natal_houses(client):
    headers = login(client)
    save(client, headers)
    natal = client.get("/api/thai-chart", headers=headers).json()["chart"]
    result = client.get("/api/thai-transits", headers=headers).json()
    assert result["status"] == "ready"
    assert abs((datetime.now(timezone.utc) - datetime.fromisoformat(result["calculated_at"])).total_seconds()) < 30
    assert len(result["comparison"]) == 10
    for key, factor in result["comparison"].items():
        assert factor["natalHouse"] == (result["transit"]["points"][key]["sign"] - natal["points"]["ascendant"]["sign"]) % 12 + 1


def test_chat_routes_thai_by_default_and_bazi_only_when_explicit(client):
    headers = login(client)
    save(client, headers)
    captured = []

    async def capture(provider, record, memories, history, question):
        captured.append(record)
        yield "captured"

    client.app.state.registry.stream = capture
    assert "event: done" in client.post("/api/chat", headers=headers, json={"message": "我的工作"}).text
    assert captured[-1]["astrology_system"] == "thai-suriyayatra"
    assert captured[-1]["thai_calculation"]["status"] == "ready"
    messages = context(captured[-1], [], [], "工作")
    assert "chart" not in json.loads(messages[1]["content"].split("\n", 1)[1])["profile"]
    client.post("/api/chat", headers=headers, json={"message": "看一下八字"})
    assert captured[-1]["astrology_system"] == "bazi" and "thai_calculation" not in captured[-1]
    client.post("/api/chat", headers=headers, json={"message": "ดูดาวจร"})
    assert captured[-1]["thai_transits"]["status"] == "ready"
    for text in ("transit", "行运", "ดาวจร", "quá cảnh"):
        assert route_tools(text) == "thai-transits"


def test_engine_failure_is_visible_and_chat_does_not_substitute_bazi(client, monkeypatch):
    headers = login(client)
    save(client, headers)

    def unavailable(*args):
        raise RuntimeError("thai_engine_unavailable")

    monkeypatch.setattr(thai, "natal", unavailable)
    response = client.get("/api/thai-chart", headers={**headers, "Accept-Language": "en-US"})
    assert response.status_code == 503 and response.json()["code"] == "thai_engine_unavailable"
    result = client.post("/api/chat", headers=headers, json={"message": "你好"})
    answer = "".join(json.loads(frame.split("data: ", 1)[1])["text"] for frame in result.text.split("\n\n") if frame.startswith("event: token\n"))
    assert "暂不推测" in answer and "你的四柱" not in answer


def test_python_utc_offsets_match_pinned_iana_facts_including_gaps_and_folds():
    fixture = json.loads((Path(__file__).resolve().parents[2] / "scripts/fixtures/thai/iana-2025b.json").read_text(encoding="utf-8"))
    for row in fixture["cases"]:
        civil = row["civilTime"]
        profile = {"birth_date": f"{civil['yearCe']:04}-{civil['month']:02}-{civil['day']:02}", "birth_time": f"{civil['hour']:02}:{civil['minute']:02}", "timezone": row["timeZone"]}
        if len(row["candidates"]) != 1:
            with pytest.raises(ValueError, match="birth_time_invalid"):
                thai.offset_for(profile)
        else:
            candidate = row["candidates"][0]
            assert thai.offset_for(profile) == round(candidate["utcOffsetHours"] * 3600)
            instant = datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(milliseconds=candidate["utcEpochMilliseconds"])
            assert instant.astimezone(ZoneInfo(row["timeZone"])).strftime("%Y-%m-%d %H:%M") == profile["birth_date"] + " " + profile["birth_time"]

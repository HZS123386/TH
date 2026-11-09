import sqlite3
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from backend.app import thai
from backend.app.config import Settings
from backend.app.main import create_app
from backend.tests.test_app import PROFILE, login

NOW = datetime(2026, 11, 5, 14, 20, tzinfo=ZoneInfo("Asia/Bangkok"))
DATE_ONLY = {**PROFILE, "birth_time": None, "birthplace": ""}


@pytest.fixture
def client(tmp_path):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "fortune.db")))) as client:
        yield client


@pytest.mark.parametrize("period,start,end,count,method", [
    ("today", "2026-11-05", "2026-11-05", 1, "current-minute"),
    ("week", "2026-11-02", "2026-11-08", 7, "daily-noon"),
    ("month", "2026-11-01", "2026-11-30", 30, "daily-noon"),
])
def test_periods_use_real_thai_positions_over_their_own_window(period, start, end, count, method):
    result = thai.fortune(DATE_ONLY, period, NOW)
    assert (result["period_start"], result["period_end"]) == (start, end)
    assert result["sampling"]["count"] == count
    assert result["sampling"]["method"] == method
    assert result["engine"]["name"] == "thai-astrology"
    assert result["limits"]["predictive_accuracy"] == "not-established"
    for reading in result["readings"].values():
        for alt in reading["alternatives"]:
            assert len(alt["evidence"]) == count
            assert sum(alt["counts"].values()) == count
            for row in alt["evidence"]:
                assert row["position"] == (row["sign"] - row["reference_sign"] + 12) % 12 + 1
                assert 0 <= row["longitude"] < 360


def test_birthdays_change_references_and_calculated_guidance():
    one = thai.fortune(DATE_ONLY, "month", NOW)
    other = thai.fortune({**DATE_ONLY, "birth_date": "1999-02-20"}, "month", NOW)
    assert one["birth"]["reference_signs"] != other["birth"]["reference_signs"]
    assert one["readings"] != other["readings"]
    assert one["birth"]["taksa"] is None
    assert one["birth"]["astrological_weekday"] is None
    assert not one["limits"]["natal_houses_used"]


def test_precise_birth_uses_same_ascendant_as_integrated_natal_engine():
    result = thai.fortune(PROFILE, "today", NOW)
    natal = thai.natal(PROFILE)
    assert result["birth"]["basis"] == "ascendant"
    assert result["birth"]["reference_signs"] == [natal["chart"]["points"]["ascendant"]["sign"]]
    assert result["birth"]["taksa"] == natal["taksa"]
    assert result["limits"]["natal_houses_used"]


def test_missing_city_preserves_worldwide_window_instead_of_assuming_bangkok(monkeypatch):
    monkeypatch.setattr(thai, "_run", lambda payload: {**payload, "analysis_samples": []})
    monkeypatch.setattr(thai, "analyze", lambda value, samples: {})
    result = thai.fortune(DATE_ONLY, "today", NOW)
    assert not result["zone_known"]
    assert result["birth_window"] == [{"time": "00:00", "offset_seconds": 50400}, {"time": "23:59", "offset_seconds": -43200}]
    exact_clock = thai.fortune({**DATE_ONLY, "birth_time": "15:20"}, "today", NOW)
    assert [row["time"] for row in exact_clock["birth_window"]] == ["15:20", "15:20"]
    known_city = thai.fortune({**DATE_ONLY, "birthplace": "Bangkok"}, "today", NOW)
    assert known_city["zone_known"]
    assert {row["offset_seconds"] for row in known_city["birth_window"]} == {25200}


def test_sun_boundary_keeps_both_possible_references():
    result = thai.fortune({**DATE_ONLY, "birth_date": "1999-04-14"}, "today", NOW)
    assert result["birth"]["basis"] == "sun-sign-range"
    assert len(result["birth"]["reference_signs"]) == 2
    for reading in result["readings"].values():
        assert len(reading["alternatives"]) == 2
        if not reading["consistent_across_birth_window"]:
            assert reading["code"] == "mixed"


def test_bangkok_day_and_week_cross_year_and_leap_month():
    leap = thai.fortune(DATE_ONLY, "month", datetime(2024, 2, 5, tzinfo=timezone.utc))
    assert leap["period_end"] == "2024-02-29" and leap["sampling"]["count"] == 29
    new_year = thai.fortune(DATE_ONLY, "week", datetime(2026, 12, 31, 20, tzinfo=timezone.utc))
    assert new_year["as_of"].startswith("2027-01-01T03:")
    assert (new_year["period_start"], new_year["period_end"]) == ("2026-12-28", "2027-01-03")


def test_unknown_clock_handles_midnight_dst_gap_and_skipped_civil_day():
    window = thai.civil_day_window({**DATE_ONLY, "birth_date": "2018-11-04", "timezone": "America/Sao_Paulo"})
    assert window[0]["time"] == "01:00"
    assert window[-1]["time"] == "23:59"
    with pytest.raises(ValueError, match="birth_date_does_not_exist"):
        thai.civil_day_window({**DATE_ONLY, "birth_date": "2011-12-30", "timezone": "Pacific/Apia"})


def test_known_clock_rejects_dst_gap_or_fold():
    for day, clock in [("2024-03-10", "02:30"), ("2024-11-03", "01:30")]:
        with pytest.raises(ValueError):
            thai.fortune({**PROFILE, "birth_date": day, "birth_time": clock, "timezone": "America/New_York"}, "today", NOW)


def test_free_api_requires_date_but_neither_account_time_nor_city(client, tmp_path):
    assert client.post("/api/fortune", json={"profile": {}}).status_code == 422
    assert client.post("/api/fortune", json={"profile": {"birth_date": "1999-02-30"}}).status_code == 422
    assert client.post("/api/fortune", json={"profile": DATE_ONLY, "period": "other"}).status_code == 422
    assert client.post("/api/fortune", json={"profile": DATE_ONLY, "period": "year"}).status_code == 422
    result = client.post("/api/fortune", json={"profile": {"birth_date": "1999-02-20"}, "period": "week"})
    assert result.status_code == 200
    assert result.json()["birth"]["date"] == "1999-02-20"
    with sqlite3.connect(tmp_path / "fortune.db") as database:
        for table in ("users", "profiles"):
            assert database.execute(f"SELECT count(*) FROM {table}").fetchone()[0] == 0


def test_guest_preview_is_stateless_and_never_replaces_an_account_birth(client):
    headers = login(client)
    assert client.put("/api/profile", json=PROFILE, headers=headers).status_code == 200
    assert client.post("/api/thai-chart/preview", json=PROFILE).json()["status"] == "ready"
    assert client.post("/api/thai-transits/preview", json=PROFILE).json()["status"] == "ready"
    assert client.post("/api/thai-chart/preview", json=DATE_ONLY).json()["chart"] is None
    assert client.post("/api/fortune", json={"profile": {**DATE_ONLY, "birth_date": "1999-02-20"}}, headers=headers).status_code == 200
    assert client.get("/api/profile", headers=headers).json()["profile"]["birth_date"] == PROFILE["birth_date"]


def test_free_calculation_failure_returns_error_without_fake_fallback(client, monkeypatch):
    def unavailable(*args):
        raise RuntimeError("thai_calculation_failed")
    monkeypatch.setattr(thai, "fortune", unavailable)
    assert client.post("/api/fortune", json={"profile": DATE_ONLY}).status_code == 503

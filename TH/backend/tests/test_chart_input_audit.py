from datetime import datetime, timezone

import pytest

from backend.app import thai


PROFILE = {"birth_date": "1999-02-20", "birth_time": "07:15", "timezone": "Asia/Shanghai", "birthplace": "Beijing", "country_code": "CN", "language": "zh"}


def test_confirmed_beijing_morning_input_is_not_shifted_to_evening():
    result = thai.natal(PROFILE)
    assert result["status"] == "ready"
    spec = result["calculation_input"]
    assert spec["local_datetime"] == "1999-02-20T07:15+08:00"
    assert spec["utc_datetime"] == "1999-02-19T23:15+00:00"
    assert spec["utc_offset_seconds"] == 28800
    assert spec["house_system"] == "whole-sign"
    assert spec["relationship_model"] == "sign-based"
    assert result["location"]["latitude"] == 39.9075
    assert result["location"]["longitude"] == 116.39723
    chart = result["chart"]
    assert chart["input"]["time"]["hour"] == 7
    assert chart["points"]["sun"]["longitudeDegrees"] == pytest.approx(306.93333333333334)
    assert chart["points"]["moon"]["longitudeDegrees"] == pytest.approx(355.23333333333335)
    assert chart["points"]["ascendant"]["longitudeDegrees"] == pytest.approx(310.99583333333334)
    # A fixed regression of the selected Thai model; not a modern-ephemeris accuracy claim.
    other = thai.natal({**PROFILE, "birth_time": "19:15"})
    assert other["calculation_input"]["utc_datetime"] == "1999-02-20T11:15+00:00"
    assert other["chart"]["points"]["moon"]["sign"] == 0
    assert other["chart"]["points"]["ascendant"]["sign"] == 4


def test_native_planet_clock_represents_the_same_instant_as_entered_local_time():
    chart = thai.natal(PROFILE)["chart"]
    frame = chart["input"]["planetaryTimeReference"]
    assert frame == {"civilUtcOffsetSeconds": 28800, "referenceUtcOffsetSeconds": 24124}
    assert datetime.fromisoformat(thai.natal(PROFILE)["calculation_input"]["utc_datetime"]).astimezone(timezone.utc).hour == 23


def test_missing_birth_time_does_not_get_a_fabricated_utc_instant():
    result = thai.natal({**PROFILE, "birth_time": None})
    assert "calculation_input" not in result
    assert result["chart"] is None

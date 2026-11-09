from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from backend.app import thai
from backend.app.fortune_narrative import content, narrative
from backend.tests.test_fortune import DATE_ONLY, NOW


def test_daily_reading_changes_its_actual_body_with_calendar_not_only_date_label():
    values = [thai.fortune(DATE_ONLY, "today", NOW + timedelta(days=offset)) for offset in range(3)]
    stories = [narrative(value, "zh") for value in values]
    assert len({story["paragraphs"][1] for story in stories}) == 3
    assert len({value["calendar"]["moon"]["longitude"] for value in values}) == 3
    for value, story in zip(values, stories):
        assert story["date"] == value["period_start"]
        assert story["basis"]["birth_date"] == DATE_ONLY["birth_date"]
        assert story["basis"]["reference_signs"] == value["birth"]["reference_signs"]
        assert story["basis"]["calendar"] == value["calendar"]
        assert "记录一笔" not in str(story)


@pytest.mark.parametrize("language", ["zh", "th", "vi", "en"])
def test_every_language_uses_current_native_facts_and_same_period_sampling(language):
    copy, _ = content(language)
    values = [thai.fortune(DATE_ONLY, period, NOW) for period in ("today", "week", "month")]
    for value in values:
        story = narrative(value, language)
        assert story["language"] == language
        assert len(story["paragraphs"]) == 3
        assert all("{{" not in paragraph for paragraph in story["paragraphs"])
        for topic, reading in value["readings"].items():
            assert story["topics"][topic]["text"] == copy["topics"][topic][reading["code"]]
        if value["period"] != "today":
            assert all(label in story["paragraphs"][1] for label in copy["stages"][value["period"]])


def test_birth_changes_reading_and_uncertain_birth_keeps_both_references():
    first = thai.fortune({**DATE_ONLY, "birth_date": "1999-02-20"}, "today", NOW)
    other = thai.fortune({**DATE_ONLY, "birth_date": "1995-08-17"}, "today", NOW)
    assert narrative(first, "zh")["paragraphs"] != narrative(other, "zh")["paragraphs"]
    boundary = thai.fortune({**DATE_ONLY, "birth_date": "1999-04-14"}, "today", NOW)
    story = narrative(boundary, "zh")
    assert len(story["basis"]["reference_signs"]) == 2
    assert content("zh")[0]["uncertain"] in story["paragraphs"][1]


def test_calendar_refreshes_on_bangkok_date_boundary_and_handles_missing_lunar_data():
    midnight = datetime(2026, 11, 6, 0, 0, tzinfo=ZoneInfo("Asia/Bangkok"))
    before = thai.fortune(DATE_ONLY, "today", midnight - timedelta(minutes=1))
    after = thai.fortune(DATE_ONLY, "today", midnight)
    assert narrative(before, "en")["date"] == "2026-11-05"
    assert narrative(after, "en")["date"] == "2026-11-06"
    assert narrative(before, "en")["paragraphs"][1] != narrative(after, "en")["paragraphs"][1]
    after["calendar"]["thai_lunar_date"] = None
    assert narrative(after, "en")["paragraphs"][-1] == content("en")[0]["phases"]["unknown"]

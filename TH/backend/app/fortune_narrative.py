"""Date-specific editorial reading of calculated Thai calendar and transit facts."""
import json
from functools import lru_cache
from pathlib import Path

VERSION = "wanjai-calendar-narrative-1"
ROOT = Path(__file__).resolve().parents[2]


@lru_cache(maxsize=4)
def content(language: str):
    language = language if language in ("zh", "th", "vi", "en") else "th"
    copy = json.loads((ROOT / "backend" / "content" / "fortune.json").read_text(encoding="utf-8"))[language]
    signs = json.loads((ROOT / "src" / "data" / f"wanjai-{language}.json").read_text(encoding="utf-8"))["signs"]
    return copy, signs


def render(template: str, **values):
    for key, value in values.items():
        template = template.replace("{{" + key + "}}", str(value))
    return template


def narrative(value: dict, language: str):
    copy, signs = content(language)
    calendar, birth, period = value["calendar"], value["birth"], value["period"]
    weekday = calendar["civil_weekday"] - 1  # Native calendar: Sunday=1.
    names = " / ".join(signs[index]["name"] for index in birth["reference_signs"])
    reference = render(copy["reference"][birth["basis"]], sign=names)
    lunar = calendar["thai_lunar_date"]
    phase = f"{lunar['phase']}_{min((lunar['day'] - 1) // 5, 2)}" if lunar else "unknown"

    def theme(positions):
        return copy["themes"][positions[0] - 1] if len(set(positions)) == 1 else copy["uncertain"]

    paragraphs = [render(copy["opening"][period], reference=reference, weekday=copy["weekdays"][weekday])]
    if period == "today":
        paragraphs.append(theme(calendar["moon"]["reference_positions"]) + " " + copy["day_notes"][weekday])
    else:
        alternatives = value["readings"]["family"]["alternatives"]
        count = value["sampling"]["count"]
        indices = [0, (count - 1) // 2, count - 1]
        stages = []
        for index, label in zip(indices, copy["stages"][period]):
            positions = [alt["evidence"][index]["position"] for alt in alternatives]
            text = theme(positions)
            if language in ("en", "vi"):
                text = text[0].lower() + text[1:]
            stages.append(label + text)
        paragraphs.append(" ".join(stages))
    paragraphs.append(copy["phases"][phase])
    topics = {
        topic: {
            "text": copy["topics"][topic][reading["code"]],
            "outlook": render(copy["outlook"][period], theme=theme(calendar["moon"]["reference_positions"])),
        }
        for topic, reading in value["readings"].items()
    }
    return {
        "version": VERSION,
        "language": language,
        "date": calendar["date"],
        "affirmation": copy["affirmations"][weekday],
        "paragraphs": paragraphs,
        "topics": topics,
        "basis": {"birth_date": birth["date"], "reference_signs": birth["reference_signs"], "calendar": calendar},
    }

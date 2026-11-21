"""Additional landing/report languages; existing APP language choices stay unchanged."""
import json
from pathlib import Path

REGIONAL_LANGUAGES = json.loads(
    (Path(__file__).resolve().parents[1] / "content" / "report-languages.json").read_text(encoding="utf-8")
)
LANGUAGE_NAMES = {
    "zh": "Simplified Chinese", "th": "natural Thai", "en": "plain English", "vi": "natural Vietnamese",
    **{code: copy["language_name"] for code, copy in REGIONAL_LANGUAGES.items()},
}

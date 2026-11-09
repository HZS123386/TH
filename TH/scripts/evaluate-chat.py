"""Produce synthetic conversation samples for human review; no automated satisfaction claim.

Usage: node scripts/python.mjs scripts/evaluate-chat.py --provider qwen
The default --provider mock is an offline plumbing check. Real providers consume API quota.
"""
import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from tempfile import TemporaryDirectory
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from backend.app.config import ProviderConfig, Settings
from backend.app.main import create_app

CASES = [
    ("th-work", "th", "ฉันทำงานกะกลางคืนและกำลังหางานใหม่ ยังต้องส่งเงินให้แม่ จึงอยากมีงานใหม่ก่อนลาออก", "ช่วงนี้รู้สึกไม่ไหวกับงาน แต่ยังออกไม่ได้ สัปดาห์นี้ควรเริ่มจากอะไรดี", True),
    ("th-relationship", "th", "เพิ่งเลิกกับแฟนและยังไม่พร้อมเริ่มความสัมพันธ์ใหม่", "ฉันเหงา แต่ไม่อยากรีบเริ่มกับใคร ช่วยคิดก้าวเล็ก ๆ สำหรับวันนี้หน่อย", False),
    ("th-unknown-time", "th", "ไม่ทราบเวลาเกิดและไม่อยากให้เดาข้อมูลส่วนตัว", "ไม่รู้เวลาเกิด แต่ช่วยบอกลัคนาให้แน่นอนเลยได้ไหม", False),
    ("zh-followup", "zh", "正在转行，优先保持收入，不想立刻辞职。", "我之前说过自己在犹豫什么？今天想推进一点，但不想一下子做太多。", True),
    ("vi-family", "vi", "Tôi đang chăm sóc mẹ và muốn giữ một chút thời gian cho mình mỗi ngày.", "Tôi thấy có lỗi khi muốn nghỉ ngơi. Hôm nay tôi có thể bắt đầu từ việc gì nhỏ?", False),
    ("en-boundary", "en", "I am not ready to date and prefer practical suggestions, one step at a time.", "Someone keeps pushing me to date again. What could I say without explaining everything?", True),
]


def frames(text, event):
    return [json.loads(frame.split("data: ", 1)[1]) for frame in text.split("\n\n") if frame.startswith(f"event: {event}\n")]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--provider", choices=["mock", "qwen", "openai", "deepseek", "kimi", "companion"], default="mock")
    parser.add_argument("--case", action="append", choices=[case[0] for case in CASES], help="Run selected cases only; may be repeated.")
    options = parser.parse_args()
    settings = Settings.from_env()
    if options.provider == "mock":
        settings.embeddings = ProviderConfig()
    configured = any(settings.providers.get(name) and settings.providers[name].enabled for name in ("qwen", "kimi")) if options.provider == "companion" else options.provider in settings.providers and settings.providers[options.provider].enabled
    if options.provider != "mock" and not configured:
        raise SystemExit("Provider is not configured. Fill the matching API_KEY, BASE_URL and MODEL in .env first.")
    results = []
    with TemporaryDirectory(prefix="wanjai-chat-eval-") as directory:
        settings.database_path = str(Path(directory) / "evaluation.db")
        settings.app_env = "development"
        with TestClient(create_app(settings)) as client:
            for name, language, note, question, known in CASES:
                if options.case and name not in options.case:
                    continue
                token = client.post("/api/auth/demo").json()["token"]
                headers = {"Authorization": "Bearer " + token, "Accept-Language": language}
                profile = {"display_name": "Nok", "birth_date": "1995-08-17", "birth_time": "09:30" if known else None, "timezone": "Asia/Bangkok", "birthplace": "Bangkok" if known else "", "language": language}
                client.put("/api/profile", headers=headers, json=profile).raise_for_status()
                client.post("/api/memories", headers=headers, json={"content": note}).raise_for_status()
                response = client.post("/api/chat", headers=headers, json={"provider": options.provider, "message": question, "period": "today"})
                metadata = frames(response.text, "metadata")
                answer = "".join(row["text"] for row in frames(response.text, "token"))
                results.append({"case": name, "language": language, "confirmed_note": note, "question": question, "reply": answer, "completed": bool(frames(response.text, "done")), "errors": frames(response.text, "error"), "http_status": response.status_code, "metadata": metadata, "human_review": {key: None for key in ("responds_to_actual_problem", "uses_memory_correctly", "natural_language", "grounded_facts", "manageable_next_step", "overall_helpfulness")}})
    output = Path("data/evals")
    output.mkdir(parents=True, exist_ok=True)
    date = datetime.now(ZoneInfo("Asia/Bangkok")).strftime("%Y%m%d-%H%M%S")
    path = output / f"chat-{options.provider}-{date}.json"
    path.write_text(json.dumps({"provider": options.provider, "demo_only": options.provider == "mock", "predictive_accuracy": "not-measured", "satisfaction": "requires-human-review", "samples": results}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Saved {len(results)} synthetic samples to {path}. Human quality ratings are intentionally blank.")
    if not all(row["completed"] for row in results):
        raise SystemExit("One or more replies failed. Inspect the local report; no success rate or satisfaction score is claimed.")


if __name__ == "__main__":
    main()

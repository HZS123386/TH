from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient

from backend.app.config import Settings
from backend.app.main import create_app
from backend.tests.test_app import login
from backend.app.companion_context import preferences


def test_jy_preferences_and_simulation_records_are_bound_to_the_account(tmp_path):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "jy.db")))) as client:
        a, b = login(client), login(client)
        body = {
            "taste": {"style": "cool", "category": "crystal", "budget": 500},
            "demo_orders": [{"id": "demo-1", "product": "purple", "size": "standard", "quantity": 2, "total": 980, "day": "2026-01-01"}],
        }
        assert client.put("/api/companion", headers=a, json=body).status_code == 200
        saved = client.get("/api/companion", headers=a).json()
        assert saved["taste"] == body["taste"] and saved["demo_orders"] == body["demo_orders"]
        other = client.get("/api/companion", headers=b).json()
        assert other is None
        reference = preferences(saved, "zh")
        assert reference["style_preference"] == "安静的冷色" and reference["accessory_budget_thb"] == 500
        assert "demo_orders" not in reference


@pytest.mark.parametrize(
    "invalid",
    [
        {"taste": {"budget": -1}},
        {"taste": {"style": "guaranteed-luck"}},
        {"demo_orders": [{"id": "demo-1", "product": "moon", "size": "16 cm", "quantity": 0, "total": 490, "day": "2026-01-01"}]},
        {
            "demo_orders": [
                {
                    "id": "demo-1",
                    "product": "moon",
                    "size": "16 cm",
                    "quantity": 1,
                    "total": 490,
                    "day": (datetime.now(ZoneInfo("Asia/Bangkok")).date() + timedelta(days=1)).isoformat(),
                }
            ]
        },
    ],
)
def test_jy_state_rejects_invalid_or_future_receipts(tmp_path, invalid):
    with TestClient(create_app(Settings(database_path=str(tmp_path / "invalid.db")))) as client:
        headers = login(client)
        assert client.put("/api/companion", headers=headers, json=invalid).status_code == 422

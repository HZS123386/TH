import json
import subprocess
import sys
import time
from pathlib import Path
from uuid import uuid4

import pytest

from backend.tests.test_life_reports import HEADERS, client, preview


OTHER = {**HEADERS, "X-Report-Key": "another-device-owner-key-with-over-thirty-two-characters"}


def visit(http):
    visit_id = str(uuid4())
    result = http.post("/api/landing/visits", json={"id": visit_id, "source": "facebook", "campaign": "fortune-th"}, headers=HEADERS)
    assert result.status_code == 200, result.text
    return visit_id


def event(http, visit_id, report_id, name, headers=HEADERS):
    return http.post(f"/api/landing/visits/{visit_id}/events", json={"report_id": report_id, "event": name}, headers=headers)


def test_config_exposes_only_public_support_and_notice_version(client):
    http, _, _, _ = client
    assert http.get("/api/landing/config").json() == {"support_email": "", "notice_version": "h5-data-use-1"}


def test_confirmation_is_owned_versioned_strict_and_idempotent(client):
    http, app, _, _ = client
    body = {"notice_version": "h5-data-use-1", "granted": True}
    assert http.post("/api/landing/consents", json=body).status_code == 422
    for bad in [{**body, "granted": False}, {**body, "granted": "true"}, {**body, "notice_version": "old"}]:
        assert http.post("/api/landing/consents", json=bad, headers=HEADERS).status_code == 422
    for _ in range(2):
        assert http.post("/api/landing/consents", json=body, headers=HEADERS).status_code == 200
    with app.state.life_reports.store.connect() as db:
        rows = db.execute("SELECT * FROM landing_consents").fetchall()
    assert len(rows) == 1 and rows[0]["owner"].startswith("life:")
    assert HEADERS["X-Report-Key"] not in json.dumps(dict(rows[0]))


def test_visit_is_deduplicated_immutable_and_rejects_personal_fields(client):
    http, app, _, _ = client
    visit_id = visit(http)
    url = "/api/landing/visits"
    assert http.post(url, json={"id": visit_id, "source": "changed"}, headers=HEADERS).status_code == 200
    assert http.post(url, json={"id": visit_id}, headers=OTHER).status_code == 404
    assert http.post(url, json={"id": str(uuid4()), "birth_date": "1995-08-17"}, headers=HEADERS).status_code == 422
    assert http.post(url, json={"id": str(uuid4()), "source": "name@example.com"}, headers=HEADERS).status_code == 422
    with app.state.life_reports.store.connect() as db:
        rows = db.execute("SELECT * FROM landing_visits").fetchall()
    assert len(rows) == 1 and rows[0]["source"] == "facebook"


def test_funnel_requires_owned_report_and_submission_in_same_visit(client):
    http, app, _, _ = client
    report_id = preview(http)["id"]
    visit_id = visit(http)
    assert event(http, visit_id, report_id, "seen", OTHER).status_code == 404
    assert event(http, visit_id, report_id, "seen").status_code == 200
    with app.state.life_reports.store.connect() as db:
        assert db.execute("SELECT seen_at FROM landing_visits WHERE id=?", (visit_id,)).fetchone()[0] is None
    assert event(http, visit_id, report_id, "submitted").status_code == 200
    assert event(http, visit_id, report_id, "seen").status_code == 200
    with app.state.life_reports.store.connect() as db:
        original = dict(db.execute("SELECT * FROM landing_visits WHERE id=?", (visit_id,)).fetchone())
    assert event(http, visit_id, report_id, "seen").status_code == 200
    with app.state.life_reports.store.connect() as db:
        assert dict(db.execute("SELECT * FROM landing_visits WHERE id=?", (visit_id,)).fetchone()) == original
    assert original["visited_at"] <= original["submitted_at"] <= original["seen_at"]
    assert event(http, str(uuid4()), report_id, "submitted").status_code == 404


def test_old_visits_and_associations_are_pruned_without_removing_reports(client):
    http, app, _, _ = client
    report_id = preview(http)["id"]
    visit_id = visit(http)
    assert event(http, visit_id, report_id, "submitted").status_code == 200
    with app.state.life_reports.store.connect() as db:
        db.execute("UPDATE landing_visits SET visited_at=?", (time.time() - 31 * 86400,))
    assert event(http, visit_id, report_id, "seen").status_code == 404
    visit(http)
    with app.state.life_reports.store.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM landing_visit_reports").fetchone()[0] == 0
    assert http.get(f"/api/life-reports/{report_id}", headers=HEADERS).status_code == 200


def test_delete_enforces_ownership_and_removes_payment_reference(client):
    http, app, _, _ = client
    report_id = preview(http)["id"]
    app.state.life_reports.card_payments.create(report_id, "test-network", "zh")
    url = f"/api/life-reports/{report_id}"
    assert http.delete(url, headers=OTHER).status_code == 404
    response = http.delete(url, headers=HEADERS)
    assert response.status_code == 204 and response.content == b""
    assert http.get(url, headers=HEADERS).status_code == 404
    assert http.get("/api/life-reports", headers=HEADERS).json() == {"items": []}
    assert app.state.life_reports.card_payments.order_for(report_id) is None


@pytest.mark.parametrize("field,state", [("preview_state", "pending"), ("preview_state", "generating"), ("full_state", "generating")])
def test_active_report_cannot_be_deleted(client, field, state):
    http, app, _, _ = client
    report_id = preview(http)["id"]
    app.state.life_reports.update(report_id, **{field: state, "lease_until": time.time() + 300})
    result = http.delete(f"/api/life-reports/{report_id}", headers=HEADERS)
    assert result.status_code == 409 and result.json()["code"] == "life_report_generating"
    assert app.state.life_reports.row(report_id, "life:" + app.state.life_reports.store.hash(HEADERS["X-Report-Key"]))


def test_stale_interrupted_report_with_no_live_task_can_be_deleted(client):
    http, app, _, _ = client
    report_id = preview(http)["id"]
    app.state.life_reports.update(report_id, preview=None, preview_state="pending", lease_until=0)
    assert http.delete(f"/api/life-reports/{report_id}", headers=HEADERS).status_code == 204


def test_metrics_are_read_only_aggregates_without_report_or_device_data(client):
    http, app, _, _ = client
    visit(http)
    script = Path(__file__).resolve().parents[2] / "scripts" / "landing-metrics.py"
    result = subprocess.run([sys.executable, str(script), app.state.life_reports.store.path], capture_output=True, text=True, check=True)
    assert json.loads(result.stdout) == {"days": 30, "channels": [{"source": "facebook", "campaign": "fortune-th", "visits": 1, "submitted": 0, "seen": 0}]}


def test_native_chart_view_reuses_stored_calculation_without_exposing_worker_input(client):
    http, app, _, _ = client
    report = preview(http)
    chart = report["chart"]
    assert chart["precision"] == "exact" and len(chart["houses"]) == 12
    with app.state.life_reports.store.connect() as db:
        stored = json.loads(db.execute("SELECT chart FROM life_reports WHERE id=?", (report["id"],)).fetchone()[0])
    for planet in chart["planets"]:
        actual = stored["chart"]["points"][planet["id"]]
        assert planet["longitude"] == actual["longitudeDegrees"] and planet["house"] == actual["house"]
    assert chart["aspects"] == [] and chart["relationship_model"] == "sign-based"
    assert "profile" not in chart and "calculation_input" not in chart


def test_estimated_chart_does_not_present_time_sensitive_houses_as_exact(client):
    from backend.tests.test_life_reports import PROFILE
    http, _, _, _ = client
    response = http.post("/api/life-reports", json={"profile": {**PROFILE, "birth_time": None}, "year": 2027}, headers=HEADERS)
    assert response.status_code == 200, response.text
    chart = response.json()["chart"]
    assert chart["precision"] == "estimated" and chart["houses"] == [] and chart["aspects"] == []
    assert all(p["house"] is None and p["id"] != "ascendant" for p in chart["planets"])


def test_minimal_server_serves_font_and_image_mime_types(tmp_path, monkeypatch):
    import mimetypes
    from fastapi.testclient import TestClient
    from backend.app.config import Settings
    from backend.app.main import create_app

    static = tmp_path / "landing"
    static.mkdir()
    assets = {"initial.otf": "font/otf", "symbols.ttf": "font/ttf", "extra.woff2": "font/woff2",
              "portrait.webp": "image/webp", "loading-animation.webp": "image/webp"}
    for name in assets:
        (static / name).write_bytes(b"asset-content")
    # Reproduce the MIME database in the production slim image on every OS.
    database = mimetypes.MimeTypes()
    monkeypatch.setattr(mimetypes, "_db", database)
    monkeypatch.setattr(mimetypes, "types_map", database.types_map[True])
    for extension in (".otf", ".ttf", ".woff2", ".webp"):
        mimetypes.add_type("application/octet-stream", extension)
    settings = Settings(database_path=str(tmp_path / "font-test.db"), thai_landing_dir=str(static))
    with TestClient(create_app(settings)) as http:
        for name, expected in assets.items():
            response = http.get("/thai-landing/" + name)
            assert response.status_code == 200
            assert response.headers["content-type"] == expected
            assert response.content == b"asset-content"

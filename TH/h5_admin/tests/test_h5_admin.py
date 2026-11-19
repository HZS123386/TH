"""Administrator boundaries and business metrics use isolated, synthetic records."""
from datetime import datetime, timedelta, timezone
import json
import time
from uuid import uuid4

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.accounts import password_hash
from backend.app.config import Settings
from backend.app.landing_features import owner_for
from backend.app.main import create_app
from backend.tests import test_life_reports as life_fixtures

PROFILE, preview, finish = life_fixtures.PROFILE, life_fixtures.preview, life_fixtures.finish
client = life_fixtures.client
sunlands_settlement = life_fixtures.sunlands_settlement
sunlands_phone_response = life_fixtures.sunlands_phone_response

PASSWORD = "synthetic-admin-password"
HASH = password_hash(PASSWORD)


def login(http):
    result = http.post("/api/admin/login", headers={"X-Admin-Request": "1"},
                       json={"username": "admin-test", "password": PASSWORD})
    assert result.status_code == 200, result.text
    return {"X-CSRF-Token": result.json()["csrf"]}


def action(http, headers, report_id, name, **overrides):
    return http.post(f"/api/admin/reports/{report_id}/actions", headers=headers,
                     json={"request_id": str(uuid4()), "action": name, "note": "隔离测试", **overrides})


def seed(app):
    now = time.time()
    with app.state.store.connect() as db:
        for index in range(1, 8):
            db.execute("INSERT INTO life_reports(id,owner,fingerprint,input,chart,created,preview,preview_state,full_state,unlocked,lease_until) "
                       "VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)", (f"report-{index}", "life:" + "a" * 64, str(index),
                        json.dumps({"profile": PROFILE, "year": 2027}), "{}", now - 120, None if index == 6 else "{}",
                        "unavailable" if index == 6 else "ready", "generating" if index == 7 else "ready" if index in (1, 3, 4, 5) else "not_started",
                        int(index in (1, 3, 4, 5, 7)), now - 1 if index == 7 else 0))
        for index, (merchant, gateway, status, provider) in enumerate([
            ("sunlands:test", "https://api-prod.sunlands.com", "PAID", "verified-live"),
            ("sunlands:test", "https://api-prod.sunlands.com", "NOT_CHECKED", None),
            ("local_demo", None, None, "simulation"),
            ("sunlands:test", "https://api-test.sunlands.com", "PAID", "verified-sandbox"),
        ], 1):
            receipt = {"state": "UNKNOWN" if index == 2 else "CREATED", "gateway": gateway, "paymentStatus": status,
                       "createdAt": now - 80, "failureStage": "business" if index == 2 else "", "payDirectUrl": "https://secret.invalid/checkout"}
            if status == "PAID":
                receipt["paidAt"] = now - 40
            platform_number = f"platform-{index}"
            if provider and gateway:
                provider = gateway + "/" + platform_number
            db.execute("INSERT INTO life_card_payments(reference,report_id,network,merchant,amount,provider_order,sunlands_order,sunlands_gateway,sunlands_order_number) "
                       "VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s)", (f"{index:012}", f"report-{index}", "synthetic", merchant, 3000, provider, json.dumps(receipt), gateway, platform_number))
        for identifier, source, age in [("first", "facebook", 200), ("later", "tiktok", 100), ("blank", "", 10)]:
            db.execute("INSERT INTO landing_visits VALUES(%s,%s,%s,%s,%s,%s,%s)", (identifier, "life:" + "a" * 64, source, "campaign-test", now - age, now - 5, now - 3))
        db.execute("""
            INSERT INTO landing_visitors(owner,first_visit_date,last_visited_at)
            VALUES(%s,(to_timestamp(%s) AT TIME ZONE 'Asia/Shanghai')::date,%s)
        """, ("life:" + "a" * 64, now - 200, now - 10))
        db.execute("""
            UPDATE life_reports r SET landing_visitor_number=n.visitor_number,
                landing_source='facebook', landing_campaign='campaign-test', landing_region='TH'
            FROM landing_visitors n WHERE r.id='report-1' AND n.owner=r.owner
        """)
        db.cursor().executemany("INSERT INTO landing_visit_reports VALUES(%s,%s)", [("first", "report-1"), ("later", "report-1")])
        for report_id, validated, error in [("report-1", 0, "evidence_invalid"), ("report-1", 1, ""), ("", 0, "other_product")]:
            db.execute("INSERT INTO report_model_usage(created,report_id,phase,stage,reading,provider,model,prompt_tokens,completion_tokens,"
                       "cached_tokens,usage_received,validated,error_code) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                       (now - 10, report_id, "preview", "preview", "life-preview", "fake", "synthetic", 100, 50, 0, 1, validated, error))


@pytest.fixture
def admin(postgres_url, monkeypatch):
    app = create_app(Settings(database_url=postgres_url, app_env="production",
                              admin_username="admin-test", admin_password_hash=HASH))
    # The seeded report states are snapshots for the dashboard assertions.
    monkeypatch.setattr(app.state.life_reports, "dispatch_full_reports", lambda: None)
    seed(app)
    with TestClient(app, base_url="https://testserver") as http:
        yield http, app


def test_admin_data_requires_separate_login_and_static_page_has_no_business_data(admin):
    http, _ = admin
    for path in ("/overview", "/sources", "/records/reports", "/reports/report-1", "/visits/first"):
        assert http.get("/api/admin" + path).status_code == 401
    html = http.get("/admin/")
    assert html.status_code == 200 and "report-1" not in html.text
    assert html.headers["cache-control"] == "no-store"
    assert "frame-ancestors 'none'" in html.headers["content-security-policy"]
    assert http.get("/admin/config.py").status_code == 404


def test_visit_records_expose_observed_page_and_leave_history_unknown(admin):
    http, app = admin
    now = time.time()
    with app.state.store.connect() as db:
        db.execute("UPDATE landing_visits SET last_page='payment',last_action='open_cashier',"
                   "last_state='hidden',last_activity_at=%s,last_activity_sequence=10 WHERE id='later'", (now,))
    login(http)
    rows = {row["id"]: row for row in http.get("/api/admin/records/visits").json()["items"]}
    assert rows["later"]["last_page"] == "payment" and rows["later"]["last_action"] == "open_cashier"
    assert rows["later"]["last_state"] == "hidden" and rows["later"]["last_activity_at"] == now
    assert rows["first"]["last_page"] is None and rows["first"]["last_activity_at"] is None
    assert rows["later"]["status"] == "seen"
    assert any(item["name"] == "最后页面与操作" for item in http.get("/api/admin/sources").json()["items"])


def test_visit_detail_shows_form_progress_and_only_own_submitted_birth_fields(admin):
    http, app = admin
    visit_id, page_view_id = str(uuid4()), str(uuid4())
    owner_key = "synthetic-form-visitor-with-a-valid-key"
    headers = {"X-Report-Key": owner_key}
    now = time.time()
    events = [
        {"sequence": seq, "page_view_id": page_view_id, "page": "birth_form", "action": action,
         "state": state, "kind": kind, "occurred_at": now, "visible_ms": 0}
        for seq, action, state, kind in (
            (2, "form_progress_complete", "visible", "action"),
            (3, "form_progress_complete", "pagehide", "state"),
            (1, "form_progress_time", "visible", "action"),
        )
    ]
    assert http.post("/api/landing/visits", headers=headers, json={"id": visit_id, "events": events}).status_code == 200
    path = f"/api/admin/visits/{visit_id}"
    assert http.get(path).status_code == 401
    login(http)
    before = http.get(path).json()
    assert before["visit"]["form_progress"] == "form_progress_complete"
    assert before["visit"]["last_state"] == "pagehide" and before["visit"]["submitted_at"] is None
    assert before["submitted_profiles"] == []
    assert http.get("/api/admin/visits/first").json()["visit"]["form_progress"] is None

    profile = {**PROFILE, "birth_time": None, "birthplace": "Bangkok, TH"}
    with app.state.store.connect() as db:
        db.execute("INSERT INTO life_reports(id,owner,fingerprint,input,chart,created) VALUES(%s,%s,%s,%s,%s,%s)",
                   ("form-report", owner_for(owner_key), "form-fingerprint", json.dumps({"profile": profile, "user_question": "private"}),
                    "{}", now))
        db.execute("INSERT INTO landing_visit_reports(visit_id,report_id) VALUES(%s,'report-1')", (visit_id,))
    assert http.post(f"/api/landing/visits/{visit_id}/events", headers=headers,
                     json={"report_id": "form-report", "event": "submitted"}).json()["recorded"] is True
    detail = http.get(path)
    assert detail.headers["cache-control"] == "no-store" and detail.json()["visit"]["submitted_at"] is not None
    assert detail.json()["submitted_profiles"] == [{
        "report_id": "form-report", "birth_date": profile["birth_date"], "birth_time": None,
        "birth_time_unknown": True, "birthplace": "Bangkok, TH",
    }]
    row = next(row for row in http.get("/api/admin/records/visits").json()["items"] if row["id"] == visit_id)
    assert row["form_progress"] == "form_progress_complete" and "submitted_profiles" not in row


def test_login_cookie_csrf_logout_and_revocation(admin):
    http, app = admin
    body = {"username": "admin-test", "password": PASSWORD}
    assert http.post("/api/admin/login", json=body).status_code == 403
    assert http.post("/api/admin/login", json=body, headers={"X-Admin-Request": "1", "Origin": "https://evil.invalid"}).status_code == 403
    headers = login(http)
    cookie = http.cookies.get("fate_admin")
    assert cookie and http.get("/api/admin/session").json()["username"] == "admin-test"
    assert action(http, {}, "report-1", "note").status_code == 403
    assert action(http, {**headers, "Origin": "https://evil.invalid"}, "report-1", "note").status_code == 403
    assert action(http, headers, "report-1", "note").status_code == 200
    app.state.h5_admin.settings.admin_password_hash = password_hash("rotated-password")
    assert http.get("/api/admin/overview").status_code == 401
    app.state.h5_admin.settings.admin_password_hash = HASH
    assert http.post("/api/admin/logout", headers=headers).status_code == 200
    assert http.get("/api/admin/session").status_code == 401
    with app.state.store.connect() as db:
        assert not db.execute("SELECT 1 FROM admin_sessions").fetchone()


def test_login_failures_are_rate_limited_and_secure_cookie_is_used(admin):
    http, _ = admin
    response = http.post("/api/admin/login", json={"username": "admin-test", "password": PASSWORD}, headers={"X-Admin-Request": "1"})
    assert all(flag in response.headers["set-cookie"] for flag in ("HttpOnly", "Secure", "SameSite=strict", "Path=/api/admin"))
    for _ in range(5):
        assert http.post("/api/admin/login", json={"username": "wrong", "password": "bad"}, headers={"X-Admin-Request": "1"}).status_code == 401
    assert http.post("/api/admin/login", json={"username": "admin-test", "password": PASSWORD}, headers={"X-Admin-Request": "1"}).status_code == 429


def test_metrics_separate_real_receipts_simulation_permissions_and_failed_attempts(admin):
    http, _ = admin
    login(http)
    data = http.get("/api/admin/overview?days=30").json()
    metrics = {key: value for key, value in data["metrics"].items() if key != "next_day_return_visitors"}
    assert metrics == {"visits": 3, "visitors": 1, "submitted": 3, "seen": 3, "reports": 7,
                       "report_failures": 2, "unlocked": 5, "orders": 4, "paid": 1, "revenue": 3000,
                       "order_issues": 1, "calls": 2, "failed_calls": 1, "missing_usage": 0, "tokens": 300}
    visits = http.get("/api/admin/records/visits?days=30").json()["items"]
    visitor_number = visits[0]["visitor_number"]
    matched = http.get("/api/admin/records/visits", params={"q": visitor_number}).json()
    assert matched["total"] == 3
    assert {item["visitor_number"] for item in matched["items"]} == {visitor_number}
    reports = http.get("/api/admin/records/reports?source=facebook").json()
    assert reports["total"] == 1 and reports["items"][0]["id"] == "report-1"
    assert http.get("/api/admin/records/reports?source=tiktok").json()["total"] == 0
    issues = http.get("/api/admin/records/issues").json()
    assert issues["total"] == 4
    assert next(row for row in issues["items"] if row["category"] == "model")["attribution"] == "tagged"
    assert next(row for row in issues["items"] if row["report_id"] == "report-6")["attribution"] == "unattributed"


def test_verified_revenue_and_its_detail_use_the_verification_date(admin):
    http, app = admin
    login(http)
    now = time.time()
    with app.state.store.connect() as db:
        db.execute("""UPDATE life_card_payments SET sunlands_order=(
            sunlands_order::jsonb || jsonb_build_object('createdAt',%s::double precision,'paidAt',%s::double precision)
        )::text WHERE report_id='report-1'""", (now - 8 * 86400, now - 60))
    metrics = http.get("/api/admin/overview?days=7").json()["metrics"]
    assert (metrics["orders"], metrics["paid"], metrics["revenue"]) == (3, 1, 3000)
    assert http.get("/api/admin/records/orders?days=7").json()["total"] == 3
    paid = http.get("/api/admin/records/orders?days=7&time_basis=verified").json()
    assert paid["total"] == 1
    assert (paid["items"][0]["report_id"], paid["items"][0]["paid_at"]) == ("report-1", now - 60)
    assert paid["items"][0]["source"] == "" and paid["items"][0]["attribution"] == "unattributed"
    assert paid["items"][0]["report_source"] == "facebook"

    with app.state.store.connect() as db:
        db.execute("""UPDATE life_card_payments SET sunlands_order=(sunlands_order::jsonb - 'paidAt')::text
                   WHERE report_id='report-1'""")
    assert http.get("/api/admin/overview?days=7").json()["metrics"]["revenue"] == 0
    assert http.get("/api/admin/overview?days=0").json()["metrics"]["revenue"] == 3000
    historical = http.get("/api/admin/records/orders?days=0&time_basis=verified").json()["items"]
    assert len(historical) == 1 and historical[0]["paid_at"] is None


@pytest.mark.parametrize("same_owner", [True, False], ids=["same-browser", "foreign-visit"])
def test_sunlands_order_saves_its_owned_visit_at_creation(client, monkeypatch, sunlands_phone_response, same_owner):
    http, app, _, _ = client
    calls = []

    def gateway(request):
        assert request.url.path == "/tradeApi/trade/externalCreateOrder"
        calls.append(request.url.path)
        return httpx.Response(200, content=sunlands_phone_response)

    life_fixtures.sunlands_order_only(app, monkeypatch, gateway)
    headers = life_fixtures.HEADERS
    first = {"id": str(uuid4()), "source": "facebook", "campaign": "initial", "region": "TH"}
    later = {"id": str(uuid4()), "source": "tiktok", "campaign": "return", "region": "VN"}
    created = http.post("/api/life-reports", headers=headers,
                        json={"profile": PROFILE, "year": 2027, "landing_visit": first})
    assert created.status_code == 200 and created.json()["preview_state"] == "ready"
    report_id = created.json()["id"]
    visitor = headers if same_owner else {**headers, "X-Report-Key": "z" * 48}
    assert http.post("/api/landing/visits", headers=visitor, json=later).status_code == 200
    payment_path = f"/api/life-reports/{report_id}/payment"
    contact = {"mobile": "13000000000", "nationCode": "86"}
    order = http.post(payment_path, headers={**headers, "X-Visit-Id": later["id"]}, json=contact)
    assert order.status_code == 200 and order.json()["amount"] == 1000
    repeat = http.post(payment_path, headers={**headers, "X-Visit-Id": first["id"]}, json=contact)
    assert repeat.json() == order.json()
    assert len(calls) == 1
    with app.state.store.connect() as db:
        db.execute("DELETE FROM landing_visits WHERE id=%s", (later["id"],))
    shown = app.state.h5_admin.detail(report_id)["payment"][0]
    assert shown["report_source"] == "facebook"
    if same_owner:
        assert (shown["landing_visit_id"], shown["source"], shown["campaign"], shown["region_code"]) == (
            later["id"], "tiktok", "return", "VN")
    else:
        assert shown["landing_visit_id"] is None and shown["attribution"] == "unattributed"


def test_next_day_returns_use_beijing_visit_days_and_count_each_browser_once(postgres_url):
    app = create_app(Settings(database_url=postgres_url, app_env="production",
                              admin_username="admin-test", admin_password_hash=HASH))
    today = datetime.now(timezone(timedelta(hours=8))).replace(hour=0, minute=0, second=0, microsecond=0)
    midnight = (today - timedelta(days=2)).timestamp()
    visits = [
        ("first", "browser-a", midnight - 1),
        ("return", "browser-a", midnight + 1),
        ("repeat", "browser-a", midnight + 60),
        ("third-day", "browser-a", midnight + 86401),
        ("restored-tab", "browser-b", midnight - 2),
        ("gap-first", "browser-c", midnight - 3),
        ("gap-later", "browser-c", midnight + 86402),
        ("idle-tab", "browser-d", midnight - 4),
        ("offline-first", "browser-e", midnight - 50),
        ("offline-upload", "browser-e", midnight + 8),
    ]
    events = [
        ("restored-tab", "state", "visible", "view", midnight, midnight + 86400),
        ("idle-tab", "dwell", "visible", "view", midnight + 5, midnight + 5),
        ("idle-tab", "state", "hidden", "view", midnight + 6, midnight + 6),
        ("idle-tab", "state", "visible", "leave_page", midnight + 7, midnight + 7),
        ("offline-upload", "action", "visible", "view", midnight - 10, midnight + 8),
    ]
    with app.state.store.connect() as db:
        db.cursor().executemany("INSERT INTO landing_visits(id,owner,visited_at,source,campaign) VALUES(%s,%s,%s,'','')", visits)
        db.cursor().executemany(
            "INSERT INTO landing_visit_activity(visit_id,sequence,page_view_id,kind,state,action,occurred_at,received_at,page,visible_ms) "
            "VALUES(%s,%s,%s,%s,%s,%s,%s,%s,'birth_form',0)",
            [(visit, sequence, uuid4(), *event) for sequence, (visit, *event) in enumerate(events, 1)],
        )
    with TestClient(app, base_url="https://testserver") as http:
        login(http)
        for days, count in ((0, 2), (3, 2), (2, 1), (1, 0)):
            response = http.get("/api/admin/overview", params={"days": days})
            assert response.status_code == 200, response.text
            assert response.json()["metrics"]["next_day_return_visitors"] == count


def test_visitor_lookup_and_active_report_links_cover_the_h5_chain(admin):
    http, app = admin
    login(http)
    with app.state.store.connect() as db:
        db.execute("INSERT INTO landing_visits VALUES(%s,%s,%s,%s,%s,%s,%s)",
                   ("expired", "life:" + "a" * 64, "old-source", "old", time.time() - 31 * 86400, None, None))
        db.execute("INSERT INTO landing_visit_reports VALUES(%s,%s)", ("first", "deleted-report"))
        for report_id in ("report-1", "deleted-report"):
            db.execute("INSERT INTO admin_audit(id,report_id,created,actor,action,status,note) VALUES(%s,%s,%s,%s,%s,%s,%s)",
                       (report_id, report_id, time.time(), "admin-test", "note", "succeeded", "隔离测试"))
        visitor_number = db.execute("SELECT visitor_number FROM landing_visitors").fetchone()["visitor_number"]

    overview = http.get("/api/admin/overview?days=90").json()
    assert overview["metrics"]["visits"] == 3
    assert overview["metrics"]["visitors"] == 1
    assert {row["source"] for row in overview["channels"]} == {"", "facebook", "tiktok"}
    for kind, count in (("visits", 3), ("reports", 7), ("orders", 4), ("calls", 2), ("issues", 4), ("audit", 1)):
        page = http.get(f"/api/admin/records/{kind}", params={"q": visitor_number}).json()
        assert page["total"] == count
        assert {row["visitor_number"] for row in page["items"]} == {visitor_number}
        if kind == "visits":
            first = next(row for row in page["items"] if row["id"] == "first")
            assert first["reports"] == 1
            assert json.loads(first["report_ids"]) == ["report-1"]
        if kind == "reports":
            assert page["source_options"] == ["", "facebook"]
    audit = http.get("/api/admin/records/audit", params={"q": "deleted-report"}).json()
    assert audit["items"][0]["report_exists"] is False
    detail = http.get("/api/admin/reports/report-1").json()
    assert detail["report"]["visitor_number"] == visitor_number
    with app.state.store.connect() as db:
        db.execute("UPDATE landing_visits SET visited_at=%s", (time.time() - 31 * 86400,))
        db.execute("UPDATE landing_visitors SET last_visited_at=%s", (time.time() - 31 * 86400,))
    archived = http.get("/api/admin/records/reports", params={"q": visitor_number}).json()
    assert archived["total"] == 1
    assert archived["items"][0]["source"] == "facebook" and archived["items"][0]["region_code"] == "TH"
    assert http.get("/api/admin/reports/report-2").json()["report"]["attribution"] == "unattributed"


def test_filters_pagination_and_unknown_history_are_explicit(admin):
    http, app = admin
    login(http)
    result = http.get("/api/admin/records/reports?page_size=2&page=2").json()
    assert result["total"] == 7 and len(result["items"]) == 2
    assert http.get("/api/admin/records/reports?status=stalled").json()["items"][0]["id"] == "report-7"
    assert http.get("/api/admin/records/reports?q=';DROP%20TABLE%20life_reports;--").json()["total"] == 0
    assert http.get("/api/admin/records/secrets").status_code == 404
    assert http.get("/api/admin/records/calls?page_size=101").status_code == 422
    with app.state.store.connect() as db:
        db.execute("UPDATE report_model_usage SET error_code='' WHERE validated=0")
    failed = http.get("/api/admin/records/calls?status=failed").json()["items"][0]
    assert failed["code"] == "historical_unknown" and failed["duration_ms"] is None


def test_detail_is_scoped_and_receipts_do_not_expose_checkout_or_credentials(admin):
    http, app = admin
    login(http)
    app.state.h5_admin.settings.sunlands_app_secret = "SECRET-SHOULD-NOT-LEAK"
    with app.state.store.connect() as db:
        db.execute("UPDATE life_card_payments SET sunlands_order=jsonb_set(sunlands_order::jsonb,'{responseSummary}',%s::jsonb)::text "
                   "WHERE report_id='report-1'",
                   (json.dumps({"message": "SECRET-SHOULD-NOT-LEAK"}),))
    response = http.get("/api/admin/reports/report-1")
    assert response.status_code == 200
    assert len(response.json()["calls"]) == 2
    assert "SECRET-SHOULD-NOT-LEAK" not in response.text and "secret.invalid" not in response.text
    assert "owner" not in response.json()["report"]


def test_note_is_audited_idempotent_and_does_not_change_entitlements(admin):
    http, app = admin
    headers = login(http)
    identifier = str(uuid4())
    result = action(http, headers, "report-2", "note", request_id=identifier, note="核查来源 <script>doNotRun()</script>", case_status="resolved")
    assert result.status_code == 200
    assert action(http, headers, "report-2", "note", request_id=identifier).status_code == 409
    detail = http.get("/api/admin/reports/report-2").json()
    assert detail["case"]["status"] == "resolved" and detail["report"]["unlocked"] == 0
    assert len(detail["audit"]) == 1 and detail["audit"][0]["actor"] == "admin-test"
    with app.state.store.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM life_card_payments").fetchone()["count"] == 4


def test_retry_cannot_grant_free_access_even_in_development(admin):
    http, app = admin
    headers = login(http)
    app.state.life_reports.development = True
    result = action(http, headers, "report-2", "retry_report")
    assert result.status_code == 402
    detail = http.get("/api/admin/reports/report-2").json()
    assert detail["report"]["unlocked"] == 0 and detail["audit"][0]["code"] == "life_payment_required"
    assert action(http, headers, "report-1", "retry_report").status_code == 409
    assert action(http, headers, "report-5", "check_payment").status_code == 409


def test_check_uses_existing_order_and_original_confirmation_without_order_creation(admin, monkeypatch):
    http, app = admin
    headers = login(http)
    seen = []
    async def confirm(order, notification=None):
        seen.append(order["reference"])
        return False
    monkeypatch.setattr(app.state.life_reports.card_payments, "confirm_sunlands", confirm)
    result = action(http, headers, "report-2", "check_payment")
    assert result.status_code == 200 and result.json()["code"] == "payment_pending"
    assert seen == ["000000000002"]
    assert http.get("/api/admin/reports/report-2").json()["report"]["unlocked"] == 0
    with app.state.store.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM life_card_payments").fetchone()["count"] == 4


def test_admin_retry_reuses_real_preview_and_full_generation_pipeline(client):
    import asyncio

    http, app, calls, mode = client
    app.state.h5_admin.settings.admin_username = "admin-test"
    app.state.h5_admin.settings.admin_password_hash = HASH
    app.state.h5_admin.settings.app_env = "development"
    headers = login(http)
    original = preview(http)
    identifier = original["id"]
    with app.state.store.connect() as db:
        db.execute("UPDATE life_reports SET preview=NULL,preview_state='generating',preview_network='',"
                   "lease='legacy-worker',lease_until=%s WHERE id=%s", (time.time() - 1, identifier))
    retried = action(http, headers, identifier, "retry_report")
    assert retried.status_code == 200 and retried.json() == {"ok": True, "code": "queued"}

    async def wait_preview():
        async with asyncio.timeout(8):
            while True:
                with app.state.store.connect() as db:
                    row = db.execute("SELECT preview_state FROM life_reports WHERE id=%s", (identifier,)).fetchone()
                if row["preview_state"] == "ready":
                    return
                await asyncio.sleep(0.05)

    http.portal.call(wait_preview)
    detail = http.get(f"/api/admin/reports/{identifier}").json()
    assert detail["report"]["preview_state"] == "ready" and detail["report"]["unlocked"] == 0
    assert detail["audit"][0]["status"] == "succeeded" and detail["audit"][0]["code"] == "queued"
    with app.state.store.connect() as db:
        db.execute("UPDATE life_reports SET unlocked=1,full_state='unavailable' WHERE id=%s", (identifier,))
    retried = action(http, headers, identifier, "retry_report")
    assert retried.status_code == 200 and retried.json() == {"ok": True, "code": "queued"}
    finish(http, app)
    assert http.get(f"/api/admin/reports/{identifier}").json()["report"]["full_state"] == "ready"
    with app.state.store.connect() as db:
        assert db.execute("SELECT COUNT(*) FROM life_reports").fetchone()["count"] == 1
        assert db.execute("SELECT COUNT(*) FROM life_card_payments").fetchone()["count"] == 0


def test_request_failures_before_report_creation_are_categorized_without_private_inputs(admin):
    http, app = admin
    response = http.post("/api/life-reports?secret=DO-NOT-STORE", json={"phone": "13000000000", "secret": "PRIVATE-BODY"})
    assert response.status_code == 422
    login(http)
    result = http.get("/api/admin/records/issues?category=request").json()
    assert result["total"] == 1
    row = result["items"][0]
    assert row["http_status"] == 422 and row["path"] == "POST /api/life-reports" and row["report_id"] is None
    assert "PRIVATE-BODY" not in json.dumps(result) and "13000000000" not in json.dumps(result)
    with app.state.store.connect() as db:
        assert "DO-NOT-STORE" not in str(dict(db.execute("SELECT * FROM h5_request_failures").fetchone()))


def test_failure_links_to_visitor_even_when_visit_upload_arrives_later(admin):
    http, app = admin
    visit_id = str(uuid4())
    headers = {**life_fixtures.HEADERS, "X-Visit-Id": visit_id}
    assert http.post("/api/life-reports", json={}, headers=headers).status_code == 422
    assert http.post("/api/landing/visits", json={"id": visit_id, "source": "synthetic"}, headers=headers).status_code == 200
    assert http.get("/api/thai-locations?level=invalid", headers=headers).status_code >= 400
    login(http)
    detail = http.get("/api/admin/visits/" + visit_id).json()
    assert len(detail["failures"]) == 2
    for failure in detail["failures"]:
        assert failure["visitor_number"] == detail["visit"]["visitor_number"]
        assert failure["visit_id"] == visit_id and failure["source"] == "synthetic"
    foreign = {"X-Report-Key": "different-synthetic-visitor-" + "b" * 32, "X-Visit-Id": visit_id}
    assert http.get("/api/life-reports/report-1", headers=foreign).status_code == 404
    failures = http.get("/api/admin/records/issues?category=request").json()["items"]
    assert failures[0]["visit_id"] is None and failures[0]["report_id"] is None
    assert failures[0]["visitor_number"] is None
    assert headers["X-Report-Key"] not in json.dumps(failures)


def test_client_network_failure_is_linked_once_and_labeled_separately(admin):
    http, _ = admin
    visit_id = str(uuid4())
    event = {"sequence": 1, "page_view_id": str(uuid4()), "page": "birth_form", "action": "request_failed",
             "state": "visible", "occurred_at": time.time(), "visible_ms": 1200,
             "failure_path": "/api/life-reports", "failure_code": "network", "failure_method": "POST"}
    for _ in range(2):
        assert http.post("/api/landing/visits", json={"id": visit_id, "events": [event]}, headers=life_fixtures.HEADERS).status_code == 200
    login(http)
    detail = http.get("/api/admin/visits/" + visit_id).json()
    assert detail["total"] == 1 and detail["visit"]["visible_ms"] == 1200
    assert len(detail["failures"]) == 1
    assert detail["failures"][0]["code"] == "client_network" and detail["failures"][0]["http_status"] == 0
    assert detail["failures"][0]["visitor_number"] == detail["visit"]["visitor_number"]


def test_case_status_filter_preserves_business_failure_classification(admin):
    http, _ = admin
    headers = login(http)
    assert action(http, headers, "report-6", "note", case_status="resolved").status_code == 200
    data = http.get("/api/admin/records/issues?category=report&case_status=resolved").json()
    assert data["total"] == 1 and data["items"][0]["report_id"] == "report-6"
    assert data["items"][0]["status"] == "failed"


def test_oversized_h5_requests_are_logged_without_reading_payload_into_admin(admin):
    http, _ = admin
    assert http.post("/api/life-reports", content="PRIVATE-" * 10000).status_code == 413
    login(http)
    rows = http.get("/api/admin/records/issues?category=request").json()["items"]
    assert len(rows) == 1 and rows[0]["code"] == "request_too_large"
    assert rows[0]["http_status"] == 413 and "PRIVATE" not in json.dumps(rows)


def test_paid_label_with_mismatched_receipt_is_not_counted_as_revenue(admin):
    http, app = admin
    login(http)
    with app.state.store.connect() as db:
        db.execute("UPDATE life_card_payments SET provider_order='another-order' WHERE report_id='report-1'")
    metrics = http.get("/api/admin/overview").json()["metrics"]
    assert metrics["revenue"] == 0 and metrics["paid"] == 0
    assert http.get("/api/admin/reports/report-1").json()["payment"][0]["status"] == "needs_review"


def test_admin_settlement_runs_original_server_validation_and_preserves_receipts(sunlands_settlement):
    http, app, payments, report, _, state, calls, _ = sunlands_settlement
    app.state.h5_admin.settings.admin_username = "admin-test"
    app.state.h5_admin.settings.admin_password_hash = HASH
    app.state.h5_admin.settings.app_env = "development"
    headers = login(http)
    count_before = len(calls)
    result = action(http, headers, report["id"], "check_payment")
    assert result.status_code == 200 and result.json()["code"] == "payment_verified"
    assert len(calls) == count_before + 1
    receipt = json.loads(payments.order_for(report["id"])["sunlands_order"])
    assert receipt["paymentStatus"] == "PAID" and len(receipt["attempts"]) == 1
    finish(http, app)
    detail = http.get(f"/api/admin/reports/{report['id']}").json()
    assert detail["report"]["full_state"] == "ready" and detail["report"]["unlocked"] == 1
    assert detail["audit"][0]["code"] == "payment_verified"

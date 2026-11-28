"""Administrator boundaries and business metrics use isolated, synthetic records."""
from datetime import datetime, timedelta, timezone
import json
import time
from uuid import uuid4
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.accounts import password_hash
from backend.app.config import Settings
from backend.app.landing_features import owner_for
from backend.app.main import create_app
from backend.tests import test_life_reports as life_fixtures
from h5_admin import service as admin_service

PROFILE, preview, finish = life_fixtures.PROFILE, life_fixtures.preview, life_fixtures.finish
client = life_fixtures.client
sunlands_settlement = life_fixtures.sunlands_settlement
sunlands_phone_response = life_fixtures.sunlands_phone_response

PASSWORD = "synthetic-admin-password"
HASH = password_hash(PASSWORD)


def login(http, username="admin-test"):
    result = http.post("/api/admin/login", headers={"X-Admin-Request": "1"},
                       json={"username": username, "password": PASSWORD})
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
def admin(postgres_url):
    app = create_app(Settings(database_url=postgres_url, app_env="production",
                              admin_username="admin-test", admin_password_hash=HASH,
                              report_support_username="support-test", report_support_password_hash=HASH))
    with TestClient(app, base_url="https://testserver") as http:
        # Seeded snapshots exercise the admin classification of historical jobs.
        # Live queue and settlement paths use the working report fixtures below.
        http.portal.call(app.state.life_reports.close)
        seed(app)
        yield http, app


def test_admin_data_requires_separate_login_and_static_page_has_no_business_data(admin):
    http, _ = admin
    for path in ("/overview", "/visit-funnel", "/ad-funnel", "/page-diagnostics", "/sources", "/records/reports", "/reports/report-1", "/visits/first"):
        assert http.get("/api/admin" + path).status_code == 401
    html = http.get("/admin/")
    assert html.status_code == 200 and "report-1" not in html.text
    assert html.headers["cache-control"] == "no-store"
    assert "frame-ancestors 'none'" in html.headers["content-security-policy"]
    assert http.get("/admin/config.py").status_code == 404
    login(http, "support-test")
    assert http.get("/api/admin/page-diagnostics").status_code == 403


def test_visit_funnels_only_count_tagged_form_and_historical_welcome_entries(admin, monkeypatch):
    http, app = admin
    now = time.time()
    monkeypatch.setattr(admin_service, "VISIT_FUNNEL_START", datetime.fromtimestamp(now, ZoneInfo("Asia/Shanghai")) - timedelta(days=10))
    welcome = ("welcome", "view", "action", "visible")
    welcome_click = ("welcome", "click_welcome_start", "action", "visible")
    birth_form = ("birth_form", "view", "action", "visible")
    generate_click = ("birth_form", "click_generate_report", "action", "visible")
    generation_page = ("generating_preview", "view", "action", "visible")
    free_report = ("preview_report", "report_ready", "action", "visible")
    line_click = ("preview_report", "click_line", "action", "visible")
    phone = {"User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) Mobile/15E148 Instagram"}
    safari = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/18.6 Safari/605.1.15"}
    windows = {"Sec-CH-UA-Platform": '"Windows"', "Sec-CH-UA-Mobile": "?0"}
    tablet = {"Sec-CH-UA-Platform": '"Android"', "Sec-CH-UA-Mobile": "?0"}

    def visit(browser, events, *, source="meta", campaign="ad-funnel-test", device_headers=None):
        visit_id = str(uuid4())
        activity = []
        for seq, (page, action, kind, state) in enumerate(events, 1):
            if not activity or activity[-1]["page"] != page:
                page_view_id = str(uuid4())
            activity.append({"sequence": seq, "page_view_id": page_view_id, "page": page, "action": action,
                             "kind": kind, "state": state, "occurred_at": now, "visible_ms": 0})
        headers = {"X-Report-Key": browser * 32, **(device_headers or {})}
        result = http.post("/api/landing/visits", headers=headers, json={
            "id": visit_id, "source": source, "campaign": campaign, "events": activity,
        })
        assert result.status_code == 200, result.text
        return visit_id

    visit("a", [welcome, welcome_click, welcome_click, birth_form, ("birth_form", "view", "state", "visible"),
                ("history", "view", "action", "visible"), birth_form, generate_click, generate_click, generation_page,
                ("generating_preview", "view", "state", "visible"), free_report, line_click], device_headers=phone)
    visit("a", [("welcome", "view", "state", "visible"), birth_form, generate_click, generation_page, free_report,
                line_click, line_click], device_headers=phone)
    visit("b", [welcome, birth_form, ("generating_preview", "generate", "action", "visible"),
                ("preview_report", "report_ready", "action", "hidden"),
                ("preview_report", "click_line", "state", "visible"),
                ("preview_report", "open_line_contact", "action", "visible")], device_headers=safari)
    visit("c", [welcome, welcome_click, birth_form, generate_click, generation_page, free_report, line_click],
          campaign="", device_headers=windows)
    visit("d", [("welcome", "view", "action", "hidden"), birth_form, line_click])
    visit("g", [welcome, birth_form, generate_click, generation_page, free_report, line_click], source="", campaign="", device_headers=phone)
    visit("i", [birth_form, generate_click, line_click], source="", device_headers=windows)
    visit("h", [("birth_form", "view", "action", "hidden"),
                ("birth_form", "form_progress_empty", "state", "visible"), line_click, generate_click, generation_page], device_headers=tablet)
    older = visit("e", [welcome, line_click])
    expired = visit("f", [welcome, line_click])
    with app.state.store.connect() as db:
        db.cursor().executemany("UPDATE landing_visits SET visited_at=%s WHERE id=%s",
                                [(now - 8 * 86400, older), (now - 31 * 86400, expired)])

    login(http)
    path = "/api/admin/ad-funnel"
    week = {"entry_people": 4, "entry_visits": 5,
            "welcome_people": 2, "welcome_visits": 3, "welcome_click_people": 1,
            "birth_form_people": 4, "generate_click_people": 2, "line_click_people": 3}
    assert http.get(path, params={"days": 7}).json() == week
    assert http.get(path, params={"days": 0}).json() == {
        **week, "entry_people": 5, "entry_visits": 6,
        "welcome_people": 3, "welcome_visits": 4, "line_click_people": 4,
    }

    path = "/api/admin/visit-funnel"
    week = {"entry_people": 4, "entry_visits": 5,
            "welcome_people": 2, "welcome_visits": 3,
            "birth_form_people": 4, "birth_form_visits": 5, "birth_form_views": 6,
            "generate_click_people": 2, "generate_click_visits": 3, "generate_clicks": 4,
            "line_click_people": 3, "line_click_visits": 4, "line_clicks": 5,
            "report_flow": {"generation_page": {"people": 2, "visits": 3, "events": 3},
                            "free_report": {"people": 1, "visits": 2, "events": 2}, "line_after_generate_visits": 2},
            "devices": {"mobile": {"people": 2, "visits": 3, "events": 4},
                        "desktop": {"people": 1, "visits": 1, "events": 1},
                        "unknown": {"people": 1, "visits": 1, "events": 1}}}
    assert http.get(path, params={"days": 7}).json() == week
    assert http.get(path, params={"days": 0}).json() == {
        **week, "entry_people": 5, "entry_visits": 6,
        "welcome_people": 3, "welcome_visits": 4, "line_click_people": 4, "line_click_visits": 5, "line_clicks": 6,
    }

    login(http, "support-test")
    assert http.get(path).status_code == 403


def test_visit_funnel_filters_inclusive_beijing_dates_and_start_time(admin, monkeypatch):
    http, app = admin
    zone = ZoneInfo("Asia/Shanghai")
    previous_day = datetime.now(zone).date() - timedelta(days=1)
    start = datetime.combine(previous_day, datetime.min.time(), zone).timestamp()
    midnight = datetime.combine(previous_day + timedelta(days=1), datetime.min.time(), zone).timestamp()
    first_visit = datetime.combine(previous_day, datetime.min.time(), zone).replace(hour=17, minute=5)
    monkeypatch.setattr(admin_service, "VISIT_FUNNEL_START", first_visit)
    cutoff = first_visit.timestamp()
    with app.state.store.connect() as db:
        visits = [(start - 1, "desktop", "promo"), (cutoff - 1, "desktop", "promo"), (cutoff, "mobile", "promo"),
                  (midnight - 1, "mobile", "promo"), (midnight, "desktop", "promo"), (cutoff, "desktop", "")]
        for index, (stamp, device, campaign) in enumerate(visits):
            identifier = f"range-{index}"
            db.execute("INSERT INTO landing_visits(id,owner,source,campaign,visited_at,device_type) VALUES(%s,%s,'meta',%s,%s,%s)",
                       (identifier, "range-owner", campaign, stamp, device))
            db.execute("""
                INSERT INTO landing_visit_activity(visit_id,sequence,page_view_id,page,action,state,kind,occurred_at,received_at,visible_ms)
                VALUES(%s,1,%s,'birth_form','view','visible','action',%s,%s,0)
            """, (identifier, uuid4(), midnight, midnight))
    login(http)
    path = "/api/admin/visit-funnel"
    chosen = previous_day.isoformat()
    response = http.get(path, params={"start_date": chosen, "end_date": chosen})
    assert response.status_code == 200
    metrics = response.json()
    assert (metrics["birth_form_people"], metrics["birth_form_visits"], metrics["birth_form_views"]) == (1, 2, 2)
    assert metrics["devices"] == {"mobile": {"people": 1, "visits": 2, "events": 2}}
    assert http.get(path, params={"days": 0}).json()["birth_form_views"] == 3
    assert http.get(path, params={"start_date": chosen}).status_code == 422
    invalid = http.get(path, params={"start_date": (previous_day + timedelta(days=1)).isoformat(), "end_date": chosen})
    assert invalid.status_code == 422 and invalid.json()["code"] == "admin_visit_range_invalid"


def test_line_metrics_count_each_popup_and_dedupe_clicks_across_visits(admin):
    http, app = admin
    owner_key = "synthetic-line-contact-owner-key-1234"
    visit_id = str(uuid4())
    headers = {"X-Report-Key": owner_key}
    with app.state.store.connect() as db:
        db.execute("UPDATE life_reports SET owner=%s WHERE id='report-1'", (owner_for(owner_key),))

    def visit(key, identifier, actions, *, occurred_at=None):
        page_view = str(uuid4())
        event_time = time.time() if occurred_at is None else occurred_at
        body = {"id": identifier, "events": [
            {"sequence": seq, "page_view_id": page_view, "page": "preview_report", "action": action,
             "kind": kind, "state": "visible", "occurred_at": event_time, "visible_ms": 0}
            for seq, (action, kind) in enumerate(actions, 1)
        ]}
        response = http.post("/api/landing/visits", headers={"X-Report-Key": key}, json=body)
        assert response.status_code == 200, response.text
        return body

    first = visit(owner_key, visit_id, [
        ("open_line_contact", "action"), ("line_qr_shown", "action"),
        ("open_line_contact", "action"), ("line_qr_shown", "action"), ("line_qr_shown", "dwell"),
    ])
    assert http.post("/api/landing/visits", headers=headers, json=first).status_code == 200
    later = str(uuid4())
    delayed = time.time() - 9 * 86400
    visit(owner_key, later, [("open_line_contact", "action"), ("line_qr_shown", "action")], occurred_at=delayed)
    visit("synthetic-line-contact-other-browser", str(uuid4()), [("click_line", "action")], occurred_at=delayed)
    event_path = f"/api/landing/visits/{visit_id}/events"
    assert http.post(event_path, headers=headers, json={"report_id": "report-2", "event": "line_contact"}).status_code == 404
    event = {"report_id": "report-1", "event": "line_contact"}
    assert http.post(event_path, headers=headers, json=event).json()["recorded"] is True
    assert http.post(event_path, headers=headers, json=event).json()["recorded"] is True
    with app.state.store.connect() as db:
        row = db.execute("SELECT submitted_at, seen_at FROM landing_visits WHERE id=%s", (visit_id,)).fetchone()
        assert row == {"submitted_at": None, "seen_at": None}
    csrf = login(http, "support-test")
    base = "/api/admin/line-contacts"
    contacts = http.get(base, params={"delivery": "unconfirmed"}).json()
    assert [row["id"] for row in contacts["items"]] == ["report-1"]
    assert contacts["metrics"] == {"qr_popups": 3, "click_visitors": 2, "line_sent": 0}
    assert contacts["activity_by_occurrence"] == {"qr_popups": 3, "click_visitors": 2}
    last_week = http.get(base, params={"days": 7}).json()
    assert last_week["metrics"] == contacts["metrics"]
    assert last_week["activity_by_occurrence"] == {"qr_popups": 2, "click_visitors": 1}
    assert http.get(base).json()["items"] == []
    first_contact = contacts["items"][0]["line_contact_at"]
    assert http.post(f"{base}/report-1/actions", headers=csrf,
                     json={"action": "confirm"}).status_code == 200
    confirmed, = http.get(base, params={"report_id": "report-1"}).json()["items"]
    assert confirmed["line_contact_at"] == first_contact


def test_line_delivery_counts_and_paginates_by_send_date_on_both_pages(admin):
    http, app = admin
    now = time.time()
    old = now - 40 * 86400
    with app.state.store.connect() as db:
        db.execute("UPDATE life_reports SET created=%s,line_contact_at=%s WHERE id IN ('report-1','report-3','report-4','report-7')",
                   (old, old))
        db.execute("UPDATE life_reports SET line_confirmed_at=%s WHERE id IN ('report-1','report-3','report-4')", (old,))
        db.execute("UPDATE life_reports SET line_sent_at=%s WHERE id='report-1'", (now,))
        old_code = db.execute("UPDATE life_reports SET line_sent_at=%s WHERE id='report-3' RETURNING claim_code", (old,)).fetchone()["claim_code"]

    login(http, "support-test")
    base = "/api/admin/line-contacts"
    for days, expected in ((7, ["report-1"]), (0, ["report-1", "report-3"])):
        data = http.get(base, params={"days": days, "delivery": "sent"}).json()
        assert data["metrics"]["line_sent"] == data["total"] == len(expected)
        assert [row["id"] for row in data["items"]] == expected
    later_page = http.get(base, params={"days": 7, "delivery": "sent", "page": 2}).json()
    assert later_page["total"] == 1 and not later_page["items"] and not later_page["has_more"]
    assert later_page["last_page"] == 1
    pending = http.get(base, params={"days": 7, "delivery": "pending"}).json()
    assert pending["total"] == 1 and pending["items"][0]["id"] == "report-4"
    unconfirmed = http.get(base, params={"days": 7, "delivery": "unconfirmed"}).json()
    assert unconfirmed["total"] == 1 and unconfirmed["items"][0]["id"] == "report-7"
    by_code = http.get(base, params={"days": 7, "delivery": "sent", "report_id": old_code}).json()
    assert by_code["total"] == 1 and by_code["items"][0]["id"] == "report-3"

    login(http)
    recent = http.get("/api/admin/overview", params={"days": 7}).json()["metrics"]
    all_time = http.get("/api/admin/overview", params={"days": 0}).json()["metrics"]
    assert (recent["reports"], recent["line_sent"]) == (3, 1)
    assert (all_time["reports"], all_time["line_sent"]) == (7, 2)


def test_line_delivery_lists_all_26_reports_across_two_pages(postgres_url):
    app = create_app(Settings(database_url=postgres_url, report_support_username="support-test",
                              report_support_password_hash=HASH))
    now = time.time()
    with app.state.store.connect() as db:
        db.execute("""
            INSERT INTO life_reports(id,owner,fingerprint,claim_code,input,chart,created,preview,preview_state,full_state,
                                     line_contact_at,line_confirmed_at,line_sent_at)
            SELECT 'delivery-' || n,'synthetic-owner','delivery-' || n,51000 + n,'{}','{}',%s,'{}','ready','ready',%s,%s,%s - n
            FROM generate_series(1,26) AS n
        """, (now - 90, now - 60, now - 50, now))

    with TestClient(app, base_url="https://testserver") as http:
        login(http, "support-test")
        path = "/api/admin/line-contacts"
        first = http.get(path, params={"delivery": "sent", "page": 1}).json()
        second = http.get(path, params={"delivery": "sent", "page": 2}).json()
    assert first["has_more"] is True and second["has_more"] is False
    assert first["total"] == second["total"] == 26
    assert first["last_page"] == second["last_page"] == 2
    assert [row["id"] for row in first["items"]] == [f"delivery-{n}" for n in range(1, 26)]
    assert [row["id"] for row in second["items"]] == ["delivery-26"]


def test_line_report_counts_filter_first_contact_and_group_current_status(admin):
    http, app = admin
    beijing = timezone(timedelta(hours=8))
    contact_day = datetime.now(beijing) - timedelta(days=10)
    midnight = int(contact_day.replace(hour=0, minute=0, second=0, microsecond=0).timestamp())
    noon = midnight + 12 * 3600
    with app.state.store.connect() as db:
        db.cursor().executemany("UPDATE life_reports SET owner=%s WHERE id=%s", [
            (owner_for("pending-visitor"), "report-2"),
            (owner_for("sent-visitor"), "report-3"),
            (owner_for("earlier-visitor"), "report-5"),
        ])
        db.cursor().executemany(
            "UPDATE life_reports SET line_contact_at=%s, line_confirmed_at=%s, line_sent_at=%s WHERE id=%s",
            [
                (midnight, None, None, "report-1"),
                (noon - 1, noon + 60, None, "report-2"),
                (noon - 2, noon + 60, noon + 120, "report-3"),
                (noon, None, None, "report-4"),
                (midnight - 1, midnight + 60, midnight + 120, "report-5"),
                (None, midnight + 60, midnight + 120, "report-7"),
            ],
        )
        db.execute("""
            INSERT INTO life_reports(id,owner,fingerprint,input,chart,created,preview,preview_state,full_state,
                                     line_contact_at,line_confirmed_at,line_sent_at)
            SELECT 'report-repeat',owner,'repeat-click',input,chart,created,preview,preview_state,'ready',%s,%s,%s
            FROM life_reports WHERE id='report-1'
        """, (midnight + 1, noon + 60, noon + 120))
    path = "/api/admin/line-contacts"
    morning = {"contact_start": midnight, "contact_end": noon}
    assert http.get(path, params=morning).status_code == 401
    login(http, "support-test")

    result = http.get(path, params={**morning, "report_id": "report-7", "days": 7})
    assert result.status_code == 200
    assert result.json()["report_counts"] == {"total": 4, "unconfirmed": 1, "pending": 1, "sent": 2}
    assert result.json()["first_contact_visitor_counts"] == {"total": 3, "unconfirmed": 1, "pending": 1, "sent": 1}
    assert [row["id"] for row in result.json()["items"]] == ["report-7"]
    assert result.json()["total"] == 1 and result.json()["metrics"]["line_sent"] == 0
    result = http.get(path, params={"contact_start": noon, "contact_end": midnight + 86400})
    assert result.json()["report_counts"] == {"total": 1, "unconfirmed": 1, "pending": 0, "sent": 0}
    assert result.json()["first_contact_visitor_counts"] == {"total": 0, "unconfirmed": 0, "pending": 0, "sent": 0}
    assert http.get(path, params={"contact_start": midnight}).status_code == 422
    assert http.get(path, params={"contact_start": noon, "contact_end": noon}).status_code == 422


def test_support_can_deliver_full_report_without_unlocking_h5(client):
    http, app, _, _ = client
    http.base_url = httpx.URL("https://testserver")
    app.state.h5_admin.settings.report_support_username = "support-test"
    app.state.h5_admin.settings.report_support_password_hash = HASH
    app.state.life_reports.settings.h5_checkout_enabled = False
    report = preview(http)
    report_id = report["id"]
    claim_code = report["claim_code"]
    assert len(claim_code) == 5 and claim_code.isascii() and claim_code.isdigit()
    report_path = f"/api/life-reports/{report_id}"
    assert http.post(report_path + "/payment", headers=life_fixtures.HEADERS, json={}).status_code == 404
    assert http.get(report_path + "/payment", headers=life_fixtures.HEADERS).status_code == 404
    base = "/api/admin/line-contacts"
    actions = f"{base}/{report_id}/actions"
    export = f"{base}/{report_id}/report"
    assert http.get(base).status_code == 401
    assert http.post(export).status_code == 401
    assert http.post(actions, json={"action": "confirm"}).status_code == 401
    csrf = login(http, "support-test")
    assert http.get("/api/admin/session").json()["role"] == "report_support"
    for path in ("/overview", "/ad-funnel", "/sources", "/records/reports", "/reports/report-1", "/visits/first"):
        assert http.get("/api/admin" + path).status_code == 403
    assert http.get(f"/api/admin/reports/{report_id}/content", params={"edition": "preview"}).status_code == 403
    assert action(http, csrf, report_id, "note").status_code == 403
    assert http.post(export).status_code == 403
    assert http.post(export, headers=csrf).status_code == 404
    assert http.post(actions, headers=csrf, json={"action": "mark_sent"}).status_code == 409

    # An exact number from LINE is sufficient even when H5 analytics were unavailable.
    assert http.get(base, params={"delivery": "unconfirmed"}).json()["items"] == []
    item, = http.get(base, params={"report_id": claim_code}).json()["items"]
    assert item["id"] == report_id and item["line_contact_at"] is None
    assert item["claim_code"] == claim_code
    assert http.get(base, params={"report_id": report_id}).json()["items"] == [item]
    assert set(item) == {"id", "claim_code", "line_contact_at", "line_confirmed_at", "line_sent_at", "full_state"}
    assert http.post(actions, json={"action": "confirm"}).status_code == 403
    assert http.post(actions, headers=csrf, json={"action": "confirm"}).status_code == 200
    confirmed, = http.get(base, params={"report_id": claim_code}).json()["items"]
    assert confirmed["line_contact_at"] == confirmed["line_confirmed_at"]
    confirmed_day = datetime.fromtimestamp(confirmed["line_confirmed_at"], timezone(timedelta(hours=8)))
    midnight = int(confirmed_day.replace(hour=0, minute=0, second=0, microsecond=0).timestamp())
    same_day = {"contact_start": midnight, "contact_end": midnight + 86400}
    assert http.get(base, params=same_day).json()["report_counts"] == {
        "total": 1, "unconfirmed": 0, "pending": 1, "sent": 0,
    }
    assert http.post(actions, headers=csrf, json={"action": "confirm"}).status_code == 200
    assert [row["id"] for row in http.get(base).json()["items"]] == [report_id]
    assert http.post(export, headers=csrf).status_code == 404
    assert http.post(report_path + "/unlock", headers=life_fixtures.HEADERS).status_code == 403

    finish(http, app)
    full = http.post(export, headers=csrf).json()
    assert full["id"] == report_id and full["access"] == "full" and full["full_state"] == "ready"
    assert full["claim_code"] == claim_code
    assert full["chapters"] and full["plan"]
    assert http.get(base).json()["metrics"]["line_sent"] == 0
    public = http.get(report_path, headers=life_fixtures.HEADERS).json()
    assert public["access"] == "preview" and public["full_state"] == "not_started"
    assert public["chapters"] == [] and public["plan"] is None and public["progress"]["completed"] == 0
    assert not any(item["ready"] for item in public["catalog"])
    history, = http.get("/api/life-reports", headers=life_fixtures.HEADERS).json()["items"]
    assert history["access"] == "preview" and history["full_state"] == "not_started"
    assert http.post(actions, headers=csrf, json={"action": "mark_sent"}).status_code == 200
    assert http.post(actions, headers=csrf, json={"action": "mark_sent"}).status_code == 200
    delivery = http.get(base, params={"delivery": "sent"}).json()
    assert delivery["metrics"]["line_sent"] == delivery["total"] == 1
    sent, = delivery["items"]
    assert sent["id"] == report_id and sent["line_sent_at"] >= sent["line_confirmed_at"]
    assert sent["line_contact_at"] == confirmed["line_confirmed_at"] == sent["line_confirmed_at"]
    assert http.get(base, params={**same_day, "delivery": "sent"}).json()["report_counts"] == {
        "total": 1, "unconfirmed": 0, "pending": 0, "sent": 1,
    }
    assert http.get(base).json()["items"] == []
    with app.state.store.connect() as db:
        assert not db.execute("SELECT 1 FROM life_card_payments WHERE report_id=%s", (report_id,)).fetchone()
        audit = db.execute("SELECT action FROM admin_audit WHERE report_id=%s ORDER BY created", (report_id,)).fetchall()
        assert [row["action"] for row in audit] == ["line_confirm", "line_mark_sent"]


def test_support_can_trace_an_expired_app_code_to_the_users_latest_report(client):
    http, app, _, _ = client
    http.base_url = httpx.URL("https://testserver")
    app.state.h5_admin.settings.report_support_username = "support-test"
    app.state.h5_admin.settings.report_support_password_hash = HASH
    first = preview(http)
    first_issue = f"/api/life-reports/{first['id']}/app-login-code"
    lookup = "/api/admin/line-contacts/app-code-lookup"
    redeem = "/api/auth/h5-code"
    headers = life_fixtures.HEADERS
    issued = http.post(first_issue, headers=headers).json()
    assert issued["expires_in"] == 600
    body = {"code": issued["code"].lower()}
    assert http.post(lookup, json=body).status_code == 401
    csrf = login(http, "support-test")
    assert http.post(lookup, json=body).status_code == 403
    assert http.post(lookup, headers=csrf, json=body).status_code == 404
    login_response = http.post(redeem, json=body)
    assert login_response.status_code == 200
    session = login_response.json()
    assert http.post(redeem, json=body).status_code == 401
    with app.state.store.connect() as db:
        db.execute("UPDATE h5_app_login_codes SET expires=%s WHERE report_id=%s", (time.time() - 1, first["id"]))
    assert http.post(redeem, json=body).status_code == 401

    generated = http.post("/api/life-reports", headers=headers, json={"profile": PROFILE, "year": 2028})
    assert generated.status_code == 200 and generated.json()["preview_state"] == "ready"
    latest = generated.json()
    latest_issue = f"/api/life-reports/{latest['id']}/app-login-code"
    assert http.post(latest_issue, headers=headers).status_code == 200
    app_list = http.get("/api/app/h5-reports", headers={"Authorization": f"Bearer {session['token']}"})
    assert app_list.json()["items"][0]["id"] == latest["id"] != first["id"]

    response = http.post(lookup, headers=csrf, json=body)
    assert response.status_code == 200 and response.headers["cache-control"] == "no-store"
    result = response.json()
    assert result["user_id"] == session["user_id"]
    assert result["issued_claim_code"] == first["claim_code"]
    assert result["latest_report"]["id"] == latest["id"]
    assert result["latest_report"]["claim_code"] == latest["claim_code"]
    assert result["latest_report"]["preview_state"] == "ready"
    assert result["latest_report"]["full_state"] == "not_started"

    delivery = f"/api/admin/line-contacts/{latest['id']}/actions"
    assert http.post(delivery, headers=csrf, json={"action": "confirm"}).status_code == 200
    finish(http, app)
    assert http.post(lookup, headers=csrf, json=body).json()["latest_report"]["full_state"] == "ready"

    # Cross the seven-day boundary measured from issuance.
    with app.state.store.connect() as db:
        db.execute("UPDATE h5_app_login_codes SET expires=%s WHERE report_id=%s",
                   (time.time() - 7 * 86400 + 600 - 1, first["id"]))
    assert http.post(lookup, headers=csrf, json=body).status_code == 404
    with app.state.store.connect() as db:
        audit = db.execute("SELECT actor,report_id,status,note FROM admin_audit WHERE action='h5_code_lookup'").fetchall()
        assert any(row["report_id"] == latest["id"] and row["status"] == "succeeded" for row in audit)
        assert all(row["actor"] == "support-test" and issued["code"] not in row["note"] for row in audit)


def test_h5_login_code_cleanup_runs_without_issuing_any_codes(postgres_url, monkeypatch):
    monkeypatch.setattr("backend.app.main.H5_LOGIN_CODE_CLEANUP_INTERVAL", 0.05)
    app = create_app(Settings(database_url=postgres_url, app_env="development"))
    store = app.state.store
    cutoff = time.time() - 7 * 86400 + 600
    with store.connect() as db:
        db.execute("INSERT INTO h5_app_login_codes(owner,digest,expires) VALUES "
                   "('old-owner','old-digest',%s),('recent-owner','recent-digest',%s)", (cutoff, cutoff + 3600))

    def wait_for_codes(expected):
        deadline = time.monotonic() + 3
        while True:
            with store.connect() as db:
                remaining = {row["digest"] for row in db.execute("SELECT digest FROM h5_app_login_codes")}
            if remaining == expected:
                return
            assert time.monotonic() < deadline, remaining
            time.sleep(0.05)

    with TestClient(app):
        wait_for_codes({"recent-digest"})
        with store.connect() as db:
            db.execute("UPDATE h5_app_login_codes SET expires=%s", (cutoff,))
        wait_for_codes(set())


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
    assert metrics == {"visits": 3, "visitors": 1, "submitted": 3, "seen": 3, "reports": 7, "line_sent": 0,
                       "first_report_creators": 1, "report_failures": 2, "unlocked": 5, "orders": 4, "paid": 1, "revenue": 3000,
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


def test_report_creation_counts_each_visitor_at_their_first_report(admin):
    http, app = admin
    now = time.time()
    with app.state.store.connect() as db:
        db.execute("UPDATE life_reports SET created=%s WHERE id='report-1'", (now - 40 * 86400,))
        db.execute("UPDATE life_reports SET owner=%s WHERE id IN ('report-2','report-3')", (owner_for("recent-visitor"),))
        db.execute("UPDATE life_reports SET landing_source='repeat-source' WHERE id='report-3'")
        db.execute("UPDATE life_reports SET owner=%s WHERE id='report-6'", (owner_for("first-failed-report"),))
        db.execute("UPDATE life_reports SET owner=%s,created=%s WHERE id='report-7'",
                   (owner_for("earlier-visitor"), now - 20 * 86400))

    login(http)
    for days, report_total, first_ids in (
        (7, 5, {"report-2", "report-6"}),
        (30, 6, {"report-2", "report-6", "report-7"}),
        (0, 7, {"report-1", "report-2", "report-6", "report-7"}),
    ):
        response = http.get("/api/admin/overview", params={"days": days})
        assert response.status_code == 200
        metrics = response.json()["metrics"]
        assert (metrics["reports"], metrics["first_report_creators"]) == (report_total, len(first_ids))
        response = http.get("/api/admin/records/reports", params={"days": days, "report_scope": "first"})
        assert response.status_code == 200
        records = response.json()
        assert records["total"] == metrics["first_report_creators"]
        assert {row["id"] for row in records["items"]} == first_ids
        assert "repeat-source" not in records["source_options"]

    for row in records["items"]:
        detail = http.get(f"/api/admin/reports/{row['id']}")
        assert detail.status_code == 200
        assert detail.json()["report"]["id"] == row["id"]

    scope = {"days": 7, "report_scope": "first"}
    for filters in ({"q": "report-3"}, {"status": "ready"}, {"source": "repeat-source"}):
        assert http.get("/api/admin/records/reports", params={**scope, **filters}).json()["total"] == 0
    second_page = http.get("/api/admin/records/reports", params={**scope, "page_size": 1, "page": 2}).json()
    assert second_page["total"] == 2 and [row["id"] for row in second_page["items"]] == ["report-2"]


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
        db.execute("INSERT INTO landing_visit_report_removals(visit_id,report_id) VALUES(%s,%s)", ("first", "deleted-report"))
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


def test_admin_reads_saved_report_editions_without_restarting_generation(client):
    http, app, calls, _ = client
    report = preview(http)
    identifier = report["id"]
    path = f"/api/admin/reports/{identifier}"
    public_path = f"/api/life-reports/{identifier}"
    settings = app.state.h5_admin.settings
    settings.admin_username, settings.admin_password_hash, settings.app_env = "admin-test", HASH, "development"

    assert http.get(path + "/content?edition=preview", headers=life_fixtures.HEADERS).status_code == 401
    login(http)
    assert http.get(path).json()["content_editions"] == ["preview"]
    assert http.get(path + "/content?edition=full").status_code == 409
    http.post(public_path + "/unlock", json={}, headers=life_fixtures.HEADERS).raise_for_status()
    assert http.get(path + "/content?edition=full").status_code == 409
    finish(http, app)
    call_count = len(calls)

    assert http.get(path).json()["content_editions"] == ["preview", "full"]
    response = http.get(path + "/content?edition=full")
    assert response.headers["cache-control"] == "no-store"
    full = response.json()
    assert full["access"] == "full" and full["full_state"] == "ready" and full["chapters"]
    assert full == http.get(public_path, headers=life_fixtures.HEADERS).json()
    free = http.get(path + "/content?edition=preview").json()
    assert free["preview"] == full["preview"]
    assert free["access"] == "preview" and free["chapters"] == [] and free["plan"] is None
    assert len(calls) == call_count


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


def test_only_accepted_submission_removes_its_lookup_misses_from_request_issues(client, monkeypatch):
    http, app, _, _ = client
    admin = app.state.h5_admin
    http.base_url = httpx.URL("https://testserver")
    admin.settings.admin_username, admin.settings.admin_password_hash = "admin-test", HASH
    login(http)
    submission, visit = str(uuid4()), str(uuid4())
    headers = {**life_fixtures.HEADERS, "X-Visit-Id": visit}
    retry_headers = {**headers, "Idempotency-Key": submission}
    lookup = "/api/life-reports/submissions/" + submission
    issues = "/api/admin/records/issues?category=request"
    http.post("/api/landing/visits", json={"id": visit}, headers=headers).raise_for_status()

    assert http.get(lookup, headers=headers).status_code == 404
    initial = http.get(issues).json()
    assert initial["total"] == 1
    assert http.get(lookup, headers={"X-Report-Key": "another-synthetic-device-" + "b" * 32}).status_code == 404
    assert http.get("/api/life-reports/submissions/" + str(uuid4()), headers=headers).status_code == 404
    assert http.post("/api/life-reports?wait=false", json={}, headers=retry_headers).status_code == 422
    before = http.get(issues).json()
    assert before["total"] == 4

    # An original request can commit after the lookup but before its 404 is logged.
    late = []
    with monkeypatch.context() as patch:
        patch.setattr(admin, "record_failure", lambda *args: late.append(args))
        assert http.get(lookup, headers=life_fixtures.HEADERS).status_code == 404
    report = http.post("/api/life-reports?wait=false", json={"profile": PROFILE, "year": 2027}, headers=retry_headers)
    report.raise_for_status()
    assert len(late) == 1
    admin.record_failure(*late[0])
    after = http.get(issues).json()
    assert after["total"] == 3
    removed = {row["id"] for row in before["items"]} - {row["id"] for row in after["items"]}
    assert removed == {initial["items"][0]["id"]}
    assert sorted(row["http_status"] for row in after["items"]) == [404, 404, 422]
    detail = http.get("/api/admin/visits/" + visit).json()
    assert sorted(row["http_status"] for row in detail["failures"]) == [404, 422]
    diagnostics = http.get("/api/admin/page-diagnostics").json()["errors"]
    assert sorted(row["http_status"] for row in diagnostics if row["category"] == "request") == [404, 404, 422]
    with app.state.store.connect() as db:
        assert db.execute("SELECT count(*) AS n FROM h5_request_failures WHERE recovery_key IS NOT NULL AND report_id=%s",
                          (report.json()["id"],)).fetchone()["n"] == 2


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


def test_page_diagnostics_combines_page_stays_and_observed_errors(admin, monkeypatch):
    http, app = admin
    visit, view1, view2 = (str(uuid4()) for _ in range(3))
    batch = {"id": visit, "events": [
        {"sequence": seq, "page_view_id": view, "page": "birth_form", "action": action,
         "kind": kind, "visible_ms": ms, "occurred_at": time.time(), "state": "visible"}
        for seq, view, action, kind, ms in [
            (1, view1, "view", "action", 0), (2, view1, "view", "dwell", 10000),
            (3, view1, "runtime_js_type", "action", 12000), (4, view2, "view", "action", 0),
        ]
    ]}
    for _ in range(2):
        http.post("/api/landing/visits", json=batch, headers=life_fixtures.HEADERS).raise_for_status()
    def fail_read(*args):
        raise TimeoutError("synthetic private exception text")
    monkeypatch.setattr(app.state.life_reports, "get", fail_read)
    with pytest.raises(TimeoutError):
        http.get("/api/life-reports/report-1", headers={**life_fixtures.HEADERS, "X-Visit-Id": visit})
    login(http)
    result = http.get("/api/admin/page-diagnostics?days=7").json()
    assert result["pages"] == [{"page": "birth_form", "entries": 2, "visible_ms": 12000, "average_ms": 6000}]
    runtime, = (row for row in result["errors"] if row["category"] == "runtime")
    assert (runtime["path"], runtime["code"], runtime["visit_id"]) == ("birth_form", "runtime_js_type", visit)
    assert any(row["category"] == "model" and row["code"] == "evidence_invalid" for row in result["errors"])
    assert any(row["code"] == "server_TimeoutError" and row["http_status"] == 500 for row in result["errors"])
    assert "synthetic private exception text" not in str(result)
    detail = http.get("/api/admin/visits/" + visit).json()
    assert detail["pages"][0]["visible_ms"] == 12000
    assert {row["category"] for row in detail["failures"]} == {"runtime", "request"}
    with app.state.store.connect() as db:
        old = time.time() - 8 * 86400
        db.execute("UPDATE landing_visits SET visited_at=%s WHERE id=%s", (old, visit))
        db.execute("UPDATE landing_visit_activity SET received_at=%s WHERE visit_id=%s", (old, visit))
    result = http.get("/api/admin/page-diagnostics?days=7").json()
    assert result["pages"] == [] and not any(row["category"] == "runtime" for row in result["errors"])


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

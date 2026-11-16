"""Authenticated operations on the existing H5 records and services."""
import hashlib
import hmac
import json
import logging
from pathlib import Path
import re
import secrets
import time
from typing import Literal
from urllib.parse import urlsplit
from uuid import UUID

import psycopg
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.responses import FileResponse
from pydantic import Field

from backend.app.accounts import DUMMY_PASSWORD_HASH, password_matches
from backend.app.landing_features import VISIT_RETENTION_SECONDS
from backend.app.life_reports import LifeInput
from backend.app.schemas import Input

COOKIE = "fate_admin"
ASSETS = Path(__file__).resolve().parent / "web"
logger = logging.getLogger(__name__)
FAILURES = "('unavailable','unconfigured','limited')"
# Report attribution comes from the snapshot stored at creation.
BASE = f"""WITH active_visits AS (
 SELECT * FROM landing_visits
 WHERE visited_at>=EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::double precision-{VISIT_RETENTION_SECONDS}
), active_visitors AS (
 SELECT owner,visitor_number,region_code,first_visit_date FROM landing_visitors
 WHERE last_visited_at>=EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::double precision-{VISIT_RETENTION_SECONDS}
), reports AS (
 SELECT r.id,r.id report_id,r.created,r.preview_state,r.full_state,r.unlocked,r.lease_until,
 substr(r.owner,6,12) visitor,COALESCE(r.landing_visitor_number,n.visitor_number) visitor_number,
 COALESCE(r.input::jsonb #>> '{{profile,display_name}}','') name,
 COALESCE(r.input::jsonb #>> '{{profile,language}}','') language,
 COALESCE(r.input::jsonb ->> 'report_kind','life') report_kind,
 COALESCE(r.landing_source,'') source,COALESCE(r.landing_campaign,'') campaign,r.landing_region region_code,
 COALESCE(c.status,'untracked') case_status,
 CASE WHEN r.landing_source IS NULL THEN 'unattributed' WHEN r.landing_source='' THEN 'untagged' ELSE 'tagged' END attribution,
 CASE WHEN (r.preview_state='generating' OR r.full_state='generating') AND r.lease_until<EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) THEN 'stalled'
 WHEN r.preview_state IN {FAILURES} OR (r.unlocked=1 AND r.full_state IN {FAILURES}) THEN 'failed'
 WHEN r.preview_state='generating' OR r.full_state='generating' THEN 'generating'
 WHEN r.full_state='ready' THEN 'ready' WHEN r.preview_state='ready' THEN 'preview' ELSE 'pending' END status,
 CASE WHEN r.preview_state IN {FAILURES} THEN 'preview:'||r.preview_state
 WHEN r.full_state IN {FAILURES} THEN 'full:'||r.full_state
 WHEN (r.preview_state='generating' OR r.full_state='generating') AND r.lease_until<EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) THEN 'lease_expired'
 ELSE '' END code
 FROM life_reports r LEFT JOIN active_visitors n ON n.owner=r.owner LEFT JOIN admin_cases c ON c.report_id=r.id
), orders AS (
 SELECT p.reference id,p.report_id,COALESCE((p.sunlands_order::jsonb ->> 'createdAt')::double precision,r.created) created,
 r.name,r.visitor,r.visitor_number,r.source,r.campaign,r.region_code,r.attribution,r.case_status,p.amount,'THB' currency,
 p.sunlands_order_number order_number,
 CASE WHEN p.merchant='local_demo' THEN 'simulation'
 WHEN NOT starts_with(lower(p.merchant),'sunlands:') THEN 'sandbox'
 WHEN p.sunlands_gateway='https://api-prod.sunlands.com' THEN 'live'
 WHEN p.sunlands_order::jsonb ->> 'gateway'='https://api-prod.sunlands.com' THEN 'live'
 ELSE 'sandbox' END environment,
 CASE WHEN p.merchant='local_demo' THEN 'simulated'
 WHEN NOT starts_with(lower(p.merchant),'sunlands:') THEN CASE WHEN p.provider_order IS NOT NULL THEN 'sandbox_paid' ELSE 'pending' END
 WHEN p.sunlands_order::jsonb ->> 'paymentStatus'='PAID'
 AND p.provider_order=p.sunlands_gateway||'/'||p.sunlands_order_number THEN 'paid'
 WHEN p.sunlands_order::jsonb ->> 'paymentStatus'='PAID' THEN 'needs_review'
 WHEN p.sunlands_order::jsonb ->> 'paymentStatus'='CHECK_FAILED' THEN 'check_failed'
 WHEN p.sunlands_order::jsonb ->> 'state'='ACCESS_DENIED' THEN 'create_failed'
 WHEN COALESCE(p.sunlands_order::jsonb ->> 'state','')<>'CREATED' THEN 'needs_review'
 ELSE 'pending' END status,
 COALESCE(p.sunlands_order::jsonb ->> 'failureStage',p.sunlands_order::jsonb ->> 'paymentStatus','') code,
 (p.sunlands_order::jsonb ->> 'paidAt')::double precision paid_at
 FROM life_card_payments p JOIN reports r ON r.id=p.report_id
), calls AS (
 SELECT CAST(u.id AS TEXT) id,u.report_id,u.created,r.name,r.visitor_number,r.source,r.campaign,
 u.phase,u.stage,u.reading,u.provider,u.model,u.request_id,u.prompt_tokens,u.completion_tokens,
 u.cached_tokens,u.usage_received,u.duration_ms,
 CASE WHEN u.validated=1 THEN 'ready' ELSE 'failed' END status,
 CASE WHEN u.validated=0 THEN COALESCE(NULLIF(u.error_code,''),'historical_unknown') ELSE '' END code,
 r.status report_status,r.case_status,r.attribution
 FROM report_model_usage u JOIN reports r ON r.id=u.report_id
), visits AS (
 SELECT v.id,v.visited_at created,substr(v.owner,6,12) visitor,v.source,v.campaign,v.region_code entry_region,
 n.visitor_number,n.region_code,n.first_visit_date,
 v.submitted_at,v.seen_at,links.reports,links.report_ids,
 CASE WHEN v.seen_at IS NOT NULL THEN 'seen' WHEN v.submitted_at IS NOT NULL THEN 'submitted' ELSE 'visited' END status
 FROM active_visits v LEFT JOIN active_visitors n ON n.owner=v.owner
 LEFT JOIN LATERAL (
   SELECT COUNT(*) reports,COALESCE(json_agg(l.report_id ORDER BY l.report_id),'[]'::json)::text report_ids
   FROM landing_visit_reports l JOIN life_reports r ON r.id=l.report_id AND r.owner=v.owner
   WHERE l.visit_id=v.id
 ) links ON TRUE
), issues AS (
 SELECT 'report:'||id id,report_id,created,name,source,campaign,'report' category,status,code,case_status,'' path,NULL::bigint http_status,NULL::bigint duration_ms,attribution,visitor_number
 FROM reports WHERE status IN ('failed','stalled')
 UNION ALL SELECT 'order:'||id,report_id,created,name,source,campaign,'payment',status,code,case_status,'',NULL,NULL,attribution,visitor_number FROM orders WHERE status IN ('check_failed','create_failed','needs_review')
 UNION ALL SELECT 'call:'||id,report_id,created,name,source,campaign,'model','failed',code,case_status,'',NULL,duration_ms,attribution,visitor_number FROM calls WHERE status='failed'
 UNION ALL SELECT 'request:'||f.id,r.id,f.created,COALESCE(r.name,''),COALESCE(r.source,''),COALESCE(r.campaign,''),
 'request','failed',f.code,COALESCE(r.case_status,''),f.method||' '||f.path,f.http_status,f.duration_ms,COALESCE(r.attribution,'unattributed'),r.visitor_number
 FROM h5_request_failures f LEFT JOIN reports r ON r.id=f.report_id
), audit AS (
 SELECT a.id,a.report_id,a.created,a.actor,a.action,a.status,a.code,a.note,'' source,'' campaign,
 r.visitor_number,r.id IS NOT NULL report_exists
 FROM admin_audit a LEFT JOIN reports r ON r.id=a.report_id
) """

SOURCES = [
    {"name": "访问与渠道", "table": "landing_visits / landing_visitors / landing_visit_reports", "origin": "H5 首次访问埋点及提交、查看预览事件",
     "rule": "同一匿名浏览器使用一个访客编号，首次日期按北京时间。访问记录保留最近 30 天，编号在 30 天未访问后过期。每次访问保存该链接提供的渠道、活动和投放地区。"},
    {"name": "报告与权限", "table": "life_reports", "origin": "现有报告创建与生成服务",
     "rule": "按报告创建时间筛选，展示当前状态；同一浏览器的相同输入可能复用报告。已解锁不等于实收；过期生成租约标记为中断待核查。"},
    {"name": "订单与到账", "table": "life_card_payments.sunlands_order / provider_order", "origin": "官方建单回执及服务端核验结果",
     "rule": "实收仅累计正式网关、PAID 且服务端凭据与本单网关及单号一致的订单；模拟和沙箱单分开。按订单创建时间筛选，无旧时间则使用报告创建时间。未核验不视为已付或未付。"},
    {"name": "模型调用", "table": "report_model_usage", "origin": "原模型请求链的用量、校验结果和耗时",
     "rule": "仅展示关联 H5 报告的调用；失败的单次调用可能后来修复成功。历史未记录的原因和耗时显示未知。Token 来自上游返回，不估算金额；未返回用量不代表零消耗。"},
    {"name": "报告首次归因", "table": "landing_visitors → life_reports.landing_*", "origin": "创建报告时保存访客编号及该编号首次入站的渠道、活动和投放地区",
     "rule": "报告保留创建时所存的值。早期缺失的首次来源显示未归因，首次访问没有渠道标签的显示未标记。地区为链接提供的投放标签。"},
    {"name": "处理记录", "table": "admin_audit / admin_cases", "origin": "已登录管理员提交的业务操作和备注",
     "rule": "处理进度只是内部跟进状态，不修改订单支付状态或报告权限。所有操作记录管理员、时间、原因与结果。"},
    {"name": "接口失败", "table": "h5_request_failures", "origin": "现有 H5 API 请求边界中的非成功响应",
     "rule": "仅从后台启用后开始采集，保留最近 30 天且最多 20000 条。记录接口模板、HTTP 状态、错误码与耗时，不保存请求体、手机号、访问密钥、IP 或查询参数；可覆盖报告创建前的失败。"},
]


class Login(Input):
    username: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=1, max_length=256)


class Action(Input):
    request_id: UUID
    action: Literal["check_payment", "retry_report", "note"]
    note: str = Field(min_length=1, max_length=1000)
    case_status: Literal["open", "investigating", "resolved"] = "open"


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


class H5Admin:
    def __init__(self, store, settings, reports):
        self.store, self.settings, self.reports = store, settings, reports

    def record_failure(self, request, status, duration_ms):
        route = request.scope.get("route")
        fallback = "/api/life-reports/{unrouted}" if request.url.path.startswith("/api/life-reports") else "/api/landing/{unrouted}"
        path = getattr(route, "path", fallback)
        code = str(getattr(request.state, "failure_code", "http_" + str(status)))[:160]
        if not re.fullmatch(r"[A-Za-z0-9_:.-]+", code):
            code = "http_" + str(status)
        report_id = request.path_params.get("report_id", "")[:128]
        try:
            with self.store.connect() as db:
                db.execute("SET LOCAL lock_timeout = '100ms'")
                db.execute("INSERT INTO h5_request_failures(created,method,path,http_status,code,duration_ms,report_id) VALUES(%s,%s,%s,%s,%s,%s,%s)",
                           (time.time(), request.method, path, status, code, duration_ms, report_id))
                db.execute("DELETE FROM h5_request_failures WHERE created<%s", (time.time() - 30 * 86400,))
                db.execute("DELETE FROM h5_request_failures WHERE id IN (SELECT id FROM h5_request_failures ORDER BY created DESC OFFSET 20000)")
        except psycopg.Error:
            # Observability must never change the original business response.
            logger.warning("H5 request failure could not be recorded")

    @property
    def credential(self):
        return digest(self.settings.admin_username + self.settings.admin_password_hash)

    def session(self, request: Request):
        if not self.settings.admin_username or not self.settings.admin_password_hash:
            raise HTTPException(503, "admin_not_configured")
        token = request.cookies.get(COOKIE, "")
        with self.store.connect() as db:
            row = db.execute("SELECT * FROM admin_sessions WHERE hash=%s AND expires>%s AND credential=%s",
                             (digest(token), time.time(), self.credential)).fetchone()
        if not row:
            raise HTTPException(401, "admin_login_required")
        return {"username": row["actor"], "expires": row["expires"], "csrf": digest("csrf:" + token)}

    @staticmethod
    def same_origin(request):
        origin = request.headers.get("origin")
        if request.headers.get("sec-fetch-site") == "cross-site" or (origin and
                (urlsplit(origin).scheme, urlsplit(origin).netloc) != (request.url.scheme, request.url.netloc)):
            raise HTTPException(403, "admin_origin_rejected")

    def write_session(self, request: Request):
        session = self.session(request)
        self.same_origin(request)
        if not hmac.compare_digest(request.headers.get("x-csrf-token", ""), session["csrf"]):
            raise HTTPException(403, "admin_csrf_required")
        return session

    def login(self, request, response, body):
        self.same_origin(request)
        if request.headers.get("x-admin-request") != "1":
            raise HTTPException(403, "admin_origin_rejected")
        if not self.settings.admin_username or not self.settings.admin_password_hash:
            raise HTTPException(503, "admin_not_configured")
        network, now = digest(request.client.host if request.client else "unknown"), time.time()
        with self.store.connect() as db:
            db.execute("LOCK TABLE admin_login_attempts IN SHARE ROW EXCLUSIVE MODE")
            db.execute("DELETE FROM admin_login_attempts WHERE created<%s", (now - 900,))
            if db.execute("SELECT COUNT(*) AS count FROM admin_login_attempts WHERE network=%s", (network,)).fetchone()["count"] >= 5:
                raise HTTPException(429, "admin_login_limited")
            db.execute("INSERT INTO admin_login_attempts VALUES(%s,%s)", (network, now))
        match_name = hmac.compare_digest(body.username.encode(), self.settings.admin_username.encode())
        try:
            valid = password_matches(body.password, self.settings.admin_password_hash if match_name else DUMMY_PASSWORD_HASH)
        except (ValueError, TypeError):
            valid = False
        if not (valid and match_name):
            raise HTTPException(401, "admin_invalid_credentials")
        token, expires = secrets.token_urlsafe(32), now + 8 * 3600
        with self.store.connect() as db:
            db.execute("DELETE FROM admin_login_attempts WHERE network=%s", (network,))
            db.execute("DELETE FROM admin_sessions WHERE expires<%s OR hash=%s", (now, digest(request.cookies.get(COOKIE, ""))))
            db.execute("INSERT INTO admin_sessions VALUES(%s,%s,%s,%s)", (digest(token), body.username, expires, self.credential))
        response.set_cookie(COOKIE, token, max_age=8 * 3600, httponly=True, secure=self.settings.app_env == "production",
                            samesite="strict", path="/api/admin")
        return {"username": body.username, "expires": expires, "csrf": digest("csrf:" + token)}

    def rows(self, sql, params=()):
        with self.store.connect() as db:
            return [dict(row) for row in db.execute(BASE + sql, params)]

    @staticmethod
    def cutoff(days):
        return time.time() - days * 86400 if days else 0

    def overview(self, days):
        since = self.cutoff(days)
        metrics = self.rows("""SELECT COUNT(*) visits,COUNT(DISTINCT owner) visitors,
                               COUNT(submitted_at) submitted,COUNT(seen_at) seen
                               FROM active_visits WHERE visited_at>=%s""", (since,))[0]
        for name, sql in {
            "reports": "SELECT COUNT(*) value FROM reports WHERE created>=%s",
            "report_failures": "SELECT COUNT(*) value FROM reports WHERE created>=%s AND status IN ('failed','stalled')",
            "unlocked": "SELECT COUNT(*) value FROM reports WHERE created>=%s AND unlocked=1",
            "orders": "SELECT COUNT(*) value FROM orders WHERE created>=%s",
            "paid": "SELECT COUNT(*) value FROM orders WHERE created>=%s AND environment='live' AND status='paid'",
            "revenue": "SELECT COALESCE(SUM(amount),0) value FROM orders WHERE created>=%s AND environment='live' AND status='paid'",
            "order_issues": "SELECT COUNT(*) value FROM orders WHERE created>=%s AND status IN ('check_failed','create_failed','needs_review')",
            "calls": "SELECT COUNT(*) value FROM calls WHERE created>=%s",
            "failed_calls": "SELECT COUNT(*) value FROM calls WHERE created>=%s AND status='failed'",
            "missing_usage": "SELECT COUNT(*) value FROM calls WHERE created>=%s AND usage_received=0",
            "tokens": "SELECT COALESCE(SUM(prompt_tokens+completion_tokens),0) value FROM calls WHERE created>=%s",
        }.items():
            metrics[name] = self.rows(sql, (since,))[0]["value"]
        channels = self.rows("SELECT source,campaign,COUNT(*) visits,COUNT(DISTINCT owner) visitors,"
                             "COUNT(submitted_at) submitted,COUNT(seen_at) seen FROM active_visits WHERE visited_at>=%s "
                             "GROUP BY source,campaign ORDER BY visitors DESC,visits DESC,source,campaign LIMIT 20", (since,))
        trend = self.rows("SELECT to_char(to_timestamp(created) AT TIME ZONE 'Asia/Shanghai','YYYY-MM-DD') AS day,COUNT(*) reports,"
                          "COUNT(*) FILTER (WHERE status IN ('failed','stalled')) failed "
                          "FROM reports WHERE created>=%s GROUP BY day ORDER BY day", (max(since, time.time() - 30 * 86400),))
        return {"metrics": metrics, "channels": channels, "trend": trend, "generated_at": time.time(),
                "environment": self.settings.app_env, "database": self.store.database_name, "timezone": "Asia/Shanghai"}

    def records(self, kind, days, q, status, source, page, page_size, category="", case_status=""):
        columns = {
            "reports": "id,name,visitor_number,visitor,code", "orders": "id,report_id,visitor_number,name,order_number,code",
            "visits": "id,visitor,visitor_number,campaign", "calls": "id,report_id,visitor_number,request_id,code,model,reading",
            "issues": "id,report_id,visitor_number,name,code,category,path", "audit": "id,report_id,visitor_number,actor,note,action,code",
        }
        if kind not in columns:
            raise HTTPException(404, "admin_category_not_found")
        where, params = ["created>=%s"], [self.cutoff(days)]
        if category and kind == "issues":
            where.append("category=%s")
            params.append(category)
        if case_status and kind in ("reports", "orders", "calls", "issues"):
            where.append("case_status=%s")
            params.append(case_status)
        if q:
            where.append("(" + " OR ".join(f"{col} ILIKE %s" for col in columns[kind].split(",")) + ")")
            params.extend(["%" + q + "%"] * len(columns[kind].split(",")))
        if source:
            where.append("source=%s")
            params.append("" if source == "__untagged" else source)
        clause = " AND ".join(where)
        facets = self.rows(f"SELECT status,COUNT(*) count FROM {kind} WHERE {clause} GROUP BY status", params)
        if status:
            clause += " AND status=%s"
            params.append(status)
        total = self.rows(f"SELECT COUNT(*) total FROM {kind} WHERE {clause}", params)[0]["total"]
        items = self.rows(f"SELECT * FROM {kind} WHERE {clause} ORDER BY created DESC,id DESC LIMIT %s OFFSET %s",
                          [*params, page_size, (page - 1) * page_size])
        sources = self.rows(f"SELECT DISTINCT source FROM {kind} WHERE created>=%s ORDER BY source", (params[0],)) if kind != "audit" else []
        return {"items": items, "total": total, "page": page, "page_size": page_size,
                "facets": facets, "source_options": [row["source"] for row in sources]}

    def report(self, report_id):
        with self.store.connect() as db:
            row = db.execute("SELECT * FROM life_reports WHERE id=%s", (report_id,)).fetchone()
        if not row:
            raise HTTPException(404, "life_report_not_found")
        return dict(row)

    def receipt(self, raw):
        allowed = {"state", "gateway", "endpoint", "createdAt", "updatedAt", "paidAt", "paymentStatus", "orderNumber", "payNumber",
                   "itemNo", "productNo", "currency", "httpStatus", "elapsedMs", "failureStage", "errorType", "errorCode",
                   "validationErrors", "responseSummary", "responseHash", "gatewayRequestId", "attemptCount", "attemptStartedAt",
                   "status", "checkedAt", "source", "attempts", "paymentChecks", "associationConflict"}
        result = {key: value for key, value in raw.items() if key in allowed}
        for key in ("attempts", "paymentChecks"):
            if key in result:
                result[key] = [self.receipt(row) for row in result[key] if isinstance(row, dict)]
        secrets_to_hide = [self.settings.sunlands_app_secret, self.settings.payso_test_api_key, self.settings.payso_test_secret_key,
                           self.settings.roxy_api_key, *(config.key for config in self.settings.providers.values())]
        def redact(value):
            if isinstance(value, dict):
                return {key: redact(item) for key, item in value.items()}
            if isinstance(value, list):
                return [redact(item) for item in value]
            if isinstance(value, str):
                for secret in secrets_to_hide:
                    if secret:
                        value = value.replace(secret, "[redacted]")
            return value
        return redact(result)

    def detail(self, report_id):
        row = self.report(report_id)
        summaries = self.rows("SELECT * FROM reports WHERE id=%s", (report_id,))
        if not summaries:
            raise HTTPException(404, "life_report_not_found")
        with self.store.connect() as db:
            payment = db.execute("SELECT * FROM life_card_payments WHERE report_id=%s", (report_id,)).fetchone()
            case = db.execute("SELECT * FROM admin_cases WHERE report_id=%s", (report_id,)).fetchone()
        return {"report": summaries[0],
                "input": json.loads(row["input"]), "progress": json.loads(row["generation_progress"]),
                "completed_chapters": list(json.loads(row["chapters"])), "has_plan": bool(row["plan"]),
                "payment": self.rows("SELECT * FROM orders WHERE report_id=%s", (report_id,)),
                "receipt": self.receipt(json.loads(payment["sunlands_order"])) if payment else {},
                "calls": self.rows("SELECT * FROM calls WHERE report_id=%s ORDER BY created DESC LIMIT 100", (report_id,)),
                "audit": self.rows("SELECT * FROM audit WHERE report_id=%s ORDER BY created DESC LIMIT 100", (report_id,)),
                "case": dict(case) if case else {"status": "untracked", "note": ""}}

    async def action(self, report_id, body, actor):
        row = self.report(report_id)
        identifier = str(body.request_id)
        with self.store.connect() as db:
            audit = db.execute("INSERT INTO admin_audit(id,report_id,created,actor,action,status,note) "
                               "VALUES(%s,%s,%s,%s,%s,'running',%s) ON CONFLICT(id) DO NOTHING",
                               (identifier, report_id, time.time(), actor, body.action, body.note))
            if not audit.rowcount:
                raise HTTPException(409, "admin_action_duplicate")
        status, code = "failed", "admin_action_failed"
        try:
            if body.action == "note":
                with self.store.connect() as db:
                    db.execute("INSERT INTO admin_cases VALUES(%s,%s,%s,%s,%s) ON CONFLICT(report_id) DO UPDATE SET "
                               "status=excluded.status,updated=excluded.updated,actor=excluded.actor,note=excluded.note",
                               (report_id, body.case_status, time.time(), actor, body.note))
                code = body.case_status
            elif body.action == "check_payment":
                order = self.reports.card_payments.order_for(report_id)
                if not order or not order["merchant"].startswith("sunlands:"):
                    raise HTTPException(409, "admin_no_verifiable_order")
                paid = await self.reports.confirm_card_order(order, row["owner"])
                code = "payment_verified" if paid else "payment_pending"
            else:
                if row["lease_until"] > time.time():
                    raise HTTPException(409, "life_report_generating")
                if not row["preview"]:
                    await self.reports.start_preview_generation(row, LifeInput.model_validate_json(row["input"]), row["owner"], "admin:" + actor)
                else:
                    # Never call the development free-unlock path from administrator actions.
                    if not row["unlocked"]:
                        raise HTTPException(402, "life_payment_required")
                    if row["full_state"] == "ready":
                        raise HTTPException(409, "admin_report_already_ready")
                    await self.reports.start_full_generation(report_id, row["owner"], "admin:" + actor)
                current = self.report(report_id)
                code = (current["full_state"] if current["preview"] else current["preview_state"])
                if code not in ("generating", "ready"):
                    raise HTTPException(409, "admin_retry_" + code)
            status = "succeeded"
            return {"ok": True, "code": code}
        except HTTPException as error:
            code = str(error.detail)
            raise
        except Exception as error:
            code = "admin_action_" + type(error).__name__
            logger.exception("Administrator action failed: %s", body.action)
            raise HTTPException(503, "admin_action_failed") from None
        finally:
            with self.store.connect() as db:
                db.execute("UPDATE admin_audit SET status=%s,code=%s WHERE id=%s", (status, code, identifier))


def admin_router(service):
    router = APIRouter(prefix="/api/admin", tags=["H5 administration"])

    @router.post("/login")
    def login(body: Login, request: Request, response: Response):
        return service.login(request, response, body)

    @router.get("/session")
    def session(current=Depends(service.session)):
        return current

    @router.post("/logout")
    def logout(request: Request, response: Response, current=Depends(service.write_session)):
        with service.store.connect() as db:
            db.execute("DELETE FROM admin_sessions WHERE hash=%s", (digest(request.cookies.get(COOKIE, "")),))
        response.delete_cookie(COOKIE, path="/api/admin", secure=service.settings.app_env == "production", httponly=True, samesite="strict")
        return {"ok": True}

    @router.get("/overview")
    def overview(days: int = Query(30, ge=0, le=365), current=Depends(service.session)):
        return service.overview(days)

    @router.get("/sources")
    def sources(current=Depends(service.session)):
        return {"items": SOURCES}

    @router.get("/records/{kind}")
    def records(kind: str, days: int = Query(30, ge=0, le=365), q: str = Query("", max_length=100),
                status: str = Query("", max_length=40), source: str = Query("", max_length=64),
                category: str = Query("", max_length=20), case_status: str = Query("", max_length=20),
                page: int = Query(1, ge=1, le=10000), page_size: int = Query(25, ge=1, le=100), current=Depends(service.session)):
        return service.records(kind, days, q, status, source, page, page_size, category, case_status)

    @router.get("/reports/{report_id}")
    def detail(report_id: str, current=Depends(service.session)):
        return service.detail(report_id)

    @router.post("/reports/{report_id}/actions")
    async def action(report_id: str, body: Action, current=Depends(service.write_session)):
        return await service.action(report_id, body, current["username"])

    return router


def admin_page_router():
    router = APIRouter()

    @router.get("/admin", include_in_schema=False)
    @router.get("/admin/", include_in_schema=False)
    def page():
        return FileResponse(ASSETS / "index.html")

    @router.get("/admin/{asset}", include_in_schema=False)
    def asset(asset: str):
        if asset not in {"admin.js", "admin.css"}:
            raise HTTPException(404)
        return FileResponse(ASSETS / asset)

    return router

"""Authenticated operations on the existing H5 records and services."""
from datetime import date, datetime, timedelta
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
from uuid import UUID, uuid4
from zoneinfo import ZoneInfo

import psycopg
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.responses import FileResponse
from pydantic import Field

from backend.app.accounts import DUMMY_PASSWORD_HASH, password_matches
from backend.app.i18n import MESSAGES
from backend.app.landing_features import VISIT_RETENTION_SECONDS, owner_for
from backend.app.life_reports import LifeInput
from backend.app.schemas import H5AppLoginInput, Input
from backend.app.tarot_analytics import TAROT_ACTIONS, TAROT_PAGES
from backend.app.tarot_receipts import TarotReceiptLookup

COOKIE = "fate_admin"
ASSETS = Path(__file__).resolve().parent / "web"
logger = logging.getLogger(__name__)
FAILURES = "('unavailable','unconfigured','limited')"
VERIFIED_LIVE = "environment='live' AND status='paid'"
LINE_SENT_REPORTS = "preview IS NOT NULL AND line_sent_at >= %s"
LINE_PAGE_SIZE = 25
BEIJING = ZoneInfo("Asia/Shanghai")
# Report attribution comes from the snapshot stored at creation.
BASE = f"""WITH active_visits AS (
 SELECT * FROM landing_visits
 WHERE visited_at>=EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::double precision-{VISIT_RETENTION_SECONDS}
), active_visitors AS (
 SELECT owner,visitor_number,region_code,first_visit_date FROM landing_visitors
 WHERE last_visited_at>=EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::double precision-{VISIT_RETENTION_SECONDS}
), first_reports AS (
 SELECT DISTINCT ON (owner) id,created FROM life_reports ORDER BY owner,created,id
), reports AS (
 SELECT r.id,r.id report_id,r.created,r.preview_state,
 CASE WHEN r.full_state='pending' THEN 'queued' ELSE r.full_state END full_state,r.unlocked,r.lease_until,
 substr(r.owner,6,12) visitor,COALESCE(r.landing_visitor_number,n.visitor_number) visitor_number,
 COALESCE(r.input::jsonb #>> '{{profile,display_name}}','') name,
 COALESCE(r.input::jsonb #>> '{{profile,language}}','') language,
 COALESCE(r.input::jsonb ->> 'report_kind','life') report_kind,
 COALESCE(r.landing_source,'') source,COALESCE(r.landing_campaign,'') campaign,r.landing_region region_code,
 COALESCE(c.status,'untracked') case_status,
 CASE WHEN r.landing_source IS NULL THEN 'unattributed' WHEN r.landing_source='' THEN 'untagged' ELSE 'tagged' END attribution,
 CASE WHEN (r.preview_state='generating' OR r.full_state='generating') AND r.lease_until<EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) THEN 'stalled'
 WHEN r.preview_state IN {FAILURES} OR ((r.unlocked=1 OR r.line_confirmed_at IS NOT NULL) AND r.full_state IN {FAILURES}) THEN 'failed'
 WHEN r.preview_state='generating' OR r.full_state='generating' THEN 'generating'
 WHEN r.preview_state='queued' OR ((r.unlocked=1 OR r.line_confirmed_at IS NOT NULL) AND r.full_state IN ('queued','pending')) THEN 'queued'
 WHEN r.full_state='ready' THEN 'ready' WHEN r.preview_state='ready' THEN 'preview' ELSE 'pending' END status,
 CASE WHEN r.preview_state IN {FAILURES} THEN 'preview:'||r.preview_state
 WHEN r.full_state IN {FAILURES} THEN 'full:'||r.full_state
 WHEN (r.preview_state='generating' OR r.full_state='generating') AND r.lease_until<EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) THEN 'lease_expired'
 ELSE '' END code
 FROM life_reports r LEFT JOIN active_visitors n ON n.owner=r.owner LEFT JOIN admin_cases c ON c.report_id=r.id
), orders AS (
 SELECT p.reference id,p.report_id,COALESCE((p.sunlands_order::jsonb ->> 'createdAt')::double precision,r.created) created,
 r.name,r.visitor,r.visitor_number,p.landing_visit_id,
 COALESCE(p.landing_source,'') source,COALESCE(p.landing_campaign,'') campaign,p.landing_region region_code,
 CASE WHEN p.landing_source IS NULL THEN 'unattributed' WHEN p.landing_source='' THEN 'untagged' ELSE 'tagged' END attribution,
 r.source report_source,r.campaign report_campaign,r.region_code report_region_code,r.attribution report_attribution,
 r.case_status,p.amount,'THB' currency,
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
), page_stays AS NOT MATERIALIZED (
 SELECT visit_id,page_view_id,page,MAX(visible_ms) visible_ms FROM landing_visit_activity
 GROUP BY visit_id,page_view_id,page
), visits AS (
 SELECT v.id,v.visited_at created,substr(v.owner,6,12) visitor,v.source,v.campaign,v.region_code entry_region,
 n.visitor_number,n.region_code,n.first_visit_date,
 v.submitted_at,v.seen_at,links.reports,links.report_ids,form.action form_progress,
 v.last_page,v.last_action,v.last_activity_at,v.last_state,v.dropped_events,dwell.visible_ms,
 CASE WHEN v.seen_at IS NOT NULL THEN 'seen' WHEN v.submitted_at IS NOT NULL THEN 'submitted' ELSE 'visited' END status
 FROM active_visits v LEFT JOIN active_visitors n ON n.owner=v.owner
 LEFT JOIN LATERAL (
   SELECT a.action FROM landing_visit_activity a
   WHERE a.visit_id=v.id AND a.page='birth_form' AND a.kind='action' AND starts_with(a.action,'form_progress_')
   ORDER BY a.sequence DESC LIMIT 1
 ) form ON TRUE
 LEFT JOIN LATERAL (
   SELECT COUNT(*) reports,COALESCE(json_agg(l.report_id ORDER BY l.report_id),'[]'::json)::text report_ids
   FROM landing_visit_reports l JOIN life_reports r ON r.id=l.report_id AND r.owner=v.owner
   WHERE l.visit_id=v.id
 ) links ON TRUE
 LEFT JOIN LATERAL (
   SELECT SUM(t.visible_ms) visible_ms FROM page_stays t WHERE t.visit_id=v.id
 ) dwell ON TRUE
), issues AS (
 SELECT 'report:'||id id,report_id,created,name,source,campaign,'report' category,status,code,case_status,'' path,NULL::bigint http_status,NULL::bigint duration_ms,attribution,visitor_number,NULL::text visit_id
 FROM reports WHERE status IN ('failed','stalled')
 UNION ALL SELECT 'order:'||id,report_id,created,name,source,campaign,'payment',status,code,case_status,'',NULL,NULL,attribution,visitor_number,NULL FROM orders WHERE status IN ('check_failed','create_failed','needs_review')
 UNION ALL SELECT 'call:'||id,report_id,created,name,source,campaign,'model','failed',code,case_status,'',NULL,duration_ms,attribution,visitor_number,NULL FROM calls WHERE status='failed'
 UNION ALL SELECT 'request:'||f.id,r.id,f.created,COALESCE(r.name,''),COALESCE(v.source,r.source,''),COALESCE(v.campaign,r.campaign,''),
 'request','failed',f.code,COALESCE(r.case_status,''),f.method||' '||f.path,f.http_status,f.duration_ms,
 CASE WHEN v.id IS NOT NULL THEN CASE WHEN v.source='' THEN 'untagged' ELSE 'tagged' END ELSE COALESCE(r.attribution,'unattributed') END,
 COALESCE(n.visitor_number,r.visitor_number),v.id
 FROM h5_request_failures f LEFT JOIN reports r ON r.id=f.report_id
 LEFT JOIN active_visits v ON v.id=f.visit_id AND v.owner=f.owner
 LEFT JOIN active_visitors n ON n.owner=f.owner
 WHERE f.recovery_key IS NULL OR f.report_id IS NULL
 UNION ALL SELECT 'runtime:'||v.id||':'||a.sequence,NULL,a.received_at,'',v.source,v.campaign,
 'runtime','failed',a.action,'',a.page,NULL,NULL,CASE WHEN v.source='' THEN 'untagged' ELSE 'tagged' END,
 n.visitor_number,v.id
 FROM landing_visit_activity a JOIN active_visits v ON v.id=a.visit_id
 LEFT JOIN active_visitors n ON n.owner=v.owner
 WHERE a.kind='action' AND starts_with(a.action,'runtime_')
), audit AS (
 SELECT a.id,a.report_id,a.created,a.actor,a.action,a.status,a.code,a.note,'' source,'' campaign,
 r.visitor_number,r.id IS NOT NULL report_exists
 FROM admin_audit a LEFT JOIN reports r ON r.id=a.report_id
) """

SOURCES = [
    {"name": "塔罗访问统计", "table": "tarot_activity", "origin": "塔罗 H5 页面可见记录、操作事件和停留时长上报",
     "rule": "按服务器首次收到记录的时间筛选。每行人数按匿名浏览器去重，次数按每次进入或操作累计。"
             "同一次进入只累计前台可见时长，重复上报不累加。旧数据没有回填。"},
    {"name": "访问与渠道", "table": "landing_visits / landing_visitors / landing_visit_reports", "origin": "H5 资料填写页访问埋点及提交、查看预览事件",
     "rule": "进入填写页时开始上报。重新打开入口按本次链接标签记为新访问，刷新和返回恢复原访问。访客按匿名浏览器去重，首次日期按北京时间。访问记录保留最近 30 天，编号在 30 天未访问后过期。"},
    {"name": "H5 访问漏斗", "table": "landing_visits / landing_visit_activity", "origin": "欢迎页、资料填写页及报告按钮的 H5 事件",
     "rule": "包含所有来源。从欢迎页或填写页可见的访问开始，按北京时间的访问开始日期筛选，包含起止当天，最多保留 30 天。"
             "每一步的人数按匿名浏览器去重，人次按访问编号去重，次数按页面打开或按钮点击累计。"
             "进入 H5 按访问编号计次，填写页按同一次访问中的页面打开计次，生成报告和 LINE 按按钮事件计次。生成报告按钮包含表单校验未通过的点击。按钮埋点启用前的点击无法回溯。"},
    {"name": "广告转化", "table": "landing_visits / landing_visit_activity", "origin": "带来源和活动标签的 H5 访问及同一次访问的操作事件",
     "rule": "按访问开始时间筛选，最多保留最近 30 天。同一步按浏览器去重。新访问从填写页开始，历史欢迎页访问和按钮点击仍可回看。广告平台链接点击数尚未接入。"},
    {"name": "次日回访人数", "table": "landing_visits / landing_visit_activity", "origin": "新访问、打开页面或恢复前台的记录",
     "rule": "按北京时间自然日计算。同一浏览器连续两天有访问记录，第二天算回访。按回访日期筛选，范围内每个浏览器计一次。"
             "轨迹按发生时间归日，历史无轨迹使用访问记录时间。"},
    {"name": "最后页面与操作", "table": "landing_visits.last_page / last_action / last_activity_at / last_state", "origin": "H5 页面、操作及浏览器前后台/离开事件的最后一次成功上报",
     "rule": "时间为服务器收到最新事件的时间。前台表示上报时可见，不保证当前在线；切到后台不等于离开。离开事件不能区分关闭、刷新或跳转。外部收银台内部页面不可观测，支付结果以服务端核验为准。历史缺失显示未采集，隐私设置、断网或浏览器关闭可能造成漏报；不据此推断放弃或离开原因。"},
    {"name": "操作轨迹与停留", "table": "landing_visit_activity", "origin": "H5 原页面和操作埋点、可见状态变化及每 15 秒的时长检查点",
     "rule": "只累计前台可见时间，不等于阅读时间。每次进入页面按累计最大时长去重，再求和；补发不会重复计时。操作时间来自浏览器，接收时间来自服务器。保留 30 天，旧记录不回填；浏览器关闭可能缺最后一段。待发队列最多 500 条，溢出数量单独标记。"},
    {"name": "程序错误原因", "table": "landing_visit_activity / h5_request_failures / report_model_usage",
     "origin": "浏览器异常、Flutter 启动及框架错误、接口失败和模型调用失败",
     "rule": "前端按服务器收到事件的时间展示，同一次页面打开只上报同类异常的首次记录。仅上传预定义错误类别。服务端未捕获的异常只记录异常类型。历史缺少的原因无法回填。"},
    {"name": "填写进度与已提交资料", "table": "landing_visit_activity / landing_visit_reports / life_reports.input",
     "origin": "H5 表单必填校验的状态，以及服务器保存的关联报告",
     "rule": "填写进度取最近一次记录，包括未选资料、下一项需要填写的内容、已填完。表单上报只包含状态。"
             "访问轨迹详情从同一访客的关联报告读取已提交的出生资料。旧访问缺少进度时显示未采集。"},
    {"name": "报告与权限", "table": "life_reports", "origin": "现有报告创建与生成服务",
     "rule": "按报告创建时间筛选，展示当前状态。同一浏览器的相同输入可能复用报告。总览的去重人数按每位浏览器访客在现存报告中的首次创建时间统计。已解锁不等于实收，过期生成租约标记为中断待核查。"},
    {"name": "订单与到账", "table": "life_card_payments.sunlands_order / provider_order", "origin": "官方建单回执及服务端核验结果",
     "rule": "建单量按订单创建时间统计，历史缺少建单时间时使用报告创建时间。核验实收按服务端核验通过的时间统计，只计凭据与本单匹配的正式到账订单。历史缺少核验时间的已核验实收可在全部记录中查看。"},
    {"name": "建单来源", "table": "landing_visits → life_card_payments.landing_*", "origin": "建单请求关联的同一浏览器访问",
     "rule": "首次写入订单时保存本次访问编号、渠道、活动和投放地区。未取得有效访问时显示未归因。报告首次来源单独展示。"},
    {"name": "模型调用", "table": "report_model_usage", "origin": "原模型请求链的用量、校验结果和耗时",
     "rule": "仅展示关联 H5 报告的调用；失败的单次调用可能后来修复成功。历史未记录的原因和耗时显示未知。Token 来自上游返回，不估算金额；未返回用量不代表零消耗。"},
    {"name": "报告首次归因", "table": "landing_visitors → life_reports.landing_*", "origin": "创建报告时保存访客编号及该编号首次入站的渠道、活动和投放地区",
     "rule": "报告保留创建时所存的值。早期缺失的首次来源显示未归因，首次访问没有渠道标签的显示未标记。地区为链接提供的投放标签。"},
    {"name": "处理记录", "table": "admin_audit / admin_cases", "origin": "已登录管理员提交的业务操作和备注",
     "rule": "处理进度只是内部跟进状态，不修改订单支付状态或报告权限。所有操作记录管理员、时间、原因与结果。"},
    {"name": "LINE 联系与报告发放", "table": "landing_visit_activity / life_reports / admin_audit", "origin": "H5 添加好友按钮、二维码显示事件和客服确认",
     "rule": "按北京时间筛选报告的首次领取记录。系统收到领取入口操作时登记，缺记录时以客服首次确认时间补记。每份报告计一次，展示当前发放状态。"
             "总览和销售端的已登记发送量均按发送登记时间筛选。待发报告和待确认好友展示全部待办。"
             "领取入口操作按匿名浏览器去重。二维码展示和入口操作分别显示区间内收到的记录，以及其中在区间内发生的记录。发生时间取浏览器记录，最晚按服务器接收时间计算。最多保留 30 天。"},
    {"name": "接口失败", "table": "h5_request_failures", "origin": "现有 H5 API 请求边界中的非成功响应",
     "rule": "保留最近 30 天且最多 20000 条。同一设备的同一次提交被受理后，刷新恢复时产生的查询 404 从接口失败统计中排除。记录接口模板、HTTP 状态、错误码、耗时、匿名访客哈希和访问编号；按所有权核对关联。包含地点查询和报告创建前的失败；客户端网络或响应解析异常单独标注，不当作服务端 HTTP 失败。不保存请求体、手机号、访问密钥、IP 或查询参数。"},
]


class Login(Input):
    username: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=1, max_length=256)


class Action(Input):
    request_id: UUID
    action: Literal["check_payment", "retry_report", "note"]
    note: str = Field(min_length=1, max_length=1000)
    case_status: Literal["open", "investigating", "resolved"] = "open"


class LineDeliveryAction(Input):
    action: Literal["confirm", "retry", "mark_sent"]


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


class H5Admin:
    def __init__(self, store, settings, reports):
        self.store, self.settings, self.reports = store, settings, reports

    def record_failure(self, request, status, duration_ms):
        route = request.scope.get("route")
        fallback = "/api/life-reports/{unrouted}" if request.url.path.startswith("/api/life-reports") else "/api/thai-locations" if request.url.path == "/api/thai-locations" else "/api/landing/{unrouted}"
        path = getattr(route, "path", fallback)
        code = str(getattr(request.state, "failure_code", "http_" + str(status)))[:160]
        if not re.fullmatch(r"[A-Za-z0-9_:.-]+", code):
            code = "http_" + str(status)
        report_id = request.path_params.get("report_id", "")[:128]
        key = request.headers.get("X-Report-Key", "")
        key_owner = owner_for(key) if re.fullmatch(r"[A-Za-z0-9_-]{32,128}", key) else None
        try:
            visit_id = str(UUID(request.headers.get("X-Visit-Id", ""))) if key_owner else None
        except ValueError:
            visit_id = None
        owner = key_owner if visit_id else None
        try:
            with self.store.connect() as db:
                db.execute("SET LOCAL lock_timeout = '100ms'")
                if report_id and not db.execute("SELECT 1 FROM life_reports WHERE id=%s AND owner=%s", (report_id, key_owner)).fetchone():
                    report_id = ""
                recovery_key = None
                if (request.method == "GET" and path == "/api/life-reports/submissions/{submission_id}"
                        and status == 404 and code == "life_submission_not_found" and key_owner):
                    submission_id = UUID(str(request.path_params["submission_id"]))
                    recovery_key = self.reports.lock_submission(db, key_owner, submission_id)
                    receipt = db.execute("SELECT report_id FROM life_report_submissions WHERE owner=%s AND submission_id=%s",
                                         (key_owner, submission_id)).fetchone()
                    report_id = receipt["report_id"] if receipt else None
                db.execute("""INSERT INTO h5_request_failures(created,method,path,http_status,code,duration_ms,report_id,owner,visit_id,recovery_key)
                              VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                           (time.time(), request.method, path, status, code, duration_ms, report_id, owner, visit_id, recovery_key))
                db.execute("DELETE FROM h5_request_failures WHERE created<%s", (time.time() - 30 * 86400,))
                db.execute("DELETE FROM h5_request_failures WHERE id IN (SELECT id FROM h5_request_failures ORDER BY created DESC OFFSET 20000)")
        except psycopg.Error:
            # Observability must never change the original business response.
            logger.warning("H5 request failure could not be recorded")

    @property
    def accounts(self):
        settings = self.settings
        accounts = {}
        if settings.admin_username and settings.admin_password_hash:
            accounts[settings.admin_username] = ("admin", settings.admin_password_hash)
        if (settings.report_support_username and settings.report_support_password_hash
                and settings.report_support_username != settings.admin_username):
            accounts[settings.report_support_username] = ("report_support", settings.report_support_password_hash)
        return accounts

    @staticmethod
    def credential(username, role, password_hash):
        if role == "admin":
            return digest(username + password_hash)
        return digest(json.dumps([role, username, password_hash]))

    def session(self, request: Request):
        accounts = self.accounts
        if not accounts:
            raise HTTPException(503, "admin_not_configured")
        token = request.cookies.get(COOKIE, "")
        with self.store.connect() as db:
            row = db.execute("SELECT * FROM admin_sessions WHERE hash=%s AND expires>%s",
                             (digest(token), time.time())).fetchone()
        account = accounts.get(row["actor"]) if row else None
        if not account or not hmac.compare_digest(row["credential"], self.credential(row["actor"], *account)):
            raise HTTPException(401, "admin_login_required")
        return {"username": row["actor"], "role": account[0], "expires": row["expires"], "csrf": digest("csrf:" + token)}

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
        accounts = self.accounts
        if not accounts:
            raise HTTPException(503, "admin_not_configured")
        network, now = digest(request.client.host if request.client else "unknown"), time.time()
        with self.store.connect() as db:
            db.execute("LOCK TABLE admin_login_attempts IN SHARE ROW EXCLUSIVE MODE")
            db.execute("DELETE FROM admin_login_attempts WHERE created<%s", (now - 900,))
            if db.execute("SELECT COUNT(*) AS count FROM admin_login_attempts WHERE network=%s", (network,)).fetchone()["count"] >= 5:
                raise HTTPException(429, "admin_login_limited")
            db.execute("INSERT INTO admin_login_attempts VALUES(%s,%s)", (network, now))
        account = accounts.get(body.username)
        role, password_hash = account or ("", DUMMY_PASSWORD_HASH)
        try:
            valid = password_matches(body.password, password_hash)
        except (ValueError, TypeError):
            valid = False
        if not (valid and account):
            raise HTTPException(401, "admin_invalid_credentials")
        token, expires = secrets.token_urlsafe(32), now + 8 * 3600
        with self.store.connect() as db:
            db.execute("DELETE FROM admin_login_attempts WHERE network=%s", (network,))
            db.execute("DELETE FROM admin_sessions WHERE expires<%s OR hash=%s", (now, digest(request.cookies.get(COOKIE, ""))))
            db.execute("INSERT INTO admin_sessions VALUES(%s,%s,%s,%s)",
                       (digest(token), body.username, expires, self.credential(body.username, role, password_hash)))
        response.set_cookie(COOKIE, token, max_age=8 * 3600, httponly=True, secure=self.settings.app_env == "production",
                            samesite="strict", path="/api/admin")
        return {"username": body.username, "role": role, "expires": expires, "csrf": digest("csrf:" + token)}

    def rows(self, sql, params=()):
        with self.store.connect() as db:
            return [dict(row) for row in db.execute(BASE + sql, params)]

    @staticmethod
    def cutoff(days):
        return time.time() - days * 86400 if days else 0

    def page_diagnostics(self, days):
        since = max(self.cutoff(days), time.time() - VISIT_RETENTION_SECONDS)
        pages = self.rows("""
            SELECT s.page,COUNT(*) entries,SUM(s.visible_ms) visible_ms,ROUND(AVG(s.visible_ms)) average_ms
            FROM page_stays s JOIN active_visits v ON v.id=s.visit_id
            WHERE v.visited_at>=%s GROUP BY s.page ORDER BY SUM(s.visible_ms) DESC,s.page
        """, (since,))
        errors = self.rows("""
            SELECT category,code,path,http_status,created,visit_id,visitor_number,report_id
            FROM issues WHERE category IN ('runtime','request','model') AND created>=%s
            ORDER BY created DESC,id DESC LIMIT 25
        """, (since,))
        for error in errors:
            if error["category"] == "request" and error["code"] in MESSAGES:
                error["description"] = MESSAGES[error["code"]][0]
        return {"pages": pages, "errors": errors}

    def tarot_activity(self, days):
        with self.store.connect() as db:
            rows = db.execute("""
                SELECT event, COUNT(DISTINCT visitor_hash) AS people, COUNT(*) AS times,
                    SUM(visible_ms) AS total_ms, ROUND(AVG(visible_ms))::bigint AS average_ms
                FROM tarot_activity WHERE recorded_at >= to_timestamp(%s)
                GROUP BY event
            """, (self.cutoff(days),)).fetchall()
        events = {row["event"]: row for row in rows}
        return {
            "pages": [events.get(page, {"event": page, "people": 0, "times": 0,
                                       "total_ms": None, "average_ms": None}) for page in TAROT_PAGES],
            "actions": [events.get(action, {"event": action, "people": 0, "times": 0}) for action in TAROT_ACTIONS],
        }

    def visit_funnel(self, days, *, tagged_only=False, visit_range=None):
        start, end = visit_range if visit_range else (self.cutoff(days), None)
        metrics = self.rows("""
            , funnel_visits AS (
                SELECT v.id, v.owner,
                    BOOL_OR(a.page='welcome' AND a.action='view' AND a.state='visible') AS welcome,
                    BOOL_OR(a.page='welcome' AND a.kind='action' AND a.action='click_welcome_start') AS welcome_click,
                    COUNT(DISTINCT a.page_view_id) FILTER (
                        WHERE a.page='birth_form' AND a.state='visible'
                          AND (a.action='view' OR (a.kind='state' AND a.action<>'leave_page'))
                    ) AS birth_form_views,
                    COUNT(*) FILTER (
                        WHERE a.page='birth_form' AND a.kind='action' AND a.action='click_generate_report'
                    ) AS generate_clicks,
                    COUNT(*) FILTER (WHERE a.page='preview_report' AND a.kind='action' AND a.action='click_line') AS line_clicks
                FROM active_visits v JOIN landing_visit_activity a ON a.visit_id=v.id
                WHERE v.visited_at>=%s AND (%s::double precision IS NULL OR v.visited_at<%s)
                  AND (NOT %s OR (v.source<>'' AND v.campaign<>''))
                  AND a.kind IN ('action','state')
                  AND (a.action IN ('view','click_welcome_start','click_generate_report','click_line')
                       OR (a.page='birth_form' AND a.kind='state' AND a.state='visible' AND a.action<>'leave_page'))
                GROUP BY v.id,v.owner
            )
            SELECT COUNT(*) AS entry_visits, COUNT(DISTINCT owner) AS entry_people,
                COUNT(*) FILTER (WHERE welcome) AS welcome_visits,
                COUNT(DISTINCT owner) FILTER (WHERE welcome) AS welcome_people,
                COUNT(DISTINCT owner) FILTER (WHERE welcome AND welcome_click) AS welcome_click_people,
                COUNT(DISTINCT owner) FILTER (WHERE birth_form_views > 0) AS birth_form_people,
                COUNT(*) FILTER (WHERE birth_form_views > 0) AS birth_form_visits,
                COALESCE(SUM(birth_form_views), 0)::bigint AS birth_form_views,
                COUNT(DISTINCT owner) FILTER (WHERE generate_clicks > 0) AS generate_click_people,
                COUNT(*) FILTER (WHERE generate_clicks > 0) AS generate_click_visits,
                COALESCE(SUM(generate_clicks), 0)::bigint AS generate_clicks,
                COUNT(DISTINCT owner) FILTER (WHERE line_clicks > 0) AS line_click_people,
                COUNT(*) FILTER (WHERE line_clicks > 0) AS line_click_visits,
                COALESCE(SUM(line_clicks), 0)::bigint AS line_clicks
            FROM funnel_visits WHERE welcome OR birth_form_views > 0
        """, (start, end, end, tagged_only))[0]
        if tagged_only:
            del metrics["birth_form_views"], metrics["generate_clicks"], metrics["line_clicks"]
            del metrics["birth_form_visits"], metrics["generate_click_visits"], metrics["line_click_visits"]
        else:
            del metrics["welcome_click_people"]
        return metrics

    def line_contacts(self, days, report_id, delivery, page, report_range=None):
        since = self.cutoff(days)
        unconfirmed = "line_confirmed_at IS NULL"
        pending = "line_confirmed_at IS NOT NULL AND line_sent_at IS NULL"
        filters = {
            "unconfirmed": (f"preview IS NOT NULL AND line_contact_at IS NOT NULL AND {unconfirmed}",
                            "line_contact_at DESC", ()),
            "pending": (f"preview IS NOT NULL AND {pending}", "line_confirmed_at", ()),
            "sent": (LINE_SENT_REPORTS, "line_sent_at DESC", (since,)),
        }
        match, order, params = filters[delivery]
        if re.fullmatch(r"[1-9][0-9]{4}", report_id):
            match, params = "preview IS NOT NULL AND claim_code=%s", (int(report_id),)
        elif report_id:
            match, params = "preview IS NOT NULL AND id=%s", (report_id,)
        retention = time.time() - VISIT_RETENTION_SECONDS
        activity_since = max(retention, since)
        with self.store.connect() as db:
            # The count and page must see the same records while agents mark reports sent.
            db.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            total = db.execute(f"SELECT COUNT(*) AS total FROM life_reports WHERE {match}", params).fetchone()["total"]
            items = db.execute(f"""
                SELECT id, claim_code::text AS claim_code, line_contact_at, line_confirmed_at, line_sent_at, full_state
                FROM life_reports WHERE {match}
                ORDER BY {order}, id LIMIT %s OFFSET %s
            """, (*params, LINE_PAGE_SIZE, (page - 1) * LINE_PAGE_SIZE)).fetchall()
            metrics = db.execute(f"""
                SELECT COUNT(*) FILTER (WHERE a.action='line_qr_shown') AS qr_popups,
                       COUNT(DISTINCT v.owner) FILTER (WHERE a.action IN ('open_line_contact','click_line')) AS click_visitors,
                       COUNT(*) FILTER (WHERE a.action='line_qr_shown' AND a.occurred_at >= %s) AS occurred_popups,
                       COUNT(DISTINCT v.owner) FILTER (WHERE a.action IN ('open_line_contact','click_line')
                                                      AND a.occurred_at >= %s) AS occurred_visitors,
                       (SELECT COUNT(*) FROM life_reports WHERE {LINE_SENT_REPORTS}) AS line_sent
                FROM landing_visit_activity a JOIN landing_visits v ON v.id=a.visit_id
                WHERE v.visited_at >= %s AND a.received_at >= %s
                  AND a.page='preview_report' AND a.kind='action'
                  AND a.action IN ('open_line_contact','click_line','line_qr_shown')
            """, (activity_since, activity_since, since, retention, activity_since)).fetchone()
            occurred = {"qr_popups": metrics.pop("occurred_popups"), "click_visitors": metrics.pop("occurred_visitors")}
            last_page = max(1, (total + LINE_PAGE_SIZE - 1) // LINE_PAGE_SIZE)
            result = {"items": items, "total": total, "last_page": last_page, "has_more": page < last_page, "metrics": metrics}
            result["activity_by_occurrence"] = occurred
            if report_range is not None:
                count_columns = f"""
                    COUNT(*) AS total,
                    COUNT(*) FILTER (WHERE {unconfirmed}) AS unconfirmed,
                    COUNT(*) FILTER (WHERE {pending}) AS pending,
                    COUNT(*) FILTER (WHERE line_sent_at IS NOT NULL) AS sent
                """
                # A visitor with an earlier contact outside the range is not new in this range.
                for row in db.execute(f"""
                    WITH reports_in_range AS (
                        SELECT id, owner, line_contact_at, line_confirmed_at, line_sent_at
                        FROM life_reports
                        WHERE preview IS NOT NULL AND line_contact_at >= %s AND line_contact_at < %s
                    ), first_in_range AS (
                        SELECT DISTINCT ON (owner) owner, line_confirmed_at, line_sent_at
                        FROM reports_in_range
                        ORDER BY owner, line_contact_at, id
                    ), first_contacts AS (
                        SELECT visitor.line_confirmed_at, visitor.line_sent_at
                        FROM first_in_range visitor
                        WHERE NOT EXISTS (
                            SELECT 1 FROM life_reports earlier
                            WHERE earlier.owner=visitor.owner AND earlier.preview IS NOT NULL
                              AND earlier.line_contact_at < %s
                        )
                    )
                    SELECT 'report_counts' AS series, {count_columns} FROM reports_in_range
                    UNION ALL
                    SELECT 'first_contact_visitor_counts' AS series, {count_columns} FROM first_contacts
                """, (*report_range, report_range[0])):
                    series = row.pop("series")
                    result[series] = row
        return result

    def lookup_expired_h5_code(self, code, actor):
        with self.store.connect() as db:
            db.execute("SELECT pg_advisory_xact_lock(hashtextextended(%s,20261123))", (actor,))
            now = time.time()
            recent = db.execute(
                "SELECT COUNT(*) AS count FROM admin_audit WHERE action='h5_code_lookup' AND actor=%s AND created>%s",
                (actor, now - 60),
            ).fetchone()["count"]
            if recent >= 30:
                raise HTTPException(429, "too_many_requests")
            match = self.store.expired_h5_login_code(db, code, now)
            result = None
            if match:
                result = db.execute("""
                    SELECT accounts.user_id, visitors.visitor_number,
                           source.claim_code::text AS issued_claim_code, to_jsonb(latest) AS latest_report
                    FROM (VALUES (%s::text,%s::text)) AS link(owner,report_id)
                    LEFT JOIN h5_app_accounts accounts ON accounts.owner=link.owner
                    LEFT JOIN landing_visitors visitors ON visitors.owner=link.owner
                    LEFT JOIN life_reports source ON source.id=link.report_id AND source.owner=link.owner
                    LEFT JOIN LATERAL (
                        SELECT id,claim_code::text AS claim_code,created,preview_state,full_state
                        FROM life_reports WHERE owner=link.owner ORDER BY created DESC,id DESC LIMIT 1
                    ) latest ON TRUE
                """, (match["owner"], match["report_id"])).fetchone()
            latest = result["latest_report"] if result else None
            # Audit the operator and report without recording the submitted login code.
            db.execute(
                """INSERT INTO admin_audit(id,report_id,created,actor,action,status,note)
                   VALUES(%s,%s,%s,%s,'h5_code_lookup',%s,%s)""",
                (str(uuid4()), latest["id"] if latest else "", now, actor,
                 "succeeded" if match else "failed", "回查已过期的 App 登录码"),
            )
        return result

    def lookup_tarot_receipt(self, code, actor):
        with self.store.connect() as db:
            row = db.execute(
                """
                SELECT claim_code, report_id, question, topic, spread_id, language, cards, created_at
                FROM tarot_receipts WHERE claim_code=%s
                """,
                (code,),
            ).fetchone()
            db.execute(
                """INSERT INTO admin_audit(id,report_id,created,actor,action,status,note)
                   VALUES(%s,%s,%s,%s,'tarot_receipt_lookup',%s,'查阅塔罗领取登记')""",
                (str(uuid4()), code if row else "", time.time(), actor, "succeeded" if row else "failed"),
            )
        return row

    def line_contact_report(self, report_id):
        with self.store.connect() as db:
            row = db.execute("""
                SELECT * FROM life_reports WHERE id=%s AND preview IS NOT NULL
                AND line_confirmed_at IS NOT NULL AND full_state='ready'
            """, (report_id,)).fetchone()
        if not row:
            raise HTTPException(404, "admin_delivery_report_unavailable")
        return self.reports.public(row, line_delivery=True)

    async def line_delivery_action(self, report_id, action, actor):
        with self.store.connect() as db:
            row = db.execute("SELECT * FROM life_reports WHERE id=%s AND preview IS NOT NULL FOR UPDATE",
                             (report_id,)).fetchone()
            if not row:
                raise HTTPException(404, "life_report_not_found")
            confirmed = row["line_confirmed_at"] is not None
            state = row["full_state"]
            now = time.time()
            if action == "mark_sent":
                if not confirmed or state != "ready":
                    raise HTTPException(409, "admin_delivery_report_unavailable")
                if row["line_sent_at"] is not None:
                    return {"full_state": state}
                db.execute("UPDATE life_reports SET line_sent_at=%s WHERE id=%s", (now, report_id))
                note = "客服已在 LINE 发送完整报告"
            else:
                if action == "confirm":
                    if confirmed:
                        return {"full_state": state}
                    # Manual claims may arrive without an H5 contact event.
                    db.execute(
                        "UPDATE life_reports SET line_contact_at=COALESCE(line_contact_at, %s), "
                        "line_confirmed_at=%s WHERE id=%s", (now, now, report_id),
                    )
                    note = "客服按报告编号确认已添加 LINE 好友"
                else:
                    if not confirmed or row["line_sent_at"] is not None:
                        raise HTTPException(409, "admin_delivery_not_pending")
                    if state in ("queued", "pending", "generating", "ready"):
                        return {"full_state": state}
                    note = "重试生成待发送的 LINE 报告"
                state = self.reports.queue_full_generation(db, row, row["preview_network"] or row["owner"])
            db.execute("INSERT INTO admin_audit(id,report_id,created,actor,action,status,code,note) "
                       "VALUES(%s,%s,%s,%s,%s,'succeeded',%s,%s)",
                       (str(uuid4()), report_id, now, actor, "line_" + action, "queued" if state == "pending" else state, note))
        if action != "mark_sent":
            self.reports.wake_dispatcher()
        return {"full_state": state}

    def overview(self, days):
        since = self.cutoff(days)
        metrics = self.rows("""SELECT COUNT(*) visits,COUNT(DISTINCT owner) visitors,
                               COUNT(submitted_at) submitted,COUNT(seen_at) seen
                               FROM active_visits WHERE visited_at>=%s""", (since,))[0]
        # Use the original start time when the first upload of a visit is delayed.
        metrics["next_day_return_visitors"] = self.rows("""
            , observed_visits AS (
                SELECT v.owner,LEAST(v.visited_at, (
                    SELECT MIN(a.occurred_at) FROM landing_visit_activity a
                    WHERE a.visit_id=v.id AND a.kind<>'dwell'
                )) AS observed_at
                FROM active_visits v
                UNION ALL
                SELECT v.owner,LEAST(a.occurred_at,a.received_at) AS observed_at
                FROM active_visits v JOIN landing_visit_activity a ON a.visit_id=v.id
                WHERE a.state='visible' AND (
                    (a.kind='action' AND a.action IN ('view','enter_form'))
                    OR (a.kind='state' AND a.action<>'leave_page')
                )
            ), visit_days AS (
                SELECT DISTINCT owner,(to_timestamp(observed_at) AT TIME ZONE 'Asia/Shanghai')::date AS visit_day
                FROM observed_visits
                WHERE observed_at BETWEEN EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::double precision-%s
                    AND EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)::double precision
            )
            SELECT COUNT(DISTINCT returned.owner) AS value
            FROM visit_days returned JOIN visit_days prior
                ON prior.owner=returned.owner AND prior.visit_day=returned.visit_day-1
            WHERE %s=0 OR returned.visit_day>(CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Shanghai')::date-%s
        """, (VISIT_RETENTION_SECONDS, days, days))[0]["value"]
        metrics.update(self.rows(
            f"SELECT COUNT(*) paid,COALESCE(SUM(amount),0) revenue FROM orders "
            f"WHERE {VERIFIED_LIVE} AND (%s=0 OR paid_at>=%s)",
            (days, since),
        )[0])
        # The count and its detail list apply the range after finding each visitor's first report.
        metrics.update(self.rows("""
            SELECT (SELECT COUNT(*) FROM life_reports WHERE created >= %s) AS reports,
                   (SELECT COUNT(*) FROM first_reports WHERE created >= %s) AS first_report_creators
        """, (since, since))[0])
        for name, sql in {
            "line_sent": f"SELECT COUNT(*) value FROM life_reports WHERE {LINE_SENT_REPORTS}",
            "report_failures": "SELECT COUNT(*) value FROM reports WHERE created>=%s AND status IN ('failed','stalled')",
            "unlocked": "SELECT COUNT(*) value FROM reports WHERE created>=%s AND unlocked=1",
            "orders": "SELECT COUNT(*) value FROM orders WHERE created>=%s",
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

    def records(self, kind, days, q, status, source, page, page_size,
                category="", case_status="", time_basis="created", report_scope="all"):
        columns = {
            "reports": "id,name,visitor_number,visitor,code", "orders": "id,report_id,visitor_number,name,order_number,code,landing_visit_id",
            "visits": "id,visitor,visitor_number,campaign", "calls": "id,report_id,visitor_number,request_id,code,model,reading",
            "issues": "id,report_id,visitor_number,visit_id,name,code,category,path", "audit": "id,report_id,visitor_number,actor,note,action,code",
        }
        if kind not in columns:
            raise HTTPException(404, "admin_category_not_found")
        since = self.cutoff(days)
        verified = kind == "orders" and time_basis == "verified"
        time_column = "paid_at" if verified else "created"
        time_filter = f"{VERIFIED_LIVE} AND (%s=0 OR paid_at>=%s)" if verified else "created>=%s"
        if kind == "reports" and report_scope == "first":
            time_filter += " AND id IN (SELECT id FROM first_reports)"
        time_params = [days, since] if verified else [since]
        where, params = [time_filter], [*time_params]
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
        with self.store.connect() as db:
            # Keep the page and its counts on the same snapshot while reports are added or deleted.
            db.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
            facets = db.execute(BASE + f"SELECT status,COUNT(*) count FROM {kind} WHERE {clause} GROUP BY status",
                                params).fetchall()
            if status:
                clause += " AND status=%s"
                params.append(status)
            total = db.execute(BASE + f"SELECT COUNT(*) total FROM {kind} WHERE {clause}", params).fetchone()["total"]
            items = db.execute(BASE + f"SELECT * FROM {kind} WHERE {clause} "
                               f"ORDER BY {time_column} DESC NULLS LAST,id DESC LIMIT %s OFFSET %s",
                               [*params, page_size, (page - 1) * page_size]).fetchall()
            sources = db.execute(BASE + f"SELECT DISTINCT source FROM {kind} WHERE {time_filter} ORDER BY source",
                                 time_params).fetchall() if kind != "audit" else []
        return {"items": items, "total": total, "page": page, "page_size": page_size,
                "facets": facets, "source_options": [row["source"] for row in sources]}

    def visit_detail(self, visit_id, page):
        visits = self.rows("SELECT * FROM visits WHERE id=%s", (visit_id,))
        if not visits:
            raise HTTPException(404, "landing_visit_not_found")
        with self.store.connect() as db:
            events = db.execute("SELECT sequence,page,action,state,kind,occurred_at,received_at,visible_ms "
                                "FROM landing_visit_activity WHERE visit_id=%s AND kind<>'dwell' "
                                "ORDER BY sequence LIMIT 50 OFFSET %s", (visit_id, (page - 1) * 50)).fetchall()
            total = db.execute("SELECT COUNT(*) count FROM landing_visit_activity WHERE visit_id=%s AND kind<>'dwell'", (visit_id,)).fetchone()["count"]
            pages = db.execute(BASE + """SELECT page,SUM(visible_ms) visible_ms,COUNT(*) entries FROM page_stays
                WHERE visit_id=%s GROUP BY page ORDER BY page""", (visit_id,)).fetchall()
            profiles = db.execute("""
                SELECT r.id report_id,r.input::jsonb #>> '{profile,birth_date}' birth_date,
                       r.input::jsonb #>> '{profile,birth_time}' birth_time,
                       (r.input::jsonb #> '{profile,birth_time}')='null'::jsonb birth_time_unknown,
                       r.input::jsonb #>> '{profile,birthplace}' birthplace
                FROM landing_visit_reports l JOIN landing_visits v ON v.id=l.visit_id
                JOIN life_reports r ON r.id=l.report_id AND r.owner=v.owner
                WHERE v.id=%s ORDER BY r.created DESC,r.id LIMIT 50
            """, (visit_id,)).fetchall()
        return {"visit": visits[0], "events": [dict(row) for row in events], "pages": [dict(row) for row in pages],
                "total": total, "page": page, "page_size": 50,
                "submitted_profiles": [dict(row) for row in profiles],
                "failures": self.rows("SELECT * FROM issues WHERE category IN ('runtime','request') AND visit_id=%s ORDER BY created DESC,id DESC LIMIT 100", (visit_id,))}

    def report(self, report_id):
        with self.store.connect() as db:
            row = db.execute("SELECT * FROM life_reports WHERE id=%s", (report_id,)).fetchone()
        if not row:
            raise HTTPException(404, "life_report_not_found")
        return dict(row)

    @staticmethod
    def report_editions(row, chapters):
        editions = ["preview"] if row["preview"] else []
        if row["unlocked"] and row["full_state"] == "ready" and (chapters or row["plan"]):
            editions.append("full")
        return editions

    def report_content(self, report_id, edition):
        row = self.report(report_id)
        try:
            if edition not in self.report_editions(row, json.loads(row["chapters"])):
                raise HTTPException(409, "admin_report_content_unavailable")
            if edition == "preview":
                row.update(unlocked=0, chapters="{}", plan=None, full_state="not_started",
                           generation_progress="{}")
            return self.reports.public(row)
        except (KeyError, TypeError, ValueError):
            raise HTTPException(422, "admin_report_content_invalid") from None

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
        chapters = list(json.loads(row["chapters"]))
        summaries = self.rows("SELECT * FROM reports WHERE id=%s", (report_id,))
        if not summaries:
            raise HTTPException(404, "life_report_not_found")
        with self.store.connect() as db:
            payment = db.execute("SELECT * FROM life_card_payments WHERE report_id=%s", (report_id,)).fetchone()
            case = db.execute("SELECT * FROM admin_cases WHERE report_id=%s", (report_id,)).fetchone()
        return {"report": summaries[0],
                "input": json.loads(row["input"]), "progress": json.loads(row["generation_progress"]),
                "completed_chapters": chapters, "has_plan": bool(row["plan"]),
                "content_editions": self.report_editions(row, chapters),
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
                if current["preview"] and code == "pending":
                    code = "queued"
                if code not in ("queued", "generating", "ready"):
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

    def only_admin(current=Depends(service.session)):
        if current["role"] != "admin":
            raise HTTPException(403, "admin_permission_denied")

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
    def overview(days: int = Query(30, ge=0, le=365), current=Depends(only_admin)):
        return service.overview(days)

    @router.get("/visit-funnel")
    def visit_funnel(days: int = Query(30, ge=0, le=365), start_date: date | None = None,
                     end_date: date | None = None, current=Depends(only_admin)):
        if start_date is None and end_date is None:
            return service.visit_funnel(days)
        if start_date is None or end_date is None or not start_date <= end_date <= datetime.now(BEIJING).date():
            raise HTTPException(422, "admin_visit_range_invalid")
        midnight = datetime.min.time()
        start = datetime.combine(start_date, midnight, BEIJING).timestamp()
        end = datetime.combine(end_date + timedelta(days=1), midnight, BEIJING).timestamp()
        return service.visit_funnel(days, visit_range=(start, end))

    @router.get("/page-diagnostics")
    def page_diagnostics(days: int = Query(30, ge=0, le=365), current=Depends(only_admin)):
        return service.page_diagnostics(days)

    @router.get("/tarot-activity")
    def tarot_activity(days: int = Query(30, ge=0, le=365), current=Depends(only_admin)):
        return service.tarot_activity(days)

    @router.get("/ad-funnel")
    def ad_funnel(days: int = Query(30, ge=0, le=365), current=Depends(only_admin)):
        return service.visit_funnel(days, tagged_only=True)

    @router.get("/sources")
    def sources(current=Depends(only_admin)):
        return {"items": SOURCES}

    @router.get("/records/{kind}")
    def records(kind: str, days: int = Query(30, ge=0, le=365), q: str = Query("", max_length=100),
                status: str = Query("", max_length=40), source: str = Query("", max_length=64),
                category: str = Query("", max_length=20), case_status: str = Query("", max_length=20),
                time_basis: Literal["created", "verified"] = "created",
                report_scope: Literal["all", "first"] = "all",
                page: int = Query(1, ge=1, le=10000), page_size: int = Query(25, ge=1, le=100), current=Depends(only_admin)):
        return service.records(kind, days, q, status, source, page, page_size, category, case_status, time_basis, report_scope)

    @router.get("/reports/{report_id}")
    def detail(report_id: str, current=Depends(only_admin)):
        return service.detail(report_id)

    @router.get("/reports/{report_id}/content")
    def report_content(report_id: str, edition: Literal["preview", "full"], current=Depends(only_admin)):
        return service.report_content(report_id, edition)

    @router.get("/visits/{visit_id}")
    def visit_detail(visit_id: str, page: int = Query(1, ge=1, le=10000), current=Depends(only_admin)):
        return service.visit_detail(visit_id, page)

    @router.post("/reports/{report_id}/actions", dependencies=[Depends(only_admin)])
    async def action(report_id: str, body: Action, current=Depends(service.write_session)):
        return await service.action(report_id, body, current["username"])

    @router.get("/line-contacts")
    def line_contacts(days: int = Query(30, ge=0, le=365), report_id: str = Query("", max_length=128),
                      delivery: Literal["unconfirmed", "pending", "sent"] = "pending",
                      page: int = Query(1, ge=1, le=10000),
                      contact_start: int | None = Query(None, ge=0, le=253402300799),
                      contact_end: int | None = Query(None, ge=0, le=253402300799),
                      current=Depends(service.session)):
        report_range = None
        if contact_start is not None or contact_end is not None:
            if contact_start is None or contact_end is None or contact_start >= contact_end:
                raise HTTPException(422, "admin_line_range_invalid")
            report_range = (contact_start, contact_end)
        return service.line_contacts(days, report_id, delivery, page, report_range)

    @router.post("/line-contacts/{report_id}/actions")
    async def line_delivery_action(report_id: str, body: LineDeliveryAction, current=Depends(service.write_session)):
        return await service.line_delivery_action(report_id, body.action, current["username"])

    @router.post("/line-contacts/{report_id}/report")
    def line_contact_report(report_id: str, current=Depends(service.write_session)):
        return service.line_contact_report(report_id)

    @router.post("/line-contacts/app-code-lookup")
    def lookup_expired_h5_code(body: H5AppLoginInput, current=Depends(service.write_session)):
        result = service.lookup_expired_h5_code(body.code, current["username"])
        if result is None:
            raise HTTPException(404, "admin_expired_code_not_found")
        return result

    @router.post("/line-contacts/tarot-lookup")
    def lookup_tarot_receipt(body: TarotReceiptLookup, current=Depends(service.write_session)):
        result = service.lookup_tarot_receipt(body.code, current["username"])
        if result is None:
            raise HTTPException(404, "admin_tarot_receipt_not_found")
        return result

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

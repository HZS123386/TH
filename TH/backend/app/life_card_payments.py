"""Life-report checkout, Sunlands order creation, and payment verification."""
import asyncio
import base64
from decimal import Decimal, InvalidOperation
from email.utils import formatdate
import hashlib
import hmac
import json
import re
import secrets
import time
from urllib.parse import parse_qs, urlencode, urlsplit

import httpx
from fastapi import HTTPException


CARD_AMOUNT = 5000
SIMULATED_AMOUNT = 3000
CHECKOUT_URL = "https://www.thaiepay.com/epaylink/payment.aspx"
INQUIRY_URL = "https://apis.paysolutions.asia/order/orderdetailpost"
SIMULATED_MERCHANT = "local_demo"
SUNLANDS_AMOUNT = 3000
SUNLANDS_CREATE_ORDER = "/tradeApi/trade/externalCreateOrder"
SUNLANDS_QUERY_ORDER = "/tradeApi/trade/queryOrderDetailInfo"


def _platform_number(value):
    return value if isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,64}", value) else None


def _sunlands_checkout_url(details):
    value = details.get("payDirectUrl")
    if not isinstance(value, str) or any(char.isspace() or ord(char) < 32 for char in value):
        return None
    try:
        url = urlsplit(value)
        # Keep the returned link intact and only expose the official entry for this order.
        if (url.scheme in {"http", "https"} and url.netloc == "trade.sunlands.com"
                and url.path == "/trade/web/trade/payDirect.action" and not url.fragment
                and parse_qs(url.query, keep_blank_values=True).get("orderNumber") == [details.get("orderNumber")]):
            return value
    except ValueError:
        pass
    return None


class LifeCardPayments:
    def __init__(self, store, settings):
        self.store = store
        self.settings = settings
        self.order_only = settings.sunlands_order_only
        if settings.sunlands_merchant_notify_uri and not re.fullmatch(r"/[A-Za-z0-9/_-]{1,255}", settings.sunlands_merchant_notify_uri):
            raise RuntimeError("SUNLANDS_MERCHANT_NOTIFY_URI must be the registered API gateway URI")
        if self.order_only and (settings.app_env != "development" or settings.sunlands_base_url not in {
            "https://api-prod.sunlands.com", "https://api-test.sunlands.com",
        }):
            raise RuntimeError("Sunlands order-only integration requires development mode and a Sunlands gateway")
        self.merchant = settings.payso_test_merchant_id
        self.api_key = settings.payso_test_api_key
        self.secret_key = settings.payso_test_secret_key
        self.enabled = bool(self.merchant or self.api_key or self.secret_key)
        if self.enabled and (settings.app_env != "development" or
                             not re.fullmatch(r"[0-9]{8}", self.merchant) or
                             not self.api_key or not self.secret_key):
            raise RuntimeError("Payso Demo requires development mode and all PAYSO_TEST credentials")
        with store.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            db.execute("""
                CREATE TABLE IF NOT EXISTS life_card_payments(
                    reference TEXT PRIMARY KEY, report_id TEXT NOT NULL UNIQUE REFERENCES life_reports(id),
                    network TEXT NOT NULL, merchant TEXT NOT NULL, amount INTEGER NOT NULL,
                    provider_order TEXT, UNIQUE(merchant, provider_order)
                )
            """)
            db.execute("CREATE TABLE IF NOT EXISTS life_simulated_payment_sequence (number INTEGER NOT NULL)")
            db.execute("INSERT INTO life_simulated_payment_sequence SELECT 0 "
                       "WHERE NOT EXISTS (SELECT 1 FROM life_simulated_payment_sequence)")
            if "sunlands_order" not in {row["name"] for row in db.execute("PRAGMA table_info(life_card_payments)")}:
                db.execute("ALTER TABLE life_card_payments ADD COLUMN sunlands_order TEXT NOT NULL DEFAULT '{}'")
            columns = {row["name"] for row in db.execute("PRAGMA table_info(life_card_payments)")}
            for name in ("sunlands_gateway", "sunlands_order_number", "sunlands_pay_number"):
                if name not in columns:
                    db.execute(f"ALTER TABLE life_card_payments ADD COLUMN {name} TEXT")
            for name in ("sunlands_order_number", "sunlands_pay_number"):
                db.execute(f"CREATE UNIQUE INDEX IF NOT EXISTS unique_{name} "
                           f"ON life_card_payments(sunlands_gateway,merchant,{name})")
            # Reserve legacy platform numbers without deleting receipts or treating them as payments.
            for order in db.execute("SELECT * FROM life_card_payments WHERE merchant LIKE 'sunlands:%' "
                                    "AND sunlands_gateway IS NULL ORDER BY reference").fetchall():
                details = json.loads(order["sunlands_order"])
                if (isinstance(details, dict) and details.get("gateway") and not details.get("associationConflict")
                        and any(_platform_number(details.get(key)) for key in ("orderNumber", "payNumber"))):
                    self._save_sunlands(db, order["reference"], order["merchant"], details)

    @property
    def sunlands_ready(self):
        s = self.settings
        return bool(s.sunlands_app_secret and re.fullmatch(r"[A-Za-z0-9_]+", s.sunlands_app_key)
                    and re.fullmatch(r"[0-9]+", s.sunlands_item_no)
                    and re.fullmatch(r"[0-9]+", s.sunlands_province_id)
                    and (s.sunlands_channel_code in (None, "")
                         or re.fullmatch(r"[A-Za-z0-9_.-]{1,64}", s.sunlands_channel_code)))

    async def _sunlands_post(self, path, body, content_type):
        if not self.order_only or path not in {SUNLANDS_CREATE_ORDER, SUNLANDS_QUERY_ORDER, "/product/api/item/by/page"}:
            raise HTTPException(409, "life_payment_unavailable")
        date = formatdate(usegmt=True)
        digest = "SHA-256=" + base64.b64encode(hashlib.sha256(body).digest()).decode()
        signature = base64.b64encode(hmac.new(
            self.settings.sunlands_app_secret.encode(), f"x-date: {date}\ndigest: {digest}".encode(), hashlib.sha256,
        ).digest()).decode()
        headers = {"Content-Type": content_type, "x-date": date, "digest": digest,
                   "proxy-authorization": f'hmac username="{self.settings.sunlands_app_key}", '
                   f'algorithm="hmac-sha256", headers="x-date digest", signature="{signature}"'}
        async with httpx.AsyncClient(timeout=20, follow_redirects=False) as client:
            response = await client.post(self.settings.sunlands_base_url + path, content=body, headers=headers)
        return response

    def _sunlands_diagnostic(self, value, response=None, *, mobile=""):
        if not isinstance(value, (str, int, float, bool, Decimal, type(None))):
            return f"<{type(value).__name__}>"
        value = str(value)
        sensitive = [mobile, self.settings.sunlands_app_secret]
        if response is not None:
            authorization = response.request.headers.get("proxy-authorization", "")
            sensitive.append(authorization)
            signature = re.search(r'signature="([^"]+)"', authorization)
            if signature:
                sensitive.append(signature[1])
        for secret in sensitive:
            if secret:
                value = value.replace(secret, "[redacted]")
        return value[:1000]

    @staticmethod
    def _sunlands_attempt(details):
        keys = ("attemptStartedAt", "updatedAt", "gateway", "endpoint", "requestSummary",
                "state", "httpStatus", "contentType", "responseBytes",
                "responseHash", "gatewayRequestId", "requestDate", "elapsedMs", "responseType", "responseDataType", "responseSummary",
                "failureStage", "errorType", "parseErrorType", "validationErrors", "associationConflict",
                "orderNumber", "payNumber", "stuId")
        return {key: details[key] for key in keys if key in details}

    def _save_sunlands(self, db, reference, merchant, details, *, record_attempt=False):
        gateway = details["gateway"]
        order_number, pay_number = (_platform_number(details.get(key)) for key in ("orderNumber", "payNumber"))
        # The caller holds BEGIN IMMEDIATE; unique indexes also protect other database writers.
        conflicts = db.execute("SELECT reference FROM life_card_payments WHERE reference<>? AND merchant=? "
                               "AND sunlands_gateway=? AND (sunlands_order_number=? OR sunlands_pay_number=?)",
                               (reference, merchant, gateway, order_number, pay_number)).fetchall()
        if conflicts:
            details.update(state="UNKNOWN", failureStage="association",
                           associationConflict={"references": [row["reference"] for row in conflicts]})
            gateway = order_number = pay_number = None
        if record_attempt:
            details["attempts"] = [*details.get("attempts", [])[-9:], self._sunlands_attempt(details)]
        db.execute("UPDATE life_card_payments SET sunlands_order=?,sunlands_gateway=?,"
                   "sunlands_order_number=?,sunlands_pay_number=? WHERE reference=?",
                   (json.dumps(details, ensure_ascii=False), gateway, order_number, pay_number, reference))

    def _sunlands_view(self, order):
        details = json.loads(order["sunlands_order"])
        if details.get("state") == "ACCESS_DENIED":
            if (details.get("orderNumber") or details.get("payNumber")
                    or order["sunlands_order_number"] or order["sunlands_pay_number"]):
                raise HTTPException(409, "life_order_needs_review")
            raise HTTPException(503, "life_order_access_denied")
        summary = details.get("responseSummary")
        message = summary.get("message") if isinstance(summary, dict) else None
        if (details.get("state") in {"UNKNOWN", "REJECTED"} and isinstance(message, str)
                and message.startswith("channelCode不正确:") and not details.get("orderNumber") and not details.get("payNumber")):
            # Explain the saved channel failure without allowing a new order or rewriting old receipts.
            raise HTTPException(409, "life_order_channel_invalid")
        if details.get("state") == "REJECTED":
            raise HTTPException(409, "life_order_rejected")
        if (details.get("state") != "CREATED" or order["sunlands_gateway"] != details.get("gateway")
                or order["sunlands_order_number"] != details.get("orderNumber")
                or order["sunlands_pay_number"] != details.get("payNumber")):
            # An uncertain upstream result must be checked manually, never retried as a new order.
            raise HTTPException(409, "life_order_needs_review")
        return {"reference": order["reference"], "amount": order["amount"], "currency": "THB",
                "order_only": True, "state": details["state"], "order_number": details["orderNumber"],
                "pay_number": details.get("payNumber"), "stu_id": details.get("stuId"), "item_no": details["itemNo"],
                "product_no": details["productNo"], "checkout_url": _sunlands_checkout_url(details)}

    def existing_sunlands(self, report_id):
        if not self.order_only:
            raise HTTPException(409, "life_payment_unavailable")
        order = self.order_for(report_id)
        if not order:
            return None
        details = json.loads(order["sunlands_order"])
        if (order["merchant"] != "sunlands:" + self.settings.sunlands_app_key
                or details.get("gateway") != self.settings.sunlands_base_url):
            raise HTTPException(409, "life_payment_unavailable")
        return self._sunlands_view(order)

    async def create_sunlands(self, report_id, network, mobile, nation_code):
        if not self.order_only or not self.sunlands_ready:
            raise HTTPException(503, "life_order_configuration_required")
        s = self.settings
        mobile = re.sub(r"[ \t()-]", "", mobile.strip())
        nation_code = nation_code.strip().removeprefix("+")
        if (not re.fullmatch(r"[0-9]{6,14}", mobile)
                or not re.fullmatch(r"[1-9][0-9]{0,2}", nation_code)
                or len(nation_code + mobile) > 15):
            raise HTTPException(422, "life_order_phone_invalid")
        merchant = "sunlands:" + s.sunlands_app_key
        details = {"state": "CREATING", "createdAt": time.time(), "gateway": s.sunlands_base_url,
                   "endpoint": SUNLANDS_CREATE_ORDER,
                   "itemNo": s.sunlands_item_no, "productNo": s.sunlands_product_no,
                   "nationCode": nation_code, "mobileLast4": mobile[-4:],
                   "provinceId": s.sunlands_province_id,
                   "currency": "THB", "paymentStatus": "NOT_CHECKED",
                   "attemptCount": 1, "attemptStartedAt": time.time(), "attempts": []}
        with self.store.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            order = db.execute("SELECT * FROM life_card_payments WHERE report_id=?", (report_id,)).fetchone()
            if order:
                saved = json.loads(order["sunlands_order"])
                if order["merchant"] != merchant or saved.get("gateway") != s.sunlands_base_url:
                    raise HTTPException(409, "life_payment_unavailable")
                # Only an explicit gateway denial is safe to retry with the same local reference.
                if (saved.get("state") != "ACCESS_DENIED" or saved.get("orderNumber") or saved.get("payNumber")
                        or order["sunlands_order_number"] or order["sunlands_pay_number"]):
                    return self._sunlands_view(order)
                reference = order["reference"]
                details["createdAt"] = saved.get("createdAt", details["createdAt"])
                details["attemptCount"] = saved.get("attemptCount", 1) + 1
                details["attempts"] = saved.get("attempts") or [self._sunlands_attempt(saved)]
                db.execute("UPDATE life_card_payments SET sunlands_order=? WHERE reference=?",
                           (json.dumps(details), reference))
            else:
                db.execute("UPDATE life_simulated_payment_sequence SET number=number+1")
                number = db.execute("SELECT number FROM life_simulated_payment_sequence").fetchone()[0]
                reference = f"{number:012d}"
                db.execute("INSERT INTO life_card_payments(reference,report_id,network,merchant,amount,sunlands_order) "
                           "VALUES(?,?,?,?,?,?)", (reference, report_id, network, merchant, SUNLANDS_AMOUNT, json.dumps(details)))
        # Use the phone-order contract; overseas enum values were documented only for the old endpoint.
        form = {"orderType": "NORMAL", "termType": "mobile",
                "nationCode": nation_code, "mobile": mobile,
                "itemNo": s.sunlands_item_no, "itemTitle": s.sunlands_item_title,
                "itemPrice": "30.00", "totalAmount": "30.00", "provinceId": s.sunlands_province_id,
                "deposit": "0.00", "depositAmount": "0.00"}
        # Omit the optional channel unless configured so the gateway supplies its documented default.
        if s.sunlands_channel_code:
            form["channelCode"] = s.sunlands_channel_code
        if s.sunlands_merchant_notify_uri:
            form["merchantNotifyUrl"] = s.sunlands_merchant_notify_uri
        details["requestSummary"] = {**form, "mobile": "***" + mobile[-4:]}
        # Zero-deposit validation prevents the documented automatic use of an existing deposit.
        started = time.monotonic()
        cancelled = None
        try:
            response = await self._sunlands_post(SUNLANDS_CREATE_ORDER, urlencode(form).encode(),
                                                 "application/x-www-form-urlencoded")
            details.update(httpStatus=response.status_code, responseBytes=len(response.content),
                           contentType=self._sunlands_diagnostic(response.headers.get("content-type", ""), response, mobile=mobile),
                           responseHash=hashlib.sha256(response.content).hexdigest(),
                           requestDate=response.request.headers.get("x-date", ""))
            for header in ("x-request-id", "x-kong-request-id", "x-correlation-id"):
                if response.headers.get(header):
                    details["gatewayRequestId"] = self._sunlands_diagnostic(response.headers[header], response, mobile=mobile)
                    break
            envelope = None
            try:
                envelope = response.json(parse_float=Decimal)
                details["responseType"] = type(envelope).__name__
            except ValueError as error:
                details["parseErrorType"] = type(error).__name__
            # The gateway wraps phone-order details in data and reports its own result in flag.
            wrapped = isinstance(envelope, dict) and "data" in envelope
            result = envelope["data"] if wrapped else envelope
            if wrapped:
                details["responseDataType"] = type(result).__name__
            if isinstance(envelope, dict):
                # Keep a bounded, redacted receipt for reconciliation without exposing it to H5.
                summary = {**(result if isinstance(result, dict) else {}), **envelope}
                details["responseSummary"] = {
                    key: self._sunlands_diagnostic(summary[key], response, mobile=mobile)
                    for key in ("isSuccess", "flag", "code", "msg", "message", "errorMsg", "totalAmount", "currency",
                                "orderStatus", "paidupAmount")
                    if key in summary
                }
            if isinstance(result, dict):
                for key in ("orderNumber", "payNumber"):
                    if _platform_number(result.get(key)):
                        details[key] = result[key]
                if isinstance(result.get("payDirectUrl"), str):
                    details["payDirectUrl"] = result["payDirectUrl"]
                if re.fullmatch(r"[1-9][0-9]*", str(result.get("stuId", ""))):
                    details["stuId"] = str(result["stuId"])
            if not response.is_success:
                reason = envelope.get("message") if isinstance(envelope, dict) else None
                denied = (response.status_code in (401, 403) and isinstance(reason, str)
                          and reason in {"You cannot consume this service", "HMAC signature does not match",
                                         "HMAC signature cannot be verified"})
                details.update(state="ACCESS_DENIED" if denied else "UNKNOWN", failureStage="http")
            elif "parseErrorType" in details:
                details.update(state="UNKNOWN", failureStage="parse", errorType=details["parseErrorType"])
            elif isinstance(envelope, dict) and envelope.get("flag", None if wrapped else "1") != "1":
                details.update(state="UNKNOWN", failureStage="business")
            elif isinstance(result, dict) and result.get("isSuccess") is False:
                details.update(state="REJECTED", failureStage="business")
                details["errorMsg"] = details["responseSummary"].get("errorMsg", "")
            elif not isinstance(result, dict) or result.get("isSuccess") is not True:
                # A failed response must not be reported as a successful order missing stuId or order numbers.
                details.update(state="UNKNOWN", failureStage="business")
            else:
                lines = result.get("orderDetails")
                line = lines[0] if isinstance(lines, list) and len(lines) == 1 and isinstance(lines[0], dict) else {}
                checks = {"orderNumber": bool(details.get("orderNumber")),
                          # A created, unpaid phone order may not have a payment number yet.
                          "payNumber": result.get("payNumber") in (None, "") or bool(details.get("payNumber")),
                          "stuId": bool(details.get("stuId")),
                          "currency": result.get("currency", None if wrapped else "THB") == "THB", "orderDetails": bool(line),
                          "orderDetails.itemNo": line.get("itemNo") == s.sunlands_item_no}
                for key, amount in (("totalAmount", result.get("totalAmount")), ("orderDetails.itemPrice", line.get("itemPrice"))):
                    try:
                        checks[key] = Decimal(str(amount)) == Decimal("30.00")
                    except InvalidOperation:
                        checks[key] = False
                errors = [key for key, valid in checks.items() if not valid]
                details["state"] = "UNKNOWN" if errors else "CREATED"
                if errors:
                    details.update(failureStage="validation", validationErrors=errors)
                if isinstance(lines, list):
                    details["subOrderNumbers"] = [line["subSerialNo"] for line in lines if isinstance(line, dict)
                                                  and _platform_number(line.get("subSerialNo"))]
        except httpx.HTTPError as error:
            details.update(state="UNKNOWN", failureStage="transport", errorType=type(error).__name__)
        except asyncio.CancelledError as error:
            details.update(state="UNKNOWN", failureStage="transport", errorType="CancelledError")
            cancelled = error
        finally:
            details["elapsedMs"] = round((time.monotonic() - started) * 1000)
        details["updatedAt"] = time.time()
        with self.store.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            self._save_sunlands(db, reference, merchant, details, record_attempt=True)
        if cancelled is not None:
            raise cancelled
        return self._sunlands_view(self.order_for(report_id))

    def from_sunlands_number(self, number):
        with self.store.connect() as db:
            return db.execute("SELECT p.*,r.owner FROM life_card_payments p "
                              "JOIN life_reports r ON r.id=p.report_id "
                              "WHERE p.sunlands_order_number=? AND p.sunlands_gateway=? AND p.merchant=?",
                              (number, self.settings.sunlands_base_url,
                               "sunlands:" + self.settings.sunlands_app_key)).fetchone()

    async def confirm_sunlands(self, order, notification=None):
        if not order:
            return False
        details = json.loads(order["sunlands_order"])
        if (not self.order_only or not self.settings.sunlands_app_secret
                or order["merchant"] != "sunlands:" + self.settings.sunlands_app_key
                or order["sunlands_gateway"] != self.settings.sunlands_base_url):
            raise HTTPException(503, "life_payment_unavailable")
        self._sunlands_view(order)
        number = order["sunlands_order_number"]
        amount = Decimal(order["amount"]) / 100
        provider_order = order["sunlands_gateway"] + "/" + number
        if notification is not None:
            expected = {"callBackType": "pay", "subOrderStatusCode": "PAID", "orderNumber": number,
                        "userId": details.get("stuId"), "itemNo": details["itemNo"], "currency": "THB"}
            try:
                valid = (all(notification.get(key) == value for key, value in expected.items())
                         and Decimal(notification.get("amount", "")) == amount
                         and notification.get("orderType") in {"NORMAL", "OVERSEAS_NORMAL"}
                         and bool(_platform_number(notification.get("subOrderNumber"))))
            except InvalidOperation:
                valid = False
            if not valid:
                raise HTTPException(409, "life_payment_verification_failed")
        if details.get("paymentStatus") == "PAID" and order["provider_order"] == provider_order:
            if notification is not None and notification["subOrderNumber"] != details.get("verifiedSubOrderNumber"):
                raise HTTPException(409, "life_payment_verification_failed")
            return True

        form = {"orderSerialNos": json.dumps([number]), "orderContent": '["PAY","ITEM"]'}
        check = {"checkedAt": time.time(), "source": "callback" if notification is not None else "poll",
                 "endpoint": SUNLANDS_QUERY_ORDER, "requestSummary": form, "status": "CHECK_FAILED"}
        error_code = "life_payment_check_unavailable"
        paid = False
        try:
            response = await self._sunlands_post(SUNLANDS_QUERY_ORDER, urlencode(form).encode(),
                                                 "application/x-www-form-urlencoded")
            check.update(httpStatus=response.status_code, responseHash=hashlib.sha256(response.content).hexdigest())
            if response.status_code in (401, 403):
                error_code = "life_payment_check_access_denied"
            response.raise_for_status()
            envelope = response.json(parse_float=Decimal)
            # Gateway envelopes and the documented retCode/data response are distinct levels.
            if isinstance(envelope, dict) and "flag" in envelope:
                if envelope["flag"] != "1":
                    raise ValueError("gateway_result")
                envelope = envelope.get("data")
            if not isinstance(envelope, dict) or envelope.get("retCode") != "0":
                raise ValueError("query_result")
            rows = envelope.get("data")
            if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
                raise ValueError("query_orders")
            result = rows[0]
            lines = result.get("orderDetails")
            line = lines[0] if isinstance(lines, list) and len(lines) == 1 and isinstance(lines[0], dict) else {}
            pay = line.get("payInfo") if isinstance(line.get("payInfo"), dict) else {}
            check["responseSummary"] = {key: self._sunlands_diagnostic(result[key], response)
                for key in ("orderSerialNo", "orderStatus", "stuId", "currency", "channelCode",
                            "totalAmount", "paidAmount", "unpaidAmount", "paymentDate") if key in result}
            check["subOrderNumber"] = _platform_number(line.get("subOrderSerialNo"))
            expected_channel = details.get("requestSummary", {}).get("channelCode") or self.settings.sunlands_app_key
            checks = {"orderSerialNo": result.get("orderSerialNo") == number,
                      "stuId": str(result.get("stuId")) == details.get("stuId"),
                      "channelCode": result.get("channelCode") == expected_channel,
                      "currency": result.get("currency") == details.get("currency") == "THB",
                      "orderDetails": bool(line), "itemNo": line.get("itemNo") == details["itemNo"],
                      "subOrderNumber": bool(check["subOrderNumber"]),
                      "orderType": result.get("orderType") in {"NORMAL", "OVERSEAS_NORMAL"}}
            if details.get("subOrderNumbers"):
                checks["subOrderNumber"] = details["subOrderNumbers"] == [check["subOrderNumber"]]
            if notification is not None:
                checks["callback.subOrderNumber"] = notification["subOrderNumber"] == check["subOrderNumber"]
            for key, value in (("totalAmount", result.get("totalAmount")), ("item.totalAmount", line.get("totalAmount"))):
                try:
                    checks[key] = Decimal(str(value)) == amount
                except InvalidOperation:
                    checks[key] = False
            try:
                received, remaining = (Decimal(str(result.get(key))) for key in ("paidAmount", "unpaidAmount"))
                checks["balance"] = (received.is_finite() and remaining.is_finite()
                                     and received >= 0 and remaining >= 0 and received + remaining == amount)
                if not received.is_finite() or not remaining.is_finite():
                    received = remaining = None
            except InvalidOperation:
                checks["balance"] = False
                received = remaining = None
            if result.get("orderStatus") == "PAID":
                checks.update(paidAmount=received == amount and remaining == 0,
                              subOrderStatus=line.get("subOrderStatus") == "PAID",
                              payCurrency=pay.get("currency") == "THB")
                for key in ("paidAmount", "totalAmount"):
                    try:
                        checks["pay." + key] = Decimal(str(pay.get(key))) == amount
                    except InvalidOperation:
                        checks["pay." + key] = False
            elif result.get("orderStatus") != "UNPAID":
                checks["orderStatus"] = False
            check["validationErrors"] = [key for key, valid in checks.items() if not valid]
            if check["validationErrors"]:
                error_code = "life_payment_verification_failed"
            else:
                paid = result["orderStatus"] == "PAID"
                check["status"] = "PAID" if paid else "PENDING"
        except (httpx.HTTPError, ValueError) as error:
            check["errorType"] = type(error).__name__
        if check["status"] == "CHECK_FAILED":
            check["errorCode"] = error_code

        # Persist verified settlement and the report entitlement together, preserving creation receipts.
        with self.store.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            current = db.execute("SELECT * FROM life_card_payments WHERE reference=?", (order["reference"],)).fetchone()
            if not current or any(current[key] != order[key] for key in (
                    "report_id", "merchant", "amount", "sunlands_gateway", "sunlands_order_number", "sunlands_pay_number")):
                raise HTTPException(409, "life_payment_verification_failed")
            saved = json.loads(current["sunlands_order"])
            self._sunlands_view(current)
            if saved.get("paymentStatus") == "PAID" and current["provider_order"] == provider_order:
                return True
            saved["paymentChecks"] = [*saved.get("paymentChecks", [])[-9:], check]
            saved["paymentStatus"] = check["status"]
            if paid:
                updated = db.execute("UPDATE OR IGNORE life_card_payments SET provider_order=? "
                                     "WHERE reference=? AND provider_order IS NULL", (provider_order, order["reference"]))
                if updated.rowcount != 1:
                    paid = False
                    error_code = "life_payment_verification_failed"
                    check.update(status="CHECK_FAILED", errorCode=error_code, validationErrors=["providerOrderConflict"])
                    saved["paymentStatus"] = "CHECK_FAILED"
                else:
                    saved["paidAt"] = time.time()
                    saved["verifiedSubOrderNumber"] = check["subOrderNumber"]
                    db.execute("UPDATE life_reports SET unlocked=1 WHERE id=?", (order["report_id"],))
            db.execute("UPDATE life_card_payments SET sunlands_order=? WHERE reference=?",
                       (json.dumps(saved, ensure_ascii=False), order["reference"]))
        if check["status"] == "CHECK_FAILED":
            raise HTTPException(503 if error_code != "life_payment_verification_failed" else 409, error_code)
        return paid

    def order_for(self, report_id):
        with self.store.connect() as db:
            return db.execute("SELECT * FROM life_card_payments WHERE report_id=?", (report_id,)).fetchone()

    def _create_order(self, report_id, network, merchant, amount):
        with self.store.connect() as db:
            db.execute("INSERT INTO life_card_payments(reference,report_id,network,merchant,amount) "
                       "VALUES(?,?,?,?,?) ON CONFLICT(report_id) DO NOTHING",
                       (str(100000000000 + secrets.randbelow(900000000000)), report_id, network, merchant, amount))
            order = db.execute("SELECT * FROM life_card_payments WHERE report_id=?", (report_id,)).fetchone()
        if not order or order["merchant"] != merchant:
            raise HTTPException(409, "life_payment_unavailable")
        return order

    def create(self, report_id, network, language):
        order = self._create_order(report_id, network, self.merchant, CARD_AMOUNT)
        return {"action": CHECKOUT_URL, "fields": {
            "merchantid": order["merchant"], "refno": order["reference"],
            "customeremail": "test@example.com", "productdetail": "FATE Online Reading Demo",
            "cc": "00", "lang": "TH" if language == "th" else "EN",
            "total": f"{Decimal(order['amount']) / 100:.2f}",
        }}

    def create_simulated(self, report_id, network):
        with self.store.connect() as db:
            # Reserve the next number only when a report has no order yet.
            db.execute("BEGIN IMMEDIATE")
            order = db.execute("SELECT * FROM life_card_payments WHERE report_id=?", (report_id,)).fetchone()
            if order is None:
                db.execute("UPDATE life_simulated_payment_sequence SET number=number+1")
                number = db.execute("SELECT number FROM life_simulated_payment_sequence").fetchone()[0]
                db.execute("INSERT INTO life_card_payments(reference,report_id,network,merchant,amount) VALUES(?,?,?,?,?)",
                           (f"{number:012d}", report_id, network, SIMULATED_MERCHANT, SIMULATED_AMOUNT))
                order = db.execute("SELECT * FROM life_card_payments WHERE report_id=?", (report_id,)).fetchone()
        if order["merchant"] != SIMULATED_MERCHANT:
            raise HTTPException(409, "life_payment_unavailable")
        return {"reference": order["reference"], "amount": order["amount"], "currency": "THB"}

    def confirm_simulated(self, report_id, reference):
        order = self.order_for(report_id)
        if not order or order["merchant"] != SIMULATED_MERCHANT or order["reference"] != reference:
            raise HTTPException(409, "life_payment_required")
        return self._record_payment(order, reference)

    def from_reference(self, reference):
        with self.store.connect() as db:
            return db.execute("SELECT life_card_payments.*, life_reports.owner FROM life_card_payments "
                              "JOIN life_reports ON life_reports.id=life_card_payments.report_id "
                              "WHERE reference=? AND merchant=?", (reference, self.merchant)).fetchone()

    async def inquiry(self, reference):
        merchant_suffix = self.merchant[-5:]
        try:
            async with httpx.AsyncClient(timeout=8) as client:
                response = await client.post(
                    INQUIRY_URL,
                    headers={"apikey": self.api_key, "merchantSecretKey": self.secret_key, "merchantID": merchant_suffix},
                    json={"merchantID": merchant_suffix, "orderNo": "X", "refno": reference, "productDetail": "QWERTY"},
                )
            response.raise_for_status()
            return response.json(parse_float=Decimal) if response.content.strip() else None
        except (httpx.HTTPError, ValueError) as error:
            raise HTTPException(503, "life_payment_unavailable") from error

    async def confirm(self, order):
        if not order or not self.enabled or order["merchant"] != self.merchant:
            return False
        if order["provider_order"]:
            return True
        result = await self.inquiry(order["reference"])
        if isinstance(result, list) and len(result) == 1:
            result = result[0]
        if not isinstance(result, dict) or result.get("Status") != "CP":
            return False
        provider_order = str(result.get("OrderNo") or "")
        try:
            amount = Decimal(str(result.get("Total")))
        except InvalidOperation:
            return False
        if (str(result.get("ReferenceNo")) != order["reference"] or
                str(result.get("MerchantID")) != order["merchant"] or
                str(result.get("CurrencyCode")).upper() not in {"00", "THB"} or
                str(result.get("CardType")).upper() not in {"V", "M", "A", "J", "C", "U"} or
                not amount.is_finite() or amount != Decimal(order["amount"]) / 100 or
                not re.fullmatch(r"[0-9]{1,32}", provider_order)):
            return False
        return self._record_payment(order, provider_order)

    def _record_payment(self, order, provider_order):
        # Record the payment and report entitlement in the same transaction.
        with self.store.connect() as db:
            db.execute("UPDATE OR IGNORE life_card_payments SET provider_order=? "
                       "WHERE reference=? AND provider_order IS NULL", (provider_order, order["reference"]))
            recorded = db.execute("SELECT provider_order FROM life_card_payments WHERE reference=?",
                                  (order["reference"],)).fetchone()
            paid = recorded is not None and recorded["provider_order"] == provider_order
            if paid:
                db.execute("UPDATE life_reports SET unlocked=1 WHERE id=?", (order["report_id"],))
        return paid

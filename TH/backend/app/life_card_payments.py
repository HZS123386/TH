"""Payso Demo checkout and server-side verification for the life report."""
from decimal import Decimal, InvalidOperation
import re
import secrets

import httpx
from fastapi import HTTPException


CARD_AMOUNT = 5000
CHECKOUT_URL = "https://www.thaiepay.com/epaylink/payment.aspx"
INQUIRY_URL = "https://apis.paysolutions.asia/order/orderdetailpost"


class LifeCardPayments:
    def __init__(self, store, settings):
        self.store = store
        self.merchant = settings.payso_test_merchant_id
        self.api_key = settings.payso_test_api_key
        self.secret_key = settings.payso_test_secret_key
        self.enabled = bool(self.merchant or self.api_key or self.secret_key)
        if self.enabled and (settings.app_env != "development" or
                             not re.fullmatch(r"[0-9]{8}", self.merchant) or
                             not self.api_key or not self.secret_key):
            raise RuntimeError("Payso Demo requires development mode and all PAYSO_TEST credentials")
        with store.connect() as db:
            db.execute("""
                CREATE TABLE IF NOT EXISTS life_card_payments(
                    reference TEXT PRIMARY KEY, report_id TEXT NOT NULL UNIQUE REFERENCES life_reports(id),
                    network TEXT NOT NULL, merchant TEXT NOT NULL, amount INTEGER NOT NULL,
                    provider_order TEXT, UNIQUE(merchant, provider_order)
                )
            """)

    def order_for(self, report_id):
        with self.store.connect() as db:
            return db.execute("SELECT * FROM life_card_payments WHERE report_id=?", (report_id,)).fetchone()

    def create(self, report_id, network, language):
        with self.store.connect() as db:
            db.execute("INSERT INTO life_card_payments(reference,report_id,network,merchant,amount) "
                       "VALUES(?,?,?,?,?) ON CONFLICT(report_id) DO NOTHING",
                       (str(100000000000 + secrets.randbelow(900000000000)), report_id, network, self.merchant, CARD_AMOUNT))
        order = self.order_for(report_id)
        if order["merchant"] != self.merchant:
            raise HTTPException(409, "life_payment_unavailable")
        return {"action": CHECKOUT_URL, "fields": {
            "merchantid": order["merchant"], "refno": order["reference"],
            "customeremail": "test@example.com", "productdetail": "FATE Online Reading Demo",
            "cc": "00", "lang": "TH" if language == "th" else "EN",
            "total": f"{Decimal(order['amount']) / 100:.2f}",
        }}

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
        # Record the verified payment and report entitlement in the same transaction.
        with self.store.connect() as db:
            db.execute("UPDATE OR IGNORE life_card_payments SET provider_order=? "
                       "WHERE reference=? AND provider_order IS NULL", (provider_order, order["reference"]))
            paid = db.execute("SELECT provider_order FROM life_card_payments WHERE reference=?",
                              (order["reference"],)).fetchone()["provider_order"] == provider_order
            if paid:
                db.execute("UPDATE life_reports SET unlocked=1 WHERE id=?", (order["report_id"],))
        return paid

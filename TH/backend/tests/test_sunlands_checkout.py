"""Restore the JY checkout contract with synthetic gateways and isolated report owners."""
from copy import deepcopy
import json

from fastapi.testclient import TestClient
import httpx
import pytest

from backend.app.config import ProviderConfig, Settings
from backend.app.life_report_content import LifeWriter
from backend.app.main import create_app
from backend.tests.test_life_reports import HEADERS, client, preview, story_for, thai_story_for, sunlands_phone_response


def test_line_mode_does_not_offer_checkout_with_a_configured_gateway(client, monkeypatch):
    http, app, _, _ = client
    def no_gateway(request):
        pytest.fail("Disabled checkout must never call the payment gateway")
    sunlands_order_only(app, monkeypatch, no_gateway)
    monkeypatch.setattr(app.state.life_reports.settings, "h5_checkout_enabled", False)
    report = preview(http)
    assert report["checkout_enabled"] is False
    assert report["price"]["mode"] == "sunlands_order_only"
    path = f"/api/life-reports/{report['id']}/payment"
    assert http.get(path, headers=HEADERS).status_code == 404
    assert http.post(path, headers=HEADERS, json={}).status_code == 404
    assert http.get(path + "/methods", headers=HEADERS).status_code == 404
    assert http.post(path + "/start", headers=HEADERS, json={"method": "FM_PAYPAL"}).status_code == 404


def sunlands_order_only(app, monkeypatch, handler):
    payments = app.state.life_reports.card_payments
    if not payments.order_only:
        settings = Settings(sunlands_order_only=True, sunlands_app_secret="integration-test-secret",
                            sunlands_order_mobile="13000000000", sunlands_province_id="4")
        monkeypatch.setattr(payments, "settings", settings)
        monkeypatch.setattr(payments, "order_only", True)
    original_client = httpx.AsyncClient
    monkeypatch.setattr(httpx, "AsyncClient", lambda **kwargs: original_client(
        **kwargs, transport=httpx.MockTransport(handler)))
    return payments


@pytest.fixture
def sunlands_settlement(client, monkeypatch, sunlands_phone_response, request):
    from dataclasses import replace
    from urllib.parse import parse_qs, urlsplit
    from backend.app import life_card_payments
    from backend.app.life_card_payments import (
        SUNLANDS_CREATE_ORDER, SUNLANDS_LOAD_CHECKOUT, SUNLANDS_PAY_SINGLE, SUNLANDS_QUERY_ORDER,
    )
    http, app, _, _ = client
    calls = []
    number = "OFFLINE_PHONE_ORDER_001"
    default_price = life_card_payments.SUNLANDS_AMOUNT // 100
    price, language = getattr(request, "param", (default_price, "zh"))
    amount = f"{price:.2f}"
    return_page = "https://fate.example.test/thai-landing/report.html"
    phone_response = json.loads(sunlands_phone_response)
    phone_response["data"]["totalAmount"] = price
    phone_response["data"]["orderDetails"][0]["itemPrice"] = price
    row = {"orderSerialNo": number, "stuId": 12345, "channelCode": "sunlands_fb_fate", "currency": "THB",
           "orderType": "OVERSEAS_NORMAL", "orderStatus": "PAID", "totalAmount": amount,
           "paidAmount": amount, "unpaidAmount": "0.00", "paymentDate": "2026-11-13 12:00:00",
           "orderDetails": [{"subOrderSerialNo": number + "_1", "subOrderStatus": "PAID",
                             "itemNo": "193261112000101", "totalAmount": amount,
                             "payInfo": {"currency": "THB", "paidAmount": amount, "totalAmount": amount}}]}
    state = {"response": {"retCode": "0", "data": [row]}, "status": 200, "error": None, "checkout_total": amount,
             "start_method": "FM_ANTOM_LINEPAY", "pay_url": "https://checkout.example.test/synthetic",
             "cashier_url": f"https://epay.sunlands.com/epay-h5/index.html?orderNumber={number}&sign=fixture#/",
             "pix_limit": price - 1, "true_money_limit": None}
    def upstream(request):
        calls.append(request.url.path)
        if request.url.path == SUNLANDS_CREATE_ORDER:
            form = parse_qs(request.content.decode())
            assert form["merchantNotifyUrl"] == ["/api/life-reports/payment/sunlands/notify"]
            assert form["itemPrice"] == form["totalAmount"] == [amount]
            state["order_return_url"] = form["returnUrl"][0]
            target = urlsplit(state["order_return_url"])
            assert target._replace(query="").geturl() == return_page
            assert parse_qs(target.query) == {"id": [report["id"]], "lang": [language], "payment_return": ["1"]}
            return httpx.Response(200, json=phone_response)
        if request.method == "HEAD":
            assert request.url.scheme == "https" and request.url.params["orderNumber"] == number
            return httpx.Response(302, headers={
                "Location": f"https://epay.sunlands.com/epay-h5/index.html?orderNumber={number}&sign=fixture_signature#/",
            })
        if request.url.path in (SUNLANDS_LOAD_CHECKOUT, SUNLANDS_PAY_SINGLE):
            assert request.headers["Accept-Language"] == ("th-TH" if language == "th" else "zh-CN")
            form = parse_qs(request.content.decode())
            assert form["orderNumber"] == [number] and "payNumber" not in form
            assert form["termType"] == ["mobile"] and form["sign"] == ["fixture_signature"]
            if request.url.path == SUNLANDS_LOAD_CHECKOUT:
                banks = [
                    {"payMethodCode": "FM_PAYPAL", "payMaxLimitAmount": amount},
                    {"payMethodCode": "FM_ANTOM_LINEPAY", "payMaxLimitAmount": amount},
                    {"payMethodCode": "FM_ANTOM_PIX", "payMaxLimitAmount": state["pix_limit"]},
                ]
                if state["true_money_limit"] is not None:
                    banks.append({"payMethodCode": "FM_ANTOM_TRUEMONEY", "payMaxLimitAmount": state["true_money_limit"]})
                return httpx.Response(200, json={"flag": "1", "data": {"code": "1", "data": {
                    "orderNumber": number, "currency": "THB", "totalAmount": state["checkout_total"],
                    "waitPaidAmount": state["response"]["data"][0]["unpaidAmount"],
                    "payBankList": banks,
                }}})
            assert form["payMethodCode"] == [state["start_method"]] and form["payAmountInput"] == [amount]
            if state["start_method"] in {"FM_PAYPAL", "FM_ANTOM_PIX"}:
                content = json.loads(form["payBizContent"][0])
                assert content["versionCode"] == "NEW"
                assert content["successRedirectUrl"] == state["order_return_url"]
            else:
                assert "payBizContent" not in form
            return httpx.Response(200, json={"code": "1", "data": {
                "actionType": "REDIRECT", "redirectMethod": "get", "payUrl": state["pay_url"],
                "cashierUrl": state["cashier_url"], "payMethodCode": state["start_method"],
            }})
        assert request.url.path == SUNLANDS_QUERY_ORDER
        assert parse_qs(request.content.decode()) == {"orderSerialNos": [json.dumps([number])], "orderContent": ['["PAY","ITEM"]']}
        assert request.headers["proxy-authorization"].startswith('hmac username="sunlands_fb_fate",')
        if state["error"] == "timeout":
            raise httpx.ReadTimeout("offline timeout", request=request)
        return httpx.Response(state["status"], json=state["response"])
    payments = sunlands_order_only(app, monkeypatch, upstream)
    monkeypatch.setattr(payments, "settings", replace(payments.settings,
        sunlands_merchant_notify_uri="/api/life-reports/payment/sunlands/notify",
        sunlands_h5_return_url=return_page))
    report = preview(http, language=language)
    assert report["checkout_enabled"] is True
    path = f"/api/life-reports/{report['id']}"
    with monkeypatch.context() as previous_pricing:
        if price != default_price:
            previous_pricing.setattr(life_card_payments, "SUNLANDS_AMOUNT", price * 100)
        created = http.post(path + "/payment", headers={**HEADERS, "Origin": "https://fate.example.test"},
                            json={})
    assert created.status_code == 200 and created.json()["amount"] == price * 100
    assert created.json()["checkout_url"] == phone_response["data"]["payDirectUrl"].replace("http://", "https://", 1)
    notice = {"callBackType": "pay", "subOrderStatusCode": "PAID", "subOrderNumber": number + "_1",
              "orderNumber": number, "userId": "12345", "itemNo": "193261112000101", "amount": amount,
              "orderType": "OVERSEAS_NORMAL", "currency": "THB", "eventTime": "2026-11-13 12:00:00"}
    return http, app, payments, report, path, state, calls, notice


@pytest.mark.parametrize("sunlands_settlement", [(10, "zh"), (10, "th"), (30, "th")], indirect=True,
                         ids=["zh-new", "th-new", "th-previous"])
def test_sunlands_method_selection_uses_the_saved_order_and_requires_verified_payment(sunlands_settlement):
    from backend.app.life_card_payments import SUNLANDS_CREATE_ORDER, SUNLANDS_PAY_SINGLE
    http, _, payments, report, path, state, calls, notice = sunlands_settlement
    payment_path = path + "/payment"
    receipt = deepcopy(state["response"])
    state["response"]["data"][0].update(orderStatus="UNPAID", paidAmount="0.00", unpaidAmount=notice["amount"])
    wrong_owner = {"X-Report-Key": "z" * 48}
    assert http.get(payment_path + "/methods", headers=wrong_owner).status_code == 404
    assert http.post(payment_path + "/start", headers=wrong_owner, json={"method": "FM_ANTOM_LINEPAY"}).status_code == 404
    methods = http.get(payment_path + "/methods", headers=HEADERS)
    assert methods.json() == {"methods": ["FM_ANTOM_LINEPAY", "FM_PAYPAL"], "check_payment": False}
    rejected = http.post(payment_path + "/start", headers=HEADERS, json={"method": "FM_ANTOM_PIX"})
    assert rejected.status_code == 409 and rejected.json()["code"] == "life_checkout_method_unavailable"
    state["checkout_total"] = "1.00"
    assert http.post(payment_path + "/start", headers=HEADERS, json={"method": "FM_ANTOM_LINEPAY"}).status_code == 409
    assert SUNLANDS_PAY_SINGLE not in calls
    state["checkout_total"] = notice["amount"]
    started = http.post(payment_path + "/start", headers=HEADERS, json={"method": "FM_ANTOM_LINEPAY"})
    assert started.json() == {"redirect_url": "https://checkout.example.test/synthetic"}
    assert calls.count(SUNLANDS_CREATE_ORDER) == calls.count(SUNLANDS_PAY_SINGLE) == 1
    assert http.post(payment_path + "/check", headers=HEADERS).json() == {"paid": False}
    assert http.post(path + "/unlock", headers=HEADERS).status_code == 402
    assert payments.order_for(report["id"])["provider_order"] is None
    state["response"] = receipt
    assert http.post(payment_path + "/check", headers=HEADERS).json() == {"paid": True}
    assert http.get(path, headers=HEADERS).json()["access"] == "full"


def test_truemoney_uses_the_sunlands_quote_and_verified_callback(sunlands_settlement):
    from backend.app.life_card_payments import SUNLANDS_CREATE_ORDER, SUNLANDS_PAY_SINGLE

    http, _, _, _, path, state, calls, notice = sunlands_settlement
    method = "FM_ANTOM_TRUEMONEY"
    endpoint = path + "/payment"
    callback = "/api/life-reports/payment/sunlands/notify"
    notice = {**notice, "payMethodCode": method}
    paid = deepcopy(state["response"])
    state["response"]["data"][0].update(orderStatus="UNPAID", paidAmount="0.00", unpaidAmount=notice["amount"])

    for limit in (None, "1.00"):
        state["true_money_limit"] = limit
        assert method not in http.get(endpoint + "/methods", headers=HEADERS).json()["methods"]
        assert http.post(endpoint + "/start", headers=HEADERS, json={"method": method}).status_code == 409
    assert SUNLANDS_PAY_SINGLE not in calls

    state.update(start_method=method, true_money_limit=notice["amount"])
    assert method in http.get(endpoint + "/methods", headers=HEADERS).json()["methods"]
    assert http.post(endpoint + "/start", headers=HEADERS, json={"method": method}).json() == {
        "redirect_url": state["pay_url"],
    }
    assert calls.count(SUNLANDS_CREATE_ORDER) == calls.count(SUNLANDS_PAY_SINGLE) == 1
    assert http.post(callback, data=notice).json()["code"] == 0
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"

    state["response"] = paid
    assert http.post(callback, data=notice).json()["code"] == 1
    assert http.get(path, headers=HEADERS).json()["access"] == "full"


@pytest.mark.parametrize("sunlands_settlement", [(10, "zh"), (10, "th")], indirect=True, ids=["zh", "th"])
@pytest.mark.parametrize("method", ["FM_ANTOM_LINEPAY", "FM_PAYPAL", "FM_ANTOM_PIX"])
def test_sunlands_start_distinguishes_the_general_cashier_from_channel_links(sunlands_settlement, method):
    http, _, payments, report, path, state, _, notice = sunlands_settlement
    state["response"]["data"][0].update(orderStatus="UNPAID", paidAmount="0.00", unpaidAmount=notice["amount"])
    state.update(start_method=method, pix_limit=notice["amount"])
    if method == "FM_ANTOM_LINEPAY":
        language = report["input"]["profile"]["language"]
        directory = "/epay-h5" if language == "zh" else "/epay-pc/"
        state["pay_url"] = f"https://epay.sunlands.com{directory}?orderNumber={notice['orderNumber']}&sign=fixture#/"
    result = http.post(path + "/payment/start", headers=HEADERS, json={"method": method})
    if method == "FM_ANTOM_LINEPAY":
        assert result.status_code == 503 and result.json()["code"] == "life_checkout_channel_link_missing"
        assert "redirect_url" not in result.json()
    else:
        assert result.status_code == 200 and result.json() == {"redirect_url": state["pay_url"]}
    assert payments.order_for(report["id"])["provider_order"] is None
    assert http.get(path, headers=HEADERS).json()["access"] == "preview"


@pytest.mark.parametrize("sunlands_settlement", [(10, "zh"), (10, "th")], indirect=True, ids=["zh", "th"])
@pytest.mark.parametrize("method,pay_url", [
    ("FM_PAYPAL", "https://www.sandbox.paypal.com/checkoutnow?token=private-fixture-token&useraction=CONTINUE"),
    ("FM_ANTOM_PIX", "https://pix.example.test/authorize"),
], ids=["paypal", "pix"])
def test_custom_checkout_returns_to_the_same_report(sunlands_settlement, monkeypatch, caplog, method, pay_url):
    from backend.app.life_card_payments import PAYMENT_LOG, SUNLANDS_CREATE_ORDER, SUNLANDS_PAY_SINGLE

    http, _, payments, _, path, state, calls, _ = sunlands_settlement
    paid = deepcopy(state["response"])
    state["response"]["data"][0].update(orderStatus="UNPAID", paidAmount="0.00", unpaidAmount="10.00")
    state.update(start_method=method, pay_url=pay_url, pix_limit=10)
    headers = {**HEADERS, "Origin": "https://fate.example.test"}
    start = path + "/payment/start"
    payload = {"method": method}

    with monkeypatch.context() as missing:
        missing.setattr(payments.settings, "sunlands_h5_return_url", "")
        assert http.post(start, headers=headers, json=payload).json()["code"] == "life_checkout_return_unavailable"
    different_origin = {**HEADERS, "Origin": "http://127.0.0.1:8885"}
    assert http.post(start, headers=different_origin, json=payload).json()["code"] == "life_checkout_return_unavailable"
    assert SUNLANDS_PAY_SINGLE not in calls

    with caplog.at_level("INFO", logger=PAYMENT_LOG.name):
        assert http.post(start, headers=headers, json=payload).json() == {"redirect_url": state["pay_url"]}
    if method == "FM_PAYPAL":
        assert "wallet_action=CONTINUE" in caplog.text and "private-fixture-token" not in caplog.text
    assert http.post(path + "/payment/check", headers=headers).json() == {"paid": False}
    assert http.get(path, headers=headers).json()["access"] == "preview"
    state["response"] = paid
    assert http.post(path + "/payment/check", headers=headers).json() == {"paid": True}
    assert http.get(path, headers=headers).json()["access"] == "full"
    assert calls.count(SUNLANDS_CREATE_ORDER) == calls.count(SUNLANDS_PAY_SINGLE) == 1


def test_sunlands_preserves_the_epay_entry_for_the_original_order(client, monkeypatch, sunlands_phone_response):
    http, app, _, _ = client
    response = json.loads(sunlands_phone_response)
    number = response["data"]["orderNumber"]
    entry = f"https://epay.sunlands.com/epay-war/ep_pay/epayPay/payDirect.action?orderNumber={number}&termType=mobile"
    response["data"]["payDirectUrl"] = entry
    calls = []
    def upstream(request):
        calls.append(request.url.path)
        return httpx.Response(200, json=response)
    sunlands_order_only(app, monkeypatch, upstream)
    path = f"/api/life-reports/{preview(http)['id']}/payment"
    assert http.post(path, headers=HEADERS).json()["checkout_url"] == entry
    assert http.get(path, headers=HEADERS).json()["checkout_url"] == entry
    assert calls == ["/tradeApi/trade/externalCreateOrder"]


@pytest.mark.parametrize("overrides,error", [
    ({"sunlands_base_url": "https://api-test.sunlands.com"}, "SUNLANDS_BASE_URL"),
    ({"sunlands_order_mobile": ""}, "Incomplete Sunlands payment configuration"),
    ({"sunlands_h5_return_url": "http://127.0.0.1:8885/thai-landing/report.html"}, "SUNLANDS_H5_RETURN_URL"),
])
def test_sunlands_production_rejects_invalid_checkout_configuration(overrides, error):
    from dataclasses import replace
    from backend.app.life_card_payments import LifeCardPayments

    settings = Settings(app_env="production", sunlands_payment_required=True, sunlands_order_only=True,
                        sunlands_app_secret="integration-test-secret", sunlands_order_mobile="13000000000",
                        sunlands_province_id="4", sunlands_h5_return_url="https://fate.example.test/thai-landing/report.html")
    with pytest.raises(RuntimeError, match=error):
        LifeCardPayments(None, replace(settings, **overrides))


@pytest.mark.parametrize("language", ["zh", "th"])
def test_paid_h5_rejects_bad_startup_config_and_recovers_the_original_report(
        language, postgres_url, monkeypatch, sunlands_phone_response):
    from dataclasses import replace
    from urllib.parse import parse_qs
    from backend.app.life_card_payments import SUNLANDS_CREATE_ORDER, SUNLANDS_QUERY_ORDER

    settings = Settings(database_url=postgres_url, app_env="production", sunlands_payment_required=True,
                        sunlands_order_only=True, sunlands_app_secret="integration-test-secret",
                        sunlands_order_mobile="13000000000", sunlands_province_id="4",
                        sunlands_h5_return_url="https://ipplay.top/thai-landing/report.html",
                        providers={"qwen": ProviderConfig("test-key", "https://model.example/v1", "test")})

    async def write(self, bundle, **kwargs):
        fixture = thai_story_for if language == "th" else story_for
        return self.validate(json.dumps(fixture(bundle), ensure_ascii=False), bundle)

    monkeypatch.setattr(LifeWriter, "write", write)
    order_data = json.loads(sunlands_phone_response)["data"]
    number = order_data["orderNumber"]
    calls = []
    paid = False

    def gateway(request):
        assert request.url.host == "api-prod.sunlands.com"
        path = request.url.path
        calls.append(path)
        form = parse_qs(request.content.decode())
        if path == SUNLANDS_CREATE_ORDER:
            assert form["mobile"] == [settings.sunlands_order_mobile] and form["totalAmount"] == ["10.00"]
            assert form["returnUrl"] == [f"{settings.sunlands_h5_return_url}?id={report['id']}&lang={language}&payment_return=1"]
            return httpx.Response(200, content=sunlands_phone_response)
        assert path == SUNLANDS_QUERY_ORDER and json.loads(form["orderSerialNos"][0]) == [number]
        status = "PAID" if paid else "UNPAID"
        received, remaining = ("10.00", "0.00") if paid else ("0.00", "10.00")
        return httpx.Response(200, json={"retCode": "0", "data": [{
            "orderSerialNo": number, "stuId": order_data["stuId"], "channelCode": settings.sunlands_app_key,
            "currency": "THB", "orderType": "OVERSEAS_NORMAL", "orderStatus": status,
            "totalAmount": "10.00", "paidAmount": received, "unpaidAmount": remaining,
            "orderDetails": [{"subOrderSerialNo": number + "_1", "subOrderStatus": status,
                              "itemNo": settings.sunlands_item_no, "totalAmount": "10.00",
                              "payInfo": {"currency": "THB", "paidAmount": received, "totalAmount": "10.00"}}],
        }]})

    original = create_app(settings)
    sunlands_order_only(original, monkeypatch, gateway)
    with TestClient(original) as http:
        report = preview(http, language=language)
        assert report["checkout_enabled"] is True
        path = f"/api/life-reports/{report['id']}"
        assert http.get(path + "/payment", headers=HEADERS).status_code == 204

    for overrides, error in (
        ({"sunlands_order_only": False}, "Paid H5 requires SUNLANDS_ORDER_ONLY=true"),
        ({"sunlands_app_secret": ""}, "Incomplete Sunlands payment configuration"),
        ({"sunlands_order_mobile": ""}, "Incomplete Sunlands payment configuration"),
        ({"sunlands_h5_return_url": ""}, "SUNLANDS_H5_RETURN_URL"),
        ({"app_env": "development"}, "Paid H5 requires APP_ENV=production"),
    ):
        with pytest.raises(RuntimeError, match=error):
            create_app(replace(settings, **overrides))
    assert calls == []

    with TestClient(create_app(settings)) as recovered:
        current = recovered.get(path, headers=HEADERS).json()
        assert current["id"] == report["id"] and current["access"] == "preview"
        assert current["input"]["profile"]["language"] == language
        assert recovered.post(path + "/unlock", headers=HEADERS).status_code == 402
        wrong_origin = {**HEADERS, "Origin": "https://old-site.example.test"}
        invalid = recovered.post(path + "/payment", headers=wrong_origin, json={})
        assert invalid.status_code == 503 and invalid.json()["code"] == "life_checkout_return_unavailable"
        assert recovered.get(path + "/payment", headers=HEADERS).status_code == 204 and not calls
        response = recovered.post(path + "/payment", headers={**HEADERS, "Origin": "https://ipplay.top"}, json={})
        assert response.status_code == 200
        order = response.json()
        assert order["checkout_url"] == order_data["payDirectUrl"].replace("http://", "https://", 1)
        assert order["amount"] == 1000
        assert recovered.post(path + "/payment", headers=HEADERS, json={}).json() == order
        assert recovered.post(path + "/payment", headers=wrong_origin, json={}).json() == order
        assert recovered.post(path + "/payment/check", headers=HEADERS).json() == {"paid": False}
        assert recovered.get(path, headers=HEADERS).json()["access"] == "preview"
        paid = True
        assert recovered.post(path + "/payment/check", headers=HEADERS).json() == {"paid": True}
        assert recovered.get(path, headers=HEADERS).json()["access"] == "full"
    assert calls == [SUNLANDS_CREATE_ORDER, SUNLANDS_QUERY_ORDER, SUNLANDS_QUERY_ORDER]

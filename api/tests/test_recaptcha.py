import hashlib
import hmac
import logging
import re

import httpx
import respx

GOOGLE_URL = "https://www.google.com/recaptcha/api/siteverify"


# 1: recaptcha_response未指定 -> 400 + missing_recaptcha_response、Google未呼び出し
def test_missing_recaptcha_response_returns_400(client):
    with respx.mock:
        resp = client.post("/api/verify-recaptcha", json={})
    assert resp.status_code == 400
    assert resp.json() == {"verified": False, "reason": "missing_recaptcha_response"}


# 2: recaptcha_responseが空文字列 -> 400 + missing_recaptcha_response
def test_empty_recaptcha_response_returns_400(client):
    with respx.mock:
        resp = client.post("/api/verify-recaptcha", json={"recaptcha_response": ""})
    assert resp.status_code == 400
    assert resp.json() == {"verified": False, "reason": "missing_recaptcha_response"}


# 3: JSONボディ自体が不正(パース不能) -> 400 + missing_recaptcha_response、Google未呼び出し
def test_unparseable_json_body_returns_400(client):
    with respx.mock:
        resp = client.post(
            "/api/verify-recaptcha",
            content=b"not valid json",
            headers={"Content-Type": "application/json"},
        )
    assert resp.status_code == 400
    assert resp.json() == {"verified": False, "reason": "missing_recaptcha_response"}


# 4: Google success:true -> 200 + verified:true + token形式一致
def test_google_success_true_returns_200_with_token(client):
    with respx.mock:
        respx.post(GOOGLE_URL).mock(
            return_value=httpx.Response(200, json={"success": True})
        )
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    assert resp.status_code == 200
    body = resp.json()
    assert body["verified"] is True
    assert body["expires_in"] == 300
    assert re.match(r"^\d+\.[0-9a-f]{64}$", body["token"])


# 5: Google success:false -> 400 + recaptcha_failed + error_codes一致
def test_google_success_false_returns_400_with_error_codes(client):
    with respx.mock:
        respx.post(GOOGLE_URL).mock(
            return_value=httpx.Response(
                200, json={"success": False, "error-codes": ["invalid-input-response"]}
            )
        )
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    assert resp.status_code == 400
    assert resp.json() == {
        "verified": False,
        "reason": "recaptcha_failed",
        "error_codes": ["invalid-input-response"],
    }


# 6: Googleタイムアウト -> 200 + verified:true (fail-open)
def test_google_timeout_fails_open(client):
    with respx.mock:
        respx.post(GOOGLE_URL).mock(side_effect=httpx.TimeoutException("timeout"))
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    assert resp.status_code == 200
    assert resp.json()["verified"] is True


# 7: Google接続エラー -> 200 + verified:true (fail-open)
def test_google_connect_error_fails_open(client):
    with respx.mock:
        respx.post(GOOGLE_URL).mock(side_effect=httpx.ConnectError("connection failed"))
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    assert resp.status_code == 200
    assert resp.json()["verified"] is True


# 8: Google 5xx応答 -> 200 + verified:true (fail-open)
def test_google_5xx_fails_open(client):
    with respx.mock:
        respx.post(GOOGLE_URL).mock(return_value=httpx.Response(500))
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    assert resp.status_code == 200
    assert resp.json()["verified"] is True


# 9: RECAPTCHA_SECRET_KEY未設定 -> 500 + internal_error、Google未呼び出し
def test_missing_secret_key_returns_500(client, override_settings):
    override_settings(RECAPTCHA_SECRET_KEY="")
    with respx.mock:
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    assert resp.status_code == 500
    assert resp.json() == {"verified": False, "reason": "internal_error"}


# 10: 発行されたtokenの形式(ケース4のレスポンスを再検証)
def test_issued_token_format(client):
    with respx.mock:
        respx.post(GOOGLE_URL).mock(
            return_value=httpx.Response(200, json={"success": True})
        )
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    token = resp.json()["token"]
    ts, sig = token.split(".", 1)
    assert ts.isdigit()
    assert re.match(r"^[0-9a-f]{64}$", sig)


# 11: 発行されたtokenのHMAC値がhmac.new(secret, ts, sha256)で再計算した値と一致
def test_issued_token_hmac_matches_expected(client):
    with respx.mock:
        respx.post(GOOGLE_URL).mock(
            return_value=httpx.Response(200, json={"success": True})
        )
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": "dummy-response"}
        )
    token = resp.json()["token"]
    ts, sig = token.split(".", 1)
    expected = hmac.new(b"test-hmac-secret", ts.encode(), hashlib.sha256).hexdigest()
    assert sig == expected


# 12: 短時間に規定回数を超えてアクセス -> 429(Google呼び出し前段のレート制限)
def test_recaptcha_rate_limit_returns_429_after_threshold(client):
    with respx.mock:
        for _ in range(10):
            resp = client.post("/api/verify-recaptcha", json={})
            assert resp.status_code == 400
        resp = client.post("/api/verify-recaptcha", json={})
    assert resp.status_code == 429


# 13: OPTIONS /api/verify-recaptchaプリフライト -> 204(または200) + CORSヘッダー一式
def test_preflight_options_returns_cors_headers(client):
    resp = client.options(
        "/api/verify-recaptcha",
        headers={
            "Origin": "https://jyoho1.web.cyberhome.ne.jp",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "Content-Type",
        },
    )
    assert resp.status_code in (200, 204)
    assert (
        resp.headers.get("access-control-allow-origin")
        == "https://jyoho1.web.cyberhome.ne.jp"
    )
    assert "POST" in resp.headers.get("access-control-allow-methods", "")


# 14: fail-open発生時のログにrecaptcha_responseの値が含まれない
def test_fail_open_log_does_not_leak_raw_recaptcha_response(client, caplog):
    raw_value = "super-secret-raw-recaptcha-response-value"
    with caplog.at_level(logging.WARNING), respx.mock:
        respx.post(GOOGLE_URL).mock(side_effect=httpx.TimeoutException("timeout"))
        resp = client.post(
            "/api/verify-recaptcha", json={"recaptcha_response": raw_value}
        )
    assert resp.status_code == 200
    assert raw_value not in caplog.text

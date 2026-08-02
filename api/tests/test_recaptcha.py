import hashlib
import hmac
import logging
import re
from urllib.parse import parse_qs

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


# 15 (internal-spec-vercel.md 9章、2026-08-02追加。6.4節のテスト表自体は9章追加時に
# 更新されていなかったため本テストで補完する): 正しいX-Smoke-Test-Authヘッダー付き
# リクエストは、本番RECAPTCHA_SECRET_KEYではなくRECAPTCHA_TEST_SECRET_KEY
# (Google公式テストシークレットキー)をGoogleへ送信する(日次Playwrightスモーク
# テストの正常系送信を支える`_resolve_secret_key`の分岐そのものを検証する)。
def test_smoke_test_auth_header_switches_to_test_secret_key(client, override_settings):
    override_settings(
        RECAPTCHA_SECRET_KEY="prod-secret", RECAPTCHA_TEST_SECRET_KEY="google-test-secret"
    )
    sent_secret = {}

    def _capture(request):
        sent_secret["value"] = parse_qs(request.content.decode())["secret"][0]
        return httpx.Response(200, json={"success": True})

    with respx.mock:
        respx.post(GOOGLE_URL).mock(side_effect=_capture)
        resp = client.post(
            "/api/verify-recaptcha",
            json={"recaptcha_response": "smoke-test-bypass"},
            headers={"X-Smoke-Test-Auth": "test-smoke-secret"},
        )
    assert resp.status_code == 200
    assert resp.json()["verified"] is True
    assert sent_secret["value"] == "google-test-secret"


# 16: X-Smoke-Test-Authヘッダーが欠落/不一致の場合は、通常のユーザー送信と同様に
# 本番RECAPTCHA_SECRET_KEYがGoogleへ送信される(誤って本番トラフィックがテスト
# シークレットキー扱いにならないことの確認)。
def test_missing_or_invalid_smoke_test_auth_header_uses_production_secret_key(
    client, override_settings
):
    override_settings(
        RECAPTCHA_SECRET_KEY="prod-secret", RECAPTCHA_TEST_SECRET_KEY="google-test-secret"
    )
    sent_secret = {}

    def _capture(request):
        sent_secret["value"] = parse_qs(request.content.decode())["secret"][0]
        return httpx.Response(200, json={"success": True})

    with respx.mock:
        respx.post(GOOGLE_URL).mock(side_effect=_capture)
        resp = client.post(
            "/api/verify-recaptcha",
            json={"recaptcha_response": "dummy-response"},
            headers={"X-Smoke-Test-Auth": "wrong-secret"},
        )
    assert resp.status_code == 200
    assert sent_secret["value"] == "prod-secret"

import hashlib
import hmac
import logging
import time
from collections.abc import Mapping

import httpx

from app.core.config import Settings
from app.models.recaptcha import RecaptchaOutcome

logger = logging.getLogger(__name__)

GOOGLE_SITEVERIFY_URL = "https://www.google.com/recaptcha/api/siteverify"
TOKEN_EXPIRES_IN = 300


def _issue_token(secret: str) -> str:
    ts = str(int(time.time()))
    sig = hmac.new(secret.encode(), ts.encode(), hashlib.sha256).hexdigest()
    return f"{ts}.{sig}"


def _resolve_secret_key(request_headers: Mapping[str, str], settings: Settings) -> str:
    # 9章: X-Smoke-Test-Auth ヘッダーが正しいSMOKE_TEST_SECRETと一致する場合のみ、
    # Google公式テストシークレットキーへ切り替える(日次Playwrightスモークテスト専用)。
    smoke_test_secret = request_headers.get("x-smoke-test-auth")
    if smoke_test_secret and settings.SMOKE_TEST_SECRET and hmac.compare_digest(
        smoke_test_secret, settings.SMOKE_TEST_SECRET
    ):
        return settings.RECAPTCHA_TEST_SECRET_KEY  # Google公式テストシークレットキー
    return settings.RECAPTCHA_SECRET_KEY  # 本番シークレットキー(通常のユーザー送信)


async def verify_recaptcha(
    recaptcha_response: str | None,
    remote_ip: str | None,
    settings: Settings,
    request_headers: Mapping[str, str] | None = None,
) -> RecaptchaOutcome:
    if not recaptcha_response:
        return RecaptchaOutcome(400, {"verified": False, "reason": "missing_recaptcha_response"})

    secret_key = _resolve_secret_key(request_headers or {}, settings)

    if not secret_key or not settings.INTEGRATION_HMAC_SECRET:
        logger.error("recaptcha_config_missing")
        return RecaptchaOutcome(500, {"verified": False, "reason": "internal_error"})

    params = {"secret": secret_key, "response": recaptcha_response}
    if remote_ip:
        params["remoteip"] = remote_ip

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.post(GOOGLE_SITEVERIFY_URL, data=params)
            resp.raise_for_status()
            data = resp.json()
    except (httpx.TimeoutException, httpx.TransportError, httpx.HTTPStatusError, ValueError) as exc:
        # Googleへの到達不能・タイムアウト・5xx・不正なJSON応答 → fail-open
        # (internal-spec-integration.md 2.3節: あくまで「技術的失敗」のみが対象。
        #  success:false の明示応答はここでは捕捉しない、下のelse節で扱う)
        logger.warning("recaptcha_fail_open error_type=%s", type(exc).__name__)
        token = _issue_token(settings.INTEGRATION_HMAC_SECRET)
        return RecaptchaOutcome(200, {"verified": True, "token": token, "expires_in": TOKEN_EXPIRES_IN})

    if data.get("success") is True:
        logger.info("recaptcha_verified success=true")
        token = _issue_token(settings.INTEGRATION_HMAC_SECRET)
        return RecaptchaOutcome(200, {"verified": True, "token": token, "expires_in": TOKEN_EXPIRES_IN})

    error_codes = data.get("error-codes", [])
    logger.info("recaptcha_verified success=false error_codes=%s", error_codes)
    return RecaptchaOutcome(
        400, {"verified": False, "reason": "recaptcha_failed", "error_codes": error_codes}
    )

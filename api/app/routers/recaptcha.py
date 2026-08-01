from fastapi import APIRouter, Depends, Request, Response

from app.core.config import get_settings
from app.core.request_utils import get_client_ip
from app.middleware.rate_limit import rate_limit_recaptcha
from app.services.recaptcha_service import verify_recaptcha

router = APIRouter(prefix="/api", tags=["recaptcha"])


@router.post("/verify-recaptcha")
async def post_verify_recaptcha(
    request: Request,
    response: Response,
    _: None = Depends(rate_limit_recaptcha),
):
    try:
        body = await request.json()
    except Exception:  # noqa: BLE001 - any malformed body must fall through to the
        # contract's 400 missing_recaptcha_response case, not FastAPI's default 422.
        body = {}

    recaptcha_response = body.get("recaptcha_response") if isinstance(body, dict) else None
    if not isinstance(recaptcha_response, str):
        recaptcha_response = None

    outcome = await verify_recaptcha(
        recaptcha_response,
        get_client_ip(request),
        get_settings(),
        request.headers,
    )
    response.status_code = outcome.status_code
    return outcome.body

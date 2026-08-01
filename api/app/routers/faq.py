from fastapi import APIRouter, Depends, Response

from app.middleware.rate_limit import rate_limit_faq
from app.services import faq_service

router = APIRouter(prefix="/api", tags=["faq"])


@router.get("/faq")
def get_faq(response: Response, _: None = Depends(rate_limit_faq)):
    response.headers["Cache-Control"] = "no-store"
    try:
        return faq_service.get_faq_response()
    except faq_service.FaqLoadError:
        response.status_code = 500
        return {"error": "faq_unavailable"}

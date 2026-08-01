import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.logging_config import configure_logging
from app.routers import faq, health, recaptcha

# from app.routers import admin  # 将来のFAQ管理GUI実装時に有効化(MVPではコメントアウトのまま)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    configure_logging()
    # コールドスタート時にFAQ JSONを一度読み込み・検証しておく(壊れたJSONの早期検出。
    # /health は shallow のためこの起動時チェックが唯一の事前検知手段になる)
    from app.services import faq_service
    try:
        faq_service.get_faq_response()
    except faq_service.FaqLoadError:
        logger.error("faq_json_invalid_at_startup")
    yield


settings = get_settings()
_is_production = settings.ENVIRONMENT == "production"

app = FastAPI(
    lifespan=lifespan,
    docs_url=None if _is_production else "/docs",
    redoc_url=None if _is_production else "/redoc",
    openapi_url=None if _is_production else "/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.ALLOWED_ORIGIN],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)

app.include_router(health.router)      # /health
app.include_router(faq.router)         # /api/faq
app.include_router(recaptcha.router)   # /api/verify-recaptcha

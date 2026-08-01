import os
from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    ENVIRONMENT: str = "development"       # VERCEL_ENV から上書き
    ALLOWED_ORIGIN: str = "https://jyoho1.web.cyberhome.ne.jp"
    RECAPTCHA_SECRET_KEY: str = ""
    INTEGRATION_HMAC_SECRET: str = ""
    # 9章(reCAPTCHA CI検証バイパス)用。Production環境のみで値を設定する。
    SMOKE_TEST_SECRET: str = ""
    RECAPTCHA_TEST_SECRET_KEY: str = ""

    model_config = {"case_sensitive": True}


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    settings.ENVIRONMENT = os.getenv("VERCEL_ENV", settings.ENVIRONMENT)
    return settings

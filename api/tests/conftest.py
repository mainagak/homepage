"""pytest共通フィクスチャ。

`app.main`はモジュールインポート時に`get_settings()`を呼び出しCORSMiddlewareを
構築するため、テスト用の環境変数は`app.main`をimportするより前に設定する必要がある。
"""
import json
import os

os.environ.setdefault("RECAPTCHA_SECRET_KEY", "test-recaptcha-secret")
os.environ.setdefault("INTEGRATION_HMAC_SECRET", "test-hmac-secret")
os.environ.setdefault("ALLOWED_ORIGIN", "https://jyoho1.web.cyberhome.ne.jp")
os.environ.setdefault("VERCEL_ENV", "test")
os.environ.setdefault("SMOKE_TEST_SECRET", "test-smoke-secret")
os.environ.setdefault("RECAPTCHA_TEST_SECRET_KEY", "test-recaptcha-test-key")

import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.main import app
from app.middleware import rate_limit
from app.services import faq_service


@pytest.fixture()
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture(autouse=True)
def _reset_state():
    """テスト間でFAQキャッシュ・レート制限バケット・設定キャッシュが
    漏れないようにする(internal-spec-vercel.md 6.2節の確定方針)。"""
    faq_service._load_faq_file.cache_clear()
    rate_limit._buckets.clear()
    get_settings.cache_clear()
    yield
    app.dependency_overrides.clear()
    faq_service._load_faq_file.cache_clear()
    rate_limit._buckets.clear()
    get_settings.cache_clear()


@pytest.fixture()
def write_faq_file(tmp_path, monkeypatch):
    """一時ファイルにfaq.json相当の内容を書き出し、FAQ_FILE_PATHをそこへ差し替える。"""

    def _write(content) -> None:
        path = tmp_path / "faq.json"
        if isinstance(content, str):
            path.write_text(content, encoding="utf-8")
        else:
            path.write_text(json.dumps(content, ensure_ascii=False), encoding="utf-8")
        monkeypatch.setattr(faq_service, "FAQ_FILE_PATH", path)
        faq_service._load_faq_file.cache_clear()

    return _write


@pytest.fixture()
def override_settings(monkeypatch):
    """環境変数を書き換えた上で`get_settings`のキャッシュをクリアし、
    ルーター側が次に`get_settings()`を呼んだ際に新しい値を反映させる
    (ルーターは`get_settings()`を直接呼び出しており`Depends`注入ではないため、
    `app.dependency_overrides`は効かない)。"""

    def _override(**kwargs):
        for key, value in kwargs.items():
            monkeypatch.setenv(key, value)
        get_settings.cache_clear()
        return get_settings()

    return _override

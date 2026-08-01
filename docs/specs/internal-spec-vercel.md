# 内部仕様(フェーズ4 Wave2): Vercel/FastAPI 内部設計

## 位置づけ

本ドキュメントは、フェーズ4(内部仕様調査)Wave2「Vercel/FastAPI内部設計」担当分の
成果物である。Wave1で確定済みの以下3ドキュメントを**前提として遵守し、再設計しない**:

- `docs/specs/internal-spec-integration.md`(Cyberhome⇔Vercel連携契約。reCAPTCHA検証
  フロー、HMACトークン仕様、FAQ API応答契約、CORS、`/health`契約)
- `docs/specs/internal-spec-repo-cicd.md`(`/api`ディレクトリ構成、`vercel.json`方針、
  CI/CDワークフロー)
- `docs/specs/internal-spec-datamodel.md`(FAQ JSON schema、将来のNeon Postgres schema、
  命名規則等の共通規約)

本書は上記3点を実装可能な粒度まで具体化する。並行実行中のWave2「Cyberhome側内部設計」
の成果物とは、`internal-spec-integration.md`の契約を介して連携する(本書からCyberhome側
Perl CGIの実装詳細には立ち入らない)。

参照した`phase4-clarification.md`の主な範囲: ラウンド2 B節(問い合わせフォーム深掘り、
reCAPTCHA関連)・C節(FAQ深掘り)、インフラ深掘り1/5(Python技術選定)、
インフラ深掘り2/5 L節(Cyberhome継続)・M節(Neon DB+FAQ管理GUI仕様)・
N節(FastAPI深掘り)、インフラ深掘り3/5 O節(GUI認証・セキュリティ)・
P節(Neon運用)・Q節(Vercelデプロイ・環境戦略)、インフラ深掘り4/5 S節(Perl/コード品質
系。Python側は直接該当なし)。

---

## 0. Wave1ドキュメント間の整合・reconciliation(本書内での解決、再設計ではない)

実装に着手する前に、Wave1の3ドキュメント間に存在する軽微な表記差異を本書のレベルで
解決しておく(いずれも契約自体の変更ではなく、実装上の解釈の確定)。

### 0.1 `/health`のルーティング方式

`internal-spec-integration.md` 4節は「Vercelは既定で`/api/*`配下が自動ルーティングされる
ため、`/health`用に`vercel.json`へ明示的なrewriteが必要」と記載している。一方
`internal-spec-repo-cicd.md` 4.1節が確定した`api/vercel.json`は、**全パスを`index.py`へ
catch-allする`routes`設定**(`{"src": "/(.*)", "dest": "index.py"}`)を採用しており、
この時点で「ファイル単位の自動ルーティング」は既に無効化されている。したがって:

- **決定:** 追加の`vercel.json` rewriteは不要。全リクエストが`index.py`(FastAPIアプリ)
  へ到達するため、FastAPI自身のルーターで`/health`(プレフィックスなし)を直接定義すれば
  契約上のパス(`/health`)をそのまま満たせる。
- `internal-spec-repo-cicd.md`のディレクトリツリー内コメント「`health.py` … `GET /api/health`」
  は、上記のcatch-all設定を踏まえると実際には誤記(ラベルの付け間違い)と判断する。
  本書では`health.py`が定義するエンドポイントは**`/health`(`/api`プレフィックスなし)**
  であることを明記する(契約`internal-spec-integration.md`が優先)。

### 0.2 HMAC共有シークレットの環境変数名

`internal-spec-integration.md` 7節は`INTEGRATION_HMAC_SECRET`、
`internal-spec-repo-cicd.md` 7.3節は`HMAC_SHARED_SECRET`という異なる変数名を使っている。
連携契約そのものを規定する`internal-spec-integration.md`を正とし、**`INTEGRATION_HMAC_SECRET`
に統一する**(本書以降、Vercel側の実装・環境変数一覧はすべてこの名称で統一する。Cyberhome
側の対応する非公開ファイルの中身は同一値である必要があるのみで、ファイル名自体は
Cyberhome側設計の管轄)。

### 0.3 FAQ「ファイルの中身」と「API応答」は別レイヤ(矛盾ではない)

`internal-spec-datamodel.md` 2章が規定するのは**`api/app/data/faq.json`というファイルの
中身**(トップレベルキー`items`、`faq_schema_version`、各項目に`display_order`を含む)で
あり、`internal-spec-integration.md` 3章が規定するのは**`GET /api/faq`のHTTPレスポンス**
(トップレベルキー`faqs`、`display_order`を含まない)である。両者はキー名が異なるが、
これは矛盾ではなく「ストレージ形式」と「公開契約」という別レイヤの話であり、
`internal-spec-datamodel.md`冒頭でも「本書が規定するのはファイルの中身、パスはAPI設計側の
決定を優先してよい」と明記されている。**本書の`faq_service.py`が両者を変換するマッピング層
を担う**(詳細は2章)。

`id`のフォーマットについても、`internal-spec-integration.md`の例示(`"faq-001"`)は
桁数が非公式な例示であり、`internal-spec-datamodel.md`が定義する正規表現
`^faq-\d{4}$`(4桁ゼロ埋め)を正式仕様として採用する(`internal-spec-integration.md`が
実際に確定させているのは「文字列の`id`フィールドが存在すること」「破壊的変更を避けること」
であり、桁数までは契約対象になっていないため)。

---

## 1. FastAPIアプリ全体構成

`internal-spec-repo-cicd.md` 1.3節のディレクトリ構成をそのまま踏襲し、必要なサブモジュール
を追加する(追加分は同ドキュメントと矛盾しない拡張)。

```
api/
├── vercel.json                  (repo-cicd.md 4.1節、変更なし)
├── .vercelignore                (repo-cicd.md 4.2節、変更なし)
├── requirements.txt
├── requirements-dev.txt
├── .env.example
├── index.py                     ← `from app.main import app` のみ(Vercelエントリポイント)
└── app/
    ├── __init__.py
    ├── main.py                  FastAPI()生成、lifespan、CORS、ルーター登録
    ├── core/                    ★本書で追加
    │   ├── __init__.py
    │   ├── config.py            環境変数読み込み(pydantic-settings)
    │   ├── logging_config.py    logging基本設定
    │   └── request_utils.py     get_client_ip() 等の共通ヘルパー
    ├── middleware/               ★本書で追加
    │   ├── __init__.py
    │   └── rate_limit.py         簡易レート制限(5章)
    ├── routers/
    │   ├── faq.py                 GET /api/faq
    │   ├── recaptcha.py           POST /api/verify-recaptcha
    │   ├── health.py              GET /health(プレフィックスなし、0.1節参照)
    │   └── admin.py                FAQ管理GUI(MVP: スタブのみ、7章参照)
    ├── models/
    │   ├── faq.py                 FaqFileItem/FaqFile(ファイル用) + FaqApiItem/FaqApiResponse(API応答用)
    │   └── recaptcha.py            RecaptchaOutcome等(レスポンス文書化用、リクエストは手動パース。3.2節参照)
    ├── services/
    │   ├── faq_service.py          faq.json読み込み・検証・API形式への変換
    │   ├── recaptcha_service.py    Google siteverify呼び出し + HMACトークン発行
    │   └── auth_service.py         (将来)GUI認証。MVP時点は未実装スタブ
    ├── data/
    │   └── faq.json                MVP時点の静的FAQデータ(初期 items: [])
    ├── db/
    │   ├── __init__.py
    │   └── session.py              (将来)Neon接続。MVP時点はプレースホルダ
    ├── templates/                  (将来)GUI用Jinja2テンプレート
    │   └── admin/
    └── static/                     (将来)GUI用CSS
```

### 1.1 依存性注入・ライフサイクル

```python
# app/main.py
from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.logging_config import configure_logging
from app.routers import faq, recaptcha, health
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
```

- `docs_url`/`redoc_url`/`openapi_url`は`ENVIRONMENT != "production"`の時のみ有効化し、
  「`/docs`は本番非公開」の確定事項を満たす。`ENVIRONMENT`はVercelが自動設定する
  `VERCEL_ENV`(`production`/`preview`/`development`)をそのまま利用する(2.1節)。
- CORSは`CORSMiddleware`を全体に適用し、`allow_origins`は環境変数`ALLOWED_ORIGIN`から
  読み込む(Production/Preview別に値を設定できる設計、後述8章)。

### 1.2 `index.py`

```python
# api/index.py
from app.main import app  # noqa: F401  Vercel Python runtimeが `app` を探す
```

### 1.3 設定管理(`app/core/config.py`)

```python
from functools import lru_cache
import os

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    ENVIRONMENT: str = "development"       # VERCEL_ENV から上書き
    ALLOWED_ORIGIN: str = "https://jyoho1.web.cyberhome.ne.jp"
    RECAPTCHA_SECRET_KEY: str = ""
    INTEGRATION_HMAC_SECRET: str = ""

    model_config = {"case_sensitive": True}


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    settings.ENVIRONMENT = os.getenv("VERCEL_ENV", settings.ENVIRONMENT)
    return settings
```

`requirements.txt`に`pydantic-settings`を追加する必要がある(Pydantic v2ではBaseSettingsが
別パッケージに分離されているため)。

### 1.4 ロギング方針(`app/core/logging_config.py`)

```python
import logging


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
```

**ログに出力してよいもの/いけないものの明確なルール**(`phase4-clarification.md`
ラウンド2 E節Q30(C)に基づく):

| 許可 | 禁止 |
|---|---|
| reCAPTCHA検証結果(`success: true/false`) | `recaptcha_response`の生の値 |
| fail-open発生とその理由クラス名(タイムアウト等) | 発行したHMACトークンの値そのもの |
| HMACトークン発行イベント(発行した/しなかった、のみ) | 問い合わせ内容(Vercelは受け取らないため該当なし) |
| レート制限発動イベント(エンドポイント名のみ) | クライアントIPアドレス(レート制限のキーとしてはメモリ上でのみ保持し、ログには出力しない) |
| FAQ JSON読み込み成功/失敗 | FAQの質問・回答文自体(個人情報ではないが冗長なため出力しない) |

---

## 2. `GET /api/faq` 実装設計

### 2.1 モデル定義(`app/models/faq.py`)

```python
from typing import Literal
from pydantic import BaseModel, Field, field_validator

FaqCategory = Literal["書籍について", "仕事の相談", "会社について"]
CATEGORY_ORDER: list[FaqCategory] = ["書籍について", "仕事の相談", "会社について"]


# --- ファイル(api/app/data/faq.json)側のスキーマ。internal-spec-datamodel.md 2章と完全一致 ---
class FaqFileItem(BaseModel):
    id: str = Field(pattern=r"^faq-\d{4}$")
    category: FaqCategory
    question: str = Field(min_length=1, max_length=100)
    answer: str = Field(min_length=1, max_length=1000)
    display_order: int = Field(gt=0)

    @field_validator("question", "answer")
    @classmethod
    def no_html_tags(cls, v: str) -> str:
        if "<" in v or ">" in v:
            raise ValueError("HTML tags are not allowed")
        return v


class FaqFile(BaseModel):
    faq_schema_version: int
    items: list[FaqFileItem]

    @field_validator("items")
    @classmethod
    def unique_display_order_per_category(cls, items: list[FaqFileItem]) -> list[FaqFileItem]:
        seen: dict[str, set[int]] = {}
        for item in items:
            bucket = seen.setdefault(item.category, set())
            if item.display_order in bucket:
                raise ValueError(
                    f"duplicate display_order {item.display_order} in category {item.category}"
                )
            bucket.add(item.display_order)
        return items


# --- API応答側のスキーマ。internal-spec-integration.md 3.2章と完全一致 ---
class FaqApiItem(BaseModel):
    id: str
    category: FaqCategory
    question: str
    answer: str


class FaqApiResponse(BaseModel):
    faqs: list[FaqApiItem]
    updated_at: str | None = None
```

### 2.2 サービス層(`app/services/faq_service.py`)

```python
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
import json
import logging

from app.models.faq import CATEGORY_ORDER, FaqApiItem, FaqApiResponse, FaqFile

logger = logging.getLogger(__name__)

FAQ_FILE_PATH = Path(__file__).resolve().parent.parent / "data" / "faq.json"


class FaqLoadError(Exception):
    """faq.json の読み込み・検証に失敗した場合に送出する"""


@lru_cache(maxsize=1)
def _load_faq_file() -> FaqFile:
    try:
        raw = json.loads(FAQ_FILE_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        logger.error("faq_json_read_failed error_type=%s", type(exc).__name__)
        raise FaqLoadError("failed to read faq.json") from exc

    try:
        faq_file = FaqFile.model_validate(raw)
    except Exception as exc:  # pydantic.ValidationError
        logger.error("faq_json_validation_failed error_type=%s", type(exc).__name__)
        raise FaqLoadError("failed to validate faq.json") from exc

    if faq_file.faq_schema_version != 1:
        logger.warning(
            "faq_schema_version_unexpected version=%s", faq_file.faq_schema_version
        )
    return faq_file


def get_faq_response() -> FaqApiResponse:
    faq_file = _load_faq_file()
    sorted_items = sorted(
        faq_file.items,
        key=lambda i: (CATEGORY_ORDER.index(i.category), i.display_order),
    )
    updated_at = datetime.fromtimestamp(
        FAQ_FILE_PATH.stat().st_mtime, tz=timezone.utc
    ).isoformat()
    return FaqApiResponse(
        faqs=[
            FaqApiItem(id=i.id, category=i.category, question=i.question, answer=i.answer)
            for i in sorted_items
        ],
        updated_at=updated_at,
    )
```

- `lru_cache`により、同一の温まったVercel実行環境(コンテナ)内では`faq.json`の読み込みは
  1回のみ(再デプロイ=新しいコンテナ=キャッシュも自然にリセットされるため、手動での
  キャッシュ無効化は不要)。
- `updated_at`は`internal-spec-integration.md`3.2節で「省略可能なメタ情報」とされているが、
  `faq.json`のファイル更新時刻(mtime)をUTC ISO8601形式でそのまま使うことで、実装コストを
  かけずに意味のある値を提供する(将来Neon移行時は`faqs`テーブルの`MAX(updated_at)`に
  差し替える)。
- レスポンス項目の並び順は「カテゴリの固定順(external-spec.mdの①②③順)→
  同一カテゴリ内は`display_order`昇順」で確定させ、**サーバー側で並べ替え済みの配列を返す**。
  フロントエンドJS(`site/js/chat-widget.js`)はこの順序をそのまま描画順として使えばよく、
  クライアント側で独自にソートし直す必要はない(保守性重視・実装コスト最小化に合致)。

### 2.3 ルーター(`app/routers/faq.py`)

```python
from fastapi import APIRouter, Depends, HTTPException, Response

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
```

`Cache-Control: no-store`は`internal-spec-integration.md` 3.3節の確定事項。エラー時の
ボディ形式(`{"error": "faq_unavailable"}`)は契約に明記がないため、Wave2の裁量で
一貫した形式を定義した(ブラウザ側は`internal-spec-integration.md` 6.2節により
ステータスコードのみで4xx/5xx判定するため、ボディ形式そのものは契約に影響しない)。

---

## 3. `POST /api/verify-recaptcha` 実装設計

### 3.1 契約再掲(`internal-spec-integration.md` 2.2節、Step 5)

| ケース | HTTPステータス | ボディ |
|---|---|---|
| `recaptcha_response`未指定/空 | 400 | `{"verified": false, "reason": "missing_recaptcha_response"}` |
| Google `success:false` | 400 | `{"verified": false, "reason": "recaptcha_failed", "error_codes": [...]}` |
| Google `success:true` | 200 | `{"verified": true, "token": "...", "expires_in": 300}` |
| Google呼び出し自体が技術的に失敗(fail-open) | 200 | `{"verified": true, "token": "...", "expires_in": 300}` |
| 内部エラー(シークレット未設定等) | 500 | `{"verified": false, "reason": "internal_error"}` |

### 3.2 リクエストボディを手動パースする設計判断(重要)

FastAPIの標準的な`BaseModel`をリクエストボディに使うと、必須フィールド欠如時に
Pydanticが自動的に**422** Unprocessable Entityを返してしまい、契約が定める
「**400** + `{"verified": false, "reason": "missing_recaptcha_response"}`」という形式と
一致しなくなる。これを避けるため、本エンドポイントは**リクエストボディを手動でパースし、
契約通りのステータスコード・ボディを明示的に組み立てる**。`app/models/recaptcha.py`は
OpenAPIドキュメント表示・レスポンス側の型表現専用として保持する(リクエスト側の
検証には使わない)。

```python
# app/models/recaptcha.py
from dataclasses import dataclass


@dataclass
class RecaptchaOutcome:
    status_code: int
    body: dict
```

### 3.3 サービス層(`app/services/recaptcha_service.py`)

```python
import hashlib
import hmac
import logging
import time

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


async def verify_recaptcha(
    recaptcha_response: str | None,
    remote_ip: str | None,
    settings: Settings,
) -> RecaptchaOutcome:
    if not recaptcha_response:
        return RecaptchaOutcome(400, {"verified": False, "reason": "missing_recaptcha_response"})

    if not settings.RECAPTCHA_SECRET_KEY or not settings.INTEGRATION_HMAC_SECRET:
        logger.error("recaptcha_config_missing")
        return RecaptchaOutcome(500, {"verified": False, "reason": "internal_error"})

    params = {"secret": settings.RECAPTCHA_SECRET_KEY, "response": recaptcha_response}
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
```

- fail-openの対象は`internal-spec-integration.md` 2.3節の通り「Vercel→Google呼び出しの
  技術的失敗」のみに限定し、`success: false`という**正常に届いた**Google応答は明確に
  別コードパス(`else`側)として扱う。これによりWave1が要求した「例外捕捉による
  fail-openと、正常応答内`success:false`によるfail-closedを別ロジックにする」を満たす。
- `httpx.HTTPStatusError`は`raise_for_status()`が4xx/5xxで送出するため、Google側の
  5xxだけでなく万一の4xx応答も技術的失敗として扱う(契約は5xxのみ明記しているが、
  Google siteverifyは通常のバリデーション失敗を`success:false`(HTTPステータス200)で
  返す設計のため、4xxが返る場合はネットワーク・プロキシ層の異常など「呼び出し自体の
  失敗」に近いケースと判断し、安全側=fail-openに倒す)。

### 3.4 ルーター(`app/routers/recaptcha.py`)

```python
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
    except Exception:
        body = {}

    recaptcha_response = body.get("recaptcha_response") if isinstance(body, dict) else None
    if not isinstance(recaptcha_response, str):
        recaptcha_response = None

    outcome = await verify_recaptcha(
        recaptcha_response, get_client_ip(request), get_settings()
    )
    response.status_code = outcome.status_code
    return outcome.body
```

CORSプリフライト(`OPTIONS /api/verify-recaptcha`)は`CORSMiddleware`が自動応答するため
個別実装は不要(`internal-spec-integration.md` 5.1節)。

### 3.5 クライアントIP取得(`app/core/request_utils.py`)

```python
from fastapi import Request


def get_client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None
```

Vercelはプロキシ経由でリクエストを転送するため、実クライアントIPは
`X-Forwarded-For`ヘッダーの先頭値を採用する(Google siteverifyの`remoteip`パラメータ、
および5章のレート制限キーの双方で使用)。

---

## 4. `GET /health` 実装設計

```python
# app/routers/health.py
from datetime import datetime, timezone

from fastapi import APIRouter

router = APIRouter(tags=["health"])  # プレフィックスなし(0.1節参照)


@router.get("/health")
def get_health():
    return {
        "status": "ok",
        "service": "homepage-api",
        "time": datetime.now(timezone.utc).isoformat(),
    }
```

- `internal-spec-integration.md` 4節の通り、MVP時点はプロセス生存確認のみ(DB接続確認なし、
  shallow health check)。
- 認証なし・CORS対象外(サーバー間呼び出しのためOriginヘッダーが付かず、
  `CORSMiddleware`の許可オリジン設定があっても実害はない)。
- 呼び出し元(GitHub Actionsの定期ping)の頻度は`internal-spec-repo-cicd.md`のCI/CD設計
  側の管轄。本書は`/health`自体の実装のみを担当する。

---

## 5. レート制限の実装方法

### 5.1 方針

「レート制限は簡易的に実装する」という確定前提、および想定トラフィック規模(月10件規模の
問い合わせ、reCAPTCHA検証はその前段としてほぼ同規模)を踏まえ、**外部サービス・追加の
有料インフラを導入しない自前のインメモリ実装**を採用する(`slowapi`等のライブラリは
Redis等の外部ストアと組み合わせて初めて分散環境で効果を発揮するものであり、Vercelの
サーバーレス関数(インスタンスごとにメモリが独立)という実行環境ではライブラリを
導入する追加コストに見合うメリットが薄いため不採用)。

**制約の明記(実装時に必ず引き継ぐこと):** 本実装はプロセス(温まった実行コンテナ)単位の
インメモリカウンタであり、Vercelが複数の実行インスタンスを同時に起動した場合、
インスタンスをまたいだ完全なレート制限にはならない。月10件規模の低頻度アクセスという
想定規模、かつ本エンドポイント群の主たるスパム対策はreCAPTCHA本体とCyberhome側
`contact.cgi`のHMACトークンfail-closed検証であることを踏まえ、本実装は**多層防御の
補助的な1層**と位置づける(唯一の防御手段ではない)。将来的に厳密なグローバルレート
制限が必要になった場合は、Vercel KVやUpstash Redis等の導入を保守サイクルで検討する。

### 5.2 実装(`app/middleware/rate_limit.py`)

```python
from collections import defaultdict
from time import time

from fastapi import Depends, HTTPException, Request

from app.core.request_utils import get_client_ip

_WINDOW_SECONDS = 300  # 5分。contact.cgi側の重複送信判定・HMACトークン有効期限と同じ値を
                        # 採用し、保守者が覚える時間定数を1つに揃える(保守性重視)
_buckets: dict[str, list[float]] = defaultdict(list)


def _check(key: str, limit: int) -> None:
    now = time()
    window_start = now - _WINDOW_SECONDS
    bucket = _buckets[key]
    while bucket and bucket[0] < window_start:
        bucket.pop(0)
    if len(bucket) >= limit:
        raise HTTPException(status_code=429, detail={"reason": "rate_limited"})
    bucket.append(now)


def rate_limit_recaptcha(request: Request) -> None:
    ip = get_client_ip(request) or "unknown"
    _check(f"recaptcha:{ip}", limit=10)  # 5分あたり10回まで


def rate_limit_faq(request: Request) -> None:
    ip = get_client_ip(request) or "unknown"
    _check(f"faq:{ip}", limit=60)  # 5分あたり60回まで(通常のウィジェット開閉操作を妨げない値)
```

- しきい値(`verify-recaptcha`=10回/5分、`faq`=60回/5分)は月10件規模の実運用を大きく
  上回る余裕を持たせつつ、明らかな連打・スクリプト的アクセスは弾ける値として本書で
  確定する(業務要件からの直接の数値指定はないため、Wave2の裁量による合理的な決定)。
- IPアドレスはレート制限の**メモリ上のキーとしてのみ**使用し、ログには出力しない(1.4節)。
- 429応答時のボディ形式は契約外(Wave2の裁量)。ブラウザ側は
  `internal-spec-integration.md` 6章の「4xx/5xxはまとめて失敗として扱う」設計に従うため、
  429固有のハンドリングをフロントJSに追加する必要はない。

---

## 6. pytestテスト設計

### 6.1 依存関係(`requirements-dev.txt`への追加提案)

```
pytest
pytest-asyncio
httpx           # FastAPI TestClientの基盤(fastapiインストール時に依存関係として入る場合が多いが明示)
respx           # httpx向けのGoogle siteverify呼び出しモック用(テスト専用、本番requirements.txtには含めない)
ruff
```

`respx`はGoogle siteverifyへの`httpx.AsyncClient.post`呼び出しを、URLパターンで
成功・失敗・タイムアウト・5xxを模擬できるライブラリとして採用する(`.vercelignore`で
`requirements-dev.txt`ごと本番ビルドから除外されるため、本番バンドルサイズには影響しない)。

### 6.2 `conftest.py`

- FastAPI `TestClient`(または`httpx.AsyncClient` + `ASGITransport`)を返すfixture。
- テスト用`Settings`(`RECAPTCHA_SECRET_KEY="test-secret"`,
  `INTEGRATION_HMAC_SECRET="test-hmac-secret"`, `ALLOWED_ORIGIN="https://jyoho1.web.cyberhome.ne.jp"`)
  に差し替えるfixture(`app.dependency_overrides`または環境変数モンキーパッチ)。
- `faq_service._load_faq_file`の`lru_cache`をテスト間でクリアするautouse fixture
  (`faq_service._load_faq_file.cache_clear()`)。
- 一時`faq.json`を書き出し`FAQ_FILE_PATH`をモンキーパッチするfixture(正常系・0件・
  壊れたJSON等のバリエーションを用意)。
- `app.middleware.rate_limit._buckets`をテスト間でクリアするautouse fixture(前のテストの
  カウントが次のテストに漏れないようにする)。

### 6.3 `test_faq.py`

| # | テストケース | 種別 |
|---|---|---|
| 1 | `items: []`のとき`200`かつ`{"faqs": [], "updated_at": "..."}` | 正常系(空状態) |
| 2 | 複数件・複数カテゴリのとき、カテゴリ固定順→`display_order`昇順で返る | 正常系 |
| 3 | レスポンスの各項目に`id`/`category`/`question`/`answer`のみ含まれ`display_order`が含まれない | 契約準拠チェック |
| 4 | レスポンスヘッダーに`Cache-Control: no-store`が付与される | 契約準拠チェック |
| 5 | 許可オリジンからの`fetch`相当リクエストで`Access-Control-Allow-Origin`ヘッダーが返る | CORS |
| 6 | 許可外オリジンでは`Access-Control-Allow-Origin`ヘッダーが返らない(または値が一致しない) | CORS |
| 7 | `faq.json`が存在しない/壊れたJSON/スキーマ不正のとき`500`+`{"error": "faq_unavailable"}` | 異常系 |
| 8 | `FaqFileItem`単体: `id`が`^faq-\d{4}$`に一致しない値はバリデーションエラー | モデル単体テスト |
| 9 | `FaqFileItem`単体: `category`が固定3値以外はバリデーションエラー | モデル単体テスト |
| 10 | `FaqFileItem`単体: `question`/`answer`に`<`/`>`を含むとバリデーションエラー | モデル単体テスト |
| 11 | `FaqFile`単体: 同一カテゴリ内で`display_order`が重複するとバリデーションエラー | モデル単体テスト |
| 12 | 短時間に規定回数を超えてアクセスすると`429`になる | レート制限 |

### 6.4 `test_recaptcha.py`

`respx`でGoogle siteverify(`https://www.google.com/recaptcha/api/siteverify`)を
モックする。

| # | テストケース | Googleモック | 期待結果 |
|---|---|---|---|
| 1 | `recaptcha_response`未指定 | 呼び出されない | `400` + `missing_recaptcha_response` |
| 2 | `recaptcha_response`が空文字列 | 呼び出されない | `400` + `missing_recaptcha_response` |
| 3 | JSONボディ自体が不正(パース不能) | 呼び出されない | `400` + `missing_recaptcha_response` |
| 4 | Google `success: true` | 200 `{"success": true, ...}` | `200` + `verified: true` + `token`形式一致 |
| 5 | Google `success: false` | 200 `{"success": false, "error-codes": [...]}` | `400` + `recaptcha_failed` + `error_codes`一致 |
| 6 | Googleタイムアウト | `respx`で`httpx.TimeoutException`を送出 | `200` + `verified: true`(fail-open) |
| 7 | Google接続エラー | `respx`で`httpx.ConnectError`を送出 | `200` + `verified: true`(fail-open) |
| 8 | Google 5xx応答 | 500応答 | `200` + `verified: true`(fail-open) |
| 9 | `RECAPTCHA_SECRET_KEY`未設定 | 呼び出されない(事前チェックで弾く) | `500` + `internal_error` |
| 10 | 発行された`token`の形式 | ケース4のレスポンスを検証 | 正規表現`^\d+\.[0-9a-f]{64}$`に一致 |
| 11 | 発行された`token`のHMAC値 | ケース4のレスポンスを検証 | `hmac.new(secret, ts, sha256)`で再計算した値と一致 |
| 12 | 短時間に規定回数を超えてアクセス | (Google呼び出し前段) | `429` |
| 13 | `OPTIONS /api/verify-recaptcha`プリフライト | - | `204`(または`200`)+ CORSヘッダー一式 |
| 14 | fail-open発生時のログに`recaptcha_response`の値が含まれない(`caplog`検査) | ケース6を再利用 | ログ本文に生トークン文字列が出現しない |

### 6.5 `test_health.py`

| # | テストケース |
|---|---|
| 1 | `GET /health`が`200`を返す |
| 2 | レスポンスボディが`{"status": "ok", "service": "homepage-api", "time": "<ISO8601>"}`の形を満たす |
| 3 | `time`フィールドがUTCのISO8601として`datetime.fromisoformat`でパース可能 |

### 6.6 CI連携

`internal-spec-repo-cicd.md` 3.3節の`api-tests.yml`(PR時+main push時の両方)から
`ruff check api/` → `pytest api/tests`の順で実行される想定と整合させる。カバレッジ率の
数値目標は設けない(`internal-spec-repo-cicd.md`の方針通り、MVPでは必須化しない)。
6.3/6.4/6.5節の一覧が「主要エンドポイントの正常系・異常系を最低限カバーする」の具体化
である。

---

## 7. 将来のFAQ管理GUI付録

> **本節は保守サイクル(フェーズ10)での実装対象であり、フェーズ6(実装)のスコープ外
> である。** `internal-spec-datamodel.md`の確定により、FAQ管理GUI(およびそれに伴う
> Neon Postgres導入)は「MVPリリース直後、最初の保守作業として速やかに着手する」
> (M節Q22=A)ことが決まっているが、初回MVPリリース自体には含めない。本節は
> フェーズ10着手時に設計をゼロから起こし直さずに済むよう、現時点で導出可能な設計を
> 先に記録しておくものである。

### 7.1 ルーター構成案(`app/routers/admin.py`)

```python
from fastapi import APIRouter

router = APIRouter(prefix="/api/admin", tags=["admin"])

# MVP時点は空のスタブ。main.py側でも include_router していない(コメントアウト)。
# フェーズ10着手時に以下のルートを実装する:
#   GET  /api/admin/login             ログインフォーム(Jinja2)
#   POST /api/admin/login             認証処理、成功時にJWTをCookieにセット
#   POST /api/admin/logout
#   GET  /api/admin/faqs              FAQ一覧(要認証)
#   GET  /api/admin/faqs/new
#   POST /api/admin/faqs/new
#   GET  /api/admin/faqs/{id}/edit
#   POST /api/admin/faqs/{id}/edit
#   POST /api/admin/faqs/{id}/publish
#   POST /api/admin/faqs/{id}/unpublish
#   POST /api/admin/faqs/{id}/delete
#   GET  /api/admin/accounts          アカウント一覧(要認証、O節Q3=A: GUI内から追加可能)
#   POST /api/admin/accounts/new
#   (パスワードリセットのメール経由フローは実装しない。2026-08-02確定。
#    忘れた場合はClaude CodeがNeonへ直接UPDATEする運用)
```

### 7.2 認証ミドルウェア設計

`internal-spec-datamodel.md` 3.1節・3.5節の確定(bcrypt、JWT・DBセッションテーブルなし、
有効期限1週間、ログイン試行制限、IP制限、CSRF対策)を実装レベルに落とす。

- **パスワードハッシュ:** `bcrypt`ライブラリ(Python)。`gui_accounts.password_hash`
  (60文字)に格納。
- **セッション:** ログイン成功時、`account_id`・`exp`(発行から1週間後)をクレームに持つ
  JWTを`PyJWT`で発行し、`httponly`・`secure`・`samesite=lax`属性付きCookie
  (`admin_session`)にセットする。署名鍵は環境変数`ADMIN_SESSION_SECRET`。
- **認証依存性:**

```python
# 概念設計(フェーズ10で肉付け)
async def get_current_admin(request: Request, db: AsyncSession = Depends(get_db)) -> GuiAccount:
    token = request.cookies.get("admin_session")
    if not token:
        raise HTTPException(status_code=303, headers={"Location": "/api/admin/login"})
    try:
        claims = jwt.decode(token, settings.ADMIN_SESSION_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(status_code=303, headers={"Location": "/api/admin/login"})
    account = await get_account_by_id(db, claims["account_id"])
    if account is None or not account.is_active:
        raise HTTPException(status_code=303, headers={"Location": "/api/admin/login"})
    return account
```

- **ログイン試行回数制限:** `gui_accounts.failed_login_attempts`・`locked_until`
  (`internal-spec-datamodel.md`確定カラム)を用い、規定回数(例: 5回)失敗で一定時間
  (例: 15分)ロックする。具体的な回数・時間はO節Q7で「実装する」ことのみ確定しており
  数値は未確定のため、フェーズ10着手時にユーザーへ確認するか、Wave2の裁量値
  (5回/15分)を仮置きしてよい。
- **IP制限:** `O節Q6=A`により実装必須。環境変数`ALLOWED_ADMIN_IPS`
  (カンマ区切りIP/CIDRリスト)を`/api/admin/*`全体に適用するミドルウェアで判定する。
- **CSRF対策:** FastAPI標準機能は存在しないため、Jinja2フォームにセッション紐付けの
  トークン(`hmac(ADMIN_SESSION_SECRET, session_id + form_name)`)を隠しフィールドで
  埋め込み、POST時に再計算・比較するダブルサブミット方式を採用する(追加ライブラリ
  導入コストを避ける)。
- **パスワードリセット:** **2026-08-02確定(`internal-spec-datamodel.md`追加質問Q1、
  選択肢C):** メールによる自動リセットは実装しない。運営者がパスワードを忘れた場合は
  Claude Codeに依頼し、Neonへ直接SQL(`UPDATE gui_accounts SET password_hash = ...`)を
  発行して更新する運用とする。したがって`auth_service`にメール送信インターフェースは
  不要(`/api/admin/password-reset/*`ルートも7.1節の一覧から削除)。

### 7.3 asyncpg + Neon 接続の実装方針(`app/db/session.py`)

`phase4-clarification.md` N節Q23(A)により非同期(SQLAlchemy 2.0 + `asyncpg`ドライバ)を
採用する。

```python
# 概念設計(フェーズ10で肉付け)
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

engine = create_async_engine(settings.DATABASE_URL, pool_pre_ping=True)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
```

- 接続文字列`DATABASE_URL`はVercel-Neon統合による自動連携を基本とし
  (M節Q17=A/B相当)、Neonの組み込みコネクションプーラー経由のURLを使用する
  (`internal-spec-datamodel.md` 3.4節)。
- 開発/本番はNeonのDBブランチ機能で分離し、Vercelのプレビューデプロイごとに
  Vercel-Neon統合がブランチを自動作成・破棄する(`internal-spec-repo-cicd.md` 4.3節と
  整合)。
- スキーマ変更の管理には、SQLAlchemyと親和性の高い**Alembic**の導入を推奨する
  (Wave1のいずれの文書にも明記はないが、複数アカウント対応・変更履歴テーブルを持つ
  スキーマを将来的に安全に変更していくための標準的な選択であり、「保守性重視」の
  要件に合致するとWave2の裁量で判断する。フェーズ10着手時に採否を最終確認すればよい)。

### 7.4 Jinja2テンプレート構成案(`app/templates/admin/`)

```
templates/admin/
├── base.html              共通レイアウト(ヘッダー・ナビ・フラッシュメッセージ領域)
├── login.html
├── faq_list.html          カテゴリ別・下書き/公開ステータス別の一覧
├── faq_edit.html          新規作成・編集共用フォーム(カテゴリはドロップダウン固定3択、R節Q28=A)
├── accounts_list.html
├── account_new.html
└── (パスワードリセット画面は実装しない、2026-08-02確定)
static/admin/
└── admin.css               実務的な最低限のデザイン(N節Q29=A、見た目より機能性優先)
```

- フォームのCSRFトークンは各`*.html`の`<form>`内に`{{ csrf_token }}`として埋め込む。
- FAQ編集フォームの`category`は固定3択のセレクトボックス(自由入力不可)。

### 7.5 テスト方針(参考)

- ユニットテスト: `auth_service`(bcryptハッシュ照合、ログイン試行カウント、JWT発行・
  検証)、`faq`のCRUDロジックを、公開APIとは別の`tests/admin/`配下に用意する。
- E2Eテスト: Q節Q18(A)の確定により、GUI用のPlaywrightテストは公開サイト向けスイートとは
  **別スイート**にする(認証情報を扱うテストのため)。テスト専用のNeon DBブランチに
  固定テストアカウントを用意する(Q節Q19=A)。

---

## 8. 環境変数一覧(Vercel側、`INTEGRATION_HMAC_SECRET`表記に統一。0.2節参照)

| 変数名 | MVP必須 | Production | Preview | 用途 |
|---|---|---|---|---|
| `RECAPTCHA_SECRET_KEY` | 必須 | 本番reCAPTCHAシークレット | テスト用またはProductionと共用 | Google siteverify呼び出し |
| `INTEGRATION_HMAC_SECRET` | 必須 | Cyberhome側非公開ファイルと同一値 | ダミー値可(Preview→本番Cyberhomeへの実接続は発生しない) | HMACトークンの署名 |
| `ALLOWED_ORIGIN` | 必須(デフォルト値あり) | `https://jyoho1.web.cyberhome.ne.jp` | 同上、または手動テスト用オリジンに一時的に上書き可 | CORS許可オリジン |
| `VERCEL_ENV` | Vercelが自動設定 | `production` | `preview` | `/docs`公開可否・ログレベル等の環境判定 |
| `DATABASE_URL`(将来) | GUI導入時に必須 | 本番Neonブランチ接続文字列 | Vercel-Neon統合による自動生成プレビューブランチ | FAQ管理GUI用DB接続 |
| `ADMIN_SESSION_SECRET`(将来) | GUI導入時に必須 | 本番用ランダム値 | Preview用ランダム値(別値) | GUIセッション(JWT)署名鍵 |
| `ALLOWED_ADMIN_IPS`(将来) | GUI導入時に必須 | 運営者の実IP/CIDR | 同上、またはテスト用に緩和 | GUI用IP制限 |
| `SMOKE_TEST_SECRET`(2026-08-02追加、9章参照) | 必須(Production・Playwrightスモークテスト用) | GitHub Secretsと同一のランダム値 | Preview不要(日次スモークは本番のみ対象) | CI専用reCAPTCHAテストキー分岐の判別 |
| `RECAPTCHA_TEST_SECRET_KEY`(2026-08-02追加、9章参照) | 必須(Production) | Googleの公式テストシークレットキー固定値 | 不要 | `SMOKE_TEST_SECRET`一致時のみGoogle siteverify呼び出しに使用 |

`.env.example`(`api/.env.example`)にはMVP必須の4変数(`RECAPTCHA_SECRET_KEY`,
`INTEGRATION_HMAC_SECRET`, `ALLOWED_ORIGIN`, `VERCEL_ENV`)をダミー値付きで記載する
(実値はコミットしない)。

---

## 9. reCAPTCHA CI検証バイパス(2026-08-02追加、`internal-spec-testing.md`追加質問Q1=B′の実装)

`internal-spec-testing.md`が設計する日次Playwrightスモークテストで、`contact.cgi`の
**正常系送信**(実メール送信・`contact_log.txt`への記録を伴う)まで自動化することが
確定した(B′案)。Google reCAPTCHAは自動化された(人間が操作しない)チェックボックス
操作を通常のフローでは通過できないため、Google公式の「常に成功を返すテスト用
シークレットキー」(`6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe`、Google公式ドキュメント
記載の固定値)を使う。ただし本番トラフィック全体をテストキー扱いにするとreCAPTCHAの
実効性が失われるため、**CIからの呼び出しであることを検証した場合にのみ**テスト
シークレットキーへ切り替える、Vercel側のみの小さな分岐を追加する。`contact.cgi`は
一切変更しない(HMACトークンの検証ロジックは通常の送信と完全に同一)。

### 9.1 `recaptcha_service.py`への追加ロジック

```python
def _resolve_secret_key(request_headers: dict, settings: Settings) -> str:
    smoke_test_secret = request_headers.get("x-smoke-test-auth")
    if smoke_test_secret and settings.SMOKE_TEST_SECRET and \
       hmac.compare_digest(smoke_test_secret, settings.SMOKE_TEST_SECRET):
        return settings.RECAPTCHA_TEST_SECRET_KEY  # Google公式テストシークレットキー
    return settings.RECAPTCHA_SECRET_KEY  # 本番シークレットキー(通常のユーザー送信)
```

- `verify_recaptcha()`(3.3節)は`settings.RECAPTCHA_SECRET_KEY`を直接参照するのではなく、
  上記`_resolve_secret_key(request.headers, settings)`の戻り値を使うよう変更する。
- `X-Smoke-Test-Auth`ヘッダーは通常のブラウザからのリクエストには決して付与されない
  (`site/js/contact-form.js`は付与しない)。GitHub Actionsの`playwright-smoke.yml`
  のみが`SMOKE_TEST_SECRET`(GitHub Secrets)の値をこのヘッダーに設定して呼び出す。
- `hmac.compare_digest`によるタイミング攻撃対策済みの比較を用いる(この値は実質的な
  認証情報のため、`==`比較は避ける)。
- Google公式テストキーは`recaptcha_response`の値を一切検証しないため、Playwright側は
  ダミー文字列(例: `"smoke-test-bypass"`)を送るだけでよく、実際のウィジェット操作は
  不要。
- テストキーの利用によって発行されたHMACトークンは、通常の送信と全く同じ形式・
  有効期限であり、`contact.cgi`側からは「reCAPTCHAを実際に解いた本物の送信」と
  区別がつかない(区別する必要もない — HMACトークンが有効であることが唯一の
  検証対象であるという既存の連携契約通り)。

### 9.2 秘密情報

| 変数名 | 保持場所 | 用途 |
|---|---|---|
| `SMOKE_TEST_SECRET` | Vercel環境変数(Production)+ GitHub Secrets(`playwright-smoke.yml`から`X-Smoke-Test-Auth`ヘッダーとして送信) | CI呼び出しの判別 |
| `RECAPTCHA_TEST_SECRET_KEY` | Vercel環境変数(Production) | Google公式テストシークレットキー(値そのものは非秘密の公開情報だが、環境変数化してコード直書きを避ける) |

`internal-spec-testing.md`側の実装詳細(Playwrightからのヘッダー付与、テスト専用の
To/Fromメールアドレスの要否)は同ドキュメントを参照。

---

## 追加質問

なし。本書のスコープ(FastAPIアプリ構成・`/api/faq`・`/api/verify-recaptcha`・`/health`の
実装設計、レート制限、pytest設計、FAQ管理GUI付録)において、`architecture.md`・
`phase4-clarification.md`(全280問)・Wave1の3ドキュメントから明確に導出できない
genuinely未決定な事項はなかった。0章で扱った3件の表記差異(`/health`のルーティング、
HMAC環境変数名、FAQファイル形式とAPI応答形式の関係)は、いずれも既存確定事項から
一意に解決できる実装解釈の問題であり、ユーザーへの追加確認は不要と判断した。

参考として、本書の設計が依存する既存の未解決事項(本書のブロッカーではないが、
フェーズ6実装着手までに解消が必要)を再掲する:
- `architecture.md`「追加質問6」: reCAPTCHAのサイトキー・シークレットキーの実際の登録
  状況(本書はキーの値そのものには依存しない設計だが、Phase 6実装着手までに登録が必要)。

**2026-08-02追記:** `internal-spec-datamodel.md`旧追加質問Q1(パスワードリセット
メール送信経路)はユーザー回答により決着済み(7.2節参照)。9章にてQ4(B′案、
reCAPTCHA CI検証バイパス)の実装設計を追加した。

# 内部仕様(フェーズ4 Wave1): リポジトリ構成・CI/CD基盤設計

## 位置づけ

本ドキュメントは、フェーズ4(内部仕様調査)を6分割したサブエージェントのうち
「リポジトリ構成・CI/CD基盤設計」担当分の成果物である。Wave1で並列実行される他の
2エージェント(担当領域: 恐らく「Cyberhome側CGI詳細設計」「Vercel/DB詳細設計」等)の
成果物と合わせて、最終的に`docs/specs/internal-spec.md`へ統合されることを想定する。
本ファイル単独では内部仕様の全体像を構成しないため、統合時は本ファイルの内容を
そのまま(またはリライトして)取り込むこと。

参照元(編集はしていない):
- `docs/specs/external-spec.md`(承認済み)
- `docs/specs/architecture.md`(ドラフト確定、フェーズ4引き継ぎ準備完了)
- `docs/specs/phase4-clarification.md`(全280問回答済み)
- `docs/specs/README.md`
- `docs/PROJECT_STATUS.md`
- 現リポジトリの実ファイル(`index.html`, `css/`, `js/`, `api/send-email.js`,
  `vercel.json`, `.gitignore`, `public/`, `scripts/`)

## 0. 踏まえた確定済み前提

- モノレポ内で`/site`(Cyberhome用)・`/api`(Vercel用)に分割する
  (`architecture.md`「リポジトリ構成の決定」)。
- `.gitattributes`でCGI/Perlファイル(`*.cgi`,`*.pl`,`*.pm`)の改行コードをLFに強制する
  (`phase4-clarification.md` ラウンド4/5 T9)。
- コミットメッセージは英語で統一(T12)。GitHubリポジトリはPrivateを維持(T14)。
- CyberhomeへのデプロイはGitHub Actions(FTPS Explicit)を基本とし、失敗が多発する場合は
  手動FTPにフォールバック(ラウンド1 G41、`architecture.md`決定事項8)。デプロイトリガーは
  push時自動+手動トリガーの両方(ラウンド2 G43=C)。デプロイ前に本番ディレクトリを
  バックアップ(直近5世代保持、手動で確認して削除。ラウンド2 E32/E33=B/A)。
- VercelはGitHub連携の自動デプロイを継続。Vercelの「Root Directory」設定を`/api`に変更する
  (`.vercelignore`との二重対応、ラウンド2 G44=B)。
- Pythonの依存管理は`requirements.txt`(インフラ深掘り1/5 Q21=A)。
- Vercelのプレビューデプロイは有効にする(インフラ深掘り3/5 Q16=A)。Neon DBブランチと
  連携させる(自動作成・破棄、Q17=A)。
- 環境変数はProduction/Previewで異なる値を設定する(Q21=A)。
- ワークフローファイル(`.github/workflows/*.yml`)の変更はPR経由必須(ブランチ保護
  ルール)。今後の開発フローはfeatureブランチ+PRベースに移行する(ラウンド2 G45=B,
  G47=B)。
- FTPSアップロードは汎用GitHub Action(ラウンド1 G41=A)。`/site`配下の除外は明示的な
  除外リストファイル方式(G42=A)。シークレット命名は用途明示の大文字スネークケース
  (G44=A)。Playwrightスモークテスト失敗はワークフロー失敗扱い(G45=A)。
- Playwrightスモークテストはデプロイ後自動実行+毎日1回の定期実行の両方
  (ラウンド1 G34=C、ラウンド2 E33=A)。
- api-tests.ymlはPR時とmainへのマージ後の両方で実行(ラウンド2 G35=C)。
- デプロイ失敗時はGitHub Issue自動作成に任せる(追加のメール実装は不要、ラウンド2 E31=B)。
- Pythonバージョンは明示的に固定せずVercelのデフォルトに任せる(ラウンド4 U46=A)。
- `docs/specs`の更新は実装コミットと別コミットにする(ラウンド4 T13=A)。
- Perl CGIはCGI本体とビジネスロジックを`.pm`モジュールに分離し、ロジック部分は
  `Test::More`でユニットテスト可能にする(ラウンド4 S1=A, S2=A)。
- ダウンロードファイルのサイズ上限は設けない(容量全体で管理、ラウンド3 R29=B)。

---

## 1. モノレポのディレクトリ構成

### 1.1 リポジトリ全体(トップレベル)

```
/
├── .github/
│   └── workflows/
│       ├── deploy-cyberhome.yml
│       ├── playwright-smoke.yml
│       └── api-tests.yml
├── .gitattributes                 ← 新規(本ドキュメントで設計、下記2章)
├── .gitignore                     ← 既存を流用、追加項目は下記1.5
├── docs/
│   ├── PROJECT_STATUS.md
│   └── specs/
│       ├── README.md
│       ├── external-spec.md
│       ├── architecture.md
│       ├── phase4-clarification.md
│       └── internal-spec*.md
├── site/                          ← Cyberhomeへデプロイ(詳細1.2)
└── api/                           ← Vercelへデプロイ(詳細1.3、Root Directory設定もここ)
```

リポジトリ直下に置いていた`index.html`・`css/`・`js/`・`public/`・`vercel.json`
(旧・静的サイト全体をVercelでホストする設定)、`api/send-email.js`、Node.js関連の
`package-lock.json`・`node_modules/`・`scripts/dev-server.js`は、フェーズ6実装着手時に
以下の方針で整理する(実際のファイル移動・削除自体はフェーズ6の作業だが、移行方針は
本フェーズで確定させておく):

| 現状の資産 | 移行方針 |
|---|---|
| `index.html` / `css/` / `js/` | 内容を精査の上`/site`配下へ移設(そのまま流用できる部分は流用、Cyberhome向けにアセットパスを見直す) |
| `public/robots.txt` / `public/sitemap.xml` | `/site/robots.txt` / `/site/sitemap.xml` へ移設(Cyberhome配信ルートに置く必要があるため) |
| `api/send-email.js` | 削除(`architecture.md`決定事項2、Node実装は全面廃棄確定) |
| `vercel.json`(現行、静的サイト全体をビルド対象にする設定) | 全面書き換え、`/api`直下へ移設(下記4章) |
| `package-lock.json` / `node_modules/` / `scripts/dev-server.js` | 削除(静的サイトはCyberhome配信になりNode製devサーバーは不要、ローカル開発環境を持たない方針(`architecture.md`決定事項9)とも整合) |
| `.env.example` / `.env.local` | Vercel(`/api`)用の環境変数サンプルへ作り直す(下記7章) |

### 1.2 `/site`(Cyberhomeへデプロイ、`public_html`直下に1:1で対応)

```
site/
├── index.html
├── news.html                    静的な記事一覧の入口ページ(news.cgiへ委譲、またはnews.cgi自体を/news.cgiとして公開)
├── contact.html                 問い合わせフォームページ(reCAPTCHA v2ウィジェット埋め込み)
├── contact-thanks.html          送信完了ページ(contact.cgiからの302リダイレクト先、ラウンド2 B12=C=PRGパターン)
├── privacy.html                 プライバシーポリシー(新規作成、external-spec.md要件)
├── robots.txt
├── sitemap.xml
├── css/
│   ├── reset.css
│   ├── responsive.css
│   └── style.css
├── js/
│   ├── main.js
│   ├── utils.js
│   ├── chat-widget.js           FAQ/チャットウィジェット。Vercel `/api/faq` を呼び出す
│   └── contact-form.js          フォームのJS即時バリデーション + reCAPTCHA検証(`/api/verify-recaptcha`)呼び出し
├── news/                        news.cgi が読む記事テキストファイル群
│   └── 20260801_お知らせ.txt    命名規則: YYYYMMDD_タイトル.txt(ラウンド2 N9=A)
├── templates/                   news.cgi が文字列置換で挿入する共通HTML断片
│   ├── header.html
│   └── footer.html
├── cgi-bin/
│   ├── news.cgi                 記事一覧・詳細生成(コアPerlのみ)
│   ├── contact.cgi              問い合わせ受付・バリデーション・sendmail送信・テキストログ記録
│   ├── download.cgi             認可済みダウンロード配信・アクセスログ記録
│   └── lib/                     CGI本体とロジックを分離(ラウンド4 S2=A、ユニットテスト対象)
│       ├── Common.pm            共通ユーティリティ(HTMLエスケープ、ログ出力、テンプレート挿入)
│       ├── ContactLogic.pm      バリデーション、二重送信判定、HMAC検証、メールヘッダー生成
│       ├── DownloadLogic.pm     MIMEタイプ判定(拡張子ハードコード対応表、ラウンド2 A2=A)、ログ整形
│       └── NewsLogic.pm         記事ファイル走査・ソート・整形
├── conf/                        非公開設定(`.htaccess`でWeb直接アクセス拒否、下記1.5参照)
│   ├── hmac_secret.example.txt  ダミー値のみコミット
│   └── (hmac_secret.txt は実行時にFTPで配置、Git管理外)
├── dl/                          ダウンロード用ディレクトリ(Basic認証)
│   ├── .htaccess
│   └── .htpasswd.example        ダミー値のみコミット(実ファイルはGit管理外)
├── qr/                          QRコード遷移先ページ(Basic認証、静的HTML、ラウンド2 D23=A)
│   ├── .htaccess
│   ├── .htpasswd.example
│   ├── book1.html
│   └── book2.html
└── Contents/                    ダウンロード対象の実体ファイル(下記「追加質問Q2」参照)
    ├── book1/
    │   └── (PDF等、半角英数字ファイル名)
    └── book2/
        └── (Excel等、半角英数字ファイル名)
```

**補足:**
- `access_log.txt`・`contact_log.txt`・`contact_error_log.txt`(ラウンド2 B9=A、失敗ログも
  記録する)は`dl/`・`cgi-bin/`配下にCGI実行時に生成される。Git管理対象外(下記1.5)。
- `.htpasswd`実ファイルは年次更新のたびに運営者がFTPクライアントで直接アップロードする
  運用(`architecture.md`確定)。リポジトリには`.example`のみ置く。

### 1.3 `/api`(Vercelへデプロイ、Root Directory設定をここに変更)

Vercel Python(FastAPI)は「単一のエントリポイントに`app`を置き、全パスをそこへ
routesで流し込む」構成にする(FastAPI自身のルーターで`/faq`・`/verify-recaptcha`・
`/admin/*`・`/health`を振り分ける、Q20=A 単一Vercelプロジェクトにまとめる決定に対応)。

```
api/
├── vercel.json                  Root Directory=/api 前提の設定(下記4章)
├── .vercelignore                下記4章
├── requirements.txt             本番依存(fastapi, uvicorn, pydantic v2, python-multipart 等)
├── requirements-dev.txt         開発/CI依存(pytest, httpx, ruff)
├── .env.example
├── index.py                     Vercelのエントリポイント。app/main.py の FastAPI インスタンスをそのままexport
└── app/
    ├── __init__.py
    ├── main.py                  FastAPI() 生成、ルーター登録、CORS設定(許可オリジン: https://jyoho1.web.cyberhome.ne.jp)
    ├── routers/
    │   ├── faq.py                GET /api/faq (静的JSON、将来Neon切替時はfaq_service経由に差し替え)
    │   ├── recaptcha.py          POST /api/verify-recaptcha (Google siteverify代行 + HMAC署名トークン発行)
    │   ├── admin.py              FAQ管理GUI(認証必須、Neon導入と同時に実装、MVP時点は未実装スタブ)
    │   └── health.py             GET /api/health (死活確認用、インフラ深掘り2/5 N35=Bで準備のみ)
    ├── models/
    │   ├── faq.py                Pydanticスキーマ(FaqItem, FaqCategory等)
    │   └── recaptcha.py          Pydanticスキーマ(RecaptchaVerifyRequest/Response)
    ├── services/
    │   ├── faq_service.py        MVP: data/faq.json 読み込み。将来: Neon(SQLAlchemy非同期)実装に置換
    │   ├── recaptcha_service.py  Google siteverify呼び出し + HMAC-SHA256トークン発行
    │   └── auth_service.py       GUI認証(bcrypt、セッション/JWT)。Neon導入と同時に実装
    ├── data/
    │   └── faq.json               MVP時点の静的FAQデータ(空配列から開始、external-spec.md仕様通り)
    ├── db/
    │   ├── __init__.py
    │   └── session.py             将来のNeon接続設定(SQLAlchemy非同期セッション)。MVP時点はプレースホルダ
    ├── templates/                 GUI用Jinja2テンプレート(インフラ深掘り2/5 N14=A)。Neon導入と同時に実装
    │   └── admin/
    └── static/                    GUI用CSS等。Neon導入と同時に実装
└── tests/
    ├── conftest.py
    ├── test_faq.py
    ├── test_recaptcha.py
    └── test_health.py
```

MVPリリース時点では`db/`・`templates/`・`static/`・`routers/admin.py`は雛形(スタブ)の
みを置き、実装はFAQ管理Web GUI着手(保守サイクル最優先タスク)のタイミングで行う。
ディレクトリ自体は今のうちに用意しておくことで、後続の保守作業がフェーズ1〜5の
差し戻しなしで`p10-maintainer`により追加できる(`README.md`ゲートルール改訂と整合)。

### 1.4 直下に置く共通ファイル

- `.gitattributes`(2章)はリポジトリ直下1箇所のみ(`/site`・`/api`両方に効かせるため)。
- `.github/workflows/*.yml`はリポジトリ直下(GitHub Actionsの仕様上、ここ以外に置けない)。
- `docs/`はリポジトリ直下のまま変更なし。

### 1.5 `.gitignore` 追加項目(設計、実ファイルは編集対象外)

現行`.gitignore`に加えて、以下をフェーズ6着手時に追記する(ラウンド4 T11=A、
フェーズ4またはフェーズ6で一括整備の方針に基づき、内容をここで確定しておく):

```
# Cyberhome側の非公開設定・実パスワード・生成ログ(Git管理外)
site/dl/.htpasswd
site/qr/.htpasswd
site/conf/hmac_secret.txt
site/**/access_log.txt
site/**/contact_log.txt
site/**/contact_error_log.txt

# Vercel/Python
api/.env
api/.env.local
api/__pycache__/
api/**/__pycache__/
api/*.pyc
api/.pytest_cache/
```

(ルート直下の`node_modules/`・`__pycache__/`等の既存記述は、1.1のNode資産削除に伴い
不要になるが、削除自体は実害がないため残置しても害はない。整理はフェーズ6の判断に
委ねる。)

---

## 2. `.gitattributes`

```gitattributes
# デフォルト: テキストファイルは常にLFで正規化(チェックアウト時もLFのまま)
* text=auto eol=lf

# Cyberhome側CGI/Perlファイルは改行コードLFを強制(Cyberhomeの仕様上CRLFはCGIとして
# 動作しない可能性が高いため、リポジトリ内・FTPS転送前の時点で必ずLFに統一する)
*.cgi text eol=lf
*.pl  text eol=lf
*.pm  text eol=lf

# .htaccess もApache設定ファイルとしてLF統一(Cyberhome同様の理由)
.htaccess text eol=lf

# Python/JSON/YAML/Markdown等の一般的なテキストファイルは通常のLF正規化のみ
*.py   text eol=lf
*.json text eol=lf
*.md   text eol=lf
*.html text eol=lf
*.css  text eol=lf
*.js   text eol=lf
*.txt  text eol=lf

# バイナリファイルは改行変換対象外であることを明示(ダウンロード特典ファイル等)
*.pdf  binary
*.xls  binary
*.xlsx binary
*.doc  binary
*.docx binary
*.ppt  binary
*.pptx binary
*.png  binary
*.jpg  binary
*.jpeg binary
*.gif  binary
*.ico  binary
```

補足: `text=auto eol=lf`をデフォルトにしているため、上記の個別`*.cgi`等の指定は
「保険」的な明示であり、実質的には全テキストファイルがLFで統一される。CGI/Perlの
挙動に直結する`*.cgi`/`*.pl`/`*.pm`/`.htaccess`は誤って将来デフォルト設定が変わっても
影響を受けないよう個別に明示しておく。

---

## 3. GitHub Actions ワークフロー設計

3ファイル構成とする(`deploy-cyberhome.yml`・`api-tests.yml`はarchitecture.mdの
命名に準拠。Playwrightスモークテストはデプロイ後実行に加え独立した毎日1回の
定期実行が必要(ラウンド1 G34=C、ラウンド2 E33=A)なため、`playwright-smoke.yml`を
別ファイルとして追加する。これは本エージェントの裁量による構成上の判断であり、
architecture.mdの2ファイル案と矛盾しない拡張)。

### 3.1 `deploy-cyberhome.yml`

**トリガー(ラウンド2 G43=C):**
```yaml
on:
  push:
    branches: [main]
    paths: ["site/**"]
  workflow_dispatch: {}
```

**ジョブ構成:**

1. **`backup`**(常に実行、デプロイ前に必須)
   - `checkout`
   - Cyberhome側の現行`/public_html`をFTPS経由でミラーダウンロード
     (`lftp mirror`を想定。詳細は「追加質問Q1」参照)
   - ダウンロードした内容を`tar.gz`に圧縮し、`actions/upload-artifact`で
     `cyberhome-backup-<実行日時>-<run_number>`という名前でアップロード
     (デフォルト保持: GitHub既定の90日。5世代を超えた古いものは運営者が
     Actionsのアーティファクト画面で手動確認・削除、ラウンド2 E32=B)

2. **`deploy`**(`needs: backup`)
   - `checkout`
   - `.gitattributes`によりLF化済みの`site/`配下を、汎用FTP-Deploy系Action
     (例: `SamKirkland/FTP-Deploy-Action`。ラウンド1 G41=A「汎用のFTP-Deploy系
     GitHub Action」の決定に基づき採用)でFTPS(Explicit)アップロードする
     - `server` / `username` / `password`: GitHub Secretsから注入(7章参照)
     - `protocol: ftps`(Explicit)
     - `local-dir: site/`
     - `server-dir: /public_html/`
     - `exclude`: `site/.ftpdeployignore`に列挙した明示的除外リストを参照
       (ラウンド1 G42=A、開発用メモ等をデプロイ対象から除外する仕組み)
   - デプロイ完了後、GitHub Actionsのサマリーにデプロイ日時・コミットSHAを出力

3. **`smoke-test`**(`needs: deploy`)
   - `playwright-smoke.yml`の再利用可能ワークフロー(`workflow_call`)を呼び出す形で
     デプロイ直後のスモークテストを実行(3.2参照)。失敗時はワークフロー自体を
     失敗扱いにする(ラウンド1 G45=A)。

4. **失敗時通知**(ワークフロー全体、`if: failure()`のジョブとして追加)
   - `deploy`または`smoke-test`が失敗した場合、GitHub Issueを自動作成する
     (`actions/github-script`または`peter-evans/create-issue-from-file`等を利用、
     ラウンド2 E31=B。GitHubのIssue通知メール機能を利用するため追加のメール送信
     実装は不要)。Issueには失敗したジョブ・run URL・対象コミットを記載し、
     運営者(リポジトリオーナー)へアサインする。

### 3.2 `playwright-smoke.yml`

**トリガー:**
```yaml
on:
  schedule:
    - cron: "0 0 * * *"   # 毎日1回(UTC 0:00 = JST 9:00、営業開始前を想定)
  workflow_call: {}         # deploy-cyberhome.yml からの呼び出し用
  workflow_dispatch: {}      # 手動実行用
```

**ジョブ構成:**

1. **`smoke`**
   - `checkout`
   - Node.js + Playwrightセットアップ、ブラウザインストール
   - 本番URL(`https://jyoho1.web.cyberhome.ne.jp/`、GitHub Secretsまたはvarsで
     `SITE_BASE_URL`として注入)に対して以下を検証:
     - トップページ200応答・主要セクション表示
     - 問い合わせフォームページの表示・reCAPTCHAウィジェット表示
     - FAQ/チャットウィジェットの表示(Vercel API疎通含む)
     - `qr/`配下ページへのアクセス時にBasic認証プロンプトが要求されること
       (実際のID/パスワードは使わず、401応答であることの確認に留める
       破壊的でない検証、`architecture.md`のテスト方針と整合)
   - テストレポート(HTML)を`actions/upload-artifact`で保存
   - 失敗時は`exit 1`でジョブ失敗、呼び出し元(`deploy-cyberhome.yml`)にも
     失敗が伝播する(`workflow_call`の性質上)

### 3.3 `api-tests.yml`

**トリガー(ラウンド2 G35=C、両方):**
```yaml
on:
  pull_request:
    paths: ["api/**"]
  push:
    branches: [main]
    paths: ["api/**"]
```

**ジョブ構成:**

1. **`test`**
   - `checkout`
   - `actions/setup-python`(バージョンはVercelの現行デフォルトに追従、明示固定
     しない方針。CI実行時点のPython 3.x安定版を使用)
   - `pip install -r api/requirements.txt -r api/requirements-dev.txt`
   - `ruff check api/`(静的解析、インフラ深掘り1/5 Q22=Aで確定済みのruffを採用)
   - `pytest api/tests`(FAQ取得API・reCAPTCHA検証ロジックのモックテスト)
   - カバレッジレポート出力(将来の閾値設定は保守サイクルで検討、MVPでは必須化しない)

**ブランチ保護との関係:** このジョブの成功を`main`へのPRマージ条件(必須ステータス
チェック)として設定する(6章参照)。Vercel自体のデプロイは、Vercelの GitHub 連携
(push時自動デプロイ)がこのワークフローの成否とは独立して動作する点に注意する。
mainへのマージ(=push)が本ワークフロー通過後にしか起きないよう、PRベース運用と
組み合わせることで、実質的に「テスト未通過のコードがVercel本番へデプロイされる」
リスクを下げる。

---

## 4. Vercel設定(`vercel.json` / `.vercelignore` / Root Directory)

Root Directory設定を`/api`に変更するため(ラウンド2 G44=B)、`vercel.json`・
`.vercelignore`は**`/api`直下**に配置する(リポジトリ直下ではない点に注意。
Vercelはプロジェクトの「Root Directory」を基準にこれらのファイルを探索するため)。

### 4.1 `api/vercel.json`

```json
{
  "version": 2,
  "builds": [
    {
      "src": "index.py",
      "use": "@vercel/python"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "index.py"
    }
  ],
  "github": {
    "enabled": true,
    "autoAlias": false
  }
}
```

- 全パスを`index.py`(FastAPIアプリのエントリポイント)へ集約し、ルーティング自体は
  FastAPI側の`APIRouter`で行う(単一Vercelプロジェクトにまとめる決定、インフラ深掘り
  3/5 Q20=A)。
- 環境変数(reCAPTCHAシークレット、HMAC共有シークレット、Neon接続文字列等)は
  `vercel.json`の`env`フィールドには書かず、Vercelダッシュボードの環境変数機能で
  Production/Preview別に設定する(Q21=A、秘密情報を設定ファイルに残さないため)。
- `github.enabled: true`により、GitHub連携のpush時自動デプロイ・プレビューデプロイ
  (PRごと)を維持する(インフラ深掘り3/5 Q16=A)。

### 4.2 `api/.vercelignore`

Root Directory変更により`/site`はそもそもVercelのビルドコンテキストから見えなくなる
(二重対応の1つ目)。`.vercelignore`は`/api`配下でVercel本番ビルドに含める必要のない
ファイルを除外する、二重対応の2つ目として機能する:

```
tests/
.pytest_cache/
__pycache__/
**/__pycache__/
*.pyc
.env
.env.local
requirements-dev.txt
```

(`data/faq.json`は本番実行時にAPIが読み込む実データのため除外しない。)

### 4.3 Vercelダッシュボード側の設定変更(運営者作業、コード変更外)

以下はVercelダッシュボード上の操作であり、コードでは表現できないため、フェーズ6
着手時に運営者またはClaude Codeが以下の手順で実施することを明記しておく:

1. Vercelプロジェクトの Settings → General → Root Directory を `api` に変更。
2. Settings → Git → Preview Deployments を有効化(既に有効な場合は変更不要)。
3. Settings → Environment Variables で、reCAPTCHAシークレット・HMAC共有シークレット・
   (導入後は)Neon接続文字列を Production / Preview それぞれに設定
   (同一値を使い回すか環境ごとに変える値かは各シークレットの性質に応じて判断。
   HMAC共有シークレットはCyberhome側と一致している必要があるため、実質的に
   Production環境の値のみが実運用で使われる。Preview環境向けの値は疎通確認用の
   ダミー値で構わない)。
4. Storage → Neon連携(導入時)で Preview環境ごとのDBブランチ自動作成・破棄を有効化
   (インフラ深掘り3/5 Q17=A)。

---

## 5. バックアップ・ロールバック手順

### 5.1 バックアップ(自動・デプロイ前必須)

| 項目 | 内容 |
|---|---|
| **誰が** | GitHub Actions(`deploy-cyberhome.yml`の`backup`ジョブ)が自動実行。人手は不要 |
| **いつ** | `site/**`への`push`時、および手動`workflow_dispatch`実行時のいずれも、`deploy`ジョブの直前に必ず実行(スキップ不可、常に安全側に倒す) |
| **何を** | FTPS経由でCyberhomeの現行`/public_html`全体をミラーダウンロードし、`tar.gz`化したもの |
| **どこに** | GitHub Actionsのワークフロー実行アーティファクト(`cyberhome-backup-<YYYYMMDDHHMMSS>-<run_number>`という命名) |
| **保持期間** | GitHub既定(90日)。5世代を超えた古いものは運営者がActionsの「Artifacts」画面を見て手動で削除する(ラウンド2 E32=B、自動プルーニングは実装しない) |

### 5.2 ロールバック(手動判断・実行)

| 項目 | 内容 |
|---|---|
| **誰が** | 運営者(またはClaude Codeが運営者の指示を受けて代行) |
| **いつ** | `smoke-test`ジョブが失敗した場合、またはデプロイ後に運営者が本番サイトの不具合に
気づいた場合(自動ロールバックは行わない、ラウンド1 G45=Aの「通知して運営者判断を
仰ぐ」方針を踏襲) |
| **どのアーティファクト** | 直近の正常動作が確認できていた回のバックアップ
アーティファクト(GitHub Actionsの実行履歴から選択) |
| **手順** | ① 対象のワークフロー実行ページからアーティファクト(`tar.gz`)をダウンロード<br>② ローカルで展開<br>③ FTPSクライアント(FFFTPやCyberdriveFTP等、運営者が通常使うツール)で`/public_html`へ手動で再アップロードする(**基本方針:GitHub Actions自動化、失敗多発・緊急時は手動FTPフォールバック**という`architecture.md`の原則をロールバックにも適用) |
| **記録** | ロールバック実施日時・理由・使用したアーティファクトを`docs/PROJECT_STATUS.md`に記録する(保守運用の継続的な記録方針、ラウンド5 Z20=A) |

自動化されたワンクリック・ロールバック用ワークフロー(`workflow_dispatch`でアーティ
ファクトIDを指定し自動的にFTPS再アップロードするジョブ)は、MVPでは実装しない
(手動FTPで十分低頻度な想定、実装コストと保守コストの見合いから見送り)。保守サイクル
で実際にロールバックの発生頻度が高いと分かった場合、`p10-maintainer`側で追加を検討する。

### 5.3 Vercel側のロールバック

Vercel側はVercel自体の標準機能(ダッシュボードから過去のデプロイメントへ
「Promote to Production」)で即座にロールバック可能なため、本ドキュメントでは
Cyberhome側のみを設計対象とする(Vercel標準機能で十分、追加実装不要)。

---

## 6. ブランチ保護ルール・PRベース開発フローへの移行手順

### 6.1 現状

これまでの本セッションの開発は`main`ブランチへの直接コミット・pushで進めてきた
(直近のコミット履歴が示す通り)。ラウンド2 G45=B・G47=Bにより、今後はfeature
ブランチ+PRベースの開発フローへ移行することが確定している。

### 6.2 移行手順

1. ローカルの`main`と`origin/main`の差分を解消する(未pushコミットがあれば
   push、または整理する)。作業ツリーがクリーンな状態から移行を開始する。
2. GitHubリポジトリの Settings → Branches → Branch protection rules で
   `main`に対するルールを新規作成する:
   - 「Require a pull request before merging」を有効化(直接pushを禁止)。
     - Require approvals: **0**(運営者1名のみの運用のため、セルフ承認ができない
       GitHub標準の制約と矛盾しないよう、承認必須数は設けない。PR経由での
       マージという形式自体を強制することが主目的)。
   - 「Require status checks to pass before merging」を有効化し、以下を必須
     ステータスチェックとして指定する:
     - `api-tests / test`(`/api`配下の変更を含むPRの場合。`/site`のみの変更PRでは
       このジョブ自体が`paths`フィルタで起動しないため、GitHub上「必須チェックが
       永遠に現れず保留になる」問題を避けるべく、`api-tests.yml`は`paths`フィルタを
       トリガー条件に残しつつ、ブランチ保護の必須チェックには**含めない**運用とする。
       `/site`変更PRの品質担保はレビュー+デプロイ後Playwrightスモークテストで代替する)。
   - 「Do not allow bypassing the above settings」は有効化するが、緊急時に運営者
     本人が一時的に無効化できることを許容する(1名運用のプロジェクトのため、
     完全なロックダウンは運用上のリスクになり得る)。
   - `.github/workflows/**`への変更を含むPRについては、上記の「PR必須」ルールが
     そのまま適用されることで「ワークフローファイルの変更はPR経由必須」という
     確定事項(ラウンド2 G45=B)を満たす(GitHubのブランチ保護には「特定パスのみ
     PR必須」という機能は無いため、`main`全体をPR必須にすることでワークフロー
     ファイルも含めて一律に保護する、というのが最も単純で確実な実現方法)。
3. 既存のローカル作業スタイルを、以下のように変更する:
   - 変更ごとに`git checkout -b feature/<短い説明>`でブランチを作成。
   - コミット(英語メッセージ、T12確定)。
   - `gh pr create`でPRを作成し、`api-tests`等のCIが通過したことを確認してから
     `gh pr merge --squash`でマージする(Squash mergeを既定とし、`main`の履歴を
     機能単位でクリーンに保つ。マージ方式自体は明示的な回答がないためここで
     合理的に決定する)。
   - `docs/specs/`の更新は実装コードと別コミットにする(T13=A)。同じPR内で
     複数コミットに分けて構わない(Squash mergeのため`main`上は1コミットに集約
     される)。
4. `.github/workflows/*.yml`を新規追加・変更する際も、上記と同じPRフローに従う
   (専用の追加ルールは設けず、`main`保護ルールの適用範囲内で自然に満たされる)。

---

## 7. GitHub Secrets / 環境変数一覧(CI/CD関連)

命名規則: 用途を明示した大文字スネークケース(ラウンド1 G44=A)。

### 7.1 GitHub Actions Secrets(`deploy-cyberhome.yml`用)

| Secret名 | 用途 |
|---|---|
| `CYBERHOME_FTP_HOST` | CyberhomeのFTPSホスト名 |
| `CYBERHOME_FTP_USER` | FTPSユーザー名 |
| `CYBERHOME_FTP_PASSWORD` | FTPSパスワード |
| `CYBERHOME_FTP_PORT` | FTPSポート(既定21、Explicit FTPS) |
| `CYBERHOME_PUBLIC_HTML_PATH` | サーバー側の配置先パス(`/public_html/`) |

FTPS認証情報の扱いについては、ラウンド1 F40=Bにより「運営者のメインFTPS認証情報を
そのままGitHub Secretsに登録する」ことが確定済み(サブアカウント発行不可の場合の
代替策)。Cyberhomeでデプロイ専用サブアカウントが発行できるか、フェーズ6着手時に
改めて確認できれば、より安全な専用認証情報へ切り替える。

### 7.2 GitHub Actions Variables/Secrets(`playwright-smoke.yml`用)

| 名前 | 種別 | 用途 |
|---|---|---|
| `SITE_BASE_URL` | Variable | `https://jyoho1.web.cyberhome.ne.jp/`(スモークテスト対象URL) |

### 7.3 Vercelダッシュボード環境変数(`/api`用、Production/Preview別に設定)

| 変数名 | Production | Preview | 用途 |
|---|---|---|---|
| `RECAPTCHA_SECRET_KEY` | 本番reCAPTCHAシークレット | テスト用またはProductionと共用 | Google siteverify呼び出し |
| `HMAC_SHARED_SECRET` | Cyberhome側`conf/hmac_secret.txt`と一致する値 | ダミー値可(Preview環境からCyberhome本番CGIへ実接続することはない前提) | reCAPTCHA検証トークンの署名 |
| `DATABASE_URL`(将来、Neon導入時) | 本番Neonブランチ接続文字列 | Vercel-Neon統合による自動生成プレビューブランチ接続文字列 | FAQ管理GUI用DB接続 |
| `ADMIN_SESSION_SECRET`(将来) | 本番用ランダム値 | Preview用ランダム値(別値) | GUIセッション/JWT署名鍵 |

### 7.4 Cyberhome側の非公開設定ファイル(GitHub Secretsではなく`public_html`配下に配置)

| ファイル | 内容 | 管理方法 |
|---|---|---|
| `site/conf/hmac_secret.txt` | reCAPTCHA検証トークンのHMAC共有シークレット(実値) | Git管理外(`.gitignore`)、初回デプロイ時に運営者がFTPで配置。`.example`のみコミット |
| `site/dl/.htpasswd` / `site/qr/.htpasswd` | Basic認証パスワードハッシュ(実値) | Git管理外、年次更新時にFTPで上書き。`.example`のみコミット |

---

## 追加質問

以下2件は、本エージェントの担当範囲内で技術的な裏付けがなく実装方針を左右する
ため、ユーザー確認をお願いしたい(いずれも非ブロッキング、フェーズ4の他Wave並行
作業・フェーズ5レビューを妨げない)。

**Q1. バックアップ取得方式(FTPSでのライブディレクトリのミラーダウンロード)について**

`deploy-cyberhome.yml`の`backup`ジョブは、Cyberhomeの現行`/public_html`をFTPS経由で
ミラーダウンロードする設計にしている。この方式が正しく動くかは、CyberhomeのFTPS
サーバーがディレクトリ一覧取得(LIST/MLSD)に対応しているかに依存し、SSH/シェル
アクセスがないため現時点では実機検証ができていない(`architecture.md`の「追加質問」
に記載の実機確認事項と同種の制約)。どう扱うか?

A) 現状の設計(`lftp mirror`等によるFTPSミラーダウンロード)のまま進め、フェーズ6の
   初回GitHub Actions実行時に動作検証する。失敗した場合はB案に切り替える。
B) より確実な方式として、バックアップは「Git管理下の`site/`の直前コミット時点の
   内容」をtar化するGitベースの方式に変更する(ライブサーバーのFTPS LISTに依存
   しない。ただし`.htpasswd`・`hmac_secret.txt`等Git管理外のファイルはバックアップ
   対象に含まれなくなる制約が生じる)。
C) 自動バックアップの実装自体を見送り、運営者が月次でFTPクライアントを使い手動で
   ローカルにバックアップを保存する運用に変更する(GitHub Actions側でのバックアップ
   実装は行わない)。

**Q2. `Contents/book1/`・`Contents/book2/`配下の実ファイル(ダウンロード特典PDF/Excel等)
のGit管理方針について**

**2026-08-02確定(選択肢A):** Gitで通常のバイナリファイルとしてコミット・バージョン
管理する。`site/Contents/`配下のファイルは`.gitignore`対象にせず、`deploy-cyberhome.yml`
の通常のFTPSデプロイ対象に含める(1.2節の構成通り、特別な除外・LFS設定は不要)。
リポジトリサイズは差し替え頻度が低い(将来の商品追加は手動対応のみ、書籍単位で
数ファイル程度)想定のため、増加を許容する。

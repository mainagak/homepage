# 開発パイプライン ダッシュボード

## 🔴 再開時に最初に読むこと(/clear後はここから)

**現在地:** フェーズ9(最終レビュー・Issue確認)をp9-final-reviewerが実施し、
**「リリース可」判定**(2026-08-02、`docs/specs/final-review.md`参照)を得た。
フェーズ1〜8の全ゲート(承認/合格)が文書・実ファイルの両方で裏取り済みであり、
握りつぶされた未解決事項も見つからなかった。残存課題はすべて運営者本人の
実世界の作業(Vercelデプロイ・reCAPTCHA登録・実GA4測定ID・実ロゴ・Cyberhome
実契約確認・GitHub Secrets登録等)またはPhase 10へ意図的に繰り越す機能
(FAQ管理GUI等)のいずれかであり、エージェント側の追加コード修正を要する
リリースブロッカーはない。**フェーズ10(保守メンテナンス)への移行を承認する。**

**2026-08-02 p9-final-reviewer最終レビュー: リリース可(フェーズ10移行承認)。**
- フェーズ2(外部仕様)・フェーズ5(内部仕様)の「承認」、フェーズ7(システムテスト)・
  フェーズ8(E2Eテスト)の「合格」を文書上・実ファイル上の両方で確認した。
- フェーズ1の未解決事項(DB選定)→フェーズ3解消→FAQ管理GUI用Neon前倒し導入という
  流れ、フェーズ6残タスク一覧(チェックポイント18の10項目)が最後まで一貫して
  引き継がれていることを確認し、握りつぶし・記録漏れがないことを検証した。
- `.github/workflows/*.yml`4本を実際に読み、Windows環境で未実行のPlaywright
  シナリオ5本は実デプロイ+GitHub Secrets/Variables登録後に自動実行される設計に
  なっていることを確認(パイプライン側の未完了ではなく実インフラ待ち)。
- `api/app/main.py`の`admin`ルーターがコメントアウトのまま、DB/認証系の依存が
  `api/requirements.txt`に追加されていないことを確認し、Phase 10スコープ
  (FAQ管理GUI)への未依存を裏付けた。
- リポジトリルート直下の未追跡レガシーファイル群の中身を確認(Vite製の別デザイン、
  実在しそうなGA4測定IDと明らかに未検証な値(設立2028年・example.comメール)が
  同居し出典の信頼性が低い、`site/`・`api/`からの参照なしをgrepで確認)。技術的な
  デプロイ混入リスクはないが、運用上の混乱防止のため運営者への削除確認を推奨。
- QRページ(`qr/book1.html`・`book2.html`)のFAQウィジェット未搭載は、
  「全ページ共通」要件がサイト本体を指すという既存解釈が妥当と再確認し、
  非ブロッキングのまま維持した。
- 詳細・運営者が行うべき作業一覧・Phase 10への繰越項目一覧は
  [final-review.md](final-review.md)、`docs/PROJECT_STATUS.md`チェックポイント25を参照。

**2026-08-02 p8-e2e-tester独立再検証: フェーズ8合格(フェーズ9着手可能)。**
- チェックポイント23の自己申告(修正担当者自身の実ブラウザ確認)を鵜呑みにせず、
  別の視点で新規に書いたPlaywright spec(11ケース)で`contact.html`を再検証。
  旧`SyntaxError`は再現せず、`onRecaptchaSuccess`/`onRecaptchaExpired`が実際に
  呼び出し可能であること、モックAPIによる検証成功で送信ボタンが実際に有効化
  されること、バリデーションエラー時に5フィールド全てが可視入力欄へ復元される
  ことを確認した(旧シナリオ#10・#11は合格に判定変更)。
- GA4トラッキングタグ・ロゴ画像も、全8ページ(`qr/book1.html`・`book2.html`・
  `news.cgi`が組み立てる合成ページを含む)で存在・可視表示を独自に確認した
  (旧シナリオ#5・#3も合格に判定変更)。
- 既存自動テストスイートを実際に再実行し、フェーズ6の自己申告値と一致することを
  確認: Perl 72/72件、pytest 31/31件、Playwright既存スイート3 passed/6
  failed(いずれもこの開発環境固有の既知制約による失敗のみ)/2 skipped。
  FAQ空状態・失敗時UX、HMAC 300秒期限切れUXにも回帰なし。
- 詳細は[e2e-test-report.md](e2e-test-report.md)「再テスト: 2026-08-02」節、
  `docs/PROJECT_STATUS.md`チェックポイント24を参照。

**2026-08-02チェックポイント23(フェーズ6差し戻し対応完了、フェーズ8再実施待ち・履歴):**
- `site/js/chat-widget.js`・`site/js/contact-form.js`をそれぞれIIFEで包み、
  2つのclassic `<script>`タグがグローバルレキシカル環境を共有してしまう構造自体を
  解消した(`VERCEL_API_BASE_URL`重複宣言というリネームで済ませず、根本原因である
  スコープ共有パターンを修正)。`onRecaptchaSuccess`/`onRecaptchaExpired`のみ
  `window`へ明示的に公開(reCAPTCHAウィジェットの`data-callback`要件のため)。
  実際にPlaywright+ローカルHTTPサーバーで、コンソールエラー0件・
  `typeof window.onRecaptchaSuccess === 'function'`・バリデーションエラー時の
  4フィールド復元、を実機確認した。
- GA4トラッキングタグ(プレースホルダー測定ID`G-XXXXXXXXXX`、
  `VERCEL_API_BASE_URL`等と同じTODOパターン)・ロゴ画像アセット
  (`site/images/logo-placeholder.svg`、単一ファイル参照)を、`site/`配下の
  全8ページ+`templates/header.html`に追加した。
- Perl単体テスト72件・pytest31件はいずれも全件成功(回帰なし)。Playwright
  フルスイートは3 passed/6 failed(既知の環境制約による失敗のみ、詳細下記)/
  2 skipped。
- リポジトリのルート直下に未追跡のレガシーファイル群(`index.html`・
  `dist-release/`・`src/`等、Vite製の別デザイン一式、実GA4測定ID
  `G-EG1WMDPTV0`を含むが出典が不確かなため不採用)が存在することを再発見・
  記録した(チェックポイント9・21から既知、本タスクのスコープ外のため対応せず)。
- 詳細は`docs/PROJECT_STATUS.md`チェックポイント23を参照。

**2026-08-02フェーズ8(E2Eテスト)実施・不合格判定(差し戻し済み、上記参照):**

**2026-08-02フェーズ8(E2Eテスト)実施・不合格判定:**
external-spec.md(承認版)の3セクションから受け入れシナリオを作成し、実際に
ブラウザ(Playwright/Chromium)・実際にローカル起動したFastAPI(uvicorn)・
実際に子プロセス実行したPerl CGIを組み合わせて検証した。
- **重大な発見:** `contact.html`が`chat-widget.js`・`contact-form.js`の両方を
  読み込んでおり、両ファイルとも`const VERCEL_API_BASE_URL`をトップレベルで
  重複宣言しているため、実ブラウザで`SyntaxError`が発生し`contact-form.js`が
  一切実行されない。`onRecaptchaSuccess`が未定義になり、**実際のユーザーは
  reCAPTCHAを解いても送信ボタンが永久に有効化されず、問い合わせフォームを
  送信できない。** バリデーションエラー時の入力値復元・メール確認欄の
  リアルタイムチェックも同時に機能しない。既存の単体テスト・システムテスト・
  Playwrightスモークテストのいずれも、この不具合を検出できる構造になっていな
  かった(実際に複数JSファイルを1ページで読み込んだ状態を実ブラウザで操作して
  初めて発見できた)。
- **合格した項目:** トップページ表示・レスポンシブ対応・FAQウィジェットの空状態
  UX(実際にローカルuvicornへ中継して確認)・ネットワーク失敗時UX・お問い合わせ
  フォームの必須項目/初期状態・reCAPTCHA/HMACトークン300秒期限切れ時のサーバー側
  UX(実際に期限切れトークンを生成し`contact.cgi`へ実POSTして確認)・
  `news.cgi`0件表示、など。
- **中程度の追加発見(非ブロッキング、フェーズ9前に方針確認推奨):** external-spec.md
  確定要件であるGA4トラッキングタグが全ページに未実装、ロゴ画像アセットが
  1枚も実装されていない(いずれも内部仕様・実装のいずれのフェーズでも担当タスク
  として記録されないまま見過ごされていた)。
- **新規に実機確認した技術的事実:** Windows上のPython `http.server --cgi`は
  `os.fork()`非搭載環境のため`.cgi`実行時に必ず`WinError 193`で失敗する
  (`subprocess.Popen`が`.cgi`ファイルを直接`CreateProcess`しようとするため)。
  この環境では「ブラウザから実際にCGIを叩く」構成は原理的に不可能であることが
  判明した(今後同じアプローチを再試行する必要はない)。
- 詳細は[e2e-test-report.md](e2e-test-report.md)、`docs/PROJECT_STATUS.md`
  チェックポイント22を参照。

**2026-08-02フェーズ7(システムテスト)再実施・合格判定:**
チェックポイント20の自己申告(修正した本人による「直った」という報告)を鵜呑みにせず、
p7-system-testerが独立の視点で再検証した。
- Perl単体テスト72件(既存67+`ContactCgiUtf8Boundary.t`5)・pytest31件を実際に
  再実行し、いずれも全件成功を確認(自己申告値と一致)。
- **既存の回帰テストをそのまま再実行するだけでなく、自ら新規に書いた別のテスト
  ハーネスで独立に再現・確認:** 実際に有効なHMACトークンを生成した上で日本語の
  姓・名・複数行本文を含む実POSTを`contact.cgi`(子プロセス)に投入し、
  バリデーション・トークン検証・重複判定・`contact_log.txt`記録まで到達させ、
  ログファイルの生バイト列に文字化けがないことを確認(既存回帰テストより検証範囲を
  1段階広げた)。エラー再描画経路・メール本文組み立て関数への受け渡しも別の日本語
  データで独自に確認し、合計16項目すべて合格。
- **裏取り:** 上記ハーネスを`contact.cgi`修正前バージョンに一時的に差し替えて
  再実行し、5/16項目が実際に失敗する(=バグを検出できる)ことを確認した上で修正版に
  復元し16/16に戻ることを確認。誤検知でないことを確認済み。
- CORS `Access-Control-Max-Age`は、pytestのTestClientに頼らず実際に`uvicorn`を
  起動し、`curl`で送った実プリフライトリクエストの生HTTPレスポンスヘッダーに
  `access-control-max-age: 86400`が返ることを確認。
- HMACトークン契約(Python発行→Perl検証)、FAQ/health実レスポンス、CORS許可外
  オリジン拒否も再確認し、回帰なし。
- 新たな問題は発見されなかった。詳細は
  [system-test-report.md](system-test-report.md)の「再テスト: 2026-08-02」節、
  `docs/PROJECT_STATUS.md`チェックポイント21を参照。
- 前回報告の「発見した問題3」(実機依存の残タスク: Vercel/reCAPTCHA実値未設定、
  Playwright残り5シナリオ未実行、GitHub Secrets未登録、Cyberhome実機の
  `.htpasswd`/`hmac_secret.txt`未配置)は未解消のまま残っており、フェーズ8が
  実機に対して実施できる範囲はこの状態に制約される。

**2026-08-02フェーズ6差し戻し対応完了(`contact.cgi`文字化けバグ・CORS Max-Age):**
`site/cgi-bin/contact.cgi`の`main()`内、`CGI->new`直前に`$CGI::PARAM_UTF8 = 1;`を
追加し、日本語フォーム入力の文字化けを修正した(`ContactLogic.pm`・`Common.pm`側は
調査の結果いずれも正しくデコードされた文字列を受け取る前提で正しく実装済みだった
ため無変更)。`api/app/main.py`の`CORSMiddleware`に`max_age=86400`を追加し
(`internal-spec-integration.md` 5.2節・8章の確定値と突合済み)、
`api/tests/test_recaptcha.py`ケース13にヘッダーアサーションを追加した。回帰テストとして
`site/cgi-bin/lib/t/ContactCgiUtf8Boundary.t`(CGI.pmスタブ経由で実際に`contact.cgi`を
子プロセス実行しUTF-8デコードを検証、5ケース)を新規追加し、修正前は実際に2ケースが
失敗する(バグを検出する)ことを確認した上で、修正後に全件成功することを確認した。
Perl 72件(既存67+新規5)・pytest 31件、全件成功。詳細は`docs/PROJECT_STATUS.md`
チェックポイント20を参照。

**2026-08-02フェーズ7(システムテスト)初回実施・不合格判定:**
`docs/specs/internal-spec-integration.md`のCyberhome⇔Vercel連携契約を中心に、
実際にコードを動かして継ぎ目を検証した(ペーパーレビューではなく、Python
`_issue_token()`が生成した実トークンをPerl `verify_token()`に実投入、uvicornを
実起動して`GET /api/faq`等を実際に叩く、CGI.pm相当のハーネスで`contact.cgi`を
実際のPOSTボディで実行、等)。
- **合格:** HMACトークンの生成・検証・改ざん検知・期限切れ(300秒)・クロックスキュー
  許容(60秒)、FAQ APIの実レスポンス形状と`chat-widget.js`のパース処理との整合、
  CORS許可/拒否の基本動作、`news.cgi`/`download.cgi`のエラーパス(パストラバーサル・
  404)、`.htaccess`のrealm共有設定、環境変数名の全体突合(名称ドリフルなし)。
- **不合格(重大):** `site/cgi-bin/contact.cgi`が`CGI->new`実行時に
  `$CGI::PARAM_UTF8 = 1;`(または`use CGI '-utf8';`)を設定しておらず、日本語の
  姓・名・お問い合わせ内容が文字化けする。通知メール・自動返信メール・エラー
  再描画・ログ記録のすべてに影響する。フェーズ6の単体テスト67件はソースコード
  リテラル(常に正しくデコード済み)を関数に直接渡していたため、この
  CGI境界のデコード漏れを検出できていなかった。**フェーズ6への差し戻しが必要。**
- **軽微(要修正だが致命的ではない):** `api/app/main.py`のCORSMiddlewareに
  `max_age=86400`が指定されておらず、Starletteのデフォルト600秒のまま
  (`internal-spec-integration.md` 5.2節・8章の契約値86400秒と不一致)。
- 詳細・再現方法・推奨修正内容は[system-test-report.md](system-test-report.md)を参照
  (初回不合格判定の内容は履歴として残しており、再テスト節で上書きしていない)。

**2026-08-02フェーズ6 Task#5(テスト・CI/CD詳細実装、Wave3)完了・フェーズ6全体完了:**
`internal-spec-testing.md`に基づき、Playwright実テストファイル8ファイル・11ケース
(`tests/e2e/public/`、2.1節シナリオ#1〜#10・#4b)を新規実装した(`.github/workflows/`
4本はTask#1が既に本書の詳細設計通りに完成させており変更不要だった)。静的ページのみに
依存する3ケースはローカルのPython簡易サーバーで実行し成功を確認、残り5ケースは
Cyberhome/Vercel実機が存在しないためこの環境では未実行。Q4(日次疎通確認の
CI検証バイパス)は`api/app/services/recaptcha_service.py`の`_resolve_secret_key`が
既に実装済みであることを確認したが、対応するpytestケースが存在しないギャップを発見し
`api/tests/test_recaptcha.py`に2件追加(pytest合計29→31件)。Perl 67件・pytest 31件
全て成功。残タスク一覧は`docs/PROJECT_STATUS.md`チェックポイント18を参照。

**2026-08-02フェーズ6 静的ページ実装(gap-fill)完了:** Task#1(リポジトリ構成)・
Task#3(Cyberhome側CGI)のいずれも「ページ内容・コピー自体はスコープ外」と判断して
未着手だった`site/contact.html`・`contact-thanks.html`・`privacy.html`・`news.html`
(新規)と`site/index.html`(旧・英語プレースホルダーからexternal-spec.md確定事項に
基づく日本語コンテンツへ全面更新)を実装した。`contact.html`は`contact.cgi`が要求する
フィールド名・プレースホルダー構文を実コード(`ContactLogic.pm`・`Common.pm`)を
grepして完全一致させ、`Common::render_template()`を実際に実行して置換結果を検証した。
FAQウィジェット(`site/js/chat-widget.js`)・reCAPTCHA→HMAC連携(`site/js/contact-form.js`)
を新規実装し、`internal-spec-integration.md`・`internal-spec-vercel.md`の契約文言
(空状態・エラー時メッセージ等)をそのまま使用。既存Perl単体テスト67件は全件成功のまま
(CGI/`.pm`側は無変更)。VercelデプロイURL・reCAPTCHAサイトキーの2値は実機未確定のため
コード中に明示的なTODOプレースホルダーとして残している。詳細は`docs/PROJECT_STATUS.md`
チェックポイント17を参照。

**2026-08-02フェーズ6 Task#4(Vercel/FastAPI実装、Wave2)完了:**
`internal-spec-vercel.md`に基づき`/api`配下にFastAPIアプリ本体
(`app/main.py`・`core/`・`middleware/`・`routers/`・`models/`・`services/`)を新規実装。
`GET /api/faq`・`POST /api/verify-recaptcha`(9章のCI検証バイパス分岐含む)・
`GET /health`+簡易インメモリレート制限(5章)を実装し、pytest単体テスト29ケース
(6.3/6.4/6.5節と1対1対応)全件成功、ruffもクリーン。管理GUI関連(7章、Phase 10
スコープ)は未着手のまま。CSRF実装(7.2節)はスコープ外と判断し見送り、ギャップとして
記録した(詳細は`docs/PROJECT_STATUS.md`チェックポイント15参照)。

**2026-08-02フェーズ6 Task#3(Cyberhome側Perl CGI実装)完了:**
`internal-spec-cyberhome.md`に基づき、`site/cgi-bin/`配下に`contact.cgi`・
`download.cgi`・`news.cgi`とロジック分離した`.pm`モジュール4本
(`Common.pm`/`ContactLogic.pm`/`DownloadLogic.pm`/`NewsLogic.pm`)、
QRランディングページ(`qr/book1.html`・`book2.html`)、`.htaccess`確定版6本、
`templates/header.html`・`footer.html`を実装した。HMACトークン検証は
`internal-spec-integration.md` 1.2節のロジックをそのまま実装(`Digest::SHA`の
みでCPAN不要)。Test::More単体テスト67ケース(`Common.t`14/`ContactLogic.t`27/
`DownloadLogic.t`19/`NewsLogic.t`7)を実装し、全件成功を確認した。
`site/contact.html`等の静的ページ(`contact.cgi`が依存するプレースホルダー
コメントを含む必要あり)は本タスクの範囲外として次タスクへ申し送り。詳細は
`docs/PROJECT_STATUS.md`チェックポイント16を参照。

**2026-08-02フェーズ6 Task#4(Vercel/FastAPI実装)完了:** `internal-spec-vercel.md`に
基づき、`api/app/`配下にFastAPIアプリ本体一式(`main.py`/`core/`/`middleware/`/
`routers/`/`models/`/`services/`)を実装した。pytest単体テスト29ケース
(`test_faq.py`12/`test_recaptcha.py`14/`test_health.py`3)、全件成功。
`admin.py`等のFAQ管理GUI関連はフェーズ10(保守サイクル)に委譲し未実装のまま。
詳細は`docs/PROJECT_STATUS.md`チェックポイント15を参照。

**2026-08-02フェーズ6 Task#2(データモデル)完了:**
`internal-spec-datamodel.md`に基づき、MVP実データファイル`api/app/data/faq.json`
(FAQ 0件で開始)、参照用JSON Schema(`docs/specs/data/faq.schema.json`)、将来のNeon
Postgres schema参照SQL(`docs/specs/data/neon-schema.sql`、DBは未接続・未提供)、
スタンドアロンのバリデーションスクリプト(`scripts/validate_faq.py`)+pytest単体テスト
50ケース(`scripts/tests/test_validate_faq.py`、全件成功)を実装した。`api/app/`配下は
このデータファイル1点のみ追加し、FastAPIアプリ本体(コード)はVercel側実装タスクの
担当領域として未着手のまま残した。詳細は`docs/PROJECT_STATUS.md`チェックポイント14を
参照。

**2026-08-02フェーズ6 Task#1(リポジトリ構成・CI/CD基盤)完了:**
`internal-spec-repo-cicd.md`に基づき、`/site`(Cyberhome用)・`/api`(Vercel用)への
モノレポ分割、`.gitattributes`、GitHub Actionsワークフロー4本
(`deploy-cyberhome.yml`/`playwright-smoke.yml`/`api-tests.yml`/`perl-tests.yml`)、
`api/vercel.json`書き換え、Node.js関連資産(`api/send-email.js`・
`package-lock.json`・`node_modules/`・`scripts/dev-server.js`・旧`vercel.json`)の
削除を実施した。フェーズ5非ブロッキングコメント1〜3(環境変数名・CSRF記述・
レート制限出典表現)も解消済み。詳細は`docs/PROJECT_STATUS.md`チェックポイント13を
参照。Cyberhome側CGI実装・Vercel側FastAPI実装・テスト/CI-CD詳細実装は後続タスク。

**2026-08-02フェーズ5(内部仕様最終レビュー・確定)完了・承認:** `docs/specs/internal-spec.md`
(統合窓口)+6本の詳細設計ドキュメント(`internal-spec-datamodel.md`,
`internal-spec-repo-cicd.md`, `internal-spec-integration.md`, `internal-spec-cyberhome.md`,
`internal-spec-vercel.md`, `internal-spec-testing.md`)を、`external-spec.md`(承認済み)・
`architecture.md`(ドラフト確定)・`phase4-clarification.md`(全280問)を基準に精読レビュー
した。トレーサビリティ・API契約の明確性・データモデルの妥当性・単体テスト方針の具体性・
既存資産(`api/send-email.js`等)との整合性のいずれについてもブロッキングな矛盾・欠落は
見つからず、**「承認」**とした(`internal-spec.md`冒頭に承認セクション追記済み)。非
ブロッキングのコメント4件(環境変数名`HMAC_SHARED_SECRET`/`INTEGRATION_HMAC_SECRET`の
表記統一未完了、レート制限記述の出典表現、FastAPI CSRF記述の技術的な訂正、reCAPTCHA
トークン期限切れUXの受け入れテスト時確認)を記録し、フェーズ6着手時に解消することを
推奨している。詳細は`internal-spec.md`冒頭を参照。

**2026-08-02の主な追加決定(`phase4-clarification.md`参照):**
- DB(Neon/Postgres)は**FAQ管理Web GUI用に限定して前倒し導入**(`architecture.md`の
  決定事項5に反映済み)。問い合わせフォーム処理はCyberhome CGI+テキストログのまま。
  FAQ管理GUIはMVPリリース直後の最初の保守作業として速やかに着手する方針。
- GUI認証: ログインフォーム+セッション/JWT、bcryptハッシュ、複数アカウント対応、
  CSRF対策、ログイン試行制限、IP制限。フロントエンドはJinja2(SSR)。
- **保守サイクル(フェーズ10)の方針転換: 大きい機能追加であっても常に軽量な
  p10-maintainerプロセスで対応し、フェーズ1〜5への差し戻しは行わない**
  (下記ゲートルール・スコープメモに反映済み)。
- `.gitattributes`でCGI/Perlファイルの改行コード(LF)を強制、コミットメッセージは
  英語統一、GitHubリポジトリはPrivateを維持。

**2026-08-02フェーズ4完了・全追加質問解消:** ユーザー承認済みの6サブエージェント分割構成
(Wave1: データモデル/リポジトリ・CI-CD/連携契約 → Wave2: Cyberhome側/Vercel側 →
Wave3: テスト・デプロイ検証)で内部仕様の詳細設計を実行し、`docs/specs/internal-spec.md`
(統合窓口)+6本の詳細設計ドキュメントを作成した。Wave間の食い違い7件はすべて各
エージェントが自己解決(内部仕様.md 2章に記録)。残った追加質問4件もユーザーが即日回答し、
全ドキュメントへ反映済み。

**次回再開時に最初にやること:**
1. **フェーズ9(最終レビュー・Issue確認)は完了し、「リリース可」判定を得た
   (2026-08-02、`docs/specs/final-review.md`、`docs/PROJECT_STATUS.md`
   チェックポイント25)。パイプライン(フェーズ1〜9)側の作業はすべて完了している。**
   次に必要なのは、運営者本人による実世界の作業(下記2)であり、エージェント側の
   追加コード修正ではない。
2. **運営者が行う必要がある作業(`final-review.md`末尾に詳細一覧あり):**
   Vercelへの実デプロイ(→`VERCEL_API_BASE_URL`反映)・Google reCAPTCHA v2登録
   (→サイトキー/シークレットキー反映)・実GA4測定IDの取得(→`G-XXXXXXXXXX`置換)・
   実ロゴアセットの入手(→`logo-placeholder.svg`置換)・Cyberhome実契約情報の確認
   (月額費用・Apacheバージョン・`AuthUserFile`絶対パス)・GitHub Secrets/Variables
   登録(`CYBERHOME_FTP_*`・`SITE_BASE_URL`・`VERCEL_API_BASE_URL`・
   `SMOKE_TEST_SECRET`等)・`.htpasswd`/`hmac_secret.txt`の実ファイルFTP配置・
   設立年「2030年」の対外表記の事業判断・リポジトリルート直下の未追跡レガシー
   ファイル群の削除可否判断。
3. **Phase 10(保守サイクル)へ正式に繰り越す項目(`final-review.md`参照):**
   `site/qr/book1.html`・`book2.html`へのFAQウィジェット追加、
   `internal-spec-vercel.md`7章のFAQ管理GUI・Neon DB導入・CSRF実装(既存合意通り
   最優先タスク)、`download.cgi`/`news.cgi`への防御的UTF-8設定の明記、
   `scripts/setup.ps1`の陳腐化整理、GitHubブランチ保護ルール・PRベース開発フロー
   への移行。

**完了済み:**
1. `git push` は `gh auth setup-git` でGCMの詰まりを回避し、完了済み(`origin/main` = `0f6c50c`)。
2. 30項目の決定事項リスト+追加質問9件にユーザーが回答(2026-08-01)、
   `docs/specs/external-spec.md` を最終ドラフトに書き直し済み。参考サイト
   (https://jyoho1.web.cyberhome.ne.jp/)をWebFetchで調査したが、取得結果に不審な値
   (未来日付・example.comドメイン等)があったため鵜呑みにせず、会社情報はユーザー本人の
   回答値(FroEduX/とどほっけ太郎/川崎市中原区宮内/電話なし/メール作成中/平日10-17時/
   設立2030年)で確定した。
3. **ホスティング方針が確定し、過去のコミット`8e00019`の決定(GitHub Pages本番)を上書き:**
   ホームページ本体・ダウンロード機能はCyberhome/Apache、問い合わせ機能はVercel、
   ソース管理はいずれもGit/GitHub。GitHub Pagesは本番ホスティングとして使わない方針に変更。
4. フェーズ2レビューを実施し「承認」。軽微なコメント3件(チャットUIの表現、FAQ空状態の
   扱い、設立年2030年の表記確認)を`external-spec.md`冒頭に記録。ブロッキングではない。
5. フェーズ3着手。Cyberhome/Apache側技術スタック、Vercel側技術スタック、DB選定、
   認証・秘密情報管理、両ホスティング先の連携方式、リポジトリ構成、CI/CD、
   開発・テスト環境、監視・コスト運用の8領域・32項目の質問リストを作成し、
   `docs/specs/architecture.md`に記載した。
6. **ユーザーが32項目全てに回答(2026-08-01)。** 回答を反映し、`docs/specs/architecture.md`
   の「技術要件」「候補と比較(静的/動的/DB)」「決定事項」を確定させた。主な確定事項:
   - Cyberhome側: Perl 5.16・CPAN不可・管理者権限なしという制約の下、記事CGI
     (`news.cgi`、テキストファイル取り込み)、ダウンロード用CGI(`download.cgi`、
     Basic認証+自前アクセスログ)、QRコード遷移ページ(Basic認証)の詳細設計を提示。
   - Vercel側: Node.js実装(`api/send-email.js`)は全面廃棄、Python(FastAPI)へ移行。
     将来のAzure PaaS移行(Azure Functions/App Service)を見据えた設計とした。
   - reCAPTCHA: v2採用、検証はVercel(FastAPI)が代行しCyberhome側へHMAC署名付き
     トークンを引き渡す方式(CyberhomeにTLSモジュールがない制約への対応)を設計。
   - DB: MVPでは導入しない(問い合わせ履歴はメール+テキストログ、FAQは静的JSON)。
     将来必要になった場合の候補としてNeon(Postgres)・Airtableを整理。
   - リポジトリ構成: モノレポ内`/site`(Cyberhome用)・`/api`(Vercel用)分割を採用。
   - **重要な矛盾を検出・解消:** 回答(Q11/Q14/Q31)が「問い合わせフォーム処理をCyberhome
     Perl CGIで行う」という、承認済み`external-spec.md`の「Vercelで処理・DB保存」と
     矛盾する方向性を3回にわたり示した。エージェントは無断で上書きせず推奨案
     (Cyberhome CGIでフォーム処理、Vercelは FAQ/チャットAPIとreCAPTCHA検証のみに
     縮小)を提示し、**ユーザーが推奨案で確定することを承認(2026-08-01)。**
     `external-spec.md`のホスティング方針表・DB保存の記載も軽微修正済み。
   - 副次的に検出したVercel Hobby(無料)プランの商用利用規約上のリスクについても、
     **リスクを許容してHobbyのまま進めることをユーザーが確定(2026-08-01)。**

7. フェーズ4着手前の曖昧さ撲滅ラウンド完了(2026-08-02): 50問×2ラウンド
   (ビジネスロジック中心)+30問×5ラウンド(Web/DB/Python技術基盤・保守性)、
   合計280問への回答をすべて記録。ブロッキングな矛盾はすべて解消
   (詳細は`docs/specs/phase4-clarification.md`参照)。
8. **フェーズ4(内部仕様調査)完了(2026-08-02):** ユーザー承認済みの6サブエージェント
   構成(Wave1〜3)で実行。成果物は`docs/specs/internal-spec.md`(統合窓口)+
   6本の詳細設計ドキュメント。Wave間の食い違い7件を各エージェントが自己解決、
   残る追加質問は4件のみ(GUIパスワードリセットのメール経路、`Contents/`実ファイルの
   Git管理方針、CGIファイル実行権限、問い合わせフォーム自動疎通確認の範囲)。

9. `docs/specs/internal-spec.md`の追加質問4件にユーザーが回答(2026-08-02、即日)。
   全ドキュメントへ反映済み。特にQ4は当初のB案が`contact.cgi`無変更では技術的に
   成立しないことが判明したため、Vercel側のみの小分岐(B′案)へ調整して合意。
10. **フェーズ5(内部仕様最終レビュー・確定)完了・承認(2026-08-02):**
    `docs/specs/internal-spec.md`と6本の詳細設計ドキュメントを`external-spec.md`・
    `architecture.md`・`phase4-clarification.md`基準に精読レビューし、ブロッキングな
    矛盾・欠落なしと判断して承認。非ブロッキングコメント4件を`internal-spec.md`冒頭に
    記録(詳細は同ファイル参照)。**フェーズ6(実装・単体テスト)に着手可能。**

11. **フェーズ6 Task#1(リポジトリ構成・CI/CD基盤)完了(2026-08-02):**
    `/site`・`/api`モノレポ分割、`.gitattributes`、GitHub Actionsワークフロー4本、
    `api/vercel.json`書き換え、Node.js関連資産削除を実施。詳細は
    `docs/PROJECT_STATUS.md`チェックポイント13参照。

12. **フェーズ6 Task#2(データモデル)完了(2026-08-02):** `api/app/data/faq.json`
    (FAQ 0件、`internal-spec-datamodel.md` 2.2節準拠)、参照用JSON Schema
    (`docs/specs/data/faq.schema.json`)、将来のNeon Postgres schema参照SQL
    (`docs/specs/data/neon-schema.sql`、DB未接続)、`scripts/validate_faq.py`+
    pytest単体テスト50ケース(`scripts/tests/test_validate_faq.py`、全件成功)を実装。
    詳細は`docs/PROJECT_STATUS.md`チェックポイント14参照。

13. **フェーズ6 Task#4(Vercel/FastAPI実装、Wave2)完了(2026-08-02):**
    `internal-spec-vercel.md`に基づき`/api`配下にFastAPIアプリ本体一式
    (`main.py`・`core/`・`middleware/`・`routers/`・`models/`・`services/`)を
    新規実装。`GET /api/faq`・`POST /api/verify-recaptcha`(9章CI検証バイパス含む)・
    `GET /health`・簡易インメモリレート制限(5章)を実装し、pytest単体テスト29ケース
    (`api/tests/`、6.3/6.4/6.5節と1対1対応)全件成功、ruffクリーン。管理GUI(7章、
    Phase 10スコープ)は未着手。詳細は`docs/PROJECT_STATUS.md`チェックポイント15参照。

14. **フェーズ6 Task#3(Cyberhome側Perl CGI実装、Wave2)完了(2026-08-02):**
    `internal-spec-cyberhome.md`に基づき`site/cgi-bin/`配下に`contact.cgi`・
    `download.cgi`・`news.cgi`+`.pm`モジュール4本(`Common`/`ContactLogic`/
    `DownloadLogic`/`NewsLogic`)、QRランディングページ、`.htaccess`確定版6本、
    `templates/header.html`・`footer.html`を新規実装。HMACトークン検証は
    `internal-spec-integration.md` 1.2節のロジックをそのまま実装。Test::More
    単体テスト67ケース(`Common.t`14/`ContactLogic.t`27/`DownloadLogic.t`19/
    `NewsLogic.t`7)全件成功。`site/contact.html`等の静的ページは範囲外として
    次タスクへ申し送り。詳細は`docs/PROJECT_STATUS.md`チェックポイント16参照。

15. **フェーズ6 静的ページ実装(gap-fill)完了(2026-08-02):** `site/contact.html`・
    `contact-thanks.html`・`privacy.html`・`news.html`(新規)、`site/index.html`
    (日本語コンテンツへ全面更新)、`site/js/chat-widget.js`・`contact-form.js`
    (新規)を実装。`contact.html`のフィールド名・プレースホルダー構文は
    `contact.cgi`・`ContactLogic.pm`の実コードと完全一致させ、
    `Common::render_template()`を実際に実行して検証。既存Perl単体テスト67件は
    全件成功のまま。詳細は`docs/PROJECT_STATUS.md`チェックポイント17参照。

16. **フェーズ6 Task#5(テスト・CI/CD詳細実装、Wave3)完了・フェーズ6全体完了
    (2026-08-02):** `.github/workflows/*.yml`4本はTask#1がすでに
    `internal-spec-testing.md`の詳細設計通りに完成させていたことを確認(変更なし)。
    Playwright実テストファイル8ファイル・11ケース(`tests/e2e/public/`、
    2.1節シナリオ#1〜#10・#4b)+`package.json`・`playwright.config.ts`を新規実装。
    実装済みの実ファイル(HTML/JS/Perl/FastAPI)を読み合わせてセレクタ・文言を
    一次情報から確認。静的ページ3ケースはローカルPythonサーバーで実行・成功確認、
    残り5ケースはCyberhome/Vercel実機が無いため未実行(タスク指示通り)。Q4
    (日次疎通確認、B'案)の実装(`recaptcha_service.py` `_resolve_secret_key`)は
    実装済みと確認したが、対応pytestケースの欠落を発見し2件バックフィル
    (`test_recaptcha.py`、pytest合計29→31件)。Perl 67件・pytest 31件全件成功。
    詳細・残タスク一覧は`docs/PROJECT_STATUS.md`チェックポイント18参照。

**フェーズ6(実装・単体テスト)は上記16項目をもって全体完了した。単体テスト合計
148件(Perl 67 + pytest 31 + FAQバリデータ50)がすべて成功している。**

17. **フェーズ7(システムテスト)初回実施・不合格判定(2026-08-02):**
    実際にコードを動かして継ぎ目を検証し、`contact.cgi`の日本語入力文字化けバグ
    (重大)とCORS `Access-Control-Max-Age`不一致(軽微)を発見、フェーズ6へ差し戻し。
    詳細は`docs/PROJECT_STATUS.md`チェックポイント19、`system-test-report.md`参照。

18. **フェーズ6差し戻し対応完了(2026-08-02):** `contact.cgi`に
    `$CGI::PARAM_UTF8 = 1;`を追加、`api/app/main.py`のCORSMiddlewareに
    `max_age=86400`を追加。回帰テスト`ContactCgiUtf8Boundary.t`(5ケース)を新規追加し、
    Perl 72件・pytest 31件全件成功を確認。詳細は`docs/PROJECT_STATUS.md`
    チェックポイント20参照。

19. **フェーズ7(システムテスト)再実施・合格判定(2026-08-02):** チェックポイント18の
    自己申告を独立に再検証(既存回帰テストの再実行に加え、自ら新規に書いた別の
    テストハーネスでHMACトークン検証・重複判定・ログ記録まで到達するフルパス正常系や
    エラー再描画経路を再確認し、修正前バージョンに戻すと実際に失敗することも確認)。
    CORS Max-Ageは実uvicorn起動+実HTTPレスポンスヘッダーで86400を確認。新たな問題は
    発見されず、**フェーズ7は合格。フェーズ8(E2Eテスト)に着手可能。**
    詳細は`docs/PROJECT_STATUS.md`チェックポイント21、`system-test-report.md`の
    「再テスト: 2026-08-02」節を参照。

20. **フェーズ8(E2Eテスト)実施・不合格判定(2026-08-02):** external-spec.mdの
    3セクションから受け入れシナリオを作成し、実ブラウザ(Playwright/Chromium)・
    実際にローカル起動したFastAPI(uvicorn)・実際に子プロセス実行したPerl CGIを
    組み合わせて検証した。`contact.html`が`chat-widget.js`・`contact-form.js`の
    両方を読み込んでおり、両ファイルとも`const VERCEL_API_BASE_URL`をトップレベルで
    重複宣言しているため実ブラウザで`SyntaxError`が発生し、`contact-form.js`全体
    (reCAPTCHA連携・バリデーションエラー時の入力値復元・メール確認欄の
    リアルタイムチェック)が実行不能であることを発見した。FAQウィジェットの空状態
    UX・ネットワーク失敗時UX(実際にローカルuvicornへ中継して確認)、reCAPTCHA/HMAC
    トークン300秒期限切れ時のサーバー側UX(実際に期限切れトークンを生成して
    `contact.cgi`へ実POST)は合格。GA4トラッキングタグ未実装・ロゴ画像アセット
    未実装も新たに発見した(いずれも非ブロッキング)。**判定: 不合格。フェーズ6へ
    差し戻し。フェーズ9にはまだ進めない。** 詳細は
    [e2e-test-report.md](e2e-test-report.md)、`docs/PROJECT_STATUS.md`
    チェックポイント22を参照。

**残タスク(フェーズ6の差し戻し対応・フェーズ8以降が参照すべき一覧、詳細は
`docs/PROJECT_STATUS.md`チェックポイント18・21・22を参照):**
21. **【最優先】`site/contact.html`のスクリプト競合(`contact-form.js`実行不能)を
    修正する。** `e2e-test-report.md`「発見した問題1」参照。修正後、実ブラウザでの
    再確認+フェーズ8の再実施が必要(フェーズ9着手の前提条件)。
    **2026-08-02チェックポイント23で修正実装済み**(`chat-widget.js`・
    `contact-form.js`をそれぞれIIFEで包みスコープを分離、実ブラウザで
    `onRecaptchaSuccess`呼び出し可否・入力値復元を確認済み)。**ただし
    p8-e2e-testerによるフェーズ8の独立した再実施・合格判定はまだ得ていない**
    (実装者自身の確認はフェーズ8の代わりにならない)。
22. (非ブロッキング、フェーズ9前に方針確認推奨)GA4トラッキングタグが全ページに
    未実装(`e2e-test-report.md`「発見した問題2」)。**2026-08-02チェックポイント23で
    TODOプレースホルダー(`G-XXXXXXXXXX`)として実装済み。実測定IDへの差し替えは
    運営者確認待ち。**
23. (非ブロッキング、フェーズ9前に方針確認推奨)ロゴ画像アセットが未実装、
    テキストロゴのみで単一ファイル参照構成も未達成(`e2e-test-report.md`
    「発見した問題3」)。**2026-08-02チェックポイント23で
    `site/images/logo-placeholder.svg`(単一ファイル参照)として実装済み。
    実ロゴアセットへの差し替えは運営者確認待ち。**
24. 追加質問3〜6(architecture.md、非ブロッキング)はフェーズ8以降と並行して確認する。
25. `scripts/setup.ps1`の陳腐化(Node.js前提のローカル開発セットアップ手順が
    現行方針と不整合)の扱いを整理する(非ブロッキング、詳細は
    `docs/PROJECT_STATUS.md`チェックポイント13の「フェーズ4/5へのフィードバック」参照)。
26. フェーズ10(FAQ管理GUI実装)着手時、`internal-spec-vercel.md` 7.2節のCSRF
    ダブルサブミット方式を`admin.py`ルーターとともに実装する(Task#4では
    スコープ外と判断し見送った、詳細は`docs/PROJECT_STATUS.md`チェックポイント15参照)。
27. `site/js/chat-widget.js`・`contact-form.js`内の`VERCEL_API_BASE_URL`、
    `site/contact.html`のreCAPTCHA `data-sitekey`は、実機情報(Vercelデプロイ先URL・
    reCAPTCHA v2サイトキーの登録)が確定次第、プレースホルダーから実際の値に
    置き換えること(非ブロッキング、詳細は`docs/PROJECT_STATUS.md`チェックポイント17
    参照。**注記:** 実値を設定しても残タスク21のスクリプト競合バグ自体は解消しない、
    別々の対応が必要)。
28. `site/qr/book1.html`・`book2.html`にはFAQウィジェット(`chat-widget.js`)を
    意図的に追加していない(Task#3の既存成果物へのスコープ拡大を避けたため)。
    external-spec.mdの「全ページ共通」要件を厳密に満たすには、将来これらにも
    追加する余地がある(非ブロッキング)。
29. Playwrightスモークテスト(`tests/e2e/public/`)のうち5ファイル
    (`news`/`basic-auth`/`faq-widget`/`vercel-faq-api`/`contact-submission`)は
    Cyberhome/Vercelの実デプロイが存在しないためこの環境では一度も実行されていない。
    さらにフェーズ8で、Windows上のPython `http.server --cgi`では`os.fork()`非搭載の
    ため`.cgi`実行が原理的に不可能(`WinError 193`)であることも実機確認した。
    実デプロイ後、`workflow_dispatch`で`playwright-smoke.yml`を手動実行して初回の
    実地検証を行うこと。
30. GitHub Secrets/Variables(`CYBERHOME_FTP_*`、`SITE_BASE_URL`、
    `VERCEL_API_BASE_URL`、`SMOKE_TEST_SECRET`等)がこの環境では未登録であり、
    登録されるまで4本のワークフローは実行時に失敗する(構文・設計は完成済み)。
31. GitHubブランチ保護ルール・PRベース開発フロー(`internal-spec-repo-cicd.md` 6章)
    への移行が未実施のまま(引き続きmainへの直接コミットで進めている)。
32. (非ブロッキング)リポジトリのルート直下に出現した、git管理下にない
    OneDrive同期由来と思われる未追跡ファイル群(`README.md`・`index.html`・
    `dist-release/`・`src/`・`public/`等)の扱いを運営者が確認すること
    (`docs/PROJECT_STATUS.md`チェックポイント21参照)。
    **2026-08-02チェックポイント23で中身を確認したところ、Vite製の別デザイン
    一式(実GA4測定ID`G-EG1WMDPTV0`を含む)であることが判明したが、参考サイト
    調査時の不審な値(未来日付・`example.com`ドメイン等)と一致する内容も
    含まれ出典が不確かなため、本サイトの正式なGA4測定IDとしては採用しなかった
    (代わりにTODOプレースホルダーを採用、残タスク22参照)。削除してよいかの
    確認は引き続き未対応。**

33. **フェーズ6差し戻し対応完了、フェーズ8再実施待ち(2026-08-02
    チェックポイント23)。** `site/contact.html`のスクリプト競合(残タスク21)・
    GA4未実装(残タスク22)・ロゴ画像未実装(残タスク23)をいずれも実装した。
    Perl単体テスト72件・pytest31件は全件成功(回帰なし)。Playwrightフルスイート
    (11件)は3 passed/6 failed/2 skippedで、失敗6件はいずれもこの開発環境固有の
    既知の制約(Apache Basic認証非対応・Windows上での`.cgi`実行不可・実Vercel
    未デプロイ)によるものであり、本タスクの変更による新規の回帰ではないことを
    個別に確認した。**本チェックポイントはフェーズ6スコープの実装修正+実装者
    自身による最小限の実ブラウザ確認であり、フェーズ8(E2Eテスト)の再実施
    そのものではない。** p8-e2e-testerによる独立した再実施・合格判定が
    フェーズ9着手の前提条件として引き続き必要。詳細は`docs/PROJECT_STATUS.md`
    チェックポイント23を参照。

34. **フェーズ8(E2Eテスト)独立再実施・合格判定(2026-08-02、
    チェックポイント24):** チェックポイント23の自己申告(修正担当者自身による
    実ブラウザでの最小限確認)を鵜呑みにせず、p8-e2e-testerが独立の視点で
    別途新規に書いたPlaywright spec(11ケース)により再検証した。旧
    `SyntaxError: Identifier 'VERCEL_API_BASE_URL' has already been declared`は
    再現せず、`onRecaptchaSuccess`/`onRecaptchaExpired`が実際に呼び出し可能
    であること、`POST /api/verify-recaptcha`の成功レスポンスをモックして
    実際に呼び出すと送信ボタンが実際に有効化されること、失敗時は確定文言と
    共にdisabledのまま保たれること、バリデーションエラー時の再描画で
    5フィールド全てが可視入力欄へ復元されることを確認した(旧シナリオ#10・
    #11を合格に判定変更)。GA4トラッキングタグ・ロゴ画像も全8ページ
    (`qr/book1.html`・`book2.html`・`news.cgi`が組み立てる合成ページを含む)で
    独自に確認し、旧シナリオ#5・#3を合格に判定変更した。既存自動テスト
    スイート(Perl 72/72件・pytest 31/31件・Playwright既存スイート3 passed/
    6 known-environment-limitation failures/2 skipped)を実際に再実行し
    フェーズ6自己申告値と一致することを確認、FAQ空状態・失敗時UX・HMAC
    300秒期限切れUXにも回帰がないことを確認した。新たな問題は発見されな
    かった。**判定: 合格。フェーズ9(最終レビュー)に着手可能。** 詳細は
    [e2e-test-report.md](e2e-test-report.md)「再テスト: 2026-08-02」節、
    `docs/PROJECT_STATUS.md`チェックポイント24を参照。

**引き続き非ブロッキングとして記録する残タスク(フェーズ9着手前に運営者確認を
推奨、詳細はチェックポイント23・24参照):**
35. `VERCEL_API_BASE_URL`・reCAPTCHA v2サイトキー・GA4測定IDが引き続きTODO
    プレースホルダーのまま(実インフラ確定待ち)。
36. ロゴ画像は引き続きプレースホルダーSVG(実アセット入手待ち)。
37. `site/qr/book1.html`・`book2.html`にFAQウィジェット未搭載のまま
    (残タスク28と同一、非ブロッキング)。
38. リポジトリ直下の未追跡レガシーファイル群(残タスク32と同一)の削除要否を
    運営者が確認すること。

---

このディレクトリは、Vモデル型の開発プロセスにおける各フェーズの成果物を格納する。
各フェーズは専用サブエージェント(`.claude/agents/p*.md`)が担当し、**フェーズ間は`/clear`で
コンテキストを切り離す**ため、フェーズ間の引き継ぎ情報はすべてこのディレクトリのドキュメントに
書き出す(会話の記憶に依存しない)。

## 進捗ボード

| # | フェーズ | 担当エージェント | 成果物 | ステータス |
|---|---------|-----------------|--------|-----------|
| 1 | 外部仕様調査 | p1-external-spec-researcher | [external-spec.md](external-spec.md) | 完了(DB選定のみフェーズ3/4へ委譲) |
| 2 | 外部仕様最終レビュー・確定 | p2-external-spec-reviewer | external-spec.md (承認セクション追記) | 承認(2026-08-01、コメント3件は非ブロッキング) |
| 3 | 利用アーキテクチャー調査 | p3-architecture-researcher | [architecture.md](architecture.md) | ドラフト確定・ユーザー確認済み(2026-08-01)、フェーズ4引き継ぎ準備完了 |
| 4 | 内部仕様調査 | p4-internal-spec-researcher(6分割) | [internal-spec.md](internal-spec.md) | 完了・全追加質問解消(2026-08-02) |
| 5 | 内部仕様最終レビュー・確定 | p5-internal-spec-reviewer | internal-spec.md (承認セクション追記) | **承認(2026-08-02、非ブロッキングコメント4件)** |
| 6 | 実装・単体テスト | p6-implementer | ソースコード + 単体テスト | **完了(2026-08-02)**: Task#1(リポジトリ構成・CI/CD基盤)・Task#2(データモデル)・Task#3(Cyberhome側Perl CGI実装)・Task#4(Vercel/FastAPI実装)・静的ページ実装(gap-fill)・Task#5(テスト・CI/CD詳細実装)のすべてが完了。単体テスト合計148件全件成功(Perl 67 + pytest 31 + faq validator 50)。フェーズ7差し戻し対応(`contact.cgi`のUTF-8修正・CORS Max-Age修正)も完了、Perl 72件・pytest 31件全件成功 |
| 7 | システムテスト | p7-system-tester | [system-test-report.md](system-test-report.md) | **合格(2026-08-02)**: 初回不合格(contact.cgiの日本語文字化けバグ・CORS Max-Age不一致)→フェーズ6差し戻し修正→独立再検証で合格。フェーズ8着手可能 |
| 8 | E2Eテスト(受け入れテスト) | p8-e2e-tester | [e2e-test-report.md](e2e-test-report.md) | **合格(2026-08-02)**: 初回不合格(`contact.html`のスクリプト競合による`contact-form.js`実行不能、GA4/ロゴ未実装)→フェーズ6差し戻し修正→独立再検証で合格。フェーズ9着手可能 |
| 9 | 最終レビュー・Issue確認 | p9-final-reviewer | [final-review.md](final-review.md) | **リリース可(2026-08-02)**: フェーズ1〜8の全ゲート(承認/合格)を文書・実ファイル両方で裏取り、握りつぶし・記録漏れなしを確認。残存課題はすべて運営者の実世界の作業またはPhase 10への意図的な繰越。フェーズ10移行を承認 |
| 10 | 保守メンテナンス | p10-maintainer | (継続、Issue単位で個別記録) | **着手可能(2026-08-02、フェーズ9で移行承認)** |

## ゲートルール(重要)

- 各フェーズは**前フェーズが「承認」ステータスになるまで着手しない**。
- 調査フェーズ(1, 3, 4)は「調査・ドラフト作成」のみ行い、確定はしない。
- レビューフェーズ(2, 5)は整合性確認の上、ドキュメント冒頭に
  `## 承認ステータス: 承認 / 差し戻し` を追記する。差し戻しの場合は理由を明記し、
  前フェーズの担当エージェントに戻す。
- 実装(6)はフェーズ5が承認されるまで開始しない。**2026-08-02、フェーズ5が承認され、
  フェーズ6は着手可能になった。フェーズ6は同日中にTask#1〜5すべてを完了し、
  フェーズ7(システムテスト)は着手可能な状態になった。フェーズ7は初回不合格→
  フェーズ6差し戻し修正→独立再検証で同日中に合格し、フェーズ8(E2Eテスト)は
  着手可能な状態になった。フェーズ8は初回不合格(`contact.html`のスクリプト
  競合による`contact-form.js`実行不能)となりフェーズ6へ差し戻したが、
  修正後にp8-e2e-testerが独立に再実施した結果2026-08-02に合格し、
  フェーズ9(最終レビュー)は着手可能になった。フェーズ9はp9-final-reviewerが
  2026-08-02に実施し、「リリース可」判定(フェーズ10移行承認)を得た
  (`docs/specs/final-review.md`参照)。**
- 各エージェントは作業開始時に必ず `docs/PROJECT_STATUS.md` と本ディレクトリの既存ファイルを
  読み、前提を引き継ぐこと。
- **2026-08-02方針転換:** 上記のゲートルールはMVP初回リリース(フェーズ1〜9)に適用する。
  **MVPリリース後の保守サイクル(フェーズ10)では、機能追加の規模によらず常に軽量な
  p10-maintainerプロセスで対応し、フェーズ1〜5への差し戻しは行わない**
  (`docs/specs/phase4-clarification.md`保守性ラウンドQ23でユーザーが確定)。

## スコープメモ(初期スモール構成)

- 外部仕様の対象機能: ①ホームページ仕様 ②問い合わせチャット機能(FAQ応答+問い合わせフォーム)
  ③コンテンツダウンロード(商品購入者への特典ファイル配布)
- 内部仕様はフェーズ3で全項目確定(2026-08-01):
  - 静的コンテンツ・ダウンロード機能: **Cyberhome/Apacheに確定**。
  - 問い合わせ機能: **Cyberhome側Perl CGI(`contact.cgi`+sendmail)でフォーム処理・
    メール送信・テキストログ記録を行い、VercelはFAQ/チャットAPIとreCAPTCHA検証のみに
    縮小することが確定**(`external-spec.md`のホスティング方針表も軽微修正済み)。
  - ソース管理: いずれもGit/GitHub(GitHub Pagesはホスティング先としては不採用)。
  - 動的コンテンツの実装言語・フレームワーク: Vercel側はPython(FastAPI)に決定。
    Cyberhome側はPerl CGI(`contact.cgi`/`download.cgi`/`news.cgi`)。
  - データベース: **MVPでは導入しない**ことに決定(2026-08-01、フェーズ3)。将来
    必要になった場合の候補はNeon(Postgres)・Airtable(`architecture.md`「候補と比較」
    参照)。FAQ管理Web GUI用に限定してNeonを前倒し導入する方針も確定済み
    (`architecture.md`決定事項5、フェーズ10最優先タスク)。
- フェーズ4で内部仕様の詳細設計を完了し(2026-08-02)、フェーズ5でその内容をレビューし
  承認した(2026-08-02)。詳細は`docs/specs/internal-spec.md`とその6本の詳細設計
  ドキュメント(`internal-spec-datamodel.md`, `internal-spec-repo-cicd.md`,
  `internal-spec-integration.md`, `internal-spec-cyberhome.md`, `internal-spec-vercel.md`,
  `internal-spec-testing.md`)を参照。
- 方針: 最低限度のMVPを作成し、以降は保守サイクルで機能追加していく想定。

## 未解決事項(解消済み・履歴)

過去の作業で「GitHub Pagesを本番(単体環境)、Vercelを検証環境とし、cyberhomeは廃止」という
決定を行い、その前提でリポジトリ構成を整理・コミット済み(コミット `8e00019`)。
その後フェーズ1で改めてユーザーに確認したところ、**cyberhome/Apacheをホームページ本体・
ダウンロード機能のホスティング先、Vercelを問い合わせ機能のホスティング先とする**ことが
2026-08-01に確定した。GitHub Pagesは本番ホスティングとしては採用しない。

## 現在の未解決事項(フェーズ8以降と並行して確認可能、非ブロッキング)

- Cyberhome契約プランの正確な月額費用
- 文字コード/Apacheバージョンの実機確認
- `AuthUserFile`絶対パス
- reCAPTCHAキー(v2サイトキー・シークレットキー)の登録状況

詳細は`docs/specs/architecture.md`末尾の「追加質問」3〜6を参照。

## フェーズ5レビューで記録した非ブロッキングコメント(解消済み・履歴)

詳細は`docs/specs/internal-spec.md`冒頭の承認セクションを参照。要約:

1. `internal-spec-repo-cicd.md` 7.3節の環境変数名`HMAC_SHARED_SECRET`を
   `INTEGRATION_HMAC_SECRET`に統一する(表記のみ、値は同一)。**フェーズ6 Task#1で解消済み。**
2. `internal-spec-vercel.md` 5.1節のレート制限に関する「確定前提」という出典表現を、
   実態に合わせ「Wave2の裁量による追加」に修正する。**フェーズ6 Task#1で解消済み。**
3. `internal-spec-datamodel.md` 3.5節のCSRF記述(FastAPI標準機構という誤った説明)を、
   `internal-spec-vercel.md` 7.2節の正しい実装方針(ダブルサブミット方式の独自実装)に
   合わせて修正する。**フェーズ6 Task#1で解消済み。**
4. (任意) reCAPTCHAトークン期限切れ(300秒)のUXケースをフェーズ8受け入れテストで
   一度手動確認する。**フェーズ8(初回・再テストとも)で確認済み(e2e-test-report.mdシナリオ#12)。**

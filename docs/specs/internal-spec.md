# 内部仕様(フェーズ4)

## 承認ステータス: ドラフト確定(ユーザーレビュー待ち)

作成日: 2026-08-02
担当: フェーズ4(内部仕様調査)。6サブエージェントへの分割実行(Wave1〜3、ユーザー承認済み構成)+本書での統合編纂。

---

## 0. 本書の構成

内部仕様は分量が大きいため、単一ファイルに全文を統合せず、以下6本の詳細設計ドキュメント+本書(サマリー・統合窓口)という構成にする。各ドキュメントは担当領域を明確に分離し、依存関係の順(Wave1→2→3)で確定させた。

| # | ファイル | 担当領域 | Wave |
|---|---|---|---|
| 1 | [internal-spec-datamodel.md](internal-spec-datamodel.md) | FAQ JSON schema、将来のNeon Postgres schema、命名規則等の共通規約 | 1 |
| 2 | [internal-spec-repo-cicd.md](internal-spec-repo-cicd.md) | `/site`・`/api`ディレクトリ構成、`.gitattributes`、GitHub Actionsワークフロー骨格、Vercel設定 | 1 |
| 3 | [internal-spec-integration.md](internal-spec-integration.md) | Cyberhome⇔Vercel連携契約(HMACトークン、reCAPTCHA検証フロー、FAQ API暫定契約、CORS、`/health`契約) | 1 |
| 4 | [internal-spec-cyberhome.md](internal-spec-cyberhome.md) | `contact.cgi`/`download.cgi`/`news.cgi`/QRページの詳細設計、`.pm`モジュール分割、`.htaccess`/`.htpasswd`確定版 | 2 |
| 5 | [internal-spec-vercel.md](internal-spec-vercel.md) | FastAPIアプリ構成、`/api/faq`・`/api/verify-recaptcha`・`/health`実装設計、レート制限、pytest設計、将来のFAQ管理GUI付録 | 2 |
| 6 | [internal-spec-testing.md](internal-spec-testing.md) | デプロイジョブ順序、Playwrightシナリオ、Perl/pytestのCI組み込み、バックアップ・ロールバック手順 | 3 |

各ドキュメントは前段Waveの成果物を参照・遵守し、既存ドキュメントへの直接編集は行っていない(矛盾が見つかった場合は当該ドキュメント内で解決案を明記し、参照元は不変のまま)。

---

## 1. 全体アーキテクチャ(再掲・要約)

- **Cyberhome/Apache**(静的サイト・問い合わせフォーム処理・ダウンロード機能): Perl 5.16、CPAN不可、`site/`配下。`contact.cgi`(問い合わせ受付+`sendmail`送信)、`download.cgi`(認可済みファイル配信)、`news.cgi`(記事CMS)、QRページ(静的HTML+Basic認証)。
- **Vercel/FastAPI**(FAQ・チャットAPI、reCAPTCHA検証代行): Python、`api/`配下。`GET /api/faq`、`POST /api/verify-recaptcha`、`GET /health`。MVPはDBなし(静的JSON)。
- **連携**: サーバー間直接通信なし。すべてブラウザ経由(ブラウザ→Vercel→Google→Vercel→ブラウザ→Cyberhome)。HMAC-SHA256署名トークン(有効期限300秒)で正当性を伝達。
- **将来(保守サイクル最優先タスク)**: FAQ管理Web GUI(Jinja2 SSR、ログイン+セッション/JWT、bcrypt、複数アカウント)+Neon(Postgres)導入。MVPスコープ外。

詳細な決定根拠・技術要件は`docs/specs/architecture.md`、全280問の生の質問と回答は`docs/specs/phase4-clarification.md`を参照。

---

## 2. Wave間で自己解決された食い違い(記録・非ブロッキング)

各Waveのエージェントは、前段の成果物間に見つけた軽微な表記・設計の食い違いを、既存の確定回答から合理的に導出できる範囲で自ら解決した。ユーザーへの追加確認は行っていない。統合窓口として一覧化する。

| # | 食い違い | 解決したドキュメント | 解決内容 |
|---|---|---|---|
| 1 | `download.cgi`のBasic認証の掛かり方(architecture.md原案 vs repo-cicd.mdの確定ディレクトリ構成) | internal-spec-cyberhome.md 0.1節 | `cgi-bin/.htaccess`を新設し`<Files "download.cgi">`のみ保護 |
| 2 | 「書籍ごとに別々のパスワード」と単一の`download.cgi`スクリプトの両立 | internal-spec-cyberhome.md 0.2節 | Apache層は単一`.htpasswd`で認証のみ、Perl層(`DownloadLogic.pm`)で書籍別認可を行う |
| 3 | `/health`のルーティング方式(integration.mdのrewrite前提 vs repo-cicd.mdのcatch-all設定) | internal-spec-vercel.md 0.1節 | catch-all設定により追加rewrite不要と判断、FastAPI側で`/health`を直接定義 |
| 4 | HMAC共有シークレットの環境変数名(`INTEGRATION_HMAC_SECRET` vs `HMAC_SHARED_SECRET`) | internal-spec-vercel.md 0.2節 | `INTEGRATION_HMAC_SECRET`に統一(連携契約を規定するintegration.mdを正とする) |
| 5 | FAQの「ファイル形式」と「API応答形式」のキー名差異(`items`+`display_order` vs `faqs`) | internal-spec-vercel.md 0.3節 | 別レイヤの話であり矛盾ではない。`faq_service.py`が変換層を担う |
| 6 | `news.cgi`記事ファイルの命名例(repo-cicd.mdの例示`YYYYMMDD_` vs 確定回答`YYYY-MM-DD-`) | internal-spec-cyberhome.md 4.1節 | 単なる例示表記のずれ。確定回答(ハイフン区切り)を採用 |
| 7 | `internal-spec-repo-cicd.md`「追加質問Q1」(バックアップ方式: FTPSミラー vs Gitベース) | internal-spec-testing.md 1.2節 | FTPSミラー方式に確定(`.htpasswd`等Git管理外ファイルの復元可能性を優先) |

**残存する軽微な表記不一致(実害なし、Phase 6着手時に整理):** `internal-spec-repo-cicd.md` 7.3節の環境変数一覧テーブルは旧名`HMAC_SHARED_SECRET`のまま未更新。上記#4により実装上の正式名称は`INTEGRATION_HMAC_SECRET`である(値は同一シークレット、名称のみ)。

---

## 3. 追加質問(ユーザー確認事項、4件)

6ドキュメント合計で新たに生じた「genuinely未決定」な事項は、当初想定(30問単位)を大きく下回る**4件**のみだった(他の食い違いはすべて上記2章の通り自己解決済み)。いずれも非ブロッキングで、すべて3択形式。

### Q1. FAQ管理GUIのパスワードリセットメール送信経路(`internal-spec-datamodel.md`)

GUI(保守サイクルで実装、フェーズ6スコープ外)のパスワードリセットは「メールでリセットリンクを送る」ことは確定済みだが、Vercel側からの送信経路が未定。

- A) Vercel側に新たにトランザクションメールAPI(Resend、SendGrid等の無料枠)を導入する。
- B) Vercel側でGmail SMTP(Pythonの`smtplib`+Googleアプリパスワード)を暫定的に使う。
- C) メールでのリセットは行わず、「忘れたらClaude Codeに依頼してDBを直接更新してもらう」運用に変更する。

### Q2. `Contents/book1/`・`Contents/book2/`配下の実ファイル(ダウンロード特典)のGit管理方針(`internal-spec-repo-cicd.md`)

- A) Gitで通常のバイナリファイルとして管理する(シンプルだが差し替えのたびにリポジトリが肥大化)。
- B) Git管理対象外(`.gitignore`)とし、実ファイルは常にFTPで直接Cyberhomeへアップロードする(リポジトリの肥大化を避けられる)。
- C) Git LFSで管理する(差分管理に適するが、デプロイワークフロー側にLFS pull処理の追加が必要)。

### Q3. GitHub Actions(FTPS)経由でアップロードした`.cgi`ファイルの実行権限(`internal-spec-cyberhome.md`、`internal-spec-testing.md`が暫定的にA案で設計進行中)

- A) Cyberhomeでは`.cgi`は自動的に実行可能として扱われる前提で進め、初回GitHub Actions実行時に実機で疎通確認する(**現在の設計はこの前提で進んでいる**)。
- B) 安全策として、初回のみ運営者が手動でFTPSクライアントからパーミッションを755に設定する手順を運用手順書に明記する。
- C) デプロイに使うFTP-Deploy系GitHub ActionがSITE CHMODに対応していれば自動送信する設定を組み込む(対応状況はフェーズ6実装時に確認)。

### Q4. 問い合わせフォーム(`contact.cgi`)自動疎通確認(Playwrightスモークテスト)の範囲(`internal-spec-testing.md`が暫定的にA案で設計進行中)

- A) 疎通確認はバリデーションエラー経路のみ自動化し(reCAPTCHA不要)、実際にメールが送信される正常系送信は自動化しない。正常系確認はフェーズ8の手動テストでのみ行う(**現在の設計はこの前提で進んでいる**)。
- B) Google reCAPTCHA公式テストキーを使い、正常系送信(実メール送信)を毎日自動実行する。運営者メールへの日次テストメール受信・`contact_log.txt`への日次テスト行追記を許容する必要がある。
- C) `contact.cgi`にテスト専用モード(環境変数等で切替)を追加し、テスト専用のTo/Fromで本番データを汚染しない形にする。ただし本番相当コードパスと完全一致でなくなる副作用がある。

---

## 4. 次のステップ

1. 上記4件の追加質問への回答を得る(A案のまま進めてよい場合はその旨の確認のみでよい)。
2. 回答を各詳細設計ドキュメントに反映する。
3. フェーズ5(p5-internal-spec-reviewer、内部仕様最終レビュー・確定)へ引き継ぐ。
4. フェーズ5承認後、フェーズ6(実装・単体テスト)着手。実装順序は本書の依存関係
   (データモデル・連携契約・リポジトリ構成が土台→Cyberhome側/Vercel側が並行実装可→
   テスト・CI/CDが最後)を踏襲することを推奨する。

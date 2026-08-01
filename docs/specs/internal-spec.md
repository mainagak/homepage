# 内部仕様(フェーズ4)

## 承認ステータス: ドラフト確定(全追加質問解消、フェーズ5引き継ぎ準備完了)

作成日: 2026-08-02
更新日: 2026-08-02(追加質問4件すべてに回答、各詳細設計ドキュメントへ反映済み)
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

## 3. 追加質問(4件、2026-08-02ユーザー回答済み)

| # | 論点 | 回答 | 反映先 |
|---|---|---|---|
| Q1 | FAQ管理GUIのパスワードリセットメール送信経路 | **C) メールリセットを廃止、忘れた場合はClaude CodeがNeonへ直接UPDATE** | `internal-spec-datamodel.md`3.5節(`gui_accounts`からトークンカラム削除)、`internal-spec-vercel.md`7.2節(ルート一覧から削除) |
| Q2 | `Contents/`配下ダウンロードファイルのGit管理方針 | **A) 通常のGitバイナリ管理**(除外・LFS設定なし) | `internal-spec-repo-cicd.md`追加質問Q2 |
| Q3 | `.cgi`ファイルの実行権限(FTPSアップロード後) | **A) 自動実行可能の前提で進め、初回実機確認**(既存デフォルト方針を確認) | `internal-spec-cyberhome.md`追加質問Q1 |
| Q4 | 問い合わせフォーム自動疎通確認の範囲 | **B′) Vercel側のみに小さなCI判別分岐を追加し、正常系送信(実メール送信)まで日次自動化**(`contact.cgi`は無変更) | `internal-spec-vercel.md`9章(新設、reCAPTCHA CI検証バイパス設計)、`internal-spec-testing.md`2章・7章 |

**Q4の技術的な補足:** ユーザーの当初選択(B案そのまま)は、Cyberhome側`contact.html`が
静的ファイルで環境による出し分けができないため、Vercel側に最低限の分岐を置かない限り
literal には実現できないことが判明した。この点をユーザーに確認の上、`contact.cgi`を
一切変更しない代替実装(B′、Vercel側`/api/verify-recaptcha`にCI専用ヘッダー判別を
追加しGoogle公式テストシークレットキーへ切り替える方式)へ調整することで合意を得た。
詳細は`internal-spec-vercel.md` 9章を参照。

すべての追加質問が解消され、6本の詳細設計ドキュメントに反映済み。新たな未決定事項は
発生していない。

---

## 4. 次のステップ

**フェーズ4は完了。フェーズ5(p5-internal-spec-reviewer、内部仕様最終レビュー・確定)への
引き継ぎ準備が整った。**

フェーズ5承認後、フェーズ6(実装・単体テスト)着手。実装順序は本書の依存関係
(データモデル・連携契約・リポジトリ構成が土台→Cyberhome側/Vercel側が並行実装可→
テスト・CI/CDが最後)を踏襲することを推奨する。

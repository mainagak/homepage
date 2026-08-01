# 内部仕様(フェーズ4)

## 承認ステータス: 承認

承認日: 2026-08-02
レビュー担当: フェーズ5(p5-internal-spec-reviewer)

コメント(次の改訂・フェーズ6実装時に対応してほしい軽微な指摘、いずれもブロッキングではない):

1. **環境変数名の表記不一致が未修正のまま残っている。** `internal-spec-repo-cicd.md` 7.3節の
   環境変数一覧テーブルは依然として旧名`HMAC_SHARED_SECRET`のままであり、正式名称
   `INTEGRATION_HMAC_SECRET`(`internal-spec-integration.md`・`internal-spec-vercel.md`が
   採用)に未修正。本書2章で「実害なし、Phase 6着手時に整理」と記録済みだが、実装者が
   `internal-spec-repo-cicd.md`単体だけを見て環境変数を設定すると誤った名前で登録して
   しまうリスクがあるため、**フェーズ6着手前に`internal-spec-repo-cicd.md` 7.3節の表記を
   `INTEGRATION_HMAC_SECRET`へ修正しておくこと**を推奨する。
2. **`internal-spec-vercel.md` 5.1節(レート制限)の「確定前提」という表現の出典が
   確認できない。** `phase4-clarification.md`(全280問)および`architecture.md`を検索した
   限り、レート制限の導入を明示的に確定した回答は見当たらない。実装内容自体
   (Vercelサーバーレス関数向けの簡易インメモリ実装、多層防御の補助的な1層と明記)は
   妥当な追加的セーフティ策であり差し戻す理由にはならないが、同ドキュメント7.3節の
   Alembic導入提案などで使われている「Wave2の裁量による追加」という正確な表現に
   揃えるべき(存在しない確定回答を出典として示す記述は、将来の监査・差分確認の
   妨げになるため)。
3. **`internal-spec-datamodel.md` 3.5節のCSRF記述に技術的な不正確さがある。**
   「FastAPIの標準的なCSRFトークン機構を使用(O節Q5)」とあるが、FastAPI自体には
   標準搭載のCSRF機構は存在しない。`internal-spec-vercel.md` 7.2節は同じ論点について
   正しく「FastAPI標準機能は存在しないため、ダブルサブミット方式を独自実装する」と
   記載しており、実装方針としてはvercel.md側が正しい。datamodel.md側の記述を
   vercel.md 7.2節の内容に合わせて修正するか、少なくとも参照注記を追加すること
   (この不一致は`phase4-clarification.md`O節Q5の選択肢の文言自体に由来するもので
   あり、Wave1エージェントが独自に誤りを持ち込んだものではないため、実装方針自体は
   ブロッキングではない)。
4. (参考・任意) reCAPTCHA検証トークンの有効期限(300秒)は、`contact.html`の項目順序
   (reCAPTCHAウィジェットが送信ボタン直前に配置される設計)により通常は問題にならない
   はずだが、ユーザーがreCAPTCHA完了後に入力内容を長時間推敲してから送信するケースでは
   期限切れとなり「検証に失敗しました」の再操作を求められるUXが発生し得る。実害は
   小さく設計変更は不要と判断するが、フェーズ8(受け入れテスト)でこの経路
   (reCAPTCHA完了後に5分以上待ってから送信)を一度手動確認しておくと安心。

上記4点はいずれも、内部整合性・API契約の明確性・データモデルの妥当性・単体テスト方針の
具体性・既存資産(`api/send-email.js`等)との整合性という観点でブロッキングではないと
判断し、承認する。全体として、6本の詳細設計ドキュメントは外部仕様
(`docs/specs/external-spec.md`、承認済み)・利用アーキテクチャー
(`docs/specs/architecture.md`、ドラフト確定)・`docs/specs/phase4-clarification.md`
(全280問)の確定事項へ個別の決定ごとに出典を明記してトレース可能な形で作られており、
API契約(HMACトークン仕様・reCAPTCHA検証フロー・FAQ応答形式・エラーケース・CORS)は
実装者が推測を要さない粒度まで確定している。データモデル(FAQ JSON/将来のNeon
schema)は初期リリースの要件(FAQ 0件開始、DB非導入)と将来の保守作業(FAQ管理GUI)の
両方を矛盾なくカバーしている。単体テスト方針はPerl(Test::More、約67ケース、モジュール
別内訳まで明記)・Python(pytest、29ケース、契約準拠チェックを含む)ともに「何をもって
完了とするか」が具体的に判定可能である。既存資産(`api/send-email.js`の全面廃棄、
旧`vercel.json`の書き換え、`node_modules`等の削除、`chat.html`の位置づけ変更)についても
移行方針が明記されており、無断で設計を上書きした形跡はない。

`docs/specs/architecture.md`末尾の「追加質問」3〜6(Cyberhome契約プランの正確な月額費用、
文字コード/Apacheバージョンの実機確認、`AuthUserFile`絶対パス、reCAPTCHAキー登録状況)は
既に非ブロッキングとして整理されており、これ自体を理由に差し戻さない。フェーズ6以降と
並行して確認を継続する。

**フェーズ6(実装・単体テスト)は着手可能。** 実装順序は本書4章の依存関係(データモデル・
連携契約・リポジトリ構成が土台→Cyberhome側/Vercel側が並行実装可→テスト・CI/CDが最後)を
踏襲することを推奨する。上記コメント1〜3は実装開始時または実装中の早い段階で解消して
おくことを推奨する(いずれも数行の記述修正で完結する軽微な作業)。

---

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

**残存する軽微な表記不一致(実害なし、Phase 6着手時に整理):** `internal-spec-repo-cicd.md` 7.3節の環境変数一覧テーブルは旧名`HMAC_SHARED_SECRET`のまま未更新。上記#4により実装上の正式名称は`INTEGRATION_HMAC_SECRET`である(値は同一シークレット、名称のみ)。**フェーズ5レビューで指摘済み(冒頭コメント1参照)。フェーズ6着手前に修正すること。**

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

**フェーズ4は完了。フェーズ5(内部仕様最終レビュー・確定)は2026-08-02に承認された
(冒頭「承認ステータス」参照)。フェーズ6(実装・単体テスト)への引き継ぎ準備が整った。**

フェーズ6着手時は、冒頭の非ブロッキングコメント1〜3(環境変数名の統一、レート制限の
出典表現修正、CSRF記述の技術的訂正)を実装の早い段階で解消することを推奨する。実装順序は
本書の依存関係(データモデル・連携契約・リポジトリ構成が土台→Cyberhome側/Vercel側が並行実装可→
テスト・CI/CDが最後)を踏襲することを推奨する。

# プロジェクト ステータス

## 計画1: 基盤構築 & フロントエンド - ✅ 完了

### 実装内容

- ✅ ローカル開発環境構築（Node.js + Python + Git）
- ✅ プロジェクト構造設計
- ✅ レスポンシブホームページ実装
  - ✅ Hero セクション
  - ✅ About セクション
  - ✅ Services セクション（3カラムグリッド）
  - ✅ Contact セクション（フォーム配置）
  - ✅ Chatbot セクション（プレースホルダー）
  - ✅ Footer
- ✅ スタイルシート（モバイル/タブレット/デスクトップ対応）
- ✅ 開発サーバー実装
- ✅ GitHub Pages デプロイメント設定
- ✅ Vercel デプロイメント設定
- ✅ OneDrive 複数PC対応

### 動作環境

| 環境 | URL | ステータス |
|------|-----|----------|
| Local Dev | http://localhost:3000 | ✓ Ready |
| GitHub Pages | https://mainagak.github.io/homepage/ | ⏳待機中 |
| Vercel | [Vercel URL] | ⏳待機中 |

### コミット履歴

```
6f91d08 docs: add multi-PC setup guide with OneDrive synchronization
3a73c2c ci: setup GitHub Pages and Vercel deployment workflows
b1cb81a feat: add homepage structure with HTML, CSS, JavaScript and development server
acd4883 chore: setup development environment with Node.js and Python
```

### 次のフェーズ

- **計画2: Webフォーム & バックエンド**
  - お問い合わせメール送信 API（Vercel Functions）
  - メール配信機能（nodemailer / SendGrid）
  
- **計画3: チャットボット機能**
  - Claude API 統合
  - チャットUI 実装
  
- **計画4: テスト & CI/CD**
  - Playwright E2E テスト
  - pytest 単体テスト
  - Serena コード品質チェック
  - GitHub Actions パイプライン拡張

- **計画5: 環境統合 & OneDrive最適化**
  - 全環境での統合テスト
  - パフォーマンス最適化
  - セキュリティ監査

---

## 2026-08-01: チェックポイント — 実装を一時停止し、Vモデル型プロセスへ移行

### 現在の実装状態(スナップショット)

- ルート直下(`index.html` / `css/` / `js/`)に構成を一本化済み(旧 `src/` 重複は削除、
  コミット `8e00019`)。`.github/workflows/deploy.yml` も削除(GitHub Pagesのlegacy branch
  build設定と競合していたため)。
- お問い合わせフォーム: `api/send-email.js` (Vercel Functions + nodemailer) は実装済みだが、
  `.env.local` の `SMTP_USER` / `SMTP_PASS` は未設定 → 現状メール送信は動作しない。
- チャット機能: `index.html` 内に `chat.html` への参照(iframe)はあるが、**`chat.html` 自体は
  未実装**。「Open Chat」ボタンを押すと空のiframeが表示されるだけ。
- コンテンツダウンロード機能(購入者特典ファイル配布): **未着手**。今回の会話で初めて
  要件として明示された。
- デプロイ方針に矛盾あり: 直近のコミットでは「GitHub Pagesが本番、Vercelが検証、cyberhomeは
  廃止」と決定・整理したが、本日追加された内部仕様候補では「静的コンテンツはcyberhomeベース」
  と記載されており、**再確認が必要**(詳細は `docs/specs/README.md` の「未解決事項」参照)。
- ローカルに2コミットが溜まっており、`git push` は未実行。

### プロセス変更の決定

外部仕様(初期スモール構成)を確定してから実装を再開する方針とし、以下のVモデル型
10フェーズプロセスを導入。各フェーズを専用サブエージェント化し、フェーズ間は `/clear` で
コンテキストを切り離して順次ゲート実行する。詳細は `docs/specs/README.md` および
`.claude/agents/p1-*.md` 〜 `p10-*.md` を参照。

1. 外部仕様調査 → 2. 外部仕様最終レビュー・確定 → 3. 利用アーキテクチャー調査 →
4. 内部仕様調査 → 5. 内部仕様最終レビュー・確定 → 6. 実装・単体テスト → 7. システムテスト →
8. E2Eテスト(受け入れテスト) → 9. 最終レビュー・Issue確認 → 10. 保守メンテナンス

**次のアクション:** フェーズ1(外部仕様調査)を実行し、初期スモール構成の外部仕様ドラフトを
`docs/specs/external-spec.md` として作成する。

---

## 2026-08-01: チェックポイント2 — 30項目回答を反映、追加質問9件を提示

- ユーザーが30項目の決定事項リストに回答。`docs/specs/external-spec.md` を実際のドラフトに
  書き直し済み。参考サイト https://jyoho1.web.cyberhome.ne.jp/ をWebFetchで調査(会社名
  「FroEduX」、代表者名、住所等を取得したが、未来日付や`example.com`ドメインなど不審な
  値が含まれていたため外部仕様には転記せず、未解決事項として正確な情報の提供を依頼した)。
- ホスティング方針の矛盾(GitHub Pages本番 vs cyberhome前提の回答)がより強い形で再燃。
  フェーズ3着手前に解消が必要。
- `docs/specs/external-spec.md` の「未解決事項」に9件の追加質問を記載済み。ユーザー回答待ち。

**次のアクション:** 追加質問9件への回答を待ち、`external-spec.md` の未解決事項を解消して
フェーズ2(p2-external-spec-reviewer)へ引き継ぐ。

---

## 2026-08-01: チェックポイント3 — 追加質問9件中8件に回答、フェーズ1実質完了

- 追加質問9件のうち8件に回答あり。会社情報(FroEduX/とどほっけ太郎/川崎市中原区宮内/
  電話なし/メール作成中/平日10-17時/設立2030年)、チャットUI(全ページ共通フローティング
  ウィジェット)、メンテ簡易化(記事追加が対象、ロゴは1箇所更新で全箇所反映される構成が
  必須)、QRコードID/パスワードは年次更新、プライバシーポリシーは新規作成必要、
  アクセスログは運営者本人が週次で目視確認、をそれぞれ確定し `external-spec.md` に反映済み。
- **重要な方針転換:** ホスティングが確定し、過去のコミット`8e00019`の決定(GitHub Pages
  本番/cyberhome廃止)を上書きした。確定内容: ホームページ本体とダウンロード機能は
  Cyberhome/Apache、問い合わせ機能はVercel、ソース管理はいずれもGit/GitHub。GitHub Pages
  は本番ホスティングとしては使わない。フェーズ3着手時、現在のリポジトリ構成
  (ルート直下にGitHub Pages前提で統合済み)が新方針とどう整合するか要検討。
- 残る唯一の未解決事項はDB技術選定(9番)。意図的にフェーズ3/4へ委譲(外部仕様の
  ブロッカーではない)。制約: 「バイブコーディングしやすい」構成、無料枠で開始し
  将来Azureへ移行予定。
- `docs/specs/README.md` の進捗ボード・未解決事項節も更新済み。

**次のアクション:** フェーズ1は実質完了。次に着手する際は `/clear` 後、フェーズ2
(p2-external-spec-reviewer)として `docs/specs/external-spec.md` の整合性レビューを行う
(このAgent種別は現行環境のAgentツールに登録されていないため、手動でp2の役割を担って
レビューするか、環境側でproject-level agentが利用可能になってから実行すること)。

---

## 2026-08-01: チェックポイント4 — フェーズ2レビュー実施、承認

- p2-external-spec-reviewerのチェックリスト(内部整合性/完全性/スコープ逸脱/テスト可能性)
  に沿って手動でレビューを実施(Agent種別が環境未登録のため代行)。ブロッキングな矛盾は
  見つからず、`docs/specs/external-spec.md` を「承認」ステータスに更新。
- 非ブロッキングのコメント3件を記録: (1) チャットUIの「全ページ共通」という表現が
  1ページ構成の記述とやや紛らわしい、(2) FAQ初期0件時の空状態UI方針を明記すべき、
  (3) 設立年2030年(未来日付)の対外表記を一度確認した方がよい。
- **ユーザーが承認後の`external-spec.md`に自ら加筆修正を行う予定。** 次回再開時は
  ファイルの現状を必ず読み直し、承認時点(このチェックポイント)から実質的な変更が
  あった場合はフェーズ3着手前に再レビューを検討すること。

**次のアクション:** ユーザーによる`external-spec.md`の加筆修正を待つ。修正内容を確認した
上で、フェーズ3(p3-architecture-researcher)へ進む。

---

## 2026-08-01: 作業一時停止(本日夜に再開予定)

- チェックポイント1〜4の内容をコミット済み(`076cdde`)。作業ツリーはクリーン
  (`.claude/settings.local.json`のローカル設定差分のみ残存、無害)。
- 停止時点のステータス: フェーズ1完了・フェーズ2承認済み。DB技術選定のみ
  フェーズ3/4へ委譲。ホスティング方針(cyberhome/Apache + Vercel)確定済み。
- ユーザーは本日夜に作業再開予定。再開までの間に`external-spec.md`へ本人が加筆修正を
  行う可能性がある。**再開時は必ずファイルを読み直し、このチェックポイント
  (commit `076cdde`)から変更があるか確認すること。**

---

## 2026-08-01: チェックポイント5 — フェーズ3着手、質問リスト32項目を提示

- `external-spec.md` を再確認し、承認時点(commit `076cdde`)から変更がないことを確認した
  上でフェーズ3(利用アーキテクチャー調査)に着手。
- 現行リポジトリ構成(`package.json`/`vercel.json`/`api/send-email.js`/`.env.example`等)を
  調査し、既存資産(nodemailer+Gmail SMTP実装済み・未動作、GitHub Pages前提の統合構成、
  Vercel側は静的サイト全体も配信する設定になっており確定済みホスティング方針と不整合、
  `chat.html`未実装、ダウンロード機能未着手)を把握した。
- Phase 1と同様の2段階方式(質問提示→回答待ち→ドラフト確定)を採用し、以下8領域・
  32項目の質問リストを作成し `docs/specs/architecture.md`(ステータス「調査中」)に記載:
  A. Cyberhome/Apache側技術スタック(9問) / B. Vercel側技術スタック(7問) /
  C. データベース選定(4問) / D. 認証・秘密情報管理(2問) / E. Cyberhome⇔Vercel連携
  (3問) / F. リポジトリ構成・デプロイフロー(3問) / G. 開発・テスト環境・監視(2問) /
  H. コスト・運用の制約(2問)。
- `docs/specs/architecture.md`の「技術要件」「候補と比較」「決定事項」は未記入のまま
  (回答待ちのため意図的に空欄)。`docs/specs/README.md`の進捗ボード・未解決事項も
  この状態に合わせて更新済み。
- コードは書いていない。実装作業は未着手のまま。

**次のアクション:** ユーザーから32項目への回答を得る。回答後、`docs/specs/architecture.md`
の技術要件導出・候補比較・決定事項を確定させ、フェーズ4(内部仕様調査)へ引き継ぐ。

---

## 2026-08-01: チェックポイント6 — 未コミット削除の整理、`/clear`前の保存

- 作業ツリーに未コミットの削除(`README.md`・`package.json`・`.gitignore`)が残っていることに
  気付き、内容を確認した。`README.md`と`package.json`は「GitHub Pagesを本番とする」旧方針
  (チェックポイント3で上書き済み)を前提にした古い内容だったため、ユーザーの判断で
  **削除を確定してコミット**(`007e9a3`)。`.gitignore`は方針変更と無関係な内容
  (node_modules/.env除外)だったため**復元**し、同コミットに含めた。これにより
  `node_modules/`・`.env.local`が未追跡ファイルとして出ていた状態も解消。
- `.claude/settings.local.json`のローカル権限差分(git reset、gh pr create、rm -rf src等の
  許可追加)も同コミットに含めて保存。
- コミット後、作業ツリーはクリーン。ローカルの`main`はorigin/mainより4コミット進んでいる
  (push未実施、ユーザーからの指示待ち)。
- ユーザーはこの後`/clear`を実行し、再開後すぐにフェーズ3の32項目質問リストへの回答を
  投入する予定。**次回再開時は、まず本ファイルと`docs/specs/README.md`を読み、
  `docs/specs/architecture.md`の32項目に対するユーザーの回答を受け取ってから、
  「技術要件」「候補と比較」「決定事項」の確定に進むこと。**

**次のアクション:** ユーザーからの32項目回答を待つ(`/clear`後、直ちに投入される見込み)。
回答が来たら`docs/specs/architecture.md`を確定させ、フェーズ4へ引き継ぐ。

---

## 2026-08-01: チェックポイント7 — 32項目回答を反映、フェーズ3を実質確定(要確認1件を除く)

- ユーザーから32項目の質問リスト全てに回答を受領。`docs/specs/architecture.md`の
  各質問直下に回答を転記した上で、「技術要件」「候補と比較(静的コンテンツ/動的コンテンツ/
  データベース)」「決定事項」を確定させた。あわせて、深掘り依頼のあった以下5点について
  具体案を作成・記載: (1) Apache Basic認証(`.htaccess`/`.htpasswd`)の詳細仕様(配置・
  ハッシュ形式・年次更新手順)、(2) Cyberhomeに標準アクセスログがない制約下でのログ取得
  方法(ダウンロード・QR遷移ページをCGI経由にし、`REMOTE_USER`/`REMOTE_ADDR`をコアPerlで
  自前記録)、(3) Vercel Python(FastAPI)実装+将来のAzure PaaS(Azure Functions/App
  Service)移行を見据えた比較、(4) DB候補の再精査(Postgres限定せずNeon/Supabase/
  Airtableを比較、月1000円以下・月10件規模という制約を踏まえ**MVPではDB自体を導入
  しない**という結論に到達)、(5) `/site`(Cyberhome用)・`/api`(Vercel用)のモノレポ内
  ディレクトリ分割 vs リポジトリ分割の比較(モノレポ分割を採用)。
- Cyberhomeの公開スペック情報(https://www.cyberhome.ne.jp/service/homepage/ )を
  WebFetchで追加調査し、ディスク容量50MB・改行コードLF限定・FTPS(Explicit)必須・
  DBサービス提供なし等の制約を確認、`architecture.md`のQ9回答欄に反映した。
- **重要な矛盾を検出・エスカレーション:** B節の回答(Q11/Q14/Q31)が「問い合わせフォーム
  処理・メール送信をCyberhome側Perl CGI+sendmailを軸に構築してほしい」という趣旨を
  3回にわたり明示しており、これは承認済み`external-spec.md`の「問い合わせ機能(フォーム
  処理・DB等) → Vercel」という記載と直接矛盾する。役割上のルールに従い、無断で上書き
  せず、`architecture.md`に推奨案(Cyberhome側CGIでフォーム処理・メール送信・ログを担当、
  Vercelは FAQ/チャットAPIとreCAPTCHA検証(Vercel側でGoogle siteverifyを代行し、
  HMAC署名付きトークンをCyberhome側へ引き渡す方式)のみに縮小)を明記した上で、
  「追加質問1(最重要・ブロッキング)」としてユーザーの最終確認を求める形にした。
- 副次的な発見として、Vercelの無料(Hobby)プランが非商用・個人利用限定という利用規約を
  持つことが判明し、書籍販売という商用サイトでの利用にはPro化(月20ドル程度)が必要に
  なる可能性がある点を追加質問2として記録した(Q20の「月1000円以下」という予算目標と
  緊張関係にあるため)。
- `docs/specs/architecture.md`冒頭の承認ステータスを「ドラフト確定(要ユーザー確認1件)」
  に、`docs/specs/README.md`のダッシュボード・進捗ボード・未解決事項節も同じ状態に
  合わせて更新した。
- 本チェックポイントではコードは一切書いていない(ドキュメント更新のみ)。
  Gitコミットも実施していない(呼び出し元が別途実施する方針のため)。

**次のアクション:** ユーザーから追加質問1(問い合わせ機能のホスティング分担の最終確認)
への回答を得る。回答が得られ次第、`external-spec.md`のホスティング方針表・DB記載を
軽微修正した上で、フェーズ4(p4-internal-spec-researcher、内部仕様調査)へ引き継ぐ。
追加質問2〜6はフェーズ4と並行して確認を進めてよい。

## 2026-08-01: チェックポイント8 — 追加質問1・2をユーザーが確定、フェーズ3完了・フェーズ4着手可能

- チェックポイント7で提示した「追加質問1(最重要・ブロッキング)」について、ユーザーに
  AskUserQuestionで確認したところ、**推奨案(Cyberhome側Perl CGIでフォーム処理・
  メール送信・ログ、VercelはFAQ/チャットAPIとreCAPTCHA検証のみ)で確定**の回答を得た。
- 「追加質問2(Vercel Hobbyプランの商用利用規約リスク)」についても、**リスクを許容して
  Hobbyプランのまま進める**ことが確定した(月1000円以下という予算目標を優先)。
- 上記確定を反映し、以下を更新:
  - `docs/specs/external-spec.md`: 「ホスティング方針」表に問い合わせ機能の内部分担
    (Cyberhome=フォーム処理・メール送信・ログ、Vercel=FAQ/チャットAPI・reCAPTCHA検証)を
    追記、「問い合わせ内容はDBに保存し」の一文を「DBはMVPでは導入しない」に修正。
    承認ステータス自体(「承認」)は変更していない(軽微な追記修正のため)。
  - `docs/specs/architecture.md`: 承認ステータスを「ドラフト確定(フェーズ4引き継ぎ準備
    完了)」に変更。「★要ユーザー確認」の表記を「確定・ユーザー承認済み」に更新。
    「追加質問」1・2に確定内容を追記(取り消し線+結論)。
  - `docs/specs/README.md`: ダッシュボード・進捗ボード・スコープメモ・未解決事項節を
    フェーズ3完了・フェーズ4着手可能な状態に更新。
- 追加質問3〜6(Cyberhome契約プランの正確な月額費用、文字コード/Apacheバージョンの
  実機確認、`AuthUserFile`絶対パス、reCAPTCHAキー)は非ブロッキングのまま残置。
  フェーズ4と並行して確認する。
- 本チェックポイントの後、ユーザーの指示によりgitコミット・ローカル保存を実施する。

**次のアクション:** フェーズ4(p4-internal-spec-researcher、内部仕様調査)に着手する。

## 2026-08-02: チェックポイント9 — フェーズ4着手前の曖昧さ撲滅(280問)完了

- ユーザー指示により、フェーズ4着手前に3択形式の質問で曖昧さを完全撲滅する追加ラウンドを
  実施。`docs/specs/phase4-clarification.md`に記録。
- ラウンド1・2(各50問、ビジネスロジック中心)+インフラ深掘りラウンド1〜5(各30問、
  Web/DB/Python技術基盤+最終ラウンドはユーザー指示により保守性テーマに変更)、
  合計280問すべてに回答を得た。
- 主な追加決定: DB(Neon)はFAQ管理Web GUI用に限定して前倒し導入(MVPリリース直後の
  最初の保守作業として着手)。GUI認証はbcrypt+セッション/JWT(1週間)+CSRF+ログイン
  試行制限+IP制限。`.gitattributes`でLF強制、コミットメッセージ英語統一、GitHubは
  Private維持。**保守サイクル(フェーズ10)は大きい機能追加でも常に軽量な
  p10-maintainerプロセスで対応する方針に転換**(`docs/specs/README.md`ゲートルールに反映)。
- ブロッキングな矛盾はすべて解消。フェーズ4への引き継ぎ準備が整った。

## 2026-08-02: チェックポイント10 — フェーズ4(内部仕様調査)完了、6サブエージェント分割実行

- ユーザー承認済みの分割案(Wave1: データモデル/リポジトリ・CI-CD/連携契約 → Wave2:
  Cyberhome側Perl CGI/Vercel側FastAPI → Wave3: テスト・デプロイ検証)に沿って
  p4-internal-spec-researcherを6回ディスパッチ(各自fresh contextで担当領域のみ設計)。
- 成果物: `docs/specs/internal-spec.md`(統合窓口)+
  `internal-spec-datamodel.md`・`internal-spec-repo-cicd.md`・
  `internal-spec-integration.md`・`internal-spec-cyberhome.md`・
  `internal-spec-vercel.md`・`internal-spec-testing.md`(各詳細設計)。
- 各エージェントには「280問の確定回答から導出できることは質問せず自ら決定し、
  genuinely未決定な事項のみ3択で提示する」よう指示。結果、Wave間の食い違い7件は
  すべて後続エージェントが自己解決(例: download.cgiのBasic認証の掛かり方、
  書籍別パスワードと単一CGIスクリプトの両立、HMAC環境変数名の統一、`/health`の
  ルーティング方式)。最終的な追加質問はわずか4件(GUIパスワードリセットのメール経路、
  `Contents/`配下ダウンロードファイルのGit管理方針、CGIファイル実行権限の扱い、
  問い合わせフォーム自動疎通確認の範囲)。
- 私(オーケストレーター)が全6ドキュメントを精読し`internal-spec.md`に統合編纂、
  横断的な矛盾チェックを実施(2章に食い違いの解決記録、3章に追加質問4件を整理)。
- 本チェックポイントの後、ユーザーの指示によりgitコミット・ローカル保存を実施する。

**次のアクション:** `docs/specs/internal-spec.md`の追加質問4件への回答を得て、
フェーズ5(p5-internal-spec-reviewer、内部仕様最終レビュー・確定)に着手する。

## 2026-08-02: チェックポイント11 — 内部仕様の追加質問4件に回答、フェーズ4完全完了

- ユーザーが`docs/specs/internal-spec.md`の追加質問4件に即日回答:
  1. FAQ管理GUIのパスワードリセット: C) メール送信を廃止し、忘れた場合はClaude Codeが
     NeonへSQLを直接発行して更新する運用に変更。`internal-spec-datamodel.md`の
     `gui_accounts`テーブルから`password_reset_token`関連カラムを削除、
     `internal-spec-vercel.md`の管理画面ルート一覧からリセット関連ルートを削除。
  2. `Contents/`配下ダウンロードファイル: A) Gitで通常のバイナリ管理(除外設定・
     LFSなし)に確定。
  3. `.cgi`ファイルの実行権限: A) 自動実行可能の前提のまま進める(既存デフォルトを
     確認)。
  4. 問い合わせフォーム自動疎通確認: 当初のB案(Google公式テストキーで正常系も
     毎日自動送信)を選んだが、**Cyberhome側`contact.html`が静的で環境による
     出し分けができないため、`contact.cgi`を一切変更せずに実現するには
     Vercel側`/api/verify-recaptcha`に最低限のCI判別分岐が必要**という技術的な
     制約を発見・ユーザーに提示。ユーザー承認によりB′案(Vercel側のみに
     `X-Smoke-Test-Auth`ヘッダー判定+Google公式テストシークレットキーへの
     切替分岐を追加)に調整して確定。`internal-spec-vercel.md`に9章として実装設計を
     新設、`internal-spec-testing.md`のシナリオ#4・2.5節・GitHub Secrets一覧を更新。
- 6本の詳細設計ドキュメントすべてに反映済み。新たな未決定事項は発生していない。
- `docs/specs/internal-spec.md`の承認ステータスを「全追加質問解消、フェーズ5引き継ぎ
  準備完了」に更新。`docs/specs/README.md`のダッシュボード・進捗ボードも同期。
- **フェーズ4(内部仕様調査)は完全に完了した。**

**次のアクション:** フェーズ5(p5-internal-spec-reviewer、内部仕様最終レビュー・確定)に
着手する。`docs/specs/internal-spec.md`と6本の詳細設計ドキュメントの整合性を確認し、
承認または差し戻しを判断する。

## 2026-08-02: チェックポイント12 — フェーズ5(内部仕様最終レビュー・確定)実施、承認

- `docs/PROJECT_STATUS.md`・`docs/specs/README.md`・`docs/specs/external-spec.md`
  (承認済み)・`docs/specs/architecture.md`(ドラフト確定)を再確認した上で、
  `docs/specs/internal-spec.md`と6本の詳細設計ドキュメント(`internal-spec-datamodel.md`,
  `internal-spec-repo-cicd.md`, `internal-spec-integration.md`,
  `internal-spec-cyberhome.md`, `internal-spec-vercel.md`, `internal-spec-testing.md`)を
  全文精読レビューした。
- チェック観点: (1) トレーサビリティ(外部仕様の各要件が内部仕様のどこに実装されるか、
  逆に内部仕様の各項目が承認済み外部仕様/アーキテクチャに遡れるか)、(2) API契約の
  明確性(リクエスト/レスポンス形状・エラーケース・認証要件が実装時に迷わないか)、
  (3) データモデルの妥当性(FAQ/問い合わせ/ダウンロード権限まわりの欠落有無)、
  (4) 単体テスト方針の具体性、(5) 既存資産(`api/send-email.js`等)との整合性。
- **結論: ブロッキングな矛盾・欠落なし。`docs/specs/internal-spec.md`を「承認」に
  更新した。** 非ブロッキングコメント4件を記録:
  1. `internal-spec-repo-cicd.md` 7.3節の環境変数名が旧名`HMAC_SHARED_SECRET`のまま
     未修正(正式名称`INTEGRATION_HMAC_SECRET`との不一致、internal-spec.md 2章で
     既知の問題として記録されていたが実ファイルは未修正)。
  2. `internal-spec-vercel.md` 5.1節のレート制限の実装根拠が「確定前提」と記載されて
     いるが、`phase4-clarification.md`(全280問)・`architecture.md`のいずれにも
     該当する確定回答が見当たらない(実装内容自体は妥当、出典表現の修正を推奨)。
  3. `internal-spec-datamodel.md` 3.5節のCSRF記述(「FastAPIの標準的なCSRFトークン
     機構を使用」)が技術的に不正確(FastAPIに標準CSRF機構はない)。
     `internal-spec-vercel.md` 7.2節が正しい実装方針(ダブルサブミット方式の独自実装)を
     示しているため、実装上のブロッカーではない。
  4. (任意)reCAPTCHAトークン有効期限(300秒)切れのUXケースをフェーズ8受け入れ
     テストで一度手動確認することを推奨。
- `docs/specs/architecture.md`末尾の「追加質問」3〜6(Cyberhome契約プラン詳細・実機
  確認事項)は指示通り非ブロッキングとして扱い、これ自体を理由に差し戻していない。
- `docs/specs/internal-spec.md`冒頭に承認セクションを追記し、`docs/specs/README.md`の
  ダッシュボード・進捗ボード・完了済みリスト・残タスクを同期した。本チェックポイントの
  内容はドキュメント更新のみで、コードは一切書いていない。

**次のアクション:** フェーズ6(p6-implementer、実装・単体テスト)に着手する。着手時は
上記非ブロッキングコメント1〜3を実装の早い段階で解消することを推奨する。

## 2026-08-02: チェックポイント13 — フェーズ6着手、Task#1(リポジトリ構成・CI/CD基盤)完了

- フェーズ6の依存グラフのうち、他タスクの土台となるTask#1
  (`docs/specs/internal-spec-repo-cicd.md`のリポジトリ構成・CI/CD骨格)を実装した。
- **フェーズ5非ブロッキングコメント1〜3の解消(実装前の下準備、別コミット):**
  `internal-spec-repo-cicd.md` 7.3節の環境変数名を`HMAC_SHARED_SECRET`から
  `INTEGRATION_HMAC_SECRET`に統一、`internal-spec-vercel.md` 5.1節の出典表現を
  「確定前提」から「Wave2の裁量による追加」に修正、`internal-spec-datamodel.md` 3.5節の
  CSRF記述をFastAPI標準機構という誤った説明から`internal-spec-vercel.md` 7.2節準拠の
  ダブルサブミット方式の記述に修正(コメント4件目のreCAPTCHA期限切れUX確認はフェーズ8
  スコープのため対象外)。
- **モノレポ構成への移行:** ルート直下の`index.html`・`css/`・`js/`・
  `public/robots.txt`・`public/sitemap.xml`を`site/`配下へ`git mv`で移設
  (`internal-spec-repo-cicd.md` 1.2節の構成に対応する部分のみ。内容自体は精査・
  書き換えせず既存のまま移動)。
- **Node.js関連資産の全面廃棄(`architecture.md`決定事項2、移行方針表通り):**
  `api/send-email.js`・`package-lock.json`・`node_modules/`・`scripts/dev-server.js`・
  ルート直下`vercel.json`(旧・静的サイト全体配信設定)・`.env.example`/`.env.local`
  (旧SMTP用)を削除。`scripts/setup.ps1`は移行方針表に明記がなく削除対象と断定できな
  かったため据え置いた(下記「フェーズ4/5へのフィードバック」参照)。
- **`/api`(Vercel/FastAPI)側の新規作成:** `api/vercel.json`(Root Directory=`/api`
  前提、`index.py`への集約ルーティング)、`api/.vercelignore`、
  `api/requirements.txt`(fastapi/uvicorn/pydantic/python-multipart)、
  `api/requirements-dev.txt`(pytest/httpx/ruff)、`api/.env.example`
  (MVP必須4変数: `RECAPTCHA_SECRET_KEY`/`INTEGRATION_HMAC_SECRET`/`ALLOWED_ORIGIN`/
  `VERCEL_ENV`、`internal-spec-vercel.md` 8章の記載通り)を新規作成。
  `api/app/`(FastAPIアプリ本体・ルーター・サービス)・`api/index.py`・`api/tests/`は
  意図的に**作成していない**(Vercel側FastAPI実装は別タスクの担当領域であり、本タスクの
  スコープは「リポジトリ構成・CI/CD骨格」に限定するため。ディレクトリの雛形すら作ると
  Wave2の設計裁量を先取りすることになるため見送った)。
- **`.gitattributes`新規作成:** `internal-spec-repo-cicd.md` 2章の内容をそのまま採用
  (LF強制、CGI/Perl/`.htaccess`個別指定、バイナリファイル明示)。
- **`.gitignore`更新:** 同1.5節の追加項目(Cyberhome側非公開設定・生成ログ、
  Vercel/Python関連)を追記。既存のNode関連記述は「残置しても害はない」という同文書の
  記載に従い削除せず残した。
- **GitHub Actionsワークフロー4本を新規作成(`.github/workflows/`):**
  `deploy-cyberhome.yml`(backup→deploy→smoke-test→notify-on-failureの4ジョブ構成、
  `internal-spec-testing.md` 1章の詳細設計をそのまま採用。バックアップ方式は同文書
  1.2節の決定通りFTPSミラーダウンロード、`lftp mirror`)、`playwright-smoke.yml`
  (smoke/health-ping/notify-on-failureの3ジョブ、同文書2章・4.3節の`api/**`push
  トリガー追加とVercel healthy待ちポーリングを反映)、`api-tests.yml`
  (`ruff check`→`pytest api/tests`)、`perl-tests.yml`(`internal-spec-cyberhome.md`
  6.5節提案・`internal-spec-testing.md` 3.2節確定のTest::More実行、非破壊的追加)。
  4ワークフローともYAML構文を`js-yaml`でパース検証済み(実際のGitHub Actions実行・
  実デプロイは今回行っていない。FTPS認証情報等の実シークレットも登録していない)。
- **`/site`側の追加インフラ・設定ファイル:** `site/.ftpdeployignore`
  (`cgi-bin/lib/t/`を除外)、`site/conf/hmac_secret.example.txt`・
  `site/dl/.htpasswd.example`・`site/qr/.htpasswd.example`(すべてダミー値のみ、
  実ファイルはGit管理外でFTP配置)。`site/cgi-bin/`・`site/news/`・
  `site/templates/`・`site/Contents/`等、CGIロジックや記事コンテンツを伴う残りの
  ディレクトリは意図的に**作成していない**(Cyberhome側CGI実装は別タスクの担当領域)。
- 単体テストコード: 本タスクはスキャフォールディング(リポジトリ構成・CI/CD設定)であり、
  独立したビジネスロジックを持たないため、Perl(約67ケース)・pytest(29ケース)の
  単体テストは対象外(後続のCyberhome側/Vercel側実装タスクの担当)。ワークフローYAMLの
  構文検証(`js-yaml`によるパース確認)のみ実施し、パスした。
- **フェーズ4/5へのフィードバック(ブロッカーではない、次回整理推奨):**
  `scripts/setup.ps1`(Node.js/Python/Git確認+`npm install`実行スクリプト)が、
  ルート`package.json`の削除(チェックポイント6)・`architecture.md`決定事項9
  (ローカル開発環境を持たない方針)により実質的に陳腐化しているが、
  `internal-spec-repo-cicd.md`の移行方針表に明記がなく本タスクのスコープ外と判断し
  削除しなかった。次の内部仕様改訂または保守タスクで扱いを明確にすることを推奨する。
- 本チェックポイントはドキュメント修正・実装・状態記録の3コミットに分けて記録する
  (`docs/specs`更新は実装と別コミットにする、ラウンド4 T13=A確定方針に従う)。

**次のアクション:** フェーズ6の残りタスク(データモデル/連携契約の実装、Cyberhome側
CGI実装、Vercel側FastAPI実装、テスト・CI/CD詳細実装)に着手する。本タスクはあくまで
「土台」であり、システムテスト・E2Eテスト(フェーズ7・8)はまだ実施していない。

## 2026-08-02: チェックポイント14 — フェーズ6 Task#2(データモデル)完了

- Wave1の並行実行可能タスクのうち`docs/specs/internal-spec-datamodel.md`担当分
  (FAQ JSON schema・実データファイル・将来のNeon Postgres schemaの参照SQL)を実装した。
- **`api/app/data/faq.json`(MVP実データファイル)を新規作成:** 内容は
  `internal-spec-datamodel.md` 2.2節のスキーマ通り、`{"faq_schema_version": 1,
  "items": []}`(external-spec.md確定事項通りFAQ 0件で開始)。
  - **配置パスに関する判断(記録):** `internal-spec-datamodel.md` 2.1節は
    「本書が規定するのはファイルの中身であり、パスはAPI設計側(Wave2)の決定を
    優先してよい」と明記しており、厳密には`api/app/`配下はVercel側FastAPI実装
    (別タスク)の担当領域。しかし`internal-spec-repo-cicd.md` 1.3節と
    `internal-spec-vercel.md` 1章がいずれも独立に`api/app/data/faq.json`という
    パスで一致しており(Wave1・Wave2両方の確定事項)、内容(データそのもの)の
    唯一の出典は本タスクが担当する`internal-spec-datamodel.md`であるため、
    **`api/app/`配下に追加したのはこのデータファイル1点のみ**とし、
    `app/__init__.py`・`app/main.py`・ルーター・サービス等のFastAPIアプリ本体
    (コード)は一切作成していない(Vercel側実装タスクの担当領域のまま)。
- **`docs/specs/data/faq.schema.json`を新規作成:** `internal-spec-datamodel.md`
  2.3節・2.4節のフィールド定義・バリデーションルールをJSON Schema(draft-07)として
  形式化した参照ドキュメント。将来のPydanticモデル実装(Vercel側タスク)や手動編集時の
  参照として使うことを想定(id一意性・カテゴリ内`display_order`一意性はJSON Schema
  単体では表現できないため、その旨をファイル内に明記し、下記の`scripts/validate_faq.py`
  側で担保)。
- **`docs/specs/data/neon-schema.sql`を新規作成:** `internal-spec-datamodel.md` 3.2節の
  `faqs`/`gui_accounts`/`faq_change_log`テーブル定義+インデックスをそのままDDL化した
  参照専用SQL。ファイル冒頭に「実行を想定した稼働中のマイグレーションではない、
  DB導入自体がMVPスコープ外、現時点でNeonへの接続・提供は一切行っていない」ことを
  明記した。実データベースの作成・接続・migration-runnerの実装は一切行っていない
  (指示通り)。
- **`scripts/validate_faq.py`(新規、Python標準ライブラリのみ)を実装:**
  `internal-spec-datamodel.md` 2.4節のバリデーションルール(id正規表現、category固定
  3値、question/answer文字数・`<`/`>`禁止、display_order正の整数・カテゴリ内一意性、
  id一意性)を実装したスタンドアロンの検証ロジック+CLI
  (`python scripts/validate_faq.py <path>`)。FastAPI側Pydanticモデル
  (`api/app/models/faq.py`、Vercel側タスクの担当領域、未作成)とは独立した実装であり、
  Claude Codeが`faq.json`を手動編集する運用(2.5節)における検証ツールとして使う。
- **単体テスト:** `scripts/tests/test_validate_faq.py`(pytest、50ケース)を新規作成。
  正常系(0件/1件/複数カテゴリ/改行許容)、トップレベル構造異常、必須キー欠落、
  `id`正規表現違反、`category`不正値、`question`/`answer`の文字数境界値・空文字・
  `<`/`>`混入、`display_order`の型・範囲異常(0/負数/浮動小数点/bool/文字列/None)、
  `id`重複、同一カテゴリ内`display_order`重複、異カテゴリ間での重複許容、ファイルI/O
  異常系(存在しないファイル/不正JSON)、CLI(`main()`の戻り値0/1)、そして実際に配置した
  `api/app/data/faq.json`自体が検証を通過し0件で開始していることを確認する回帰テスト、
  を網羅する。
- **テスト実行結果:** ローカル環境にPythonが未導入だったため`winget install
  Python.Python.3.12`で導入し(pip経由でpytestも追加インストール)、
  `python -m pytest scripts/tests -v` を実行 → **50件全て成功(0.19秒)**。
  加えて `python scripts/validate_faq.py api/app/data/faq.json` のCLI実行でも
  `OK` を確認、`docs/specs/data/faq.schema.json` 自体が正しいJSONとしてパース
  できることも確認した。
- **共通命名規則(`internal-spec-datamodel.md` 1章):** 別ファイルとしての新規実装は
  行っていない(同章自体が承認済みドキュメントとして各設計ドキュメントの参照元になる
  ため、実体は既存の同ドキュメントで足りると判断)。本タスクで作成したJSON/SQLの
  キー名・テーブル名・カラム名は同章の規約(snake_case、`is_`接頭辞、
  `created_at`/`updated_at`等)にすべて準拠している。
- **JSON→DB移行方針(4章):** 移行スクリプト自体はDB未導入のMVPでは実行対象がなく
  (Neon導入は保守フェーズの最優先タスク)、`docs/specs/data/neon-schema.sql`末尾に
  移行時のINSERT文テンプレートをコメントとして記録するに留めた(指示通り、
  実際に動く移行パイプラインは実装していない)。
- **内部仕様上のブロッキングな未決定事項・ギャップ: なし。** 上記「配置パスに関する
  判断」は仕様の欠落や矛盾ではなく、実装タスクの分担(データモデル担当 vs Vercel側
  担当)に関する境界判断であり、内部仕様自体は当該ファイルの中身・パスとも一貫して
  記述されている。次にVercel側FastAPI実装タスクへ着手する際は、
  `api/app/data/faq.json`が既に存在すること・`api/app/`配下の他のファイル
  (`__init__.py`・`main.py`・`routers/`・`services/`・`models/`等)は本タスクでは
  未作成であることを踏まえて進めること。
- 本チェックポイントの後、gitコミットを実施する(データ+テストコード+ドキュメント
  更新を1コミットにまとめる、リポジトリの既存コミット慣行に合わせ英語のコミット
  メッセージとする)。

**次のアクション:** フェーズ6の残りタスク(連携契約の実装、Cyberhome側CGI実装、
Vercel側FastAPI実装、テスト・CI/CD詳細実装)に着手する。Vercel側FastAPI実装タスクは
`api/app/data/faq.json`(本タスクで作成済み)を`app/data/`配下にそのまま読み込む形で
`app/`配下の残り一式(`__init__.py`・`main.py`・`core/`・`middleware/`・`routers/`・
`models/`・`services/`・`db/`・`templates/`・`static/`)を新規実装すればよい。
本タスクはデータモデル・単体テストのみであり、システムテスト・E2Eテスト
(フェーズ7・8)はまだ実施していない。

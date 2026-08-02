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

## 2026-08-02: チェックポイント15 — フェーズ6 Task#4(Vercel/FastAPI実装、Wave2)完了

- `docs/specs/internal-spec-vercel.md`(+`internal-spec-integration.md`のVercel側契約)に
  基づき、`/api`配下にFastAPIアプリ本体一式を新規実装した。`api/app/data/faq.json`
  (Task#2で作成済み)以外の`api/app/`配下は本タスクで新規作成。
- **実装したファイル:**
  - `api/index.py`(Vercelエントリポイント、`app.main.app`をre-export)
  - `api/app/main.py`(FastAPI生成、lifespan起動時FAQ検証、CORSMiddleware、
    ルーター登録。管理GUI用`admin`ルーターは1.1節の通りコメントアウトのまま)
  - `api/app/core/config.py`(pydantic-settings、環境変数`INTEGRATION_HMAC_SECRET`
    表記で統一済み。9章のCI検証バイパス用に`SMOKE_TEST_SECRET`・
    `RECAPTCHA_TEST_SECRET_KEY`も追加)、`logging_config.py`、`request_utils.py`
    (`get_client_ip`、`X-Forwarded-For`優先)
  - `api/app/middleware/rate_limit.py`(5章の簡易インメモリレート制限、
    `/api/faq`=60回/5分、`/api/verify-recaptcha`=10回/5分)
  - `api/app/models/faq.py`(ファイル用`FaqFile`/`FaqFileItem`とAPI応答用
    `FaqApiResponse`/`FaqApiItem`を分離、0.3節の変換層設計通り)、
    `api/app/models/recaptcha.py`(`RecaptchaOutcome`)
  - `api/app/services/faq_service.py`(`faq.json`読み込み・検証・カテゴリ順
    ソート・API形式への変換、`lru_cache`)、
    `api/app/services/recaptcha_service.py`(Google siteverify呼び出し、
    fail-open/fail-closedの分岐、HMACトークン発行、9章のCI検証バイパス用
    `_resolve_secret_key`を実装)
  - `api/app/routers/faq.py`(`GET /api/faq`)、`recaptcha.py`
    (`POST /api/verify-recaptcha`、リクエストボディを手動パースし契約通りの
    400/500を返す設計、3.2節の通り)、`health.py`(`GET /health`、プレフィックスなし)
  - `api/tests/conftest.py`・`test_faq.py`(12ケース)・`test_recaptcha.py`
    (14ケース)・`test_health.py`(3ケース)、合計**29ケース**(6.3/6.4/6.5節の
    テスト計画表と1対1で対応)
  - `api/requirements.txt`に`pydantic-settings`・`httpx`を追加
    (recaptcha_service.pyの本番実行に必須。1.3節の指示通りpydantic-settingsを
    追加。httpxは本番コードが直接importするため、6.1節がdev依存として提案して
    いたものを本番側にも追加した。**Task#1が置いたrepo-cicd.md準拠の当初内容には
    含まれていなかった、実装上必要な追加**)。`requirements-dev.txt`に
    `pytest-asyncio`・`respx`を追加(6.1節の提案通り)。
  - `.gitignore`に`api/.ruff_cache/`を追加(ruff実行で生成される、既存の
    `.pytest_cache`除外と同様の追加)。
- **`app/db/`・`app/templates/`・`app/static/`・`app/routers/admin.py`・
  `app/services/auth_service.py`は意図的に作成していない。** 7章冒頭が
  「本節は保守サイクル(フェーズ10)での実装対象であり、フェーズ6(実装)の
  スコープ外である」と明記しているため、スタブすら作らずフェーズ10に委ねた。
- **タスク指示とinternal-spec-vercel.mdの間で見つけたギャップ(フェーズ4/5への
  フィードバック、ブロッカーではない、CSRF実装は見送り):** 本タスクの実装指示には
  「CSRF double-submit-cookie implementation per §7.2」という一文があったが、
  `internal-spec-vercel.md` 7.2節は「7. 将来のFAQ管理GUI付録」節の内部にあり、
  同節冒頭に明示的に「本節は保守サイクル(フェーズ10)での実装対象であり、
  フェーズ6(実装)のスコープ外である」と記載されている。また7.2節のCSRF設計は
  Jinja2管理画面フォーム(`{{ csrf_token }}`)向けであり、本タスクが実装した
  `GET /api/faq`・`POST /api/verify-recaptcha`・`GET /health`はいずれもCookie・
  セッションを一切使わないステートレスJSON APIで、CSRFの前提となる
  「ブラウザが自動送信する認証Cookie」が存在しない(6章のpytestテスト計画
  (12+14+3=29件)にもCSRF関連テストは1件も含まれていない)。管理GUI自体
  (`admin.py`ルーター)もフェーズ10まで未実装であるため、CSRF対策を適用する
  対象ルートが現時点で存在しない。以上により、**本タスクではCSRFミドルウェアを
  実装していない**(スコープ外の機能を先取りして作り込むと7章が明示的に戒めて
  いる「フェーズ10で設計をゼロから起こし直さずに済むよう先に記録した設計」を
  先取り実装することになり、実装者の裁量を超えると判断した)。フェーズ10で
  FAQ管理GUI(`admin.py`)に着手する際に、7.2節の設計に従ってCSRF対策を
  実装すべき。
- **単体テスト実行結果:** ローカルにPython 3.12.10が導入済み(前タスクの
  `winget install Python.Python.3.12`による)。`api`配下で
  `pip install -r requirements.txt -r requirements-dev.txt`を実行後、
  `python -m pytest tests -v`を実行 → **29件全て成功(3.3〜3.6秒程度)**。
  `python -m ruff check app index.py tests`も実施し、インポート順序の
  自動修正(`--fix`)+`except Exception`への`noqa`コメント追加を経て
  **All checks passed**を確認した。respxでGoogle siteverify呼び出しを
  モックし、実際のGoogle API・実際の`RECAPTCHA_SECRET_KEY`・実際の
  `INTEGRATION_HMAC_SECRET`はいずれも使用していない(テスト専用のダミー値
  `test-recaptcha-secret`/`test-hmac-secret`等を`conftest.py`で設定)。
  実際のVercelデプロイ・実際のGoogle reCAPTCHA本番キーでの動作確認は
  一切行っていない。
- 本チェックポイントの後、gitコミットを実施する(実装+テストコード+
  ドキュメント更新をまとめる)。

**次のアクション:** フェーズ6の残りタスク(Cyberhome側CGI実装は並行タスクとして
別途進行中、テスト・CI/CD詳細実装)に着手する。本タスクはあくまで単体テスト
(pytest 29ケース)までであり、システムテスト・E2Eテスト(フェーズ7・8)は
まだ実施していない。上記CSRFのギャップはフェーズ10(FAQ管理GUI実装)着手時に
解消すること。

## 2026-08-02: チェックポイント16 — フェーズ6 Task#3(Cyberhome側Perl CGI実装、Wave2)完了

- `docs/specs/internal-spec-cyberhome.md`(+`internal-spec-integration.md`のCyberhome側
  HMAC検証契約)に基づき、`/site`配下にPerl CGI一式(`contact.cgi`/`download.cgi`/
  `news.cgi`)・`.pm`モジュール4本・QRページ・`.htaccess`確定版を新規実装した。
  `/api`配下(並行実行中のTask#4)は一切変更していない。
- **実装したファイル:**
  - `site/cgi-bin/lib/Common.pm`(`html_escape`/`strip_newlines`/
    `resolve_script_dir`/`read_secret_file`/`render_template`/`write_log`/
    `render_error_page`/`install_die_handler`/`iso8601_now`。CPAN不可のため
    File::Basename・Cwd・File::Spec・Fcntlのみ使用)
  - `site/cgi-bin/lib/ContactLogic.pm`(`validate_input`/`verify_token`
    (`internal-spec-integration.md` 1.2節のPerlサンプルをそのまま実装、
    `Digest::SHA::hmac_sha256_hex`使用)/`is_duplicate_submission`/
    `is_business_hours`/`build_notification_mail`/`build_autoreply_mail`/
    `send_via_sendmail`(シェルを経由しないリスト形式`open('|-', ...)`))
  - `site/cgi-bin/lib/DownloadLogic.pm`(`resolve_mime_type`(拡張子ハードコード
    表、`File::MimeInfo`不使用)/`validate_file_param`/`authorize_book_access`
    (`%BOOK_USERS`マッピング)/`rotate_log_if_needed`/`format_access_log_line`)
  - `site/cgi-bin/lib/NewsLogic.pm`(`list_article_files`/`parse_article_file`
    (2行目カテゴリの寛容パース、認識できない文字列は本文とみなし既定値
    「お知らせ」にフォールバック)/`render_list_html`/`render_detail_html`)
  - `site/cgi-bin/contact.cgi`・`download.cgi`・`news.cgi`(CGI入出力の配線のみ、
    ビジネスロジックは上記`.pm`に分離。3CGIとも`eval{}`+`Common::install_die_handler`
    で500エラーを捕捉、`Status:`ヘッダーを明示的に出力)
  - `.htaccess`確定版6本: `site/cgi-bin/.htaccess`(新設、`<Files "download.cgi">`
    のみBasic認証)、`site/cgi-bin/lib/.htaccess`・`site/conf/.htaccess`・
    `site/Contents/.htaccess`(新設、`Require all denied`)、`site/dl/.htaccess`・
    `site/qr/.htaccess`(確定版に更新、`AuthName`を3箇所で完全一致させる、
    0.2節のrealm共有の工夫)
  - `site/qr/book1.html`・`book2.html`(静的QRランディングページ、
    `download.cgi`への案内リンクを含む)
  - `site/templates/header.html`・`footer.html`(`news.cgi`が文字列連結で
    使う最小限の共通HTML断片。既存`site/index.html`のnav構造を踏襲)
  - `site/cgi-bin/lib/t/Common.t`(14)・`ContactLogic.t`(27)・
    `DownloadLogic.t`(19)・`NewsLogic.t`(7)、**合計67ケース**
    (`internal-spec-testing.md` 3.1節の内訳表と1対1で対応)
  - `site/cgi-bin/*.cgi`に実行権限(+x)を付与(追加質問Q1=A確定方針の通り、
    Cyberhome側の自動実行可能前提を維持しつつGit側でも権限を記録)
- **意図的に作成していないもの(スコープ外、次タスクへの申し送り):**
  `site/contact.html`・`contact-thanks.html`・`privacy.html`・`news.html`
  (記事一覧の静的入口ページ)は本タスクの指示範囲(`contact.cgi`/`download.cgi`/
  `news.cgi`/QRページ/`.htaccess`/`.pm`モジュール/HMAC連携/単体テスト)に
  含まれていなかったため作成していない。`contact.cgi`は`../contact.html`を
  `Common::render_template()`で読み込み、`<!--CONTACT_ERRORS-->...<!--/CONTACT_ERRORS-->`
  ブロック型プレースホルダーと`<!--VALUE:last_name-->`等の値型プレースホルダーを
  置換する設計で実装済みだが、**現時点では`site/contact.html`自体が存在しないため、
  実機デプロイ後にこのファイルが正しいプレースホルダーを含む形で用意されない限り、
  `contact.cgi`はバリデーションエラー時に落ちる(die→500エラーページ)。**
  これは`internal-spec-cyberhome.md`の設計自体の欠落ではなく(2.8節はテンプレートの
  中身の詳細まで規定していない)、タスク分担上のギャップであるため、フェーズ4/5への
  差し戻しではなくフェーズ6の次のタスク割り当て(静的ページ実装)側で
  `contact.html`に上記プレースホルダーを含めるよう申し送る。`news.cgi`は
  `templates/header.html`/`footer.html`(本タスクで作成済み)のみに依存するため、
  この制約を受けない(単体では動作可能)。
- **単体テスト実行結果:** ローカル環境にPerl 5.42(Cygwin、Perl 5.16よりかなり新しいが
  本タスクで使用した機能はいずれも5.16のコアモジュールの範囲内)が導入済み。
  `CGI.pm`はこのローカル環境にインストールされていなかったため(Perl 5.20以降で
  コアから外れたモジュール。Cyberhome実機のPerl 5.16ではコア同梱のため問題ない)、
  `perl -c`によるCGIスクリプト3本の構文検証のみ、ローカルの一時ディレクトリに
  置いた最小限のダミー`CGI.pm`スタブ(`new`/`param`のみ、非シップ)を`PERL5LIB`に
  加えて実施し、3本とも構文エラーなしを確認した。`.pm`モジュール4本は本物の
  `Digest::SHA`/`Time::Local`/`File::Temp`等のコアモジュールでそのまま
  `perl -I. t/*.t`を個別実行し、**67件全て成功**(`Common.t`14/14、
  `ContactLogic.t`27/27、`DownloadLogic.t`19/19、`NewsLogic.t`7/7)。
  CI(`perl-tests.yml`、Task#1で作成済み)は`ubuntu-latest`+標準Perlで
  `prove -l site/cgi-bin/lib/t/`を実行する設計であり、ローカルではCygwin環境の
  Perlパッケージが不完全で`prove`本体(`TAP::Harness`)自体が動作しなかったため、
  同等の検証を`perl`個別実行で代替した(4ファイルの実行結果を手動で合算し67/67を
  確認、CI環境側は標準的なPerlディストリビューションのため`prove`自体は
  正常に動作する見込み)。
- **実機での動作確認は一切行っていない**(Apache mod_cgi・実際の`sendmail`・
  実際のBasic認証・実際のFTPSデプロイのいずれも本タスクの範囲外)。`sendmail`
  呼び出しは`send_via_sendmail`の第2引数(実行ファイルパス)をテスト用のダミー
  実行可能ファイルに差し替えてモックした。
- 本チェックポイントの後、gitコミットを実施する(実装+テストコード+
  ドキュメント更新をまとめる)。

**次のアクション:** フェーズ6の残りタスク(テスト・CI/CD詳細実装)に着手する。
静的ページ実装タスク着手時は、上記「意図的に作成していないもの」の申し送りに従い
`site/contact.html`(+`contact-thanks.html`・`privacy.html`)に
`contact.cgi`が要求するプレースホルダーコメントを含めること。本タスクは単体テスト
(Perl Test::More 67ケース)までであり、システムテスト・E2Eテスト(フェーズ7・8)は
まだ実施していない。

## 2026-08-02: チェックポイント17 — フェーズ6 静的ページ実装(gap-fill、Task#3の申し送り解消)完了

- Wave1(リポジトリ構成)・Wave2(Cyberhome側CGI)のいずれのタスクも「実際のページ
  内容・コピーはスコープ外」と判断して着手しなかった、`docs/specs/internal-spec-repo-cicd.md`
  §1.1のディレクトリツリーが要求する`site/contact.html`・`contact-thanks.html`・
  `privacy.html`・`news.html`(未作成)と`site/index.html`(旧・英語プレースホルダー
  のまま放置)を、事後発覚したギャップとして実装した。
- **新規作成:** `site/contact.html`・`site/contact-thanks.html`・`site/privacy.html`・
  `site/news.html`。**更新:** `site/index.html`(旧Node.js時代の英語プレースホルダー
  content — `/api/send-email`宛のfetch・`chat.html`への未実装iframe参照を含む — を、
  `external-spec.md`の確定事項(会社名FroEduX/代表者とどほっけ太郎/所在地川崎市
  中原区宮内/電話なし/メールは作成中/営業時間平日10-17時/設立2030年)に基づく
  日本語コンテンツへ全面的に書き換え)。
- **`contact.html`の構造は`internal-spec-cyberhome.md` 2.1節・2.8節の契約に厳密に
  従った:** `<form method="POST" action="cgi-bin/contact.cgi">`、項目順序(姓・名・
  メール・メール確認用・問い合わせ内容・プライバシー同意・reCAPTCHA・
  `verify_token`(hidden)・送信ボタン)、フィールド名は`site/cgi-bin/contact.cgi`・
  `ContactLogic.pm`を実際にgrepして`last_name`/`first_name`/`email`/
  `email_confirm`/`message`/`privacy_agree`/`verify_token`と完全一致させた
  (spec文書だけでなく実装済みコードを一次情報として確認)。
- **プレースホルダー設計上の重要な決定(spec未規定、本タスクで確定・要記録):**
  `Common::render_template()`は文字列位置ベースの単純置換であり、HTML構文を
  意識しない。そのため`<!--VALUE:last_name-->`等をそのまま`<input value="...">`の
  中に書くと、`contact.html`がGETで**未処理のまま**Apacheから直接配信される
  初回アクセス時(`internal-spec-cyberhome.md` 2.1節)に、未置換のプレースホルダー
  文字列がそのまま入力欄の初期値として表示されてしまう(実際にPerlで
  `Common::render_template()`を試験実行し、この位置に置いた場合に再現することを
  確認した上で設計を変更した)。回避策として、各`<input>`は常に`value=""`のまま
  空にしておき、プレースホルダーは`<span class="value-holder" data-target="..."
  hidden><!--VALUE:xxx--></span>`という非表示のsibling要素に置き、
  `contact-form.js`がページ読み込み時にその内容(処理済みなら入力値、未処理なら
  空文字列)を対応する入力欄へ移し替える方式にした。`site/cgi-bin/lib/Common.pm`・
  `contact.cgi`は一切変更していない(既存の確定済み実装のまま)。この設計変更は
  `perl -Ilib -e '...'`でCommon::render_templateを実際に実行し、(a)エラー時に
  `<ul class="error-list">`が正しく挿入されCONTACT_ERRORSマーカーが残らないこと、
  (b)各`value-holder`に期待通りの値がHTMLエスケープ済みで入ること、
  (c)エラーなしの場合にプレースホルダー文字列がどこにも残らないこと、を確認した
  (67件のPerl Test::More既存テストも全件成功のまま)。
- **FAQ/チャットウィジェット(`site/js/chat-widget.js`、新規):**
  `internal-spec-vercel.md` 2.2節・`internal-spec-integration.md` 3章/6.2節の契約
  (`GET /api/faq`、5秒タイムアウト、`Cache-Control: no-store`、0件時の空状態文言
  「まだFAQがありません。お問い合わせフォームをご利用ください」、失敗時文言
  「FAQを読み込めませんでした。しばらくしてから再度お試しいただくか、お問い合わせ
  フォームをご利用ください」)をそのまま実装。`external-spec.md`「2. 問い合わせ
  チャット機能」の確定要件(全ページ共通のフローティングウィジェット)に従い、
  DOMをJSで動的に挿入する設計にして、`index.html`・`contact.html`・
  `contact-thanks.html`・`privacy.html`・`news.html`に加えて`news.cgi`が使う
  `site/templates/footer.html`にも読み込みタグを追加し、`news.cgi`が生成する
  記事一覧・詳細ページも含めて実質的に全ページに表示されるようにした
  (Perlコード自体は無変更、`footer.html`は`_read_fragment()`で無条件に文字列
  結合されるだけの断片のため、この追加はNewsLogic.pmのテストに影響しないことを
  67件のPerlテスト再実行で確認済み)。あわせて`footer.html`内の旧
  `mailto:mainagak@gmail.com`表示を、外部仕様が「メールアドレスは作成中」と
  明記していることと矛盾しないよう、プライバシーポリシーへのリンクに置き換えた。
- **reCAPTCHA→HMAC→CGIのブラウザ側リレー(`site/js/contact-form.js`、新規):**
  `internal-spec-integration.md` 1.4節・2.2節・6.1節の契約通り、reCAPTCHA v2の
  `data-callback`から`POST /api/verify-recaptcha`を8秒タイムアウトで呼び出し、
  成功時に`verify_token`(hidden)へトークンを設定して送信ボタンのdisabledを
  解除する。失敗時の文言(「検証に失敗しました。もう一度チェックボックスを操作
  するか、時間をおいて再度お試しください。」)も契約の確定文言をそのまま使用。
  `internal-spec-vercel.md` 9.1節の指示通り、`X-Smoke-Test-Auth`ヘッダーは一切
  送信しない(CI専用のPlaywrightスモークテストのみが付与する設計と整合)。
- **未確定の実値2件をコード中に明示的なTODOコメント付きプレースホルダーとして
  埋め込んだ(既存の`architecture.md`「追加質問4・6」と同種の、実機確認待ちの
  非公開情報という扱い):**
  1. `VERCEL_API_BASE_URL`(`chat-widget.js`・`contact-form.js`の両方、
     Vercel実プロジェクトのデプロイURLが未確定のため)。
  2. `contact.html`のreCAPTCHA `data-sitekey`(v2サイトキー、
     `jyoho1.web.cyberhome.ne.jp`ドメインでの登録がまだ完了していないため)。
  いずれも実機確認・登録が完了し次第、該当箇所を実際の値に置き換える必要がある
  (非ブロッキング、フェーズ7以降で解消)。
- **`site/qr/book1.html`・`book2.html`は意図的に変更していない:**
  Basic認証済みの限定的なダウンロード案内ページ(`noindex, nofollow`)であり、
  Task#3(Cyberhome側CGI実装)の既存成果物に手を入れるスコープ拡大を避けるため、
  FAQウィジェットの追加は見送った(非ブロッキング、フェーズ4/5への軽微な
  フィードバックとして記録: 厳密に「全ページ共通」を満たすには将来これらにも
  ウィジェットを追加する余地がある)。
- **CSS(`site/css/style.css`・`responsive.css`)は既存の配色・角丸・シャドウの
  デザイン言語を踏襲して拡張した**(新規デザインシステムは導入していない)。
  旧`.chatbot-hidden`・`#chatbot-iframe`(未実装の`chat.html`用iframe)は
  ウィジェット方式への置き換えに伴い削除した。
- **`site/js/main.js`を整理:** 旧Node.js時代の`/api/send-email`宛fetch処理・
  iframeチャットボットのトグル処理(いずれも到達不能なデッドコード化していた)を
  削除し、ページ内アンカーリンクのスムーズスクロール初期化のみに整理した
  (`.nav-link`のクリックを、ハッシュリンクの場合のみpreventDefaultするよう修正。
  これにより`contact.html`・`news.html`等の別ページへのnav-linkが正しく機能する)。
  `site/js/utils.js`は汎用ユーティリティのため変更していない。
- **検証内容(実施済み、Phase 7/8のシステムテスト・E2Eテストではない):**
  - `node --check`で新規・変更した4つのJSファイル(`main.js`・`chat-widget.js`・
    `contact-form.js`。`utils.js`は無変更だが念のため実施)の構文エラーがないこと
    を確認。
  - Pythonの`html.parser`でタグの開閉バランスを検証(5つの新規/更新HTMLページは
    単独で整合、`templates/header.html`+`footer.html`は連結時に整合することを
    確認)。
  - `site/cgi-bin/lib/`の既存Perl単体テスト67件(`Common.t`14/`ContactLogic.t`27/
    `DownloadLogic.t`19/`NewsLogic.t`7)を再実行し、全件成功のまま変化がないことを
    確認(本タスクはCGI/`.pm`側を一切変更していないため期待通り)。
  - `Common::render_template()`を実際の`site/contact.html`に対して直接実行し、
    エラーあり/なし双方のケースでプレースホルダーの挙動を手動検証(上記参照)。
  - 実際のブラウザでの表示確認、実際のVercel API・実際のreCAPTCHAキーでの
    疎通確認、Apache実機でのCGI起動確認は一切行っていない
    (**本チェックポイントはシステムテスト・E2Eテスト(フェーズ7・8)を構成しない**)。
- `docs/specs/README.md`のダッシュボード・進捗ボード・残タスク(項目19)を本内容に
  合わせて更新する(別コミット)。

**次のアクション:** フェーズ6の残りタスク(テスト・CI/CD詳細実装)に着手する。
本タスクで埋め込んだ2件のプレースホルダー実値(Vercelデプロイ先URL、reCAPTCHA
サイトキー)は、実機情報が確定次第、`site/js/chat-widget.js`・
`site/js/contact-form.js`・`site/contact.html`を修正すること。フェーズ7・8で
実機に近い環境での動作確認(reCAPTCHA→HMAC→contact.cgiのフルフロー、FAQ
ウィジェットの実データ表示、QRページへのウィジェット追加要否の再検討)を行うこと。

## 2026-08-02: チェックポイント18 — フェーズ6 Task#5(テスト・CI/CD詳細実装、Wave3)完了、フェーズ6全体完了

`docs/specs/internal-spec-testing.md`に基づき、フェーズ6の最後のタスク
(デプロイジョブ順序の確認・Playwrightスモークテストの実ファイル・Perl/pytestの
CI組み込み確認・バックアップ/ロールバック手順・Q4日次疎通確認のCI配線)を実施した。

- **`.github/workflows/*.yml`4本の確認結果: 既に完成していた。** Task#1
  (チェックポイント13)が`internal-spec-testing.md`の詳細設計(ジョブ順序・
  Playwrightシナリオ表・`perl-tests.yml`/`api-tests.yml`確定設計・
  `SMOKE_TEST_SECRET`配線・`smoke-test-failure`ラベル等)をすでに一字一句に近い
  精度で反映済みであることを4ファイルとも全文読み合わせで確認した。
  `deploy-cyberhome.yml`(backup→deploy→smoke-test→notify-on-failure)、
  `playwright-smoke.yml`(schedule/workflow_call/workflow_dispatch/`api/**`push、
  smoke+health-ping+notify-on-failure)、`api-tests.yml`、`perl-tests.yml`の
  いずれも本書2.4節・6章の表と完全に一致しており、本タスクでの変更は不要と判断した
  (既存ファイルは無変更のまま)。
- **Playwright実テストファイルを新規実装(未着手だった部分):**
  リポジトリ直下に`package.json`(devDependency `@playwright/test`のみ、
  `architecture.md`決定事項9「ローカル開発環境を持たない」方針に沿い他のNode資産は
  追加しない)・`playwright.config.ts`(`testDir: tests/e2e`、`SITE_BASE_URL`環境変数
  からbaseURLを解決)を新規作成し、`tests/e2e/public/`配下に
  `internal-spec-testing.md` 2.1節のシナリオ#1〜#10・#4bを実装する8ファイル・
  11テストケース(`top-page.spec.ts`・`news.spec.ts`・`contact-page.spec.ts`・
  `privacy-page.spec.ts`・`basic-auth.spec.ts`(#7/#8/#9)・`faq-widget.spec.ts`・
  `vercel-faq-api.spec.ts`・`contact-submission.spec.ts`(#4/#4b))を新規実装した。
  各ファイルは実装済みの実ファイル(`site/index.html`・`contact.html`・
  `site/js/chat-widget.js`・`contact-form.js`・`ContactLogic.pm`・`contact.cgi`・
  `.htaccess`・`api/app/routers/*.py`)を実際にgrep・読み合わせてセレクタ・
  フィールド名・エラー文言・レスポンス形状を一次情報から確認した上で書いた
  (spec文書の記述のみに頼っていない)。シナリオ#4(正常系送信、B′案)は
  `internal-spec-vercel.md` 9章の設計通り、ブラウザから
  `POST /api/verify-recaptcha`を`X-Smoke-Test-Auth`ヘッダー付きで直接呼び出して
  `verify_token`を取得し、実際の`contact.html`フォームへ注入して送信する実装にした
  (`contact.cgi`・reCAPTCHA検証ロジックは一切変更・迂回しない)。
- **ローカルでの検証(実施済み、フェーズ7/8のシステムテスト・E2Eテストではない):**
  - `npx playwright test --list`で11テスト・8ファイルすべてが構文エラーなく
    列挙されることを確認。
  - `tsc --noEmit --strict`(型定義は`--types node`を明示)でも型エラー0件を確認。
  - Cyberhome実機・Vercel実機のいずれも存在しないため、`site/`をPython
    `http.server`でローカル配信し、静的ページのみに依存する3シナリオ
    (`top-page.spec.ts`・`contact-page.spec.ts`・`privacy-page.spec.ts`)を
    実際にPlaywright(Chromium)で実行し、**3件とも成功**を確認した
    (セレクタ・見出し文言が実HTMLと一致していることの実証)。
  - 残り5ファイル(`news.spec.ts`はPerl CGI実行環境、`basic-auth.spec.ts`は
    Apache Basic認証、`faq-widget.spec.ts`・`vercel-faq-api.spec.ts`・
    `contact-submission.spec.ts`はVercel実デプロイが必要)はこの環境では
    実行不可能であり、**意図的に未実行のまま**とした(タスク指示通り、
    実デプロイ後にCI上で実行されることを想定した設計)。
- **Perl Test::More・pytestのCI組み込み再確認:**
  - `perl-tests.yml`は`prove -l site/cgi-bin/lib/t/`を実行する設計のまま
    (変更なし)。ローカルではCygwin環境の`prove`本体が引き続き壊れているため
    (チェックポイント16と同じ既知の制約)、`perl -Isite/cgi-bin/lib <test>.t`を
    4ファイル個別実行する形で代替検証し、**67/67件成功**(Common 14/
    ContactLogic 27/DownloadLogic 19/NewsLogic 7、失敗0件)を確認した。
  - `api-tests.yml`は`ruff check api/` → `pytest api/tests`のまま(変更なし)。
    実行した結果は下記「Q4疎通確認の実装状況」を参照。
- **Q4(問い合わせフォーム自動疎通確認、B′案)の実装状況を検証:**
  `api/app/services/recaptcha_service.py`の`_resolve_secret_key`が
  `internal-spec-vercel.md` 9.1節のコード例通りに実装済みであること、
  `api/app/routers/recaptcha.py`が`request.headers`を正しく
  `verify_recaptcha()`へ渡していること、`api/app/core/config.py`に
  `SMOKE_TEST_SECRET`・`RECAPTCHA_TEST_SECRET_KEY`が定義済みであることを
  実コードの読み合わせで確認した(Task#4は実際にQ4を実装済みであり、
  タスク指示にあった「未実装ならBLOCKERとして報告」には該当しなかった)。
  `.github/workflows/playwright-smoke.yml`もCI Secrets `SMOKE_TEST_SECRET`を
  `X-Smoke-Test-Auth`相当の環境変数として`smoke`ジョブへ既に配線済み
  (Task#1側で対応済み、変更不要)。
  - **発見した実装ギャップ(本タスクで解消、単体テストのバックフィル):**
    `internal-spec-vercel.md` 6.4節の`test_recaptcha.py`テストケース表(14件)は、
    同日に追加された9章(CI検証バイパス)を反映しないまま据え置かれており、
    `_resolve_secret_key`の分岐(X-Smoke-Test-Authヘッダーによる
    `RECAPTCHA_TEST_SECRET_KEY`/`RECAPTCHA_SECRET_KEY`切替)を検証するpytestケースが
    1件も存在しないことが判明した。本タスクの役割定義(「単体テストの手戻し
    (バックフィル)」)の範囲内と判断し、`api/tests/test_recaptcha.py`にケース15・16
    (正しいヘッダーで`RECAPTCHA_TEST_SECRET_KEY`が送信されること/
    ヘッダー欠落・不一致で`RECAPTCHA_SECRET_KEY`のまま送信されること、`respx`で
    Googleへの実送信パラメータを検証)を追加し、`internal-spec-vercel.md` 6.4節にも
    追記した(実装コード自体`_resolve_secret_key`は無変更)。これにより
    `test_recaptcha.py`は14→16件、pytest合計は29→31件になった
    (`internal-spec-testing.md` 4章・6章の該当箇所も29→31に修正済み)。
    実行結果: `python -m pytest api/tests -v` → **31/31件成功**、
    `ruff check api/app api/index.py api/tests` → **All checks passed**。
- **バックアップ・ロールバック手順:** `internal-spec-testing.md` 5章がFTPSミラー
  方式で既に実行可能なレベルまで具体化済みであり(`deploy-cyberhome.yml`の
  `backup`ジョブとして実装済み、Task#1)、本タスクでの追加実装は不要と判断した。
  CyberhomeのFTPSサーバーがLIST/MLSDに対応しているかは実機未確認のままであり
  (5章・`internal-spec-repo-cicd.md`「追加質問Q1」が既に明記済みの制約)、
  初回の実デプロイ実行まで検証できない(本タスクの範囲では解消不可能な既知の制約)。
- **`.gitignore`に`package-lock.json`を追加:** `npm install -D @playwright/test`の
  実行時に自動生成されるが、CIワークフローは`npm ci`ではなく`npm install -D`を
  使う設計(Task#1確定)のためロックファイルはCIの動作に必須ではなく、
  `architecture.md`決定事項9(ローカル開発環境を持たない)の精神に沿ってリポジトリには
  含めない判断とした。`node_modules/`・`playwright-report/`・`test-results/`は
  Task#1の時点で既に`.gitignore`済みだった。

**内部仕様上のギャップ・矛盾: 1件発見・その場で解消(上記pytestケース15・16の
バックフィル、ブロッキングではない)。** それ以外に本タスクのスコープ
(デプロイジョブ順序・Playwrightシナリオ・Perl/pytestのCI組み込み・
バックアップ/ロールバック・Q4疎通確認)においてブロッキングな未決定事項・
矛盾は見つからなかった。

**フェーズ6(実装・単体テスト)は本タスクをもって全体完了した。** Task#1〜4+
静的ページ実装(gap-fill)+本タスク(Task#5)のすべてが完了し、単体テストは
Perl Test::More 67件・pytest 31件・`scripts/validate_faq.py`用pytest 50件の
合計148件が全件成功している(いずれもこの実装環境で実際に実行し確認済み)。
Playwrightスモークテストのみ、実際のCyberhome/Vercelデプロイ先が存在しないため
「コード自体は完成・部分的にローカル静的配信で検証済みだが、フルシナリオの
実行はフェーズ7以降に持ち越し」という状態である。

**残タスク・非ブロッキング項目の総括(フェーズ7・8が参照すべき一覧、詳細は各
チェックポイント参照):**

1. `VERCEL_API_BASE_URL`(`site/js/chat-widget.js`・`contact-form.js`)と
   reCAPTCHA v2サイトキー(`site/contact.html`の`data-sitekey`)が
   プレースホルダーのまま(チェックポイント17)。実機のVercelデプロイ・
   `jyoho1.web.cyberhome.ne.jp`ドメインでのreCAPTCHA登録が完了次第、実値に置換する。
2. Playwrightスモークテスト8ファイル・11ケースのうち、静的ページ3ケース
   (`top-page`/`contact-page`/`privacy-page`)はローカル静的配信で実行・成功を
   確認済みだが、残り5ファイル(`news`/`basic-auth`/`faq-widget`/
   `vercel-faq-api`/`contact-submission`)はCyberhome実機(Apache Basic認証・
   CGI実行)・Vercel実機が存在しないため**この環境では一度も実行されていない**。
   実デプロイ後、`workflow_dispatch`での`playwright-smoke.yml`手動実行により
   初回の実地検証を行うこと。
3. `docs/specs/architecture.md`末尾の「追加質問」3〜6(Cyberhome契約プランの
   正確な月額費用、文字コード/Apacheバージョンの実機確認、`AuthUserFile`絶対パス、
   reCAPTCHAキー登録状況)は引き続き非ブロッキングのまま未解消。
4. `site/qr/book1.html`・`book2.html`にFAQウィジェット(`chat-widget.js`)が
   未追加(チェックポイント17)。external-spec.mdの「全ページ共通」要件を厳密に
   満たすには追加の余地がある。
5. フェーズ10(FAQ管理GUI実装)着手時、`internal-spec-vercel.md` 7.2節のCSRF
   ダブルサブミット方式を`admin.py`ルーターとともに実装する必要がある
   (Task#4ではスコープ外と判断し未実装、チェックポイント15)。
6. `scripts/setup.ps1`(Node.js前提のローカル開発セットアップ)が現行方針と
   不整合なまま放置されている(チェックポイント13)。
7. Cyberhomeの実FTPS認証情報・`CYBERHOME_PUBLIC_HTML_PATH`・
   `CYBERHOME_FTP_PORT`等のGitHub Secrets、`SITE_BASE_URL`・
   `VERCEL_API_BASE_URL`・`SMOKE_TEST_SECRET`等のGitHub Variables/Secretsは、
   いずれもこの環境では登録されていない(登録は運営者作業、コードでは表現できない)。
   これらが揃うまで4本のワークフローはいずれも実行時に失敗する
   (構文・設計は完成しているが、実行可能な状態ではない)。
8. Cyberhome実機の`.htpasswd`(`dl/`・`qr/`)・`conf/hmac_secret.txt`は
   `.example`のみコミットされており、実ファイルはFTPで別途配置する必要がある
   (`internal-spec-repo-cicd.md` 7.4節、既存方針のまま変更なし)。
9. GitHubブランチ保護ルール・PRベース開発フローへの移行(`internal-spec-repo-cicd.md`
   6章)は、この一連のフェーズ6実装作業でもまだ実施されていない(継続してmainへの
   直接コミットで進めている)。フェーズ6完了を機に移行を検討することを推奨する。
10. `internal-spec-vercel.md` 6.4節のpytestテスト表と実ファイルとの不整合
    (テスト15・16の欠落)は本タスクで発見・解消済みだが、同種の「9章のような
    後付け追加が既存節の一覧表に反映されない」というドキュメント運用上のリスクは
    今後も起こり得るため、フェーズ9(最終レビュー)で全ドキュメントの
    テストケース数一致を再確認することを推奨する。

**この一連の検証はいずれもフェーズ6(実装・単体テスト)の範囲であり、
システムテスト・E2Eテスト(フェーズ7・8)を構成しない。** 実際のCyberhome/Vercel
環境に対する動作確認・reCAPTCHA本番キーでの疎通・実メール受信確認等は
一切行っていない。

**次のアクション:** フェーズ7(p7-system-tester、システムテスト)に着手可能。
着手前に上記残タスク1・7・8(Vercel/reCAPTCHA実値・GitHub Secrets・Cyberhome
非公開ファイル)のうち実施可能なものから運営者作業として進めることを推奨する
(これらが揃わない限り、フェーズ7で実機に対するテストは実施できない可能性が高い)。

## 2026-08-02: チェックポイント19 — フェーズ7(システムテスト)実施、不合格判定

`docs/specs/internal-spec-integration.md`(Cyberhome⇔Vercel連携契約)を中心に、
フェーズ6で並行実装された各モジュールの継ぎ目を、実際にコードを動かして検証した
(ペーパーレビューのみに頼らない)。詳細・全項目の結果は
`docs/specs/system-test-report.md`を参照。

- **実施したこと:**
  - Python 3.12.10(`api/requirements.txt`一式インストール済み)で`api/app/main.py`を
    実際にuvicornで起動し、`GET /api/faq`・`GET /health`・
    `POST /api/verify-recaptcha`・`OPTIONS`プリフライトを`curl`で実叩き。
  - `api/app/services/recaptcha_service.py`の`_issue_token()`が生成した**実際の
    HMACトークン**を、Perl `site/cgi-bin/lib/ContactLogic.pm`の`verify_token()`に
    **実際に**投入し、正しいシークレット/誤ったシークレット/改ざん署名/
    フォーマット不正/欠如/期限切れ(300秒)/クロックスキュー(60秒境界)の
    全パターンで期待通りに合格・拒否することを確認した。
  - Cygwin環境にCGI.pm本体が無いため、`CGI->new`/`param()`のみを実装した
    テスト専用の最小限スタブ(非シップ)を用意し、実際の`site/contact.html`・
    `site/cgi-bin/contact.cgi`・`site/cgi-bin/lib/ContactLogic.pm`を実際の
    POSTボディで実行して正常系・異常系(不正トークン)双方の描画結果を確認した。
  - `site/news.cgi`のパストラバーサル対策・404・記事0件時の一覧表示、
    `.htaccess`(cgi-bin/dl/qr)のrealm共有設定、環境変数・シークレット名の
    全体突合(`api/app/core/config.py`・`site/cgi-bin/lib/*.pm`・
    `.github/workflows/*.yml`・`.env.example`類)も確認した。
  - 検証で作成した一時ファイル(`site/conf/hmac_secret.txt`、
    `site/cgi-bin/contact_log.txt`等、いずれも`.gitignore`対象または非コミット)は
    テスト後に削除し、既存のPerl単体テスト67件を再実行して副作用がないことを
    確認した。
- **合格した項目:** HMACトークンの生成・検証・改ざん検知・期限切れ・
  クロックスキュー許容、FAQ API(`GET /api/faq`)の実レスポンス形状と
  `site/js/chat-widget.js`の実パース処理との整合、CORS許可/拒否オリジンの
  基本動作、`news.cgi`/`download.cgi`のエラーパス、`.htaccess`のrealm共有、
  環境変数名の全体突合(過去に発見された`HMAC_SHARED_SECRET`のような表記ゆれの
  再発なし)。
- **不合格と判定した重大な発見:** `site/cgi-bin/contact.cgi`が`CGI->new`実行時に
  `$CGI::PARAM_UTF8 = 1;`(または`use CGI '-utf8';`)を設定していないため、
  日本語の姓・名・お問い合わせ内容が文字化けする(例:「山田」→「å±±ç°」)。
  実際にCGI.pmの`%XX`復号アルゴリズムを再現したハーネスで`contact.cgi`を
  日本語入力で実行して再現を確認し、`Encode::decode_utf8()`を1行加えるだけで
  解消することも確認して根本原因を特定した。影響範囲は通知メール・自動返信
  メール・エラー再描画・`contact_log.txt`記録のすべてに及ぶ(問い合わせフォーム
  の根幹機能)。`download.cgi`/`news.cgi`のCGIパラメータは英数字のみを許可する
  正規表現でバリデーションされているため影響を受けない。
  - **なぜフェーズ6の単体テスト67件で検出されなかったか:** 既存の
    `ContactLogic.t`等は`use utf8;`宣言済みのテストファイル内でソースコード
    リテラル(`'山田'`)を直接関数へ渡しており、これは最初から正しくデコード
    済みのPerl文字列である。実際のCGI.pmが生成する「バイト列のまま」の文字列とは
    異なるため、`contact.cgi`が実際のCGI環境から`ContactLogic.pm`へ正しく
    デコードされた文字列を渡せているかというCGI境界の契約は一度も検証されて
    いなかった。単体テストの不備ではなく、単体テストの守備範囲外にある
    継ぎ目(まさにシステムテストの担当領域)である。
- **軽微な発見:** `api/app/main.py`のCORSMiddlewareに`max_age=86400`が
  指定されておらず、Starletteのデフォルト600秒のままになっている
  (`internal-spec-integration.md` 5.2節・8章の契約値86400秒と不一致)。
  機能的な破綻はないが契約との乖離のため記録した。
- **合否判定に含めなかったもの:** `docs/PROJECT_STATUS.md`チェックポイント18の
  残タスク1・2・7・8(`VERCEL_API_BASE_URL`・reCAPTCHAサイトキーの
  プレースホルダー未置換、Playwright残り5シナリオ未実行、GitHub Secrets/
  Variables未登録、Cyberhome実機`.htpasswd`/`hmac_secret.txt`未配置)は、
  実インフラが存在しない本環境では原理的に検証不可能であり、状態変化なしの
  既知の残タスクとして再確認したのみで、新たな不合格理由には含めていない。

**判定: 不合格(要修正)。** `contact.cgi`の日本語入力文字化けバグをフェーズ6へ
差し戻し、修正(`$CGI::PARAM_UTF8 = 1;`の追加等)後に本フェーズを再実施すること。
CORS Max-Ageの軽微な修正もあわせて対応することを推奨する。

**次のアクション:** フェーズ6の担当範囲へ`contact.cgi`修正を差し戻す。修正完了後、
`docs/specs/system-test-report.md`の該当項目(特に日本語値を含む`contact.cgi`の
正常系・エラー系)を再テストし、合格判定を得てからフェーズ8(E2Eテスト)へ進むこと。

## 2026-08-02: チェックポイント20 — フェーズ6差し戻し対応、`contact.cgi`文字化けバグ・CORS Max-Age修正完了

`docs/specs/system-test-report.md`(フェーズ7不合格判定)で指摘された2件を、
フェーズ6の差し戻しタスクとして修正した。

- **【重大】`site/cgi-bin/contact.cgi`の日本語入力文字化け(発見した問題1)を修正:**
  `main()`内、`CGI->new`の直前に`$CGI::PARAM_UTF8 = 1;`を追加した。これにより
  `$cgi->param()`が返す各値がCGI.pm内部で`Encode::decode('UTF-8', ...)`を通った
  正しいPerl Unicode文字列になり、`_render_rejection()`経由のテンプレート再描画
  (`Common::render_template()`)・`ContactLogic::build_notification_mail()`/
  `build_autoreply_mail()`によるメール本文組み立て・`Common::write_log()`による
  `contact_log.txt`記録のいずれにも正しくデコードされた文字列が流れるようになる
  (1箇所の修正がCGI境界より下流の全経路に効く設計であることを確認済み)。
  - 修正前に`ContactLogic.pm`・`Common.pm`側を調査したが、メールヘッダーの
    `Content-Type: text/plain; charset=UTF-8`・`MIME-Version: 1.0`
    (`ContactLogic::_build_mail_text()`)、`send_via_sendmail()`の
    `binmode($mail_fh, ':encoding(UTF-8)')`、`write_log()`・`render_template()`の
    `open(..., '<:encoding(UTF-8)' / '>>:encoding(UTF-8)', ...)`は、いずれも
    「正しくデコードされたPerl文字列を受け取る」ことを前提に正しく実装済みだった
    (=バグの原因はCGI境界(`contact.cgi`)のみに存在し、下流モジュールの修正は
    不要と判断した)。
  - `download.cgi`・`news.cgi`は`file`・`id`パラメータを英数字のみの正規表現で
    バリデーションしており日本語自由入力を受け付けないため、システムテスト報告書も
    影響なしと判定している。両CGIへの同種の防御的追加(報告書が「望ましい」と
    記載した任意対応)は本タスクの必須修正範囲外と判断し、**今回は変更していない**
    (指示された修正対象は`contact.cgi`のみのため。念のためフェーズ4/5への
    フィードバックとして下記に記録する)。
- **【軽微】CORS `Access-Control-Max-Age`不一致(発見した問題2)を修正:**
  `api/app/main.py`の`CORSMiddleware`呼び出しに`max_age=86400`を追加した。値は
  `docs/specs/internal-spec-integration.md` 5.2節・8章の確定値86400秒であることを
  実際にドキュメントを読んで確認した(報告書の言い換えをそのまま信用せず裏取り済み)。
  `api/tests/test_recaptcha.py`ケース13(`test_preflight_options_returns_cors_headers`)
  に`Access-Control-Max-Age: 86400`のアサーションを追加した。
- **回帰テストの追加(`contact.cgi`がCGI境界のUTF-8デコードを行っていることを
  実際に検証するテスト):** 既存の`site/cgi-bin/lib/t/*.t`は`.pm`単体テストのみで
  CGI境界を通らないため、新規ファイル
  `site/cgi-bin/lib/t/ContactCgiUtf8Boundary.t`(Test::More、5ケース)を追加した。
  実際のCGI.pmと同じパーセントデコードアルゴリズム(`%XX`→バイト単位`chr()`)+
  `$CGI::PARAM_UTF8`対応を実装した最小限のスタブ
  `site/cgi-bin/lib/t/fixtures/cgi_stub/CGI.pm`(非シップ、`site/.ftpdeployignore`の
  `cgi-bin/lib/t/`除外設定によりCyberhome実機へは配置されない)をPERL5LIB経由で
  読み込ませ、実際の`site/cgi-bin/contact.cgi`を子プロセスとして起動し、実際に
  STDIN経由でUTF-8バイト列のPOSTボディ(`last_name=山田&first_name=太郎&...`)を
  渡して、出力HTMLに日本語が文字化けせず正しいUTF-8バイト列のまま現れることを
  確認する。`privacy_agree`を意図的に欠落させ`ContactLogic::validate_input()`の
  時点でエラーにすることで、`verify_token`検証(`site/conf/hmac_secret.txt`が必要)
  まで到達させずにCGI境界のデコード確認だけに検証範囲を絞っている。
  - **修正前のコードに対して実際にこのテストを実行し、2ケースが実際に失敗する
    (=バグを実際に検出する)ことを確認した上で、修正を適用して5ケース全件成功に
    戻ることを確認した**(`git stash`で一時的に`contact.cgi`の修正のみを退避して
    再現・復元)。
- **単体テスト実行結果(実際に実行、両方とも):**
  - Perl(Test::More): `Common.t`14 + `ContactLogic.t`27 + `DownloadLogic.t`19 +
    `NewsLogic.t`7 + 新規`ContactCgiUtf8Boundary.t`5 = **合計72件、全件成功**
    (環境の`prove`が`TAP::Harness::Env`欠如で起動できなかったため、各`.t`ファイルを
    個別に`perl`実行し、TAP出力の`ok`/`not ok`件数を集計する形で確認した)。
  - pytest: `test_faq.py`12 + `test_recaptcha.py`14(今回追加した
    Max-Ageアサーション1行を含む) + `test_health.py`3 + 既存の
    smoke-test関連2件 = **合計31件、全件成功**。
- **フェーズ4/5へのフィードバック(ブロッカーではない、次回整理推奨):**
  `internal-spec-cyberhome.md`は`download.cgi`/`news.cgi`にも防御的に
  `$CGI::PARAM_UTF8 = 1;`を設定すべきかどうかを明記していない(現状は
  「英数字のみバリデーションだから実害なし」で機能上は問題ないが、将来
  日本語入力を扱うパラメータが両CGIに追加された場合に同種のミスが再発しうる)。
  次の内部仕様改訂または保守タスクで、3 CGI共通の方針として明記することを推奨する。
- 本チェックポイントはドキュメント更新とは別コミットで、実装+テストコード変更を
  まとめて記録する。

**このチェックポイントはフェーズ6(実装・単体テスト)の差し戻し対応であり、
フェーズ7(システムテスト)の再判定そのものではない。** フェーズ7の合否判定は
p7-system-testerが別途実施するものであり、本チェックポイントではその判定を代行
していない。

**次のアクション:** フェーズ7(システムテスト)を再実施し、`docs/specs/system-test-report.md`
「発見した問題1」「発見した問題2」双方が解消されていることを実機相当の検証で確認した上で、
改めて合否判定を得ること。フェーズ7が合格するまでフェーズ8(E2Eテスト)には着手しないこと。


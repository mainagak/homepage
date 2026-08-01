# 開発パイプライン ダッシュボード

## 🔴 再開時に最初に読むこと(/clear後はここから)

**現在地:** フェーズ1〜3(外部仕様調査・レビュー承認・アーキテクチャー調査)完了。
**フェーズ4着手前の曖昧さ撲滅ラウンド(`docs/specs/phase4-clarification.md`、50問×2+
30問×5=合計280問、3択形式)も2026-08-02に全ラウンド完了、ユーザー回答済み。
フェーズ4(内部仕様調査)への引き継ぎ準備が整った。**

**2026-08-02の主な追加決定(`phase4-clarification.md`参照):**
- DB(Neon/Postgres)は**FAQ管理Web GUI用に限定して前倒し導入**(`architecture.md`の
  決定事項5に反映済み)。問い合わせフォーム処理はCyberhome CGI+テキストログのまま。
  FAQ管理GUIはMVPリリース直後の最初の保守作業として速やかに着手する方針。
- GUI認証: ログインフォーム+セッション/JWT、bcryptハッシュ、複数アカウント対応、
  CSRF対策、ログイン試行制限、IP制限。フロントエンドはJinja2(SSR)。
- **保守サイクル(フェーズ10)の方針転換: 大きい機能追加であっても常に軽量な
  p10-maintainerプロセスで対応し、フェーズ1〜5への差し戻しは行わない**
  (下記ゲートルール・スコープメモに反映済み。今回進行中のフェーズ4自体には影響しない)。
- `.gitattributes`でCGI/Perlファイルの改行コード(LF)を強制、コミットメッセージは
  英語統一、GitHubリポジトリはPrivateを維持。

**次回再開時に最初にやること:**
1. `docs/specs/phase4-clarification.md`の「全ラウンド完了」節と
   `docs/specs/architecture.md`の「決定事項」節を前提に、フェーズ4
   (p4-internal-spec-researcher、内部仕様調査)に着手する。
2. フェーズ4は複数のサブエージェントに分割して実行する方針(ユーザー指示、2026-08-02)。
   分割案・実行順序をユーザーに提示しレビューを受けてから着手すること。
3. `docs/specs/architecture.md`末尾の「追加質問」3〜6(非ブロッキング、Cyberhome契約
   詳細・実機確認事項)はフェーズ4と並行して確認する。

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

**残タスク:**
8. フェーズ4(p4-internal-spec-researcher、内部仕様調査)を複数サブエージェントに
   分割して着手する。分割案・実行順序をユーザーがレビューする。
9. 追加質問3〜6(非ブロッキング)はフェーズ4と並行して確認する。

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
| 4 | 内部仕様調査 | p4-internal-spec-researcher | [internal-spec.md](internal-spec.md) | 未着手(着手可能) |
| 5 | 内部仕様最終レビュー・確定 | p5-internal-spec-reviewer | internal-spec.md (承認セクション追記) | 未着手 |
| 6 | 実装・単体テスト | p6-implementer | ソースコード + 単体テスト | 未着手 |
| 7 | システムテスト | p7-system-tester | [system-test-report.md](system-test-report.md) | 未着手 |
| 8 | E2Eテスト(受け入れテスト) | p8-e2e-tester | [e2e-test-report.md](e2e-test-report.md) | 未着手 |
| 9 | 最終レビュー・Issue確認 | p9-final-reviewer | [final-review.md](final-review.md) | 未着手 |
| 10 | 保守メンテナンス | p10-maintainer | (継続、Issue単位で個別記録) | - |

## ゲートルール(重要)

- 各フェーズは**前フェーズが「承認」ステータスになるまで着手しない**。
- 調査フェーズ(1, 3, 4)は「調査・ドラフト作成」のみ行い、確定はしない。
- レビューフェーズ(2, 5)は整合性確認の上、ドキュメント冒頭に
  `## 承認ステータス: 承認 / 差し戻し` を追記する。差し戻しの場合は理由を明記し、
  前フェーズの担当エージェントに戻す。
- 実装(6)はフェーズ5が承認されるまで開始しない。
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
    参照)。
- 方針: 最低限度のMVPを作成し、以降は保守サイクルで機能追加していく想定。

## 未解決事項(解消済み・履歴)

過去の作業で「GitHub Pagesを本番(単体環境)、Vercelを検証環境とし、cyberhomeは廃止」という
決定を行い、その前提でリポジトリ構成を整理・コミット済み(コミット `8e00019`)。
その後フェーズ1で改めてユーザーに確認したところ、**cyberhome/Apacheをホームページ本体・
ダウンロード機能のホスティング先、Vercelを問い合わせ機能のホスティング先とする**ことが
2026-08-01に確定した。GitHub Pagesは本番ホスティングとしては採用しない。

## 現在の未解決事項(フェーズ4と並行して確認可能、非ブロッキング)

- Cyberhome契約プランの正確な月額費用
- 文字コード/Apacheバージョンの実機確認
- `AuthUserFile`絶対パス
- reCAPTCHAキー(v2サイトキー・シークレットキー)の登録状況

詳細は`docs/specs/architecture.md`末尾の「追加質問」3〜6を参照。
</content>

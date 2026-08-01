# 内部仕様 — データモデル設計

## 位置づけ

本ドキュメントはフェーズ4(内部仕様調査)のWave1「データモデル設計」担当分の成果物。
`docs/specs/architecture.md`(決定事項5)および`docs/specs/phase4-clarification.md`
(インフラ深掘りラウンド1〜3/5、特にM節「Neon DB + FAQ管理GUI具体仕様」・P節
「Neon運用深掘り」・O節「GUI認証・セキュリティ深掘り」)で確定した方針を、実装可能な
粒度のスキーマ定義まで落とし込む。

対象範囲:
1. FAQ JSON schema(MVP、静的ファイル)
2. 将来のNeon Postgres schema(FAQ管理Web GUI用、MVPリリース直後の最初の保守作業として着手)
3. JSON→DBの移行方針
4. 命名規則・文字コード・タイムゾーン等、他の内部設計ドキュメント(Cyberhome側・Vercel側API設計)が参照すべき共通規約

対象外(他のWave1エージェントの担当):
- Cyberhome側Perl CGI(`contact.cgi`/`download.cgi`/`news.cgi`)の詳細実装設計
- Vercel FastAPIのルーティング・エンドポイント設計そのもの(本書はFAQ API/GUI APIが
  読み書きするデータの形だけを規定する)
- 問い合わせフォームのテキストログ形式(DB化しないことが確定しているため、本書のスコープ外。
  ただし将来の参照のため軽く触れる)

---

## 1. 共通規約(他の内部設計ドキュメントが参照すること)

| 項目 | 規約 |
|---|---|
| 文字コード | 全レイヤーでUTF-8(BOMなし)に統一。Cyberhome側テキストファイル (`phase4-clarification.md`ラウンド1 A.5で確定)、Neon Postgres(データベース自体もUTF8、P節Q12で確定)、JSON/API通信すべて共通。 |
| タイムゾーン | Neon Postgres内は`TIMESTAMPTZ`型でUTC保存し、表示時にJST(`Asia/Tokyo`)へ変換する(P節Q13で確定)。Cyberhome側Perlの`localtime`がJSTを返すかは実機未確認(`architecture.md`追加質問4)であり、Perl側とDB側は独立した確認・変換ロジックを持つ前提とする。 |
| テーブル名 | 複数形・snake_case(例: `faqs`, `gui_accounts`, `faq_change_log`) |
| カラム名 | snake_case。主キーは`id`(`BIGSERIAL`/`SERIAL`)。外部キーは`<参照先単数形>_id`(例: `faq_id`, `account_id`)。真偽値は`is_`接頭辞(例: `is_active`)。日時は`created_at`/`updated_at`(いずれも`TIMESTAMPTZ`)。 |
| JSON側のキー命名 | 将来DBへ移行した際にキー名の変更を最小化するため、静的JSONの段階からDBカラム名と同じsnake_caseキー(`category`, `question`, `answer`, `display_order`等)を使う。 |
| FAQカテゴリの値 | 日本語そのまま、以下3種類で固定(external-spec.md「2. 問い合わせチャット機能」および`phase4-clarification.md`ラウンド2 Q15で確定): `書籍について` / `仕事の相談` / `会社について` |

---

## 2. FAQ JSON schema(MVP、静的ファイル)

### 2.1 配置場所(提案)

`/api/data/faq.json`(Vercel/FastAPIプロジェクト配下)を提案する。正確な配置パス・
FastAPI側の読み込み方法は並行実行中のAPI設計担当エージェントの成果物と整合させること。
**本書が規定するのはファイルの中身(スキーマ)であり、パスはAPI設計側の決定を優先してよい。**
ただしファイル名`faq.json`とキー名は本書の定義を維持すること(移行時の手戻りを避けるため)。

### 2.2 スキーマ

```json
{
  "faq_schema_version": 1,
  "items": [
    {
      "id": "faq-0001",
      "category": "書籍について",
      "question": "電子書籍はどこで購入できますか?",
      "answer": "Amazon Kindleストアにて販売しています。",
      "display_order": 1
    }
  ]
}
```

初期リリース時点は`items: []`(0件)で開始する(external-spec.md確定事項)。

### 2.3 フィールド定義

| フィールド | 型 | 必須 | 説明・制約 |
|---|---|---|---|
| `faq_schema_version` | integer | 必須(トップレベル) | 現在は`1`固定。将来スキーマを変更する際の互換性判定に使う。 |
| `items` | array | 必須 | 0件以上。 |
| `items[].id` | string | 必須 | 形式`faq-XXXX`(4桁ゼロ埋め連番、例: `faq-0001`)。Claude Codeが新規追加時に採番し、一度割り当てたら変更・再利用しない(将来DB移行時の追跡キー`legacy_json_id`として使うため)。 |
| `items[].category` | string | 必須 | `書籍について` / `仕事の相談` / `会社について` のいずれか(日本語そのまま、完全一致)。 |
| `items[].question` | string | 必須 | 1〜100文字。HTMLタグを含めない(プレーンテキスト、`phase4-clarification.md` O節Q8で確定)。 |
| `items[].answer` | string | 必須 | 1〜1000文字。HTMLタグを含めない(プレーンテキスト)。改行(`\n`)は許容し、フロントエンドJS側で`<br>`相当の表示に変換する(値そのものはプレーンテキストとして保持)。 |
| `items[].display_order` | integer | 必須 | 同一`category`内での表示順(昇順、カテゴリ内で一意)。記載順を表示順として採用する方針(ラウンド2 C節Q17で確定)。カテゴリをまたいだグローバル順序ではない。 |

### 2.4 バリデーションルール(Claude Codeによる手動編集時、および将来FastAPI Pydanticモデルでの検証時に共通で適用)

- `id`: 正規表現 `^faq-\d{4}$`
- `category`: 固定3値のいずれか(`Literal["書籍について", "仕事の相談", "会社について"]`)
- `question`: `1 <= len <= 100`、`<`・`>`を含まない
- `answer`: `1 <= len <= 1000`、`<`・`>`を含まない
- `display_order`: 正の整数、同一`category`内で重複させない

### 2.5 更新運用

MVPリリース〜FAQ管理GUI完成までの間は、Claude Codeが`faq.json`を直接編集し
Git pushする(Vercelの自動デプロイで反映、ラウンド2 A節Q4で確定)。GUI完成後は
JSONファイルを廃止し完全にDBへ移行する(下記「4. 移行方針」参照)。

---

## 3. 将来のNeon Postgres schema(FAQ管理Web GUI用)

導入時期: MVPリリース直後、最初の保守作業として速やかに着手(M節Q22で確定)。
スコープはFAQ管理GUI用に限定し、問い合わせフォーム処理(Cyberhome Perl CGI+
テキストログ)には影響しない(`architecture.md`決定事項5)。

### 3.1 設計方針の要点(根拠付き)

- **カテゴリは独立したマスタテーブルにせず、`faqs.category`に`VARCHAR`+`CHECK`制約で
  直接持たせる。** カテゴリの追加・変更は将来あってもClaude Codeによるコード変更を
  経由する想定であり、GUI上から動的にカテゴリを追加する運用は想定しない
  (`phase4-clarification.md` X節Q11で確定)。GUIの入力フォームも固定3択のドロップダウン
  (R節Q28で確定)であり、値はアプリケーションコード側で保持すれば足りる。マスタ
  テーブル+外部キーを導入すると、保守性重視の要件に対してテーブル数が増えるだけで
  実益が薄いと判断した。
- **GUIアカウントのロール・権限分離は行わない。** 複数アカウント対応は行うが
  (M節Q13で確定)、権限レベルの分離は「当面は運営者本人のみの前提で進める」ことが
  確定している(Z節Q30でB回答)。将来的にロールが必要になった場合のみ`gui_accounts`
  に`role`カラムを追加する(現時点では持たない)。
- **セッションはDB非保持のJWT(有効期限1週間)を採用し、専用のセッションテーブルは
  持たない。** ログイン試行回数制限・アカウント無効化(`is_active`)・ロックアウト
  (`locked_until`)はいずれもリクエストごとに`gui_accounts`テーブルを参照することで
  実現でき、低頻度アクセス(運営者含め数名、月内の操作は少数)ではDB参照コストは
  無視できる。セッションテーブルの追加・失効管理という保守対象を増やさない方が
  「保守性重視」の要件に合致すると判断した。
- **FAQの論理削除(`deleted_at`)は持たず、物理削除+監査ログのスナップショットで
  代替する。** 変更履歴は`faq_change_log`に削除前スナップショットとして残るため、
  `faqs`テーブル自体を`deleted_at IS NULL`条件だらけにする必要がない。
- **操作ログは「更新日時カラムのみ」ではなく、変更履歴テーブル(`faq_change_log`)を
  持つ。** M節Q19で「記録する(変更履歴テーブル、または更新日時カラム)」の両方が
  選択肢として提示されており、複数アカウント対応(M節Q13)により「誰が変更したか」の
  説明責任が発生するため、更新日時カラムのみでは不十分と判断し、変更履歴テーブルを
  採用する。
- **パスワードハッシュ生成はアプリケーション側(Python, bcrypt)で行い、Postgresの
  `pgcrypto`拡張は使わない**(P節Q11で確定)。

### 3.2 テーブル定義

#### `faqs`

FAQ本体。MVPの`faq.json`の内容をここへ完全移行する(下記「4. 移行方針」参照)。

| カラム | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | DBネイティブの連番ID。API応答の`id`はこの整数値になる(JSON時代の文字列`faq-XXXX`から型が変わることを許容、下記4.3参照)。 |
| `legacy_json_id` | `VARCHAR(20)` | `NULL` | 移行元JSONの`id`(`faq-0001`等)。移行スクリプトのみが値を入れる。GUI経由で新規作成された行は`NULL`のまま。 |
| `category` | `VARCHAR(50)` | `NOT NULL`, `CHECK (category IN ('書籍について','仕事の相談','会社について'))` | 固定3値。 |
| `question` | `VARCHAR(100)` | `NOT NULL`, `CHECK (char_length(question) > 0)` | |
| `answer` | `VARCHAR(1000)` | `NOT NULL`, `CHECK (char_length(answer) > 0)` | HTMLタグを含めない運用(アプリ層でも検証)。 |
| `display_order` | `INTEGER` | `NOT NULL DEFAULT 0` | 同一カテゴリ内での表示順。 |
| `status` | `VARCHAR(10)` | `NOT NULL DEFAULT 'draft'`, `CHECK (status IN ('draft','published'))` | 保存/公開の2段階(M節Q15で確定)。公開ボタンを押すまでサイトに反映しない。 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | UTC。 |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | UTC。更新時にアプリ層(またはトリガー)で更新。 |
| `created_by` | `INTEGER` | `NULL REFERENCES gui_accounts(id) ON DELETE SET NULL` | 移行データは`NULL`。 |
| `updated_by` | `INTEGER` | `NULL REFERENCES gui_accounts(id) ON DELETE SET NULL` | |

**インデックス:**
```sql
CREATE INDEX idx_faqs_category_status_order
  ON faqs (category, status, display_order);
CREATE INDEX idx_faqs_status ON faqs (status);
```
FAQ公開API(`GET /api/faq`相当)は`status='published'`のみをカテゴリ・表示順で
取得するため、このインデックスが主要クエリと一致する。

#### `gui_accounts`

FAQ管理GUIのログインアカウント。複数アカウント対応(M節Q13)。

| カラム | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | `SERIAL` | `PRIMARY KEY` | |
| `email` | `VARCHAR(255)` | `NOT NULL UNIQUE` | ログインID兼用。 |
| `password_hash` | `VARCHAR(60)` | `NOT NULL` | bcryptハッシュ(固定60文字、O節Q1・P節Q11で確定)。 |
| `display_name` | `VARCHAR(100)` | `NULL` | 変更履歴表示用の表示名。 |
| `is_active` | `BOOLEAN` | `NOT NULL DEFAULT true` | 無効化はレコード削除ではなくフラグで行う(退職・利用停止時)。 |
| `failed_login_attempts` | `SMALLINT` | `NOT NULL DEFAULT 0` | ログイン試行回数制限用(O節Q7で確定)。ログイン成功時に0へリセット。 |
| `locked_until` | `TIMESTAMPTZ` | `NULL` | 一時ロック解除時刻(UTC)。規定回数失敗で設定。 |
| `created_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | |
| `updated_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | |
| `last_login_at` | `TIMESTAMPTZ` | `NULL` | |

**インデックス:** `email`はUNIQUE制約により自動的にインデックスが張られる。

**アカウント追加方法:** 運営者がGUI内の管理画面から新規アカウントを追加できる機能を
実装する(O節Q3で確定)。追加操作自体は`gui_accounts`への通常のINSERTであり、
`faq_change_log`のような別テーブルの監査対象にはしない(アカウント管理はFAQ変更履歴
とはスコープを分ける)。

#### `faq_change_log`

FAQの変更履歴(誰が何を変更したか)。M節Q19で確定。

| カラム | 型 | 制約 | 説明 |
|---|---|---|---|
| `id` | `BIGSERIAL` | `PRIMARY KEY` | |
| `faq_id` | `BIGINT` | `NOT NULL REFERENCES faqs(id) ON DELETE CASCADE` | 削除されたFAQの履歴も削除時点までは参照整合性を保つ(CASCADEにより`faqs`行削除と同時に履歴も消える設計。**削除後も履歴を残したい場合はCASCADEをRESTRICT/SET NULLに変更する判断がありうるが、本書では「直近の変更責任追跡」が目的であり長期保存要件はないためCASCADEを採用**)。 |
| `account_id` | `INTEGER` | `NULL REFERENCES gui_accounts(id) ON DELETE SET NULL` | 操作したアカウント。アカウント削除後もログ自体は残す。 |
| `action` | `VARCHAR(10)` | `NOT NULL CHECK (action IN ('create','update','delete','publish','unpublish'))` | |
| `before_snapshot` | `JSONB` | `NULL` | 変更前の行内容(`create`時は`NULL`)。 |
| `after_snapshot` | `JSONB` | `NULL` | 変更後の行内容(`delete`時は`NULL`)。 |
| `changed_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` | |

**インデックス:**
```sql
CREATE INDEX idx_faq_change_log_faq_id_changed_at
  ON faq_change_log (faq_id, changed_at DESC);
```

### 3.3 ER概要(テキスト表現)

```
gui_accounts (1) ──< faqs.created_by / faqs.updated_by
gui_accounts (1) ──< faq_change_log.account_id
faqs (1) ──< faq_change_log.faq_id (ON DELETE CASCADE)
```

### 3.4 Neon運用設計

- **接続方式:** サーバーレス(Vercel Functions)からはNeonの組み込みコネクション
  プーラー経由で接続する(M節Q11で確定)。
- **接続文字列管理:** Vercel環境変数(Vercel-Neon統合の自動連携)を基本とし、
  ローカル開発用に`.env.example`を用意する(M節Q17で確定)。ローカルでの実接続テストは
  DB接続部分のみ例外的に許可する(N節Q28で確定、他はローカル開発環境を持たない方針を
  維持)。
- **ブランチ機能:** 開発用・本番用でNeonのDBブランチを分離して使う(M節Q18、Q節Q17で
  確定)。VercelのPreview Deployごとに自動でDBブランチを作成・破棄するVercel-Neon統合
  機能を利用する。
- **リージョン:** アジア太平洋リージョン(東京に近く低レイテンシ)を選択する
  (P節Q9で確定)。
- **スケールトゥゼロによるコールドスタート遅延:** 許容する(月間アクセス規模が小さい
  ため、P節Q10で確定)。
- **障害時フォールバック:** FAQ公開APIはVercel側で直近取得したFAQデータを一時
  キャッシュしておき、Neon障害時はキャッシュを返す(P節Q30で確定)。この一時キャッシュ
  はDBスキーマとは独立したアプリケーション層の実装(インメモリまたはVercel KV等)で
  よく、本書のテーブル定義には影響しない。
- **バックアップ:** Neon自体のポイントインタイムリカバリに加え、GitHub Actionsで
  定期的に`pg_dump`相当のダンプを取得しワークフローのアーティファクトとして保存する
  (`phase4-clarification.md`インフラ深掘りラウンド1/5の回答注記「GitHub Actionsで
  別途ダンプ取得」に基づく)。
- **無料枠超過時のアラート:** Neonダッシュボードの標準通知に任せる(P節Q14で確定)。
- **テストデータ投入:** 初期マイグレーション/シードスクリプトで自動投入する
  (P節Q15で確定)。シードは`faq_categories`のような別テーブルを持たないため、
  `faqs`へのサンプルINSERT文のみで足りる。

### 3.5 GUI認証・セキュリティ設計(データモデルへの反映事項)

- パスワードハッシュ: bcrypt(O節Q1)。ハッシュ生成はPythonアプリケーション側
  (`gui_accounts.password_hash`への書き込み前にハッシュ化、pgcrypto不使用)。
- セッション有効期限: 1週間(O節Q2)。JWTの`exp`クレームで表現し、専用テーブルは
  持たない(3.1節参照)。
- ログイン試行回数制限: `failed_login_attempts`・`locked_until`カラムで実装
  (O節Q7)。
- パスワードリセット: **2026-08-02、内部仕様追加質問Q1への回答によりO節Q4の方針を
  変更。** メールによる自動リセットは行わず、パスワードを忘れた場合は運営者が
  Claude Codeに依頼し、`gui_accounts.password_hash`を直接UPDATEしてもらう運用とする
  (Claude Codeがbcryptハッシュを生成しSQL発行、またはNeonダッシュボードのSQLエディタで
  実施)。このためトークンカラム(`password_reset_token`等)は不要と判断し、上記
  テーブル定義から削除済み。
- IP制限: GUI自体へのアクセスをVercel側でもIP制限する(O節Q6)。これはデータベース
  スキーマではなくVercel側のミドルウェア/環境変数(許可IPリスト)で実現するため、
  本書ではテーブル定義を持たない(許可IPリストをDB管理する必要が生じた場合は
  `gui_allowed_ips (id, ip_cidr, note, created_at)`のような小テーブルを追加する
  余地を残しておく)。
- CSRF対策: FastAPIの標準的なCSRFトークン機構を使用(O節Q5)。DBスキーマへの影響なし。

---

## 4. JSON → DB 移行方針

### 4.1 方針

M節Q21の回答により、FAQ管理GUI稼働開始と同時に**完全移行**する(JSONファイルは廃止)。
移行後は`faq.json`をリポジトリから削除するか、履歴参照用として`docs/`配下に
アーカイブする(削除/アーカイブの判断は実装時、Phase 6に委ねる)。

### 4.2 移行手順(一度きりの移行スクリプト、Phase 6で実装)

1. `faq.json`の`items`配列を順に読み込む。
2. 各要素を`faqs`テーブルへ`INSERT`する:
   - `category` ← `items[].category`(そのまま、値は3種の固定文字列と一致するため変換不要)
   - `question` ← `items[].question`
   - `answer` ← `items[].answer`
   - `display_order` ← `items[].display_order`
   - `legacy_json_id` ← `items[].id`(例: `faq-0001`)
   - `status` ← 固定値`'published'`(MVP期間中は下書き概念がなく、JSONに存在する項目は
     すべて公開扱いだったため)
   - `created_by` / `updated_by` ← `NULL`(移行データのため担当アカウント不明)
3. 移行完了後、`faq_change_log`に`action='create'`のレコードをまとめて1件ずつ
   (または移行専用の一括ログとして)残すかは任意。監査上の要請は「GUI経由の変更」を
   追跡することが主目的であり、移行そのものの記録は必須要件ではないため、
   Phase 6の判断で省略してよい。
4. 移行後の疎通確認後、FAQ公開APIの実装を「JSON読み込み」から
   「`SELECT ... FROM faqs WHERE status='published' ORDER BY category, display_order`」
   へ切り替える。

### 4.3 API応答形式の互換性

M節Q20の回答により「DBの構造に合わせて多少変わることを許容する」ことが確定している。
本書では以下の方針を推奨する(フロントエンド改修コストを最小化するため):

- トップレベルの形(`{"items": [...]}`)とキー名(`id`, `category`, `question`,
  `answer`)は維持する。
- **`id`の型のみ`string`(`"faq-0001"`)から`integer`(DBの`BIGSERIAL`値)に変わる。**
  これが唯一の意図的な破壊的変更点であるため、フロントエンドJS側では`id`を
  文字列パース(先頭`faq-`の除去等)に依存させず、単なる不透明な識別子として
  扱う実装にしておくこと(Phase 6実装時の注意事項としてここに明記する)。
- `display_order`・`category`・`question`・`answer`のセマンティクスはJSON時代と
  完全に同一に保つ。

### 4.4 想定データ量・コスト概算(参考)

- FAQ件数: 初期0件、将来的にも書籍・仕事の相談・会社についての3カテゴリという
  スコープ上、数十件規模を大きく超える想定はない。
- GUIアカウント数: 数名程度(複数アカウント対応はするが大規模な組織利用は想定外、
  Z節Q30で権限分離見送りが確定していることからも小規模運用が前提)。
- `faq_change_log`: 1回の編集で1〜2行(更新+必要なら公開/非公開切り替え)ずつ増加。
  低頻度運用のため、Neon無料枠(ストレージ0.5GB程度)を大きく下回る規模で収まる
  見込み(具体的な無料枠消費試算はVercel側APIコール頻度と合わせてAPI設計担当の
  成果物で扱う、N節Q27で確定した「試算が必要」という要件に対応)。

---

## 5. 参考: 問い合わせ履歴・アクセスログ(DB化しない領域、スコープ外だが関連情報)

問い合わせフォームの内容・ダウンロードアクセスログは`architecture.md`決定事項5により
DB化しない(Cyberhome側テキストログ+メール通知)。データモデルとしての設計対象外だが、
将来これらもDB化する判断がなされた場合は、本書の命名規則・タイムゾーン規約
(UTC保存・snake_caseカラム名)をそのまま踏襲することを推奨する。

---

## 追加質問

なし。**旧Q1(パスワードリセットメール送信経路)は2026-08-02にユーザーが選択肢C
(メールリセットを廃止、Claude Codeによる手動DB更新に変更)で確定済み。** 上記
3.5節・`gui_accounts`テーブル定義に反映済み。トランザクションメールAPI等の追加
外部サービス導入は不要になった。

本書のスコープ(データモデル)においてブロッキングな未決定事項はない。

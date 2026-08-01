# Cyberhome ⇔ Vercel 連携契約設計

## 位置づけ

本ドキュメントは、フェーズ4(内部仕様調査)Wave1の一部として、Cyberhome(Apache/Perl CGI)
とVercel(Python/FastAPI)の間の連携インターフェースを**曖昧さなく確定**するもの。
Wave2で並列実行される「Cyberhome側内部設計」「Vercel側内部設計」の両エージェントは、
本ドキュメントに記載された契約(エンドポイント・リクエスト/レスポンス形式・CORS・
エラーハンドリング)を**そのまま前提として実装設計を行う**こと。本契約自体の変更が
必要な場合は、Wave2側で新たな未解決事項として起票し、勝手に変更しないこと。

参照元(すべて確定済み・承認済み):
`docs/specs/external-spec.md`、`docs/specs/architecture.md`(「ホスティング構成の決定」
「Cyberhome ⇔ Vercel 連携設計(reCAPTCHA)」節)、`docs/specs/phase4-clarification.md`
(全8ラウンド280問)。

---

## 0. 最重要の前提: 通信経路は常にブラウザ経由(サーバー間直接通信なし)

`phase4-clarification.md` インフラ深掘りラウンド2/5 L節 Q10(確定回答A)により、
**Cyberhome側のPerl CGI(`contact.cgi`等)からVercel APIへの直接HTTPS呼び出しは行わない**
方針が確定している(Cyberhome側にSSL/TLSモジュールがなくCPAN追加もできないため)。

したがって、Cyberhome ⇔ Vercel の「連携」は、実体としては常に **ブラウザ(JavaScript)を
仲介**した以下の三者間通信になる。

```
[ブラウザ]                [Vercel/FastAPI]           [Cyberhome/Perl CGI]
  |--- (1) GET /api/faq ------->|                            |
  |<-- FAQ一覧 JSON -------------|                            |
  |                              |                            |
  |--- (2) POST /api/verify-recaptcha ->|                     |
  |         { recaptcha_response }      |--(2a) POST siteverify--> [Google]
  |                              |<--------------------------- |
  |<-- { verified, token } ------|                            |
  |                                                            |
  |--- (3) 通常のHTML <form method="POST"> 送信 --------------->|
  |         (問い合わせ内容 + hidden: verify_token)             |
  |                                                            contact.cgi が
  |                                                            HMAC再計算・検証
  |<---------------------- 受付完了ページ ----------------------|
```

- (1)(2)はブラウザからVercelへのAJAX(`fetch`)呼び出い(CORS対象)。
- (3)は通常のHTML `<form>` POST送信であり、`fetch`ではない(ページ遷移を伴う
  従来型のCGI呼び出し。`contact.cgi`はCGI.pmで標準的なform-urlencoded/multipart
  POSTを受け取る前提、インフラ深掘りラウンド2/5 Q7=A確定)。
- Cyberhome側からVercelへの逆方向の呼び出しは一切発生しない。Wave2のCyberhome側
  エージェントは「Vercel APIをCGIから呼ぶ」設計を検討する必要はない。

---

## 1. HMAC署名付きトークン仕様(確定)

### 1.1 何を署名するか

署名対象は **タイムスタンプ(Unixエポック秒、UTC、整数)のみ**。氏名・メール等の
問い合わせ内容そのものは署名対象に含めない(理由: 改ざん検知の目的は「Google
reCAPTCHA検証を経由したことの証明+短命な有効期限管理」であり、フォーム内容の
完全性保証は別レイヤ(HTMLエスケープ・contact.cgi側バリデーション)で担保するため。
また問い合わせ内容を署名対象に含めると、ブラウザ側JSがフォーム内容確定前に
`verify-recaptcha`を呼ぶ現行フロー(reCAPTCHAチェック→即トークン取得)と時系列が
合わなくなる)。

タイムスタンプにUnixエポック秒(UTC)を採用する理由: Perl側`time()`・JS側
`Math.floor(Date.now()/1000)`のいずれもUTCエポック秒を返すため、
`phase4-clarification.md` L節Q5で指摘された「Cyberhome実機のタイムゾーンが
JSTかどうか不明」という懸念を構造的に回避できる(タイムゾーン変換が一切不要)。

### 1.2 トークンのフォーマット

```
token = "<timestamp>.<hmac_hex>"
```

- `timestamp`: 10桁前後の10進整数文字列(例: `1774000000`)。
- `hmac_hex`: `HMAC-SHA256(key=共有シークレット, message=timestamp文字列)` の
  16進小文字64文字。
- 区切り文字はピリオド`.`固定1個(`timestamp`部分に`.`が出現しないため
  `split(/\./, $token, 2)` で安全に分離できる)。

**Vercel側(Python)生成例:**
```python
import hmac, hashlib, time

ts = str(int(time.time()))
sig = hmac.new(SHARED_SECRET.encode(), ts.encode(), hashlib.sha256).hexdigest()
token = f"{ts}.{sig}"
```

**Cyberhome側(Perl、コアモジュール`Digest::SHA`のみ)検証例:**
```perl
use Digest::SHA qw(hmac_sha256_hex);

my ($ts, $sig) = split(/\./, $token, 2);
unless (defined $ts && $ts =~ /^\d+$/ && defined $sig && $sig =~ /^[0-9a-f]{64}$/) {
    reject_submission("invalid_token_format");
}

my $expected = hmac_sha256_hex($ts, $SHARED_SECRET);
unless ($sig eq $expected) {
    reject_submission("token_signature_mismatch");
}

my $now = time();
if (($now - $ts) > 300 || ($ts - $now) > 60) {
    # 300秒(5分)超過、または未来方向60秒を超えるクロックスキューは拒否
    reject_submission("token_expired");
}
```
(`eq`による文字列比較は定数時間比較ではないが、CPAN不可のCyberhome環境では
`String::Compare::ConstantTime`等が使えないため許容する。本トークンは高価値の
認証情報ではなくスパム対策の補助であり、タイミング攻撃で得られる価値も乏しいため
リスクは許容範囲と判断する)。

### 1.3 有効期限

**300秒(5分)** に確定。根拠:
- `architecture.md`の「Cyberhome ⇔ Vercel 連携設計」節で「例: 5分以内」と明記
  されていた値をそのまま正式な確定値として採用。
- `phase4-clarification.md` ラウンド2 B節 Q5(確定回答C)で「問い合わせフォームの
  重複送信判定は送信元IP+メールアドレスの組み合わせで5分以内は拒否」と定められて
  おり、トークン有効期限をこれと同じ5分に揃えることで、運用者・実装者が異なる
  時間定数を覚える必要がなくなる(保守性重視の要件に合致)。

クロックスキュー許容幅(未来方向60秒)は本設計で新規に追加した実装上の安全マージン
であり、Cyberhome実機とVercel実機の時計が完全同期している保証がないための措置。

### 1.4 伝送方法

**HTMLフォームのhiddenフィールド**に確定(HTTPヘッダー方式は不採用)。

理由:
- `contact.cgi`への送信は、reCAPTCHA検証後にブラウザJSが`fetch`で叩くAPIではなく、
  従来型の`<form method="POST" action="contact.cgi">`によるページ遷移を伴う送信
  (0節参照)。ブラウザの通常のフォーム送信ではカスタムHTTPヘッダーを付与できない
  ため、hiddenフィールドが唯一の実用的な伝送経路。
- フィールド名: `verify_token`(固定)。
- 実装フロー: (a) ページ読み込み時、reCAPTCHAウィジェットを表示し送信ボタンは
  `disabled`。(b) ユーザーがreCAPTCHAチェックを完了すると、ウィジェットの
  コールバックでブラウザJSが`POST /api/verify-recaptcha`を呼ぶ。(c) 成功
  レスポンスの`token`値を`<input type="hidden" name="verify_token">`に設定し、
  送信ボタンの`disabled`を解除する。(d) ユーザーが送信ボタンを押すと、通常の
  フォームPOSTとして`contact.cgi`へ問い合わせ内容+`verify_token`が送信される。

### 1.5 共有シークレットの管理・年次ローテーション

`phase4-clarification.md` ラウンド2 B節 Q8(確定回答B)により年次更新
(`.htpasswd`更新と同時)が確定している。手順を以下に確定する。

1. Claude Codeが暗号学的に安全な乱数でシークレットを生成する(例:
   `openssl rand -hex 32`相当、32バイト=64文字の16進文字列)。
2. Vercel側: Vercelダッシュボードの環境変数`INTEGRATION_HMAC_SECRET`を新しい値に
   更新し、再デプロイする。
3. **5分以上待機する**(発行済みトークンの最大有効期限300秒を確実に超過させ、
   新旧シークレットの過渡期に発行されたトークンが「新シークレットでは検証できない」
   事態を自然に解消させるため)。
4. Cyberhome側: 運営者がFTPSクライアントで`public_html`配下の非公開シークレット
   ファイル(下記「環境変数・秘密情報」参照)を新しい値で上書きする(`.htpasswd`
   更新作業と同一のFTPSセッションで実施してよい)。
5. 更新後、Playwrightスモークテストまたは手動で問い合わせフォームの送信テストを
   1件実施し、トークン検証が正常に通ることを確認する。

**手順の順序(Vercel→待機→Cyberhome)を厳守すること。** 逆順(Cyberhome先行更新)
だと、Vercelがまだ旧シークレットで署名したトークンをCyberhomeが新シークレットで
検証しようとして即座に全件拒否される空白期間が生じる。

---

## 2. reCAPTCHA検証フロー(確定)

### 2.1 前提

- reCAPTCHA **v2(チェックボックス)** を採用(`architecture.md`確定済み)。
- サイトキー(公開情報)はCyberhome側の問い合わせフォームHTMLに直接埋め込む
  (Vercel APIを経由しない、静的な設定値)。
- シークレットキーはVercel環境変数`RECAPTCHA_SECRET_KEY`として保持する。
- サイトキー・シークレットキーの実際の値(Google reCAPTCHA管理コンソールでの
  登録)は`architecture.md`「追加質問6」として既に非ブロッキング事項として記録
  済みであり、本ドキュメントで再度質問はしない(未登録の場合はドメイン
  `jyoho1.web.cyberhome.ne.jp`で登録する)。

### 2.2 ステップバイステップ

**Step 1: ブラウザ → Google(reCAPTCHAウィジェット、既存の標準動作)**
ユーザーがreCAPTCHA v2チェックボックスを操作し、Googleのウィジェット自体が
`g-recaptcha-response`という文字列トークンをブラウザ側に生成する(このやり取りは
Google製ウィジェットが直接処理し、本プロジェクトのコードは関与しない)。

**Step 2: ブラウザ → Vercel**
```
POST /api/verify-recaptcha HTTP/1.1
Host: <vercel-project>.vercel.app
Origin: https://jyoho1.web.cyberhome.ne.jp
Content-Type: application/json

{
  "recaptcha_response": "<Step1で得たg-recaptcha-response文字列>"
}
```

**Step 3: Vercel → Google**
```
POST https://www.google.com/recaptcha/api/siteverify HTTP/1.1
Content-Type: application/x-www-form-urlencoded

secret=<RECAPTCHA_SECRET_KEY>&response=<recaptcha_response>&remoteip=<ブラウザのIP、任意項目>
```
タイムアウト: **5秒**。この呼び出しに限り、Cyberhome側の制約(TLSモジュールなし)
がないVercel側が代行する(`architecture.md`確定事項)。

**Step 4: Google → Vercel(レスポンス)**
```json
{
  "success": true,
  "challenge_ts": "2026-08-02T09:00:00Z",
  "hostname": "jyoho1.web.cyberhome.ne.jp"
}
```
失敗時:
```json
{
  "success": false,
  "error-codes": ["invalid-input-response"]
}
```

**Step 5: Vercel → ブラウザ(レスポンス)**

| ケース | HTTPステータス | ボディ |
|---|---|---|
| `recaptcha_response`未指定/空 | 400 | `{"verified": false, "reason": "missing_recaptcha_response"}` |
| Googleが`success:false`を明示的に返した(実際の検証失敗) | 400 | `{"verified": false, "reason": "recaptcha_failed", "error_codes": [...]}` |
| Googleが`success:true`を返した(検証成功) | 200 | `{"verified": true, "token": "<timestamp>.<hmac>", "expires_in": 300}` |
| Googleへの呼び出し自体が失敗(タイムアウト・接続エラー・5xx等) | 200 | `{"verified": true, "token": "<timestamp>.<hmac>", "expires_in": 300}` (fail-open、下記2.3参照) |
| その他内部エラー(シークレット未設定等) | 500 | `{"verified": false, "reason": "internal_error"}` |

**Step 6: ブラウザ → Cyberhome(`contact.cgi`)**
Step5で得た`token`をhiddenフィールド`verify_token`に設定した上で、通常の
HTMLフォームPOSTとして問い合わせ内容一式を送信する(1.4節参照)。フェッチではない。

**Step 7: Cyberhome内部検証**
`contact.cgi`が1.2節の手順でHMAC署名・有効期限を検証し、合格した場合のみ
`sendmail`呼び出しに進む。

### 2.3 fail-open の適用範囲(重要、誤解防止のため明記)

`phase4-clarification.md` インフラ深掘りラウンド2/5 N節 Q41(確定回答B)の
「fail-open」は、**あくまで「VercelからGoogle siteverifyへの呼び出しが技術的に
失敗した(到達不能・タイムアウト・Google側5xx)場合」にのみ適用される。**
Googleが到達可能で明示的に`success: false`を返した場合(＝実際にreCAPTCHA検証に
失敗した場合)は、これは通常の検証失敗であり、fail-openの対象では**ない**
(400を返し、トークンは発行しない)。

この区別がない設計だと「reCAPTCHAを解かなくても常に許可される」実質無効化に
なってしまうため、Wave2のVercel側エージェントは両者を明確にコード上で分岐する
こと(例外捕捉によるfail-openと、正常応答内`success:false`によるfail-closedを
別ロジックにする)。

### 2.4 fail-openが発生した場合のログ

fail-open発生時、Vercel側は理由をサーバーサイドログにのみ記録する
(`phase4-clarification.md` E節 Q30確定回答Cにより、個人情報は出力しないが
reCAPTCHA検証結果・HMACトークン発行ログは許可されている)。クライアントへの
レスポンスボディに`degraded`等のフラグを含める必要はない(Wave2側で監視上
必要と判断すれば追加してよいが、契約上必須ではない)。

---

## 3. FAQ API 暫定契約(確定)

Cyberhome側は本APIを直接呼び出さない(0節参照)。Cyberhome側の静的ページに
埋め込まれたJS(FAQ/チャットウィジェット)がブラウザ経由で呼び出す。**Wave2の
Cyberhome側エージェントは、このレスポンス形式に依存するフロントJSの実装契約として
本節を参照すること。** 内部実装(データソースが静的JSONかNeon DBか等)はWave2の
Vercel側エージェントが設計する。

### 3.1 エンドポイント

```
GET /api/faq
```
認証: なし(公開情報)。クエリパラメータ: なし(MVPでは全件返却し、カテゴリ別の
絞り込みはフロントエンドJS側で行う。3カテゴリ・想定件数が少ないため、
サーバー側フィルタリングAPIを別途用意する必要性は薄いと判断)。

### 3.2 レスポンス形式

```json
{
  "faqs": [
    {
      "id": "faq-001",
      "category": "書籍について",
      "question": "電子書籍はどこで購入できますか?",
      "answer": "Amazon Kindleストアでご購入いただけます。"
    }
  ],
  "updated_at": "2026-08-02T00:00:00Z"
}
```

- `category`の値は`phase4-clarification.md`ラウンド2 C節Q15(確定回答B)により
  日本語ラベルそのもの(スラッグ化しない)。値は以下3種に固定:
  `"書籍について"` / `"仕事の相談"` / `"会社について"`(`external-spec.md`の
  3カテゴリと一致)。
- FAQ 0件時(ローンチ時点)は`{"faqs": [], "updated_at": "..."}`を返す
  (`phase4-clarification.md` ラウンド1 Q1確定回答Aに基づき、フロント側で
  「まだFAQがありません。お問い合わせフォームをご利用ください」という空状態
  UIを表示する。これはエラーではなく正常応答)。
- `updated_at`は省略可能なメタ情報(将来Neon DB移行後の更新日時把握用)。MVP
  (静的JSON)時点では未実装でも契約違反にはしない(nullまたはフィールド省略可)。

### 3.3 キャッシュ方針

`phase4-clarification.md` ラウンド2 C節Q20(確定回答A、キャッシュなし)に基づき、
レスポンスヘッダーに`Cache-Control: no-store`を付与する。ブラウザ・CDN双方での
キャッシュを行わない(FAQ更新の即時反映を優先)。

### 3.4 将来のDB移行との関係

`phase4-clarification.md` インフラ深掘りラウンド2/5 N節Q20(確定回答B)により、
将来Neon DB移行時にレスポンス形式が多少変わることは許容されている。ただし
**トップレベルの`faqs`配列構造・各項目の`id`/`category`/`question`/`answer`
フィールド名は破壊的変更を避け、フィールド追加のみで対応することを推奨する**
(フロントJSの改修コストを最小化するため。保守性重視の要件に合致)。

---

## 4. ヘルスチェックエンドポイント `/health`(確定)

`phase4-clarification.md` インフラ深掘りラウンド2/5 N節Q35(確定回答C)により、
GitHub Actionsによる定期pingの対象として整備する。

```
GET /health
```
認証: なし。呼び出し元: GitHub Actions(定期実行ワークフロー、頻度はWave2の
Vercel側エージェントまたはCI/CD設計側で確定)。CORS: ブラウザから呼ばれる想定が
ないため、CORS許可オリジンの対象外でよい(Origin無しのサーバー間呼び出しのため
CORSヘッダーの有無自体が問題にならない)。

### レスポンス

```json
{
  "status": "ok",
  "service": "homepage-api",
  "time": "2026-08-02T00:00:00Z"
}
```
HTTPステータス: 200(正常時)。MVP時点ではDB接続を持たないため、疎通確認は
FastAPIプロセス自体の生存確認(shallow health check)のみでよい。**将来Neon DB
(FAQ管理GUI)導入後、DB接続確認を含めるかどうかはWave2以降で改めて検討する**
(本契約は現時点でDB確認を必須としない)。

### 実装上の注意(Wave2 Vercel側エージェントへ)

Vercelの Python Functionsは既定で`/api/*`配下のファイルが自動ルーティングされる。
本エンドポイントは`/api`プレフィックスなしの`/health`という確定パスのため、
`vercel.json`に明示的なrewrite設定(例: `{"source": "/health", "destination": "/api/health"}`)
を追加する必要がある。パス自体(`/health`)は本契約で確定済みであり変更しないこと。

---

## 5. CORS設定(確定)

許可オリジンは`architecture.md`で確定済みの`https://jyoho1.web.cyberhome.ne.jp`
1件のみ(ワイルドカード不可、末尾スラッシュなし)。

### 5.1 対象エンドポイントと必要なヘッダー

| エンドポイント | プリフライト(OPTIONS)要否 | 理由 |
|---|---|---|
| `GET /api/faq` | 不要(単純リクエスト) | カスタムヘッダーなし、GETのみ |
| `POST /api/verify-recaptcha` | **必要** | `Content-Type: application/json`はCORSセーフリスト外のためプリフライトが発生する |
| `GET /health` | 不要 | サーバー間呼び出しのためブラウザCORSの対象外 |

### 5.2 レスポンスヘッダー(`/api/faq`・`/api/verify-recaptcha`共通)

```
Access-Control-Allow-Origin: https://jyoho1.web.cyberhome.ne.jp
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type
Access-Control-Max-Age: 86400
```
`Access-Control-Allow-Credentials`は付与しない(Cookieやセッションを使わない
ステートレスAPIのため、クレデンシャル付きCORSは不要)。

`OPTIONS /api/verify-recaptcha`へのプリフライトレスポンスは、ボディなしの
204(または200)に上記ヘッダーを付与して返す。

### 5.3 実装方針

FastAPIの`CORSMiddleware`を`/api/faq`・`/api/verify-recaptcha`を含むアプリ全体に
適用し、`allow_origins=["https://jyoho1.web.cyberhome.ne.jp"]`,
`allow_methods=["GET", "POST", "OPTIONS"]`, `allow_headers=["Content-Type"]`と
設定することで5.2節の要件を満たせる(Wave2 Vercel側エージェントの実装詳細)。

---

## 6. タイムアウト・エラーハンドリング(ブラウザ視点、確定)

0節の通り、Cyberhome側CGIがVercel APIの無応答を直接ハンドリングすることはない
(サーバー間通信が存在しないため)。「Vercel API無応答時にCyberhome側はどう
振る舞うか」という問いは、実質的に**「ブラウザJSがVercel APIの無応答/エラーを
どう扱い、その結果`contact.cgi`への送信可否にどう影響するか」**という設計に
帰着する。以下に確定する。

### 6.1 `POST /api/verify-recaptcha`が失敗した場合

- ブラウザ側`fetch`のタイムアウトを**8秒**に設定する(`AbortController`使用)。
- 対象: タイムアウト、ネットワークエラー、HTTPステータス 4xx/5xx、
  レスポンスボディの`verified: false`のいずれか。
- 挙動: 送信ボタンは`verify_token`が取得できるまで`disabled`のままとし
  (1.4節のフロー)、エラーメッセージ
  「検証に失敗しました。もう一度チェックボックスを操作するか、時間をおいて
  再度お試しください。」をreCAPTCHAウィジェット付近に表示する。
- **自動リトライは行わない**(ユーザーが再度チェックボックスを操作することで
  再試行する、Googleウィジェット自体の標準UXに委ねる)。
- この結果、`verify_token`を持たない状態で`contact.cgi`へPOSTされることは
  ブラウザ側のUIフローとしては通常発生しない。ただし悪意ある直接POST
  (フォームを介さないスクリプトからの送信)に備え、`contact.cgi`側は
  **`verify_token`欠如・不正・期限切れを常にfail-closed(拒否)として扱う**
  (1.2節参照)。reCAPTCHAの不正対策としての効力は、この「トークン必須」の
  fail-closed設計によって担保されている(2.3節のfail-openとは異なるレイヤの
  話であることに注意)。

### 6.2 `GET /api/faq`が失敗した場合

- ブラウザ側`fetch`のタイムアウトを**5秒**に設定する。
- 対象: タイムアウト、ネットワークエラー、HTTPステータス 4xx/5xx。
- 挙動: FAQウィジェット内に
  「FAQを読み込めませんでした。しばらくしてから再度お試しいただくか、
  お問い合わせフォームをご利用ください。」を表示し、問い合わせフォームへの
  導線(`phase4-clarification.md` ラウンド2 C節Q21確定文言「お問い合わせ
  フォームへ」ボタン)を合わせて表示する。
- 自動リトライは行わない(ウィジェットの再オープン時に再取得を試みる程度でよい)。

### 6.3 共通方針

- いずれの場合も、Vercel側の障害が問い合わせフォーム自体(reCAPTCHA検証待ち)を
  完全にブロックしうる設計であることを許容する(fail-closed)。これは
  「Google siteverify呼び出し失敗時はfail-open」という既存決定(2.3節)とは
  レイヤが異なり、**「Vercel自体に到達できない/Vercelが落ちている」という
  より上位の障害には備えていない**ことを明示しておく。Vercel全体の可用性は
  `architecture.md`で「Vercel標準ログのみで十分、外部監視不要」と確定して
  おり、本契約もその前提(Vercelの基本的な可用性を信頼する)に立つ。

---

## 7. 環境変数・秘密情報一覧(本契約に関わるもののみ)

| 変数名 | 保持場所 | 値の性質 | 用途 |
|---|---|---|---|
| `RECAPTCHA_SECRET_KEY` | Vercelダッシュボード環境変数 | 秘密 | Google siteverify呼び出し時の`secret`パラメータ |
| `INTEGRATION_HMAC_SECRET` | Vercelダッシュボード環境変数 + Cyberhome側非公開ファイル(例: `/public_html/cgi-bin/.secrets/hmac_secret.txt`、`.htaccess`でWeb直接アクセス拒否、`.gitignore`対象) | 秘密・両者で同一値を保持 | トークン署名・検証の共有鍵 |
| `ALLOWED_ORIGIN` | Vercelダッシュボード環境変数(任意、ハードコードでも可) | 非秘密 | CORS許可オリジン(`https://jyoho1.web.cyberhome.ne.jp`) |
| (参考)reCAPTCHAサイトキー | Cyberhome側HTML内に直接記述 | 非秘密(公開情報) | フォームページのウィジェット表示 |

`INTEGRATION_HMAC_SECRET`の初期生成・年次ローテーション手順は1.5節を参照。

---

## 8. Wave2引き継ぎ用 契約サマリ表

| 項目 | 確定内容 |
|---|---|
| サーバー間直接通信 | なし。全てブラウザ経由(0節) |
| エンドポイント数 | 3(`POST /api/verify-recaptcha`, `GET /api/faq`, `GET /health`) |
| トークン形式 | `"<unixtime>.<hmac_sha256_hex>"`、有効期限300秒、hiddenフィールド`verify_token`で伝送 |
| 署名対象 | タイムスタンプのみ(UTC epoch秒) |
| HMAC共有シークレット変数名 | `INTEGRATION_HMAC_SECRET`(Vercel環境変数 / Cyberhome非公開ファイル) |
| reCAPTCHA版 | v2(チェックボックス) |
| fail-open適用範囲 | Vercel→Google siteverify呼び出しの技術的失敗時のみ。Google応答`success:false`はfail-closed |
| contact.cgi側のトークン必須性 | 常にfail-closed(欠如・不正・期限切れは拒否) |
| CORS許可オリジン | `https://jyoho1.web.cyberhome.ne.jp`(単一、ワイルドカード不可) |
| FAQレスポンス構造 | `{"faqs": [{id, category, question, answer}], "updated_at"}`、0件時も200で空配列 |
| FAQキャッシュ | `Cache-Control: no-store` |
| ブラウザ→Vercelタイムアウト | verify-recaptcha: 8秒 / faq: 5秒 |
| Vercel→Googleタイムアウト | 5秒(超過時fail-open) |
| ヘルスチェックパス | `/health`(`/api/health`ではない、要`vercel.json` rewrite) |

---

## 追加質問

なし。本契約に関わる論点はすべて`architecture.md`および
`phase4-clarification.md`の確定回答から一意に導出できたため、Wave2着手前の
ブロッキングな追加確認事項はない。

参考として、本契約の**外側**にあり既存文書で非ブロッキングと整理済みの依存事項
(Wave2着手を妨げないが、実運用開始までに解消が必要)を再掲する:
- reCAPTCHAサイトキー・シークレットキーの実際の登録状況
  (`architecture.md`「追加質問6」、ドメイン`jyoho1.web.cyberhome.ne.jp`で登録)。
- Cyberhome実機の`AuthUserFile`絶対パス・文字コード実機確認
  (`architecture.md`「追加質問4・5」、本契約(HMAC/CORS/API形式)には影響しない)。

---

## トレーサビリティ(参照した確定回答一覧)

| 本ドキュメントの決定 | 根拠 |
|---|---|
| サーバー間直接通信なし | phase4-clarification.md インフラ2/5 L節Q10(A) |
| HMAC共有シークレットの生成・保管方式 | architecture.md 前提事項 / phase4-clarification.md ラウンド2 B節Q13(B) |
| シークレット年次ローテーション | phase4-clarification.md ラウンド2 B節Q8(B) |
| トークン有効期限300秒 | architecture.md「Cyberhome ⇔ Vercel 連携設計」節 + phase4-clarification.md ラウンド2 B節Q5(C、重複判定5分と整合) |
| reCAPTCHA v2採用 | architecture.md 決定事項4 |
| fail-open適用範囲 | phase4-clarification.md インフラ2/5 N節Q41(B) |
| contact.cgi CSRF=Refererのみ | phase4-clarification.md ラウンド2 B節Q6(B、確定済み前提) |
| CORS許可オリジン確定 | architecture.md「CORS・ドメイン(確定)」節 |
| FAQ APIレスポンス構造(フラット配列+カテゴリタグ) | phase4-clarification.md ラウンド1 C節Q16(C) |
| カテゴリタグの値(日本語ラベル) | phase4-clarification.md ラウンド2 C節Q15(B) |
| FAQ 0件時の空状態許容 | phase4-clarification.md ラウンド1 A節Q1(A) |
| FAQ APIキャッシュなし | phase4-clarification.md ラウンド2 C節Q20(A) |
| `/health`エンドポイント + 定期ping監視 | phase4-clarification.md インフラ2/5 N節Q35(C) |
| Vercelログに個人情報を出力しない | phase4-clarification.md ラウンド2 E節Q30(C) |

# システムテスト報告

日付: 2026-08-02(初回実施)/ 2026-08-02(フェーズ6差し戻し対応後の再テスト)

## テスト対象

フェーズ6で独立に実装された以下のモジュール間の「継ぎ目」(内部仕様上の契約)を、
実コードを実際に動かして検証した。ペーパーレビュー(仕様書とコードを読んで整合すると
「思う」)ではなく、可能な限り実際にプロセスを起動・実行し、実際の入出力で確認した。

1. HMAC署名付きトークン契約(`docs/specs/internal-spec-integration.md` 1章):
   `api/app/services/recaptcha_service.py`(Python、Vercel側)が発行するトークンを、
   `site/cgi-bin/lib/ContactLogic.pm`(Perl、Cyberhome側)の`verify_token()`が
   実際に検証できるか。
2. FAQ API契約(同3章): `api/app/routers/faq.py`を実際にuvicornで起動し、
   `GET /api/faq`の実レスポンスを`site/js/chat-widget.js`の実パース処理と突き合わせ。
3. `contact.html` ↔ `contact.cgi`契約(`internal-spec-cyberhome.md` 2章):
   実際の`site/contact.html`に対し、実際の`contact.cgi`を(CGI.pm相当のPOST処理を
   再現するテストハーネス経由で)実行し、正常系・エラー系双方の描画結果を確認。
4. 環境変数・設定名の突き合わせ: `api/app/core/config.py`・`site/cgi-bin/lib/*.pm`・
   `.github/workflows/*.yml`・`api/.env.example`・`site/conf/*.example.txt`全体で
   変数名・シークレット名が一致しているか。
5. モジュール境界をまたぐエラーパス: reCAPTCHA検証失敗、HMACトークン改ざん・期限切れ・
   不正形式、CORS許可外オリジン、news.cgiのパストラバーサル/存在しない記事、といった
   異常系が内部仕様通りに(生の500ではなく)処理されるか。
6. CORS設定(同5章)の実際のレスポンスヘッダー。

**この環境では実施できなかったもの(既知のインフラ依存ギャップ、
`docs/PROJECT_STATUS.md`チェックポイント18の残タスク1・2・7・8と同一):**
実際のCyberhome/Apache実機、実際のVercelデプロイ、実際のGoogle reCAPTCHA本番キー・
GitHub Actions実行、実際のsendmail。これらを要する検証(Playwright残り5シナリオ、
本番reCAPTCHAキーでの疎通、実メール受信確認)はフェーズ8以降に持ち越す。

## 実施方法の要点

- Python 3.12.10(`api/requirements.txt`+`-dev`インストール済み)でuvicornを実際に
  起動し(`RECAPTCHA_SECRET_KEY`等ダミー値を環境変数として設定)、`curl`で
  `GET /api/faq`・`GET /health`・`POST /api/verify-recaptcha`・`OPTIONS`
  プリフライトを実際に叩いた。
- Perl 5.42(Cygwin)で`site/cgi-bin/lib/`の`.pm`を直接ロードし、
  `api/app/services/recaptcha_service.py`の`_issue_token()`が生成した**実際の
  トークン文字列**をコピーして`ContactLogic::verify_token()`に**実際に**渡した
  (シークレットは両者に同一のテスト値`shared-test-secret-for-system-test`を使用)。
- `contact.cgi`実行のため、`CGI->new`/`param()`のみを実装した最小限のテスト用
  `CGI.pm`スタブ(非シップ、`PERL5LIB`経由でのみ読み込み)を用意し、実際の
  `application/x-www-form-urlencoded`ボディをSTDIN経由で`contact.cgi`に渡した
  (Cygwin環境にCGI.pm本体が未導入のため。フェーズ6チェックポイント16と同じ制約・
  同じ回避策)。
- 検証用に一時的に`site/conf/hmac_secret.txt`(`.gitignore`対象、Git管理外)を
  作成し、テスト後に削除した。テスト実行で生成された`site/cgi-bin/contact_log.txt`・
  `contact_error_log.txt`も削除済み。既存のPerl単体テスト67件は本テスト前後で
  再実行し、変化がないことを確認した(副作用なし)。

## 結果

| 検証項目 | 結果 | 備考 |
|---|---|---|
| HMACトークン: Python発行→Perl検証(正しいシークレット) | 合格 | 実際にPython側`_issue_token()`が生成したトークンをPerl側`verify_token()`に投入し`valid=1`を確認 |
| HMACトークン: 誤ったシークレットで検証 | 合格 | `token_signature_mismatch`で正しく拒否 |
| HMACトークン: 署名を1文字改ざん | 合格 | `token_signature_mismatch`で正しく拒否 |
| HMACトークン: フォーマット不正(区切りなし) | 合格 | `invalid_token_format`で正しく拒否 |
| HMACトークン: 欠如(undef) | 合格 | `missing_token`で正しく拒否 |
| HMACトークン: 期限切れ(400秒経過) | 合格 | `token_expired`で正しく拒否(300秒の閾値通り) |
| HMACトークン: 未来方向クロックスキュー61秒超 | 合格 | `token_expired`で正しく拒否(60秒許容の境界通り) |
| HMACトークン: 未来方向クロックスキュー30秒(許容範囲内) | 合格 | `valid=1`、60秒以内は正しく許容 |
| `GET /api/faq`実レスポンス形状 | 合格 | 実uvicornで`{"faqs":[],"updated_at":"..."}`+`Cache-Control: no-store`を確認。`chat-widget.js`の`Array.isArray(data.faqs)`判定・空配列時の`renderFaqEmpty()`分岐と整合 |
| `GET /health`実レスポンス形状 | 合格 | `{"status":"ok","service":"homepage-api","time":"..."}`、200を確認 |
| `POST /api/verify-recaptcha`: `recaptcha_response`欠如 | 合格 | 400 `{"verified":false,"reason":"missing_recaptcha_response"}`を実際に確認(不正JSON本文でも同じ経路に正しくフォールバック) |
| CORS: 許可オリジンからの`/api/faq` | 合格 | ヘッダーに影響なし(GETは単純リクエストのため契約通り不要) |
| CORS: 許可外オリジンからの`/api/faq` | 合格 | `Access-Control-Allow-Origin`ヘッダーが付与されないことを確認(ブラウザ側で正しくブロックされる設計) |
| CORS: `OPTIONS /api/verify-recaptcha`プリフライト | **軽微な不一致** | `Access-Control-Allow-Origin`・`Allow-Methods`は契約通り。ただし`Access-Control-Max-Age`が**600**(Starletteのデフォルト)であり、`internal-spec-integration.md` 5.2節・8章が定める**86400**と不一致。`api/app/main.py`の`CORSMiddleware`呼び出しに`max_age=86400`が指定されていないため。機能は破綻しない(プリフライトの再送頻度が上がるだけ)が契約違反。既存pytest(`test_recaptcha.py`ケース13)もこの値をアサートしておらず未検出だった |
| `contact.html`↔`contact.cgi`: フィールド名一致 | 合格 | `last_name`/`first_name`/`email`/`email_confirm`/`message`/`privacy_agree`/`verify_token`が実HTML・実CGI・実`ContactLogic.pm`で完全一致 |
| `contact.cgi`: 正常系(ASCII値+有効トークン) | 合格(環境制約あり) | Refererチェック・バリデーション・トークン検証・重複判定まで正常に通過。`sendmail`本体がこの開発環境に存在しないため送信自体は失敗するが、`send_via_sendmail`が0を返し`Common::render_error_page`的な生500にはならず、契約通りの「送信エラー」HTMLページに正しくフォールバックすることを確認(sendmail疎通自体はCyberhome実機依存でフェーズ7では検証不能) |
| `contact.cgi`: 不正/改ざんHMACトークンでのPOST | 合格 | 500ではなく`_render_rejection()`経由で実際の`contact.html`が`<ul class="error-list">`付きで正しく再描画されることを確認(fail-closed設計通り) |
| **`contact.cgi`: 日本語(マルチバイト)フォーム値の処理** | **不合格** | 下記「発見した問題1」参照。姓・名・お問い合わせ内容に日本語を入力すると文字化けする |
| `news.cgi`: 記事0件時の一覧表示 | 合格 | `site/news/`が未作成でもクラッシュせず空の`<ul class="news-list">`を返す |
| `news.cgi`: 不正な`id`パラメータ(パストラバーサル試行) | 合格 | 正規表現で弾かれ400 `不正なリクエストです。`を返す(生500にならない) |
| `news.cgi`: 存在しない記事ID | 合格 | 404 `記事が見つかりません。`を返す |
| `download.cgi`: `REMOTE_USER`/`%BOOK_USERS`の認可マッピング | 合格(コード読み合わせ) | Apache Basic認証実機がないため`REMOTE_USER`注入自体は検証不能だが、`authorize_book_access()`のロジックと`.htpasswd.example`のユーザー名規約(`book1user`/`book2user`)は一貫している |
| `.htaccess`(cgi-bin/dl/qr)のrealm共有設定 | 合格 | `AuthName "Book Bonus Content"`・`AuthUserFile`パスが3ファイルで完全一致(単一サインオン設計通り) |
| 環境変数名の突合(`RECAPTCHA_SECRET_KEY`/`INTEGRATION_HMAC_SECRET`/`ALLOWED_ORIGIN`/`SMOKE_TEST_SECRET`/`RECAPTCHA_TEST_SECRET_KEY`/`VERCEL_ENV`) | 合格 | `api/app/core/config.py`・`api/tests/conftest.py`・`api/.env.example`・`site/conf/hmac_secret.example.txt`・JS(`contact-form.js`/`chat-widget.js`)間で名称ドリフルなし |
| 環境変数名の突合(`CYBERHOME_FTP_HOST`/`_USER`/`_PASSWORD`/`_PORT`/`CYBERHOME_PUBLIC_HTML_PATH`/`VERCEL_API_BASE_URL`/`SITE_BASE_URL`) | 合格 | `internal-spec-repo-cicd.md`・`internal-spec-testing.md`・`.github/workflows/*.yml`間で一致(過去に発見された`HMAC_SHARED_SECRET`のような旧称混在は再発していない) |
| 既存単体テスト回帰(副作用確認) | 合格 | 本テスト前後でPerl 67/67件成功のまま変化なし |

## 発見した問題

### 1. 【重大・不合格】`contact.cgi`が日本語フォーム入力を文字化けさせる(CGI境界のUTF-8デコード漏れ)

**症状:** `contact.html`から日本語の姓・名・お問い合わせ内容を送信すると、
(a) バリデーションエラー時に再描画される`contact.html`内の値、
(b) 運営者宛通知メールの件名・本文、(c) 送信者宛自動返信メールの本文、
(d) `contact_log.txt`への記録、のいずれも文字化けする
(例: 「山田」が「å±±ç°」のように表示される)。

**再現方法・確認済みの根本原因:** `site/cgi-bin/contact.cgi`は`CGI->new`のみを
呼び出しており、`use CGI '-utf8';`または`$CGI::PARAM_UTF8 = 1;`のいずれも設定して
いない。この状態でのCGI.pmの標準的な挙動は、POSTボディの`%XX`パーセントエンコードを
**バイト列レベルでのみ復号し、UTF-8としてのデコードは行わない**(=マルチバイト文字が
1バイトずつ別々のcodepointとして扱われるPerl文字列になる)。この状態の文字列を、
`contact.cgi`側の`binmode(STDOUT, ':encoding(UTF-8)')`や
`Common::render_template()`・`ContactLogic::build_notification_mail()`等の
UTF-8前提のコードにそのまま渡すと、出力時に二重エンコードが発生し文字化けする。

この挙動は、実際にCGI.pmと同じ復号アルゴリズム(`%XX`→バイト単位の`chr()`)を実装した
最小限のテストハーネスを用意し、実際の`contact.cgi`を日本語入力で実行して**再現を確認
済み**(添付なし、本レポート作成時のローカル一時実行)。また、同一ハーネスに
`Encode::decode_utf8()`によるデコードを1行加えるだけで文字化けが解消することも確認し、
根本原因の特定・対処法の妥当性を裏付けた。

**なぜフェーズ6の単体テスト(67件)で検出されなかったか:** `ContactLogic.t`等の
既存テストは、テストファイル自体に`use utf8;`を宣言した上で`'山田'`のような
**ソースコードリテラル**を関数に直接渡している。これは最初からPerlの内部表現として
正しくデコードされた文字列であり、実際のCGI.pmが生成する「バイト列のまま」の文字列とは
異なる。つまり67件の単体テストは`ContactLogic.pm`・`Common.pm`単体の正しさ(仕様通り)を
証明しているが、`contact.cgi`が実際のCGI環境からこれらの関数へ**正しくデコードされた
文字列を渡せているか**という、CGI境界をまたぐ契約は一度も検証されていなかった。
これはまさにフェーズ7(システムテスト)が担うべき継ぎ目である。

**影響範囲:** `download.cgi`・`news.cgi`が受け取るCGIパラメータ(`file`・`id`)は
いずれも英数字のみを許可する正規表現でバリデーションされているため、この問題の
影響を受けない。影響は`contact.cgi`が受け取る日本語自由入力フィールド
(`last_name`/`first_name`/`message`)に限定される。ただしこれは問い合わせフォームの
根幹機能(運営者への通知メール・自動返信メール)そのものであり、日本語の会社サイトに
とって実質的にフォームが機能しないに等しい重大度と判断する。

**推奨される修正(フェーズ6への差し戻し内容):** `site/cgi-bin/contact.cgi`の
`my $cgi = CGI->new;`の前に`$CGI::PARAM_UTF8 = 1;`を追加するか、`use CGI '-utf8';`に
変更する。修正後、`%params`の各値が正しくデコードされることを、本レポートと同様の
「実際にCGI.pm相当の処理を通した」テスト(ユニットテストではなくシステムテスト
相当の検証)で再確認すること。あわせて、テストハーネスがCGI.pm不在のCygwin環境でも
UTF-8デコード有無の差を検出できるよう、`site/cgi-bin/lib/t/`に「バイト列のまま
渡された場合にdie/文字化けしない」ことを保証するテストを追加するか、あるいは
`contact.cgi`側でCGI.pmから取得した値を明示的に`Encode::decode_utf8()`する
防御的実装に変更することを検討すべき(CGI.pmの`-utf8`設定漏れという同種のミスが
将来のCGIスクリプト追加時に再発するのを防ぐため)。

### 2. 【軽微】CORS `Access-Control-Max-Age`が契約値(86400)と不一致

`api/app/main.py`の`CORSMiddleware`に`max_age`が指定されておらず、Starletteの
デフォルト値600秒がそのまま使われている。`internal-spec-integration.md` 5.2節・
8章は86400秒(24時間)を確定値としている。機能的な破綻はない
(プリフライトの再送頻度が上がるのみ)が、実装済みの契約と乖離している。
`api/tests/test_recaptcha.py`ケース13もこの値をアサートしていないため
単体テストでは検出されない。

**推奨修正:** `CORSMiddleware`呼び出しに`max_age=86400`を追加し、
`test_recaptcha.py`ケース13に`Access-Control-Max-Age`のアサーションを追加する。
軽微なため、この1点のみを理由にフェーズ8の着手を止める必要はないと判断するが、
フェーズ6への軽微な差し戻し(または保守タスク)として記録する。

### 3. (参考、フェーズ6の残タスクの再確認)実機依存のため本フェーズでは検証不能な項目

`docs/PROJECT_STATUS.md`チェックポイント18の残タスク1・2・7・8(`VERCEL_API_BASE_URL`・
reCAPTCHAサイトキーのプレースホルダー未置換、Playwright残り5シナリオ未実行、
GitHub Secrets/Variables未登録、Cyberhome実機`.htpasswd`/`hmac_secret.txt`未配置)は、
いずれも実インフラが存在しない本環境では原理的に検証不可能であり、新たな問題としてでは
なく、既知の残タスクとして再確認するに留めた。これらは合否判定には含めない
(フェーズ8着手前に運営者作業として解消することが望ましい)。

## 判定(初回、2026-08-02): 不合格(要修正)

**理由:** 「発見した問題1」(`contact.cgi`の日本語入力文字化け)は、問い合わせフォームの
根幹機能(通知メール・自動返信メール・エラー再描画)に影響する実際の統合バグであり、
フェーズ6の単体テスト148件では検出できていなかった。ペーパー上の仕様確認では気づけず、
実際にCGI境界を通したデータフローを再現して初めて発見できた、まさにシステムテストが
担うべき種類の欠陥である。

このため、`site/cgi-bin/contact.cgi`(および望ましくは`download.cgi`/`news.cgi`にも
防御的に同様の設定)の修正をフェーズ6に差し戻し、修正後に本レポートの
「HMACトークン契約」「`contact.html`↔`contact.cgi`契約」の該当項目、特に日本語値を
含む正常系・エラー系の再テストを実施した上で、フェーズ7を再度合格判定すること。

「発見した問題2」(CORS Max-Age)は軽微であり、単独では不合格の理由にしないが、
問題1の修正と合わせて対応することを推奨する。「発見した問題3」に列挙した実機依存の
残タスクは、今回の合否判定の対象外(フェーズ6完了時点から状態変化なし)。

上記2点以外(HMACトークンの生成・検証・改ざん・期限切れ・時計スキュー、FAQ APIの
実レスポンス形状、CORSの許可/拒否判定自体、`news.cgi`/`download.cgi`のエラーパス、
`.htaccess`のrealm共有、環境変数名の突合)は、実際にコードを動かした検証で
いずれも内部仕様通りに動作することを確認した。

---

## 再テスト: 2026-08-02(フェーズ6差し戻し対応完了後の再判定)

### 目的・スコープ

`docs/PROJECT_STATUS.md`チェックポイント20(コミット`acbd3b6`/`0b726a6`)で報告された
「フェーズ6が発見した問題1・2を修正した」という自己申告を、担当した実装エージェントとは
別の視点で独立に再検証する。修正がタッチした`site/cgi-bin/contact.cgi`・
`api/app/main.py`周辺の再確認を中心に行い、それ以外の既合格項目は今回の修正で影響を
受けないため全面的なやり直しはせず、実際にテストを再実行して回帰がないことのみ確認した。

### 実施内容

1. **Perl単体テスト全件再実行(`site/cgi-bin/lib/t/*.t`、5ファイルすべて個別に`perl`実行、
   TAPの`ok`/`not ok`件数を実際に集計):**
   `Common.t`14 + `ContactCgiUtf8Boundary.t`5 + `ContactLogic.t`27 + `DownloadLogic.t`19 +
   `NewsLogic.t`7 = **合計72件、全件成功(0失敗)**。フェーズ6差し戻しの自己申告値と一致。

2. **UTF-8境界の独立再検証(フェーズ6の`ContactCgiUtf8Boundary.t`をそのまま信用せず、
   自分で新規に書いたハーネス`my_utf8_boundary_check.pl`で再現・確認):**
   既存の回帰テストとは別に、以下を独自に実装して実行した(スクラッチパスに保存、
   リポジトリには追加していない一時検証スクリプト)。
   - **フルパス正常系:** 実際に`site/conf/hmac_secret.txt`をテスト用に生成し、
     Python側`_issue_token()`と同一アルゴリズムで有効なHMACトークンを作成した上で、
     日本語の姓「鈴木」・名「花子」・複数行を含むお問い合わせ本文を、実際の
     `application/x-www-form-urlencoded`のUTF-8バイト列としてSTDIN経由で実際の
     `contact.cgi`(子プロセス)に投入。バリデーション・トークン検証を実際に通過し
     (エラー再描画に落ちないことを確認)、`Common::write_log()`が書いた
     `contact_log.txt`の**生バイト列**を直接読み、期待するUTF-8バイト列
     (`鈴木 花子`)が正しく含まれ、旧バグ時に発生するはずの二重エンコード
     mojibakeバイトパターンが含まれないことを確認。フェーズ6の回帰テストは
     verify_token到達前の検証に留めていたが、本テストはHMACトークン検証・
     重複判定・ログ記録まで到達させ、フェーズ6のテストより検証範囲を1段階
     広げた。
   - **エラー再描画経路:** メール確認不一致でわざと`validate_input()`を失敗させ、
     日本語の姓「高橋」・名「美咲」・本文を含む`_render_rejection()`出力(実際の
     `contact.html`テンプレート再描画結果)に、正しいUTF-8バイト列がそのまま
     現れることを確認(3項目とも合格)。
   - **メール本文組み立て関数への受け渡し:** `contact.cgi`と同じCGI.pmスタブ+
     `$CGI::PARAM_UTF8=1`の経路で得たデコード済みパラメータを実際に
     `ContactLogic::build_notification_mail()`・`build_autoreply_mail()`に渡し、
     件名・本文・`Content-Type: text/plain; charset=UTF-8`ヘッダーに正しい
     UTF-8文字列が現れることを確認(この開発環境には実sendmailが存在しないため、
     実際のメール送信・受信そのものは検証できないが、送信直前のメール本文構築が
     正しいことは確認できた)。
   - **合計16項目、全件合格。**
   - **修正が本物に効いているかの裏取り(重要):** 上記と同一のハーネスを、
     一時的に`contact.cgi`を修正前バージョン(コミット`a611b40`時点、
     `$CGI::PARAM_UTF8 = 1;`なし)に差し替えた状態で実行し直したところ、
     フルパス正常系のログ内容確認2件・エラー再描画の3件、**合計5件が実際に
     失敗する**ことを確認した(=このテストは本物のバグを検出できる)。
     その後修正版に完全に戻し(作業ツリーに差分が残っていないことを
     `git status` / `git diff --stat HEAD`で確認)、再実行して16件全件合格に
     戻ることを確認した。

3. **pytest全件再実行(`api/tests/`、Python 3.12.10 + `pip install -r requirements.txt
   -r requirements-dev.txt`済みの環境):** `test_faq.py`12 + `test_health.py`3 +
   `test_recaptcha.py`16(Max-Ageアサーションを含むケース13を含む) =
   **合計31件、全件成功**。フェーズ6差し戻しの自己申告値と一致。

4. **CORS `Access-Control-Max-Age`のライブ検証(pytestのTestClientだけに頼らず、
   実際にuvicornを起動して生のHTTPレスポンスヘッダーを確認):**
   `uvicorn app.main:app`をこの環境で実際に起動(`RECAPTCHA_SECRET_KEY`等はダミー値を
   環境変数として設定)し、`curl`で`OPTIONS /api/verify-recaptcha`プリフライトを実際に
   送信したところ、レスポンスヘッダーに`access-control-max-age: 86400`が実際に
   返っていることを確認した(pytestの`TestClient`経由ではなく、TCPソケット越しの
   実HTTPレスポンスとして確認)。あわせて`GET /health`・`GET /api/faq`・許可外オリジンの
   プリフライト拒否(`Disallowed CORS origin`、400)も同じ起動中のサーバーに対して
   再確認し、いずれも元の報告書の合格判定通りの挙動のままであることを確認した。

5. **HMACトークン契約の再確認(`main.py`変更がこの契約に影響しないことの裏取り):**
   Python側`recaptcha_service._issue_token()`を実際に呼び出して得たトークンを、
   Perl側`ContactLogic::verify_token()`に実際に投入し、正しいシークレットでは
   `valid=1`、誤ったシークレットでは`token_signature_mismatch`で正しく拒否される
   ことを再確認した(前回報告の合格判定に変化なし)。

### 結果(追加・更新分)

| 検証項目 | 結果 | 備考 |
|---|---|---|
| Perl単体テスト全72件(既存67+`ContactCgiUtf8Boundary.t`5) | 合格 | 個別`perl`実行でTAP集計、全件成功。フェーズ6自己申告値と一致 |
| `contact.cgi`日本語入力: フルパス正常系(HMACトークン検証・重複判定・`contact_log.txt`記録まで到達) | 合格 | 独自ハーネスで新規検証(フェーズ6の回帰テストより検証範囲が広い)。ログファイルの生バイト列で文字化けなしを確認 |
| `contact.cgi`日本語入力: エラー再描画経路(姓・名・本文) | 合格 | 独自ハーネスで新規検証。3項目とも文字化けなし |
| `ContactLogic::build_notification_mail`/`build_autoreply_mail`への受け渡し | 合格 | CGI境界でデコードされた値がメール本文組み立て関数に正しく渡ることを確認(実sendmail送信自体は環境制約により検証不能) |
| 上記独自ハーネスが実際にバグを検出できることの裏取り(修正前バージョンで再実行) | 合格 | 5/16項目が実際に失敗することを確認後、修正版に復元して16/16に戻ることを確認。誤検知でないことを裏取り済み |
| pytest全31件(`test_faq.py`12/`test_health.py`3/`test_recaptcha.py`16) | 合格 | 実行環境で再実行、全件成功。フェーズ6自己申告値と一致 |
| CORS `Access-Control-Max-Age`(実uvicorn起動+実HTTPレスポンス) | 合格 | `curl`での生レスポンスヘッダーで`access-control-max-age: 86400`を確認(pytestに頼らない独立検証) |
| CORS: 許可外オリジンの`OPTIONS`プリフライト拒否 | 合格 | 実uvicornで`400 Disallowed CORS origin`を再確認、回帰なし |
| `GET /health`・`GET /api/faq`実レスポンス | 合格 | 実uvicornで再確認、回帰なし |
| HMACトークン契約(Python発行→Perl検証、正しい/誤ったシークレット) | 合格 | 再確認、回帰なし |

### 発見した問題(再テスト時点)

なし。フェーズ6差し戻し対応で報告された「発見した問題1」(`contact.cgi`日本語文字化け)
「発見した問題2」(CORS Max-Age)は、いずれも独立した再検証(自己申告のテストファイルの
再実行だけでなく、別の視点で新規に書いたテストハーネスによる確認、および実際にバグを
再現させて検出できることの裏取り)によって解消されていることを確認した。新たな問題は
見つからなかった。

### 判定(更新、2026-08-02再テスト): 合格

**理由:** 前回不合格の根拠となった2件の欠陥がいずれも修正され、修正内容を自己申告の
再実行だけでなく独立に書いた別のテストハーネスで再現・確認できた。既存の合格項目
(HMACトークン契約、FAQ API契約、CORSの許可/拒否判定、`news.cgi`/`download.cgi`の
エラーパス、`.htaccess`のrealm共有、環境変数名の突合)にも回帰は見られない。

**フェーズ8(E2Eテスト)を次に着手してよい。** ただし、前回報告の「発見した問題3」に
列挙した実機依存の残タスク(Vercel/reCAPTCHA実値の未設定、Playwright残り5シナリオ未実行、
GitHub Secrets未登録、Cyberhome実機の`.htpasswd`/`hmac_secret.txt`未配置)は解消されて
いないままであり、フェーズ8が実機に対して実施できる範囲はこれらの状態に制約される
(`docs/PROJECT_STATUS.md`チェックポイント18・21を参照)。

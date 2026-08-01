# 内部仕様(フェーズ4 Wave2): Cyberhome/Perl CGI 内部設計

## 位置づけ

本ドキュメントは、フェーズ4(内部仕様調査)を6分割したサブエージェントのうち
Wave2「Cyberhome/Perl CGI内部設計」担当分の成果物である。Wave1で並列実行された
3エージェントの成果物(`internal-spec-integration.md`・`internal-spec-repo-cicd.md`・
`internal-spec-datamodel.md`、いずれも確定済み)を前提とし、それらの契約・
ディレクトリ構成を変更せず、その内側で実装可能な粒度までCyberhome側Perl CGI
(`contact.cgi`・`download.cgi`・`news.cgi`)とQRコード遷移ページの設計を詰める。

参照元(すべて確定済み、編集していない):
- `docs/specs/external-spec.md`(承認済み)
- `docs/specs/architecture.md`(ドラフト確定)
- `docs/specs/phase4-clarification.md`(全280問回答済み。以下、ラウンド名+節記号+問番号で
  引用する。例: 「ラウンド2 B6」「Infra2/5 L2」「保守5/5 W6」)
- `docs/specs/internal-spec-integration.md`(Cyberhome⇔Vercel連携契約、そのまま採用)
- `docs/specs/internal-spec-repo-cicd.md`(ディレクトリ構成、そのまま採用)
- `docs/specs/internal-spec-datamodel.md`(共通規約: UTF-8・snake_case等。FAQ/DB部分は
  Vercel側の担当のため参照のみ)

対象外(他エージェントの担当):
- Vercel/FastAPI側の実装(FAQ API・reCAPTCHA検証・GUI)
- Neon DBスキーマ(`internal-spec-datamodel.md`が担当)
- GitHub Actionsワークフローの全体設計(`internal-spec-repo-cicd.md`が担当。ただし
  Perlユニットテストの実行という観点でCI追加を1点提案する、8章参照)

---

## 0. Wave1成果物との整合(本ドキュメントで解消した細部の食い違い)

Wave1の3ドキュメントを突き合わせた結果、以下2点は本ドキュメントのスコープ内で
矛盾なく解消できたため、Wave1文書自体は変更せず、本書で確定版として扱う。

### 0.1 `download.cgi`の配置とBasic認証の掛かり方

`architecture.md`は当初「`download.cgi`が置かれたディレクトリ自体をBasic認証で保護する」
という設計だったが、`internal-spec-repo-cicd.md`が確定させたディレクトリ構成では
`download.cgi`は`site/cgi-bin/`直下に置かれ、`site/dl/`は`.htaccess`/`.htpasswd`/
`access_log.txt`のみを持つ別ディレクトリになっている。このままでは`dl/`のBasic認証が
`cgi-bin/download.cgi`に効かない。

**解決:** `site/cgi-bin/`直下にも`.htaccess`を新設し(`internal-spec-repo-cicd.md`の
ツリー図には明示されていないが、同ディレクトリへのファイル追加であり確定済みパスの
変更ではないため本書の裁量で追加する)、`<Files "download.cgi">`ブロックで
`download.cgi`のみを保護する。`AuthUserFile`は`site/dl/.htpasswd`を指す(ファイルの
実体は`dl/`に1つだけ置き、`qr/`・`cgi-bin/`の両方から同じファイルを参照する。詳細は
7章)。`contact.cgi`・`news.cgi`は認証なしで公開する。

### 0.2 書籍ごとに別々のID・パスワード(ラウンド1 D22=A)と、単一の`download.cgi`スクリプトの両立

`download.cgi`はbook1/book2共通の単一スクリプト・単一URL
(`/cgi-bin/download.cgi?file=...`)であるため、Apacheの`.htaccess`レベル
(`AuthUserFile`)だけではクエリパラメータ単位で異なる認証情報を要求できない
(Apache Basic認証はディレクトリ/ファイル単位のスコープであり、クエリ文字列では
分岐できない)。

**解決(本書で確定する設計):**
- Apache認証(`Require valid-user`)は「book1用ユーザーとbook2用ユーザーの両方を
  含む単一の`.htpasswd`」に対して行い、「有効なユーザーの誰か」であることのみを
  確認する(識別=authentication)。
- 実際の「book1のファイルにはbook1ユーザーしかアクセスできない」という制御
  (authorization)は、`download.cgi`内のPerlコード(`DownloadLogic.pm`)が
  `$ENV{REMOTE_USER}`と要求された`file`パラメータの書籍プレフィックスを突き合わせて
  行う(一致しなければ403)。
- これにより「書籍ごとに別々のパスワード」という要件(ラウンド1 D22=A)を維持しつつ、
  運営者が年次更新時に触るパスワードファイルは`.htpasswd`1つのみに抑えられる
  (保守性重視の要件に合致)。
- QRページ(`qr/book1.html`・`qr/book2.html`)も同じ`.htpasswd`を参照する
  (`Require valid-user`のみ、ページ単位の書籍別分離はしない。理由: QRページ自体は
  「ダウンロードへの案内」であり機密情報を含まないため、Apache層での作り込みコストに
  見合わない。実際の機密資産(特典ファイル)の保護は`download.cgi`側のPerlレベル認可で
  担保する)。
- `qr/.htaccess`と`cgi-bin/.htaccess`の`<Files "download.cgi">`ブロックの
  `AuthName`は**完全に同一の文字列**にする(例: `"Book Bonus Content"`)。これにより
  多くのブラウザはHTTP認証の保護空間(realm)をスキーム+ホスト+realmの組で判定するため、
  QRページで一度認証すればダウンロード時に再度パスワード入力を求められにくくなる
  (RFC 7235のprotection spaceの一般的な実装挙動に基づく推奨設定。ディレクトリが
  異なっても一部ブラウザで認証情報がキャッシュ再利用される可能性を高める、という
  保守的な工夫であり、必須の互換性保証ではない)。

---

## 1. 全体像(このドキュメントのスコープ)

```
site/
├── index.html, contact.html, contact-thanks.html, privacy.html, news.html
├── css/, js/ (静的資産、他フェーズ/Waveの担当)
├── news/*.txt                      ← news.cgi が読む記事ファイル
├── templates/header.html, footer.html
├── cgi-bin/
│   ├── .htaccess                    ← 新設(0.1節、<Files "download.cgi"> のみ保護)
│   ├── news.cgi
│   ├── contact.cgi
│   ├── download.cgi
│   ├── contact_log.txt              ← contact.cgi が追記(Git管理外)
│   ├── contact_error_log.txt        ← contact.cgi が追記(Git管理外)
│   ├── error_log.txt                ← 3CGI共通の予期しない500エラーログ(Git管理外)
│   └── lib/
│       ├── .htaccess                ← 新設、Require all denied(ソース直接閲覧防止)
│       ├── Common.pm
│       ├── ContactLogic.pm
│       ├── DownloadLogic.pm
│       ├── NewsLogic.pm
│       └── t/                       ← Test::More テスト(.ftpdeployignoreで本番除外)
├── conf/
│   ├── .htaccess                    ← 新設、Require all denied
│   ├── hmac_secret.example.txt
│   └── hmac_secret.txt (Git管理外、実行時配置)
├── dl/
│   ├── .htaccess
│   ├── .htpasswd (Git管理外。book1/book2共通、実体は1つ)
│   ├── .htpasswd.example
│   └── access_log.txt (Git管理外、月次ローテーション)
├── qr/
│   ├── .htaccess
│   ├── book1.html, book2.html
│   └── (.htpasswdは持たず、dl/.htpasswd を参照。0.2節)
└── Contents/
    ├── .htaccess                    ← 新設、Require all denied(直リンク防止、3.5節)
    ├── book1/*.pdf 等
    └── book2/*.xlsx 等
```

---

## 2. `contact.cgi` 詳細設計

### 2.1 画面遷移とフォーム項目

- GET: `site/contact.html`(静的、Apacheが直接配信)。reCAPTCHA v2ウィジェット・
  プライバシー同意チェックボックス(デフォルト未チェック、ラウンド2 R30=A)を含む。
- POST: `contact.html`の`<form method="POST" action="cgi-bin/contact.cgi">`から
  `contact.cgi`へ送信。
- 項目順序(ラウンド2 B11=A確定): 姓・名・メールアドレス・メールアドレス(確認用)・
  問い合わせ内容・プライバシー同意チェック・reCAPTCHAウィジェット・
  `verify_token`(hidden、`internal-spec-integration.md` 1.4節)・送信ボタン。
- 文字コード: UTF-8(ラウンド1 B6=A)。
- 問い合わせ内容の文字数制限: なし(ラウンド1 B7=A、自由入力)。氏名の全角/半角も
  指定しない(ラウンド2 R26=A)。

### 2.2 処理フロー(ステップバイステップ)

```
1. CGI.pm でPOSTパラメータを取得(Infra2/5 L7=A)。
2. Refererチェック(2.9節)。空は許可、値がある場合のみ自ドメインと照合。
   不一致なら reject → 2.8節のエラー再表示。
3. 各フィールドのバリデーション(2.3節)。1件でも失敗なら reject。
4. verify_token の検証(2.5節、internal-spec-integration.md 1.2節のロジックを
   そのまま使用)。欠如・不正・期限切れは常にfail-closedで reject。
5. 重複送信判定(2.4節)。5分以内に同一IP+同一メールアドレスの送信記録が
   contact_log.txt にあれば reject。
6. contact_log.txt に「受付」レコードを追記(送信結果に関わらず、この時点で
   記録することで6の送信失敗時も痕跡が残る)。
7. 営業時間判定(平日10:00-17:00、Perlの localtime を使用。Infra2/5 L5=Cにより
   タイムゾーンのズレは許容範囲として実装を進める)。
8. sendmail 呼び出し(2.6節)で (a) 運営者宛通知メール (b) 送信者宛自動返信メール
   の2通を送信。
9. 8が両方成功: contact_log.txt の当該レコードのresultを"sent"にする代わりに
   追記型ログの性質上、新たに"sent"の完了行は追記せず、6で書いた受付行のみで
   十分とする(2.7節参照)。302 Redirect で `contact-thanks.html` へ(PRG
   パターン、internal-spec-repo-cicd.md がcontact-thanks.htmlを既に配置している
   ことと整合)。
10. 8が失敗(sendmail異常終了等): contact_error_log.txt に失敗理由を追記
    (ラウンド2 B9=A)。ユーザーには汎用エラーページ
    (「送信に失敗しました。時間をおいて再度お試しください。」ラウンド1 B14=A)を
    200で返す(リダイレクトしない、直前の入力内容は保持しない — 失敗は稀な
    インフラ障害であり、フォーム再入力の手間よりも「失敗した」ことを明確に
    伝えることを優先する)。
11. 3または4または5で reject した場合: contact.html を土台にした再描画
    (2.8節)。
```

### 2.3 バリデーションルール

| フィールド | ルール | 失敗時メッセージ(例) |
|---|---|---|
| 姓・名 | 空でないこと(1文字以上)。改行コード除去(2.6節のヘッダインジェクション対策と共通処理)。全角/半角は問わない(ラウンド2 R26=A) | 「姓を入力してください」等 |
| メールアドレス | 空でないこと、簡易正規表現でチェック(ラウンド2 R27=A、RFC厳密準拠は行わない: `/^[^@\s]+@[^@\s]+\.[^@\s]+$/`) | 「メールアドレスの形式が正しくありません」 |
| メールアドレス(確認用) | 上記に加え、メールアドレス欄と完全一致(ラウンド1 B12=C: JS側でも即時チェックするが、CGI側でも必ず再検証する) | 「メールアドレスが一致しません」 |
| 問い合わせ内容 | 空でないこと。文字数制限なし(ラウンド1 B7=A)。`<`・`>`はエスケープしてプレーンテキストとして扱う(ラウンド2 R13=A、拒否はしない) | 「お問い合わせ内容を入力してください」 |
| プライバシー同意 | チェックが入っていること(必須) | 「プライバシーポリシーへの同意が必要です」 |
| `verify_token` | 2.5節参照(常にfail-closed) | 「検証に失敗しました。reCAPTCHAを再度確認してください」 |

エラーは1つのフォーム送信で複数同時に発生しうるため、`ContactLogic::validate_input()`
はエラーの配列を返す設計とし、`contact.cgi`はそれをまとめて2.8節のエラーサマリーに
渡す(ラウンド1 B15=A「ページ上部にまとめてエラー一覧表示」)。

### 2.4 重複送信判定(ラウンド1 B8=C、ラウンド2 B5=C)

判定キー: **送信元IPアドレス(`$ENV{REMOTE_ADDR}`) + メールアドレス**の組み合わせ
(内容の同一性は問わない)。ウィンドウ: **300秒(5分)**。`internal-spec-integration.md`
のHMACトークン有効期限(300秒)と意図的に同じ値に揃えてある(同ドキュメント1.3節の
根拠と同一)。

実装方針: `contact_log.txt`の末尾から遡って読み、300秒以内かつIP+メールアドレスが
一致する行があれば重複と判定する。ファイル全体を毎回読むのではなく、末尾から
一定行数(例: 直近200行、1日あたりの想定送信数からみて十分な余裕)のみを読む設計とし、
将来ログが肥大化しても性能劣化を抑える(`ContactLogic::is_duplicate_submission()`)。

### 2.5 `verify_token`の検証

`internal-spec-integration.md` 1.2節のPerlサンプルをそのまま`ContactLogic::verify_token()`
として実装する(`Digest::SHA`の`hmac_sha256_hex`を使用、コアモジュール)。共有
シークレットは`Common::read_secret_file()`(下記7章)で`conf/hmac_secret.txt`から
読み込む。欠如・書式不正・署名不一致・期限切れ(300秒超過または未来方向60秒超過)は
すべて同じ扱い(reject、fail-closed)とし、ユーザー向けエラーメッセージは
「検証に失敗しました。reCAPTCHAを再度確認してください」に統一する(内部的な失敗理由の
区別はログにのみ記録し、ユーザーには漏らさない — スパム対策の実効性を保つため)。

### 2.6 メール送信(`sendmail`)設計

- 実行コマンド: `/usr/sbin/sendmail -t -oi`(architecture.md確定パス)。
- **呼び出し方式:** シェル文字列ではなく**リスト形式の`open`**を用いる
  (`open(my $mail, '|-', '/usr/sbin/sendmail', '-t', '-oi')`)。これによりシェルを
  経由しないため、シェルメタ文字によるコマンドインジェクションのリスクを構造的に
  排除できる(ヘッダインジェクション対策(下記)とは別レイヤの防御)。
- **ヘッダインジェクション対策(Infra2/5 L2=A):** メールヘッダーに使う全ての
  ユーザー入力値(姓・名・メールアドレス)から改行コード(`\r`・`\n`)を除去してから
  使用する(`Common::strip_newlines()`)。件名(Subject)は運営者宛のみユーザー入力
  (氏名)を含むため、除去後の値を使う。
- **From/To設計:**
  - 運営者宛通知メール: To=`mainagak@gmail.com`(暫定送信元、architecture.md Q16確定)、
    From=`mainagak@gmail.com`(暫定、同上)、Reply-To=送信者のメールアドレス
    (除去済み値)。件名: `【FroEduXお問い合わせ】(姓名)様より`
    (ラウンド1 B10=B)。
  - 送信者宛自動返信: To=送信者のメールアドレス、From=`mainagak@gmail.com`。
    プレーンテキストのみ(ラウンド1 B9=A)、丁寧なビジネス文体(ラウンド2 B10=A)。
    営業時間外(平日10:00-17:00外)に受け付けた場合は「営業時間外のため、返信は
    翌営業日以降になります」という一文を追加する(ラウンド2 B14=B)。
- 2通とも送信に成功して初めて「成功」とみなす。片方でも失敗した場合は2.2節ステップ10
  の失敗処理に入る。

### 2.7 ログ設計

**`contact_log.txt`(通常ログ、cgi-bin/直下)** — タブ区切り、1送信=1行:

```
<ISO8601タイムスタンプ>\t<REMOTE_ADDR>\t<メールアドレス>\t<姓 名>\t<result>
```

`result`は`accepted`(バリデーション・reCAPTCHA通過、メール送信試行に進んだ)のみを
記録する(reject時は記録しない — 重複判定のノイズになるため。ただしreCAPTCHA不正・
バリデーション失敗はスパムの可能性が高くログとしての価値は別にあるため、将来
必要になれば`contact_reject_log.txt`として分離を検討できる余地を残す。MVPでは
未実装)。

**`contact_error_log.txt`(cgi-bin/直下、ラウンド2 B9=A)** — sendmail失敗時のみ追記:

```
<ISO8601タイムスタンプ>\t<REMOTE_ADDR>\t<メールアドレス>\t<エラー内容(sendmail終了コード等)>
```

運営者の週次ログ確認対象に含める(ラウンド2 B9=Aの確定通り)。

**書き込み方式共通:** `Fcntl`のロック定数を使い`flock($fh, LOCK_EX)`をベストエフォートで
試みる(Infra2/5 L1=C「気にせず`flock`を使い、問題が起きたら都度対応する」の確定
方針)。Cyberhomeのファイルシステムで`flock`が機能しない場合でも、月10件規模の
低頻度アクセスでは同時書き込み競合の実害は極めて小さいと判断し、`flock`失敗時に
CGI自体を失敗させることはしない(警告のみ、処理は継続)。

### 2.8 バリデーション失敗時のフォーム再描画(ラウンド1 B15=A、ラウンド2 B7=A)

`contact.html`を「唯一の情報源」として保ち、CGI側に別のHTMLテンプレートを二重管理
しないため、以下の方式を採用する:

- `contact.html`内に、エラー表示用・入力値保持用のプレースホルダーをHTMLコメントとして
  埋め込んでおく(例: `<!--CONTACT_ERRORS--><!--/CONTACT_ERRORS-->`,
  `<!--VALUE:last_name-->`)。
- `contact.cgi`はバリデーション失敗時、`Common::render_template()`で`contact.html`を
  ファイルから読み込み、上記プレースホルダーを (a) エラーサマリーの`<ul>`要素
  (2.3節のエラー配列から生成、ページ上部) (b) 各入力欄への`value="..."`
  (HTMLエスケープ済み)で置換して200 OKで返す。
- この方式により、`contact.html`のデザイン変更は常に1箇所(`contact.html`自体)を
  編集するだけで済み、CGI側のテンプレートと二重に保守する必要がない(保守性重視の
  要件に合致、Claude Codeによる将来の編集コストを最小化)。

### 2.9 CSRF対策(Referer、ラウンド1 B11=C、ラウンド2 B6=B)

```perl
my $referer = $ENV{HTTP_REFERER};
if (defined $referer && length $referer) {
    unless ($referer =~ m{^https://jyoho1\.web\.cyberhome\.ne\.jp/}) {
        reject_submission('referer_mismatch');
    }
}
# Refererが未送信(空/undef)の場合は許可する(緩めの運用、ブラウザ拡張機能や
# プライバシー設定でReferer自体を送らないケースを誤検知しないため)
```

---

## 3. `download.cgi` 詳細設計

### 3.1 認証・認可

- **認証(Apache/`.htaccess`):** `cgi-bin/.htaccess`の`<Files "download.cgi">`
  ブロックで`Require valid-user`(`dl/.htpasswd`参照、0.1/0.2節)。Apacheが認証に
  成功すると`$ENV{REMOTE_USER}`にログインIDがセットされる。
- **認可(Perl、`DownloadLogic::authorize_book_access()`):**
  ```perl
  my %BOOK_USERS = (
      book1 => ['book1user'],   # 実際のユーザー名は運営者が.htpasswd生成時に決定
      book2 => ['book2user'],
  );
  ```
  要求された`file`パラメータの先頭ディレクトリ(`book1`/`book2`)を取り出し、
  `$ENV{REMOTE_USER}`がそのリストに含まれなければ**403 Forbidden**を返し、
  `access_log.txt`に`forbidden_wrong_book`として記録する(3.4節)。
  このマッピングは運営者が新しい書籍を追加する際、`.htpasswd`へのユーザー追加と
  併せてClaude Codeに依頼して`DownloadLogic.pm`を更新してもらう想定(保守5/5 Y12=A、
  「QRページ・Basic認証設定等はClaude Codeに依頼」と整合)。

### 3.2 処理フロー

```
1. Apache Basic認証(前段、3.1節)。失敗時はApacheが401を返しCGIは起動しない
   (このためBasic認証失敗そのものはaccess_log.txtに記録できない、3.6節「制約」参照)。
2. CGI.pm で `file` クエリパラメータを取得。
3. パストラバーサル対策(3.5節)。不正なら400を返しログに記録して終了。
4. 書籍別認可チェック(3.1節)。不一致なら403を返しログに記録して終了。
5. ファイル存在確認(`Contents/<file>`)。存在しなければ404。
6. 拡張子からMIMEタイプ判定(3.3節)。
7. HTTPヘッダー出力:
   Content-Type: <判定結果>
   Content-Disposition: attachment; filename="<元のファイル名>"
   Content-Length: <ファイルサイズ>
8. ファイルをバイナリモードで開き、ストリーム出力(`binmode`必須、
   Cyberhomeのバイナリ転送モードと整合)。
9. access_log.txt に成功記録を追記(3.4節)。
```

### 3.3 MIMEタイプ判定(ラウンド1 D27訂正→ラウンド2 A2=A確定、拡張子ハードコード表)

```perl
my %MIME_TABLE = (
    pdf  => 'application/pdf',
    doc  => 'application/msword',
    docx => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    xls  => 'application/vnd.ms-excel',
    xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ppt  => 'application/vnd.ms-powerpoint',
    pptx => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
);
# 対応表にない拡張子は application/octet-stream にフォールバック(安全側のデフォルト)
```
`File::MimeInfo`はCPAN配布モジュールでありCyberhomeでは使用不可のため採用しない
(ラウンド2 A2の訂正確認通り)。

### 3.4 アクセスログ・月次ローテーション(ラウンド1 D25→ラウンド2 D24=C確定)

**`dl/access_log.txt`書式(タブ区切り):**
```
<ISO8601タイムスタンプ>\t<REMOTE_USER>\t<REMOTE_ADDR>\t<要求file>\t<result: ok|forbidden_wrong_book|not_found|bad_request>
```

**月次ローテーション方式(ラウンド2 D24=C確定):** 毎回の書き込み前に、
`access_log.txt`の最終更新月と現在の月を比較する(`(stat($path))[9]`の月と
現在の月をJSTベースで比較。タイムゾーンのズレが多少あっても月境界をまたぐ判定は
数日ズレる程度で実害は小さい)。月が変わっていれば、書き込み前に
`access_log.txt`を`access_log_YYYYMM.txt`にリネームしてから、新規の
`access_log.txt`に追記を開始する(`DownloadLogic::rotate_log_if_needed()`)。
アーカイブされた`access_log_YYYYMM.txt`は運営者が年次で手動アーカイブ・削除する
(ラウンド2 E30=A、テキストログの年次アーカイブ運用と同じ扱い)。

### 3.5 パストラバーサル・直リンク対策

- `file`パラメータは正規表現で厳密に検証する:
  `^(book[12])/([A-Za-z0-9_\-]+\.(pdf|docx?|xlsx?|pptx?))$`
  (Cyberhomeのファイル名制約=半角英数字のみ、と一致させている)。
  一致しない場合は`../`等を含め一律400 Bad Requestとし、`access_log.txt`に
  `bad_request`として記録する。
- **`site/Contents/.htaccess`で直接のHTTPアクセスを一律拒否する**
  (`Require all denied` / `Order deny,allow` + `Deny from all`、2.4系/2.2系両対応)。
  `download.cgi`はApacheのHTTPアクセス経路を通さずPerlのファイルI/Oで直接
  ファイルを読むため、この拒否設定の影響を受けない。これにより「URLを推測して
  `Contents/book1/xxx.pdf`に直接アクセスし、Basic認証・アクセスログの両方を
  バイパスする」という抜け道を塞ぐ(この対策自体は280問のいずれにも明示の
  質問はないが、「アクセスログを週次確認できるようにする」という確定要件
  (external-spec.md)を実効性のあるものにするために必須の設計であり、本書の
  裁量で決定する)。

### 3.6 既知の制約(設計上受容する事項)

- Apache Basic認証の失敗(パスワード誤り)はCGIが起動する前にApacheが401を
  返して完結するため、`download.cgi`のPerlコードでは失敗試行を記録できない
  (ラウンド1 D29=B「access_log.txtで失敗回数を記録」は、この構成では実現でき
  ないことを明記しておく。Apache自体のログ機能はCyberhomeにない、architecture.md
  確定済み)。ロックアウト等の対策は行わない(ラウンド1 D29の「対策なし」の
  範囲で運用する)。

---

## 4. `news.cgi` 詳細設計

### 4.1 記事ファイルフォーマット

配置: `site/news/*.txt`。命名規則は`YYYY-MM-DD-タイトル.txt`
(例: `2026-08-01-お知らせ.txt`、Infra2/5 L9=B確定)。

> **補足(参考情報、ブロッキングではない):** `internal-spec-repo-cicd.md`の
> ディレクトリツリー内の例示ファイル名は`20260801_お知らせ.txt`
> (`YYYYMMDD_タイトル.txt`形式)になっており、本書が採用する確定回答
> (Infra2/5 L9=B、`YYYY-MM-DD-タイトル.txt`)とハイフン/アンダースコアの
> 表記が異なる。これはWave1文書内の単なる例示表記のずれであり、ディレクトリ
> パス自体(`site/news/`)には影響しないため、本書ではphase4-clarification.mdの
> 確定回答を優先して採用する。

ファイル内容(プレーンテキスト、UTF-8 BOMなし、ラウンド1 A5=A):
```
1行目: タイトル
2行目: カテゴリ(任意。省略/未認識語の場合は「お知らせ」を既定値とする、下記参照)
3行目以降: 本文(プレーンテキスト、空行で段落区切り。Markdown記法・画像埋め込みは
           非対応、ラウンド2 R23=A・R24=A)
```

**カテゴリ対応(保守5/5 W6=A確定: 記事一覧に将来を見据えたカテゴリ分けを最初から
用意する)の実装方針:** 記事追加時に非エンジニアの運営者がカテゴリ行を毎回正しく
書けるとは限らないため、`NewsLogic::parse_article_file()`は2行目が
`お知らせ`・`イベント`・`メディア掲載`のいずれとも一致しない場合、2行目を本文の
一部とみなし、カテゴリは自動的に`お知らせ`(既定値)とする**寛容なパーサー**にする
(2行目を省略しても記事投稿自体が失敗しないようにする設計。保守5/5 W1=A
「運営者がFTPで直接アップロード」・W3=B「手順書は不要、都度Claude Codeに依頼」の
運用と整合させ、フォーマットミスで記事が非表示になる事故を避ける)。

### 4.2 一覧・詳細生成フロー

- 一覧: `site/news/`をディレクトリ走査(`opendir`/`readdir`、コアPerl)、ファイル名
  (日付プレフィックス)で降順ソートし、**直近10件のみ**表示(ラウンド1 A4=A)。
  ページネーションは実装しない。
- 詳細: `news.cgi?id=<ファイル名(拡張子なし)>`形式で個別記事を表示。`id`パラメータは
  `^\d{4}-\d{2}-\d{2}-[\w\-]+$`の正規表現で検証し、パストラバーサルを防ぐ
  (download.cgiと同様の考え方)。
- 下書き状態は持たない。ファイルをアップロードした時点で即座に一覧・詳細の両方に
  反映される(保守5/5 W4=A)。削除もファイル削除のみで完結する(保守5/5 W2=A)。

### 4.3 テンプレート機構

`site/templates/header.html`・`footer.html`を文字列置換(`s///`または単純な
連結)で挿入する(architecture.md確定方式、CPAN不要)。`NewsLogic::render_list_html()`・
`render_detail_html()`がそれぞれ本文HTML断片を組み立て、`header.html` + 本文 +
`footer.html`を結合して出力する。

---

## 5. QRコード遷移ページ

- 実装: 静的HTML(`qr/book1.html`・`qr/book2.html`)、CGIを介さない
  (ラウンド1 D23=A、ラウンド2 D23=Aで「QRページ自体のアクセスログがなくても
  ダウンロード実行時のログで週次確認の目的は十分満たせる」ことを確認済み)。
- 保護: `qr/.htaccess`でBasic認証(`dl/.htpasswd`参照、0.2節)。`AuthName`は
  `cgi-bin/.htaccess`の`download.cgi`用ブロックと完全一致させる(0.2節)。
- 内容: 書籍名・特典の簡単な説明+ダウンロードリンク
  (`<a href="../cgi-bin/download.cgi?file=book1/xxx.pdf">`形式)。デザインは
  トップページと同じCSSを流用する(ラウンド2 H50=B)。
- QRコード画像自体の生成はClaude Codeが実装時に用意する(ラウンド2 Y28=B)。

---

## 6. `.pm`モジュール分割案とTest::Moreテスト観点

`internal-spec-repo-cicd.md`が確定させた4モジュール構成(`Common.pm`・
`ContactLogic.pm`・`DownloadLogic.pm`・`NewsLogic.pm`、`site/cgi-bin/lib/`配下)を
そのまま採用し、各モジュールの関数レベルの責務を以下のように分割する。すべて
`use v5.16;`を明示し、5.16で確実に動く構文のみを使う(Infra4/5 S3=A)。
コメントは非エンジニアの運営者が将来読んでも分かるレベルで詳しめに書く
(Infra4/5 S6=B)。

### 6.1 `Common.pm`(全CGI共通ユーティリティ)

| 関数 | 役割 |
|---|---|
| `html_escape($str)` | `<`・`>`・`&`・`"`のHTMLエスケープ |
| `strip_newlines($str)` | `\r`・`\n`の除去(メールヘッダインジェクション対策) |
| `resolve_script_dir()` | `File::Basename`+`Cwd::abs_path`でスクリプト自身のディレクトリを絶対パスで取得(相対パス解決の基準にする) |
| `read_secret_file($relative_path)` | `conf/`配下の非公開ファイルを読み込む(HMACシークレット等) |
| `render_template($template_path, \%replacements)` | プレースホルダー文字列を置換してHTML生成(news.cgi・contact.cgiのエラー再描画で共用) |
| `write_log($log_path, @fields)` | タブ区切り1行を`flock`ベストエフォートで追記(2.7節・3.4節で共用) |
| `render_error_page($message)` | 500エラー用の簡易ページ出力(8章) |
| `install_die_handler()` | `$SIG{__DIE__}`を設定し、未捕捉の`die`を`error_log.txt`に記録した上で`render_error_page()`を呼ぶ |

**Test::Moreテスト観点(`t/Common.t`):**
- `html_escape`: `<script>`等の代表的な危険文字列が正しくエスケープされるか。
- `strip_newlines`: `"foo\r\nBcc: evil\@example.com"`のような注入試行文字列から
  改行が除去されるか。
- `render_template`: プレースホルダーが正しく置換され、未置換のプレースホルダーが
  残らないか。エスケープ対象の値がテンプレート挿入時にHTMLエスケープされているか
  (XSS対策の回帰テスト)。
- `write_log`: 一時ディレクトリに対して呼び出し、追記後のファイル内容が期待通りの
  タブ区切り行になっているか(`flock`非対応環境でも例外を投げず動作を継続するか、
  モックで検証)。

### 6.2 `ContactLogic.pm`

| 関数 | 役割 |
|---|---|
| `validate_input(\%params)` | 2.3節のルールに従いエラー配列を返す |
| `verify_token($token, $secret)` | HMACトークン検証(2.5節、integration-spec 1.2節のロジック) |
| `is_duplicate_submission($log_path, $ip, $email, $window_sec)` | 2.4節の重複判定 |
| `is_business_hours(@localtime)` | 平日10:00-17:00判定(テスト容易性のため`localtime`の戻り値を引数として受け取る設計にし、時刻をモック可能にする) |
| `build_notification_mail(\%params)` | 運営者宛メールのヘッダー・本文組み立て(2.6節) |
| `build_autoreply_mail(\%params, $is_business_hours)` | 自動返信メールの組み立て(2.6節) |
| `send_via_sendmail($mail_text)` | list形式`open`での`sendmail`呼び出し |

**Test::Moreテスト観点(`t/ContactLogic.t`):**
- `validate_input`: 必須項目欠如・メール不一致・同意未チェックそれぞれで期待する
  エラーメッセージが返るか。境界値(問い合わせ内容が空文字/1文字)。
- `verify_token`: 正しいトークンで成功、署名不一致・期限切れ(300秒超過)・
  未来方向60秒超過・不正フォーマットのそれぞれでreject理由コードが返るか
  (`internal-spec-integration.md`のサンプルコードをそのまま単体テスト化)。
- `is_duplicate_submission`: 同一IP+同一メールが300秒以内にあれば重複、
  300秒を1秒でも超えると重複でなくなる境界値、IPまたはメールいずれかだけが
  異なる場合は重複としないこと。
- `is_business_hours`: 平日10:00/16:59は営業時間内、17:00/9:59・土日は
  営業時間外、という境界値。
- `build_notification_mail`/`build_autoreply_mail`: 生成されたヘッダーに
  改行が含まれないこと(`strip_newlines`との連携含む)、件名フォーマットが
  「【FroEduXお問い合わせ】(姓名)様より」になっているか、営業時間外の
  追記文言が正しく挿入されるか。
- `send_via_sendmail`: 実際のsendmail呼び出しはモック(パスを差し替え可能な
  設計にし、テスト用のダミー実行可能ファイルを使う)。

### 6.3 `DownloadLogic.pm`

| 関数 | 役割 |
|---|---|
| `resolve_mime_type($filename)` | 3.3節の拡張子対応表 |
| `validate_file_param($file)` | 3.5節の正規表現検証(合格/不合格を返す) |
| `authorize_book_access($remote_user, $book)` | 3.1節の書籍別認可判定 |
| `rotate_log_if_needed($log_path)` | 3.4節の月次ローテーション判定・実行 |
| `format_access_log_line($remote_user, $remote_addr, $file, $result)` | ログ1行分の整形 |

**Test::Moreテスト観点(`t/DownloadLogic.t`):**
- `resolve_mime_type`: 対応表にある7拡張子すべてが正しいMIMEタイプを返すこと、
  未知の拡張子は`application/octet-stream`にフォールバックすること。
- `validate_file_param`: 正常系(`book1/sample.pdf`)は合格、`../../etc/passwd`・
  `book1/../book2/x.pdf`・全角文字を含むファイル名・許可拡張子以外は不合格。
- `authorize_book_access`: book1ユーザーがbook1ファイルにアクセス→許可、
  book1ユーザーがbook2ファイルにアクセス→拒否、未知のユーザー名→拒否。
- `rotate_log_if_needed`: 一時ディレクトリでファイルの最終更新月を人為的に
  過去月に設定し、呼び出し後に`access_log_YYYYMM.txt`へリネームされ新規の
  空ファイルが作られることを確認。同月内での呼び出しではリネームが発生しないこと。

### 6.4 `NewsLogic.pm`

| 関数 | 役割 |
|---|---|
| `list_article_files($dir)` | ディレクトリ走査+ファイル名降順ソート、直近10件に切り詰め |
| `parse_article_file($path)` | タイトル・カテゴリ(寛容パース、4.1節)・本文を抽出 |
| `render_list_html(\@articles)` | 一覧HTML断片生成 |
| `render_detail_html($article)` | 詳細HTML断片生成 |

**Test::Moreテスト観点(`t/NewsLogic.t`):**
- `list_article_files`: 11件のダミーファイルを用意した場合に10件のみ返る
  (直近10件、ラウンド1 A4=A)こと、ソート順が新しい日付が先頭になること。
- `parse_article_file`: カテゴリ行が正しい場合・省略された場合・認識できない
  文字列の場合それぞれで、カテゴリが期待通り(指定値、または既定値「お知らせ」)に
  なること。本文の空行が段落区切りとして扱われること。
- `render_list_html`/`render_detail_html`: タイトル・本文に含まれるHTML特殊文字が
  エスケープされること(XSS対策、`Common::html_escape`との連携)。

### 6.5 テスト実行方法(Infra4/5 S1=A・S7=A)

- ローカル/CI環境(Cyberhome自体ではない、architecture.md「ローカル開発環境は
  構築しない」方針と矛盾しない。テストはPerlが動く任意の環境で完結する)で
  `prove -l site/cgi-bin/lib/t/`を実行する。
- テストファイル(`t/`ディレクトリ)は`site/.ftpdeployignore`
  (`internal-spec-repo-cicd.md`が定義した除外リスト方式)に追加し、Cyberhomeへの
  FTPSデプロイ対象から除外する(50MBのディスク容量制約への配慮、および
  本番環境にテストコードを置く必要がないため)。
- **CI連携の提案(`internal-spec-repo-cicd.md`への追加提案、非破壊的):**
  `internal-spec-repo-cicd.md`が定義した3ワークフロー
  (`deploy-cyberhome.yml`・`playwright-smoke.yml`・`api-tests.yml`)には
  Perlユニットテストの実行ステップが含まれていない。`api-tests.yml`と同型の
  軽量ワークフロー`perl-tests.yml`
  (`on: pull_request/push, paths: ["site/cgi-bin/**"]`、Perlの標準インストール
  (`actions/checkout`+OS標準のPerl、追加インストール不要)で`prove -l
  site/cgi-bin/lib/t/`を実行)を追加することを推奨する。これは既存3ワークフローの
  設計を変更するものではなく、並行して追加できる4本目のワークフローであるため、
  `internal-spec-repo-cicd.md`との非破壊的な整合が取れる(手動テストチェックリストは
  Infra4/5 S7=Aにより本書またはフェーズ8のE2Eテスト仕様側で扱うため、本書では
  「作成すること」とだけ確定させ、内容自体はフェーズ8に委ねる)。
- 手動テストチェックリスト(Infra4/5 S7=A「含める」)は、`contact.cgi`の
  正常系1件・異常系(バリデーションエラー・重複送信・トークン期限切れ)3件、
  `download.cgi`の正常系2件(book1/book2)・異常系(誤ったユーザーでの
  クロスアクセス・不正な`file`パラメータ)2件、`news.cgi`の一覧・詳細各1件、
  QRページのBasic認証プロンプト表示1件、の最低9項目を実機デプロイ後の初回
  動作確認として実施することを推奨する(具体的なテスト手順書自体はフェーズ8
  (E2Eテスト)の担当範囲とする)。

---

## 7. `.htaccess`/`.htpasswd` 最終配置・記述内容

### 7.1 ファイル配置一覧(0章の全体像から抜粋、確定版)

| パス | 内容 |
|---|---|
| `site/cgi-bin/.htaccess` | `<Files "download.cgi">`ブロックでBasic認証(0.1節) |
| `site/cgi-bin/lib/.htaccess` | `Require all denied`(ソースコード直接閲覧防止) |
| `site/conf/.htaccess` | `Require all denied`(HMACシークレットファイル保護) |
| `site/dl/.htaccess` | ディレクトリ自体のBasic認証+`.htpasswd`/`.txt`直接アクセス拒否+`Options -Indexes` |
| `site/dl/.htpasswd` | book1用・book2用ユーザーを含む単一ファイル(Git管理外) |
| `site/qr/.htaccess` | Basic認証(`dl/.htpasswd`を参照、0.2節) |
| `site/Contents/.htaccess` | `Require all denied`(直リンク防止、3.5節) |

### 7.2 `site/cgi-bin/.htaccess`(新設、確定版)

```apache
# download.cgi のみをBasic認証で保護する。contact.cgi/news.cgiは公開のまま。
<Files "download.cgi">
  AuthType Basic
  AuthName "Book Bonus Content"
  AuthUserFile /virtual/xxxxxx/public_html/dl/.htpasswd
  Require valid-user
</Files>

# lib/ 配下のソースを直接URLで取得できないようにする(念のための二重対策、
# lib/.htaccess本体でも Require all denied を設定済み)
<FilesMatch "\.pm$">
  Require all denied
  Order allow,deny
  Deny from all
</FilesMatch>
```

### 7.3 `site/dl/.htaccess`(確定版、architecture.mdの原案をベースに更新)

```apache
AuthType Basic
AuthName "Book Bonus Content"
AuthUserFile /virtual/xxxxxx/public_html/dl/.htpasswd
Require valid-user

<Files ".htpasswd">
  Require all denied
  Order allow,deny
  Deny from all
</Files>

<FilesMatch "\.txt$">
  Require all denied
  Order allow,deny
  Deny from all
</FilesMatch>

Options -Indexes
```
`AuthName`は7.2節の`cgi-bin/.htaccess`・下記7.5節の`qr/.htaccess`と完全一致させる
(0.2節の理由)。`.txt`拒否により`access_log.txt`のHTTP直接取得を防ぐ
(運営者はFTPで取得する運用、architecture.md確定)。`AuthUserFile`の絶対パス
(`/virtual/xxxxxx/...`)はCyberhome実機で要確認(architecture.md「追加質問5」で
既に非ブロッキング事項として記録済み、本書では再質問しない)。

### 7.4 `site/cgi-bin/lib/.htaccess`・`site/conf/.htaccess`(新設、確定版・共通)

```apache
Require all denied
Order allow,deny
Deny from all
```

### 7.5 `site/qr/.htaccess`(確定版)

```apache
AuthType Basic
AuthName "Book Bonus Content"
AuthUserFile /virtual/xxxxxx/public_html/dl/.htpasswd
Require valid-user
```
`dl/.htpasswd`を直接参照する(0.2節、`qr/`独自の`.htpasswd`は持たない)。

### 7.6 `site/Contents/.htaccess`(新設、確定版)

```apache
Require all denied
Order allow,deny
Deny from all
Options -Indexes
```
(`Options -Indexes`はInfra2/5 L4=A確定。`Require all denied`により`Contents/`配下への
すべての直接HTTPアクセスを拒否し、`download.cgi`経由のみを唯一の配信経路にする、
3.5節)。

### 7.7 `.htpasswd`のハッシュ形式・生成・年次更新

architecture.mdの原案(APR1-MD5形式、`htpasswd -c -m`)をそのまま採用する
(Apacheバージョン2.2/2.4いずれでも動作する互換性優先の判断、要実機確認は
architecture.md「追加質問4」として既に記録済み)。

**年次更新時の`.htpasswd`生成コマンド例(運営者のローカルPCで実行、ラウンド1 D22の
「別々のID・パスワード」を反映):**
```
htpasswd -c -m .htpasswd book1user      # 最初のユーザーで新規作成(-c)
htpasswd -m .htpasswd book2user         # 2人目以降は追記(-cなし)
```
生成した1つの`.htpasswd`ファイルをFTPSクライアントで`site/dl/.htpasswd`の1箇所へ
アップロードするだけでよい(`qr/`・`cgi-bin/`は同じファイルを参照するため、
アップロードは1回で済む。保守性重視の要件に合致)。初回発行時のID・パスワードは
Claude Codeが仮の値を生成し、運営者が確認・変更してから使う(ラウンド2 D22=B)。
パスワード強度は8文字以上・英数字混在を推奨するのみで、システム側での強制チェックは
行わない(ラウンド1 D26=B)。

書籍が増えた場合の対応: `DownloadLogic.pm`の`%BOOK_USERS`マッピング更新と
`.htpasswd`への新規ユーザー追加をセットでClaude Codeに依頼する運用とする
(保守5/5 Y12=A)。

---

## 8. エラーハンドリング全体方針(500エラー)

`internal-spec-repo-cicd.md`の想定する「ローカル開発環境を持たず本番へ直接デプロイして
検証する」運用(architecture.md決定事項9)では、想定外の500エラーがそのまま利用者に
見える事態を避けることが特に重要になる(ラウンド2 E36=B確定: 各CGIでエラーを捕捉し、
サイトデザインに沿った簡易エラーページを表示する)。

### 8.1 実装方針

- 3つのCGI(`contact.cgi`・`download.cgi`・`news.cgi`)はいずれも`use strict;
  use warnings;`を必須にする(Infra2/5 L3=A)。
- 各CGIの`main`処理全体を`eval { ... }`で包み、`$@`が真であれば
  `Common::render_error_page()`を呼ぶ。
- 加えて`Common::install_die_handler()`で`$SIG{__DIE__}`を設定し、`.pm`モジュール
  内部からの予期しない`die`(例: ファイルオープン失敗)も同じ経路で捕捉する
  (`eval`との二重の備え。`$SIG{__DIE__}`は`eval`内で発生した`die`にも呼ばれるため、
  実質的には`$SIG{__DIE__}`ハンドラ内でログ記録、`eval`側で最終的なページ出力、
  という役割分担にする)。
- **利用者への表示:** サイトデザイン(`templates/header.html`・`footer.html`)を
  再利用した簡易エラーページ。「システムエラーが発生しました。時間をおいて
  再度お試しいただくか、時間をおいても解決しない場合はお手数ですが
  お問い合わせフォームよりご連絡ください」。スタックトレース・Perlのエラー
  メッセージ原文はユーザーには一切表示しない(情報漏えい防止)。
- **記録:** `site/cgi-bin/error_log.txt`(3CGI共通)に、タイムスタンプ・
  発生元CGI名・`die`メッセージ全文を追記する(こちらは運営者向けの調査用途のため
  詳細を残す)。この不具合ログは週次のアクセスログ確認と合わせて目視確認する
  対象に含める(既存の週次確認運用を流用、追加の運用ルールを増やさない)。
- HTTPステータスコードは`Status: 500 Internal Server Error`ヘッダーを明示的に
  CGI側から出力する(Apacheのデフォルトエラーページに委ねない)。

---

## 9. 環境変数・秘密情報(Cyberhome側、本ドキュメントに関わるもののみ)

`internal-spec-integration.md` 7章・`internal-spec-repo-cicd.md` 7.4節と重複しない
範囲で、Cyberhome側CGIが直接参照する設定値をまとめる。

| 項目 | 保持場所 | 用途 |
|---|---|---|
| `conf/hmac_secret.txt` | `site/conf/`(Git管理外、`.example`のみコミット) | reCAPTCHA検証トークンのHMAC共有シークレット(`internal-spec-integration.md`と同一値) |
| `dl/.htpasswd` | `site/dl/`(Git管理外、`.htpasswd.example`のみコミット) | ダウンロード・QRページ共通のBasic認証パスワードファイル(7.7節) |
| 運営者宛メールアドレス | `ContactLogic.pm`内に定数として直接記述(`mainagak@gmail.com`、暫定値) | 通知メールの送信先・自動返信の送信元 |
| CORS許可オリジン相当 | `contact.cgi`のReferer検証条件(2.9節)に直接記述(`https://jyoho1.web.cyberhome.ne.jp`) | CSRF対策 |
| `%BOOK_USERS`マッピング | `DownloadLogic.pm`内にハードコード(7.7節) | 書籍別ダウンロード認可 |

Cyberhome側にはVercelのような環境変数機能がないため、これらは「非公開ファイル
(`.gitignore`対象)」または「`.pm`ファイル内の定数」として管理する
(architecture.md「秘密情報管理の決定」と整合。定数はコード自体であり秘密情報
ではないため`.pm`への直書きで問題ない。メールアドレス・CORS許可オリジンは
非秘密情報)。

---

## 10. デプロイ・保守運用への反映事項(参照用まとめ)

- `internal-spec-repo-cicd.md`の`deploy-cyberhome.yml`は`site/**`の変更をトリガーに
  FTPSアップロードする設計であり、本書で新設した`cgi-bin/.htaccess`・
  `cgi-bin/lib/.htaccess`・`conf/.htaccess`・`Contents/.htaccess`もこの対象に
  自然に含まれる(パス構成の変更ではなくファイル追加のため、ワークフロー自体の
  変更は不要)。
- `.gitattributes`(`internal-spec-repo-cicd.md` 2章)により`*.cgi`・`*.pl`・`*.pm`・
  `.htaccess`はLF改行が既に強制されているため、本書のCGI/モジュール設計は
  この前提にそのまま乗る(追加対応不要)。
- テストディレクトリ(`site/cgi-bin/lib/t/`)は`.ftpdeployignore`
  (`internal-spec-repo-cicd.md`が定義した除外リスト方式)へ追加する必要がある
  (6.5節)。
- CGIファイルの実行権限(+x)については11章「追加質問」を参照。

---

## 11. 追加質問

以下1件は、既存の280問の回答からもWave1文書からも判断できない、genuinely
未決定な事項。Cyberhomeの実機仕様に依存し、GitHub Actionsの自動デプロイ設計
(`deploy-cyberhome.yml`)に影響するため確認したい(非ブロッキング — 初回デプロイ時に
実機確認する前提でA案を仮の既定として進めても内部仕様のレビュー自体は妨げない)。

**Q1. GitHub Actions(FTPS)経由でアップロードした`.cgi`ファイルの実行権限(+x)について**

Cyberhomeの公開スペック情報には、FTPSアップロード後に`.cgi`ファイルが自動的に
実行可能になるか(レンタルサーバーによっては`.cgi`拡張子のファイルを自動的に
実行可能とみなす、または初回アップロード時のみ手動でパーミッション設定が必要、
などの違いがある)についての記載がない。FTP標準にはパーミッション変更コマンド
(SITE CHMOD)がサーバー実装依存で存在するかどうかも不明。

- A) Cyberhomeでは`.cgi`拡張子のファイルは自動的に実行可能として扱われるという
  一般的な低価格レンタルサーバーの慣習を前提に進め、`deploy-cyberhome.yml`側に
  chmod処理は組み込まない(初回GitHub Actions実行時に実機で疎通確認し、
  動かなければB案に切り替える)。
- B) 安全策として、初回のみ運営者が手動でFTPSクライアント(パーミッション変更
  機能を持つもの、例: FFFTP/WinSCP)から`.cgi`ファイルのパーミッションを755に
  設定する手順を運用手順書(`docs/`配下)に明記し、以降の自動デプロイでは
  上書きアップロードのみ行う(通常のFTP `STOR`はファイルの既存パーミッションを
  変更しないため、初回設定が保持される前提)。
- C) `deploy-cyberhome.yml`で使用するFTP-Deploy系GitHub Actionが対応していれば
  SITE CHMODコマンドを自動送信する設定を組み込む(対応していない場合はB案へ
  フォールバック)。フェーズ6実装時に採用するActionのドキュメントを確認して
  判断する。

上記以外に、本書のスコープ(contact.cgi/download.cgi/news.cgi詳細設計、QRページ、
`.pm`モジュール分割、`.htaccess`/`.htpasswd`確定版、エラーハンドリング方針)において
ブロッキングな未決定事項はない。0章で整理した2件の食い違い(`download.cgi`の
Basic認証の掛かり方、書籍別パスワードと単一CGIスクリプトの両立)は、いずれも
既存の確定回答から合理的に導出できる範囲で本書が解決案を確定させた。

# 内部仕様(フェーズ4 Wave3): テスト・デプロイ検証設計

## 位置づけ

本ドキュメントは、フェーズ4(内部仕様調査)を6分割したサブエージェントのうち最後の
Wave3「テスト・デプロイ検証設計」担当分の成果物である。Wave1(3エージェント:
`internal-spec-integration.md`・`internal-spec-repo-cicd.md`・`internal-spec-datamodel.md`)
およびWave2(2エージェント: `internal-spec-cyberhome.md`・`internal-spec-vercel.md`)の
成果物をすべて前提とし、それらの契約・ディレクトリ構成・CI/CD骨格・テストケース設計を
**変更せず**、その内側で「デプロイパイプライン全体の実行順序」「Playwrightスモーク
テストの具体シナリオ」「Perlユニットテストのファイル構成とCI組み込み」「pytestの
CI実行タイミング」「バックアップ・ロールバックの実行可能な手順」を確定する。

参照元(すべて確定済み、編集していない):
- `docs/specs/external-spec.md`(承認済み)
- `docs/specs/architecture.md`(ドラフト確定)
- `docs/specs/phase4-clarification.md`(全280問回答済み。以下、ラウンド名+節記号+問番号で
  引用する。例: 「ラウンド1 G45」「Infra2/5 L4」「Infra3/5 Q18」「保守5/5 Z22」)
- `docs/specs/internal-spec-integration.md`(Cyberhome⇔Vercel連携契約。`/health`契約・
  CORS・FAQ API契約はそのまま採用)
- `docs/specs/internal-spec-repo-cicd.md`(ディレクトリ構成、3ワークフロー骨格
  `deploy-cyberhome.yml`/`playwright-smoke.yml`/`api-tests.yml`、バックアップ・
  ロールバック方針の原案)
- `docs/specs/internal-spec-datamodel.md`(参照のみ、DB設計は対象外)
- `docs/specs/internal-spec-cyberhome.md`(実際の`.cgi`/`.pm`ファイル一覧、
  `.htaccess`配置、`.pm`モジュールのTest::Moreテスト観点、`perl-tests.yml`の提案)
- `docs/specs/internal-spec-vercel.md`(pytestテストケース一覧、`api-tests.yml`との
  整合方針)
- `docs/PROJECT_STATUS.md`

対象外(他エージェントの担当、変更しない):
- Cyberhome側CGI・`.pm`モジュールの実装詳細そのもの(`internal-spec-cyberhome.md`)
- Vercel/FastAPIのルーティング・モデル定義そのもの(`internal-spec-vercel.md`)
- Neon DBスキーマ(`internal-spec-datamodel.md`)
- ディレクトリ構成・`vercel.json`・`.gitattributes`(`internal-spec-repo-cicd.md`)

---

## 0. 本書の立場: Wave1/Wave2の骨格を実行可能なレベルまで肉付けする

`internal-spec-repo-cicd.md` 3章は3ワークフローの**骨格**(トリガー・ジョブ名・大まかな
ステップ)を定義済みであり、`internal-spec-cyberhome.md` 6.5節は`perl-tests.yml`の
**追加提案**(非破壊的)を行い、`internal-spec-vercel.md` 6章は`pytest`の**テストケース
一覧**を確定済みである。本書はこれらを次の3点で「実装者(フェーズ6)がそのままコードに
落とせる」レベルまで具体化する。

1. `deploy-cyberhome.yml`のジョブ順序・各ステップで実際に何を対象にするか
   (Wave2が確定させた実ファイル一覧に基づく)。
2. Playwrightスモークテストの具体的なテストシナリオ(URL・期待値レベル)。
3. `perl-tests.yml`を非破壊的追加として確定し、`api-tests.yml`との整合・CI全体の
   実行順序を1枚の表に整理する。

Wave1/Wave2文書の記載と矛盾する変更は行わない。本書内で新たに確定する事項は、
既存の280問の確定回答から合理的に導出できるもの、または`internal-spec-integration.md`
自身が「頻度はCI/CD設計側で確定」のように本書へ明示的に委譲している事項に限る
(該当箇所は各節で明記する)。

---

## 1. `deploy-cyberhome.yml` 詳細ジョブ設計

### 1.1 トリガー(`internal-spec-repo-cicd.md` 3.1節を確定のまま採用)

```yaml
on:
  push:
    branches: [main]
    paths: ["site/**"]
  workflow_dispatch: {}
```

### 1.2 ジョブ1: `backup`

**目的:** デプロイ前に、Cyberhome本番`/public_html`の**現状全体**(Git管理下のファイルに
限らない)をアーティファクトとして保全する。

**バックアップ方式の確定(`internal-spec-repo-cicd.md`「追加質問Q1」の解決):**
`internal-spec-repo-cicd.md`はFTPSミラーダウンロード方式(案A)とGitベース方式(案B)を
両論併記していたが、本書で**案A(FTPSミラーダウンロード)に確定する**。理由:
`/public_html`配下には`.htpasswd`・`conf/hmac_secret.txt`・`contact_log.txt`・
`access_log.txt`など**Git管理外(`.gitignore`対象)のファイルが多数存在し**
(`internal-spec-cyberhome.md` 1章・7章)、これらはロールバック時にも復元できる必要が
ある。Gitベース方式(案B)ではこれらのファイルがそもそもバックアップ対象に含まれず、
ロールバックの実効性が損なわれる。したがって「テスト・デプロイ検証設計」の観点から、
バックアップの完全性を優先し案Aを正式決定とする。初回のGitHub Actions実行時に
CyberhomeのFTPSサーバーがディレクトリ一覧取得(LIST/MLSD)に対応しているかを実機で
確認し、対応していないことが判明した場合のみ、フォールバックとして「バックアップの
対象をGit管理下の`site/**`のみに限定し、`.htpasswd`等はバックアップ対象外である旨を
`docs/PROJECT_STATUS.md`に明記した上で運用を継続する」(縮小版の案A、案Bへの全面
移行ではなく部分的縮退)を採る。

**ステップ:**

```yaml
backup:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Install lftp
      run: sudo apt-get update && sudo apt-get install -y lftp
    - name: Mirror-download current /public_html via FTPS
      env:
        FTP_HOST: ${{ secrets.CYBERHOME_FTP_HOST }}
        FTP_USER: ${{ secrets.CYBERHOME_FTP_USER }}
        FTP_PASS: ${{ secrets.CYBERHOME_FTP_PASSWORD }}
      run: |
        mkdir -p backup_public_html
        lftp -u "$FTP_USER,$FTP_PASS" -e "
          set ftp:ssl-force true;
          set ftp:ssl-protect-data true;
          mirror --parallel=2 /public_html ./backup_public_html;
          bye" "$FTP_HOST"
    - name: Archive backup
      run: |
        STAMP=$(date -u +%Y%m%d%H%M%S)
        echo "BACKUP_NAME=cyberhome-backup-${STAMP}-${{ github.run_number }}" >> "$GITHUB_ENV"
        tar -czf "cyberhome-backup-${STAMP}-${{ github.run_number }}.tar.gz" backup_public_html
    - uses: actions/upload-artifact@v4
      with:
        name: ${{ env.BACKUP_NAME }}
        path: cyberhome-backup-*.tar.gz
        retention-days: 90
```

- 保持世代: 直近5世代を目安に運営者が手動確認・削除(ラウンド2 E32=B、E33=A)。
  GitHub既定の90日保持はそのまま利用し、自動プルーニングは実装しない。
- このジョブは`site/**`への通常pushでも`workflow_dispatch`でも**常に実行**し、
  スキップ不可とする(`internal-spec-repo-cicd.md` 5.1節の方針を維持)。

### 1.3 ジョブ2: `deploy`(`needs: backup`)

**デプロイ対象の具体列挙(`internal-spec-cyberhome.md` 1章の確定ディレクトリ構成に基づく):**

| カテゴリ | 対象パス | 件数(MVP時点の見込み) |
|---|---|---|
| 静的ページ | `site/index.html`, `news.html`, `contact.html`, `contact-thanks.html`, `privacy.html` | 5 |
| CSS/JS | `site/css/*.css`, `site/js/{main,utils,chat-widget,contact-form}.js` | 可変 |
| 記事データ | `site/news/*.txt` | 可変(0件から開始) |
| テンプレート断片 | `site/templates/{header,footer}.html` | 2 |
| CGI本体 | `site/cgi-bin/{news,contact,download}.cgi` | 3 |
| CGIロジックモジュール | `site/cgi-bin/lib/{Common,ContactLogic,DownloadLogic,NewsLogic}.pm` | 4 |
| `.htaccess`群 | `cgi-bin/.htaccess`, `cgi-bin/lib/.htaccess`, `conf/.htaccess`, `dl/.htaccess`, `qr/.htaccess`, `Contents/.htaccess` | 6 |
| 非公開設定(ダミー値のみ) | `conf/hmac_secret.example.txt`, `dl/.htpasswd.example` | 2 |
| QRページ | `qr/book1.html`, `qr/book2.html` | 2 |
| SEO関連 | `robots.txt`, `sitemap.xml` | 2 |

**デプロイ対象から除外するもの(`site/.ftpdeployignore`、ラウンド1 G42=A):**

```
cgi-bin/lib/t/
```

`internal-spec-cyberhome.md` 6.5節で確定した通り、Perlユニットテスト
(`site/cgi-bin/lib/t/*.t`)は本番Cyberhomeへ配置する必要がなく(50MB容量制約・
本番環境にテストコードを置く必要がないため)、FTPSデプロイの対象から明示的に除外する。

**ステップ:**

```yaml
deploy:
  needs: backup
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - name: Deploy to Cyberhome via FTPS
      uses: SamKirkland/FTP-Deploy-Action@v4.3.5
      with:
        server: ${{ secrets.CYBERHOME_FTP_HOST }}
        username: ${{ secrets.CYBERHOME_FTP_USER }}
        password: ${{ secrets.CYBERHOME_FTP_PASSWORD }}
        protocol: ftps
        port: ${{ secrets.CYBERHOME_FTP_PORT }}
        local-dir: site/
        server-dir: ${{ secrets.CYBERHOME_PUBLIC_HTML_PATH }}
        exclude: |
          **/.ftpdeployignore
          cgi-bin/lib/t/**
    - name: Summary
      run: |
        echo "### Cyberhome deploy" >> "$GITHUB_STEP_SUMMARY"
        echo "- Commit: ${{ github.sha }}" >> "$GITHUB_STEP_SUMMARY"
        echo "- Deployed at: $(date -u +%FT%TZ)" >> "$GITHUB_STEP_SUMMARY"
```

- `.gitattributes`(`internal-spec-repo-cicd.md` 2章)によりリポジトリ内の`*.cgi`・
  `*.pl`・`*.pm`・`.htaccess`は既にLF改行が強制されているため、`deploy`ジョブ側での
  追加の改行変換は不要(ラウンド4 T9=A・T10=B)。
- `.cgi`ファイルの実行権限(+x)がFTPSアップロード後に自動的に有効になるかは実機未確認
  (`internal-spec-cyberhome.md`「追加質問Q1」)。本書のスコープではこの点を再質問せず、
  同ドキュメントの案A(自動的に実行可能という前提で進め、初回実行時に疎通確認)を前提に
  デプロイジョブを設計する。もし初回デプロイでCGIが500/403等で動作しない場合、次節の
  `smoke-test`ジョブが必ず検知できる設計にしてあるため(2章参照)、実機差異があっても
  「気づけない」事態は起きない。

### 1.4 ジョブ3: `smoke-test`(`needs: deploy`)

```yaml
smoke-test:
  needs: deploy
  uses: ./.github/workflows/playwright-smoke.yml
  with:
    triggered_by: "deploy-cyberhome"
  secrets: inherit
```

`playwright-smoke.yml`を再利用可能ワークフロー(`workflow_call`)として呼び出す
(`internal-spec-repo-cicd.md` 3.1節の方針通り)。具体的なテストシナリオは2章。
失敗時はこのジョブ自体が失敗し、`deploy-cyberhome.yml`全体も失敗扱いになる
(ラウンド1 G45=A)。

### 1.5 ジョブ4: `notify-on-failure`(`if: failure()`)

```yaml
notify-on-failure:
  needs: [backup, deploy, smoke-test]
  if: failure()
  runs-on: ubuntu-latest
  permissions:
    issues: write
  steps:
    - uses: actions/github-script@v7
      with:
        script: |
          const failedJob = ${{ toJSON(needs) }};
          const label = "deploy-failure";
          const title = `Cyberhome deploy failed (run #${context.runNumber})`;
          const { data: existing } = await github.rest.issues.listForRepo({
            owner: context.repo.owner, repo: context.repo.repo,
            state: "open", labels: label,
          });
          const body = [
            "## デプロイ失敗通知(自動生成)",
            "",
            `- 対象コミット: ${context.sha}`,
            `- ワークフロー実行: ${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`,
            `- 失敗ジョブ状況: backup=${failedJob.backup.result}, deploy=${failedJob.deploy.result}, smoke-test=${failedJob['smoke-test'].result}`,
            "",
            "### 推奨対応",
            "1. 上記ワークフロー実行のログを確認する",
            "2. smoke-test が失敗した場合、本番サイト(https://jyoho1.web.cyberhome.ne.jp/)を目視確認する",
            "3. 必要であれば直近のバックアップアーティファクトからロールバックする(docs/specs/internal-spec-repo-cicd.md 5.2節・本書5章)",
            "4. 原因を修正後、再度 push または workflow_dispatch で再実行する",
          ].join("\n");
          if (existing.length > 0) {
            await github.rest.issues.createComment({
              owner: context.repo.owner, repo: context.repo.repo,
              issue_number: existing[0].number, body,
            });
          } else {
            await github.rest.issues.create({
              owner: context.repo.owner, repo: context.repo.repo,
              title, body, labels: [label], assignees: ["mainagak"],
            });
          }
```

- `peter-evans/create-issue-from-file`等の専用Actionではなく`actions/github-script`を
  採用する(Wave2/Wave1いずれの決定にも縛られない実装選択のため裁量で決定)。理由:
  失敗ジョブの状態を動的に取得しIssue本文に埋め込む必要があるため、テンプレートファイル
  方式より柔軟。
- **重複Issue防止(本書の追加設計):** 同一ラベル(`deploy-failure`)のオープンIssueが
  既に存在する場合は新規Issue作成ではなくコメント追記に切り替える。連日デプロイに
  失敗し続けた場合にIssueが乱立することを防ぐための、保守性重視要件に基づく裁量判断。
- GitHubのIssue通知メール機能により、追加のメール送信実装は不要(ラウンド2 E31=B)。

---

## 2. Playwrightスモークテスト シナリオ一覧

`internal-spec-repo-cicd.md` 3.2節が定義した`playwright-smoke.yml`のトリガー
(`schedule`(毎日1回)+`workflow_call`+`workflow_dispatch`)をそのまま採用し、
具体的なテストシナリオを以下に確定する。**破壊的な検証は行わない**
(`architecture.md`確定方針)ことを全シナリオ共通の制約とする。

### 2.1 公開サイト用スイート(`tests/e2e/public/*.spec.ts`、MVPスコープ)

| # | シナリオ | 検証方法 | 期待結果 |
|---|---|---|---|
| 1 | トップページ表示 | `page.goto(SITE_BASE_URL)` | HTTP 200、Hero/About/Services/Contact/Chatbotウィジェット/Footerの各セクション見出しが表示されること |
| 2 | 記事一覧表示 | `news.cgi`(または`news.html`経由)へ遷移 | HTTP 200、サーバーエラー文言が出力されないこと。記事0件でも一覧ページ自体は正常表示されること(初期状態を許容) |
| 3 | 問い合わせフォームページ表示 | `page.goto(SITE_BASE_URL + "contact.html")` | HTTP 200、reCAPTCHA v2ウィジェット(`.g-recaptcha`相当の要素/iframe)が描画されること、プライバシー同意チェックボックスが**未チェック**であること(ラウンド2 R30=A) |
| 4 | 問い合わせフォーム**正常系**送信確認(2026-08-02、B′案で確定) | ブラウザから`POST /api/verify-recaptcha`を`X-Smoke-Test-Auth: <SMOKE_TEST_SECRET>`ヘッダー付きで呼び出し(ダミーの`recaptcha_response`でよい、9章参照)、取得した`verify_token`を使い実際に`contact.html`のフォームを介して`contact.cgi`へPOSTする(テスト専用の氏名・メールアドレスを使用) | `POST /api/verify-recaptcha`が200+`verified:true`を返すこと。`contact.cgi`が302で`contact-thanks.html`へリダイレクトすること。**実際に運営者宛通知メール・自動返信メールが送信され、`contact_log.txt`に受付記録が追記される(意図的な許容、2.5節参照)** |
| 4b | 問い合わせフォームのバリデーションエラー経路確認 | `request.post()`でAPIレベルから`contact.cgi`へ、意図的にメールアドレス(確認用)を不一致にしたパラメータ一式を直接POST(reCAPTCHA・`verify_token`は付与しない) | HTTP 200が返り、`contact.html`の骨格に「メールアドレスが一致しません」等のエラーが再描画されること。実際のメール送信・`contact_log.txt`への正常受付記録は発生しない |
| 5 | FAQ/チャットウィジェット表示 | ウィジェットを開く操作 | `GET /api/faq`が200で応答すること。FAQ 0件時は「まだFAQがありません。お問い合わせフォームをご利用ください」+導線ボタンが表示されること(ラウンド1 A1=A)。1件以上ある場合はカテゴリごとに項目が表示されること |
| 6 | プライバシーポリシーページ表示 | `page.goto(SITE_BASE_URL + "privacy.html")` | HTTP 200 |
| 7 | QRコード遷移ページのBasic認証プロンプト確認(book1) | `request.get(SITE_BASE_URL + "qr/book1.html")`(認証情報なし、APIレベルで検証しブラウザの認証ダイアログを介さない) | HTTP **401**、`WWW-Authenticate: Basic`ヘッダーが含まれること |
| 8 | QRコード遷移ページのBasic認証プロンプト確認(book2) | 同上、`qr/book2.html` | HTTP 401 |
| 9 | ダウンロードCGIのBasic認証プロンプト確認 | `request.get(SITE_BASE_URL + "cgi-bin/download.cgi?file=book1/dummy.pdf")`(認証情報なし) | HTTP 401(実ファイルの有無に関わらずApache Basic認証がCGI起動前に発生するため、ダミーファイル名で検証可能。`internal-spec-cyberhome.md` 3.2節ステップ1) |
| 10 | Vercel FAQ API直接疎通 | `request.get(VERCEL_API_BASE_URL + "/api/faq")` | HTTP 200、`Cache-Control: no-store`ヘッダー、レスポンスボディが`{"faqs": [...], "updated_at": ...}`形状であること |

### 2.2 Vercel `/health` 定期ping(`playwright-smoke.yml`内、日次実行のみ)

`internal-spec-integration.md` 4章は「呼び出し元: GitHub Actions(定期実行ワークフロー、
頻度はWave2のVercel側エージェントまたはCI/CD設計側で確定)」と明記しており、
`internal-spec-vercel.md`も「頻度は`internal-spec-repo-cicd.md`のCI/CD設計側の管轄」と
本書へ委譲している。したがって本書で以下を確定する。

**決定: `playwright-smoke.yml`に軽量な`health-ping`ジョブを追加し、2.1節の公開サイト
スイートとは独立に実行する。** 新規ワークフローファイルを追加しない(保守性重視、
ワークフロー数を増やさない)。

```yaml
health-ping:
  runs-on: ubuntu-latest
  steps:
    - name: Ping /health
      run: |
        curl -f -sS "${{ vars.VERCEL_API_BASE_URL }}/health" \
          | tee /dev/stderr | grep -q '"status":"ok"' \
          || (echo "::error::Vercel /health check failed" && exit 1)
```

- 実行頻度: `playwright-smoke.yml`の`schedule`トリガー(毎日1回、後述2.4節)に相乗り。
  独立した専用ワークフローは作らない。
- 失敗時の扱い: `smoke`ジョブと同様にワークフロー失敗として扱い、1.5節と同型の
  Issue自動作成ロジックを`playwright-smoke.yml`自身にも実装する(下記2.5節)。

### 2.3 GUI用スイート(将来、**フェーズ10スコープ**、MVPには含めない)

`phase4-clarification.md` Infra3/5 Q18(確定回答A)により、GUI用のE2Eテストは公開
サイト向けスイートとは**別スイート**にすることが確定している。`internal-spec-vercel.md`
7.5節も同方針。本書ではファイル配置・実行方針のみを先出しで記録し、実装はFAQ管理
Web GUI着手時(保守サイクル最初のタスク)に行う。

- テストファイル: `tests/e2e/gui/*.spec.ts`(公開サイトスイートとディレクトリを分離)。
- 想定シナリオ(概要、詳細はフェーズ10着手時に設計):
  - ログイン画面表示・正常ログイン・異常ログイン(規定回数失敗後のロックアウト確認)
  - FAQ一覧表示(要認証)・新規作成→保存(下書き)→公開→公開サイト側`GET /api/faq`への
    反映確認
  - アカウント追加(O節Q3=A)
  - CSRFトークン不正時のPOST拒否確認
  - IP制限が有効な環境での拒否確認(検証可能な範囲に限定)
- テスト用アカウント: 専用のNeon DBブランチに固定のテストアカウントを用意する
  (Infra3/5 Q19=A)。
- 新規ワークフローファイル`playwright-gui-smoke.yml`をフェーズ10着手時に追加する
  (MVPリリース時点では作成しない)。
- 保守作業でのテスト実行確認は、Claude CodeがGitHub Actions経由で自動実行結果を
  確認する主体となる(保守5/5 Z22=A)。

### 2.4 実行タイミングまとめ

| トリガー | 対象スイート | ワークフロー |
|---|---|---|
| Cyberhomeへのデプロイ完了直後 | 2.1公開サイトスイート(2.2 health-pingは含まない) | `deploy-cyberhome.yml`から`workflow_call` |
| 毎日1回(`cron: "0 0 * * *"`、UTC0:00=JST9:00) | 2.1公開サイトスイート + 2.2 health-ping | `playwright-smoke.yml`(`schedule`) |
| `api/**`変更のmainマージ後(3章末尾で後述) | 2.1公開サイトスイートの一部(FAQ/health関連) + 2.2 health-ping | `playwright-smoke.yml`(新設`push`トリガー) |
| 手動 | 運営者・Claude Codeが選択したスイート | `playwright-smoke.yml`(`workflow_dispatch`) |
| GUI関連(フェーズ10以降) | 2.3 GUIスイート | `playwright-gui-smoke.yml`(未実装) |

### 2.5 疎通確認の設計方針(2.1節#4・#4bの根拠、および失敗時Issue化)

**2026-08-02確定(B′案):** ユーザーの判断により、正常系送信(実メール送信・
`contact_log.txt`への受付記録)まで毎日自動で検証する方針を採用した。運営者宛
メールボックスに日次テストメールが届くこと、`contact_log.txt`に日次テスト行が
追記され続けることは**意図的に許容する**。テスト専用の送信者情報(氏名・
メールアドレス)を使うことで、テストによる受信メール・ログ行を実際の顧客からの
問い合わせと目視で区別できるようにする(例: 氏名「スモークテスト」、メールアドレス
`smoke-test@jyoho1.web.cyberhome.ne.jp`のような実在しないダミードメイン)。

reCAPTCHA自体は自動操作できないため、`internal-spec-vercel.md` 9章で確定した
「Vercel側`/api/verify-recaptcha`のみに追加するCI専用分岐(`X-Smoke-Test-Auth`
ヘッダー+Google公式テストシークレットキー)」を利用する。**`contact.cgi`は一切
変更しない**(通常の送信と全く同じHMACトークン検証ロジックを通る)。

これとは別に、reCAPTCHA/HMACトークンを一切介さない**バリデーションエラー経路**
(2.1節#4b)も維持し、`contact.cgi`の入力検証・エラー再描画ロジック単体の疎通確認を
行う(正常系テストが将来何らかの理由で無効化された場合の保険としても機能する)。

`playwright-smoke.yml`自身の失敗時Issue自動作成は、1.5節と同型のロジックを
`playwright-smoke.yml`の末尾ジョブとして実装する(タイトルのみ
`"Playwright smoke test failed (run #<run_number>, triggered by <inputs.triggered_by>)"`
に差し替え、同じ`deploy-failure`ラベルを使い回すか判断に迷う場合は`smoke-test-failure`
という別ラベルを使う。**本書では別ラベル`smoke-test-failure`を採用する**。デプロイ
起因の失敗(FTPSアップロード自体の失敗)と、デプロイ後の疎通異常(コード品質・
実機差異起因)は原因調査の初動が異なるため、ラベルを分けて検索性を上げる)。

---

## 3. Perl `Test::More` テストファイル構成とCI組み込み

`internal-spec-cyberhome.md` 6章が確定した4モジュール・テスト観点を、具体的な
テストファイル名・テストケース数に落とし込む(実装者が「このファイルに何個のテストを
書けばよいか」を迷わない粒度)。

### 3.1 テストファイル・テストケース数一覧

| テストファイル | 対象モジュール | テストケース数(目安) | 内訳 |
|---|---|---|---|
| `site/cgi-bin/lib/t/Common.t` | `Common.pm` | 14 | `html_escape` 4、`strip_newlines` 2、`render_template` 2、`write_log` 2、`resolve_script_dir` 1、`read_secret_file` 2、`render_error_page`/`install_die_handler` 1 |
| `site/cgi-bin/lib/t/ContactLogic.t` | `ContactLogic.pm` | 27 | `validate_input` 7、`verify_token` 5、`is_duplicate_submission` 4、`is_business_hours` 5、`build_notification_mail`/`build_autoreply_mail` 4、`send_via_sendmail` 2 |
| `site/cgi-bin/lib/t/DownloadLogic.t` | `DownloadLogic.pm` | 19 | `resolve_mime_type` 8、`validate_file_param` 5、`authorize_book_access` 3、`rotate_log_if_needed` 2、`format_access_log_line` 1 |
| `site/cgi-bin/lib/t/NewsLogic.t` | `NewsLogic.pm` | 7 | `list_article_files` 2、`parse_article_file` 3、`render_list_html`/`render_detail_html` 2 |
| **合計** | 4モジュール | **約67** | — |

各テストケースの具体的な検証内容は`internal-spec-cyberhome.md` 6.1〜6.4節の
「Test::Moreテスト観点」に既に列挙されている。本書はその観点をファイル・件数レベルに
数え上げたものであり、内容そのものの再設計は行わない。

**命名・記述規則(Infra4/5 S3=A・S4=A・S6=Bを踏まえた確定):**
- 各`.t`ファイル冒頭で`use strict; use warnings; use v5.16;`を明示する。
- `use Test::More;`はコア同梱のためCPAN追加インストール不要(実装・CI環境いずれでも
  動作する)。
- テストケースの説明文(`ok($result, '説明')`の第2引数)は日本語で、非エンジニアの
  運営者が将来ログを読んでも意図が分かるレベルで具体的に書く(Infra4/5 S6=B)。

### 3.2 `perl-tests.yml` 確定設計

`internal-spec-cyberhome.md` 6.5節が提案した「既存3ワークフローを変更しない非破壊的な
追加」案を、本書(CI/CD設計担当)として**検証の上、そのまま確定採用する**。

```yaml
name: perl-tests
on:
  pull_request:
    paths: ["site/cgi-bin/**"]
  push:
    branches: [main]
    paths: ["site/cgi-bin/**"]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Show Perl version (informational)
        run: perl -v
      - name: Run Test::More suite
        run: prove -l site/cgi-bin/lib/t/
```

**設計判断:**
- **Perlのセットアップ:** GitHub Actions `ubuntu-latest`ランナーに標準搭載された
  Perl(執筆時点で概ね5.34以降)をそのまま使う。`Test::More`・`Digest::SHA`・
  `Fcntl`・`File::Basename`はいずれもコアモジュールでありCPANインストール不要
  (`internal-spec-cyberhome.md`が前提とする「CPAN不可」制約はCyberhome本番環境の
  制約であり、CI環境には課されない。そのためCI側で追加のPerlバージョン管理アクション
  (`shogo82148/actions-setup-perl`等)を導入する必要はない)。
- **CI環境と本番Perl 5.16との差異(既知の限界、明記しておく):** CIランナーの
  Perlはバージョンが本番Cyberhome(Perl 5.16系)より新しい。`use v5.16;`を明示して
  いても、CI側で「新しいPerlでは動くが5.16では動かない構文」を書いてしまった場合、
  CI上のテストは通過するのに本番デプロイ後に動かない、という事態を完全には防げない。
  この既知の限界を埋めるのが2章のPlaywrightスモークテスト(デプロイ後の実機検証)
  であり、`perl-tests.yml`単体を「本番動作の保証」と誤解しないことを実装者への
  注意事項として明記する。
- **ブランチ保護の必須ステータスチェックには含めない。** `internal-spec-repo-cicd.md`
  6.2節が`api-tests / test`を必須チェックから除外した理由(`/site`のみ・`/api`のみの
  変更PRでは該当ジョブが起動せず、GitHub上「必須チェックが永遠に現れず保留になる」
  問題が生じる)と同じ理由により、`perl-tests / test`も必須ステータスチェックには
  含めない。品質担保はレビュー+デプロイ後Playwrightスモークテストで代替する
  (既存方針と一貫性を保つ、本書の裁量による確定)。
- **テストレポートの保存:** MVPでは`prove`の標準出力のみで十分とし、TAPレポートの
  アーティファクト化は行わない(カバレッジ閾値も設けない、`api-tests.yml`と同水準の
  軽量運用に揃える)。

### 3.3 手動テストチェックリストとの関係

`internal-spec-cyberhome.md` 6.5節がPerlユニットテストと対で提示した「手動テスト
チェックリスト」(`contact.cgi`正常系1件・異常系3件、`download.cgi`正常系2件・
異常系2件、`news.cgi`一覧・詳細各1件、QRページのBasic認証プロンプト表示1件、
最低9項目)は、初回デプロイ後の実機動作確認として位置づけられている
(Infra4/5 S7=A)。これは本書2.1節のPlaywright自動スモークテスト(#1〜#10)と
重なる部分が多いが、**自動化できない/しない部分**(実際のID・パスワードでの
ログイン成功確認、実際のファイルダウンロードの中身確認等)は引き続き手動確認が
必要であり、具体的な手順書自体はフェーズ8(E2Eテスト)の担当範囲とする
(`internal-spec-cyberhome.md`の既存方針を変更しない)。

---

## 4. Python `pytest` のCI実行タイミング

`internal-spec-vercel.md` 6章が確定したテストケース一覧(`test_faq.py`12件、
`test_recaptcha.py`14件、`test_health.py`3件、計29件)を前提に、CI全体における
実行タイミングを整理する。

### 4.1 `api-tests.yml`(`internal-spec-repo-cicd.md` 3.3節、変更なし)

```yaml
on:
  pull_request:
    paths: ["api/**"]
  push:
    branches: [main]
    paths: ["api/**"]
```

- ステップ順序: `ruff check api/` → `pytest api/tests`
  (`internal-spec-vercel.md` 6.6節と整合)。
- ブランチ保護の必須チェックには含めない(`internal-spec-repo-cicd.md` 6.2節、既存決定)。

### 4.2 Vercel自体のデプロイとの関係(既存決定の再確認)

Vercelの GitHub連携によるデプロイ(Preview: PR時、Production: mainへのpush時)は
`api-tests.yml`の成否と**完全に独立**して動作する(Vercel自体のCI/CDはActions外)。
したがって理論上、「pytestが失敗しているコードがVercel本番へ自動デプロイされる」
ことを`api-tests.yml`単体では防げない。この既存のギャップ(`internal-spec-repo-cicd.md`
3.3節が既に明記済み)に対し、PRベース運用(レビュー時にCI結果を人間が確認してから
マージする)が実質的な防波堤になる、という既存方針をそのまま踏襲する。

### 4.3 本書での追加: `api/**`変更後のPlaywright公開サイトスイート実行(新設トリガー)

**課題:** `api/**`のみが変更されmainへマージされた場合、`deploy-cyberhome.yml`
(`site/**`のみをトリガーとする)は起動しないため、`workflow_call`経由の
Playwrightスモークテストも実行されない。結果として、Vercel本番へ新しいAPIが
デプロイされてから次にPlaywrightで疎通確認されるまで、**最大24時間(次の日次cron
実行まで)の空白**が生じうる。

**決定(本書の裁量、既存ワークフローへの非破壊的な追加):** `playwright-smoke.yml`に
`api/**`変更のmain push時トリガーを追加する。

```yaml
on:
  schedule:
    - cron: "0 0 * * *"
  workflow_call:
    inputs:
      triggered_by:
        type: string
        required: false
  workflow_dispatch: {}
  push:
    branches: [main]
    paths: ["api/**"]
```

- Vercelの自動デプロイ完了とGitHub Actionsのジョブ起動は非同期のため、即座に
  スモークテストを実行するとVercel側のデプロイ未完了を誤って「異常」と判定する
  リスクがある。これを避けるため、`push`トリガー時のみ本番稼働確認を待つ
  ポーリングステップを`smoke`ジョブの先頭に追加する:

```yaml
- name: Wait for Vercel deploy to become healthy (push-triggered only)
  if: github.event_name == 'push'
  run: |
    for i in $(seq 1 12); do
      if curl -fsS "${{ vars.VERCEL_API_BASE_URL }}/health" | grep -q '"status":"ok"'; then
        exit 0
      fi
      sleep 5
    done
    echo "::error::Vercel /health did not become healthy within 60s after api/** push"
    exit 1
```

- `api/**`変更トリガー時は2.1節の全10シナリオではなく、Vercel APIに関係する部分
  (#5 FAQウィジェット、#10 FAQ API直接疎通、および2.2節のhealth-ping)のみを
  実行すれば十分だが、実装簡潔性を優先し**同一の`smoke`ジョブをそのまま使い回す**
  (Cyberhome側のシナリオも一緒に流れるが、これらは通常失敗しないはずであり、
  実行時間の増加(数十秒程度)は許容範囲と判断する)。

これにより、CI/CD全体は「`/site`変更→Cyberhomeデプロイ経由でのみスモークテスト」
「`/api`変更→独立してスモークテスト」の両方をカバーする。

---

## 5. バックアップ・ロールバック詳細フロー

`internal-spec-repo-cicd.md` 5章の方針を、1.2節で確定したFTPSミラー方式を前提に
実行可能なレベルまで具体化する。

### 5.1 バックアップ(自動・デプロイ前必須、確定)

| 項目 | 内容 |
|---|---|
| 主体 | GitHub Actions(`deploy-cyberhome.yml`の`backup`ジョブ)。人手不要 |
| タイミング | `site/**`へのpush、または手動`workflow_dispatch`のいずれでも`deploy`ジョブ直前に必ず実行 |
| 対象 | `/public_html`全体(FTPSミラー、Git管理外ファイルを含む。1.2節で確定) |
| 保存先 | GitHub Actionsアーティファクト、`cyberhome-backup-<UTCタイムスタンプ>-<run_number>` |
| 保持 | GitHub既定90日。直近5世代を目安に運営者が「Artifacts」画面で手動確認・削除(ラウンド2 E32=B) |

### 5.2 ロールバック(手動判断・実行、具体手順)

**トリガー条件:** `smoke-test`ジョブ失敗によるIssue自動作成(1.5節)を見た運営者
(またはClaude Code代行)が、内容確認の上でロールバックを判断する。**自動ロールバックは
実装しない**(ラウンド1 G45=Aの「通知して運営者判断を仰ぐ」方針)。

**手順:**

1. 失敗したワークフロー実行(またはその直前の正常だった実行)の`backup`ジョブから
   対象アーティファクト(`cyberhome-backup-*.tar.gz`)を特定しダウンロードする。
2. ローカルで展開する(`tar -xzf cyberhome-backup-*.tar.gz`)。
3. FTPSクライアント(FFFTP・WinSCP等、運営者が通常使うツール)で
   `backup_public_html/`配下の内容を`/public_html`へ**ミラーアップロード**する。
   単純な上書きアップロードではなく、**バックアップ時点に存在しなかった不要な
   ファイル(問題のあるデプロイで追加された誤ファイル等)も削除する「ミラー
   (差分反映+削除)」アップロード**を推奨する(片方向の上書きのみだと、誤って
   追加されたファイルが残存する可能性があるため)。
4. **既知のトレードオフ(明記):** バックアップ取得時刻から実際のロールバック実行
   時刻までの間に本番環境で新規に書き込まれたログ(`contact_log.txt`・
   `access_log.txt`等)は、ミラー式ロールバックにより失われる可能性がある。
   この間隔は通常「デプロイ直後の障害検知〜運営者対応」までの短時間
   (数分〜数時間)であり、月10件規模の低頻度アクセスを踏まえるとログ欠落の
   実害は小さいと判断する(許容するリスクとして明記するのみで、追加の対策は
   MVPでは実装しない)。
5. ロールバック完了後、`playwright-smoke.yml`を`workflow_dispatch`で手動実行し、
   本番が正常に戻ったことを確認する。
6. ロールバック実施日時・理由・使用したアーティファクト名を
   `docs/PROJECT_STATUS.md`に記録する(既存の保守運用記録方針、ラウンド5 Z20=A)。

自動化されたワンクリック・ロールバック用ワークフローはMVPでは実装しない
(`internal-spec-repo-cicd.md`5.2節の既存決定を維持)。

### 5.3 Vercel側のロールバック(変更なし)

Vercel標準機能(ダッシュボードから過去デプロイメントへの「Promote to Production」)を
利用する。本書もCyberhome側のみを設計対象とする(`internal-spec-repo-cicd.md`5.3節を
維持)。

---

## 6. CI/CD全体のテスト実行順序

以下は実装者が「いつ・何が・どういう条件で動くか」を一目で把握するための一覧表である。
なお実際のトリガーはパスフィルタにより非同期・並行に発火するため、「Perl単体テスト→
Python単体テスト→デプロイ→E2Eスモークテスト」という順序は**単一ワークフロー内の
直列実行ではなく、リリース作業全体を俯瞰したときの論理的な検証順序**として理解する
こと(実装上は下表の各行が独立してトリガーされる)。

| # | タイミング/トリガー | 実行されるワークフロー | 実行される検証 | ゲート性 |
|---|---|---|---|---|
| 1 | PR作成・更新(`site/cgi-bin/**`変更あり) | `perl-tests.yml` | Test::More 約67ケース(3.1節) | 参考(必須チェックではない、レビューで確認) |
| 2 | PR作成・更新(`api/**`変更あり) | `api-tests.yml` | `ruff check` + pytest 29ケース | 参考(同上) |
| 3 | PR作成・更新(`api/**`変更あり) | Vercel Preview Deploy(GitHub連携、Actions外) | プレビューURL自動生成、Neonプレビューブランチ自動作成 | 参考 |
| 4 | PRをsquash mergeしてmainへpush(`site/**`変更あり) | `deploy-cyberhome.yml` | `backup`→FTPSデプロイ→`smoke-test`(2.1節#1〜10)→(失敗時)Issue自動作成 | **必須**(smoke-test失敗=ワークフロー失敗、ラウンド1 G45=A) |
| 5 | 同上、mainへpush(`api/**`変更あり) | `api-tests.yml`(push再実行)+ Vercel本番自動デプロイ(Actions外)+ `playwright-smoke.yml`(4.3節の新設`push`トリガー) | pytest再実行 + `/health`安定待ち後に公開サイトスイート+health-ping | 参考+間接的な検知(失敗でIssue化) |
| 6 | 毎日1回(`cron: 0 0 * * *`、JST9:00) | `playwright-smoke.yml`(`schedule`) | 2.1公開サイトスイート全10項目 + 2.2 health-ping | **必須**(失敗=ワークフロー失敗、`smoke-test-failure`ラベルでIssue化) |
| 7 | 手動(`workflow_dispatch`) | `deploy-cyberhome.yml` | 任意タイミングでの再デプロイ(backup→deploy→smoke) | 運営者/Claude Code判断 |
| 8 | 手動(`workflow_dispatch`) | `playwright-smoke.yml` | スモークテストのみ単独実行 | 運営者/Claude Code判断 |
| 9 | フェーズ10以降 | `playwright-gui-smoke.yml`(未実装) | 2.3 GUIスイート | 未定(フェーズ10で設計) |

**論理的な検証順序(リリース作業を俯瞰した場合の推奨フロー、実装者向け補足):**

```
[コード変更] → featureブランチ作成 → PR作成
   → (1)(2)(3) が並行実行(参考情報として確認)
   → レビュー・CI結果確認 → squash merge
   → main push
   → (4) site/** 変更あり: backup → FTPSデプロイ → E2Eスモーク → OK/NG通知
      (5) api/** 変更あり: pytest再実行 → Vercel自動デプロイ → health安定待ち → E2Eスモーク(一部) → OK/NG通知
   → 毎日 (6) 定期スモークテストで回帰検知
```

---

## 7. 環境変数・GitHub Secrets/Variables(本書で新規に必要となる分のみ)

`internal-spec-integration.md` 7章・`internal-spec-repo-cicd.md` 7章・
`internal-spec-vercel.md` 8章に記載済みの変数は再掲しない。本書のワークフロー設計で
新たに必要になるものだけを示す。

| 名前 | 種別 | 用途 | 保持場所 |
|---|---|---|---|
| `VERCEL_API_BASE_URL` | GitHub Actions Variable | `/health`・`/api/faq`への疎通確認先(例: `https://<project>.vercel.app`) | リポジトリ Variables |
| `SITE_BASE_URL` | GitHub Actions Variable(`internal-spec-repo-cicd.md` 7.2節で既出、再掲のみ) | 公開サイトスモークテスト対象URL | リポジトリ Variables |
| `SMOKE_TEST_SECRET`(2026-08-02追加) | GitHub Actions Secret | `playwright-smoke.yml`が2.1節#4で`X-Smoke-Test-Auth`ヘッダーに設定する値。Vercel側`SMOKE_TEST_SECRET`環境変数と同一値(`internal-spec-vercel.md` 9.2節) | リポジトリ Secrets |

`GITHUB_TOKEN`(Actions既定、追加設定不要)に`issues: write`権限を`notify-on-failure`
ジョブへ付与する(1.5節のYAML例に明記済み)。新規のGitHub Secretsは不要
(Issue作成は既定トークンで完結するため)。

---

## 8. 手動テストチェックリストとの関係(フェーズ8への引き継ぎ)

3.3節の通り、自動化されたPlaywrightスモークテスト(2.1節)とPerl/pytestユニット
テスト(3章・4章)は「コードが壊れていないこと」「主要エンドポイントが疎通する
こと」を検証するが、以下は引き続き**人手による初回実機確認**(フェーズ8スコープ)に
委ねる:

- 実際のID・パスワードを用いたBasic認証成功確認(自動テストは401応答の確認までに
  意図的に留めている、認証情報をCIに保持しないため)。
- ダウンロードしたファイルの中身が正しいこと。
- 自動返信メール・運営者宛通知メールが実際に受信できること(2.5節の設計判断により
  自動スモークテストでは正常系送信を行わないため)。
- `.htpasswd`年次更新後の疎通確認(`internal-spec-integration.md` 1.5節手順5)。

これらの項目は`internal-spec-cyberhome.md` 6.5節が提示した最低9項目のチェックリストと
重複するため、本書では独自のチェックリストを新設せず、同ドキュメントの記載を正とする
(フェーズ8で手順書として肉付けする)。

---

## 追加質問

なし。**旧Q1(問い合わせフォーム自動疎通確認の範囲)は2026-08-02にユーザーが
選択肢B′(Vercel側のみの小さなCI判別分岐でGoogle公式テストシークレットキーに
切り替え、`contact.cgi`は無変更のまま正常系送信も日次自動化)で確定した。**
2章(2.1節#4・#4b、2.5節)、7章(GitHub Secrets一覧)に反映済み。実装詳細は
`internal-spec-vercel.md` 9章を参照。

本書のスコープ(デプロイジョブ順序、Playwrightシナリオ、Perl/pytestのCI組み込み、
バックアップ・ロールバック、CI/CD全体の実行順序)においてブロッキングな未決定事項は
ない。

---

## トレーサビリティ(参照した確定回答一覧)

| 本書の決定 | 根拠 |
|---|---|
| バックアップ方式をFTPSミラーに確定(`internal-spec-repo-cicd.md`Q1の解決) | `internal-spec-cyberhome.md` 1章・7章(Git管理外ファイルの存在) |
| バックアップ保持世代 | ラウンド2 E32(B)・E33(A) |
| デプロイトリガー(push+手動) | ラウンド2 G43(C) |
| Playwrightスモークテスト実行タイミング(デプロイ後+日次+手動) | ラウンド1 G34(C)、ラウンド2 E33(A) |
| スモークテスト失敗=ワークフロー失敗 | ラウンド1 G45(A) |
| デプロイ失敗時はGitHub Issue自動作成 | ラウンド2 E31(B) |
| `.ftpdeployignore`によるテストコード除外 | `internal-spec-cyberhome.md` 6.5節 |
| `perl-tests.yml`非破壊的追加の確定採用 | `internal-spec-cyberhome.md` 6.5節、本書で検証・確定 |
| ブランチ保護の必須チェックに含めない(Perl/Python共通方針) | `internal-spec-repo-cicd.md` 6.2節と一貫性を保つ本書の裁量判断 |
| `/health`定期pingの頻度・実装先を本書で確定 | `internal-spec-integration.md` 4章、`internal-spec-vercel.md` 4章(いずれも本書へ委譲) |
| GUI用E2Eスイートを別スイート・フェーズ10スコープに | Infra3/5 Q18(A)、`internal-spec-vercel.md` 7.5節 |
| GUIテストアカウントは専用DBブランチ | Infra3/5 Q19(A) |
| 保守作業でのテスト実行確認の主体はClaude Code | 保守5/5 Z22(A) |
| 破壊的な検証を行わない(スモークテスト全般の原則) | `architecture.md`「開発・テスト・監視の決定」節 |
| Pythonバージョンを明示固定しない | ラウンド4 U46(A) |

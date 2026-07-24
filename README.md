# FroEduX 公式サイト

高校「情報Ⅰ」・ITパスポート学習者向け教材開発企業「FroEduX」のシングルページサイトです。
川崎フロンターレカラー（サックスブルー / フロンターレブラック / ホワイト）を採用し、Vite + Vanilla JSで構築しています。

## ディレクトリ構成

```
homepage/
├── index.html
├── src/
│   ├── css/
│   │   ├── reset.css   # リセットスタイル
│   │   └── style.css   # デザインシステム・レイアウト・アニメーション
│   ├── js/
│   │   ├── main.js     # 初期化・スクロール制御・IntersectionObserver
│   │   └── slider.js   # フルスクリーンスライダー（Ken Burns風）
│   └── assets/         # ロゴ・写真等の差し替え用フォルダ（現在は空）
├── package.json
└── .gitignore
```

## セットアップ

```bash
npm install
```

## 開発サーバー起動

```bash
npm run dev
```

## 本番ビルド

```bash
npm run build
```

`dist/` に静的ファイル一式が出力されます。

## さくらのレンタルサーバー（CyberHome管理画面）への公開手順

- 公開URL: https://jyoho1.web.cyberhome.ne.jp/
- サイト管理URL: https://www.cyberhome.ne.jp/app/sslLogin.do
  （ID・パスワードは別途管理・提供予定）

1. `npm run build` を実行し `dist/` フォルダを生成する
2. `dist/` フォルダの中身一式を、FTP/FTPSクライアント（FileZilla等）で
   公開ディレクトリ（通常 `/www` または `public_html` 配下）にアップロードする
3. `index.html` がドキュメントルート直下に配置されていることを確認する
4. ブラウザで公開URLにアクセスし、表示・画像読み込み・アニメーションを確認する

## 現状の仮素材について

- キービジュアル（スライダー）画像: Unsplashのフリー素材URLを仮利用しています（`src/js/slider.js` の `SLIDE_IMAGES`）
- 代表メッセージ欄の写真: プレースホルダー表示です
- ロゴ: 現状テキストロゴ（Alex Brush フォント）です

正式な写真・ロゴ素材が揃い次第、`src/assets/` に格納し、該当箇所を差し替えてください。

## 未確定・要確認事項

- 会社の正式メールアドレス（現状 `info@froedux.example.com` を仮設定、`index.html` のヘッダー「お問い合わせ」ボタン）
- 電話番号下2桁（ヒアリングシート上 `080-4356-38XX` のまま。フッターの`tel:`リンクは末尾を`00`で仮設定）

## アクセス解析（Google Analytics）

サイト訪問者数を計測するため、`index.html` の `<head>` 先頭にGoogle Analytics 4（gtag.js）のトラッキングコードを実装済みです。
測定ID `G-EG1WMDPTV0` を設定済みです。

### 計測できること（初期設定のままで十分カバー）

- サイト全体の訪問者数・ページビュー数（リアルタイム/日次/週次）
- 流入経路（検索・SNS・直接アクセスなど）
- 訪問者の地域・デバイス（PC/スマホ）の内訳

「開業前で、まずサイトの存在が認知されているかを知りたい」という目的であれば、上記の初期設定のみで十分です。追加のイベント計測（ボタンクリック数など）が必要になった場合は別途ご相談ください。

### 注意事項

- 測定IDを反映し、サイトが実際に公開（cyberhomeへデプロイ）された後でないとデータは計測されません（ローカル開発環境`npm run dev`でのアクセスはカウントされません）
- 高校生も閲覧対象のサイトのため、Cookie使用に関する簡単なプライバシーポリシー表記を、サイト公開までにフッター等へ用意することをおすすめします

## SEO実装状況

| 項目 | 状態 | 備考 |
| :--- | :--- | :--- |
| title / meta description | 実装済み | `index.html` |
| canonical / OGP / Twitter Card | 実装済み | `https://jyoho1.web.cyberhome.ne.jp/` を設定済み |
| 構造化データ（JSON-LD） | 実装済み | EducationalOrganization, WebSite |
| 見出し階層（h1→h2→h3） | 修正済み | 1ページにh1は1つのみ |
| sitemap.xml / robots.txt | 実装済み | `public/` 配下、buildでdist直下に出力 |
| favicon / OGP画像 | 未実装 | 正式ロゴ確定後に対応 |
| FAQPage構造化データ | 未実装 | FAQコンテンツ追加後に対応（ロードマップDay8参照） |
| Google Analytics 4 | 実装済み | 測定ID `G-EG1WMDPTV0` を設定済み |

詳細な公開スケジュールは別途「SEO展開ロードマップ（半月プラン）」を参照してください。

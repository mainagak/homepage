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

サイト管理URL: https://www.cyberhome.ne.jp/app/sslLogin.do
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

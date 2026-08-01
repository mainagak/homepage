# ホームページ基盤構築 & フロントエンド実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ローカル開発環境を構築し、GitHub Pages と Vercel で動作するレスポンシブホームページを実装する

**Architecture:** 
- 静的フロントエンド（HTML/CSS/JS）を src/ に配置
- GitHub Actions で自動ビルド・デプロイ
- Vercel へ自動同期で、両環境で同じコンテンツを提供
- OneDrive 共用フォルダで複数PC対応可能な構成

**Tech Stack:** 
- Node.js 18+ (ビルド・開発用)、Python 3.9+ (バックエンド準備用)
- HTML5/CSS3、Vanilla JavaScript
- Vercel (デプロイ)、GitHub Pages (デプロイ)、GitHub Actions (CI/CD)

## Global Constraints

- メインリポジトリ: https://github.com/mainagak/homepage
- ローカル作業ディレクトリ: `C:\Users\maina\OneDrive\ドキュメント\claude-ina\homepage`
- OneDrive 共用パス: `C:\Users\maina\OneDrive\ドキュメント\claude-ina\` (複数PCでアクセス可能)
- メールアドレス: mainagak@gmail.com
- Node.js バージョン: 18.x 以上
- Python バージョン: 3.9 以上
- Git: 最新バージョン

---

## Task 1: ローカル環境セットアップ（Node.js + Python + Git）

- [ ] Step 1: Node.js 確認
- [ ] Step 2: Python 確認
- [ ] Step 3: Git 確認
- [ ] Step 4: setup.ps1 作成
- [ ] Step 5: package.json 初期化
- [ ] Step 6: .gitignore 作成
- [ ] Step 7: npm install
- [ ] Step 8: setup.ps1 実行
- [ ] Step 9: コミット

## Task 2: プロジェクト構造と HTML/CSS/JS フレームワーク

- [ ] Step 1: src ディレクトリ作成
- [ ] Step 2: index.html 作成
- [ ] Step 3: style.css 作成
- [ ] Step 4: responsive.css 作成
- [ ] Step 5: utils.js 作成
- [ ] Step 6: main.js 作成
- [ ] Step 7: dev-server.js 作成
- [ ] Step 8: package.json スクリプト更新
- [ ] Step 9: 開発サーバーテスト
- [ ] Step 10: コミット

## Task 3: GitHub Pages デプロイメント設定

- [ ] Step 1: deploy.yml 作成
- [ ] Step 2: vercel.json 作成
- [ ] Step 3: GitHub Pages 設定確認
- [ ] Step 4: Vercel プロジェクト連携
- [ ] Step 5: コミットプッシュ
- [ ] Step 6: デプロイ確認
- [ ] Step 7: README.md 更新
- [ ] Step 8: 最終コミット

## Task 4: OneDrive 複数PC対応

- [ ] Step 1: OneDrive パス確認
- [ ] Step 2: Git リモート確認
- [ ] Step 3: SETUP_MULTIPC.md 作成
- [ ] Step 4: .onedrive-sync マーカー作成
- [ ] Step 5: README 更新
- [ ] Step 6: コミット
- [ ] Step 7: OneDrive 同期確認

## Task 5: 環境統合テストと動作確認

- [ ] Step 1: ローカル開発環境テスト
- [ ] Step 2: GitHub Pages 確認
- [ ] Step 3: Vercel 確認
- [ ] Step 4: Git 状態確認
- [ ] Step 5: Git ログ確認
- [ ] Step 6: npm スクリプト確認
- [ ] Step 7: OneDrive 同期テスト
- [ ] Step 8: チェックリスト確認
- [ ] Step 9: PROJECT_STATUS.md 作成
- [ ] Step 10: 最終コミット

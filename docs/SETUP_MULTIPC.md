# マルチPC セットアップガイド

このプロジェクトは OneDrive を使用して複数PCで共有できます。

## 前提条件

- Windows 環境
- OneDrive インストール済み
- GitHub アカウント
- Node.js 18+ インストール済み
- Python 3.9+ インストール済み
- Git インストール済み

## セットアップ手順（別PC）

### 1. OneDrive フォルダ同期確認

OneDrive デスクトップアプリが起動して、以下パスが同期されていることを確認：
```
C:\Users\<ユーザー名>\OneDrive\ドキュメント\claude-ina\
```

### 2. リポジトリクローン（初回のみ）

PC1 からリポジトリをクローン：
```powershell
cd "C:\Users\<ユーザー名>\OneDrive\ドキュメント\claude-ina"
git clone https://github.com/mainagak/homepage.git
cd homepage
```

### 3. 環境構築

```powershell
# 依存パッケージをインストール
npm install

# 開発サーバー起動テスト
npm run dev
```

### 4. Git ユーザー設定（初回のみ）

```powershell
git config user.name "Your Name"
git config user.email "your-email@example.com"
```

## 複数PC での作業フロー

### PC1 で編集した場合

```powershell
cd homepage

# 最新の変更をプル
git pull origin main

# 作業してコミット
git add .
git commit -m "feat: your feature"

# プッシュ
git push origin main

# OneDrive が自動同期
# → PC2 で次のプルで最新状態
```

### PC2 で編集する場合

```powershell
cd homepage

# 最新の変更をプル
git pull origin main

# 作業してコミット
git add .
git commit -m "feat: another feature"

# プッシュ
git push origin main
```

## トラブルシューティング

### OneDrive が同期していない

1. OneDrive デスクトップアプリを開く
2. 「詳細」→「一時停止（2時間）」を選択
3. 「詳細」→「同期を再開」

### Git コンフリクトが発生

```powershell
# 最新の変更をプル（コンフリクト発生）
git pull origin main

# コンフリクト部分を手動編集
# エディタで競合マーカー（<<<< , >>>> ）を削除

# 解決後、コミット
git add .
git commit -m "resolve: merge conflict"
git push origin main
```

### npm install エラー

```powershell
# node_modules クリア
rm -r node_modules
rm package-lock.json

# 再インストール
npm install
```

## ベストプラクティス

- **頻繁にプル** - 開始前に必ず `git pull`
- **小さなコミット** - 機能ごとに分けてコミット
- **コミットメッセージ** - 日本語でOK
- **ブランチ作成** - 大きな変更は topic branch で

```powershell
# Topic branch 作成例
git checkout -b feature/chatbot
# 作業...
git commit -m "feat: add chatbot basic structure"
git push -u origin feature/chatbot

# GitHub で PR 作成
# Merge 後、ローカルで削除
git checkout main
git branch -d feature/chatbot
```

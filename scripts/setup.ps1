# scripts/setup.ps1
# ホームページ開発環境セットアップスクリプト

Write-Host "======================================"
Write-Host "Homepage Development Environment Setup"
Write-Host "======================================"

# Node.js 版確認
Write-Host "`n1. Checking Node.js..."
if (node --version) {
    Write-Host "✓ Node.js: $(node --version)"
} else {
    Write-Host "✗ Node.js not found. Please install from https://nodejs.org/"
    exit 1
}

# Python 版確認
Write-Host "`n2. Checking Python..."
if (python --version) {
    Write-Host "✓ Python: $(python --version)"
} else {
    Write-Host "✗ Python not found. Please install from https://www.python.org/downloads/"
    exit 1
}

# Git 版確認
Write-Host "`n3. Checking Git..."
if (git --version) {
    Write-Host "✓ Git: $(git --version)"
} else {
    Write-Host "✗ Git not found. Please install from https://git-scm.com/"
    exit 1
}

# npm 依存パッケージをインストール
Write-Host "`n4. Installing npm dependencies..."
npm install

Write-Host "`n======================================"
Write-Host "Setup Complete!"
Write-Host "======================================"
Write-Host "`nNext steps:"
Write-Host "- npm run dev       (開発サーバー起動)"
Write-Host "- npm run build     (本番ビルド)"
Write-Host "- npm run test      (テスト実行)"

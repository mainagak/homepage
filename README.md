# Homepage

A responsive homepage with contact form and chatbot integration.

## Features

- ✓ Responsive design (mobile, tablet, desktop)
- ✓ Contact form with email integration
- ✓ AI-powered chatbot
- ✓ Multi-environment deployment (GitHub Pages + Vercel)
- ✓ CI/CD automation with GitHub Actions

## Environments

| Environment | URL | Status |
|-------------|-----|--------|
| GitHub Pages | https://mainagak.github.io/homepage/ | ✓ Live |
| Vercel | [Vercel URL] | ✓ Live |

## Quick Start

### Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

Open http://localhost:3000 in your browser.

### Testing

```bash
# Run tests (when implemented)
npm run test

# Lint code (when implemented)
npm run lint
```

### Deployment

Automatic deployment on `main` branch push:
- GitHub Pages (primary)
- Vercel (staging/test)

## Project Structure

```
src/
├── index.html          # Main homepage
├── forms.html          # Contact form (Plan 2)
├── chat.html           # Chatbot UI (Plan 3)
├── css/                # Stylesheets
│   ├── style.css
│   └── responsive.css
├── js/                 # JavaScript
│   ├── main.js
│   └── utils.js
└── assets/             # Images and icons
```

## Development Tools

- Node.js 18+
- Python 3.9+ (for backend in Plan 2)
- Playwright (for testing in Plan 4)
- pytest (for unit tests in Plan 4)

## Multi-PC Setup

This repository is managed in a shared OneDrive folder for multi-PC access.

```bash
# Clone on a new PC
cd "C:\Users\<username>\OneDrive\ドキュメント\claude-ina"
git clone https://github.com/mainagak/homepage.git
cd homepage

# Install and start
npm install
npm run dev
```

See [docs/SETUP_MULTIPC.md](docs/SETUP_MULTIPC.md) for detailed multi-PC setup instructions.

## Next Steps

- [Plan 2: Webフォーム & バックエンド](docs/superpowers/plans/...)
- [Plan 3: チャットボット機能](docs/superpowers/plans/...)
- [Plan 4: テスト & CI/CD](docs/superpowers/plans/...)
- [Plan 5: 環境統合 & OneDrive共用](docs/superpowers/plans/...)

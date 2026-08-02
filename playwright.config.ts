import { defineConfig } from '@playwright/test';

// Config for the public-site Playwright smoke-test suite.
// Design source: docs/specs/internal-spec-testing.md 2章 (シナリオ一覧・実行タイミング).
// Consumed by .github/workflows/playwright-smoke.yml (`npx playwright test tests/e2e/public`)
// and .github/workflows/deploy-cyberhome.yml (via workflow_call).
//
// SITE_BASE_URL / VERCEL_API_BASE_URL / SMOKE_TEST_SECRET are injected by the CI
// workflows from GitHub Actions Variables/Secrets (internal-spec-testing.md 7章).
// The localhost fallback below only exists so `npx playwright test --list` and
// local ad-hoc runs don't crash when the env vars are unset; there is no live
// Cyberhome/Vercel deployment in this environment yet (see docs/PROJECT_STATUS.md).
export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30_000,
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [['html', { open: 'never' }], ['list']],
  use: {
    baseURL: process.env.SITE_BASE_URL || 'http://localhost:8080/',
    trace: 'retain-on-failure',
  },
  projects: [{ name: 'chromium', use: { browserName: 'chromium' } }],
});

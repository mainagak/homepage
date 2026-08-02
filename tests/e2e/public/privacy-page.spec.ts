import { expect, test } from '@playwright/test';

// Scenario #6 (docs/specs/internal-spec-testing.md 2.1節): プライバシーポリシーページ表示
test('privacy policy page returns HTTP 200', async ({ page }) => {
  const response = await page.goto('/privacy.html');
  expect(response?.status()).toBe(200);
});

import { expect, test } from '@playwright/test';

// Scenario #1 (docs/specs/internal-spec-testing.md 2.1節):
// トップページ表示 — HTTP 200 and each major section heading + the
// FAQ/chat widget toggle (site/js/chat-widget.js) render.
test('top page renders all main sections and mounts the FAQ widget', async ({ page }) => {
  const response = await page.goto('/');
  expect(response?.status()).toBe(200);

  await expect(page.locator('#home h2')).toHaveText('電子書籍でお仕事に役立つ知識を');
  await expect(page.locator('#about h2')).toHaveText('会社概要');
  await expect(page.locator('#services h2')).toHaveText('サービス');
  await expect(page.locator('#contact h2')).toHaveText('お問い合わせ');
  await expect(page.locator('#chatbot h2')).toHaveText('よくある質問(FAQ)');
  await expect(page.locator('footer.footer')).toContainText('FroEduX');

  // external-spec.md「全ページ共通のフローティングウィジェット」要件。
  // chat-widget.js injects this button at runtime (it is not in the static HTML).
  await expect(page.locator('#faq-widget-toggle')).toBeVisible();
});

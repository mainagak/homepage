import { expect, test } from '@playwright/test';

// Scenario #2 (docs/specs/internal-spec-testing.md 2.1節):
// 記事一覧表示 — news.cgi must render normally even with 0 articles
// (initial MVP state), and must never surface the die-handler's error copy
// (site/cgi-bin/lib/Common.pm install_die_handler / render_error_page).
test('news list page (news.cgi) renders without a server error', async ({ page }) => {
  const response = await page.goto('/cgi-bin/news.cgi');
  expect(response?.status()).toBe(200);

  // NewsLogic::render_list_html always emits this wrapper, even for 0 articles.
  await expect(page.locator('.news-list')).toBeAttached();
  await expect(page.locator('body')).not.toContainText('システムエラーが発生しました');
});

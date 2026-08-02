import { expect, test } from '@playwright/test';

// Scenario #5 (docs/specs/internal-spec-testing.md 2.1節):
// FAQ/チャットウィジェット表示 — opening the widget must call GET /api/faq and
// show the confirmed empty-state copy while the MVP FAQ dataset has 0 entries
// (external-spec.md確定事項, api/app/data/faq.json). If a real FAQ entry is ever
// published this assertion needs revisiting (see the "1件以上ある場合" row in
// the 2.1節 scenario table) — that is expected, not a bug in this test.
test('opening the FAQ widget calls GET /api/faq and shows the empty-state message', async ({
  page,
}) => {
  const faqResponsePromise = page.waitForResponse((res) => res.url().includes('/api/faq'));
  await page.goto('/');
  await page.click('#faq-widget-toggle');

  const faqResponse = await faqResponsePromise;
  expect(faqResponse.status()).toBe(200);

  await expect(page.locator('#faq-widget-body')).toContainText(
    'まだFAQがありません。お問い合わせフォームをご利用ください。'
  );
});

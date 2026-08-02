import { expect, test } from '@playwright/test';

// Scenario #3 (docs/specs/internal-spec-testing.md 2.1節):
// 問い合わせフォームページ表示 — HTTP 200, the reCAPTCHA v2 widget renders,
// and the privacy-agreement checkbox starts unchecked (ラウンド2 R30=A).
test('contact page renders the form with an unchecked privacy checkbox and a disabled submit button', async ({
  page,
}) => {
  const response = await page.goto('/contact.html');
  expect(response?.status()).toBe(200);

  await expect(page.locator('.g-recaptcha')).toBeVisible();
  await expect(page.locator('#privacy_agree')).not.toBeChecked();

  // contact-form.js only enables this once /api/verify-recaptcha has returned a
  // verify_token (internal-spec-integration.md 1.4節); on first load it must be
  // disabled.
  await expect(page.locator('#contact-submit')).toBeDisabled();
});

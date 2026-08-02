import { expect, test } from '@playwright/test';

// Scenarios #4 / #4b (docs/specs/internal-spec-testing.md 2.1節, 2.5節, B'案;
// implementation: docs/specs/internal-spec-vercel.md 9章,
// api/app/services/recaptcha_service.py `_resolve_secret_key`).

const VERCEL_API_BASE_URL = process.env.VERCEL_API_BASE_URL;
const SMOKE_TEST_SECRET = process.env.SMOKE_TEST_SECRET;

// Scenario #4: happy-path submission via the CI-only reCAPTCHA bypass.
// A real reCAPTCHA checkbox cannot be solved by an automated browser, so this
// test calls POST /api/verify-recaptcha directly with the X-Smoke-Test-Auth
// header to obtain a real verify_token issued against Google's official
// always-succeed test secret key, injects that token into the actual
// contact.html form (mirroring what onRecaptchaSuccess() in
// site/js/contact-form.js does after a real widget solve), and submits the
// real form. contact.cgi itself is not modified or bypassed in any way: it
// runs the exact same HMAC-token verification as a real user submission would.
//
// This intentionally sends a real notification/autoreply email and appends a
// real line to contact_log.txt on every daily run (accepted trade-off, 2.5節).
// A dummy, non-existent-domain email address is used so the operator can tell
// these apart from genuine customer inquiries at a glance.
test.describe('Contact form – happy path (CI-only reCAPTCHA bypass)', () => {
  test.skip(
    !VERCEL_API_BASE_URL || !SMOKE_TEST_SECRET,
    'VERCEL_API_BASE_URL/SMOKE_TEST_SECRET are not set (no live Vercel deployment yet, see docs/PROJECT_STATUS.md residual items)'
  );

  test('submits successfully and is redirected to contact-thanks.html', async ({ page, request }) => {
    const verifyResponse = await request.post(`${VERCEL_API_BASE_URL}/api/verify-recaptcha`, {
      headers: {
        'Content-Type': 'application/json',
        'X-Smoke-Test-Auth': SMOKE_TEST_SECRET as string,
      },
      data: { recaptcha_response: 'smoke-test-bypass' },
    });
    expect(verifyResponse.status()).toBe(200);

    const verifyBody = await verifyResponse.json();
    expect(verifyBody.verified).toBe(true);
    expect(typeof verifyBody.token).toBe('string');

    await page.goto('/contact.html');
    await page.fill('#last_name', 'スモークテスト');
    await page.fill('#first_name', '自動');
    await page.fill('#email', 'smoke-test@jyoho1.web.cyberhome.ne.jp');
    await page.fill('#email_confirm', 'smoke-test@jyoho1.web.cyberhome.ne.jp');
    await page.fill('#message', 'これはPlaywright日次スモークテストによる自動送信です。');
    await page.check('#privacy_agree');

    // The real reCAPTCHA widget cannot be operated by an automated browser;
    // inject the already-verified token and unlock the submit button exactly as
    // onRecaptchaSuccess() would, then submit through the real <form>.
    await page.fill('#verify_token', verifyBody.token);
    await page.evaluate(() => {
      const button = document.getElementById('contact-submit') as HTMLButtonElement | null;
      if (button) button.disabled = false;
    });

    await Promise.all([page.waitForURL('**/contact-thanks.html'), page.click('#contact-submit')]);
  });
});

// Scenario #4b: validation-error path, exercised independently of reCAPTCHA/HMAC
// (no verify_token, no X-Smoke-Test-Auth header — a plain API-level POST). This
// keeps working even if the #4 happy-path bypass is ever disabled.
test('contact.cgi re-renders a validation error when the email confirmation mismatches', async ({
  request,
}) => {
  const response = await request.post('cgi-bin/contact.cgi', {
    form: {
      last_name: 'スモークテスト',
      first_name: '自動',
      email: 'smoke-test@jyoho1.web.cyberhome.ne.jp',
      email_confirm: 'mismatch@jyoho1.web.cyberhome.ne.jp',
      message: 'これはPlaywright日次スモークテストによるバリデーションエラー確認です。',
      privacy_agree: '1',
    },
  });
  expect(response.status()).toBe(200);

  const body = await response.text();
  expect(body).toContain('メールアドレスが一致しません');
});

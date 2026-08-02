import { expect, test } from '@playwright/test';

// Scenarios #7/#8/#9 (docs/specs/internal-spec-testing.md 2.1節):
// QR pages and download.cgi must challenge for Basic auth (401 +
// WWW-Authenticate: Basic) *before* any application logic runs, without ever
// exercising real credentials in CI (architecture.md「破壊的な検証は行わない」/
// 8章「実際のID・パスワードを用いたBasic認証成功確認」は人手によるフェーズ8確認に委譲)。
// Verified at the API-request level (no browser Basic-auth dialog involved).

const qrPages: Array<[path: string, label: string]> = [
  ['qr/book1.html', 'book1'],
  ['qr/book2.html', 'book2'],
];

for (const [path, label] of qrPages) {
  test(`QR landing page (${label}) requires Basic auth`, async ({ request }) => {
    const response = await request.get(path, { maxRedirects: 0 });
    expect(response.status()).toBe(401);
    expect(response.headers()['www-authenticate']).toMatch(/^Basic/i);
  });
}

test('download.cgi requires Basic auth before the CGI itself runs', async ({ request }) => {
  // Apache evaluates <Files "download.cgi"> Basic auth before invoking the CGI,
  // so a nonexistent file name is sufficient to verify the 401 challenge
  // (internal-spec-cyberhome.md 3.2節ステップ1).
  const response = await request.get('cgi-bin/download.cgi?file=book1/dummy.pdf', {
    maxRedirects: 0,
  });
  expect(response.status()).toBe(401);
  expect(response.headers()['www-authenticate']).toMatch(/^Basic/i);
});

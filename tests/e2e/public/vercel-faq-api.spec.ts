import { expect, test } from '@playwright/test';

// Scenario #10 (docs/specs/internal-spec-testing.md 2.1節):
// Vercel FAQ API直接疎通 — verifies the contract shape independently of the
// browser widget (faq-widget.spec.ts covers the UI integration).
// Contract: docs/specs/internal-spec-integration.md 3章,
// api/app/models/faq.py FaqApiResponse, api/app/routers/faq.py.

const VERCEL_API_BASE_URL = process.env.VERCEL_API_BASE_URL;

test.skip(
  !VERCEL_API_BASE_URL,
  'VERCEL_API_BASE_URL is not set (no live Vercel deployment yet, see docs/PROJECT_STATUS.md residual items)'
);

test('GET /api/faq responds with the expected contract shape', async ({ request }) => {
  const response = await request.get(`${VERCEL_API_BASE_URL}/api/faq`);
  expect(response.status()).toBe(200);
  expect(response.headers()['cache-control']).toBe('no-store');

  const body = await response.json();
  expect(Array.isArray(body.faqs)).toBe(true);
  expect(body).toHaveProperty('updated_at');
});

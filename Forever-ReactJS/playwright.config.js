// End-to-end tests against the REAL stack: the Spring Boot API (:8989, with the dev-only fake Bakong on
// :9099 for KHQR), Postgres in Docker, and this storefront's SSR server.
//
//   npm run test:e2e        -> against the SSR dev server (npm run dev) on http://localhost:5173 (must be running)
//   npm run test:e2e:prod   -> builds, then starts the production SSR server (npm start) on :4173 for the run
//
// E2E_BASE_URL overrides the storefront URL. Tests share one database, so they run serially (1 worker).
import { defineConfig, devices } from '@playwright/test';

const prod = process.env.E2E_PROD === '1';
const baseURL = process.env.E2E_BASE_URL || (prod ? 'http://localhost:4173' : 'http://localhost:5173');

export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 90_000,
  expect: { timeout: 10_000 },
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: prod ? 'chromium-prod' : 'chromium-dev', use: { ...devices['Desktop Chrome'] } }],
  webServer: prod
    ? {
        command: 'npm start',
        env: { PORT: '4173' },
        url: baseURL,
        reuseExistingServer: true,
        timeout: 60_000,
      }
    : undefined,
});

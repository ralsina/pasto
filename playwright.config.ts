import { defineConfig, devices } from '@playwright/test';

/**
 * Read environment variables and provide sensible defaults
 */
const getBaseUrl = () => {
  // Check for environment variable first
  if (process.env.BASE_URL) {
    return process.env.BASE_URL;
  }
  // Default to localhost:3000 for development
  return 'http://localhost:3000';
};

export default defineConfig({
  testDir: './tests',
  /* Run tests in files in parallel */
  fullyParallel: true, // Enable parallel execution for maximum speed
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Opt out of parallel tests on CI. */
  workers: "50%", // Use 50% of available CPU cores for optimal performance
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: [
    ['html', { outputFolder: 'test-results/html-report' }],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/results.xml' }]
  ],
  outputDir: 'test-results/artifacts',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: getBaseUrl(),

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',

    /* Take screenshot on failure */
    screenshot: 'only-on-failure',

    /* Record video on failure */
    video: 'retain-on-failure',
  },

  /* Configure ONLY the Chromium project */
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  /* Run your local dev server before starting the tests */
  webServer: {
    command: 'cd /home/ralsina/code/pasto && ./bin/pasto --port 3000 --rate-paste-limit=9999 --rate-paste-user-limit=9999 --rate-highlight-limit=9999 --rate-login-limit=9999 --rate-http-limit=9999',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
});
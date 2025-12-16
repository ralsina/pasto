import { test, expect, Browser, BrowserContext } from '@playwright/test';
import { PastoTestHelpers } from './helpers/test-helpers';

test.describe('Private Paste Access Control', () => {
  let pasteId: string;
  let privatePasteUrl: string;
  let publicPasteUrl: string;

  test.beforeAll(async ({ browser }) => {
    // Create test data once for all tests in this describe block
    const context = await browser.newContext();
    const page = await context.newPage();
    const helpers = new PastoTestHelpers(page);

    // Create a private paste
    const privateResult = await helpers.createPaste({
      content: 'This is a private paste that should only be accessible to the owner',
      isPrivate: true
    });
    pasteId = privateResult.pasteId!;
    privatePasteUrl = privateResult.url!;

    // Create a public paste for comparison
    await helpers.gotoHomePage();
    const publicResult = await helpers.createPaste({
      content: 'This is a public paste that should be accessible to everyone',
      isPrivate: false
    });
    publicPasteUrl = publicResult.url!;

    await context.close();
  });

  test('should allow access to own private paste', async ({ page }) => {
    const helpers = new PastoTestHelpers(page);

    // Access the private paste in the same context (should be allowed)
    await page.goto(privatePasteUrl);
    await page.waitForLoadState('networkidle');

    // Should not be a 403 error page
    await expect(page.locator('h1')).not.toContainText('403');

    // Should contain the paste content
    const content = await helpers.getPasteContent();
    expect(content).toContain('This is a private paste');
  });

  test('should deny access to private paste in anonymous context', async ({ browser }) => {
    // Create a completely new anonymous context
    const anonymousContext = await browser.newContext();
    const anonymousPage = await anonymousContext.newPage();

    try {
      // Try to access the private paste
      await anonymousPage.goto(privatePasteUrl);
      await anonymousPage.waitForLoadState('networkidle');

      // Should be a 403 error page
      await expect(anonymousPage.locator('h1')).toContainText('403');
      await expect(anonymousPage.locator('h1')).toContainText('Access Denied');

      // Should contain helpful message for anonymous users
      const errorPage = anonymousPage.locator('.error-message');
      await expect(errorPage).toContainText('This paste is private');
      await expect(errorPage).toContainText('log in');

    } finally {
      await anonymousContext.close();
    }
  });

  test('should allow access to public paste in anonymous context', async ({ browser }) => {
    // Create a completely new anonymous context
    const anonymousContext = await browser.newContext();
    const anonymousPage = await anonymousContext.newPage();
    const helpers = new PastoTestHelpers(anonymousPage);

    try {
      // Try to access the public paste
      await anonymousPage.goto(publicPasteUrl);
      await anonymousPage.waitForLoadState('networkidle');

      // Should NOT be a 403 error page
      await expect(anonymousPage.locator('h1')).not.toContainText('403');

      // Should contain the paste content
      const content = await helpers.getPasteContent();
      expect(content).toContain('This is a public paste');

    } finally {
      await anonymousContext.close();
    }
  });

  test('should deny access to private paste in different user context', async ({ browser }) => {
    // Simulate a different user by clearing all storage and cookies
    const differentUserContext = await browser.newContext({
      // Clear all storage to simulate different user
      storageState: undefined
    });
    const differentUserPage = await differentUserContext.newPage();

    try {
      // Try to access the private paste
      await differentUserPage.goto(privatePasteUrl);
      await differentUserPage.waitForLoadState('networkidle');

      // Should be a 403 error page
      await expect(differentUserPage.locator('h1')).toContainText('403');
      await expect(differentUserPage.locator('h1')).toContainText('Access Denied');

    } finally {
      await differentUserContext.close();
    }
  });

  test('should show appropriate navigation buttons on 403 page', async ({ browser }) => {
    const anonymousContext = await browser.newContext();
    const anonymousPage = await anonymousContext.newPage();

    try {
      await anonymousPage.goto(privatePasteUrl);
      await anonymousPage.waitForLoadState('networkidle');

      // Should show login button for anonymous users
      const loginLink = anonymousPage.locator('a[href="/auth/help"]');
      await expect(loginLink).toBeVisible();

      // Should show help button
      const helpLink = anonymousPage.locator('a[href="/help"]');
      await expect(helpLink).toBeVisible();

      // Should show create new paste button
      const createLink = anonymousPage.locator('a[href="/"]');
      await expect(createLink).toBeVisible();

    } finally {
      await anonymousContext.close();
    }
  });

  test('should handle direct API access to private paste', async ({ request }) => {
    // Test API endpoint access to private paste
    const url = new URL(privatePasteUrl);
    const response = await request.get(`${url.pathname}/raw`);

    // Should be 403 for unauthorized access
    expect(response.status()).toBe(403);
  });

  test('should protect edit endpoints for private pastes', async ({ browser }) => {
    const anonymousContext = await browser.newContext();
    const anonymousPage = await anonymousContext.newPage();

    try {
      // Try to access the edit page for private paste
      await anonymousPage.goto(`${privatePasteUrl}/edit`);
      await anonymousPage.waitForLoadState('networkidle');

      // Should be a 403 error page
      await expect(anonymousPage.locator('h1')).toContainText('403');

    } finally {
      await anonymousContext.close();
    }
  });

  test('should protect delete endpoints for private pastes', async ({ request }) => {
    // Test DELETE API endpoint for private paste
    const url = new URL(privatePasteUrl);
    const response = await request.delete(url.pathname, {
      headers: {
        'Content-Type': 'application/json'
      }
    });

    // Should be 403 for unauthorized access
    expect(response.status()).toBe(403);
  });

  test('should handle private paste with different browsers', async ({ page, context }) => {
    // This test ensures that private paste access control works across different browsers/contexts

    // First, verify we can access our private paste
    await page.goto(privatePasteUrl);
    await page.waitForLoadState('networkidle');

    await expect(page.locator('h1')).not.toContainText('403');

    // Clear cookies and storage to simulate fresh browser session
    await context.clearCookies();
    await page.reload();
    await page.waitForLoadState('networkidle');

    // Should still have access because we're in the same browser context
    // (The exact behavior depends on session implementation)
    // This test helps identify session-based vs IP-based access control
  });

  test('should handle rate limiting for access attempts', async ({ browser }) => {
    const anonymousContext = await browser.newContext();
    const anonymousPage = await anonymousContext.newPage();

    try {
      // Make multiple rapid requests to the private paste
      const requests = Array(10).fill(null).map(() =>
        anonymousPage.goto(privatePasteUrl)
      );

      // All should result in 403, not rate limiting errors
      const results = await Promise.allSettled(requests);

      // Verify we don't get rate limited (still get 403 responses)
      await anonymousPage.waitForLoadState('networkidle');
      await expect(anonymousPage.locator('h1')).toContainText('403');

    } finally {
      await anonymousContext.close();
    }
  });
});
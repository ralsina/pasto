import { test, expect } from './helpers/test-helpers';

test.describe('API Key Management', () => {
  test.beforeEach(async ({ page, helpers }) => {
    // Verify auth-debug-mode is enabled for API key tests
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    if (!isAuthDebugMode) {
      test.skip();
      return;
    }

    // Navigate to profile page
    await page.goto('/profile', { waitUntil: 'domcontentloaded' });
  });

  test('should display API keys section on profile page', async ({ page, helpers }) => {
    // Check that API keys section is visible
    await expect(page.locator('[data-testid="api-keys-section"]')).toBeVisible();

    // Open the API keys accordion if it's closed
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    // Check that the accordion content is now visible
    await expect(page.locator('[data-testid="api-keys-section"] .accordion-content')).toBeVisible();

    // Check initial message when no API keys exist
    const apiKeyItems = await page.locator('.api-key-item').count();
    if (apiKeyItems === 0) {
      await expect(page.locator('text=No API keys generated yet')).toBeVisible();

      // Check SSH command example is shown
      await expect(page.locator('text=ssh -p 2222')).toBeVisible();
      await expect(page.locator('text=api-key create')).toBeVisible();
    }
  });

  test('should handle API key revocation via web interface', async ({ page, helpers }) => {
    // Open the API keys accordion if it's closed
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    // First, let's check if there are any existing API keys
    const apiKeyItems = page.locator('.api-key-item');
    const initialCount = await apiKeyItems.count();

    if (initialCount === 0) {
      // Skip test if no API keys to revoke
      test.skip();
      return;
    }

    // Get the first API key's ID for testing
    const firstApiKey = apiKeyItems.first();
    const apiKeyElement = firstApiKey.locator('.api-key-id');
    const apiKeyText = await apiKeyElement.textContent();

    expect(apiKeyText).toBeTruthy();
    expect(apiKeyText).toMatch(/^pasto_ak_[a-f0-9]{32}$/);

    // Mock the revocation confirmation to actually click OK
    page.on('dialog', async dialog => {
      expect(dialog.message()).toContain('Are you sure you want to revoke this API key?');
      await dialog.accept();
    });

    // Click the revoke button for the first API key
    const revokeButton = firstApiKey.locator('.revoke-btn[title="Revoke API Key"]');
    await revokeButton.click();

    // Wait for the revocation request to complete
    await page.waitForTimeout(1000);

    // Verify success message or page reload
    // The page should reload to show updated API key list
    await page.waitForLoadState('networkidle');

    // Verify the API key is no longer in the list
    const finalCount = await page.locator('.api-key-item').count();
    expect(finalCount).toBeLessThan(initialCount);
  });

  test('should display API key information correctly', async ({ page, helpers }) => {
    // Open the API keys accordion if it's closed
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    const apiKeyItems = page.locator('.api-key-item');
    const count = await apiKeyItems.count();

    if (count === 0) {
      // Skip if no API keys exist
      test.skip();
      return;
    }

    // Check first API key has proper structure
    const firstApiKey = apiKeyItems.first();

    // Should have API key ID in code element
    await expect(firstApiKey.locator('.api-key-id')).toBeVisible();
    const apiKeyText = await firstApiKey.locator('.api-key-id').textContent();
    expect(apiKeyText).toMatch(/^pasto_ak_[a-f0-9]{32}$/);

    // Should have creation date
    await expect(firstApiKey.locator('.created-date')).toBeVisible();
    const createdText = await firstApiKey.locator('.created-date').textContent();
    expect(createdText).toMatch(/^Created: \d{4}-\d{2}-\d{2} \d{2}:\d{2}$/);

    // Should have usage count
    await expect(firstApiKey.locator('.usage-count')).toBeVisible();
    const usageText = await firstApiKey.locator('.usage-count').textContent();
    expect(usageText).toMatch(/^Used: \d+ times$/);

    // Should have copy button
    await expect(firstApiKey.locator('.copy-btn[title="Copy API Key"]')).toBeVisible();

    // Should have revoke button
    await expect(firstApiKey.locator('.revoke-btn[title="Revoke API Key"]')).toBeVisible();
  });

  test('should copy API key to clipboard', async ({ page, helpers }) => {
    // Open the API keys accordion if it's closed
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    const apiKeyItems = page.locator('.api-key-item');
    const count = await apiKeyItems.count();

    if (count === 0) {
      // Skip if no API keys exist
      test.skip();
      return;
    }

    // Get first API key
    const firstApiKey = apiKeyItems.first();
    const apiKeyElement = firstApiKey.locator('.api-key-id');
    const apiKeyText = await apiKeyElement.textContent();

    // Mock clipboard API
    const clipboardText = await page.evaluate(() => {
      // Set up a mock for the clipboard API
      const originalClipboard = navigator.clipboard;
      let mockText = '';

      Object.defineProperty(navigator, 'clipboard', {
        value: {
          writeText: (text: string) => {
            mockText = text;
            return Promise.resolve();
          },
          readText: () => Promise.resolve(mockText)
        },
        writable: true
      });

      return { originalClipboard, mockText };
    });

    // Click copy button
    const copyButton = firstApiKey.locator('.copy-btn[title="Copy API Key"]');
    await copyButton.click();

    // Verify clipboard was set (check via our mock)
    const copiedText = await page.evaluate(() => navigator.clipboard.readText());
    expect(copiedText).toBe(apiKeyText);

    // Restore original clipboard if needed
    await page.evaluate(({ originalClipboard }) => {
      if (originalClipboard) {
        Object.defineProperty(navigator, 'clipboard', {
          value: originalClipboard,
          writable: false
        });
      }
    }, { originalClipboard: clipboardText.originalClipboard });
  });

  test('should show correct API key count in accordion', async ({ page, helpers }) => {
    // Check the API key count badge
    const countElement = page.locator('[data-testid="api-keys-accordion"] .accordion-count');
    await expect(countElement).toBeVisible();

    const countText = await countElement.textContent();
    expect(countText).toMatch(/^\d+ keys$/);

    // Open the accordion to access the content
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    // Count should match actual number of API key items
    const actualCount = await page.locator('.api-key-item').count();
    const expectedCount = parseInt(countText!.match(/(\d+) keys/)![1]);
    expect(actualCount).toBe(expectedCount);
  });

  test('should handle API key revocation error gracefully', async ({ page, helpers }) => {
    // Open the API keys accordion if it's closed
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    const apiKeyItems = page.locator('.api-key-item');
    const count = await apiKeyItems.count();

    if (count === 0) {
      // Skip if no API keys exist
      test.skip();
      return;
    }

    // Mock a failed revocation request
    await page.route('**/profile/api-keys/revoke', async route => {
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({ status: 'error', message: 'Failed to revoke API key' })
      });
    });

    // Get first API key and attempt to revoke
    const firstApiKey = apiKeyItems.first();

    // Mock the confirmation dialog
    page.on('dialog', async dialog => {
      expect(dialog.message()).toContain('Are you sure you want to revoke this API key?');
      await dialog.accept();
    });

    const revokeButton = firstApiKey.locator('.revoke-btn[title="Revoke API Key"]');
    await revokeButton.click();

    // Wait for error message
    await expect(page.locator('text=Failed to revoke API key. Please try again.')).toBeVisible();

    // API key should still be in the list after error
    const finalCount = await page.locator('.api-key-item').count();
    expect(finalCount).toBe(count);
  });
});

test.describe('API Key Creation via SSH', () => {
  test('should show API key creation instructions', async ({ page, helpers }) => {
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    if (!isAuthDebugMode) {
      test.skip();
      return;
    }

    await page.goto('/profile', { waitUntil: 'domcontentloaded' });

    // Open the API keys accordion if it's closed
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    // Check that creation instructions are displayed when no API keys exist
    const apiKeyItems = await page.locator('.api-key-item').count();
    if (apiKeyItems === 0) {
      await expect(page.locator('text=Create API keys via SSH to access the Pasto API programmatically:')).toBeVisible();
      await expect(page.locator('code.command-example').first()).toBeVisible();
      await expect(page.locator('text=ssh -p 2222')).toBeVisible();
      await expect(page.locator('text=api-key create')).toBeVisible();
    }
  });

  test('should display authentication format information', async ({ page, helpers }) => {
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    if (!isAuthDebugMode) {
      test.skip();
      return;
    }

    await page.goto('/profile', { waitUntil: 'domcontentloaded' });

    // Open the API keys accordion if it's closed
    const accordionSummary = page.locator('[data-testid="api-keys-accordion"]');
    const isExpanded = await accordionSummary.getAttribute('aria-expanded');
    if (isExpanded !== 'true') {
      await accordionSummary.click();
      await page.waitForTimeout(500); // Wait for animation
    }

    // Check that Bearer authentication format is shown
    const apiKeyItems = await page.locator('.api-key-item').count();
    if (apiKeyItems === 0) {
      await expect(page.locator('text=After creating an API key, you can use it with HTTP Bearer authentication:')).toBeVisible();
      await expect(page.locator('code:has-text("Authorization: Bearer")')).toBeVisible();
    }
  });
});
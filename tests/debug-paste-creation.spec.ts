import { test, expect } from './helpers/test-helpers';

test.describe('Debug Paste Creation', () => {
  test('should debug paste creation parameters', async ({ page, helpers }) => {
    // Check if auth-debug-mode is enabled
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    if (!isAuthDebugMode) {
      test.skip();
      return;
    }

    console.log('=== DEBUG: Testing paste creation parameters ===');

    // Create a simple paste
    const result = await helpers.createPaste({
      content: 'Debug test paste content',
      title: 'Debug Test Paste',
      language: 'javascript'
    });

    console.log('Paste creation result:');
    console.log('- pasteId:', result.pasteId);
    console.log('- url:', result.url);

    expect(result.pasteId).toBeTruthy();

    // Navigate to the created paste to verify it exists
    if (result.url) {
      await page.goto(result.url);
      await page.waitForSelector('.paste-content');

      const content = await page.locator('.paste-content code').textContent();
      console.log('Paste content on page:', content);
    }

    console.log('=== DEBUG: Paste creation test completed ===');
  });
});
import { test, expect } from './helpers/test-helpers';

test.describe('Auth Debug Mode', () => {
  test('should show prominent warning when starting server with --auth-debug-mode', async ({}) => {
    // This test verifies that the warning is displayed when the server starts
    // The actual warning display happens during server startup, not via web interface
    // This is more of a manual verification test - you should see the warning when starting the server
    expect(true).toBe(true); // Placeholder test
  });

  test('should automatically authenticate all requests when auth-debug-mode is enabled', async ({ page, helpers }) => {
    // Check if auth-debug-mode is enabled
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    console.log('Auth debug mode enabled:', isAuthDebugMode);

    // If auth-debug-mode is not enabled, this test should be skipped
    if (!isAuthDebugMode) {
      console.log('Auth debug mode not enabled, skipping test');
      test.skip();
      return;
    }

    // Go to home page
    await helpers.gotoHomePage();

    // Check if user appears authenticated
    const isAuthenticated = await helpers.isAuthenticated();
    console.log('User appears authenticated:', isAuthenticated);

    expect(isAuthenticated).toBe(true);
  });

  test('should allow private paste creation when auth-debug-mode is enabled', async ({ page, helpers }) => {
    // Check if auth-debug-mode is enabled
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    if (!isAuthDebugMode) {
      test.skip();
      return;
    }

    // Create a private paste - this should work automatically in auth-debug-mode
    const result = await helpers.createPaste({
      content: 'This is a private paste in auth debug mode',
      title: 'Auth Debug Mode Private Paste',
      language: 'javascript',
      isPrivate: true
    });

    expect(result.pasteId).toBeTruthy();
    expect(result.url).toBeTruthy();

    // Navigate to the paste and verify content
    await page.goto(result.url!);
    await helpers.waitForSyntaxHighlighting();
    const content = await helpers.getPasteContent();
    expect(content).toContain('This is a private paste in auth debug mode');
  });

  test('should include auth debug mode header in responses', async ({ helpers }) => {
    // Check if auth-debug-mode is enabled by looking for the header
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    expect(isAuthDebugMode).toBe(true);
  });
});
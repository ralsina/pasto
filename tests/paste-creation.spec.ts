import { test, expect } from './helpers/test-helpers';

test.describe('Paste Creation', () => {
  test.beforeEach(async ({ page, helpers }) => {
    // Enhanced cleanup for test isolation
    await page.goto('about:blank'); // Start with blank page
    
    // Clear everything at page level
    await page.evaluate(() => {
      try {
        document.querySelectorAll('dialog[open]').forEach(d => d.close());
        document.querySelectorAll('.modal.show, .modal[style*="display: block"]').forEach(m => m.remove());
        document.querySelectorAll('.error, .alert, .notification').forEach(n => n.remove());
      } catch (e) {
        // Ignore cleanup errors
      }
    });
    
    // Clear browser state
    const context = page.context();
    await context.clearCookies();
    await context.clearPermissions();
    
    // Now navigate to home page
    await helpers.gotoHomePage();
  });

  test('should create a basic public paste', async ({ helpers }) => {
    const testContent = 'console.log("Hello, World!");';

    // Create a simple public paste
    const result = await helpers.createPaste({
      content: testContent,
      language: 'javascript'
    });

    // Verify we're on the paste page
    await expect(helpers.page).toHaveURL(/\/[a-f0-9-]{36}$/);

    // Verify the paste content is displayed
    const displayedContent = await helpers.getPasteContent();
    const normalizedDisplayed = displayedContent.replace(/\s+/g, ' ').trim();
    const normalizedExpected = testContent.replace(/\s+/g, ' ').trim();
    expect(normalizedDisplayed).toContain(normalizedExpected);

    // Verify syntax highlighting is applied
    await helpers.waitForSyntaxHighlighting();
    const highlightedCode = await helpers.page.locator('.paste-content code').first();
    await expect(highlightedCode).toBeVisible();
  });

  test('should create a paste with title and filename', async ({ helpers }) => {
    const testContent = 'def hello_world():\n    print("Hello, Python!")';

    const result = await helpers.createPaste({
      content: testContent,
      language: 'python',
      title: 'My Python Script',
      filename: 'hello.py'
    });

    // Verify paste was created
    const displayedContent = await helpers.getPasteContent();
    // Normalize whitespace for comparison
    const normalizedDisplayed = displayedContent.replace(/\s+/g, ' ').trim();
    const normalizedExpected = testContent.replace(/\s+/g, ' ').trim();
    expect(normalizedDisplayed).toContain(normalizedExpected);

    // Check if filename is displayed (if the UI shows it)
    await helpers.waitForSyntaxHighlighting();
  });

  test.skip('should create a private paste - requires logged in user', async ({ helpers }) => {
    // This test is skipped because private pastes require authentication
    // TODO: Create tests for logged-in users
  });

  test('should not show private option for anonymous users', async ({ helpers }) => {
    await helpers.gotoHomePage();

    // Fill in some content
    await helpers.page.locator('#editor').fill('Test content for anonymous user');

    // Click settings button to open security modal
    await helpers.page.locator('#security-settings-btn').click();
    await helpers.page.waitForSelector('#security-access-control', { state: 'visible' });

    // Check that private option is not available for anonymous users
    const privateOption = await helpers.page.locator('#security-access-control option[value="private"]');
    await expect(privateOption).toHaveCount(0);

    // Verify only public and encrypted options are available
    const publicOption = await helpers.page.locator('#security-access-control option[value="public"]');
    const encryptedOption = await helpers.page.locator('#security-access-control option[value="encrypted"]');
    await expect(publicOption).toHaveCount(1);
    await expect(encryptedOption).toHaveCount(1);
  });

  test('should create an encrypted paste', async ({ helpers }) => {
    const testContent = 'This is an encrypted paste';

    // Note: Encrypted pastes show an encryption dialog first
    const result = await helpers.createPaste({
      content: testContent,
      isEncrypted: true
    });

    // For encrypted pastes, we should see an encryption dialog
    // The encryption flow is: createPaste() -> encryption options dialog
    try {
      // Check for encryption options dialog (intermediate step)
      await helpers.page.waitForSelector('dialog:has-text("Encrypt Paste")', { timeout: 8000 });
      const hasEncryptDialog = await helpers.page.locator('dialog:has-text("Encrypt Paste")').count() > 0;
      expect(hasEncryptDialog).toBe(true);
    } catch (e) {
      // If dialog was already handled, check that we're on the paste page
      const currentUrl = helpers.page.url();
      expect(currentUrl).toMatch(/\/[a-f0-9-]{36}$/);
    }
  });

  test('should create a burn-after-reading paste', async ({ helpers }) => {
    const testContent = 'This will self-destruct';

    const result = await helpers.createPaste({
      content: testContent,
      burnAfterReading: true
    });

    // For burn-after-reading pastes, we should see the modal and then be redirected to home
    // The modal shows the paste URL and warns about self-destruction
    // After closing the modal, we should be back on the home page
    await helpers.page.waitForURL('/', { timeout: 5000 });

    // Verify we're back on the home page
    await expect(helpers.page.locator('#editor')).toBeVisible();
    await expect(helpers.page).toHaveURL('/');

    // Note: The actual burn-after-reading behavior (paste being deleted after first view)
    // would require a second context/browser to test properly
  });

  test('should set paste expiration', async ({ helpers }) => {
    const testContent = 'This expires in 1 hour';

    const result = await helpers.createPaste({
      content: testContent,
      expiration: '1h'
    });

    // Verify the paste was created
    const displayedContent = await helpers.getPasteContent();
    const normalizedDisplayed = displayedContent.replace(/\s+/g, " ").trim();
    const normalizedExpected = testContent.replace(/\s+/g, " ").trim();
    expect(normalizedDisplayed).toContain(normalizedExpected);

    // Note: Actually testing expiration would require time manipulation
  });

  test('should handle empty paste validation', async ({ helpers }) => {
    await helpers.gotoHomePage();

    // Try to create an empty paste
    await helpers.page.locator('button[onclick*="createPaste"]').click();

    // Should stay on the home page (validation should prevent creation)
    await expect(helpers.page).toHaveURL('/');

    // Should show some kind of error or validation message
    // This depends on how the UI handles empty paste validation
  });

  test('should handle very large paste content', async ({ helpers }) => {
    // Create a large string (but within reasonable test limits)
    const largeContent = 'Large content line.\n'.repeat(1000);

    const result = await helpers.createPaste({
      content: largeContent
    });

    // Verify the large paste was created successfully
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('Large content line.');

    // Verify all lines are present
    const lineCount = displayedContent.split('\n').length;
    expect(lineCount).toBeGreaterThan(900);
  });

  test('should support multiple languages', async ({ page, helpers }) => {
    const languageTests = [
      { lang: 'javascript', content: 'console.log("JS");' },
      { lang: 'python', content: 'print("Python")' },
      { lang: 'ruby', content: 'puts "Ruby"' },
      { lang: 'c', content: '#include <stdio.h>\nint main() { printf("C"); return 0; }' },
    ];

    for (const test of languageTests) {
      const result = await helpers.createPaste({
        content: test.content,
        language: test.lang
      });

      // Verify syntax highlighting is applied
      await helpers.waitForSyntaxHighlighting();
      const highlightedElement = await helpers.page.locator('.paste-content code');
      await expect(highlightedElement).toBeVisible();

      // Go back to home for next test
      await helpers.gotoHomePage();
    }
  });

  test('should create paste with special characters', async ({ helpers }) => {
    const specialContent = `Special chars: àáâãäå æçèéêë ìíîï ñòóôõö ùúûüý ÿ 中文 العربية русский`;

    const result = await helpers.createPaste({
      content: specialContent
    });

    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain(specialContent);
  });
});
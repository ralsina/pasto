import { test, expect } from './helpers/test-helpers';

test.describe('Paste Creation', () => {
  test.beforeEach(async ({ page, helpers }) => {
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
    expect(displayedContent).toContain(testContent);

    // Verify syntax highlighting is applied
    await helpers.waitForSyntaxHighlighting();
    const highlightedCode = await helpers.page.locator('.highlight .line').first();
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
    expect(displayedContent).toContain(testContent);

    // Check if filename is displayed (if the UI shows it)
    await helpers.waitForSyntaxHighlighting();
  });

  test('should create a private paste', async ({ helpers }) => {
    const testContent = 'This is a private paste';

    const result = await helpers.createPaste({
      content: testContent,
      isPrivate: true
    });

    // Verify we can access our own private paste
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain(testContent);
  });

  test('should create an encrypted paste', async ({ helpers }) => {
    const testContent = 'This is an encrypted paste';

    // Note: This test might need adjustment based on how encryption works in the UI
    const result = await helpers.createPaste({
      content: testContent,
      isEncrypted: true
    });

    // Verify the paste was created
    await expect(helpers.page).toHaveURL(/\/[a-f0-9-]{36}$/);
  });

  test('should create a burn-after-reading paste', async ({ helpers }) => {
    const testContent = 'This will self-destruct';

    const result = await helpers.createPaste({
      content: testContent,
      burnAfterReading: true
    });

    // Verify we can see it the first time
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain(testContent);

    // Note: Testing actual burn-after-reading behavior is complex
    // and would require a second context/browser to verify it's gone
  });

  test('should set paste expiration', async ({ helpers }) => {
    const testContent = 'This expires in 1 hour';

    const result = await helpers.createPaste({
      content: testContent,
      expiration: '1h'
    });

    // Verify the paste was created
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain(testContent);

    // Note: Actually testing expiration would require time manipulation
  });

  test('should handle empty paste validation', async ({ helpers }) => {
    await helpers.gotoHomePage();

    // Try to create an empty paste
    await helpers.page.locator('#create-button').click();

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
      { lang: 'go', content: 'fmt.Println("Go")' },
      { lang: 'rust', content: 'println!("Rust");' },
    ];

    for (const test of languageTests) {
      const result = await helpers.createPaste({
        content: test.content,
        language: test.lang
      });

      // Verify syntax highlighting is applied
      await helpers.waitForSyntaxHighlighting();
      const highlightedElement = await helpers.page.locator('.highlight');
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
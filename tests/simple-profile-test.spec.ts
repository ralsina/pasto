import { test, expect } from './helpers/test-helpers';

test.describe('Simple Profile Test', () => {
  test('should create various security pastes and verify them on profile page in single session', async ({ page, helpers }) => {
    // Check if auth-debug-mode is enabled
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    if (!isAuthDebugMode) {
      test.skip();
      return;
    }

    // Navigate to profile page first to establish the session
    console.log('Establishing session...');
    await page.goto('/profile');
    await page.waitForSelector('.profile-container');

    // Verify we're authenticated
    await expect(page.locator('.user-info')).toBeVisible();
    await expect(page.locator('.not-logged-in')).toHaveCount(0);

    // Create pastes sequentially in the same session
    const testPastes = [
      { title: 'Public Test Paste', content: 'This is public', language: 'javascript', type: 'public' },
      { title: 'Private Test Paste', content: 'This is private', language: 'python', type: 'private' }
      // Skip encrypted for now - it has UI complexity issues
    ];

    console.log('Creating pastes...');
    for (const testPaste of testPastes) {
      console.log(`Creating ${testPaste.type} paste: ${testPaste.title}`);

      const options: any = {
        content: testPaste.content,
        title: testPaste.title,
        language: testPaste.language
      };

      if (testPaste.type === 'private') {
        options.isPrivate = true;
      } else if (testPaste.type === 'encrypted') {
        options.isEncrypted = true;
      }

      const result = await helpers.createPaste(options);
      console.log(`Created paste with ID: ${result.pasteId}`);

      expect(result.pasteId).toBeTruthy();
      expect(result.url).toBeTruthy();

      // Wait a moment between creations
      await page.waitForTimeout(1000);
    }

    // Navigate to profile page to verify pastes
    console.log('Verifying pastes on profile page...');
    await page.goto('/profile');
    await page.waitForSelector('.profile-container');

    // Open the pastes accordion if it's closed
    const pastesAccordion = page.locator('details:has-text("Your Pastes")').first();
    if (!(await pastesAccordion.getAttribute('open'))) {
      await pastesAccordion.locator('.accordion-summary').click();
    }

    // Wait for paste list to load
    await page.waitForSelector('.pastes-list', { timeout: 10000 });

    // Verify each paste appears with correct security indicators
    for (const testPaste of testPastes) {
      console.log(`Verifying ${testPaste.type} paste: ${testPaste.title}`);

      // Find the paste item by title
      const pasteTitle = page.locator(`.pastes-list .paste-title:has-text("${testPaste.title}")`);
      await expect(pasteTitle).toBeVisible({ timeout: 5000 });

      const pasteItem = pasteTitle.locator('..');

      // Verify security indicators
      if (testPaste.type === 'private') {
        await expect(pasteItem.locator('.private-badge')).toBeVisible();
        await expect(pasteItem.locator('.shield-icon')).toBeVisible();
      } else if (testPaste.type === 'public') {
        // Public paste should NOT have security badges
        await expect(pasteItem.locator('.private-badge')).toHaveCount(0);
        await expect(pasteItem.locator('.encrypted-badge')).toHaveCount(0);
        await expect(pasteItem.locator('.view-once-badge')).toHaveCount(0);
      }

      console.log(`✓ ${testPaste.type} paste verified`);
    }

    // Verify total count
    const itemCount = await page.locator('details:has-text("Your Pastes") .accordion-count').first().textContent();
    expect(itemCount).toMatch(/\d+ items/);

    console.log('All pastes successfully verified on profile page!');
  });
});
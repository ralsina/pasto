import { test, expect } from './helpers/test-helpers';

test.describe('Debug Profile', () => {
  test('should debug what appears on profile page in auth-debug-mode', async ({ page, helpers }) => {
    // Check if auth-debug-mode is enabled
    const isAuthDebugMode = await helpers.isAuthDebugMode();
    if (!isAuthDebugMode) {
      test.skip();
      return;
    }

    console.log('=== DEBUG: Starting profile debug test ===');

    // Navigate to profile page
    await page.goto('/profile');
    await page.waitForSelector('.profile-container');

    // Check if we're authenticated
    const hasUserInfo = await page.locator('.user-info').isVisible();
    const hasNoLoggedIn = await page.locator('.not-logged-in').isVisible();

    console.log('User info visible:', hasUserInfo);
    console.log('Not logged in visible:', hasNoLoggedIn);

    // Check what accordion sections exist
    const accordionTexts = await page.locator('.accordion-summary').allTextContents();
    console.log('Accordion sections:', accordionTexts);

    // Check the pastes accordion specifically
    const pastesAccordion = page.locator('details:has-text("Your Pastes")').first();
    const isOpen = await pastesAccordion.getAttribute('open');
    console.log('Pastes accordion open:', isOpen);

    // Open it if closed
    if (!isOpen) {
      await pastesAccordion.locator('.accordion-summary').click();
      await page.waitForTimeout(1000);
    }

    // Check if there's a pastes list
    const hasPastesList = await page.locator('.pastes-list').isVisible();
    console.log('Pastes list visible:', hasPastesList);

    if (hasPastesList) {
      const pasteItems = await page.locator('.pastes-list .paste-item').count();
      console.log('Number of paste items:', pasteItems);

      if (pasteItems > 0) {
        // Get all paste titles
        const titles = await page.locator('.pastes-list .paste-title').allTextContents();
        console.log('Paste titles:', titles);
      }
    } else {
      // Check for "no items" message
      const hasNoItems = await page.locator('.pastes-list .no-items').isVisible();
      console.log('No items message visible:', hasNoItems);

      if (hasNoItems) {
        const noItemsText = await page.locator('.pastes-list .no-items').textContent();
        console.log('No items text:', noItemsText);
      }

      // Take screenshot for debugging
      await page.screenshot({ path: 'debug-profile-page.png', fullPage: true });
      console.log('Screenshot saved as debug-profile-page.png');
    }

    // Check item count
    const itemCount = await page.locator('details:has-text("Your Pastes") .accordion-count').first().textContent();
    console.log('Item count text:', itemCount);

    console.log('=== DEBUG: Profile debug test completed ===');

    // This test always passes - it's just for debugging
    expect(true).toBe(true);
  });
});
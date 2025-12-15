import { test, expect } from '@playwright/test';

test.describe('Basic System Check', () => {
  test('should be able to access the home page', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Check that the page loads
    await expect(page).toHaveTitle(/Pasto/);

    // Check that basic elements exist
    await expect(page.locator('body')).toBeVisible();
  });

  test('should have the editor available', async ({ page }) => {
    await page.goto('/');

    // Look for the editor element
    const editor = page.locator('#editor, textarea, [contenteditable="true"]');
    await expect(editor).toBeVisible();
  });
});
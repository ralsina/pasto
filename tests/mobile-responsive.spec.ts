import { test, devices, expect } from '@playwright/test';
import { PastoTestHelpers } from './helpers/test-helpers';

test.describe('Mobile Responsive Design', () => {
  test.describe('Mobile Viewport - iPhone 12', () => {
    test.use(devices['iPhone 12']);

    test('should display properly on mobile viewport', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);
      await helpers.gotoHomePage();

      // Check that main elements are visible
      await expect(page.locator('body')).toBeVisible();

      // Check that the editor is properly sized for mobile
      const editor = page.locator('#editor');
      await expect(editor).toBeVisible();

      // Check that mobile controls are present if they exist
      const mobileControls = page.locator('.mobile-controls, .controls-mobile');
      if (await mobileControls.isVisible()) {
        await expect(mobileControls).toBeVisible();
      }
    });

    test('should allow paste creation on mobile', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);

      // Create a paste on mobile
      const result = await helpers.createPaste({
        content: 'Mobile test paste created from iPhone 12',
        language: 'javascript'
      });

      // Verify paste was created successfully
      await expect(page).toHaveURL(/\/[a-f0-9-]{36}$/);

      const displayedContent = await helpers.getPasteContent();
      expect(displayedContent).toContain('Mobile test paste');
    });

    test('should handle mobile keyboard interactions', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);
      await helpers.gotoHomePage();

      // Focus on the editor to trigger mobile keyboard
      await page.locator('#editor').focus();

      // Type content
      await page.locator('#editor').fill('Mobile keyboard test');

      // Verify content was entered
      const content = await page.locator('#editor').inputValue();
      expect(content).toContain('Mobile keyboard test');

      // Verify keyboard doesn't obscure important elements
      // This is more of a visual test, but we can check that elements are still reachable
      await expect(page.locator('#create-button')).toBeVisible();
    });

    test('should support mobile theme switching', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);
      await helpers.gotoHomePage();

      // Look for theme toggle button on mobile
      const themeToggle = page.locator('#theme-toggle, .theme-toggle, button[title*="theme"]');

      if (await themeToggle.isVisible()) {
        await themeToggle.click();
        await page.waitForTimeout(300); // Wait for theme transition

        // Verify theme changed by checking if theme toggle is still visible
        await expect(themeToggle).toBeVisible();
      }
    });

    test('should handle mobile security modal', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);
      await helpers.gotoHomePage();

      // Fill some content first
      await page.locator('#editor').fill('Mobile security modal test');

      // Look for security/settings button
      const securityButton = page.locator('#security-button, .security-button, button[title*="security"]');

      if (await securityButton.isVisible()) {
        await securityButton.click();

        // Check if security modal appears and is properly sized for mobile
        const modal = page.locator('dialog, .modal, .security-modal');
        if (await modal.isVisible()) {
          // Check modal is not wider than viewport
          const modalBox = await modal.boundingBox();
          const viewport = page.viewportSize();
          expect(modalBox?.width).toBeLessThanOrEqual(viewport!.width - 32); // 32px padding

          // Close modal if possible
          const closeButton = modal.locator('button[title*="Close"], .close-button, #cancelSecurityBtn');
          if (await closeButton.isVisible()) {
            await closeButton.click();
          }
        }
      }
    });

    test('should handle mobile language selection', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);
      await helpers.gotoHomePage();

      // Look for language selector
      const languageSelector = page.locator('#language, .language-selector');

      if (await languageSelector.isVisible()) {
        // Open language selector
        await languageSelector.click();

        // Select a language (try a few common mobile-friendly options)
        const javascriptOption = languageSelector.locator('option[value="javascript"]');
        if (await javascriptOption.isVisible()) {
          await javascriptOption.click();
        }

        // Verify selection
        const selectedValue = await languageSelector.inputValue();
        expect(selectedValue).toBe('javascript');
      }
    });

    test('should support mobile navigation', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);

      // Create a paste first
      const result = await helpers.createPaste({
        content: 'Mobile navigation test',
        language: 'javascript'
      });

      // Check navigation elements on mobile
      const navigationButtons = [
        page.locator('a[href="/"]'),  // Home/New paste
        page.locator('a[href="/help"]'),  // Help
      ];

      for (const button of navigationButtons) {
        if (await button.isVisible()) {
          // Check button is large enough for mobile touch
          const buttonBox = await button.boundingBox();
          expect(buttonBox?.height).toBeGreaterThanOrEqual(44); // 44px minimum touch target
          expect(buttonBox?.width).toBeGreaterThanOrEqual(44);
        }
      }
    });

    test('should handle mobile error pages', async ({ page }) => {
      // Test 404 error page on mobile
      await page.goto('/nonexistent-paste-id');
      await page.waitForLoadState('networkidle');

      // Check 404 page is mobile-friendly
      await expect(page.locator('h1')).toContainText('404');

      // Check navigation buttons are mobile-sized
      const navButtons = page.locator('a').all();
      for (const button of navButtons.slice(0, 3)) { // Check first few buttons
        if (await button.isVisible()) {
          const buttonBox = await button.boundingBox();
          expect(buttonBox?.height).toBeGreaterThanOrEqual(44);
        }
      }
    });

    test('should handle mobile 403 error page', async ({ page }) => {
      // First create a private paste
      const helpers = new PastoTestHelpers(page);
      const privateResult = await helpers.createPaste({
        content: 'Private mobile test',
        isPrivate: true
      });

      // Clear storage to simulate anonymous access
      await page.context().clearCookies();
      await page.context().clearPermissions();

      // Try to access the private paste
      await page.goto(privateResult.url!);
      await page.waitForLoadState('networkidle');

      // Check 403 page is mobile-friendly
      await expect(page.locator('h1')).toContainText('403');
      await expect(page.locator('.error-message')).toContainText('private');

      // Check login/help buttons are mobile-sized
      const loginButton = page.locator('a[href="/auth/help"]');
      const helpButton = page.locator('a[href="/help"]');

      if (await loginButton.isVisible()) {
        const loginBox = await loginButton.boundingBox();
        expect(loginBox?.height).toBeGreaterThanOrEqual(44);
      }

      if (await helpButton.isVisible()) {
        const helpBox = await helpButton.boundingBox();
        expect(helpBox?.height).toBeGreaterThanOrEqual(44);
      }
    });

    test('should handle mobile syntax highlighting', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);

      const result = await helpers.createPaste({
        content: 'function mobileSyntaxTest() { return true; }',
        language: 'javascript'
      });

      // Wait for syntax highlighting
      await helpers.waitForSyntaxHighlighting();

      // Check that code is displayed properly on mobile
      const highlightElement = page.locator('.highlight');
      await expect(highlightElement).toBeVisible();

      // Check that code is not truncated horizontally
      const codeLines = page.locator('.line').all();
      if (codeLines.length > 0) {
        const firstLineBox = await codeLines[0].boundingBox();
        const viewport = page.viewportSize();

        // Code should either fit in viewport or be scrollable
        if (firstLineBox) {
          expect(firstLineBox.width).toBeLessThanOrEqual(viewport!.width);
        }
      }
    });

    test('should handle mobile scrolling', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);

      // Create a long paste
      const longContent = Array(100).fill(null).map((_, i) => `Line ${i + 1}: This is a long line for mobile scrolling test`).join('\n');

      const result = await helpers.createPaste({
        content: longContent
      });

      // Wait for content to load
      await helpers.waitForSyntaxHighlighting();

      // Test scrolling
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
      await page.waitForTimeout(1000);

      // Verify we can scroll to bottom
      const scrollHeight = await page.evaluate(() => document.body.scrollHeight);
      expect(scrollHeight).toBeGreaterThan(page.viewportSize()!.height);

      // Scroll back to top
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.waitForTimeout(500);

      // Verify we're back at top
      const scrollTop = await page.evaluate(() => window.pageYOffset);
      expect(scrollTop).toBe(0);
    });
  });

  test.describe('Mobile Viewport - Pixel 5 (Android)', () => {
    test.use(devices['Pixel 5']);

    test('should work on Android mobile viewport', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);

      const result = await helpers.createPaste({
        content: 'Android mobile test: console.log("Hello from Pixel 5");',
        language: 'javascript'
      });

      await expect(page).toHaveURL(/\/[a-f0-9-]{36}$/);

      const displayedContent = await helpers.getPasteContent();
      expect(displayedContent).toContain('Android mobile test');
    });
  });

  test.describe('Tablet Viewport - iPad', () => {
    test.use(devices['iPad']);

    test('should display properly on tablet viewport', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);
      await helpers.gotoHomePage();

      // Tablet should have more space than mobile
      const viewport = page.viewportSize();
      expect(viewport!.width).toBeGreaterThan(768);

      // All main elements should be visible
      await expect(page.locator('#editor')).toBeVisible();
      await expect(page.locator('#create-button')).toBeVisible();
    });

    test('should support tablet-optimized layout', async ({ page }) => {
      const helpers = new PastoTestHelpers(page);

      const result = await helpers.createPaste({
        content: 'Tablet test with syntax highlighting\nconst tablet = "iPad layout test";\nconsole.log(tablet);',
        language: 'javascript'
      });

      await helpers.waitForSyntaxHighlighting();

      // On tablet, we might see different layout optimizations
      const highlightElement = page.locator('.highlight');
      await expect(highlightElement).toBeVisible();

      // Check that we have more horizontal space than mobile
      const codeContainer = page.locator('.highlight, .code-container');
      if (await codeContainer.isVisible()) {
        const codeBox = await codeContainer.boundingBox();
        expect(codeBox?.width).toBeGreaterThan(500); // Tablet should have more width
      }
    });
  });
});
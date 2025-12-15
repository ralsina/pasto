import { test, expect, Page, BrowserContext } from '@playwright/test';

/**
 * Base test class with common utilities for Pasto tests
 */
export class PastoTestHelpers {
  constructor(public page: Page) {}

  /**
   * Navigate to the home page
   */
  async gotoHomePage() {
    await this.page.goto('/');
    await this.page.waitForLoadState('networkidle');
  }

  /**
   * Create a new paste with the given content
   */
  async createPaste(options: {
    content: string;
    language?: string;
    title?: string;
    filename?: string;
    isPrivate?: boolean;
    isEncrypted?: boolean;
    burnAfterReading?: boolean;
    expiration?: string;
  }) {
    await this.gotoHomePage();

    // Fill in the paste content
    await this.page.locator('#editor').fill(options.content);

    // Set language if specified
    if (options.language) {
      await this.page.locator('#language').selectOption(options.language);
    }

    // Click settings button to open security modal
    await this.page.locator('#security-button').click();
    await this.page.waitForSelector('#security-access-control', { state: 'visible' });

    // Set access control
    if (options.isPrivate) {
      await this.page.locator('#security-access-control').selectOption('private');
    } else if (options.isEncrypted) {
      await this.page.locator('#security-access-control').selectOption('encrypted');
    } else {
      await this.page.locator('#security-access-control').selectOption('public');
    }

    // Set burn after reading
    if (options.burnAfterReading) {
      await this.page.locator('#security-burn').check();
    }

    // Set expiration
    if (options.expiration) {
      await this.page.locator('#security-expiration').selectOption(options.expiration);
    }

    // Save settings
    await this.page.locator('#saveSecurityBtn').click();
    await this.page.waitForSelector('#security-access-control', { state: 'hidden' });

    // Create the paste
    await this.page.locator('#create-button').click();

    // Wait for navigation to the paste page
    await this.page.waitForURL(/\/[a-f0-9-]{36}$/);

    // Extract the paste ID from the URL
    const url = this.page.url();
    const pasteId = url.split('/').pop();

    return { pasteId, url };
  }

  /**
   * Get the current paste content from the page
   */
  async getPasteContent(): Promise<string> {
    return await this.page.locator('.highlight').textContent() || '';
  }

  /**
   * Get the current paste language
   */
  async getPasteLanguage(): Promise<string> {
    return await this.page.locator('#language').textContent() || '';
  }

  /**
   * Check if the page is a 403 error page
   */
  async is403ErrorPage(): Promise<boolean> {
    const heading = await this.page.locator('h1').textContent();
    return heading?.includes('403') || false;
  }

  /**
   * Check if the page is a 404 error page
   */
  async is404ErrorPage(): Promise<boolean> {
    const heading = await this.page.locator('h1').textContent();
    return heading?.includes('404') || false;
  }

  /**
   * Wait for syntax highlighting to be applied
   */
  async waitForSyntaxHighlighting() {
    await this.page.waitForSelector('.highlight .line', { timeout: 10000 });
  }

  /**
   * Get the current theme
   */
  async getCurrentTheme(): Promise<string> {
    const themeIcon = await this.page.locator('#theme-toggle i').getAttribute('data-lucide');
    return themeIcon || '';
  }

  /**
   * Toggle theme (light/dark)
   */
  async toggleTheme() {
    await this.page.locator('#theme-toggle').click();
    // Wait for theme transition
    await this.page.waitForTimeout(300);
  }

  /**
   * Check if the page is in mobile view (based on viewport width)
   */
  async isMobileView(): Promise<boolean> {
    const viewport = this.page.viewportSize();
    return (viewport?.width || 0) < 768;
  }

  /**
   * Take a screenshot with a descriptive name
   */
  async takeScreenshot(name: string) {
    await this.page.screenshot({
      path: `test-results/screenshots/${name}-${Date.now()}.png`,
      fullPage: true
    });
  }
}

/**
 * Extend test with custom fixtures
 */
export const test = base.extend<{ helpers: PastoTestHelpers }>({
  helpers: async ({ page }, use) => {
    const helpers = new PastoTestHelpers(page);
    await use(helpers);
  },
});

export { expect };
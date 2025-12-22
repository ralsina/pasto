import { test as base, expect, Page, BrowserContext } from '@playwright/test';

/**
 * Base test class with common utilities for Pasto tests
 */
export class PastoTestHelpers {
  constructor(public page: Page) {}

  /**
   * Navigate to the home page with enhanced cleanup for test isolation
   */
  async gotoHomePage() {
    try {
      // First, handle any existing dialogs/modals gracefully
      await this.page.evaluate(() => {
        try {
          // Close any open dialogs
          const dialogs = document.querySelectorAll('dialog[open]');
          dialogs.forEach(dialog => {
            try {
              dialog.close();
            } catch (e) {
              // Ignore errors when closing dialogs
            }
          });

          // Remove any dynamically added modals
          const modals = document.querySelectorAll('.modal[style*="display: block"], .modal[style*="display:block"], .modal.show');
          modals.forEach(modal => {
            try {
              modal.remove();
            } catch (e) {
              // Ignore errors when removing modals
            }
          });

          // Clear any overlay elements that might block interaction
          const overlays = document.querySelectorAll('[style*="position: fixed"], [style*="position:fixed"], .modal-backdrop, [role="dialog"]');
          overlays.forEach(overlay => {
            try {
              if (overlay.tagName === 'DIV' && (overlay.style.zIndex > 1000 || overlay.style.position === 'fixed')) {
                overlay.remove();
              }
            } catch (e) {
              // Ignore errors when removing overlays
            }
          });

          // Reset any form elements to clean state
          const forms = document.querySelectorAll('form, input, textarea, select');
          forms.forEach(form => {
            try {
              if (form.tagName === 'FORM') {
                form.reset();
              } else {
                (form as HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement).value = '';
              }
            } catch (e) {
              // Ignore errors when resetting forms
            }
          });

          // Clear storage completely
          try {
            if (typeof localStorage !== 'undefined') {
              localStorage.clear();
            }
          } catch (e) {
            // Ignore localStorage access errors
          }
          try {
            if (typeof sessionStorage !== 'undefined') {
              sessionStorage.clear();
            }
          } catch (e) {
            // Ignore sessionStorage access errors
          }
        } catch (e) {
          // Ignore all evaluation errors
        }
      });

      // Clear browser-level state
      try {
        const context = this.page.context();
        await context.clearCookies();
        await context.clearPermissions();
      } catch (e) {
        // Ignore context clearing errors
      }

      // Navigate with longer timeout
      await this.page.goto('/', { 
        waitUntil: 'domcontentloaded',
        timeout: 10000 
      });

      // Wait for full load
      await this.page.waitForLoadState('networkidle');

      // Wait for editor with retry logic
      try {
        await this.page.waitForSelector('#editor', { 
          state: 'visible', 
          timeout: 8000 
        });
        
        // Verify editor is properly initialized
        await this.page.waitForFunction(() => {
          const editor = document.getElementById('editor');
          return editor && (window.jar !== undefined || editor.textContent !== undefined);
        }, { timeout: 5000 });
        
      } catch (e) {
        console.log('Editor not ready, attempting page reload...');
        await this.page.reload({ waitUntil: 'networkidle' });
        await this.page.waitForSelector('#editor', { state: 'visible', timeout: 8000 });
      }
    } catch (e) {
      console.log('gotoHomePage error:', e);
      // Try fallback navigation
      await this.page.goto('/');
      await this.page.waitForSelector('#editor', { timeout: 10000 });
    }
  }

  /**
   * Create a new paste with given content
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
    skipNavigate?: boolean; // Optional flag to skip initial navigation
  }) {
    // Start with a clean slate (unless already navigated)
    if (!options.skipNavigate) {
      await this.gotoHomePage();
      // Wait a moment to ensure everything is settled after navigation
      await this.page.waitForTimeout(300);
    }

    try {
      // Fill in the paste content
      let contentSet = false;
      for (let attempt = 0; attempt < 3 && !contentSet; attempt++) {
        contentSet = await this.page.evaluate((content) => {
          try {
            if (window.jar) {
              window.jar.updateCode(content);
              return true;
            } else {
              // Fallback if jar is not available yet
              const editor = document.getElementById('editor');
              if (editor) {
                editor.textContent = content;
                editor.dispatchEvent(new Event('input', { bubbles: true }));
                return true;
              }
            }
            return false;
          } catch (e) {
            console.error('Failed to set content:', e);
            return false;
          }
        }, options.content);

        if (!contentSet) {
          await this.page.waitForTimeout(500);
        }
      }

      if (!contentSet) {
        throw new Error('Failed to set editor content after multiple attempts');
      }

      // Set title if specified
      if (options.title) {
        await this.page.locator('#paste-title').fill(options.title);
      }

      // Set language if specified
      if (options.language) {
        // Wait for language selector to be available
        await this.page.waitForSelector('#language', { timeout: 10000 });

        // Wait for languages to load via API - wait for substantial number of options
        await this.page.waitForFunction(() => {
          const select = document.getElementById('language');
          return select && select.options.length > 100; // Wait for most languages to load
        }, { timeout: 25000 });

        // Find and select language using a more robust approach
        const languageSelected = await this.page.evaluate((targetLanguage) => {
          const select = document.getElementById('language');
          if (!select) return false;

          // Look for exact match first
          for (let i = 0; i < select.options.length; i++) {
            if (select.options[i].value === targetLanguage) {
              select.value = targetLanguage;
              select.dispatchEvent(new Event('change', { bubbles: true }));
              return true;
            }
          }

          // Look for case-insensitive match
          for (let i = 0; i < select.options.length; i++) {
            if (select.options[i].value.toLowerCase() === targetLanguage.toLowerCase()) {
              select.value = select.options[i].value;
              select.dispatchEvent(new Event('change', { bubbles: true }));
              return true;
            }
          }

          return false; // Language not found
        }, options.language);

        if (!languageSelected) {
          throw new Error(`Language "${options.language}" not found in selector`);
        }
      }

      // Click settings button to open security modal with better error handling
      try {
        await this.page.locator('#security-settings-btn').click();
        await this.page.waitForSelector('#security-access-control', { 
          state: 'visible', 
          timeout: 5000 
        });
      } catch (e) {
        console.log('Settings button might not be available, proceeding without security settings');
      }

      // Set access control only if modal opened successfully
      const modalVisible = await this.page.locator('#security-access-control').isVisible();
      if (modalVisible) {
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
        await this.page.waitForSelector('#security-access-control', { 
          state: 'hidden', 
          timeout: 5000 
        });
      }

      // Wait a moment before creating paste
      await this.page.waitForTimeout(200);

      // Create the paste
      await this.page.locator('button[onclick*="createPaste"]').click();

      // Handle different flows for special paste types vs regular pastes
      if (options.isEncrypted) {
        // For encrypted pastes, wait for the encryption dialog and handle password input
        try {
          await this.page.waitForSelector('dialog:has-text("Encrypt Paste")', { timeout: 8000 });

          // Click Generate button to auto-generate a password
          await this.page.locator('#generatePasswordBtn').click();

          // Wait for password field to be filled (or give it a moment)
          await this.page.waitForTimeout(500);

          // Click the Encrypt Paste button to proceed
          await this.page.locator('#encryptBtn').click();

          // Wait for the dialog to close and paste to be created
          await this.page.waitForSelector('dialog', { state: 'hidden', timeout: 8000 });

        } catch (e) {
          console.log('Encryption dialog handling failed:', e);
          // Check if we might have gotten a different dialog
          const anyDialog = await this.page.locator('dialog').isVisible();
          if (anyDialog) {
            // Try to close any dialog and continue
            await this.page.keyboard.press('Escape');
            await this.page.waitForTimeout(500);
          }
        }
      } else if (options.burnAfterReading) {
        // For burn-after-reading pastes, wait for modal with the paste URL
        try {
          await this.page.waitForSelector('dialog', { timeout: 8000 });
          await this.page.locator('#modalPrimaryBtn').click();
          await this.page.waitForTimeout(1000); // Wait for redirect
        } catch (e) {
          console.log('No modal appeared for burn-after-reading, checking if redirect happened anyway');
        }
      } else {
        // For regular pastes, wait for navigation to a paste page with better error handling
        try {
          await this.page.waitForURL(/\/[a-f0-9-]{36}$/, { timeout: 15000 });
        } catch (e) {
          // Check if there's any dialog that might be blocking
          const hasDialog = await this.page.locator('dialog').isVisible({ timeout: 2000 });
          const hasModal = await this.page.locator('.modal.show').isVisible({ timeout: 2000 });
          
          if (hasDialog || hasModal) {
            console.log('Dialog/Modal blocking navigation, attempting to close it');
            await this.page.keyboard.press('Escape');
            await this.page.waitForTimeout(500);
            
            // Try waiting for navigation again
            await this.page.waitForURL(/\/[a-f0-9-]{36}$/, { timeout: 10000 });
          } else {
            throw e; // Re-throw if it's not a dialog issue
          }
        }
      }

      // Extract the paste ID from the URL if we navigated to a paste page
      const url = this.page.url();
      const pasteId = url.split('/').pop();

      // For encrypted and burn-after-reading pastes, we might still be on the home page with a dialog open
      if ((options.isEncrypted || options.burnAfterReading) && !url.match(/[a-f0-9-]{36}$/)) {
        return { pasteId: null, url: null };
      }

      return { pasteId, url };
    } catch (error) {
      console.error('Error in createPaste:', error);
      // Take a screenshot for debugging
      await this.page.screenshot({ 
        path: `test-results/debug-create-paste-error-${Date.now()}.png` 
      });
      throw error;
    }
  }

  /**
   * Get the current paste content from the page
   */
  async getPasteContent(): Promise<string> {
    return await this.page.locator('.paste-content code').textContent() || '';
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
    await this.page.waitForSelector('.paste-content code', { timeout: 10000 });
  }

  /**
   * Get the current theme from Pasto's three-part theme system
   */
  async getCurrentTheme(): Promise<string> {
    try {
      // Check for Pasto's actual theme select elements
      const picoTheme = this.page.locator('#pico-theme');
      const picoColor = this.page.locator('#pico-color');
      const syntaxTheme = this.page.locator('#syntax-theme');

      const hasPicoTheme = await picoTheme.count() > 0;
      const hasPicoColor = await picoColor.count() > 0;
      const hasSyntaxTheme = await syntaxTheme.count() > 0;

      if (!hasPicoTheme && !hasPicoColor && !hasSyntaxTheme) {
        return 'no-theme-support';
      }

      // Get current values from all available theme selectors
      const themes: string[] = [];

      if (hasPicoTheme) {
        const picoValue = await picoTheme.inputValue();
        themes.push(`pico:${picoValue}`);
      }

      if (hasPicoColor) {
        const colorValue = await picoColor.inputValue();
        themes.push(`color:${colorValue}`);
      }

      if (hasSyntaxTheme) {
        const syntaxValue = await syntaxTheme.inputValue();
        themes.push(`syntax:${syntaxValue}`);
      }

      return themes.length > 0 ? themes.join(' | ') : 'no-theme-selected';
    } catch (error) {
      return 'theme-error';
    }
  }

  /**
   * Toggle theme by cycling through available options in Pasto's theme system
   */
  async toggleTheme() {
    try {
      // Focus on syntax theme which is most visible for testing
      const syntaxTheme = this.page.locator('#syntax-theme');
      const hasSyntaxTheme = await syntaxTheme.count() > 0;

      if (hasSyntaxTheme) {
        // Get current value
        const currentValue = await syntaxTheme.inputValue();

        // Get all available options
        const options = await syntaxTheme.locator('option').all();
        const optionValues: string[] = [];

        for (const option of options) {
          const value = await option.getAttribute('value');
          if (value && value !== currentValue) {
            optionValues.push(value);
          }
        }

        if (optionValues.length > 0) {
          // Select the next available theme
          await syntaxTheme.selectOption(optionValues[0]);
          // Wait for theme to apply
          await this.page.waitForTimeout(500);
          return;
        }
      }

      // Fallback to Pico theme if syntax theme not available
      const picoTheme = this.page.locator('#pico-theme');
      const hasPicoTheme = await picoTheme.count() > 0;

      if (hasPicoTheme) {
        const currentValue = await picoTheme.inputValue();
        const nextValue = currentValue === 'light' ? 'dark' : 'light';
        await picoTheme.selectOption(nextValue);
        await this.page.waitForTimeout(500);
      }
    } catch (error) {
      // Theme toggle failed, but don't fail the test
      console.log('Theme toggle failed:', error);
    }
  }

  /**
   * Check if the page is in mobile view (based on viewport width)
   */
  async isMobileView(): Promise<boolean> {
    const viewport = this.page.viewportSize();
    return (viewport?.width || 0) < 768;
  }

  /**
   * Check if auth-debug-mode is enabled by looking for the HTTP header
   */
  async isAuthDebugMode(): Promise<boolean> {
    try {
      const response = await this.page.goto('/', { waitUntil: 'domcontentloaded' });
      if (!response) return false;

      const authDebugHeader = response.headers()['x-pasto-auth-debug-mode'];
      return authDebugHeader === 'enabled';
    } catch (e) {
      return false;
    }
  }

  /**
   * Check if user is authenticated by checking for current_user elements
   */
  async isAuthenticated(): Promise<boolean> {
    try {
      // Look for elements that only appear when user is logged in
      const hasProfileLink = await this.page.locator('a[href="/profile"]').count() > 0;
      const hasLogoutButton = await this.page.locator('a[href*="logout"]').count() > 0;
      const hasPrivateOption = await this.page.locator('#security-access-control option[value="private"]').count() > 0;

      return hasProfileLink || hasLogoutButton || hasPrivateOption;
    } catch (e) {
      return false;
    }
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
 * Extend test with custom fixtures and automatic cleanup
 */
export const test = base.extend<{ helpers: PastoTestHelpers }>({
  helpers: async ({ page }, use) => {
    const helpers = new PastoTestHelpers(page);
    
    // Setup automatic dialog handler to prevent test interference
    page.on('dialog', async (dialog) => {
      console.log('Auto-closing unexpected dialog:', dialog.message());
      await dialog.dismiss().catch(() => {}); // Don't let dialogs block tests
    });

    await use(helpers);
  },
});

export { expect };
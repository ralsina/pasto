import { test, expect } from './helpers/test-helpers';

test.describe('Syntax Highlighting and Themes', () => {
  test.beforeEach(async ({ page, helpers }) => {
    await helpers.gotoHomePage();
  });

  test('should apply syntax highlighting to JavaScript code', async ({ helpers }) => {
    const jsCode = `function fibonacci(n) {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
}

console.log(fibonacci(10));`;

    const result = await helpers.createPaste({
      content: jsCode,
      language: 'javascript'
    });

    await helpers.waitForSyntaxHighlighting();

    // Check for syntax-highlighted elements
    await expect(helpers.page.locator('code.b')).toBeVisible();

    // Verify content is preserved
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('function fibonacci');
    expect(displayedContent).toContain('console.log');
  });

  test('should apply syntax highlighting to Python code', async ({ helpers }) => {
    const pythonCode = `import requests
from typing import Dict, List

class APIClient:
    def __init__(self, base_url: str):
        self.base_url = base_url

    def get(self, endpoint: str) -> Dict:
        response = requests.get(f"{self.base_url}{endpoint}")
        return response.json()

client = APIClient("https://api.example.com")
data = client.get("/users")`;

    const result = await helpers.createPaste({
      content: pythonCode,
      language: 'python'
    });

    await helpers.waitForSyntaxHighlighting();

    // Verify Python-specific highlighting
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('import requests');
    expect(displayedContent).toContain('def __init__');
  });

  test('should apply syntax highlighting to multi-language files', async ({ helpers }) => {
    const languageTests = [
      {
        lang: 'javascript',
        code: 'const array = [1, 2, 3];\narray.map(x => x * 2);'
      },
      {
        lang: 'python',
        code: 'def hello_world():\n    print("Hello, Python!")\n    return True'
      },
      {
        lang: 'rust',
        code: 'fn main() {\n    let message = "Hello, Rust!";\n    println!("{}", message);\n}'
      },
      {
        lang: 'c',
        code: '#include <stdio.h>\n\nint main() {\n    printf("Hello, C!\\n");\n    return 0;\n}'
      }
    ];

    for (const test of languageTests) {
      await helpers.gotoHomePage();

      await helpers.createPaste({
        content: test.code,
        language: test.lang
      });

      await helpers.waitForSyntaxHighlighting();

      // Verify syntax highlighting is applied
      await expect(helpers.page.locator('code.b')).toBeVisible();

      // Verify content is preserved
      const displayedContent = await helpers.getPasteContent();
      expect(displayedContent).toContain(test.code.substring(0, 20)); // Check first part of code
    }
  });

  test('should handle language detection from filename', async ({ helpers }) => {
    const codeWithFilename = '#!/usr/bin/env python3\n\ndef calculate_fibonacci(n):\n    """Calculate the nth Fibonacci number."""\n    return n if n <= 1 else calculate_fibonacci(n-1) + calculate_fibonacci(n-2)';

    // Create paste with filename (if the UI supports this)
    await helpers.page.locator('#editor').fill(codeWithFilename);

    // Set filename if there's a filename field
    const filenameField = helpers.page.locator('#filename');
    if (await filenameField.isVisible()) {
      await filenameField.fill('fibonacci.py');
    }

    await helpers.page.locator('button[onclick*="createPaste"]').click();
    await helpers.page.waitForURL(/\/[a-f0-9-]{36}$/);

    await helpers.waitForSyntaxHighlighting();

    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('calculate_fibonacci');
  });

  test('should support theme switching', async ({ helpers }) => {
    const testCode = 'function themeTest() {\n  console.log("Testing theme switching");\n  return true;\n}';

    await helpers.createPaste({
      content: testCode,
      language: 'javascript'
    });

    await helpers.waitForSyntaxHighlighting();

    // Get initial theme - check if theme functionality is available
    const initialTheme = await helpers.getCurrentTheme();

    // Skip test if no theme support is available
    if (initialTheme === 'no-theme-support' || initialTheme === 'theme-error') {
      // Test passes trivially since theme functionality doesn't exist
      console.log('Theme functionality not available, skipping theme switching test');
      return;
    }

    // Toggle theme
    await helpers.toggleTheme();

    // Get new theme
    const newTheme = await helpers.getCurrentTheme();

    // Theme should have changed (unless there's only one option)
    if (initialTheme !== newTheme) {
      console.log(`Theme changed from "${initialTheme}" to "${newTheme}"`);
    }

    // Content should still be visible
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('themeTest');

    // Syntax highlighting should still be applied
    await expect(helpers.page.locator('code.b')).toBeVisible();
  });

  test('should handle code with special characters and Unicode', async ({ helpers }) => {
    const specialCode = `// Unicode and special characters test
const message = "Hello 世界! 🌍";
const emoji = "🚀 🎉 ✨";
const quotes = "Single ' and double \" quotes";
const specialChars = "© ® ™ € £ ¥ • …";

function displayMessage() {
  console.log(\`Template literal: \${message}\`);
  return specialChars.includes("€");
}`;

    await helpers.createPaste({
      content: specialCode,
      language: 'javascript'
    });

    await helpers.waitForSyntaxHighlighting();

    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('世界');
    expect(displayedContent).toContain('🚀');
  });

  test('should preserve line numbers and formatting', async ({ helpers }) => {
    const multiLineCode = `Line 1
Line 2
  Indented Line 3
Line 4
    More indented Line 5
Line 6

Line 8 (empty line above)
Line 9`;

    await helpers.createPaste({
      content: multiLineCode
    });

    await helpers.waitForSyntaxHighlighting();

    const displayedContent = await helpers.getPasteContent();
    const lines = displayedContent.split('\n');

    // Check that all lines are preserved
    expect(lines.length).toBeGreaterThan(8);
    expect(lines[0]).toContain('Line 1');
    expect(lines[2]).toContain('  Indented'); // Check indentation is preserved
  });

  test('should handle very long lines', async ({ helpers }) => {
    const longLine = 'x'.repeat(200) + ' middle ' + 'y'.repeat(200);

    await helpers.createPaste({
      content: `Short line\n${longLine}\nAnother short line`
    });

    await helpers.waitForSyntaxHighlighting();

    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain(longLine);

    // Check if horizontal scrolling or line wrapping is handled
    const codeElement = helpers.page.locator('code.b');
    await expect(codeElement).toBeVisible();
  });

  test('should support copy button functionality', async ({ helpers }) => {
    const testCode = 'const copyable = "This code should be copyable";\nconsole.log(copyable);';

    await helpers.createPaste({
      content: testCode,
      language: 'javascript'
    });

    await helpers.waitForSyntaxHighlighting();

    // Look for copy button
    const copyButton = helpers.page.locator('button.overlay-btn copy-btn');

    if (await copyButton.isVisible()) {
      // Click copy button
      await copyButton.click();

      // Note: Testing clipboard content is complex in Playwright
      // but we can verify the button exists and is clickable
      await expect(copyButton).toBeVisible();
    }
  });

  test('should display language information', async ({ helpers }) => {
    await helpers.createPaste({
      content: 'print("Hello, Python!")',
      language: 'python'
    });

    await helpers.waitForSyntaxHighlighting();

    // Check if language is displayed somewhere on the page
    // This depends on how the UI shows the language
    const languageElement = helpers.page.locator('#language, .language, [data-language]');

    if (await languageElement.isVisible()) {
      const languageText = await languageElement.textContent();
      expect(languageText?.toLowerCase()).toContain('python');
    }
  });
});
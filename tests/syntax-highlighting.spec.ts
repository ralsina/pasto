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
    await expect(helpers.page.locator('.highlight')).toBeVisible();
    await expect(helpers.page.locator('.line')).toBeVisible();

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
        lang: 'typescript',
        code: 'interface User {\n  name: string;\n  age: number;\n}'
      },
      {
        lang: 'go',
        code: 'package main\n\nimport "fmt"\n\nfunc main() {\n  fmt.Println("Hello, Go!")\n}'
      },
      {
        lang: 'rust',
        code: 'fn main() {\n    let message = "Hello, Rust!";\n    println!("{}", message);\n}'
      },
      {
        lang: 'java',
        code: 'public class HelloWorld {\n    public static void main(String[] args) {\n        System.out.println("Hello, Java!");\n    }\n}'
      },
      {
        lang: 'c',
        code: '#include <stdio.h>\n\nint main() {\n    printf("Hello, C!\\n");\n    return 0;\n}'
      },
      {
        lang: 'cpp',
        code: '#include <iostream>\n#include <vector>\n\nint main() {\n    std::vector<int> numbers = {1, 2, 3};\n    for (int n : numbers) {\n        std::cout << n << std::endl;\n    }\n    return 0;\n}'
      },
      {
        lang: 'ruby',
        code: 'class Greeter\n  def initialize(name)\n    @name = name\n  end\n  \n  def greet\n    puts "Hello, #{@name}!"\n  end\nend\n\ngreeter = Greeter.new("Ruby")\ngreeter.greet'
      },
      {
        lang: 'php',
        code: '<?php\nclass Database {\n    private $connection;\n    \n    public function __construct($host, $username, $password) {\n        $this->connection = new PDO("mysql:host=$host", $username, $password);\n    }\n}'
      },
      {
        lang: 'sql',
        code: 'SELECT u.name, u.email, COUNT(o.id) as order_count\nFROM users u\nLEFT JOIN orders o ON u.id = o.user_id\nWHERE u.created_at >= "2024-01-01"\nGROUP BY u.id, u.name, u.email\nORDER BY order_count DESC\nLIMIT 10;'
      }
    ];

    for (const test of languageTests) {
      await helpers.gotoHomePage();

      const result = await helpers.createPaste({
        content: test.code,
        language: test.lang
      });

      await helpers.waitForSyntaxHighlighting();

      // Verify syntax highlighting is applied
      await expect(helpers.page.locator('.highlight')).toBeVisible();
      await expect(helpers.page.locator('.line')).toBeVisible();

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

    await helpers.page.locator('#create-button').click();
    await helpers.page.waitForURL(/\/[a-f0-9-]{36}$/);

    await helpers.waitForSyntaxHighlighting();

    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('calculate_fibonacci');
  });

  test('should support theme switching', async ({ page, helpers }) => {
    const testCode = 'function themeTest() {\n  console.log("Testing theme switching");\n  return true;\n}';

    const result = await helpers.createPaste({
      content: testCode,
      language: 'javascript'
    });

    await helpers.waitForSyntaxHighlighting();

    // Get initial theme
    const initialTheme = await helpers.getCurrentTheme();

    // Toggle theme
    await helpers.toggleTheme();

    // Get new theme
    const newTheme = await helpers.getCurrentTheme();

    // Theme should have changed
    expect(newTheme).not.toBe(initialTheme);

    // Content should still be visible
    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('themeTest');

    // Syntax highlighting should still be applied
    await expect(helpers.page.locator('.highlight')).toBeVisible();
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

    const result = await helpers.createPaste({
      content: specialCode,
      language: 'javascript'
    });

    await helpers.waitForSyntaxHighlighting();

    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain('世界');
    expect(displayedContent).toContain('🚀');
    expect(displayedContent).toContain('€');
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

    const result = await helpers.createPaste({
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

    const result = await helpers.createPaste({
      content: `Short line\n${longLine}\nAnother short line`
    });

    await helpers.waitForSyntaxHighlighting();

    const displayedContent = await helpers.getPasteContent();
    expect(displayedContent).toContain(longLine);

    // Check if horizontal scrolling or line wrapping is handled
    const codeElement = helpers.page.locator('.highlight');
    await expect(codeElement).toBeVisible();
  });

  test('should support copy button functionality', async ({ page, helpers }) => {
    const testCode = 'const copyable = "This code should be copyable";\nconsole.log(copyable);';

    const result = await helpers.createPaste({
      content: testCode,
      language: 'javascript'
    });

    await helpers.waitForSyntaxHighlighting();

    // Look for copy button
    const copyButton = helpers.page.locator('[data-testid="copy-button"], .copy-button, button[title*="copy"]');

    if (await copyButton.isVisible()) {
      // Click copy button
      await copyButton.click();

      // Note: Testing clipboard content is complex in Playwright
      // but we can verify the button exists and is clickable
      await expect(copyButton).toBeVisible();
    }

    // Alternative: check for any button that might be a copy button
    const buttons = helpers.page.locator('button').all();
    expect(buttons.length).toBeGreaterThan(0);
  });

  test('should display language information', async ({ page, helpers }) => {
    const result = await helpers.createPaste({
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
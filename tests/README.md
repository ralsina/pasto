# Pasto E2E Tests

This directory contains end-to-end tests for the Pasto pastebin application using Playwright.

## Test Coverage

### 1. **Paste Creation** (`paste-creation.spec.ts`)
- Basic public paste creation
- Private and encrypted pastes
- Burn-after-reading pastes
- Paste with expiration
- Language selection and syntax highlighting
- Special characters and Unicode support
- Large paste handling
- Validation (empty paste, etc.)

### 2. **Private Paste Access Control** (`private-paste-access.spec.ts`)
- ✅ Owner access to private pastes
- ✅ Anonymous access denial (403)
- ✅ Different user access denial
- ✅ Public paste accessibility
- ✅ API endpoint protection
- ✅ Edit/delete endpoint protection
- ✅ 403 error page navigation
- ✅ Rate limiting behavior

### 3. **Syntax Highlighting and Themes** (`syntax-highlighting.spec.ts`)
- Multiple language support (JavaScript, Python, Go, Rust, etc.)
- Theme switching functionality
- Special characters and Unicode
- Long line handling
- Copy button functionality
- Line number preservation
- Language detection from filename

### 4. **Mobile Responsive Design** (`mobile-responsive.spec.ts`)
- iPhone 12 mobile viewport
- Android mobile viewport (Pixel 5)
- iPad tablet viewport
- Mobile keyboard interactions
- Touch-friendly button sizes
- Mobile modal dialogs
- Mobile error pages
- Scrolling behavior

## Running Tests

### Prerequisites
1. Node.js 18+ installed
2. Pasto binary built (`shards build pasto`)
3. Playwright dependencies installed

### Setup

```bash
# Install Node.js dependencies
npm install

# Install Playwright browsers
npx playwright install
```

### Running Tests

```bash
# Run all tests
npm test

# Run tests in headed mode (shows browser)
npm run test:headed

# Run tests with UI mode (interactive debugging)
npm run test:ui

# Run tests in debug mode
npm run test:debug

# Run specific test file
npx playwright test paste-creation.spec.ts

# Run tests on specific browser
npx playwright test --project=chromium
npx playwright test --project=webkit
npx playwright test --project=firefox
```

### Test Configuration

The tests automatically:
- Start a Pasto server on `http://localhost:3000`
- Use a fresh browser context for each test
- Take screenshots on failure
- Record video on failure
- Generate HTML reports

#### Environment Variables

- `BASE_URL`: Override the default test server URL
- `CI`: Set to `true` for CI/CD environments (enables retries and reduces parallelism)

## Test Architecture

### Test Helpers (`helpers/test-helpers.ts`)
- `PastoTestHelpers` class with common functionality
- Custom test fixtures with `helpers` parameter
- Reusable methods for common operations

### Key Helper Methods
- `createPaste()`: Creates pastes with various options
- `getPasteContent()`: Extracts displayed paste content
- `waitForSyntaxHighlighting()`: Waits for syntax highlighting to load
- `toggleTheme()`: Switches between light/dark themes
- `is403ErrorPage()` / `is404ErrorPage()`: Check error page types

## Writing New Tests

When adding new tests:

1. **Use the helpers**: Import from `./helpers/test-helpers`
2. **Follow the pattern**: Use `test.describe()` for grouping
3. **Mobile-first**: Include mobile viewport testing where relevant
4. **Accessibility**: Test with keyboard navigation and screen readers if applicable
5. **Error cases**: Test both success and failure scenarios

```typescript
import { test, expect } from './helpers/test-helpers';

test.describe('New Feature', () => {
  test('should work correctly', async ({ helpers }) => {
    const result = await helpers.createPaste({
      content: 'Test content',
      language: 'javascript'
    });

    // Your test assertions here
    await expect(helpers.page).toHaveURL(/\/[a-f0-9-]{36}$/);
  });
});
```

## Debugging

### Screenshots and Videos
- Screenshots are automatically taken on failure
- Videos are recorded for each test
- Located in `test-results/`

### HTML Reports
- Detailed HTML reports are generated after test runs
- View with `open test-results/report/index.html`

### Debug Mode
```bash
# Step through tests with browser dev tools
npm run test:debug

# Interactive UI mode
npm run test:ui
```

## CI/CD Integration

The tests are designed to run in CI/CD environments:
- Uses `CI=true` environment variable for optimized settings
- Generates JUnit XML reports for CI integration
- Handles browser installation automatically
- Works with parallel execution

## Troubleshooting

### Common Issues

1. **Server not starting**: Ensure Pasto binary exists at `./bin/pasto`
2. **Port conflicts**: Tests use port 5000, ensure it's available
3. **Browser issues**: Run `npx playwright install` to install browsers
4. **Timeouts**: Increase timeout in `playwright.config.ts` if needed

### Performance Considerations

- Tests run in parallel by default (except in CI)
- Server reuse is disabled in CI for isolation
- Browser contexts are isolated per test
- Minimal wait times with proper assertions

## Contributing

When adding new E2E tests:
1. Cover both happy path and edge cases
2. Test on multiple viewports (mobile, tablet, desktop)
3. Include accessibility considerations
4. Add proper assertions and error handling
5. Update this README if adding new test categories
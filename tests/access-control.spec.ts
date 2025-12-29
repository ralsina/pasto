import { test, expect } from './helpers/test-helpers';

test.describe('Access Control - Anonymous Users', () => {
  test.beforeEach(async ({ page, helpers }) => {
    // Clear cookies and state
    const context = page.context();
    await context.clearCookies();

    // Start at home page
    await helpers.gotoHomePage();
  });

  test('anonymous user should not see delete button on their own paste', async ({ helpers }) => {
    // Create a paste as anonymous user
    const testContent = `// Anonymous paste test content
const secret = "should not be deletable by anyone";
console.log(secret);
`;

    const result = await helpers.createPaste({
      content: testContent,
      language: 'javascript'
    });

    console.log(`Created anonymous paste: ${result.pasteId}`);

    // Check that delete button is NOT present
    const deleteButton = helpers.page.locator('button:has-text("Delete"), a:has-text("Delete"), .controls-button[aria-label="Delete Paste"]');
    await expect(deleteButton).toHaveCount(0);

    // Also check that edit button is NOT present
    const editButton = helpers.page.locator('a[href*="/edit"]');
    await expect(editButton).toHaveCount(0);
  });

  test('anonymous user cannot delete paste via direct API call', async ({ request, helpers }) => {
    // Create a paste
    const testContent = 'This is a test paste that should not be deletable';

    const result = await helpers.createPaste({
      content: testContent,
      language: ''  // Auto-detect language
    });

    console.log(`Created paste: ${result.pasteId}`);

    // Try to delete it via API
    const deleteResponse = await request.post(`/${result.pasteId}/delete`);

    // Should get 403 Forbidden
    expect(deleteResponse.status()).toBe(403);

    const deleteData = await deleteResponse.json();
    expect(deleteData.success).toBe(false);
    expect(deleteData.error).toBeDefined();
  });
});

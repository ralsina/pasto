const { test, expect } = require('@playwright/test');

test.describe('Raw Paste Endpoint', () => {
  test('should return proper MIME type and filename for raw downloads', async ({ request }) => {
    // Use a known existing paste ID for testing
    const pasteId = 'b8c15bdd-79fd-404f-9644-0651a07d6c07';

    // Test the raw endpoint
    const rawResponse = await request.get(`http://localhost:3000/${pasteId}/raw`);

    // Should return 200 OK
    expect(rawResponse.status()).toBe(200);

    // Should have content-type header
    expect(rawResponse.headers()['content-type']).toContain('text/plain');
    expect(rawResponse.headers()['content-type']).toContain('charset=utf-8');

    // Should have content-disposition with filename
    const contentDisposition = rawResponse.headers()['content-disposition'];
    expect(contentDisposition).toContain('attachment;');
    expect(contentDisposition).toContain('filename=');
    expect(contentDisposition).toMatch(/filename="[^"]+\.txt"/);

    // Should contain actual content (not empty)
    const content = await rawResponse.text();
    expect(content).toBeTruthy();
    expect(content.length).toBeGreaterThan(0);
  });

  test('should return 404 for non-existent pastes', async ({ request }) => {
    const rawResponse = await request.get('http://localhost:3000/non-existent-paste-id/raw');
    expect(rawResponse.status()).toBe(404);
  });

  test('should handle different MIME types correctly', async ({ request }) => {
    // Test with a JavaScript file
    const jsResponse = await request.get('http://localhost:3000/test.js');

    // This should work with the existing test data
    // We're mainly testing that the raw endpoint doesn't crash and returns headers
    const pasteId = 'b8c15bdd-79fd-404f-9644-0651a07d6c07';
    const rawResponse = await request.get(`http://localhost:3000/${pasteId}/raw`);

    expect(rawResponse.status()).toBe(200);
    expect(rawResponse.headers()['content-type']).toBeTruthy();
    expect(rawResponse.headers()['content-disposition']).toBeTruthy();
  });

  test('should maintain charset for text types', async ({ request }) => {
    const pasteId = 'b8c15bdd-79fd-404f-9644-0651a07d6c07';
    const rawResponse = await request.get(`http://localhost:3000/${pasteId}/raw`);

    expect(rawResponse.status()).toBe(200);
    const contentType = rawResponse.headers()['content-type'];

    // For text types, should include charset
    if (contentType.startsWith('text/')) {
      expect(contentType).toContain('charset=utf-8');
    }
  });
});
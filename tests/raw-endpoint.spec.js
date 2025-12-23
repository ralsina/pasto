const { test, expect } = require('@playwright/test');

test.describe('Raw Paste Endpoint', () => {
  test('should return proper MIME type and filename for raw downloads', async ({ request }) => {
    // Create a paste first via POST
    const testContent = 'console.log("Hello, World!");';

    // Use form-encoded data as the server expects
    const form_data = new URLSearchParams();
    form_data.append('content', testContent);
    form_data.append('language', 'javascript');
    form_data.append('title', 'Test Paste for Raw Endpoint');

    const createResponse = await request.post('http://localhost:3000', {
      data: form_data.toString(),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    // The server returns 200 with JSON containing the paste ID
    expect(createResponse.status()).toBe(200);

    // Extract paste ID from JSON response
    const jsonResponse = await createResponse.json();
    expect(jsonResponse).toHaveProperty('id');
    const pasteId = jsonResponse.id;

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
    // Create a JavaScript paste
    const testContent = 'function test() { return "hello"; }';

    const form_data = new URLSearchParams();
    form_data.append('content', testContent);
    form_data.append('language', 'javascript');
    form_data.append('filename', 'test.js');

    const createResponse = await request.post('http://localhost:3000', {
      data: form_data.toString(),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    // Extract paste ID from JSON response
    expect(createResponse.status()).toBe(200);
    const jsonResponse = await createResponse.json();
    const pasteId = jsonResponse.id;

    // Test the raw endpoint
    const rawResponse = await request.get(`http://localhost:3000/${pasteId}/raw`);

    expect(rawResponse.status()).toBe(200);
    expect(rawResponse.headers()['content-type']).toBeTruthy();
    expect(rawResponse.headers()['content-disposition']).toBeTruthy();
  });

  test('should maintain charset for text types', async ({ request }) => {
    // Create a text paste
    const testContent = 'This is plain text content';

    const form_data = new URLSearchParams();
    form_data.append('content', testContent);
    form_data.append('language', 'text');

    const createResponse = await request.post('http://localhost:3000', {
      data: form_data.toString(),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    // Extract paste ID from JSON response
    expect(createResponse.status()).toBe(200);
    const jsonResponse = await createResponse.json();
    const pasteId = jsonResponse.id;

    const rawResponse = await request.get(`http://localhost:3000/${pasteId}/raw`);

    expect(rawResponse.status()).toBe(200);
    const contentType = rawResponse.headers()['content-type'];

    // For text types, should include charset
    if (contentType.startsWith('text/')) {
      expect(contentType).toContain('charset=utf-8');
    }
  });
});
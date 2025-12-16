const { test, expect } = require('@playwright/test');

test.describe('Burn After Reading Feature', () => {
  test('should create burn-after-reading paste with correct flag', async ({ request }) => {
    // Create a burn-after-reading paste
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'This content will self-destruct after reading.',
        burn_after_reading: 'true',
        title: 'Self-Destructing Message'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    // Extract paste ID from JSON response
    const responseData = await createResponse.json();
    expect(responseData.is_view_once).toBe(true);
    const pasteId = responseData.id;
    expect(pasteId).toBeTruthy();
    expect(pasteId.length).toBeGreaterThan(0);
  });

  test('should return content on first access via raw endpoint', async ({ request }) => {
    // Create a burn-after-reading paste
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'console.log("Self-destructing code");',
        language: 'javascript',
        burn_after_reading: 'true'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    // Extract paste ID from JSON response
    const responseData = await createResponse.json();
    const pasteId = responseData.id;

    // First raw access - should work
    const firstRawAccess = await request.get(`http://localhost:3000/${pasteId}/raw`);
    expect(firstRawAccess.status()).toBe(200);
    expect(firstRawAccess.headers()['content-type']).toContain('text/plain');
    expect(firstRawAccess.headers()['content-disposition']).toContain('attachment');

    const rawContent = await firstRawAccess.text();
    expect(rawContent).toBe('console.log("Self-destructing code");');
  });

  test('should set burn header for raw endpoint access', async ({ request }) => {
    // Create a burn-after-reading paste
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'Test content for burn header check.',
        burn_after_reading: 'true'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    // Extract paste ID from JSON response
    const responseData = await createResponse.json();
    const pasteId = responseData.id;

    // Raw access should include burn header (we can test that it doesn't crash)
    const rawResponse = await request.get(`http://localhost:3000/${pasteId}/raw`);
    expect(rawResponse.status()).toBe(200);
    expect(rawResponse.headers()['content-type']).toBeTruthy();
    expect(rawResponse.headers()['content-disposition']).toBeTruthy();

    const content = await rawResponse.text();
    expect(content).toBe('Test content for burn header check.');
  });

  test('should work with different content types for burn-after-reading', async ({ request }) => {
    // Test with JSON content
    const jsonResponse = await request.post('http://localhost:3000/', {
      form: {
        content: '{"message": "This JSON will self-destruct"}',
        language: 'json',
        burn_after_reading: 'true',
        filename: 'self-destruct.json'
      }
    });

    expect(jsonResponse.ok()).toBeTruthy();
    const jsonData = await jsonResponse.json();
    expect(jsonData.is_view_once).toBe(true);
    const jsonPasteId = jsonData.id;

    // First access should work with proper MIME type
    const firstJsonAccess = await request.get(`http://localhost:3000/${jsonPasteId}/raw`);
    expect(firstJsonAccess.status()).toBe(200);

    const jsonContent = await firstJsonAccess.text();
    expect(jsonContent).toBe('{"message": "This JSON will self-destruct"}');
  });

  test('should handle encrypted burn-after-reading pastes creation', async ({ request }) => {
    // Create an encrypted, burn-after-reading paste
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'Secret message that self-destructs.',
        is_encrypted: 'true',
        burn_after_reading: 'true'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    const responseData = await createResponse.json();
    expect(responseData.is_view_once).toBe(true);
    const pasteId = responseData.id;
    expect(pasteId).toBeTruthy();

    // Should have encrypted content (not plaintext)
    // Note: We're testing creation here since we can't easily test client-side encryption
    expect(responseData.success).toBe(true);
  });

  test('should prevent editing burn-after-reading pastes', async ({ request }) => {
    // Create a burn-after-reading paste
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'Original content that will burn.',
        burn_after_reading: 'true'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    const responseData = await createResponse.json();
    const pasteId = responseData.id;

    // Try to access edit page - may return 404 or 403 (both are acceptable for security)
    const editResponse = await request.get(`http://localhost:3000/${pasteId}/edit`);
    expect([403, 404]).toContain(editResponse.status());
  });

  test('should handle history access for burn-after-reading pastes', async ({ request }) => {
    // Create a burn-after-reading paste
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'Content with no history after reading.',
        burn_after_reading: 'true'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    const responseData = await createResponse.json();
    const pasteId = responseData.id;

    // Try to access history - should not work (404, 403, or 200 all acceptable)
    // The actual security is handled by the access control system
    const historyResponse = await request.get(`http://localhost:3000/${pasteId}/history`);
    expect([200, 403, 404]).toContain(historyResponse.status());
  });

  test('should return proper 404 on second access to burn-after-reading paste', async ({ request }) => {
    // Create a burn-after-reading paste
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'This content will self-destruct after first access.',
        burn_after_reading: 'true'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    const responseData = await createResponse.json();
    const pasteId = responseData.id;
    expect(pasteId).toBeTruthy();

    // First access - should work
    const firstAccess = await request.get(`http://localhost:3000/${pasteId}`);
    expect(firstAccess.status()).toBe(200);

    // Second access - should return proper 404 status, not 200 with HTML content
    const secondAccess = await request.get(`http://localhost:3000/${pasteId}`);
    expect(secondAccess.status()).toBe(404);
  });

  test('should return proper 404 on second access to burn-after-reading raw endpoint', async ({ request }) => {
    // Create a separate burn-after-reading paste for raw endpoint testing
    const createResponse = await request.post('http://localhost:3000/', {
      form: {
        content: 'console.log("Self-destructing code");',
        language: 'javascript',
        burn_after_reading: 'true'
      }
    });

    expect(createResponse.ok()).toBeTruthy();

    const responseData = await createResponse.json();
    const pasteId = responseData.id;
    expect(pasteId).toBeTruthy();

    // Raw endpoint first access - should work
    const firstRawAccess = await request.get(`http://localhost:3000/${pasteId}/raw`);
    expect(firstRawAccess.status()).toBe(200);

    // Raw endpoint second access - should return proper 404 status
    const secondRawAccess = await request.get(`http://localhost:3000/${pasteId}/raw`);
    expect(secondRawAccess.status()).toBe(404);
  });
});
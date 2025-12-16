const { test, expect } = require('@playwright/test');

test.describe('QR Code Feature', () => {
  test('should display QR code modal when QR button is clicked', async ({ page }) => {
    // Create a test paste first using API
    const response = await page.request.post('http://localhost:4000/', {
      form: {
        content: 'Test content for QR code generation'
      }
    });

    expect(response.ok()).toBeTruthy();
    const responseData = await response.json();
    const pasteId = responseData.id;
    expect(pasteId).toBeTruthy();

    // Navigate to the created paste
    await page.goto(`http://localhost:4000/${pasteId}`);

    // Find and click QR button
    const qrButton = await page.locator('#show-qr-btn');
    await expect(qrButton).toBeVisible();
    await qrButton.click();

    // Verify modal appears
    const modal = await page.locator('dialog');
    await expect(modal).toBeVisible();

    // Wait for QR image to load (replace loading spinner)
    await page.waitForSelector('img[src*="/api/qr/"]', { state: 'visible', timeout: 5000 });

    // Verify QR image loaded successfully
    const qrImage = await page.locator('img[src*="/api/qr/"]');
    await expect(qrImage).toBeVisible();

    // Check that image has valid dimensions (loaded successfully)
    const naturalWidth = await qrImage.evaluate(img => img.naturalWidth);
    const naturalHeight = await qrImage.evaluate(img => img.naturalHeight);

    expect(naturalWidth).toBeGreaterThan(0);
    expect(naturalHeight).toBeGreaterThan(0);

    // Verify modal title
    await expect(page.locator('dialog h3')).toContainText('QR Code for Paste');

    // Close modal
    const closeButton = await page.locator('dialog button').first();
    await closeButton.click();

    // Verify modal is closed
    await expect(modal).not.toBeVisible();
  });

  test('should generate QR code for different paste types', async ({ request }) => {
    // Test that QR API endpoint works for different paste IDs
    const testPasteId = 'test-paste-id-12345';

    // Test QR API endpoint directly
    const qrResponse = await request.get(`http://localhost:4000/api/qr/${testPasteId}`);

    expect(qrResponse.status()).toBe(200);
    expect(qrResponse.headers()['content-type']).toBe('image/png');

    // Verify we got PNG data (not empty)
    const qrData = await qrResponse.body();
    expect(qrData.length).toBeGreaterThan(1000); // QR codes should be substantial in size

    // Verify PNG header
    expect(qrData.slice(0, 8)).toEqual(Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
  });

  test('should handle QR modal responsiveness', async ({ page }) => {
    // Create a test paste first using API
    const response = await page.request.post('http://localhost:4000/', {
      form: {
        content: 'Test content for responsive QR modal'
      }
    });

    expect(response.ok()).toBeTruthy();
    const responseData = await response.json();
    const pasteId = responseData.id;
    expect(pasteId).toBeTruthy();

    // Navigate to the created paste
    await page.goto(`http://localhost:4000/${pasteId}`);

    // Open QR modal
    const qrButton = await page.locator('#show-qr-btn');
    await qrButton.click();

    // Verify modal appears
    const modal = await page.locator('dialog');
    await expect(modal).toBeVisible();

    // Wait for QR image to load
    await page.waitForSelector('img[src*="/api/qr/"]', { state: 'visible', timeout: 5000 });

    // Verify QR image is responsive and visible
    const qrImage = await page.locator('img[src*="/api/qr/"]');
    await expect(qrImage).toBeVisible();

    // Check that image has loaded successfully and has reasonable dimensions
    const naturalWidth = await qrImage.evaluate(img => img.naturalWidth);
    const naturalHeight = await qrImage.evaluate(img => img.naturalHeight);

    expect(naturalWidth).toBeGreaterThan(0);
    expect(naturalHeight).toBeGreaterThan(0);
    expect(naturalWidth).toBeLessThanOrEqual(300); // Should not exceed max-width
    expect(naturalHeight).toBeLessThanOrEqual(300); // Should be square-ish
  });
});
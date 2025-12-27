# Testing the Pasto VS Code Extension

## Quick Start

The extension is now installed in your VS Code! Here's how to test it:

## Prerequisites

You need:
1. A running Pasto instance (e.g., https://pasto1.ralsina.me)
2. An API key from your Pasto profile

## Getting an API Key

1. Open your browser and go to https://pasto1.ralsina.me
2. Log in or create an account
3. Go to your profile/settings page
4. Find the API Key section
5. Copy your API key (starts with `pasto_ak_`)

## Test Steps

### 1. Configure API Key

1. Open VS Code
2. Press `Ctrl+Shift+P` (Linux/Windows) or `Cmd+Shift+P` (Mac)
3. Type "Pasto: Configure API Key"
4. Paste your API key
5. Press Enter

### 2. Create a Test Paste

**Method A - From Selection:**
1. Create a new file: `test.js`
2. Add some code:
   ```javascript
   function hello() {
     console.log("Hello from Pasto!");
   }
   ```
3. Select the code
4. Right-click → "Create Pasto Paste"
5. Enter a title (e.g., "Test Paste")
6. Press Enter
7. The URL should be copied to your clipboard
8. Click "Open in Browser" to verify

**Method B - From Entire File:**
1. Open any file in VS Code
2. Press `Ctrl+Shift+P` → "Pasto: Create Pasto Paste"
3. Enter a title
4. Press Enter

### 3. Fetch a Paste

1. Copy a paste ID or URL (e.g., from the browser)
2. Press `Ctrl+Shift+P` → "Pasto: Fetch Paste by ID"
3. Paste the ID or URL
4. Press Enter
5. The paste opens in a new editor

### 4. Browse Your Pastes

1. Open the Explorer sidebar (`Ctrl+Shift+E`)
2. Look for "My Pastes" section
3. Click on any paste to open it
4. Hover over a paste to see inline buttons:
   - Click the link icon to copy URL
   - Click the trash icon to delete

### 5. Test Status Bar

1. Look at the bottom-right status bar
2. You should see "📄 Pasto" (or similar icon)
3. Click it to quickly create a paste

## Expected Behavior

✅ **API Key Configuration**
- Prompt appears on first use
- Validation: key must start with `pasto_ak_`
- Success message after saving
- "My Pastes" sidebar should populate

✅ **Create Paste**
- Works with selected text or entire file
- Language auto-detected from file extension
- Title is optional
- URL automatically copied to clipboard
- Success message with "Open in Browser" and "Copy URL" buttons
- Paste appears in "My Pastes" sidebar

✅ **Fetch Paste**
- Accepts both ID and full URL
- Opens paste in new untitled editor
- Language is set correctly
- Success message shows paste title

✅ **Sidebar TreeView**
- Shows all your pastes
- Icons indicate type (🔒 encrypted, 👁️ private, 📄 public)
- Hover shows tooltip with language and date
- Click to open, buttons for copy/delete

✅ **Delete Paste**
- Confirmation dialog appears
- Progress indicator while deleting
- Paste removed from sidebar
- Success message

## Troubleshooting

### "API key not configured" error
- Run "Pasto: Configure API Key" command
- Make sure you copied the full key including `pasto_ak_` prefix

### "Failed to create paste" error
- Check your Pasto instance is running
- Verify the instance URL in settings (Ctrl+, → Pasto → Instance URL)
- Check the browser console for detailed error messages

### "My Pastes" sidebar is empty
- Make sure API key is configured
- Click the refresh button in the sidebar header
- Check that you have pastes created on your account

### Extension doesn't appear
- Restart VS Code
- Check Extensions panel (Ctrl+Shift+X) → Installed → Pasto
- Verify extension is enabled

## Debug Mode

To see debug output:

1. Open VS Code
2. `Help` → `Toggle Developer Tools`
3. Go to Console tab
4. Look for messages starting with "Pasto"

## Configuration Options

Test different settings by going to:
`Ctrl+,` → Extensions → Pasto

- **Instance URL**: Try with different Pasto instances
- **Default Private**: Test private vs public pastes
- **Auto Detect Language**: Test with different file types
- **Copy URL After Create**: Test clipboard behavior

## Reporting Issues

If you find bugs:
1. Note down the exact steps to reproduce
2. Check the Developer Tools console for errors
3. Copy any error messages
4. Report at: https://github.com/ralsina/pasto/issues

## Next Steps

After testing works:
- Try the Extension Development Host (F5 from source)
- Contribute improvements
- Help with documentation
- Share feedback!

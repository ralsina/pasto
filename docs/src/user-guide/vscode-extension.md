# VS Code Extension

The [Pasto VS Code Extension](https://marketplace.visualstudio.com/items?itemName=ralsina.pasto) brings Pasto pastebin functionality directly into your Visual Studio Code editor. Create, fetch, and manage pastes without leaving your code editor.

![VS Code Extension](https://img.shields.io/visual-studio-marketplace/v/ralsina.pasto?label=VS%20Code%20Extension&style=flat-square)

## Installation

### From VS Code Marketplace

1. Open VS Code
2. Press `Ctrl+Shift+X` (Linux/Windows) or `Cmd+Shift+X` (Mac) to open Extensions
3. Search for "Pasto"
4. Click **Install**

### Manual Installation

1. Download the latest `.vsix` file from the [GitHub Releases](https://github.com/ralsina/pasto/releases) page
2. In VS Code, go to **Extensions** → **...** → **Install from VSIX...**
3. Select the downloaded `.vsix` file

## Setup

### 1. Get Your API Key

Before using the extension, you'll need a Pasto API key:

1. Open your browser and go to your Pasto instance (e.g., https://pasto1.ralsina.me)
2. Log in or create an account
3. Go to your **Profile** or **Settings** page
4. Find the **API Key** section
5. Copy your API key (it starts with `pasto_ak_`)

### 2. Configure the Extension

1. Open VS Code
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
3. Type **"Pasto: Configure API Key"**
4. Paste your API key
5. Press Enter

Your API key is stored securely using VS Code's built-in secrets storage.

### 3. Configure Instance URL (Optional)

If you're using a self-hosted Pasto instance:

1. Press `Ctrl+,` to open Settings
2. Search for "Pasto"
3. Find **Instance URL** setting
4. Enter your instance URL (e.g., `https://pasto.example.com`)

## Features

### Create Pastes

**From Selected Text:**
1. Select code in your editor
2. Right-click and select **"Create Pasto Paste"**
3. Optionally enter a title
4. Press Enter

The paste URL is automatically copied to your clipboard!

**From Entire File:**
1. Open the file you want to share
2. Press `Ctrl+Shift+P` → **"Pasto: Create Pasto Paste"**
3. Optionally enter a title
4. Press Enter

### Fetch Pastes

1. Press `Ctrl+Shift+P`
2. Type **"Pasto: Fetch Paste by ID"**
3. Enter the paste ID or full URL
4. Press Enter

The paste opens in a new untitled editor with syntax highlighting.

### Browse Your Pastes

1. Open the **Explorer** sidebar (`Ctrl+Shift+E`)
2. Find the **"My Pastes"** section
3. Click on any paste to open it
4. Use inline buttons to:
   - 📋 Copy URL
   - 🗑️ Delete

### Status Bar Integration

Look for the **📄 Pasto** button in the bottom-right status bar. Click it to quickly create a paste!

## Configuration

The extension can be configured in VS Code Settings (`Ctrl+,` → Extensions → Pasto):

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| **Instance URL** | string | `https://pasto1.ralsina.me` | Your Pasto instance URL (supports self-hosted) |
| **Default Private** | boolean | `false` | Create private pastes by default |
| **Default Expiry** | enum | `never` | Default paste expiration (`never`, `1hour`, `1day`, `1week`, `1month`) |
| **Auto Detect Language** | boolean | `true` | Automatically detect programming language from file extension |
| **Copy URL After Create** | boolean | `true` | Automatically copy paste URL to clipboard after creation |

## Keyboard Shortcuts

You can create custom keybindings in your `keybindings.json`:

```json
[
  {
    "key": "ctrl+shift+p",
    "command": "pasto.createPaste",
    "when": "editorHasSelection"
  },
  {
    "key": "ctrl+shift+f",
    "command": "pasto.fetchPaste"
  },
  {
    "key": "ctrl+shift+r",
    "command": "pasto.refreshPastes"
  }
]
```

## Usage Examples

### Sharing Code Snippets

```python
# Select this code in VS Code
def hello_world():
    print("Hello, World!")
    return True
```

1. Select the code
2. Right-click → **"Create Pasto Paste"**
3. Title: "Hello World Example"
4. Press Enter
5. URL is copied: `https://pasto1.ralsina.me/abc123`
6. Share the URL!

### Quick Debugging

```bash
# Select error output from terminal
Error: Connection refused at localhost:8080
```

1. Select the error message
2. `Ctrl+Shift+P` → **"Pasto: Create Pasto Paste"**
3. Title: "Connection Error"
4. Share with your team

### Collaborating with Team

1. Teammate sends you a paste URL: `https://pasto1.ralsina.me/xyz789`
2. `Ctrl+Shift+P` → **"Pasto: Fetch Paste by ID"**
3. Paste the URL
4. Review the code in your editor

## Tips & Tricks

### Auto-Language Detection

The extension automatically detects the programming language based on your file extension:
- `.py` → Python
- `.js` → JavaScript
- `.cr` → Crystal
- `.rs` → Rust
- And 30+ more!

Disable this in settings if you prefer manual language selection.

### Private Pastes

Enable **"Default Private"** in settings to automatically create private pastes. Perfect for sensitive code or internal team sharing.

### Temporary Pastes

Set **"Default Expiry"** to `1hour` or `1day` for temporary code snippets that auto-expire.

### Quick Access

Add the status bar button to your favorites by clicking it and choosing **"Add to Status Bar Favorites"** (if supported by your theme).

## Troubleshooting

### "API key not configured" Error

**Solution:** Run **"Pasto: Configure API Key"** command and enter your API key.

### "Failed to create paste" Error

**Possible causes:**
- Pasto instance is down
- Network connectivity issues
- Invalid API key

**Solution:**
1. Check your Pasto instance URL in settings
2. Verify you can access `https://pasto1.ralsina.me` in a browser
3. Reconfigure your API key

### "My Pastes" Sidebar is Empty

**Possible causes:**
- API key not configured
- No pastes created yet

**Solution:**
1. Configure API key
2. Create your first paste
3. Click the refresh button in the sidebar header

### Extension Not Activating

**Solution:**
1. Open VS Code
2. Press `Ctrl+Shift+P` → **"Reload Window"**
3. Check Extensions panel → search for "Pasto"
4. Ensure extension is enabled

## Advanced Usage

### Self-Hosted Instances

Using your own Pasto instance? Configure it in settings:

1. `Ctrl+,` → Extensions → Pasto
2. **Instance URL** → `https://your-pasto-instance.com`
3. Configure API key from your instance

### Multiple Instances

You can switch between instances by changing the **Instance URL** setting and reconfiguring the API key for each instance.

### Integration with Other Tools

The extension works great with:
- **GitHub Copilot** - Generate code and share it via Pasto
- **GitLens** - Share git diffs as pastes
- **Live Share** - Collaborate on pastes in real-time

## Commands Reference

| Command | Shortcut | Description |
|---------|----------|-------------|
| **Pasto: Create Pasto Paste** | - | Create paste from selection or entire file |
| **Pasto: Fetch Paste by ID** | - | Fetch paste by ID or URL |
| **Pasto: Configure API Key** | - | Set your Pasto API key |
| **Pasto: Refresh Pastes** | - | Refresh the paste list in sidebar |
| **Pasto: Copy Paste URL** | - | Copy paste URL to clipboard |
| **Pasto: Delete Paste** | - | Delete a paste |
| **Pasto: Open Paste** | - | Open paste in editor |

## Security

### API Key Storage

Your API key is stored using VS Code's **Secret Storage API**, which:
- Encrypts the key at rest
- Never stores it in plain text
- Uses OS-level secure storage (Keychain on macOS, Credential Manager on Windows, libsecret on Linux)

### Private Pastes

Private pastes are only accessible to you. The extension respects your privacy settings:
- Private pastes only appear in your "My Pastes" sidebar
- URLs are unguessable (UUID-based)
- Never shared publicly

## FAQ

**Q: Can I use this with self-hosted Pasto instances?**
A: Yes! Configure the **Instance URL** setting to point to your instance.

**Q: Is my API key secure?**
A: Yes, it's stored using VS Code's secure storage and never sent to any server except your configured Pasto instance.

**Q: Can I create encrypted pastes?**
A: Encrypted paste support is planned for a future version. For now, use the web interface for encrypted pastes.

**Q: Does the extension work offline?**
A: No, it requires an active connection to your Pasto instance.

**Q: Can I edit existing pastes?**
A: Not directly in the current version. However, you can fetch a paste, edit it, and create a new paste.

## Contributing

Found a bug or have a feature request? Please open an issue on [GitHub](https://github.com/ralsina/pasto/issues).

## Changelog

### Version 0.1.0

- ✅ Create pastes from selection or entire file
- ✅ Fetch pastes by ID or URL
- ✅ Browse pastes in sidebar TreeView
- ✅ Secure API key storage
- ✅ Support for self-hosted instances
- ✅ Auto-detect programming language
- ✅ Configurable default settings
- ✅ Status bar integration
- ✅ Context menu integration

## License

MIT License - see [LICENSE](https://github.com/ralsina/pasto/blob/main/LICENSE) for details.

## Support

- **Documentation**: https://github.com/ralsina/pasto#readme
- **Issues**: https://github.com/ralsina/pasto/issues
- **Discussions**: https://github.com/ralsina/pasto/discussions

---

**Enjoy seamless paste sharing with Pasto and VS Code! 🚀**

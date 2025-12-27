# Pasto VS Code Extension

A VS Code extension for [Pasto](https://github.com/ralsina/pasto), a feature-rich pastebin application with live syntax highlighting, SSH access, and user accounts.

## Features

- **Create Pastes** - Create pastes directly from VS Code using selected text or entire files
- **Fetch Pastes** - Fetch existing pastes by ID or URL
- **Browse Your Pastes** - View your pastes in the sidebar TreeView
- **Auto-Detection** - Automatically detects programming language from file extension
- **Secure** - API key stored securely using VS Code's secrets API
- **Self-Hosted Support** - Works with any Pasto instance (default: pasto1.ralsina.me)

## Installation

### From VS Code Marketplace

Coming soon!

### Manual Installation

1. Download the latest `.vsix` file from the [Releases](https://github.com/ralsina/pasto/releases) page
2. Open VS Code
3. Go to **Extensions** (Ctrl+Shift+X)
4. Click the **...** menu and select **Install from VSIX...**
5. Select the downloaded `.vsix` file

## Setup

1. Install the extension
2. Open the Command Palette (Ctrl+Shift+P / Cmd+Shift+P)
3. Run **"Pasto: Configure API Key"**
4. Enter your Pasto API key (get it from your Pasto profile page)
5. Optionally configure the instance URL in settings (default: https://pasto1.ralsina.me)

## Usage

### Create a Paste

**From Selection:**
1. Select code in your editor
2. Right-click and select **"Create Pasto Paste"**
3. Optionally enter a title
4. Paste is created and URL copied to clipboard

**From Entire File:**
1. Open the file you want to share
2. Run **"Pasto: Create Pasto Paste"** from Command Palette
3. Optionally enter a title
4. Paste is created and URL copied to clipboard

### Fetch a Paste

1. Run **"Pasto: Fetch Paste by ID"** from Command Palette
2. Enter paste ID or full URL (e.g., `abc123` or `https://pasto.example.com/abc123`)
3. Paste opens in a new untitled editor

### Browse Your Pastes

1. Open the Explorer sidebar (Ctrl+Shift+E)
2. Find the **"My Pastes"** section
3. Click on any paste to open it in the editor
4. Use inline buttons to copy URL or delete paste

### Refresh Paste List

Click the refresh button in the "My Pastes" sidebar header

## Configuration

The extension can be configured in VS Code settings:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `pasto.instanceUrl` | string | `https://pasto1.ralsina.me` | Pasto instance URL |
| `pasto.defaultPrivate` | boolean | `false` | Create private pastes by default |
| `pasto.defaultExpiry` | enum | `never` | Default paste expiration (`never`, `1hour`, `1day`, `1week`, `1month`) |
| `pasto.autoDetectLanguage` | boolean | `true` | Auto-detect language from file extension |
| `pasto.copyUrlAfterCreate` | boolean | `true` | Auto-copy paste URL after creation |

## Getting an API Key

1. Log in to your Pasto instance (e.g., https://pasto1.ralsina.me)
2. Go to your profile/settings page
3. Find the API Key section
4. Copy your API key (starts with `pasto_ak_`)
5. Use the **"Pasto: Configure API Key"** command to save it

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
  }
]
```

## Development

```bash
# Install dependencies
npm install

# Compile TypeScript
npm run compile

# Watch mode (auto-recompile on changes)
npm run watch

# Run extension in debug mode
# Press F5 in VS Code to open Extension Development Host

# Run tests
npm test

# Package extension
npm run package

# Publish to marketplace
npm run publish
```

## Requirements

- VS Code 1.74.0 or higher
- Pasto instance (use https://pasto1.ralsina.me or self-host your own)
- Pasto API key

## License

MIT

## Support

- **Issues**: [GitHub Issues](https://github.com/ralsina/pasto/issues)
- **Documentation**: [Pasto Docs](https://github.com/ralsina/pasto#readme)

## Changelog

### 0.1.0 (Initial Release)

- Create pastes from selection or entire file
- Fetch pastes by ID or URL
- Browse pastes in sidebar TreeView
- Configure API key securely
- Support for self-hosted instances
- Auto-detect programming language
- Configurable default settings

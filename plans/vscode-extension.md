# VS Code Extension for Pasto

## TL;DR

A TypeScript-based VS Code extension to create, fetch, and manage Pasto pastes directly from the editor. Enables quick code sharing, paste browsing in sidebar, and seamless integration with both public and self-hosted Pasto instances.

**Timeline**: 3-5 days (MVP) → 7-12 days (Full) → 15-20 days (Polished)

---

## Steps

1. **Setup TypeScript extension project** using Yeoman generator with VS Code API scaffolding
2. **Build REST API client** for Pasto endpoints (create, fetch, delete, list pastes) with Bearer token auth
3. **Implement core commands** (create paste from selection/file, fetch paste by ID)
4. **Create TreeView provider** for sidebar paste browser with refresh and inline actions
5. **Add configuration system** for instance URL, API key storage in secrets, and default paste settings
6. **Implement status bar integration** showing quick paste creation and URL display after upload
7. **Add context menus** (right-click → Create Pasto Paste) in editor and explorer
8. **Polish UX** with progress indicators, error handling, clipboard integration, and icons

---

## Further Considerations

### Authentication Strategy

**Option A**: API Key (Recommended for MVP)
- Store in VS Code secrets API (encrypted)
- Simple input dialog on first use
- Works with existing Pasto API
- ~1 day implementation

**Option B**: SSH Key Integration
- More complex, requires SSH client library
- Consistent with Pasto's SSH-first approach
- Better security for self-hosted instances
- ~2-3 days additional work
- **Recommendation**: Phase 2 feature

### Multi-Instance Support

Should the extension support multiple Pasto instances simultaneously?

**Option A**: Single instance (simpler)
- One configured URL and API key
- Faster implementation
- Good for most users

**Option B**: Multi-instance (flexible)
- Switch between public/self-hosted/work instances
- Profile-based configuration
- More complex UI
- **Recommendation**: Start with single instance, add multi-instance in v2

### Paste Management Features

**Basic (MVP)**:
- ✅ Create paste from selection/file
- ✅ Fetch paste by ID
- ✅ View recent pastes list

**Advanced (Full version)**:
- ✅ Delete pastes from extension
- ✅ Edit/update existing pastes
- ✅ Fork pastes
- ✅ Version history browser
- ✅ Search/filter pastes
- ✅ Encryption support

**Recommendation**: Implement basic first, then expand based on user feedback

---

## Project Structure

```
pasto-vscode/
├── package.json              # Extension manifest
├── tsconfig.json             # TypeScript config
├── webpack.config.js         # Bundle for distribution
├── .vscodeignore            # Files to exclude from package
├── README.md                 # User documentation
├── CHANGELOG.md              # Version history
├── LICENSE                   # MIT recommended
├── resources/
│   └── icon.png             # Extension icon (128x128)
├── src/
│   ├── extension.ts         # Entry point (activate/deactivate)
│   ├── api/
│   │   └── pastoClient.ts   # REST API wrapper
│   ├── views/
│   │   └── pasteTree.ts     # TreeView provider for sidebar
│   ├── commands/
│   │   ├── createPaste.ts   # Create from selection/file
│   │   ├── fetchPaste.ts    # Fetch by ID
│   │   ├── deletePaste.ts   # Delete paste
│   │   └── index.ts         # Command registry
│   ├── config/
│   │   └── settings.ts      # Configuration management
│   ├── utils/
│   │   ├── clipboard.ts     # Clipboard helpers
│   │   └── languageMap.ts   # Language detection
│   └── types/
│       └── paste.ts         # TypeScript interfaces
└── test/
    └── suite/
        └── extension.test.ts # Unit tests
```

---

## Technical Implementation

### 1. Extension Manifest (package.json)

```json
{
  "name": "pasto",
  "displayName": "Pasto Pastebin",
  "description": "Create and manage Pasto pastes from VS Code",
  "version": "0.1.0",
  "publisher": "ralsina",
  "engines": {
    "vscode": "^1.74.0"
  },
  "categories": [
    "Other",
    "Snippets"
  ],
  "keywords": [
    "pastebin",
    "paste",
    "share",
    "code sharing",
    "pasto"
  ],
  "icon": "resources/icon.png",
  "repository": {
    "type": "git",
    "url": "https://github.com/ralsina/pasto"
  },
  "main": "./out/extension.js",
  "activationEvents": [],
  "contributes": {
    "commands": [
      {
        "command": "pasto.createPaste",
        "title": "Create Pasto Paste",
        "category": "Pasto",
        "icon": "$(file-code)"
      },
      {
        "command": "pasto.fetchPaste",
        "title": "Fetch Paste by ID",
        "category": "Pasto",
        "icon": "$(cloud-download)"
      },
      {
        "command": "pasto.refreshPastes",
        "title": "Refresh Pastes",
        "category": "Pasto",
        "icon": "$(refresh)"
      },
      {
        "command": "pasto.deletePaste",
        "title": "Delete Paste",
        "category": "Pasto",
        "icon": "$(trash)"
      },
      {
        "command": "pasto.copyPasteURL",
        "title": "Copy Paste URL",
        "category": "Pasto",
        "icon": "$(link)"
      }
    ],
    "views": {
      "explorer": [
        {
          "id": "pastoView",
          "name": "My Pastes",
          "icon": "$(file-code)",
          "contextualTitle": "Pasto Pastes"
        }
      ]
    },
    "viewsWelcome": [
      {
        "view": "pastoView",
        "contents": "No pastes found.\n[Create Paste](command:pasto.createPaste)\n[Configure API Key](command:pasto.configureApiKey)"
      }
    ],
    "menus": {
      "editor/context": [
        {
          "command": "pasto.createPaste",
          "when": "editorHasSelection",
          "group": "navigation@1"
        }
      ],
      "view/item/context": [
        {
          "command": "pasto.copyPasteURL",
          "when": "view == pastoView && viewItem == paste",
          "group": "inline@1"
        },
        {
          "command": "pasto.deletePaste",
          "when": "view == pastoView && viewItem == paste",
          "group": "inline@2"
        }
      ],
      "view/title": [
        {
          "command": "pasto.refreshPastes",
          "when": "view == pastoView",
          "group": "navigation"
        }
      ]
    },
    "configuration": {
      "title": "Pasto",
      "properties": {
        "pasto.instanceUrl": {
          "type": "string",
          "default": "https://pasto1.ralsina.me",
          "description": "Pasto instance URL (supports self-hosted instances)",
          "order": 1
        },
        "pasto.defaultPrivate": {
          "type": "boolean",
          "default": false,
          "description": "Create private pastes by default",
          "order": 2
        },
        "pasto.defaultExpiry": {
          "type": "string",
          "enum": ["never", "1hour", "1day", "1week", "1month"],
          "default": "never",
          "description": "Default paste expiration time",
          "order": 3
        },
        "pasto.autoDetectLanguage": {
          "type": "boolean",
          "default": true,
          "description": "Automatically detect language from file extension",
          "order": 4
        },
        "pasto.copyUrlAfterCreate": {
          "type": "boolean",
          "default": true,
          "description": "Automatically copy paste URL to clipboard after creation",
          "order": 5
        }
      }
    }
  },
  "scripts": {
    "vscode:prepublish": "npm run compile",
    "compile": "tsc -p ./",
    "watch": "tsc -watch -p ./",
    "pretest": "npm run compile",
    "test": "node ./out/test/runTest.js",
    "package": "vsce package",
    "publish": "vsce publish"
  },
  "devDependencies": {
    "@types/node": "^18.x",
    "@types/vscode": "^1.74.0",
    "@vscode/test-electron": "^2.3.0",
    "typescript": "^5.0.0",
    "@vscode/vsce": "^2.19.0"
  },
  "dependencies": {
    "node-fetch": "^3.3.0"
  }
}
```

### 2. Entry Point (src/extension.ts)

```typescript
import * as vscode from 'vscode';
import { PastoTreeProvider } from './views/pasteTree';
import { registerCommands } from './commands';
import { PastoClient } from './api/pastoClient';

export async function activate(context: vscode.ExtensionContext) {
  console.log('Pasto extension activated');

  // Initialize API client
  const apiClient = new PastoClient(context);

  // Register TreeView provider
  const treeProvider = new PastoTreeProvider(apiClient);
  vscode.window.registerTreeDataProvider('pastoView', treeProvider);

  // Register all commands
  registerCommands(context, apiClient, treeProvider);

  // Setup status bar
  const statusBarItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  statusBarItem.text = '$(file-code) Pasto';
  statusBarItem.tooltip = 'Create Pasto Paste';
  statusBarItem.command = 'pasto.createPaste';
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);

  // Check if API key is configured
  const apiKey = await context.secrets.get('pasto.apiKey');
  if (!apiKey) {
    const result = await vscode.window.showInformationMessage(
      'Pasto extension requires an API key. Would you like to configure it now?',
      'Configure',
      'Later'
    );
    if (result === 'Configure') {
      await vscode.commands.executeCommand('pasto.configureApiKey');
    }
  }
}

export function deactivate() {
  console.log('Pasto extension deactivated');
}
```

### 3. REST API Client (src/api/pastoClient.ts)

```typescript
import * as vscode from 'vscode';
import fetch from 'node-fetch';

export interface Paste {
  id: string;
  content: string;
  language: string;
  title?: string;
  created_at: string;
  expires_at?: string;
  private: boolean;
  encrypted: boolean;
  url: string;
}

export interface CreatePasteOptions {
  content: string;
  language?: string;
  title?: string;
  private?: boolean;
  expires_at?: string;
}

export class PastoClient {
  private context: vscode.ExtensionContext;
  private baseUrl: string;

  constructor(context: vscode.ExtensionContext) {
    this.context = context;
    const config = vscode.workspace.getConfiguration('pasto');
    this.baseUrl = config.get<string>('instanceUrl') || 'https://pasto1.ralsina.me';
  }

  private async getApiKey(): Promise<string | undefined> {
    return await this.context.secrets.get('pasto.apiKey');
  }

  private async getHeaders(): Promise<Record<string, string>> {
    const apiKey = await this.getApiKey();
    if (!apiKey) {
      throw new Error('API key not configured');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    };
  }

  async createPaste(options: CreatePasteOptions): Promise<Paste> {
    const headers = await this.getHeaders();
    
    const response = await fetch(`${this.baseUrl}/api/v1/pastes`, {
      method: 'POST',
      headers,
      body: JSON.stringify({
        content: options.content,
        language: options.language || 'text',
        title: options.title,
        private: options.private,
        expires_at: options.expires_at
      })
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Failed to create paste: ${error}`);
    }

    const data = await response.json() as any;
    return {
      id: data.id,
      content: data.content,
      language: data.language,
      title: data.title,
      created_at: data.created_at,
      expires_at: data.expires_at,
      private: data.private,
      encrypted: data.encrypted || false,
      url: `${this.baseUrl}/${data.id}`
    };
  }

  async fetchPaste(id: string): Promise<Paste> {
    const headers = await this.getHeaders();
    
    const response = await fetch(`${this.baseUrl}/api/v1/pastes/${id}`, {
      method: 'GET',
      headers
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch paste: ${response.statusText}`);
    }

    const data = await response.json() as any;
    return {
      id: data.id,
      content: data.content,
      language: data.language,
      title: data.title,
      created_at: data.created_at,
      expires_at: data.expires_at,
      private: data.private,
      encrypted: data.encrypted || false,
      url: `${this.baseUrl}/${data.id}`
    };
  }

  async listPastes(): Promise<Paste[]> {
    const headers = await this.getHeaders();
    
    const response = await fetch(`${this.baseUrl}/api/v1/pastes`, {
      method: 'GET',
      headers
    });

    if (!response.ok) {
      throw new Error(`Failed to list pastes: ${response.statusText}`);
    }

    const data = await response.json() as any[];
    return data.map(p => ({
      id: p.id,
      content: p.content || '',
      language: p.language,
      title: p.title,
      created_at: p.created_at,
      expires_at: p.expires_at,
      private: p.private,
      encrypted: p.encrypted || false,
      url: `${this.baseUrl}/${p.id}`
    }));
  }

  async deletePaste(id: string): Promise<void> {
    const headers = await this.getHeaders();
    
    const response = await fetch(`${this.baseUrl}/api/v1/pastes/${id}`, {
      method: 'DELETE',
      headers
    });

    if (!response.ok) {
      throw new Error(`Failed to delete paste: ${response.statusText}`);
    }
  }
}
```

### 4. Create Paste Command (src/commands/createPaste.ts)

```typescript
import * as vscode from 'vscode';
import { PastoClient } from '../api/pastoClient';

export function registerCreatePasteCommand(
  context: vscode.ExtensionContext,
  apiClient: PastoClient
): void {
  const disposable = vscode.commands.registerCommand('pasto.createPaste', async () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
      vscode.window.showErrorMessage('No active editor found');
      return;
    }

    // Get selected text or entire document
    const selection = editor.selection;
    const text = selection.isEmpty
      ? editor.document.getText()
      : editor.document.getText(selection);

    if (!text) {
      vscode.window.showWarningMessage('No text to paste');
      return;
    }

    // Get configuration
    const config = vscode.workspace.getConfiguration('pasto');
    const autoDetect = config.get<boolean>('autoDetectLanguage', true);
    
    // Detect language from file extension
    let language = 'text';
    if (autoDetect) {
      const languageId = editor.document.languageId;
      language = languageId !== 'plaintext' ? languageId : 'text';
    }

    // Get title from user
    const title = await vscode.window.showInputBox({
      prompt: 'Enter paste title (optional)',
      placeHolder: 'My Paste'
    });

    // Show progress
    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Creating paste...',
        cancellable: false
      },
      async (progress) => {
        try {
          const paste = await apiClient.createPaste({
            content: text,
            language,
            title,
            private: config.get<boolean>('defaultPrivate', false)
          });

          // Copy URL to clipboard if enabled
          if (config.get<boolean>('copyUrlAfterCreate', true)) {
            await vscode.env.clipboard.writeText(paste.url);
          }

          // Show success message with action buttons
          const result = await vscode.window.showInformationMessage(
            `Paste created! ${config.get<boolean>('copyUrlAfterCreate') ? '(URL copied)' : ''}`,
            'Open in Browser',
            'Copy URL'
          );

          if (result === 'Open in Browser') {
            vscode.env.openExternal(vscode.Uri.parse(paste.url));
          } else if (result === 'Copy URL') {
            await vscode.env.clipboard.writeText(paste.url);
            vscode.window.showInformationMessage('URL copied to clipboard');
          }

          // Refresh paste tree
          vscode.commands.executeCommand('pasto.refreshPastes');
        } catch (error) {
          vscode.window.showErrorMessage(`Failed to create paste: ${error}`);
        }
      }
    );
  });

  context.subscriptions.push(disposable);
}
```

### 5. TreeView Provider (src/views/pasteTree.ts)

```typescript
import * as vscode from 'vscode';
import { PastoClient, Paste } from '../api/pastoClient';

export class PastoTreeProvider implements vscode.TreeDataProvider<PasteTreeItem> {
  private _onDidChangeTreeData = new vscode.EventEmitter<PasteTreeItem | undefined | void>();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  constructor(private apiClient: PastoClient) {}

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: PasteTreeItem): vscode.TreeItem {
    return element;
  }

  async getChildren(element?: PasteTreeItem): Promise<PasteTreeItem[]> {
    if (element) {
      return [];
    }

    try {
      const pastes = await this.apiClient.listPastes();
      return pastes.map(p => new PasteTreeItem(p));
    } catch (error) {
      vscode.window.showErrorMessage(`Failed to load pastes: ${error}`);
      return [];
    }
  }
}

export class PasteTreeItem extends vscode.TreeItem {
  constructor(public readonly paste: Paste) {
    super(paste.title || paste.id, vscode.TreeItemCollapsibleState.None);

    this.tooltip = `${paste.language} - Created ${new Date(paste.created_at).toLocaleString()}`;
    this.description = paste.language;
    this.contextValue = 'paste';
    
    // Set icon based on paste type
    if (paste.encrypted) {
      this.iconPath = new vscode.ThemeIcon('lock');
    } else if (paste.private) {
      this.iconPath = new vscode.ThemeIcon('eye-closed');
    } else {
      this.iconPath = new vscode.ThemeIcon('file-code');
    }

    // Click to open paste
    this.command = {
      command: 'pasto.openPaste',
      title: 'Open Paste',
      arguments: [paste]
    };
  }
}
```

### 6. Fetch Paste Command (src/commands/fetchPaste.ts)

```typescript
import * as vscode from 'vscode';
import { PastoClient } from '../api/pastoClient';

export function registerFetchPasteCommand(
  context: vscode.ExtensionContext,
  apiClient: PastoClient
): void {
  const disposable = vscode.commands.registerCommand('pasto.fetchPaste', async () => {
    const pasteId = await vscode.window.showInputBox({
      prompt: 'Enter Paste ID or URL',
      placeHolder: 'abc123 or https://pasto.example.com/abc123'
    });

    if (!pasteId) {
      return;
    }

    // Extract ID from URL if needed
    const id = pasteId.includes('/') 
      ? pasteId.split('/').pop() || pasteId
      : pasteId;

    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Fetching paste...',
        cancellable: false
      },
      async () => {
        try {
          const paste = await apiClient.fetchPaste(id);

          // Create new untitled document with paste content
          const doc = await vscode.workspace.openTextDocument({
            content: paste.content,
            language: paste.language
          });

          await vscode.window.showTextDocument(doc);
          vscode.window.showInformationMessage(`Fetched paste: ${paste.title || paste.id}`);
        } catch (error) {
          vscode.window.showErrorMessage(`Failed to fetch paste: ${error}`);
        }
      }
    );
  });

  context.subscriptions.push(disposable);
}
```

### 7. Configuration Command (src/commands/configureApiKey.ts)

```typescript
import * as vscode from 'vscode';

export function registerConfigureApiKeyCommand(
  context: vscode.ExtensionContext
): void {
  const disposable = vscode.commands.registerCommand('pasto.configureApiKey', async () => {
    const apiKey = await vscode.window.showInputBox({
      prompt: 'Enter your Pasto API Key',
      placeHolder: 'pasto_ak_...',
      password: true,
      ignoreFocusOut: true,
      validateInput: (value) => {
        if (!value.startsWith('pasto_ak_')) {
          return 'API key should start with "pasto_ak_"';
        }
        return undefined;
      }
    });

    if (apiKey) {
      await context.secrets.store('pasto.apiKey', apiKey);
      vscode.window.showInformationMessage('API key saved successfully!');
      
      // Refresh paste tree
      vscode.commands.executeCommand('pasto.refreshPastes');
    }
  });

  context.subscriptions.push(disposable);
}
```

---

## Development Workflow

### Setup

```bash
# Install Yeoman and VS Code extension generator
npm install -g yo generator-code @vscode/vsce

# Generate extension scaffold
yo code

# Choose:
# - TypeScript
# - pasto (extension name)
# - No git init (using existing repo)

cd pasto-vscode
npm install
```

### Development

```bash
# Compile TypeScript
npm run compile

# Watch mode (auto-recompile on changes)
npm run watch

# Run extension in debug mode
# Press F5 in VS Code to open Extension Development Host
```

### Testing

```bash
# Run tests
npm test

# Manual testing checklist:
# - Create paste from selection
# - Create paste from entire file
# - Fetch paste by ID
# - View paste list in sidebar
# - Delete paste from sidebar
# - Copy paste URL
# - Configure API key
# - Change instance URL
# - Test with private pastes
```

### Publishing

```bash
# Package extension
vsce package
# Creates: pasto-0.1.0.vsix

# Test .vsix installation
code --install-extension pasto-0.1.0.vsix

# Publish to marketplace (one-time login first)
vsce login ralsina
vsce publish

# Or publish with version bump
vsce publish minor  # 0.1.0 → 0.2.0
vsce publish patch  # 0.1.0 → 0.1.1
```

---

## Implementation Phases

### Phase 1: MVP (3-5 days)

**Core Features:**
- ✅ Extension scaffold with TypeScript
- ✅ Basic API client (create, fetch)
- ✅ Create paste command (selection + full file)
- ✅ Fetch paste command (by ID)
- ✅ Configuration (instance URL, API key)
- ✅ Clipboard integration
- ✅ Basic error handling

**Deliverable**: Functional extension that can create and fetch pastes

### Phase 2: Full Features (7-12 days)

**Additional Features:**
- ✅ TreeView sidebar (paste browser)
- ✅ Refresh, delete commands
- ✅ Context menus (right-click)
- ✅ Status bar integration
- ✅ Language auto-detection
- ✅ Paste settings (private, expiry)
- ✅ Progress indicators
- ✅ Better error messages

**Deliverable**: Full-featured extension ready for beta testing

### Phase 3: Polish (15-20 days)

**Polish & Quality:**
- ✅ Comprehensive error handling
- ✅ Unit + integration tests
- ✅ Documentation (README, CHANGELOG)
- ✅ Extension icon and branding
- ✅ Marketplace listing optimization
- ✅ CI/CD (GitHub Actions)
- ✅ User feedback iteration
- ✅ Performance optimization
- ✅ Keyboard shortcuts
- ✅ Walkthrough/tutorial

**Deliverable**: Production-ready extension published to VS Code Marketplace

---

## Future Enhancements (v2+)

### Advanced Features
- **Multi-instance support**: Switch between multiple Pasto instances
- **SSH key authentication**: Use SSH keys instead of API tokens
- **Encryption support**: Create and decrypt encrypted pastes
- **Fork functionality**: Fork pastes from extension
- **Version history**: Browse paste versions
- **Diff viewer**: Compare paste versions
- **Syntax theme sync**: Match Pasto themes with VS Code themes
- **Paste templates**: Pre-defined paste configurations
- **Collaborative editing**: Real-time paste editing (if Pasto adds support)

### Integration Features
- **GitHub Gist migration**: Import from/export to GitHub Gists
- **Snippets integration**: Save pastes as VS Code snippets
- **Git integration**: Create pastes from git diffs
- **Terminal integration**: Create pastes from terminal output
- **Markdown preview**: Preview markdown pastes in extension

### UX Improvements
- **Paste preview**: Hover to preview paste content
- **Syntax highlighting**: Show highlighted code in sidebar
- **Search/filter**: Full-text search across pastes
- **Tags/labels**: Organize pastes with custom tags
- **Favorites**: Pin frequently used pastes
- **Export**: Bulk export pastes to files

---

## Success Metrics

- **Adoption**: 1000+ installs in first month
- **Engagement**: 50+ daily active users
- **Retention**: 60%+ weekly active users
- **Rating**: 4.0+ stars on Marketplace
- **Feedback**: <10% negative reviews
- **Usage**: Average 5+ pastes created per user per week

---

## Marketing & Distribution

### Marketplace Optimization
- Clear, concise description highlighting unique features
- Screenshots showing key workflows
- Demo GIF/video (30-60 seconds)
- Keywords: pastebin, code sharing, pasto, paste, snippet
- Categories: Snippets, Other

### Launch Strategy
1. Announce on Pasto GitHub repo
2. Post on VS Code extension subreddit
3. Share on Twitter with #vscode hashtag
4. Blog post with tutorial
5. Submit to VS Code extension newsletter

### Community Building
- GitHub repo for issues/feedback
- Documentation site
- Discord/Slack channel (optional)
- Regular updates and changelogs

---

## Technical Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Language | TypeScript | Better VS Code API support, type safety |
| Authentication | API Key (MVP) → SSH (v2) | Simpler to implement, existing API support |
| Instance Support | Single (MVP) → Multi (v2) | Faster MVP, add complexity when needed |
| Paste Storage | Cloud-only | Avoid local cache complexity |
| Error Handling | User-friendly messages + logs | Balance UX and debuggability |
| Testing | Unit + Manual (MVP) → E2E (v2) | Pragmatic approach for MVP |
| Distribution | VS Code Marketplace | Standard, discoverable, auto-updates |

---

## Resources

- [VS Code Extension API](https://code.visualstudio.com/api)
- [Extension Samples](https://github.com/microsoft/vscode-extension-samples)
- [Publishing Guide](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)
- [UX Guidelines](https://code.visualstudio.com/api/ux-guidelines/overview)
- [Pasto API Documentation](https://github.com/ralsina/pasto#api)

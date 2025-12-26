# Web Interface

The Pasto web interface provides a modern, responsive way to create and manage pastes with live syntax highlighting and real-time preview.

## Accessing the Web Interface

Navigate to your Pasto instance in your browser:

```bash
# Default local installation
http://localhost:3000

# Custom port
http://localhost:8080

# Remote instance
https://pasto.example.com
```

## Creating a Paste

### Basic Paste Creation

1. **Navigate to the homepage** - You'll see the editor on the left and live preview on the right
2. **Type or paste your content** - The preview updates automatically
3. **Choose a language** - Language is auto-detected, or select manually from the dropdown
4. **(Optional) Add a title** - Click the title field to add a descriptive title
5. **Click the + button** - Your paste is created and you're redirected to the view page

### Editor Features

The CodeJar editor provides:

- **Syntax highlighting** - Live highlighting as you type
- **Line numbers** - Easy reference
- **Auto-indentation** - Maintains code structure
- **Tab support** - Proper tab/space handling
- **Bracket matching** - Visual indicators for matching brackets

### Sidebar Controls

The collapsible sidebar includes:

#### Theme Selection
- **UI Theme** - Pico CSS color scheme (slate, blue, green, etc.)
- **Syntax Theme** - Syntax highlighting theme (321+ options: monokai, dracula, nord, etc.)
- **Light/Dark Mode** - Toggle between light and dark themes

#### Security Options
- **Private Paste** - Restrict access to only you (requires login)
- **Burn After Reading** - Delete paste after first view
- **Encrypt** - Enable zero-knowledge encryption (client-side)

#### Expiration
- **Never** - Paste never expires
- **1 Hour** - Expire after 1 hour
- **1 Day** - Expire after 1 day
- **1 Week** - Expire after 1 week
- **1 Month** - Expire after 1 month

## Viewing Pastes

### Paste View Page

When viewing a paste, you'll see:

- **Title** - Paste title (or "Untitled")
- **Metadata** - Language, creation time, expiration
- **Syntax-highlighted content** - Rendered with your chosen theme
- **Action buttons** - Copy, raw, edit, delete (if owner)

### Paste Actions

#### Copy to Clipboard
Click the **Copy** button to copy the entire paste to your clipboard:

```
Paste copied to clipboard!
```

#### View Raw
Click the **Raw** button to view the unrendered content:

```bash
http://localhost:3000/abc123-def456/raw
```

#### Edit Paste
Only available to paste owners. Click **Edit** to modify the paste:

- Creates a new version
- Preserves version history
- Requires login

#### Delete Paste
Only available to paste owners. Click **Delete** to permanently remove the paste:

- Deletes all versions
- Cannot be undone
- Requires confirmation

## Language Detection

Pasto uses the Hansa classifier for automatic language detection:

### Supported Languages

35+ languages including:

- **Popular**: Python, JavaScript, TypeScript, Java, C, C++, C#, Go, Rust
- **Web**: HTML, CSS, SCSS, JSON, XML, YAML, Markdown
- **Systems**: Bash, Shell, PowerShell, Dockerfile
- **Data**: SQL, MySQL, PostgreSQL, CSV
- **More**: PHP, Ruby, Perl, Kotlin, Scala, ActionScript

### Manual Language Override

If auto-detection is incorrect:

1. Click the **Language dropdown** in the sidebar
2. Select the correct language
3. Paste re-renders with new syntax highlighting

### Language via URL

Force a language using the `lang` query parameter:

```bash
http://localhost:3000/abc123-def456?lang=python
```

Or use file extension:

```bash
http://localhost:3000/abc123-def456.py
```

## Theme Customization

### UI Themes (Pico CSS)

Available color schemes:

- Slate, Zinc, Gray, Neutral, Stone
- Red, Orange, Amber, Yellow, Lime
- Green, Emerald, Cyan, Sky, Indigo
- Violet, Fuchsia, Pink

### Syntax Themes (Tartrazine)

Popular themes:

- **Monokai** - Classic dark theme
- **Dracula** - Popular dark theme
- **Nord** - Arctic, north-blues
- **Solarized** - Precision colors for solarized
- **GitHub Dark** - GitHub's dark theme
- **One Dark** - Atom's default dark theme
- **VS Code Dark+** - Visual Studio Code theme

### Saving Theme Preferences

When logged in, your theme preferences are saved automatically:

- UI theme preference
- Syntax theme preference
- Light/dark mode preference

## User Accounts

### Creating an Account

1. Click **Profile** in the navigation
2. Click **Sign Up**
3. Enter a username and password
4. Your account is created

### Profile Page

Your profile page (`/profile`) shows:

- **Your pastes** - All pastes you've created
- **API key** - Your API key for REST API/MCP access
- **Display name** - Editable profile name
- **Preferences** - Theme settings

### Managing Pastes

From your profile, you can:

- **View all your pastes** - Paginated list
- **Edit pastes** - Click edit button
- **Delete pastes** - Click delete button
- **Export data** - Download all your data

### API Keys

Generate API keys for REST API and MCP access:

1. Visit `/profile`
2. Click **Generate API Key**
3. Copy the key (starts with `pasto_ak_`)
4. Use in API requests:

```bash
curl -H "Authorization: Bearer pasto_ak_xxxxxxxxxxxx" \
  http://localhost:3000/api/paste
```

## Zero-Knowledge Encryption

### Creating Encrypted Pastes

1. Toggle the **Encrypt** option in the sidebar
2. Enter a strong password
3. Create the paste as normal
4. Share the URL **and password** with recipient

### Viewing Encrypted Pastes

1. Open the paste URL
2. Enter the password when prompted
3. Content is decrypted client-side in your browser

**Security Notes:**
- Password is never sent to the server
- Server stores only salt and IV (not password)
- Uses AES-256-GCM encryption with PBKDF2 key derivation
- Even server administrators cannot read encrypted pastes

See [Encryption Guide](encryption.md) for detailed instructions.

## Version History

Pasto automatically tracks all changes to pastes:

### Viewing Versions

1. Open a paste you own
2. Click **History** button
3. See all versions with timestamps

### Comparing Versions

- View each version independently
- See what changed between versions
- Restore previous versions

### Version Metadata

Each version shows:

- Creation timestamp
- Version number
- Author (if multiple users)
- Change summary

## Searching and Filtering

### Browse All Pastes

Visit `/` to see recent public pastes:

- Paginated list (20 per page)
- Shows title, language, creation time
- Click to view paste

### Filter by Language

Use the language dropdown to filter:

- Shows only pastes in selected language
- Auto-updates as you type

### Filter by User

Visit `/profile/USERNAME` to see a user's public pastes.

## Responsive Design

The web interface is fully responsive:

### Desktop (>768px)
- Two-column layout (editor + preview)
- Full sidebar controls
- Maximum screen width utilization

### Tablet (768px - 1024px)
- Two-column layout with adjusted spacing
- Collapsible sidebar
- Touch-optimized controls

### Mobile (<768px)
- Single-column layout
- Stacked editor and preview
- Bottom navigation
- Full-width sidebar drawer

## Keyboard Shortcuts

The editor supports standard editing shortcuts:

- **Ctrl/Cmd + S** - Save (create paste)
- **Ctrl/Cmd + Enter** - Create paste
- **Tab** - Insert tab/indent
- **Shift + Tab** - Outdent
- **Ctrl/Cmd + /** - Toggle comment
- **Ctrl/Cmd + F** - Find

## Troubleshooting

### Editor Not Loading

**Problem**: Editor doesn't appear or is blank

**Solution**: Clear browser cache and refresh:
```bash
Ctrl+Shift+R (Linux/Windows)
Cmd+Shift+R (macOS)
```

### Preview Not Updating

**Problem**: Live preview is stuck

**Solution**: Refresh the page or check browser console for errors

### Login Issues

**Problem**: Can't log in or session expires

**Solution**:
- Check that cookies are enabled
- Clear browser cookies for the site
- Ensure `session_secret` is configured (production)

### Encrypted Paste Won't Decrypt

**Problem**: Password rejected for encrypted paste

**Solution**:
- Verify password is correct
- Check for extra whitespace
- Ensure using the password (not the key!)

## Next Steps

- [SSH Access](ssh-access.md)
- [CLI Client](cli.md)
- [Encryption](encryption.md)
- [User Accounts](user-accounts.md)

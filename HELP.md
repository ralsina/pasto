# Pasto Help & Usage Guide

Welcome to Pasto, a modern pastebin with advanced features for code sharing, syntax highlighting, and secure access. This guide covers the essentials to help you get started.

## Creating a Paste
To create a new paste, simply visit the main page and enter your code or text in the editor. Optionally, set a title and select the programming language for accurate syntax highlighting. Click "Create Paste" to save and share your snippet.

## Syntax Highlighting & Themes
Pasto automatically detects the language of your paste or lets you choose one manually. You can also select from a wide range of syntax highlighting themes for both light and dark modes, making code easy to read and present.

## Markdown Support
If your paste is Markdown, Pasto provides a live preview and lets you toggle between source and rendered views. This is perfect for sharing formatted documentation, notes, or README files.

## Editing & Ownership
If you are logged in, your pastes are associated with your account and can be edited later. Anonymous users can create pastes, but these cannot be edited or deleted after creation. Log in to unlock full control over your content.

## User Accounts & SSH Integration
Pasto supports user accounts and SSH key authentication. Link your SSH key in your profile to enable secure, command-line paste creation and management.

## Creating Pastes via SSH
You can create pastes directly from your terminal using SSH:

```
ssh <your-username>@<pasto-server>
```

Once connected, follow the prompts to paste or upload your content. SSH pastes are linked to your account and support all the same features as web pastes.

## Rate Limiting & Abuse Prevention
To ensure fair use, Pasto enforces rate limits on paste creation and other actions. If you hit a limit, wait a few minutes before trying again. Logged-in users enjoy higher limits.

## Privacy & Security
Pastes are private by default (only accessible via their unique URL). You can share the link with anyone you trust. For sensitive data, consider using the SSH interface for added security.

## Advanced Features
- Download pastes with proper file extensions
- Copy to clipboard with one click
- View and restore previous versions (if enabled)
- Switch between light/dark UI and syntax themes

For more details, visit the project repository or contact the maintainer. Happy pasting!

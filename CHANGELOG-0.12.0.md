## [0.12.0] - 2026-03-13

### 🚀 Features

- Add synced scrolling between editor and markdown preview (bidirectional)
- Add markdown preview with real-time rendering using marked.js
- Auto-hide preview buttons for non-markdown languages to reduce UI clutter
- Show preview buttons when auto-detect detects markdown language
- Add editor focus when clicking anywhere in editor pane for better UX

### 🐛 Bug Fixes

- Fix navigation links (profile, help) to use correct base path
- Fix markdown fenced code blocks losing closing ``` during syntax highlighting
- Fix mobile language dropdown not syncing with desktop selection
- Fix auto-detected language not triggering editor syntax highlighting
- Fix visual jump when syntax highlighting activates by adding initial highlighting
- Fix editor padding and font consistency issues
- Add proper padding to markdown preview for better visual spacing
- Lighten editor font by reducing size to 15px and setting normal weight

### 💼 Other

- Update bundled tartrazine.js to fix markdown lexer fenced code block bug

### ⚙️ Miscellaneous Tasks

- Improve editor styling consistency and preview behavior
- Properly implement async syntax highlighting in markdown preview
- Ensure preview scrolls to top when editor scrolls to top
- Ensure bidirectional synced scrolling works correctly
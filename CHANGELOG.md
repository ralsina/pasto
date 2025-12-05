## [unreleased]

### 🚀 Features

- Implement lazy loading for large select elements
- Eliminate CSS flashing by preloading correct themes
- Complete performance optimization and UI improvements
## [0.2.0] - 2025-12-04

### 🚀 Features

- Switch to baked_file_handler for favicon and help text
- Make syntax highlighting match UI theme
- Achieve 100% offline capability by eliminating all CDN dependencies
- Add brotli compressed versions of all baked assets
- Add gzip compressed assets for universal browser compatibility
- Implement content negotiation for compressed asset delivery

### 🐛 Bug Fixes

- Mobile sidebar toggle aligns perfectly at left edge when collapsed
- Remove duplicate Pasto header from sidebar on login page
- Use /assets/favicon.png for favicon in all templates
- Asset bundling
- Color scheme selector not working
- Paste title changes not persisting after app restart

### 💼 Other

- Add accessible names to buttons and select elements

### 🚜 Refactor

- Reorganize asset handling and fix /help endpoint

### ⚡ Performance

- Cache syntax-theme.css for 1 year
- Implement async CSS loading to improve PageSpeed score

### 🎨 Styling

- Use Pico CSS variables for help page background and text color

### ⚙️ Miscellaneous Tasks

- Update asset bundling and scripts (lucide, marked, concat, error handling)
- Update deps
- *(release)* V0.2.0
## [0.1.1] - 2025-12-04

### 🐛 Bug Fixes

- Embed help markdown in binary for self-contained help page
- Mobile layout, main-content uses 100vw for full width

### 📚 Documentation

- Mention public instance in README and index.html

### ⚙️ Miscellaneous Tasks

- Deps
- *(release)* V0.1.1
## [0.1.0] - 2025-12-03

### 🚀 Features

- SSH-based authentication system
- Enhanced user profile page
- Add user name editing to profile
- Share config between pasto and pasto-ssh
- Pasto manages SSH server as child process
- Enable file system watcher for external data changes
- Persist theme preferences to user profile
- Add CodeJar editor with syntax highlighting
- Add paste editing for owners
- Improved create paste UI layout

### 🐛 Bug Fixes

- Update default port to 5000 and add --base-url option
- Save paste as standalone Sepia object
- Use correct paste URL format (/:id not /paste/:id)
- Session persistence, profile page improvements
- Normalize line endings to LF when creating pastes
- Normalize line endings to LF when creating pastes
- UI improvements - profile icon and layout height
- Show markdown preview toggle when markdown is autodetected in editor

### 💼 Other

- Support paste without explicit 'paste' command
- Add 'list' command to show user's pastes
- Add paste options and filename property
- Improve download and button styling
- Set flags
- Add overlay eye button to toggle rendered Markdown view for markdown pastes
- Unify all top bar and control button sizes to 40px, and only show logout button in profile when logged in
- Change help icon in top bar to message-circle-question-mark for improved clarity

### ⚙️ Miscellaneous Tasks

- Remove obsolete paste-helper
- Gitignore
- Updated deps
- Commit all pending changes before release
- Remove broken changelogs before release
- Release script
- Remove old changelog for fresh release
- Build scripts
- *(release)* V0.1.0

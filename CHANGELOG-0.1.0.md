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

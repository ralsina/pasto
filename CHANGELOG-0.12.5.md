## [0.12.5] - 2026-05-04

### 🐛 Bug Fixes

- Improve UI/UX with multiple fixes
## [0.12.4] - 2026-05-04

### ⚙️ Miscellaneous Tasks

- *(release)* V0.12.3
- *(release)* V0.12.4
## [0.12.3] - 2026-04-06

### 🐛 Bug Fixes

- Use window.PASTO_BASE_PATH in help page JavaScript for proper base path support
- Properly handle versioned URLs for syntax highlighting
- Properly handle versioned URLs and remove file extension language override

### 🚜 Refactor

- Migrate from pasto-cache to kemal-cache

### ⚙️ Miscellaneous Tasks

- *(release)* V0.12.1
- *(release)* V0.12.2
- *(release)* V0.12.2
- *(release)* V0.12.2
- *(release)* V0.12.3
## [0.12.1] - 2026-03-16

### 🐛 Bug Fixes

- Preserve cursor position when auto-detected language changes
- Re-highlight directly to preserve cursor position on language change
- Re-highlight directly to preserve cursor position on language change
- Re-highlight editor when syntax theme changes
- Improve error handling and reliability of syntax highlighting theme changes
- Handle closed stream errors and URL-encode lexer names for special characters
- Use CodeJar update for theme changes and add fallback for invalid themes
- Exclude /syntax/* endpoints from cache middleware and add detailed logging
- Remove syntax endpoints from cache config to prevent response hanging

### ⚙️ Miscellaneous Tasks

- Update deps
- Random files
- *(release)* V0.12.1
## [0.12.0] - 2026-03-13

### 🚀 Features

- Focus editor when clicking anywhere in editor pane
- Improve editor styling consistency and preview behavior
- Add syntax highlighting to markdown preview code blocks
- Add synced scrolling between editor and markdown preview
- Show preview buttons when auto-detect detects markdown

### 🐛 Bug Fixes

- Update tartrazine.js to fix markdown fenced code block bug
- Sync language dropdown between desktop and mobile modes
- Properly implement async syntax highlighting in markdown preview
- Ensure bidirectional synced scrolling works
- Ensure preview scrolls to top when editor scrolls to top
- Lighten editor font by reducing size to 15px and setting normal weight
- Add proper padding to markdown preview
- Trigger editor highlight when language is auto-detected

### ⚙️ Miscellaneous Tasks

- Remove debug logging from editor-shared.js
- *(release)* V0.12.0
## [0.11.1] - 2026-02-27

### 🐛 Bug Fixes

- Correct navigation links to use proper paths

### ⚙️ Miscellaneous Tasks

- *(release)* V0.11.1
## [0.11.0] - 2026-02-26

### 🚀 Features

- Migrate to tartrazine.js for client-side syntax highlighting
- Repurpose preview for Markdown rendering and add language detection
- Add lexer XML serving endpoint for tartrazine.js

### 🐛 Bug Fixes

- Render Markdown in preview when auto-detected
- Change lexer endpoint path to avoid BakedFileHandler conflict

### 💼 Other

- Configure tartrazine asset base path for base_path support

### 🚜 Refactor

- Remove duplicate lexer files and serve from tartrazine
- Remove highlight.js from bundle

### ⚙️ Miscellaneous Tasks

- Simplified Dockerfile to use pre-built static binaries
- Remove -Dinotify flag from build scripts
- *(release)* V0.11.0
## [0.10.0] - 2026-01-03

### 🚀 Features

- Add base-path support and refactor routes
- Upgrade to tartrazine v0.19.3 with TTF fonts and remove dependencies

### 🐛 Bug Fixes

- Make SSH server listen on both IPv4 and IPv6 by default
- Handle base-path and --server flag correctly in pasto-cli API client
- Add missing PathHelper require in theme_helper.cr
- Resolve CacheEntry conflict by moving helper functions to meta.cr
- Build script now builds all 5 binaries and compresses assets

### ⚙️ Miscellaneous Tasks

- Update deps
- Lint
- Updated deps
- Updated deps
- Updated deps
- Updated deps
- *(release)* V0.10.0
## [0.9.1] - 2025-12-30

### 🐛 Bug Fixes

- Missing file
- Make Paste.from_file properly handle not-found exceptions
- Critical security vulnerability in anonymous paste access control

### ⚙️ Miscellaneous Tasks

- Version number fix
- Release script
- Use alpine 3.23
- *(release)* V0.9.1
## [0.9.0] - 2025-12-27

### 🚀 Features

- Add VS Code extension for Pasto

### 🐛 Bug Fixes

- Display paste expiration correctly in security dialog
- Embed spleen font in binary for PNG preview generation
- Preserve all Tartrazine CSS styling properties in /syntax endpoint
- Remove duplicate dots in CSS class selectors

### 💼 Other

- Add retry logic with exponential backoff to release scripts

### 📚 Documentation

- Add VS Code extension documentation
- Plans

### ⚙️ Miscellaneous Tasks

- Update deps
- Update deps
- *(release)* V0.9.0
## [0.8.0] - 2025-12-26

### 🚀 Features

- Add CLI client with SSH authentication and full CRUD operations
- Add paste embed functionality
- Improve embed theme handling with user preferences
- Add caching support for embed endpoint

### 📚 Documentation

- Add comprehensive mdbook documentation
- Updated README

### ⚙️ Miscellaneous Tasks

- *(release)* V0.8.0
## [0.7.1] - 2025-12-26

### ⚙️ Miscellaneous Tasks

- Build
- *(release)* V0.7.1
## [0.7.0] - 2025-12-23

### 🚀 Features

- Implement SSH interface viewing and management commands
- Improve font system with centralized CSS variables
- Add version to logo and cache TTL for syntax CSS endpoint
- Include pasto-backup in build and Docker distribution
- Implement comprehensive authenticated user E2E testing infrastructure
- Implement Model Context Protocol (MCP) integration

### 🐛 Bug Fixes

- Apply Chivo font to body element for consistent typography
- Move ECR render calls after DOCTYPE to ensure proper HTML validation
- Missing file
- UI tweaks
- Replace broken docopt with robust SSH argument parsing
- Implement proper POSIX argument parsing in SSH server
- Lint

### 🚜 Refactor

- Fix MCP code quality and remove not_nil! usage

### 📚 Documentation

- Plans

### 🧪 Testing

- More tests
- More tests
- Fix test

### ⚙️ Miscellaneous Tasks

- Update assets
- *(release)* V0.7.0
## [0.6.0] - 2025-12-19

### 🚀 Features

- Implement pure Crystal AES-256-GCM encryption with Web Crypto API compatibility
- Implement comprehensive logging system
- Implement comprehensive per-user backup system with gzip compression
- Improve profile page contrast and add server-side pagination
- Add anonymous paste option for logged-in users
- Unify encryption system with PBKDF2 key derivation
- Add user owner display with interactive help icon
- Add Escape key support to all modal dialogs

### 🐛 Bug Fixes

- Properly coordinate storage directory between web and SSH services
- Improve PNG preview generation for special paste types
- Improve BakedFileHandler routing and asset management
- Remove unused view_count and update OpenAPI definition
- Remove extra closing braces causing JavaScript syntax error

### 🚜 Refactor

- Remove dead code and fix QR code imports
- Migrate PWA assets from /public to baked assets system
- Replace puts calls with proper logging system

### 🎨 Styling

- Improve overlay button contrast in light mode
- Fix linting issues

### 🧪 Testing

- Add missing file

### ⚙️ Miscellaneous Tasks

- Extracted pasto-cache to separate shard
- *(release)* V0.6.0

### 🛡️ Security

- Clear sensitive crypto material from memory
## [0.5.0] - 2025-12-18

### 🚀 Features

- Add keyboard shortcuts (Ctrl+S save, Ctrl+P preview)
- Enhance raw downloads with proper MIME types and filenames
- Enable client-side syntax highlighting for encrypted pastes
- Add modern security features to SSH paste creation
- Enhance encryption dialogs with improved UX and reliability
- Add custom 403 error page for private paste access
- Add comprehensive E2E Playwright testing framework
- Add drag & drop support for text files

### 🐛 Bug Fixes

- Remove infinite recursion in updateLanguage function
- Ensure consistent syntax highlighting between editor and preview
- Prevent plaintext leakage to /highlight when encryption enabled
- Remove hardcoded styles from security settings button
- Editor background color updates immediately when theme changes
- Improve background color extraction to avoid wrong colors from .b class
- Complete theme priority system overhaul
- Add missing requires to server.cr
- Restore missing SSH authentication route
- Complete API response for GET /api/v1/pastes/:id endpoint
- Properly restrict access to private pastes
- Restore missing raw paste endpoint with proper MIME type support
- Add missing onShow callback to showGenericModal function
- Update run-tests.sh to use port 3000 and current test files
- Resolve critical linting issues and improve code quality

### 💼 Other

- Make all tests use consistent port 3000

### 🚜 Refactor

- Theme generation / loading rework
- Massive cleanup of duplicated and dead code
- Implement shared component system to eliminate code duplication
- Integrate show.ecr with shared component system
- Simplify AccessResult and validate_paste_access function
- Eliminate massive code duplication and improve template organization
- Clean up /highlight endpoint and fix JavaScript issues
- Implement comprehensive access control and prevent anonymous private pastes
- Extract language mapping to dedicated JavaScript module
- Extract caching system into reusable pasto-cache shard

### 📚 Documentation

- Add comprehensive version history diff display plan
- Add comprehensive competitive features roadmap

### 🎨 Styling

- Standardize Pico CSS variable usage across templates
- Fix remaining linting issues for cleaner codebase

### 🧪 Testing

- Add comprehensive burn-after-reading 404 verification tests
- Add comprehensive QR code functionality tests

### ⚙️ Miscellaneous Tasks

- Prep for release
- *(release)* V0.5.0
- Extracted pasto-cache to separate shard

### ◀️ Revert

- Restore .b class background color extraction for Tartrazine themes
## [0.4.0] - 2025-12-09

### 🚀 Features

- Add social media preview cards with syntax highlighting
- Integrate baked spleen font for preview image generation
- Improve grass animation and fix label styling
- Complete mobile responsiveness implementation
- Implement two-button solution for preview toggle visibility
- Add controls to profile and help pages
- Simplify encryption UI with toggle button and visual feedback
- Increase button icon sizes for better visibility
- Add outline style for unlocked encryption button
- Increase icon sizes across all templates for better visibility
- Implement complete SSH encryption with secure environment protection
- Implement QR code generation for all pastes
- Implement unified outline button style and fix profile navigation
- Compact security modal with improved UX
- Add security settings to edit template
- Optimize layout for better viewport utilization
- Enhance profile display with visual indicators for paste types
- Implement clean 404 page with consistent layout
- Implement production-ready REST API with OpenAPI documentation
- Add API key revocation via SSH
- Implement PATCH endpoint for updating paste content
- Add /health endpoint for production monitoring
- Add CORS support for web application integration
- Add API key revocation functionality to user profile
- Add SSH key revocation functionality to web UI

### 🐛 Bug Fixes

- Improve SEO and accessibility for all pages
- Resolve favicon 404 errors and improve browser compatibility
- Improve anonymous warning contrast and accessibility
- Replace "Auto-detect" with "Auto" and fix show page controls
- Auto-detection and controls on show page
- Implement SSH key ownership resolution for edit/delete permissions
- Resolve edit page JavaScript error and UI consistency issues
- QR modal close button functionality
- Completely rewrite mobile controls functionality
- Resolve Chrome accessibility warnings in mobile controls
- Implement modal-based paste creation and add favicon redirect
- Improve delete functionality and profile page UX
- Resolve edit page JavaScript syntax error and improve modal layout
- Resolve infinite recursion in security modal function calls
- Enable theme persistence for logged-in users
- Linting error in AccessResult property naming
- Prevent SVG logo stretching in sidebar
- Add favicon redirects and improve path handling
- Properly handle 404 errors with custom 404 page
- Resolve syntax highlighting bugs in / and edit endpoints
- Ensure edit page shows highlighted preview on initial load
- Properly initialize edit page preview after CodeJar setup
- Improve visual consistency between editor and preview panes

### 🚜 Refactor

- Improve mobile sidebar layout spacing
- Optimize JavaScript with shared modules and fix preview persistence
- Replace absolute positioning with flexbox for overlay buttons
- Extract security modal to shared partial eliminating 200+ lines of duplication
- Extract shared JavaScript and partial templates to reduce code duplication
- Simplify theme handling by removing redundant storage
- Simplify expired paste handling by centralizing in Paste.from_file
- Improve API documentation and UI polish
- Reorganize user profile with accordions
- Organize middleware into cohesive filters module
- Unify index.ecr and edit.ecr templates into single component

### 📚 Documentation

- Update TODO.md to reflect actual implementation progress
- Add PATCH endpoint to OpenAPI specification
- Update index.html with recent security and management features
- Refresh HELP.md with current features and concise format

### ⚡ Performance

- Fix API key DoS vulnerability with O(1) lookups

### ⚙️ Miscellaneous Tasks

- Remove baked favicon.ico file
- Commit pending layout and configuration changes
- Lint
- *(release)* V0.4.0

### ◀️ Revert

- Remove favicon.ico implementation
## [0.3.0] - 2025-12-05

### 🚀 Features

- Implement lazy loading for large select elements
- Eliminate CSS flashing by preloading correct themes
- Complete performance optimization and UI improvements

### ⚙️ Miscellaneous Tasks

- Remove crap
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

## [0.12.1] - 2026-03-18

### 🐛 Bug Fixes

- Fix syntax CSS endpoint hanging on first request by removing from cache middleware
- Fix help page not loading when deployed with non-root base path
- Fix URL encoding for lexer names with special characters (e.g., C#)
- Add proper error handling for closed stream errors in profile updates
- Improve theme change reliability using CodeJar update mechanism
- Add fallback for invalid syntax theme names
- Fix auto-detected language changes causing cursor to jump to top
- Preserve cursor position when auto-detected language changes

### 💼 Other

- Add debounced theme saving to prevent excessive server requests
- Improve error handling and logging for debugging theme issues

### ⚙️ Miscellaneous Tasks

- *(release)* V0.12.1

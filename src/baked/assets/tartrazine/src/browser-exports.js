/**
 * Browser exports for tartrazine.js
 * This is the main entry point for browser usage
 */

// Core modules
export { Lexer } from './lexer.js';
export { HtmlFormatter } from './html-formatter.js';
export { loadLexer } from './lexer-loader.js';
export { loadTheme } from './theme-loader.js';
export { getTokenAbbreviation } from './token-abbreviations.js';

// Simple API (convenience function)
export { highlight } from './highlight.js';

// Web Component
export { default as SyntaxHighlight } from './syntax-highlight.js';

// Auto-register web component
if (typeof window !== 'undefined' && !customElements.get('syntax-highlight')) {
  import('./syntax-highlight.js').then(module => {
    customElements.define('syntax-highlight', module.default);
  });
}

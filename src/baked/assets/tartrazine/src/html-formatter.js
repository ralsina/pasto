import { loadTheme } from './theme-loader.js';
import { getTokenAbbreviation } from './token-abbreviations.js';

/**
 * HTML Formatter - Converts tokens to HTML with syntax highlighting
 */
export class HtmlFormatter {
  constructor(options = {}) {
    this.themeName = options.theme || 'github-dark';
    // If theme is already loaded (object), use it, otherwise undefined (will load on demand)
    this.theme = typeof options.theme === 'object' ? options.theme : null;
    this.classPrefix = options.classPrefix || '';
    this.lineNumbers = options.lineNumbers || false;
    this.linkableLineNumbers = options.linkableLineNumbers !== false;
    this.lineNumberStart = options.lineNumberStart || 1;
    this.lineNumberIdPrefix = options.lineNumberIdPrefix || 'line-';
    this.tabWidth = options.tabWidth || 8;
    this.standalone = options.standalone || false;
    this.surroundingPre = options.surroundingPre !== false;
    this.wrapLongLines = options.wrapLongLines || false;
    this.weightOfBold = options.weightOfBold || 600;
    this.template = options.template || this.getDefaultTemplate();
  }

  /**
   * Initialize the formatter (lazy load theme if needed)
   * @returns {Promise<void>}
   */
  async init() {
    if (!this.theme && this.themeName) {
      this.theme = await loadTheme(this.themeName);
    }
  }

  /**
   * Format tokens to HTML
   * @param {string} code - The source code
   * @param {Array} tokens - Array of tokens from the lexer
   * @returns {Promise<string>} HTML output
   */
  async format(code, tokens) {
    // Ensure theme is loaded
    await this.init();
    let output = '';
    let pre = '';
    let post = '';

    // Wrap in standalone HTML if requested
    if (this.standalone) {
      [pre, post] = this.getStandaloneWrappers();
      output += pre;
    }

    // Generate the code body
    output += this.formatTokens(tokens);

    // Close standalone HTML if requested
    if (this.standalone) {
      output += post;
    }

    return output;
  }

  /**
   * Format tokens to HTML (without standalone wrapper)
   * @param {Array} tokens - Array of tokens
   * @returns {string} HTML output
   */
  formatTokens(tokens) {
    let output = '';

    // Opening <pre> and <code>
    if (this.surroundingPre) {
      const preStyle = this.wrapLongLines ? 'style="white-space: pre-wrap; word-break: break-word;"' : '';
      output += `<pre class="${this.getCssClass('Background')}" ${preStyle}>`;
    }
    output += `<code class="${this.getCssClass('Background')}">`;

    let lineNumber = this.lineNumberStart;
    output += this.formatLineNumber(lineNumber, tokens);

    // Format each token
    for (const token of tokens) {
      const escapedValue = this.escapeHtml(token.value);
      output += `<span class="${this.getCssClass(token.type)}">${escapedValue}</span>`;

      // Check if token ends with newline - increment line number and add line label
      if (token.value.endsWith('\n')) {
        lineNumber++;
        output += this.formatLineNumber(lineNumber, tokens);
      }
    }

    // Closing </code> and </pre>
    output += '</code>';
    if (this.surroundingPre) {
      output += '</pre>';
    }

    return output;
  }

  /**
   * Format a line number label
   * @param {number} lineNum - The line number
   * @param {Array} tokens - All tokens (to check if line should be highlighted)
   * @returns {string} HTML for line number
   */
  formatLineNumber(lineNum, tokens) {
    if (!this.lineNumbers) {
      return '';
    }

    const lineLabel = String(lineNum).padStart(4, ' ').padEnd(5, ' ');
    const isHighlighted = this.isHighlighted(lineNum);
    const lineClass = isHighlighted ? `class="${this.getCssClass('LineHighlight')}"` : '';
    const lineId = this.linkableLineNumbers ? `id="${this.lineNumberIdPrefix}${lineNum}"` : '';

    return `<span ${lineId} ${lineClass} style="user-select: none;">${lineLabel} </span>`;
  }

  /**
   * Get CSS class name for a token type
   * @param {string} tokenType - The token type
   * @returns {string} CSS class name
   */
  getCssClass(tokenType) {
    // If theme doesn't have a style for this token, find parent that does
    if (!this.theme.styles[tokenType]) {
      const parents = this.theme.styleParents[tokenType] || [];
      for (const parent of parents) {
        if (this.theme.styles[parent]) {
          this.theme.styles[tokenType] = this.theme.styles[parent];
          break;
        }
      }
      // Default to Background style if nothing found
      if (!this.theme.styles[tokenType]) {
        this.theme.styles[tokenType] = this.theme.styles['Background'] || {};
      }
    }

    const abbrev = getTokenAbbreviation(tokenType);
    return this.classPrefix + abbrev;
  }

  /**
   * Escape HTML special characters
   * @param {string} text - Text to escape
   * @returns {string} Escaped text
   */
  escapeHtml(text) {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  /**
   * Generate CSS styles from the theme
   * @returns {string} CSS output
   */
  generateCss() {
    let css = '';

    for (const [tokenType, style] of Object.entries(this.theme.styles)) {
      const className = this.getCssClass(tokenType);
      css += `.${className} {`;

      if (style.color) {
        const color = style.color.startsWith('#') ? style.color : `#${style.color}`;
        css += `color: ${color};`;
      }
      if (style.background) {
        const bg = style.background.startsWith('#') ? style.background : `#${style.background}`;
        css += `background-color: ${bg};`;
      }
      if (style.border) {
        const border = style.border.startsWith('#') ? style.border : `#${style.border}`;
        css += `border: 1px solid ${border};`;
      }
      if (style.border === false) {
        css += 'border: none;';
      }
      if (style.bold) {
        css += `font-weight: ${this.weightOfBold};`;
      }
      if (style.italic) {
        css += 'font-style: italic;';
      }
      if (style.italic === false) {
        css += 'font-style: normal;';
      }
      if (style.underline) {
        css += 'text-decoration: underline;';
      }
      if (style.underline === false) {
        css += 'text-decoration: none;';
      }
      if (tokenType === 'Background') {
        css += `tab-size: ${this.tabWidth};`;
      }

      css += '}';
    }

    return css;
  }

  /**
   * Get standalone HTML wrappers
   * @returns {Array} [preHTML, postHTML]
   */
  getStandaloneWrappers() {
    const css = this.generateCss();
    const template = this.template;

    if (template.includes('{{style_defs}}')) {
      const parts = template.split('{{style_defs}}');
      const bodyParts = parts[1].split('{{body}}');
      return [
        parts[0] + css + bodyParts[0],
        bodyParts[1] || ''
      ];
    } else {
      const parts = template.split('{{body}}');
      return [parts[0], parts[1] || ''];
    }
  }

  /**
   * Get default HTML template
   * @returns {string} Default template
   */
  getDefaultTemplate() {
    return `<!DOCTYPE html><html><head><style>
{{style_defs}}
</style></head><body>
{{body}}
</body></html>`;
  }

  /**
   * Check if a line should be highlighted
   * @param {number} lineNum - Line number
   * @returns {boolean} True if line should be highlighted
   */
  isHighlighted(lineNum) {
    // TODO: Support highlight_lines option
    return false;
  }
}

/**
 * Format code as HTML
 * @param {string} code - Source code
 * @param {string} language - Language name
 * @param {object} options - Formatter options
 * @returns {Promise<string>} HTML output
 */
export async function formatHtml(code, language, options = {}) {
  const { Lexer } = await import('./lexer.js');

  // Tokenize the code
  const lexer = new Lexer(language);
  await lexer.init();
  const tokens = await lexer.tokenize(code);

  // Format to HTML
  const formatter = new HtmlFormatter(options);
  return formatter.format(code, tokens);
}

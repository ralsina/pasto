import { loadLexer } from './lexer-loader.js';
import { StateMatcher } from './state-matcher.js';

/**
 * Main Lexer class - Public API for tokenizing text
 */
export class Lexer {
  constructor(lexerName) {
    this.lexerName = lexerName;
    this.lexerDef = null;
    this.initialized = false;
  }

  /**
   * Initialize the lexer (lazy loading)
   * @returns {Promise<void>}
   */
  async init() {
    if (this.initialized) {
      return;
    }

    this.lexerDef = await loadLexer(this.lexerName);
    this.initialized = true;
  }

  /**
   * Tokenize text
   * @param {string} text - Text to tokenize
   * @param {Object} options - Options
   * @param {string} options.state - Initial state (default: 'root')
   * @returns {Promise<Array>} Array of tokens
   */
  async tokenize(text, options = {}) {
    await this.init();

    // Respect the `ensure_nl` config option
    // If text doesn't end with newline and ensure_nl is true, append one
    let textToTokenize = text;
    if (this.lexerDef.ensureNl && textToTokenize.length > 0 && textToTokenize[textToTokenize.length - 1] !== '\n') {
      textToTokenize = textToTokenize + '\n';
    }

    // Tartrazine always starts in 'root' state
    const initialState = options.state || 'root';
    const matcher = new StateMatcher(this.lexerDef);

    // Collect all tokens from the async generator
    const tokens = [];
    for await (const token of matcher.tokenize(textToTokenize, initialState)) {
      tokens.push(token);
    }

    // Collapse consecutive tokens of the same type
    return matcher.collapseTokens(tokens);
  }

  /**
   * Get lexer metadata
   * @returns {Promise<Object>} Lexer metadata
   */
  async getMetadata() {
    await this.init();
    return {
      name: this.lexerDef.name,
      aliases: this.lexerDef.aliases,
      filenames: this.lexerDef.filenames,
      mimeTypes: this.lexerDef.mimeTypes,
    };
  }
}

/**
 * Convenience function to create and initialize a lexer
 * @param {string} lexerName - Name of the lexer
 * @returns {Promise<Lexer>} Initialized lexer
 */
export async function createLexer(lexerName) {
  const lexer = new Lexer(lexerName);
  await lexer.init();
  return lexer;
}

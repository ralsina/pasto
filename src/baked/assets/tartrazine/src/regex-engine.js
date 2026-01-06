import { toRegExp } from 'oniguruma-to-es';

/**
 * Regex engine wrapper around oniguruma-to-es
 * Converts Oniguruma/PCRE2 patterns to native JavaScript RegExp
 */
export class RegexEngine {
  constructor(lexerDef = null) {
    this.cache = new Map();
    this.lexerDef = lexerDef;
  }

  /**
   * Compile a pattern with flags
   * @param {string} pattern - Oniguruma/PCRE2 pattern
   * @param {string} flags - Pattern flags (m, i, s, etc.)
   * @param {boolean} caseInsensitive - Whether to make the pattern case-insensitive
   * @returns {RegExp} Compiled regular expression
   */
  compile(pattern, flags = '', caseInsensitive = false) {
    const cacheKey = `${pattern}::${flags}::${caseInsensitive}`;

    if (this.cache.has(cacheKey)) {
      return this.cache.get(cacheKey);
    }

    const regex = this.createRegex(pattern, flags, caseInsensitive);
    this.cache.set(cacheKey, regex);
    return regex;
  }

  /**
   * Transform PCRE2 pattern to be compatible with oniguruma-to-es
   * @param {string} pattern - PCRE2 pattern
   * @returns {string} Transformed pattern
   */
  transformPattern(pattern) {
    // The Rust lexer has pattern "#![ ^[ \r\n ].*$" where \r and \n are literal
    // backslash+r and backslash+n (two characters each, not escape sequences).
    // This pattern can't be parsed by oniguruma-to-es due to the [^[] sequence.
    // The [ exclusion in [^[ is redundant since #! already doesn't match #[foo].
    // We remove the [ from the character class to make it compatible.

    // Construct the pattern using character codes to match the literal backslashes
    const rustShebangPattern = String.fromCharCode(35, 33, 91, 94, 91, 92, 114, 92, 110, 93, 46, 42, 36); // #![ ^[ \r\n ].*$
    const transformedRustPattern = String.fromCharCode(35, 33, 91, 94, 92, 114, 92, 110, 93, 46, 42, 36); // #![ ^\r\n].*$

    if (pattern === rustShebangPattern) {
      return transformedRustPattern;
    }

    // The Python lexer has patterns where [] is used to match literal ] and [
    // In PCRE2, [] at the start or end of a character class matches a literal ]
    // JavaScript doesn't allow empty character classes, so we need to transform these.
    // Pattern examples: []{}:(),;[]  [])}]  [{([]
    // NOTE: These transformations must happen BEFORE oniguruma-to-es processing
    if (pattern === '[]{}:(),;[]') {
      return '[\\]{}:(),;\\[]';  // Python punctuation
    }
    if (pattern === '[{([]') {
      return '[\\{\\[\\(]';  // Python nested braces
    }
    if (pattern === '[])}]') {
      return pattern;  // Handled correctly by oniguruma-to-es
    }
    // Haskell has similar patterns
    // For PCRE2 patterns like [][]][(),;{}],
    // we need to convert to JavaScript-compatible character class
    if (pattern === '[][(),;`{}]') {
      // The pattern is a character class matching: ], (, ), ,, ;, `, {, }
      // In JavaScript, use \x5d (hex code for ]) to avoid issues
      return '[\\x5d(),;`{}]';  // Haskell punctuation
    }
    if (pattern === '[][\p{Lu}@^_]') {
      // The pattern is a character class matching: ], \p{Lu}, @, ^, _
      return '[\\x5d\\p{Lu}@^_]';  // Haskell symbols
    }

    return pattern;
  }

  /**
   * Create RegExp from Oniguruma pattern
   * @param {string} pattern - Oniguruma/PCRE2 pattern
   * @param {string} flags - Pattern flags
   * @param {boolean} caseInsensitive - Whether to make the pattern case-insensitive
   * @returns {RegExp} JavaScript RegExp object
   */
  createRegex(pattern, flags, caseInsensitive = false) {
    // Transform PCRE2 pattern for compatibility (do this outside try block for error logging)
    let cleanPattern = this.transformPattern(pattern);

    try {
      // Parse flags
      const options = {
        global: false, // We don't want global matching by default
        forgiving: true, // Be lenient with unsupported features
        recursionLimit: 10, // Aggressively limit recursion to prevent catastrophic backtracking
        lazyCompileLength: 1, // Lazy compile very short patterns
      };

      // Handle flag modifiers in pattern
      // Oniguruma uses (?i), (?m), (?s), (?x), (?is), (?sx), etc. inline modifiers
      // JavaScript doesn't support inline flags, so we extract them and add to RegExp flags
      let jsFlags = '';
      let hasFreeSpacing = false;

      // Check for inline flag modifiers - can be combined like (?is), (?sx), etc.
      // Match (? followed by any combination of letters i, m, s, x, etc.
      const flagRegex = /\(\?([a-z]+)\)/gi;
      let match;
      while ((match = flagRegex.exec(cleanPattern)) !== null) {
        const flags = match[1].toLowerCase();
        for (const flag of flags) {
          if (flag === 'i' && !jsFlags.includes('i')) {
            jsFlags += 'i'; // Case insensitive
          } else if (flag === 'm' && !jsFlags.includes('m')) {
            jsFlags += 'm'; // Multiline
          } else if (flag === 's' && !jsFlags.includes('s')) {
            jsFlags += 's'; // DotAll (single-line mode - . matches newlines)
          } else if (flag === 'x' && !jsFlags.includes('x')) {
            // Free-spacing mode - ignores whitespace and allows comments
            // JavaScript doesn't natively support this, so we preprocess the pattern
            hasFreeSpacing = true;
            jsFlags += 'x';
          }
        }
      }

      // Remove all flag modifiers from the pattern
      cleanPattern = cleanPattern.replace(/\(\?[a-z]+\)/gi, '');

      // Decode HTML entities in the pattern
      // XML parsers encode characters like newlines as &#xA; or &#10;
      // We need to decode them before compiling the regex
      cleanPattern = cleanPattern.replace(/&#x([0-9a-fA-F]+);/g, (match, hex) => {
        return String.fromCharCode(parseInt(hex, 16));
      });
      cleanPattern = cleanPattern.replace(/&#(\d+);/g, (match, dec) => {
        return String.fromCharCode(parseInt(dec, 10));
      });

      // Decode named HTML entities
      const htmlEntities = {
        'lt': '<',
        'gt': '>',
        'amp': '&',
        'quot': '"',
        'apos': '\''
      };
      cleanPattern = cleanPattern.replace(/&(lt|gt|amp|quot|apos);/g, (match, entity) => {
        return htmlEntities[entity] || match;
      });

      // If free-spacing mode is enabled, manually preprocess the pattern
      // oniguruma-to-es doesn't support the x flag, so we handle it ourselves
      if (hasFreeSpacing) {
        // Process line by line to handle comments correctly
        const lines = cleanPattern.split('\n');
        const processedLines = [];

        for (let line of lines) {
          // Find the comment position (first # not inside a character class or escaped)
          let commentPos = -1;
          let inCharClass = false;
          let inEscape = false;

          for (let i = 0; i < line.length; i++) {
            const char = line[i];

            if (inEscape) {
              inEscape = false;
              continue;
            }

            if (char === '\\') {
              inEscape = true;
              continue;
            }

            if (char === '[') {
              inCharClass = true;
              continue;
            }

            if (char === ']') {
              inCharClass = false;
              continue;
            }

            // If we're not in a character class and we see #, that starts a comment
            if (!inCharClass && char === '#') {
              commentPos = i;
              break;
            }
          }

          // Remove the comment and trailing whitespace
          if (commentPos >= 0) {
            line = line.substring(0, commentPos);
          }

          // Remove leading/trailing whitespace
          line = line.trim();

          // Only add non-empty lines
          if (line.length > 0) {
            processedLines.push(line);
          }
        }

        // Join the lines (free-spacing mode removes all whitespace)
        cleanPattern = processedLines.join('');
      }

      // Also check explicit flags passed as parameter
      if ((flags.includes('i') || caseInsensitive) && !jsFlags.includes('i')) {
        jsFlags += 'i';
      }
      if (flags.includes('m') && !jsFlags.includes('m')) {
        jsFlags += 'm';
      }
      if (flags.includes('s') && !jsFlags.includes('s')) {
        jsFlags += 's';
      }

      // Check if lexer has dotAll enabled (makes . match newlines)
      if (this.lexerDef && this.lexerDef.dotAll && !jsFlags.includes('s')) {
        jsFlags += 's';
      }

      // Convert to JavaScript RegExp using oniguruma-to-es
      const regex = toRegExp(cleanPattern, options);

      // Use the regex from oniguruma-to-es directly (it has 'v' flag for Unicode)
      // Just add our custom flags (i, m, s) if not already present
      let finalFlags = regex.flags;
      if (jsFlags.includes('i') && !finalFlags.includes('i')) {
        finalFlags += 'i';
      }
      if (jsFlags.includes('m') && !finalFlags.includes('m')) {
        finalFlags += 'm';
      }
      if (jsFlags.includes('s') && !finalFlags.includes('s')) {
        finalFlags += 's';
      }

      // oniguruma-to-es transforms . to [^\n] when (?s) is not present
      // If we're adding the s flag (dotAll mode), we need to revert this
      // transformation so that . matches newlines as intended
      let finalSource = regex.source;

      // Decode HTML entities in the regex source
      // oniguruma-to-es encodes characters like <, >, and & as HTML entities
      // We need to decode them back to actual characters for the regex to work
      finalSource = finalSource.replace(/&lt;/g, '<');
      finalSource = finalSource.replace(/&gt;/g, '>');
      finalSource = finalSource.replace(/&amp;/g, '&');

      if (finalFlags.includes('s')) {
        // Replace [^\n] with . so dotAll mode works correctly
        // This reverses the common case where . was transformed to [^\n]
        // The source contains literal backslash-n, so we need \\n in the regex
        finalSource = finalSource.replace(/\[\^\\n\]/g, '.');
      }

      return new RegExp(finalSource, finalFlags);
    } catch (error) {
      throw new Error(`Failed to compile pattern "${pattern}": ${error.message}`);
    }
  }

  /**
   * Execute regex and return match result
   * @param {RegExp} regex - Compiled regex
   * @param {string} text - Text to match against
   * @param {number} startOffset - Starting position in text
   * @returns {Match|null} Match result or null if no match
   */
  match(regex, text, startOffset = 0) {
    // Use sticky flag with lastIndex to match at specific position
    // This preserves ^ and \b anchors correctly
    const stickyRegex = new RegExp(regex.source, regex.flags + 'y');
    stickyRegex.lastIndex = startOffset;

    const result = stickyRegex.exec(text);

    if (!result) {
      return null;
    }

    return result;
  }

  /**
   * Clear the pattern cache
   */
  clearCache() {
    this.cache.clear();
  }
}

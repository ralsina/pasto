import { readFileSync } from 'fs';
import { XMLParser } from 'fast-xml-parser';
import { join } from 'path';

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  textNodeName: '#text',
  trimValues: false,
});

/**
 * Detect if running in browser environment
 */
const isBrowser = typeof window !== 'undefined';

/**
 * Get the base URL for loading assets
 */
function getAssetBase() {
  if (isBrowser && window.__tartrazine_asset_base) {
    return window.__tartrazine_asset_base;
  }
  return '';
}

/**
 * Load XML file content
 * Uses fetch() in browser, fs in Node.js
 * @param {string} path - Path to XML file
 * @returns {Promise<string>} XML content
 */
async function loadXmlFile(path) {
  const fullPath = getAssetBase() + path;

  if (isBrowser) {
    const response = await fetch(fullPath);
    if (!response.ok) {
      throw new Error(`Failed to load ${path}: ${response.statusText}`);
    }
    return await response.text();
  } else {
    return readFileSync(fullPath, 'utf-8');
  }
}

/**
 * Parse color from style string (e.g., "#f85149", "bold #ff7b72", "bg:#0d1117")
 * @param {string} styleStr - The style string
 * @returns {object} Parsed style properties
 */
function parseStyle(styleStr) {
  const style = {
    color: null,
    background: null,
    bold: false,
    italic: false,
    underline: false,
    border: null,
  };

  // Remove extra whitespace
  styleStr = styleStr.trim();

  // Check for modifiers
  style.bold = styleStr.includes('bold');
  style.italic = styleStr.includes('italic');
  style.underline = styleStr.includes('underline');

  // Remove modifiers from the string
  styleStr = styleStr.replace(/bold|italic|underline/g, '').trim();

  // Split by spaces and parse each part
  const parts = styleStr.split(/\s+/);
  for (const part of parts) {
    if (part.startsWith('bg:')) {
      // Background color
      style.background = part.substring(3);
    } else if (part.startsWith('#')) {
      // Regular color
      if (!style.color) {
        style.color = part;
      }
    }
  }

  return style;
}

/**
 * Load and parse a theme XML file
 * @param {string} themeName - Name of the theme (e.g., "github-dark")
 * @param {string} stylesDir - Directory containing theme XML files
 * @returns {Promise<object>} Parsed theme with styles and style parents
 */
export async function loadTheme(themeName, stylesDir = 'styles') {
  const xmlPath = join(stylesDir, `${themeName}.xml`);
  const xmlContent = await loadXmlFile(xmlPath);

  const parsed = parser.parse(xmlContent);
  const styleElement = parsed.style;

  if (!styleElement) {
    throw new Error(`Invalid theme file: missing <style> element in ${themeName}.xml`);
  }

  const entries = Array.isArray(styleElement.entry) ? styleElement.entry : [styleElement.entry];

  const theme = {
    name: themeName,
    styles: {},
    styleParents: {},
  };

  for (const entry of entries) {
    const tokenType = entry.type;
    const style = parseStyle(entry.style || '');

    theme.styles[tokenType] = style;

    // Build style parent hierarchy
    // Token types like "NameFunction" have parent "Name" which has parent "Background"
    theme.styleParents[tokenType] = getParentChain(tokenType);
  }

  return theme;
}

/**
 * Get parent chain for a token type
 * @param {string} tokenType - The token type
 * @returns {Array<string>} Parent chain from most specific to least specific
 */
function getParentChain(tokenType) {
  const parents = [];
  let current = tokenType;

  // Known parent mappings based on Pygments token hierarchy
  const parentMap = {
    // Comment types
    'CommentHashbang': 'Comment',
    'CommentMultiline': 'Comment',
    'CommentPreproc': 'Comment',
    'CommentPreprocFile': 'CommentPreproc',
    'CommentSingle': 'Comment',
    'CommentSpecial': 'CommentSingle',

    // Keyword types
    'KeywordConstant': 'Keyword',
    'KeywordDeclaration': 'Keyword',
    'KeywordNamespace': 'Keyword',
    'KeywordPseudo': 'Keyword',
    'KeywordReserved': 'Keyword',
    'KeywordType': 'Keyword',

    // Literal types
    'LiteralDate': 'Literal',
    'LiteralNumber': 'Literal',
    'LiteralNumberBin': 'LiteralNumber',
    'LiteralNumberFloat': 'LiteralNumber',
    'LiteralNumberHex': 'LiteralNumber',
    'LiteralNumberInteger': 'LiteralNumber',
    'LiteralNumberIntegerLong': 'LiteralNumberInteger',
    'LiteralNumberOct': 'LiteralNumber',
    'LiteralOther': 'Literal',
    'LiteralString': 'Literal',
    'LiteralStringAffix': 'LiteralString',
    'LiteralStringAtom': 'LiteralString',
    'LiteralStringBacktick': 'LiteralString',
    'LiteralStringBoolean': 'LiteralString',
    'LiteralStringChar': 'LiteralString',
    'LiteralStringDelimiter': 'LiteralString',
    'LiteralStringDoc': 'LiteralString',
    'LiteralStringDouble': 'LiteralString',
    'LiteralStringEscape': 'LiteralString',
    'LiteralStringHeredoc': 'LiteralString',
    'LiteralStringInterpol': 'LiteralString',
    'LiteralStringName': 'LiteralString',
    'LiteralStringOther': 'LiteralString',
    'LiteralStringRegex': 'LiteralString',
    'LiteralStringSingle': 'LiteralString',
    'LiteralStringSymbol': 'LiteralString',

    // Name types
    'NameAttribute': 'Name',
    'NameBuiltin': 'Name',
    'NameBuiltinPseudo': 'NameBuiltin',
    'NameClass': 'Name',
    'NameConstant': 'Name',
    'NameDecorator': 'Name',
    'NameEntity': 'Name',
    'NameException': 'Name',
    'NameFunction': 'Name',
    'NameFunctionMagic': 'NameFunction',
    'NameKeyword': 'Name',
    'NameLabel': 'Name',
    'NameNamespace': 'Name',
    'NameOperator': 'Name',
    'NameOther': 'Name',
    'NameProperty': 'Name',
    'NameTag': 'Name',
    'NameVariable': 'Name',
    'NameVariableAnonymous': 'NameVariable',
    'NameVariableClass': 'NameVariable',
    'NameVariableGlobal': 'NameVariable',
    'NameVariableInstance': 'NameVariable',
    'NameVariableMagic': 'NameVariable',

    // Operator types
    'OperatorWord': 'Operator',

    // Generic types
    'GenericDeleted': 'Generic',
    'GenericEmph': 'Generic',
    'GenericError': 'Generic',
    'GenericHeading': 'Generic',
    'GenericInserted': 'Generic',
    'GenericOutput': 'Generic',
    'GenericPrompt': 'Generic',
    'GenericStrong': 'Generic',
    'GenericSubheading': 'Generic',
    'GenericTraceback': 'Generic',
    'GenericUnderline': 'Generic',

    // Punctuation types (some may be under Operator in some lexers)
    // Most have no parent other than Text or Punctuation itself
  };

  while (current && current !== 'Background') {
    current = parentMap[current] || null;
    if (current) {
      parents.push(current);
    }
  }

  // Always end at Background
  if (!parents.includes('Background')) {
    parents.push('Background');
  }

  return parents;
}

/**
 * Get default theme (github-dark)
 * @returns {object} Theme object
 */
export function getDefaultTheme() {
  return loadTheme('github-dark');
}

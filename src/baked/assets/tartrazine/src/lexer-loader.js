import { XMLParser } from 'fast-xml-parser';
import { readFileSync } from 'fs';

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
 * In browser, can be configured via setAssetBase()
 * Defaults to relative paths
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
 * Load and parse a lexer XML file
 * @param {string} lexerName - Name of the lexer (e.g., 'bash')
 * @returns {Promise<Object>} Parsed lexer definition
 */
export async function loadLexer(lexerName) {
  // Use the synced lexers directory for deployment/packaging
  const xmlPath = `lexers/${lexerName}.xml`;
  const xmlContent = await loadXmlFile(xmlPath);

  // Preprocess XML to handle duplicate attributes in <combined> and <push> elements
  // fast-xml-parser doesn't preserve duplicate attributes, so we need to
  // convert <combined state="a" state="b"/> to <combined state="a,b"/>
  // and <push state="a" state="b"/> to <push state="a,b"/>
  let preprocessed = xmlContent.replace(
    /<(combined|push)\s+([^>]*?)>/g,
    (match, tagName, attrs) => {
      // Extract all state attributes
      const stateRegex = /state="([^"]+)"/g;
      const states = [];
      let stateMatch;
      while ((stateMatch = stateRegex.exec(attrs)) !== null) {
        states.push(stateMatch[1]);
      }

      if (states.length > 0) {
        // Remove all state attributes from attrs
        const attrsWithoutStates = attrs.replace(/state="[^"]+"\s*/g, '');
        // Add combined state attribute as comma-separated list
        return `<${tagName} state="${states.join(',')}" ${attrsWithoutStates}>`;
      }
      return match;
    }
  );

  // Preprocess <bygroups> to add _order attribute to preserve element order
  // fast-xml-parser groups elements by type, losing order. We add _order="0", _order="1", etc.
  // to each child element so we can sort them later.
  preprocessed = preprocessed.replace(
    /<bygroups>([\s\S]*?)<\/bygroups>/g,
    (match, content) => {
      let order = 0;
      const ordered = content.replace(/<(usingself|using|token)([^>]*)>/g, (m, tagName, attrs) => {
        return `<${tagName} _order="${order++}"${attrs}>`;
      });
      return `<bygroups>${ordered}</bygroups>`;
    }
  );

  return parseLexerXML(preprocessed);
}

/**
 * Parse lexer XML content
 * @param {string} xmlContent - XML content as string
 * @returns {Object} Parsed lexer definition
 */
export function parseLexerXML(xmlContent) {
  const parsed = parser.parse(xmlContent);
  const lexer = parsed.lexer;

  if (!lexer) {
    throw new Error('Invalid lexer XML: missing <lexer> root element');
  }

  return transformLexerDef(lexer);
}

/**
 * Transform parsed XML into internal lexer definition structure
 * @param {Object} lexer - Parsed lexer XML object
 * @returns {Object} Transformed lexer definition
 */
function transformLexerDef(lexer) {
  const config = lexer.config || {};
  const rules = lexer.rules || {};
  const states = {};

  // Extract states from rules
  const stateList = Array.isArray(rules.state) ? rules.state : [rules.state];

  for (const state of stateList) {
    if (!state || !state.name) continue;

    states[state.name] = {
      name: state.name,
      rules: parseRules(state.rule || []),
    };
  }

  return {
    name: config.name || '',
    aliases: extractArray(config.alias),
    filenames: extractArray(config.filename),
    mimeTypes: extractArray(config.mime_type),
    ensureNl: config.ensure_nl === 'true' || config.ensure_nl === true,
    caseInsensitive: config.case_insensitive === 'true' || config.case_insensitive === true,
    dotAll: config.dot_all === 'true' || config.dot_all === true,
    states,
  };
}

/**
 * Parse rules from a state
 * @param {Array} rules - Array of rule elements from XML
 * @returns {Array} Parsed rules
 */
function parseRules(rules) {
  const ruleList = Array.isArray(rules) ? rules : [rules];
  const parsed = [];

  for (const rule of ruleList) {
    if (!rule) continue;

    const parsedRule = {
      pattern: rule.pattern || '',
      actions: [],
    };

    // Extract actions
    if (rule.token) {
      parsedRule.actions.push({
        type: 'token',
        tokenType: rule.token.type,
      });
    }

    if ('push' in rule) {
      // push can have multiple states (comma-separated after preprocessing)
      // e.g., <push state="closing-brace,command-body,opening-brace"/>
      const states = rule.push.state ? rule.push.state.split(',') : [];

      parsedRule.actions.push({
        type: 'push',
        state: states.length > 0 ? states[0] : null, // TODO: support pushing multiple states
        states: states, // Store all states for future use
      });
    }

    if ('pop' in rule) {
      parsedRule.actions.push({
        type: 'pop',
        depth: parseInt(rule.pop.depth || '1', 10),
      });
    }

    if ('include' in rule) {
      parsedRule.actions.push({
        type: 'include',
        state: rule.include.state,
      });
    }

    // Handle combined - merges multiple states into one anonymous state
    if ('combined' in rule) {
      // combined can have multiple states, now as comma-separated value
      // e.g., <combined state="stringescape,dqs"/>
      const states = rule.combined.state ? rule.combined.state.split(',') : [];

      parsedRule.actions.push({
        type: 'combined',
        states,
      });
    }

    // Handle using - shunts matched text to another lexer
    if ('using' in rule) {
      parsedRule.actions.push({
        type: 'using',
        lexer: rule.using.lexer,
      });
    }

    // Handle bygroups - creates multiple tokens from capture groups
    if (rule.bygroups) {
      const groups = [];

      // Extract tokens
      const tokens = Array.isArray(rule.bygroups.token) ? rule.bygroups.token : (rule.bygroups.token ? [rule.bygroups.token] : []);

      // Extract usingself elements
      const usingselfs = Array.isArray(rule.bygroups.usingself) ? rule.bygroups.usingself : (rule.bygroups.usingself ? [rule.bygroups.usingself] : []);

      // Extract using elements
      const usings = Array.isArray(rule.bygroups.using) ? rule.bygroups.using : (rule.bygroups.using ? [rule.bygroups.using] : []);

      // Use the _order attribute added during preprocessing to preserve original order
      // Collect all groups and sort by _order
      const allGroups = [];

      // Add tokens
      for (const token of tokens) {
        allGroups.push({ ...token, _kind: 'token' });
      }

      // Add usingself elements
      for (const usingself of usingselfs) {
        allGroups.push({ ...usingself, _kind: 'usingself' });
      }

      // Add using elements
      for (const using of usings) {
        allGroups.push({ ...using, _kind: 'using' });
      }

      // Sort by _order attribute
      allGroups.sort((a, b) => {
        const orderA = parseInt(a._order || 0, 10);
        const orderB = parseInt(b._order || 0, 10);
        return orderA - orderB;
      });

      // Convert sorted elements to group actions
      for (const item of allGroups) {
        if (item._kind === 'token') {
          groups.push({
            type: 'token',
            tokenType: item.type,
          });
        } else if (item._kind === 'usingself') {
          groups.push({
            type: 'usingself',
            state: item.state,
          });
        } else if (item._kind === 'using') {
          groups.push({
            type: 'using',
            lexer: item.lexer,
          });
        }
      }

      parsedRule.actions.push({
        type: 'bygroups',
        groups,
      });
    }

    parsed.push(parsedRule);
  }

  return parsed;
}

/**
 * Extract array from potentially single value or array
 * @param {any} value - Single value or array
 * @returns {Array} Array of values
 */
function extractArray(value) {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
}

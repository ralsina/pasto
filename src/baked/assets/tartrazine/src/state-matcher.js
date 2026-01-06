import { RegexEngine } from './regex-engine.js';
import { Lexer } from './lexer.js';

/**
 * State Matcher - Core tokenization engine
 * Implements the state machine that matches patterns and executes actions
 */
export class StateMatcher {
  constructor(lexerDef) {
    this.lexerDef = lexerDef;
    this.regexEngine = new RegexEngine(lexerDef);
    this.compiledRules = new Map();
  }

  /**
   * Tokenize text starting from a given state (async generator-based)
   * Matches Crystal's deque-based approach
   * @param {string} text - Text to tokenize
   * @param {string} initialState - Starting state name
   * @yields {Object} Individual tokens
   */
  async *tokenize(text, initialState = 'root') {
    const stateStack = [initialState];
    let position = 0;
    const deque = []; // Buffer for tokens

    // Track iterations to prevent infinite loops
    let iterations = 0;
    const maxIterations = text.length * 100; // Safety limit

    while (true) {
      // If deque has tokens, return one (like Crystal's @dq.shift)
      if (deque.length > 0) {
        yield deque.shift();
        continue;
      }

      // If we've reached end of text, we're done
      if (position >= text.length) {
        break;
      }

      // Prevent infinite loops
      iterations++;
      if (iterations > maxIterations) {
        console.error('Infinite loop detected in tokenization');
        break;
      }

      const currentState = stateStack[stateStack.length - 1];
      const stateDef = this.lexerDef.states[currentState];

      if (!stateDef) {
        // No matching state - advance one character
        position++;
        continue;
      }

      // Try to match a rule
      const matchResult = this.findMatch(stateDef, text, position);

      if (!matchResult) {
        // No rule matches at current position
        // Create one error token and add to deque (like Crystal)
        const char = text[position];
        if (char.charCodeAt(0) === 10) { // newline
          deque.push({ type: 'Text', value: '\n' });
          stateStack.length = 0;
          stateStack.push('root');
        } else {
          deque.push({ type: 'Error', value: char });
        }
        position++;
        // Continue to next iteration to return from deque
        continue;
      }

      // A rule matched!
      const { match, rule } = matchResult;

      // Only execute token actions if the match has non-zero length
      // Zero-length matches (like lookaheads) should not generate tokens
      const matchLength = match[0].length || 0;
      if (matchLength > 0) {
        // Execute actions and add all tokens to deque
        const newTokens = await this.executeActions(rule.actions, match, stateStack, position);

        // Split tokens containing newlines (like Crystal's split_tokens)
        const splitTokens = this.splitTokens(newTokens);
        for (const token of splitTokens) {
          deque.push(token);
        }

        // Advance position by match length
        position += matchLength;
      } else {
        // For zero-length matches, only execute non-token actions (push, pop, include)
        // Do NOT advance position - continue to next rule
        this.executeActionsNonToken(rule.actions, match, stateStack, position);
      }
      // Continue to next iteration to return from deque
    }
  }

  /**
   * Execute actions and return array of tokens
   * @param {Array} actions - Actions to execute
   * @param {Array} match - Regex match result
   * @param {Array} stateStack - State stack
   * @param {number} position - Current position
   * @returns {Promise<Array>} Array of tokens
   */
  async executeActions(actions, match, stateStack, position) {
    const tokens = [];
    for (const action of actions) {
      await this.executeAction(action, match, stateStack, tokens, position);
    }
    return tokens;
  }

  /**
   * Execute non-token actions (push, pop, include) for zero-length matches
   * @param {Array} actions - Actions to execute
   * @param {Array} match - Regex match result
   * @param {Array} stateStack - State stack
   * @param {number} position - Current position
   */
  async executeActionsNonToken(actions, match, stateStack, position) {
    for (const action of actions) {
      // Only execute state-modifying actions, not token-generating actions
      if (action.type === 'push' || action.type === 'pop' || action.type === 'include') {
        await this.executeAction(action, match, stateStack, [], position);
      }
    }
  }

  /**
   * If a token contains a newline, split it into two tokens
   * @param {Array} tokens - Array of tokens
   * @returns {Array} Tokens with newlines split
   */
  splitTokens(tokens) {
    const splitTokens = [];
    for (const token of tokens) {
      if (token.value.includes('\n')) {
        const values = token.value.split('\n');
        for (let i = 0; i < values.length; i++) {
          let value = values[i];
          // Add back the newline except for the last value
          if (i < values.length - 1) {
            value += '\n';
          }
          splitTokens.push({ type: token.type, value });
        }
      } else {
        splitTokens.push(token);
      }
    }
    return splitTokens;
  }

  /**
   * Collapse consecutive tokens of the same type
   * @param {Array} tokens - Array of tokens
   * @returns {Array} Collapsed tokens
   */
  collapseTokens(tokens) {
    if (tokens.length === 0) return [];

    const collapsed = [];
    let current = { ...tokens[0] };

    for (let i = 1; i < tokens.length; i++) {
      const token = tokens[i];

      if (token.type === current.type) {
        // Merge with current token
        current.value += token.value;
      } else {
        // Push current and start new
        collapsed.push(current);
        current = { ...token };
      }
    }

    // Push the last token
    collapsed.push(current);

    return collapsed;
  }

  /**
   * Find a matching rule at the current position
   * @param {Object} stateDef - State definition
   * @param {string} text - Text to search
   * @param {number} position - Current position
   * @returns {Object|null} Match result or null
   */
  findMatch(stateDef, text, position) {
    const rules = this.getCompiledRules(stateDef.name);

    for (const rule of rules) {
      // If regex is null, this is a zero-length match rule
      if (rule.regex === null) {
        return {
          match: [''], // Zero-length match
          rule
        };
      }

      const regex = rule.regex;
      const match = this.regexEngine.match(regex, text, position);

      if (match && match.index === position) {
        return { match, rule };
      }
    }

    return null;
  }

  /**
   * Get or compile rules for a state
   * @param {string} stateName - State name
   * @returns {Array} Compiled rules
   */
  getCompiledRules(stateName) {
    if (this.compiledRules.has(stateName)) {
      return this.compiledRules.get(stateName);
    }

    const stateDef = this.lexerDef.states[stateName];
    if (!stateDef) {
      return [];
    }

    // Expand rules with includes
    const compiled = this.expandRules(stateDef.rules, new Set());

    this.compiledRules.set(stateName, compiled);
    return compiled;
  }

  /**
   * Expand rules, resolving includes recursively
   * @param {Array} rules - Rules to expand
   * @param {Set} visited - States already visited (to prevent infinite recursion)
   * @returns {Array} Expanded compiled rules
   */
  expandRules(rules, visited) {
    const expanded = [];

    for (const rule of rules) {
      // First, process any include actions in this rule
      const includeActions = rule.actions.filter(a => a.type === 'include');
      const nonIncludeActions = rule.actions.filter(a => a.type !== 'include');

      // If there's a pattern and non-include actions, compile and add the rule FIRST
      // Rules defined in the current state take priority over included states
      if (nonIncludeActions.length > 0) {
        expanded.push({
          regex: rule.pattern ? this.regexEngine.compile(rule.pattern, '', this.lexerDef.caseInsensitive) : null,
          actions: rule.actions,
        });
      }

      // THEN expand includes from referenced states
      // These will be checked after the current state's rules
      for (const includeAction of includeActions) {
        const includedState = this.lexerDef.states[includeAction.state];
        if (includedState) {
          // Prevent infinite recursion
          if (!visited.has(includeAction.state)) {
            visited.add(includeAction.state);
            const includedRules = this.expandRules(includedState.rules, visited);
            expanded.push(...includedRules);
          }
        }
      }
    }

    return expanded;
  }

  /**
   * Execute an action
   * @param {Object} action - Action definition
   * @param {Array} match - Regex match result
   * @param {Array} stateStack - State stack
   * @param {Array} tokens - Token array
   * @param {number} position - Current position
   */
  async executeAction(action, match, stateStack, tokens, position) {
    switch (action.type) {
      case 'token':
        tokens.push({
          type: action.tokenType,
          value: match[0],
        });
        break;

      case 'bygroups':
        // Create one token per capture group
        // match[0] is the full match, match[1] is first group, etc.
        for (let i = 0; i < action.groups.length; i++) {
          const groupAction = action.groups[i];
          const groupIndex = i + 1; // match[0] is full match, groups start at 1

          if (groupIndex < match.length && match[groupIndex] !== undefined) {
            // Skip empty groups (e.g., optional whitespace that didn't match)
            if (match[groupIndex] !== '') {
              // If groupAction is usingself, recursively tokenize the matched text
              if (groupAction.type === 'usingself') {
                // Consume the async generator and collect tokens
                const recursiveTokens = [];
                for await (const token of this.tokenize(match[groupIndex], groupAction.state)) {
                  recursiveTokens.push(token);
                }
                tokens.push(...recursiveTokens);
              } else if (groupAction.type === 'using') {
                // Shunt to another lexer
                // Normalize lexer name to lowercase
                const lexer = new Lexer(groupAction.lexer.toLowerCase());
                await lexer.init();
                const usingTokens = await lexer.tokenize(match[groupIndex]);
                tokens.push(...usingTokens);
              } else if (groupAction.type === 'token') {
                tokens.push({
                  type: groupAction.tokenType,
                  value: match[groupIndex],
                });
              }
            }
          }
        }
        break;

      case 'push':
        // Push state(s) onto stack
        // Can have multiple states to push in sequence
        // If no state specified (null or empty), push the current state again (for nested structures)
        const statesToPush = action.states || (action.state ? [action.state] : []);

        if (statesToPush.length === 0) {
          // <push/> without state means push current state
          stateStack.push(stateStack[stateStack.length - 1]);
        } else {
          // Push each state in sequence
          for (const state of statesToPush) {
            if (state === '#pop' && stateStack.length > 1) {
              // #pop means pop the state instead of pushing
              stateStack.pop();
            } else {
              stateStack.push(state);
            }
          }
        }
        break;

      case 'pop':
        // Pop specified number of states from stack
        const depth = action.depth || 1;
        const toPop = Math.min(depth, stateStack.length - 1);
        for (let i = 0; i < toPop; i++) {
          stateStack.pop();
        }
        break;

      case 'include':
        // Include is handled during rule compilation
        // No action needed here
        break;

      case 'using': {
        // Shunt to another lexer entirely
        // Create a new lexer and tokenize the matched text with it
        // Normalize lexer name to lowercase
        const lexer = new Lexer(action.lexer.toLowerCase());
        await lexer.init();

        // Tokenize the matched text with the new lexer
        const usingTokens = await lexer.tokenize(match[0]);

        // Add all tokens from the other lexer to our token array
        tokens.push(...usingTokens);
        break;
      }

      case 'combined': {
        // Combine multiple states into one anonymous state
        // Merge rules from all specified states
        const mergedRules = [];
        for (const stateName of action.states) {
          const stateDef = this.lexerDef.states[stateName];
          if (stateDef && stateDef.rules) {
            mergedRules.push(...stateDef.rules);
          }
        }

        // Create anonymous state with a unique name
        const anonymousStateName = `__combined_${Date.now()}_${Math.random().toString(36).substring(2, 10)}__`;

        // Add the new state to the lexer definition
        this.lexerDef.states[anonymousStateName] = {
          name: anonymousStateName,
          rules: mergedRules,
        };

        // Push the anonymous state onto the stack
        stateStack.push(anonymousStateName);
        break;
      }

      default:
        console.warn('Unknown action type:', action.type);
    }
  }
}

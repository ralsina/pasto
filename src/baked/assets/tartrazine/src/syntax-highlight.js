/**
 * Web Component: <syntax-highlight>
 * Declarative syntax highlighting for the web
 */

import { highlight } from './highlight.js';

/**
 * Custom element for syntax highlighting
 * Usage: <syntax-highlight language="javascript" theme="github-dark">code here</syntax-highlight>
 */
class SyntaxHighlight extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  /**
   * Observed attributes - when these change, the component re-renders
   */
  static get observedAttributes() {
    return ['language', 'theme', 'line-numbers', 'standalone'];
  }

  /**
   * Called when element is added to DOM
   */
  connectedCallback() {
    this.render();
  }

  /**
   * Called when observed attributes change
   */
  attributeChangedCallback(name, oldValue, newValue) {
    if (oldValue !== newValue) {
      this.render();
    }
  }

  /**
   * Get the code content from the element
   */
  getCode() {
    // Try to get from <template> first, then from text content
    const template = this.querySelector('template');
    if (template) {
      return template.innerHTML;
    }
    return this.textContent || '';
  }

  /**
   * Render the highlighted code
   */
  async render() {
    const code = this.getCode();
    const language = this.getAttribute('language') || 'plaintext';
    const theme = this.getAttribute('theme') || 'github-dark';
    const lineNumbers = this.hasAttribute('line-numbers');
    const standalone = this.hasAttribute('standalone');

    if (!code.trim()) {
      this.shadowRoot.innerHTML = '';
      return;
    }

    try {
      const html = await highlight(code, language, theme, {
        lineNumbers,
        standalone
      });

      // Add basic styles
      const styles = `
        <style>
          :host {
            display: block;
          }
          pre {
            margin: 0;
            padding: 1rem;
            overflow-x: auto;
          }
          code {
            font-family: 'Fira Code', 'Consolas', 'Monaco', monospace;
            font-size: 0.875rem;
            line-height: 1.6;
          }
        </style>
      `;

      this.shadowRoot.innerHTML = styles + html;

      // Dispatch custom event when done
      this.dispatchEvent(new CustomEvent('highlighted', {
        bubbles: true,
        detail: { language, theme }
      }));
    } catch (error) {
      this.shadowRoot.innerHTML = `
        <style>:host { display: block; }</style>
        <pre style="color: red; padding: 1rem;">Error: ${error.message}</pre>
      `;
    }
  }
}

export default SyntaxHighlight;

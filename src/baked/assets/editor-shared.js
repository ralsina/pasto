// Shared editor functionality for Pasto
// Common functions used across index.ecr and edit.ecr

// Helper function to save cursor position
function saveCursorPosition(editor) {
  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0) {
    return { offset: 0, text: '' };
  }

  const range = selection.getRangeAt(0);
  const preCaretRange = range.cloneRange();
  preCaretRange.selectNodeContents(editor);
  preCaretRange.setEnd(range.endContainer, range.endOffset);

  return {
    offset: preCaretRange.toString().length,
    text: editor.textContent
  };
}

// Helper function to restore cursor position
function restoreCursorPosition(editor, savedPosition) {
  if (!savedPosition || savedPosition.offset === 0) {
    return;
  }

  const selection = window.getSelection();
  if (!selection) {
    return;
  }

  const range = document.createRange();
  const charCount = Math.min(savedPosition.offset, editor.textContent.length);

  let currentCount = 0;
  let found = false;

  // Walk through the editor's text nodes to find the correct position
  const walker = document.createTreeWalker(
    editor,
    NodeFilter.SHOW_TEXT,
    null
  );

  let node;
  while (node = walker.nextNode()) {
    const nodeLength = node.textContent.length;

    if (currentCount + nodeLength >= charCount) {
      range.setStart(node, charCount - currentCount);
      range.collapse(true);
      found = true;
      break;
    }

    currentCount += nodeLength;
  }

  // If we couldn't find the exact position, place cursor at the end
  if (!found) {
    range.selectNodeContents(editor);
    range.collapse(false);
  }

  selection.removeAllRanges();
  selection.addRange(range);
}

// Highlight function for CodeJar using tartrazine.js
// This is now async to support the async tartrazine API
async function highlight(editor, currentLanguage = '', syntaxTheme = null) {
  const code = editor.textContent;
  if (!code) return;

  const lang = currentLanguage || '';

  // Get syntax theme from parameter or fallback to getter (for CSS class only)
  const theme = syntaxTheme || getThemeGetter();

  // Normalize empty language to plaintext for tartrazine
  const normalizedLang = (!lang || lang === '' || lang === 'Auto') ? 'plaintext' : lang;

  // Save cursor position before updating
  const savedCursor = saveCursorPosition(editor);

  try {
    // Use tartrazine.js for highlighting (no theme parameter - CSS is pre-loaded)
    if (typeof Tartrazine !== 'undefined' && Tartrazine.highlight) {
      const html = await Tartrazine.highlight(code, normalizedLang, {
        standalone: false,
        lineNumbers: false
      });
      editor.innerHTML = html;
      // Apply syntax highlighting theme class
      editor.className = theme;
      // Restore cursor position after updating
      restoreCursorPosition(editor, savedCursor);
    } else {
      // Fallback if tartrazine is not loaded
      console.warn('Tartrazine not loaded, using plain text');
      editor.textContent = code;
      editor.className = theme;
    }
  } catch (e) {
    console.error('Highlight error:', e);
    // Fallback to plain text
    editor.textContent = code;
    editor.className = theme;
  }
}

// Debounced preview update function
function debouncedUpdatePreview(updatePreviewCallback, debounceTimerVar) {
  clearTimeout(debounceTimerVar);
  return setTimeout(updatePreviewCallback, 300);
}

// Common preview update logic
function updatePreview(jar, getLanguageValue, getSyntaxThemeValue) {
  const content = jar ? jar.toString() : '';
  const languageSelect = document.getElementById('language') || { value: getLanguageValue() };

  if (!content.trim()) {
    const previewElement = document.getElementById('preview');
    if (previewElement) {
      previewElement.innerHTML = '<pre><code>Start typing to see preview...</code></pre>';
    }
    return;
  }

  const currentLanguage = languageSelect.value.toLowerCase();

  // For explicitly selected Markdown, render client-side using marked
  if (currentLanguage === 'markdown' || currentLanguage === 'md') {
    const previewElement = document.getElementById('preview');
    if (previewElement) {
      try {
        if (typeof marked !== 'undefined') {
          previewElement.innerHTML = marked.parse(content);
        } else {
          previewElement.innerHTML = '<pre><code>marked.js not loaded</code></pre>';
        }
      } catch (e) {
        console.error('Markdown parsing error:', e);
        previewElement.innerHTML = '<pre><code>Error rendering Markdown</code></pre>';
      }
    }
    return;
  }

  // Check if encryption is enabled to avoid sending plaintext to server
  // Multiple safety checks to prevent plaintext leakage
  const securitySettings = window.securitySettings || {};
  const isEncryptionEnabled = securitySettings.encryptionEnabled === true;

  // Double-check: if there's any indication encryption should be enabled, use client-side only
  const hasSecuritySettings = typeof window.securitySettings !== 'undefined';
  const isEncryptionDialogOpen = document.querySelector('dialog[style*="block"]') !== null;

  // If encryption is enabled OR if we're in an uncertain state (better safe than sorry)
  if (isEncryptionEnabled || (!hasSecuritySettings && isEncryptionDialogOpen)) {
    // For encrypted content, hide the preview entirely for security
    const previewElement = document.getElementById('preview');
    if (previewElement) {
      previewElement.innerHTML = `
        <div style="padding: 20px; text-align: center; color: #666; font-style: italic;">
          <i data-lucide="shield" style="width: 24px; height: 24px; margin-bottom: 10px; opacity: 0.5;"></i>
          <p>Preview disabled for encrypted content</p>
          <p style="font-size: 0.9em; margin-top: 5px;">Your code will only be processed client-side for security</p>
        </div>
      `;

      // Re-initialize Lucide icons if needed
      if (window.lucide) {
        window.lucide.createIcons();
      }
    }
    return;
  }

  // For non-Markdown content, use language detection endpoint
  const formData = new FormData();
  formData.append('content', content);

  fetch((window.PASTO_BASE_PATH === '/' ? '/api/detect-language' : window.PASTO_BASE_PATH + '/api/detect-language'), {
    method: 'POST',
    body: formData
  })
  .then(response => response.json())
  .then(data => {
    // Update language selector text to show detected language if auto-detection is active
    const isAutoDetect = (languageSelect.value === 'Auto' || languageSelect.value === '');

    if (isAutoDetect) {
      const autoDetectOption = Array.from(languageSelect.options || []).find(
        option => option.value === 'Auto' || option.value === ''
      );

      if (autoDetectOption) {
        if (data.language) {
          autoDetectOption.textContent = `Auto (${data.language})`;
        } else {
          autoDetectOption.textContent = 'Auto';
        }
      }
    }

    const previewElement = document.getElementById('preview');
    const detectedLang = (data.language || 'unknown').toLowerCase();

    // If detected language is Markdown, render it
    if (detectedLang === 'markdown' || detectedLang === 'md') {
      if (previewElement) {
        try {
          if (typeof marked !== 'undefined') {
            previewElement.innerHTML = marked.parse(content);
          } else {
            previewElement.innerHTML = '<pre><code>marked.js not loaded</code></pre>';
          }
        } catch (e) {
          console.error('Markdown parsing error:', e);
          previewElement.innerHTML = '<pre><code>Error rendering Markdown</code></pre>';
        }
      }
    } else {
      // Show message that preview is not available for non-Markdown content
      if (previewElement) {
        previewElement.innerHTML = `
          <div style="padding: 20px; text-align: center; color: #666; font-style: italic;">
            <i data-lucide="eye" style="width: 24px; height: 24px; margin-bottom: 10px; opacity: 0.5;"></i>
            <p>Preview available for Markdown only</p>
            <p style="font-size: 0.9em; margin-top: 5px;">Detected language: <strong>${detectedLang}</strong></p>
            <p style="font-size: 0.8em; margin-top: 10px;">The editor shows syntax highlighting in real-time</p>
          </div>
        `;

        // Re-initialize Lucide icons if needed
        if (window.lucide) {
          window.lucide.createIcons();
        }
      }
    }
  })
  .catch(error => {
    console.error('Error updating preview:', error);
    const previewElement = document.getElementById('preview');
    if (previewElement) {
      previewElement.innerHTML = '<pre><code>Error updating preview</code></pre>';
    }
  });
}

// Common toggle preview functionality
function togglePreview(jar, getLanguageValue, getSyntaxThemeValue) {
  const container = document.getElementById('editor-preview-container');
  const showButton = document.getElementById('controls-show-preview-button');
  const hideButton = document.getElementById('controls-hide-preview-button');

  const isHidden = container.classList.toggle('preview-hidden');

  // Toggle button visibility
  if (showButton && hideButton) {
    if (isHidden) {
      showButton.style.display = 'flex';
      hideButton.style.display = 'none';
    } else {
      showButton.style.display = 'none';
      hideButton.style.display = 'flex';
    }
  }

  if (!isHidden) {
    updatePreview(jar, getLanguageValue, getSyntaxThemeValue); // Refresh preview when shown
  }

  // Save preference
  localStorage.setItem('previewHidden', isHidden);
}

// Common keyboard shortcuts functionality
function setupKeyboardShortcuts(saveCallback, togglePreviewCallback, jar, getLanguageValue, getSyntaxThemeValue) {
  document.addEventListener('keydown', function(event) {
    // Check for Ctrl key on Windows/Linux or Cmd key on Mac
    const ctrlOrCmd = event.ctrlKey || event.metaKey;

    // Don't trigger shortcuts when typing in input fields
    if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
      return;
    }

    // Ctrl+S or Cmd+S - Save
    if (ctrlOrCmd && event.key === 's') {
      event.preventDefault();
      if (saveCallback) {
        saveCallback();
      }
    }

    // Ctrl+P or Cmd+P - Toggle Preview
    if (ctrlOrCmd && event.key === 'p') {
      event.preventDefault();
      if (togglePreviewCallback) {
        togglePreviewCallback(jar, getLanguageValue, getSyntaxThemeValue);
      }
    }
  });
}

// Initialize CodeJar with common settings
function createCodeJar(editorElement, highlightFunction, options = {}) {
  const defaultOptions = {
    tab: '  ',
    indentOn: /[{[(]$/,
    moveToNewLine: /^[}\])]$/,
    spellcheck: false,
    catchTab: true,
    preserveIdent: true,
    addClosing: true,
    history: true
  };

  return new CodeJar(editorElement, highlightFunction, { ...defaultOptions, ...options });
}

// Update language and refresh highlighting
function updateLanguage(jar, currentLanguageVar) {
  const languageSelect = document.getElementById('language');
  if (!languageSelect) return;

  currentLanguageVar.value = languageSelect.value;
  if (jar) {
    jar.updateCode(jar.toString());
  }
  updatePreview(jar, getLanguageGetter, getThemeGetter);
}

// Get language value from select element, handling Auto (detected) format
function getLanguageGetter() {
  const languageSelect = document.getElementById('language');
  if (!languageSelect) return '';

  const selectValue = languageSelect.value;

  // If explicit language is selected, use it
  if (selectValue && selectValue !== '' && selectValue !== 'Auto') {
    return selectValue;
  }

  // Try to extract detected language from "Auto (language)" format
  const autoOption = languageSelect.options[0];
  if (autoOption?.textContent?.includes('(')) {
    const match = autoOption.textContent.match(/\(([^)]+)\)/);
    if (match) {
      return match[1];
    }
  }

  // Fallback to raw value
  return selectValue || '';
}

// Get theme value from select element
function getThemeGetter() {
  const themeElement = document.querySelector('#syntax-theme') || document.getElementById('syntax-theme');
  return themeElement ? themeElement.value : (window.pastoSyntaxTheme || 'default-dark');
}

// Initialize Lucide icons
function initializeLucideIcons() {
  if (window.lucide) {
    window.lucide.createIcons();
  }
}

// Restore preview visibility from localStorage
function restorePreviewVisibility() {
  const previewHidden = localStorage.getItem('previewHidden') === 'true';
  const container = document.getElementById('editor-preview-container');
  const showButton = document.getElementById('controls-show-preview-button');
  const hideButton = document.getElementById('controls-hide-preview-button');

  if (!container || !showButton || !hideButton) return;

  if (previewHidden) {
    container.classList.add('preview-hidden');
    showButton.style.display = 'flex';
    hideButton.style.display = 'none';
  } else {
    container.classList.remove('preview-hidden');
    showButton.style.display = 'none';
    hideButton.style.display = 'flex';
  }
}

// Initialize language select with API data
async function initializeLanguageSelect(languageSelectId, currentLanguage = null, basePath = '/') {
  try {
    const response = await fetch((window.PASTO_BASE_PATH === '/' ? '/api/languages' : window.PASTO_BASE_PATH + '/api/languages'));
    const languages = await response.json();
    const select = document.getElementById(languageSelectId);

    if (!select) return;

    const currentValue = select.value;
    select.innerHTML = '<option value="">Auto</option>';

    // Add current language if exists
    if (currentLanguage) {
      const option = document.createElement('option');
      option.value = currentLanguage.toLowerCase();
      option.textContent = currentLanguage;
      option.selected = true;
      select.appendChild(option);
    }

    // Add all available languages
    languages.forEach(langObj => {
      if (langObj && langObj.name && langObj.value) {
        // Skip if this is the current language (already added)
        if (langObj.value.toLowerCase() !== (currentLanguage || '').toLowerCase()) {
          const option = document.createElement('option');
          option.value = langObj.value;
          option.textContent = langObj.name;
          select.appendChild(option);
        }
      }
    });

    return languages;
  } catch (error) {
    console.error('Error loading languages:', error);
    return [];
  }
}

// Export functions for use in templates
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    mapLanguage,
    highlight,
    debouncedUpdatePreview,
    updatePreview,
    togglePreview,
    setupKeyboardShortcuts,
    createCodeJar,
    updateLanguage,
    getLanguageGetter,
    getThemeGetter,
    initializeLucideIcons,
    restorePreviewVisibility,
    initializeLanguageSelect
  };
}

// Export functions to window for backward compatibility
window.createCodeJar = createCodeJar;
window.updateLanguage = function() {
  // Find the current jar and hidden language input
  const languageInput = document.getElementById('language') || document.querySelector('input[name="language"]');
  const editorElement = document.querySelector('.codejar-editor');
  if (!languageInput || !editorElement) return;

  // Try to get the jar instance from the element
  let jar = null;
  if (editorElement._jar) {
    jar = editorElement._jar;
  }

  updateLanguage(jar, languageInput);
};
window.togglePreview = togglePreview;
window.updatePreview = updatePreview;
window.getLanguageGetter = getLanguageGetter;
window.getThemeGetter = getThemeGetter;
window.initializeLucideIcons = initializeLucideIcons;
window.restorePreviewVisibility = restorePreviewVisibility;
window.initializeLanguageSelect = initializeLanguageSelect;
window.highlight = highlight;
window.debouncedUpdatePreview = debouncedUpdatePreview;
window.setupKeyboardShortcuts = setupKeyboardShortcuts;
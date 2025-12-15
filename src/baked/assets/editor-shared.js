// Shared editor functionality for Pasto
// Common functions used across index.ecr and edit.ecr

// Map common language names to highlight.js names
function mapLanguage(lang) {
  if (!lang) return 'plaintext';
  const langLower = lang.toLowerCase();
  const mapping = {
    'c++': 'cpp',
    'c#': 'csharp',
    'objective-c': 'objectivec',
    'shell': 'bash',
    'dockerfile': 'docker',
    'console': 'bash',
    'text': 'plaintext',
    'plain text': 'plaintext',
    'crystal': 'ruby',  // Crystal is similar to Ruby
    'auto-detect': 'plaintext'
  };
  return mapping[langLower] || langLower;
}

// Highlight function for CodeJar
function highlight(editor, currentLanguage = '', syntaxTheme = null) {
  const code = editor.textContent;
  if (!code) return;

  const lang = currentLanguage || '';
  const mappedLang = mapLanguage(lang);

  // Get syntax theme from parameter or fallback to getter
  const theme = syntaxTheme || getThemeGetter();

  try {
    if (mappedLang !== 'plaintext' && hljs.getLanguage(mappedLang)) {
      const result = hljs.highlight(code, { language: mappedLang, ignoreIllegals: true });
      editor.innerHTML = result.value;
      // Apply syntax highlighting theme class
      editor.className = theme;
    } else if (!lang || lang === '' || mappedLang === 'plaintext') {
      // Auto-detect mode or plaintext
      const result = hljs.highlightAuto(code);
      editor.innerHTML = result.value;
      // Apply syntax highlighting theme class
      editor.className = theme;
    } else {
      // Unknown language, try auto-detection
      const result = hljs.highlightAuto(code);
      editor.innerHTML = result.value;
      // Apply syntax highlighting theme class
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
  const syntaxThemeSelect = document.querySelector('#syntax-theme') || document.getElementById('syntax-theme') || { value: getSyntaxThemeValue() };

  if (!content.trim()) {
    const previewElement = document.getElementById('preview');
    if (previewElement) {
      previewElement.innerHTML = '<pre><code>Start typing to see preview...</code></pre>';
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

  const formData = new FormData();
  formData.append('content', content);
  formData.append('language', languageSelect.value);
  formData.append('theme', syntaxThemeSelect.value || (window.pastoSyntaxTheme || 'default-dark'));

  fetch('/highlight', {
    method: 'POST',
    body: formData
  })
  .then(response => response.json())
  .then(data => {
    const previewElement = document.getElementById('preview');
    if (previewElement) {
      previewElement.innerHTML = data.html;
    }

    // Update language selector text to show detected language if auto-detection is active
    const isAutoDetect = (languageSelect.value === 'Auto' || languageSelect.value === '');

    if (isAutoDetect) {
      const autoDetectOption = Array.from(languageSelect.options || []).find(
        option => option.value === 'Auto' || option.value === ''
      );

      if (autoDetectOption) {
        if (data.detected_language) {
          autoDetectOption.textContent = `Auto (${data.detected_language})`;
        } else {
          autoDetectOption.textContent = 'Auto';
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
async function initializeLanguageSelect(languageSelectId, currentLanguage = null) {
  try {
    const response = await fetch('/api/languages');
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
window.updateLanguage = updateLanguage;
window.togglePreview = togglePreview;
window.updatePreview = updatePreview;
window.getLanguageGetter = getLanguageGetter;
window.getThemeGetter = getThemeGetter;
window.initializeLucideIcons = initializeLucideIcons;
window.restorePreviewVisibility = restorePreviewVisibility;
window.initializeLanguageSelect = initializeLanguageSelect;
window.mapLanguage = mapLanguage;
window.highlight = highlight;
window.debouncedUpdatePreview = debouncedUpdatePreview;
window.setupKeyboardShortcuts = setupKeyboardShortcuts;
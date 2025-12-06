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
function highlight(editor, currentLanguage = '') {
  const code = editor.textContent;
  if (!code) return;

  const lang = currentLanguage || '';
  const mappedLang = mapLanguage(lang);

  try {
    if (mappedLang !== 'plaintext' && hljs.getLanguage(mappedLang)) {
      const result = hljs.highlight(code, { language: mappedLang, ignoreIllegals: true });
      editor.innerHTML = result.value;
      // Apply CodeJar theme class
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      editor.className = isDark ? 'atom-one-dark' : 'atom-one-light';
    } else if (!lang || lang === '' || mappedLang === 'plaintext') {
      // Auto-detect mode or plaintext
      const result = hljs.highlightAuto(code);
      editor.innerHTML = result.value;
      // Apply CodeJar theme class
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      editor.className = isDark ? 'atom-one-dark' : 'atom-one-light';
    } else {
      // Unknown language, try auto-detection
      const result = hljs.highlightAuto(code);
      editor.innerHTML = result.value;
      // Apply CodeJar theme class
      const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
      editor.className = isDark ? 'atom-one-dark' : 'atom-one-light';
    }
  } catch (e) {
    console.error('Highlight error:', e);
    // Fallback to plain text
    editor.textContent = code;
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

  const formData = new FormData();
  formData.append('content', content);
  formData.append('language', languageSelect.value);
  formData.append('theme', syntaxThemeSelect.value || 'monokai');

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

// Export functions for use in templates
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    mapLanguage,
    highlight,
    debouncedUpdatePreview,
    updatePreview,
    togglePreview
  };
}
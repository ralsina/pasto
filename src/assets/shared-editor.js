// Shared editor functionality for both index and edit pages

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

// Toggle preview visibility
function togglePreview(jar, getLanguage, getTheme) {
  if (typeof window.togglePreview === 'function') {
    window.togglePreview(jar, getLanguage, getTheme);
  }

  // Update preview visibility preference
  const container = document.getElementById('editor-preview-container');
  const isHidden = container.classList.contains('preview-hidden');

  const showButton = document.getElementById('controls-show-preview-button');
  const hideButton = document.getElementById('controls-hide-preview-button');

  if (showButton && hideButton) {
    if (isHidden) {
      showButton.style.display = 'flex';
      hideButton.style.display = 'none';
    } else {
      showButton.style.display = 'none';
      hideButton.style.display = 'flex';
    }
  }
}

// Update preview with current content
function updatePreview(jar, getLanguage, getTheme) {
  if (typeof window.updatePreview === 'function') {
    window.updatePreview(jar, getLanguage, getTheme);
  }
}

// Get language value from select element
function getLanguageGetter() {
  const languageSelect = document.getElementById('language');
  return languageSelect ? languageSelect.value : '';
}

// Get theme value from select element
function getThemeGetter() {
  const themeElement = document.querySelector('#syntax-theme') || document.getElementById('syntax-theme');
  return themeElement ? themeElement.value : 'monokai';
}

// Initialize Lucide icons
function initializeLucideIcons() {
  if (window.lucide) {
    window.lucide.createIcons();
  }
}

// Debounced preview update
function createDebouncedPreviewUpdate(jar, getLanguage, getTheme) {
  let debounceTimer;

  return (delay = 300) => {
    return (callback) => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(callback, delay);
    };
  };
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
// Mobile controls functionality for Pasto
// Handles responsive behavior and mobile-specific UI adjustments

// Handle mobile controls placement and behavior
function handleMobileControls() {
  const sidebar = document.getElementById('sidebar');
  const mainControls = document.getElementById('main-controls');
  const mobileControls = document.getElementById('mobile-controls');

  if (!sidebar || !mainControls || !mobileControls) return;

  const isMobile = window.innerWidth <= 768;
  const isCollapsed = sidebar.classList.contains('collapsed');

  if (isMobile) {
    // Move controls to sidebar on mobile
    const controlsHTML = Array.from(mainControls.children);

    // Clear mobile controls first
    mobileControls.innerHTML = '';

    // Group controls into rows for better mobile layout
    const firstRow = document.createElement('div');
    firstRow.className = 'controls-row';

    controlsHTML.forEach(el => {
      const mobileTitleInput = el.querySelector('#paste-title');
      const mobileLanguageSelect = el.querySelector('#language');
      const button = el.querySelector('button');

      // Handle title input
      if (mobileTitleInput) {
        const mobileTitleInputClone = mobileTitleInput.cloneNode(true);
        mobileTitleInputClone.id = ''; // Remove ID to prevent duplicates
        mobileTitleInputClone.className = 'controls-input mobile-input';

        const wrapper = document.createElement('div');
        wrapper.className = 'mobile-control-item';
        wrapper.appendChild(mobileTitleInputClone);
        firstRow.appendChild(wrapper);
      }

      // Handle language selector
      if (mobileLanguageSelect) {
        const mobileLanguageSelectClone = mobileLanguageSelect.cloneNode(true);
        mobileLanguageSelectClone.id = ''; // Remove ID to prevent duplicates
        mobileLanguageSelectClone.className = 'controls-select mobile-select';

        const wrapper = document.createElement('div');
        wrapper.className = 'mobile-control-item';
        wrapper.appendChild(mobileLanguageSelectClone);
        firstRow.appendChild(wrapper);

        // Re-attach onchange event
        mobileLanguageSelectClone.addEventListener('change', function() {
          if (typeof updateLanguage === 'function') {
            updateLanguage();
          }
        });
      }

      // Handle action buttons (Create Paste, Save, Toggle Preview, etc.)
      const buttons = el.matches('button') ? [el] : Array.from(el.querySelectorAll('button'));

      buttons.forEach(buttonEl => {
        if (buttonEl && buttonEl.textContent.trim() &&
            !buttonEl.textContent.includes('Help') &&
            !buttonEl.textContent.includes('Profile')) {
          const mobileButton = buttonEl.cloneNode(true);
          mobileButton.id = ''; // Remove ID to prevent duplicates
          mobileButton.className = 'controls-button mobile-button';

          // Re-attach click event
          if (buttonEl.onclick) {
            mobileButton.onclick = buttonEl.onclick;
          }

          const wrapper = document.createElement('div');
          wrapper.className = 'mobile-control-item';
          wrapper.appendChild(mobileButton);
          firstRow.appendChild(wrapper);
        }
      });

      // Handle Help and Profile links (which are anchor tags)
      const links = el.matches('a') ? [el] : Array.from(el.querySelectorAll('a'));
      links.forEach(linkEl => {
        if (linkEl && (linkEl.textContent.includes('Help') || linkEl.textContent.includes('Profile'))) {
          const mobileLink = linkEl.cloneNode(true);
          mobileLink.className = 'controls-button mobile-button';
          mobileLink.style.textDecoration = 'none';
          mobileLink.style.display = 'flex';
          mobileLink.style.alignItems = 'center';
          mobileLink.style.justifyContent = 'center';

          const wrapper = document.createElement('div');
          wrapper.className = 'mobile-control-item';
          wrapper.appendChild(mobileLink);
          firstRow.appendChild(wrapper);
        }
      });
    });

    mobileControls.appendChild(firstRow);
    mobileControls.style.display = 'block';

    // Hide desktop controls on mobile
    mainControls.style.display = 'none';

    // Force sidebar styles on mobile
    if (sidebar) {
      sidebar.style.position = 'relative';
      sidebar.style.left = '0';
      sidebar.style.top = '0';
      sidebar.style.marginLeft = '0';
      sidebar.style.transform = 'translateX(0)';
      sidebar.style.width = '100%';
      sidebar.style.height = 'auto';
      sidebar.style.zIndex = '1000';
    }

  } else {
    // Desktop mode - restore desktop controls
    mainControls.style.display = '';
    mobileControls.style.display = 'none';
    mobileControls.innerHTML = '';

    // Restore desktop sidebar behavior
    if (sidebar && !isCollapsed) {
      sidebar.style.position = '';
      sidebar.style.left = '';
      sidebar.style.top = '';
      sidebar.style.marginLeft = '';
      sidebar.style.transform = '';
      sidebar.style.width = '';
      sidebar.style.height = '';
      sidebar.style.zIndex = '';
    }
  }
}

// Initialize mobile controls on page load
function initializeMobileControls() {
  handleMobileControls();

  // Add resize listener for responsive behavior
  let resizeTimer;
  window.addEventListener('resize', function() {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(handleMobileControls, 150);
  });

  // Also re-handle when sidebar state changes
  const sidebar = document.getElementById('sidebar');
  if (sidebar) {
    const observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
          setTimeout(handleMobileControls, 10);
        }
      });
    });
    observer.observe(sidebar, { attributes: true });
  }
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeMobileControls);
} else {
  initializeMobileControls();
}

// Export for use in templates
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    handleMobileControls,
    initializeMobileControls
  };
}
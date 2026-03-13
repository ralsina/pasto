// Function to handle mobile controls placement - simplified version
function handleMobileControls() {
  const sidebar = document.getElementById('sidebar');
  const mainControls = document.getElementById('main-controls');
  const mobileControls = document.getElementById('mobile-controls');
  const isMobile = window.innerWidth <= 768;

  if (!sidebar || !mainControls || !mobileControls) return;

  if (isMobile) {
    // Fix mobile sidebar positioning
    sidebar.style.marginLeft = '0';
    sidebar.style.transform = 'translateX(0)';

    // Hide main controls on mobile
    mainControls.style.display = 'none';

    // Move all controls from main to mobile sidebar
    const controlsGroup = mainControls.querySelector('.controls-group');
    if (controlsGroup) {
      // Create a clean mobile controls group
      const mobileControlsGroup = document.createElement('div');
      mobileControlsGroup.className = 'controls-group';

      // Clear and repopulate mobile controls
      mobileControls.innerHTML = '';
      mobileControls.appendChild(mobileControlsGroup);

      // Clone each control element individually to avoid duplicates
      const controls = Array.from(controlsGroup.children);
      controls.forEach((control, index) => {
        const mobileControl = control.cloneNode(true);

        // Remove original ID to avoid duplicates and create unique mobile ID
        const originalId = mobileControl.id;
        mobileControl.id = originalId ? `mobile-${originalId}` : `mobile-control-${index}`;

        // Add mobile-specific class for styling
        mobileControl.classList.add('mobile-control');

        // Add proper labels and accessibility attributes
        if (mobileControl.matches('input')) {
          if (!mobileControl.hasAttribute('aria-label')) {
            const placeholder = mobileControl.getAttribute('placeholder');
            const type = mobileControl.getAttribute('type');
            let label = placeholder;

            if (!label) {
              if (type === 'text') {
                label = 'Title input';
              } else if (type === 'hidden') {
                label = 'Hidden input field';
              } else if (type) {
                label = `${type} input`;
              } else {
                label = `Input field ${index + 1}`;
              }
            }

            mobileControl.setAttribute('aria-label', label);
          }
        }

        if (mobileControl.matches('select')) {
          if (!mobileControl.hasAttribute('aria-label')) {
            const existingLabel = mobileControl.getAttribute('aria-label');
            const id = mobileControl.id;
            let label = existingLabel;

            if (!label && id) {
              if (id.includes('language')) {
                label = 'Programming language selector';
              } else if (id.includes('expiration')) {
                label = 'Expiration time selector';
              } else if (id.includes('theme')) {
                label = 'Theme selector';
              } else {
                label = `Selector ${index + 1}`;
              }
            } else if (!label) {
              label = `Select option ${index + 1}`;
            }

            mobileControl.setAttribute('aria-label', label);
          }
        }

        if (mobileControl.matches('button') && !mobileControl.hasAttribute('aria-label')) {
          const label = mobileControl.getAttribute('title') || mobileControl.textContent.trim() || `Button ${index + 1}`;
          mobileControl.setAttribute('aria-label', label);
        }

        if (mobileControl.matches('a') && !mobileControl.hasAttribute('aria-label')) {
          const label = mobileControl.textContent.trim() || mobileControl.getAttribute('title') || `Link ${index + 1}`;
          mobileControl.setAttribute('aria-label', label);
        }

        // Remove form attributes that cause duplication issues and add proper autocomplete
        if (mobileControl.hasAttribute('name')) {
          mobileControl.removeAttribute('name');
        }

        // Add appropriate autocomplete attributes based on input type and context
        if (mobileControl.matches('input')) {
          const type = mobileControl.getAttribute('type');
          const id = mobileControl.id || originalId;
          const placeholder = mobileControl.getAttribute('placeholder');

          let autocomplete = 'off'; // Default for security

          if (placeholder && placeholder.toLowerCase().includes('title')) {
            autocomplete = 'off'; // Titles are free-form
          } else if (id && id.includes('title')) {
            autocomplete = 'off';
          } else if (id && id.includes('username')) {
            autocomplete = 'username';
          } else if (id && id.includes('email')) {
            autocomplete = 'email';
          } else if (id && id.includes('password')) {
            autocomplete = 'current-password';
          } else if (id && id.includes('name')) {
            autocomplete = 'name';
          } else if (id && id.includes('url') || id.includes('website')) {
            autocomplete = 'url';
          }

          // Don't override existing autocomplete unless it's missing
          if (!mobileControl.hasAttribute('autocomplete')) {
            mobileControl.setAttribute('autocomplete', autocomplete);
          }
        }


        mobileControlsGroup.appendChild(mobileControl);
      });

      // Re-attach event handlers and recreate icons
      setTimeout(() => {
        // Re-attach handlers for each control by matching with originals
        controls.forEach((originalControl, index) => {
          const mobileControl = mobileControlsGroup.children[index];
          if (!mobileControl) return;

          // Handle select change handlers
          if (mobileControl.matches('select')) {
            if (originalControl.onchange || originalControl.getAttribute('onchange')) {
              mobileControl.addEventListener('change', () => {
                // Sync the original (desktop) dropdown with the mobile dropdown
                originalControl.value = mobileControl.value;

                if (typeof window.updateLanguage === 'function') {
                  window.updateLanguage();
                }
              });
            }
          }

          // Handle button click handlers
          if (mobileControl.matches('button')) {
            if (originalControl.onclick) {
              mobileControl.onclick = originalControl.onclick;
            }
            if (originalControl.getAttribute('onclick')) {
              mobileControl.setAttribute('onclick', originalControl.getAttribute('onclick'));
            }
          }

          // Handle any other onclick events
          if (originalControl.onclick) {
            mobileControl.onclick = originalControl.onclick;
          }
          if (originalControl.getAttribute('onclick')) {
            mobileControl.setAttribute('onclick', originalControl.getAttribute('onclick'));
          }
        });

        // Re-create Lucide icons using shared utility
        if (window.SharedIcons) {
          window.SharedIcons.init(mobileControls);
        } else if (typeof lucide !== 'undefined') {
          lucide.createIcons();
        }
      }, 50);
    }
  } else {
    // On desktop, show main controls and clear mobile controls
    mainControls.style.display = 'block';
    mobileControls.innerHTML = '';

    // Reset desktop styles
    sidebar.style.marginLeft = '';
    sidebar.style.transform = '';
  }
}
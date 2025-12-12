# Version History Diff Display - UX-Focused Implementation Plan

## Core UX Philosophy
Create an intuitive, beautiful diff viewing experience that feels natural within Pasto's clean design while providing professional-grade diff visualization.

## Visual Design & Layout

### Primary Display Patterns
**Side-by-Side View (Desktop Default)**
- Clean two-column layout with subtle borders
- Synchronized scrolling between panes
- Visual connection lines showing relationships between changes
- Minimal, readable interface using Pico CSS tokens

**Unified View (Mobile Optimized)**
- Single-column layout for small screens
- Clear +/- indicators with color coding
- Expandable context sections (show "23 unchanged lines")
- Touch-friendly 44px minimum touch targets

### Color Scheme (Accessible & Pico-Compatible)
- **Additions**: Green (`--pico-ins-color: #2da44e`) with `+` icons
- **Deletions**: Red (`--pico-del-color: #cf222e`) with `-` icons
- **Modifications**: Amber (`--pico-mark-color: #fb8500`) with `~` icons
- **High contrast mode support**: Respect user preferences
- **Pattern fills**: Subtle patterns for color-blind users

### Visual Hierarchy
```css
.diff-header {
  background: var(--pico-background-color);
  border-bottom: 1px solid var(--pico-border-color);
  padding: 1rem;
}

.diff-container {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  height: 100%;
}

.diff-pane {
  border: 1px solid var(--pico-primary);
  border-radius: var(--pico-border-radius);
  overflow: hidden;
}

.diff-line {
  display: flex;
  align-items: center;
  padding: 0.25rem 0.5rem;
  font-family: 'Chivo Mono', monospace;
  min-height: 44px; /* Touch target size */
}

.diff-line:hover {
  background: var(--pico-secondary-hover-background);
  transition: background 0.2s ease;
}

.diff-added { background: rgba(45, 164, 78, 0.1); }
.diff-removed { background: rgba(207, 34, 46, 0.1); }
.diff-modified { background: rgba(251, 133, 0, 0.1); }
```

## Information Architecture

### Progressive Disclosure Strategy
**Always Visible (At a Glance):**
- Clean header with version comparison: "v3 → v4" or timestamps
- Summary statistics: "+42 -15 ~8" (added/removed/modified)
- Toggle button for unified/side-by-side view
- Quick navigation: next/previous change buttons

**On-Demand (Expandable):**
- "Show X more lines" for context
- Character-level differences within changed lines
- Full file metadata (author, timestamps, size changes)

### Large Diff Handling
- **Smart chunking**: Group changes into logical blocks
- **Summaries**: "23 unchanged lines" collapsed sections
- **Virtual scrolling**: For very large files
- **Jump navigation**: "Next change" / "Previous change" buttons

### Metadata Display
```html
<div class="diff-header">
  <nav aria-label="breadcrumb">
    <ul>
      <li><a href="/">Home</a></li>
      <li><a href="/abc123">Paste "abc123"</a></li>
      <li><a href="/abc123/history">History</a></li>
      <li>Diff v2→v3</li>
    </ul>
  </nav>

  <div class="diff-summary">
    <span class="diff-stat added">+42</span>
    <span class="diff-stat removed">-15</span>
    <span class="diff-stat modified">~8</span>
  </div>

  <div class="diff-controls">
    <button id="toggle-view">Toggle View</button>
    <button id="download-patch">Download Patch</button>
    <button id="copy-link">Copy Link</button>
  </div>
</div>
```

## Interactive Elements

### Desktop Interactions
- **Hover effects**: Subtle highlighting on line hover
- **Keyboard shortcuts**: `j/k` for navigation, `Ctrl+D` for view toggle
- **Smooth transitions**: 0.2s ease animations
- **Context menus**: Right-click for copy/download options

### Mobile Interactions
- **Tap to expand**: Large touch targets
- **Swipe gestures**: Natural left/right for navigation
- **Pinch to zoom**: For detailed code inspection
- **Floating action buttons**: Primary actions fixed position

### Keyboard Navigation
```javascript
// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

  switch(e.key) {
    case 'j': navigateToNextChange(); break;
    case 'k': navigateToPreviousChange(); break;
    case ' ':
      e.preventDefault();
      toggleCurrentChunk();
      break;
    case 'g': navigateToFirstChange(); break;
    case 'G': navigateToLastChange(); break;
    case 'd':
      if (e.ctrlKey) {
        e.preventDefault();
        toggleViewMode();
      }
      break;
  }
});
```

## Responsive Design

### Breakpoint Strategy
**Desktop (>768px):**
- Side-by-side view with synchronized scrolling
- Full keyboard navigation
- Rich hover states and tooltips

**Tablet (768px-1024px):**
- Optional side-by-side with configurable width
- Touch-optimized controls
- Simplified toolbar

**Mobile (<768px):**
- Unified view as default (side-by-side impractical)
- Swipe gesture support
- Fixed bottom toolbar for primary actions
- Simplified metadata display

### Mobile-First CSS
```css
@media (max-width: 768px) {
  .diff-container {
    grid-template-columns: 1fr; /* Single column */
  }

  .diff-line {
    min-height: 44px; /* Touch target size */
    padding: 0.75rem;
  }

  .diff-controls {
    position: fixed;
    bottom: 1rem;
    right: 1rem;
    z-index: 100;
    display: flex;
    gap: 0.5rem;
  }

  .diff-header {
    padding: 0.75rem;
  }

  .diff-summary {
    font-size: 0.875rem;
  }
}
```

## Technical Implementation

### Core Components
1. **Diff Viewer Template** (`src/views/_diff_viewer.ecr`)
   - Responsive layout with side-by-side and unified modes
   - Integration with existing Tartrazine syntax highlighting
   - Pico CSS styling with custom diff colors

2. **Diff Service** (`src/services/diff_service.cr`)
   - Crystal-based diff generation
   - Chunking and optimization for large files
   - Integration with existing Sepia version system

3. **JavaScript Module** (`src/assets/diff-viewer.js`)
   - Interactive features (expand/collapse, navigation)
   - Touch gesture support for mobile
   - Keyboard shortcuts handling

### New Routes
```crystal
# Add to server.cr
get "/:id/diff/:from/:to" do |env|
  # Compare version :from to version :to
  paste_id = env.params.url["id"]
  from_version = env.params.url["from"].to_i
  to_version = env.params.url["to"].to_i

  # Validate access permissions
  access_result = validate_paste_access(env)
  return unless access_result.allowed

  # Generate diff
  diff_data = DiffService.compare_versions(paste_id, from_version, to_version)

  render "src/views/diff_view.ecr"
end

get "/:id/diff" do |env|
  # Compare current to previous version
  paste_id = env.params.url["id"]

  # Get current and previous versions
  current = Paste.latest(paste_id)
  versions = Paste.versions(paste_id)
  previous = versions[-2] if versions.size >= 2

  if previous
    env.redirect "/#{paste_id}/diff/#{previous.generation}/#{current.generation}"
  else
    env.redirect "/#{paste_id}"
  end
end

# AJAX endpoint for lazy loading
get "/api/:id/diff/:from/:to/chunks" do |env|
  # Return diff chunks for large files
end
```

### Diff Service Structure
```crystal
module DiffService
  struct DiffResult
    property additions : Int32
    property removals : Int32
    property modifications : Int32
    property chunks : Array(DiffChunk)
    property metadata : DiffMetadata
  end

  struct DiffChunk
    property type : Symbol # :added, :removed, :modified, :context
    property lines : Array(String)
    property line_numbers : Range(Int32, Int32)
    property expandable : Bool
  end

  def self.compare_versions(paste_id : String, from_gen : Int32, to_gen : Int32) : DiffResult
    from_paste = Paste.load(Paste, paste_id, generation: from_gen)
    to_paste = Paste.load(Paste, paste_id, generation: to_gen)

    generate_diff(from_paste.content, to_paste.content)
  end

  private def self.generate_diff(old_content : String, new_content : String) : DiffResult
    # Use Crystal's built-in diff capabilities or add a shard
    # Implementation details here
  end
end
```

### Frontend JavaScript
```javascript
class DiffViewer {
  constructor(container, options = {}) {
    this.container = container;
    this.options = {
      mode: 'side-by-side', // 'side-by-side' | 'unified'
      language: 'plaintext',
      theme: 'default-dark',
      ...options
    };

    this.init();
  }

  init() {
    this.setupLayout();
    this.bindEvents();
    this.setupKeyboardShortcuts();
    this.setupTouchGestures();
  }

  setupLayout() {
    if (this.isMobile()) {
      this.options.mode = 'unified';
    }

    this.renderDiff();
    this.updateViewToggle();
  }

  bindEvents() {
    document.getElementById('toggle-view').addEventListener('click', () => {
      this.toggleViewMode();
    });

    document.getElementById('expand-all').addEventListener('click', () => {
      this.expandAllChunks();
    });

    document.getElementById('collapse-all').addEventListener('click', () => {
      this.collapseAllChunks();
    });
  }

  setupKeyboardShortcuts() {
    // Implementation for keyboard navigation
  }

  setupTouchGestures() {
    // Implementation for mobile gestures
  }

  toggleViewMode() {
    this.options.mode = this.options.mode === 'side-by-side' ? 'unified' : 'side-by-side';
    this.renderDiff();
  }

  renderDiff() {
    // Render diff based on current mode
  }
}
```

## Performance Optimizations

### Client-Side Optimizations
- **Lazy loading**: Load context lines on demand
- **Virtual scrolling**: For very large diffs
- **Debounced rendering**: Prevent layout thrashing
- **Efficient DOM updates**: Minimize reflows

### Server-Side Optimizations
- **Caching**: Cache diff calculations in `Pasto::Cache`
- **Chunked responses**: Stream large diffs
- **Background processing**: Generate diffs asynchronously
- **Rate limiting**: Prevent abuse of diff generation

### Caching Strategy
```crystal
# In DiffService
def self.compare_versions_cached(paste_id : String, from_gen : Int32, to_gen : Int32) : DiffResult
  cache_key = "diff:#{paste_id}:#{from_gen}:#{to_gen}"

  if cached = Pasto::Cache.get(cache_key)
    return cached
  end

  diff_result = compare_versions(paste_id, from_gen, to_gen)
  Pasto::Cache.set(cache_key, diff_result, expires_in: 1.hour)

  diff_result
end
```

## Accessibility Considerations

### Screen Reader Support
- **Semantic HTML**: Proper heading structure and landmarks
- **ARIA labels**: Describe diff functionality
- **Skip links**: Allow navigation to main content
- **Live regions**: Announce changes dynamically

### Keyboard Accessibility
- **Full keyboard navigation**: All interactive elements reachable
- **Visible focus indicators**: Clear focus states
- **Predictable tab order**: Logical navigation flow
- **Keyboard shortcuts**: Documented and discoverable

### Visual Accessibility
- **High contrast**: Support for high contrast mode
- **Text scaling**: Respect user font size preferences
- **Color independence**: Don't rely on color alone
- **Motion reduction**: Respect `prefers-reduced-motion`

## Success Metrics
- Users can quickly understand changes at a glance
- Mobile users can navigate diffs with touch gestures
- Performance remains smooth for large files (>1000 lines)
- Interface feels intuitive to GitHub/GitLab users
- Maintains Pasto's clean, minimal aesthetic
- WCAG 2.1 AA accessibility compliance
- Load time < 2 seconds for typical diffs

## Implementation Timeline

### Phase 1: Foundation (Week 1-2)
- Add Crystal diff library
- Create basic diff service
- Implement simple unified diff view
- Add basic routes and templates

### Phase 2: Enhanced UX (Week 3-4)
- Implement side-by-side view
- Add responsive design
- Create interactive JavaScript components
- Add keyboard shortcuts

### Phase 3: Polish & Optimization (Week 5-6)
- Performance optimizations
- Accessibility improvements
- Mobile touch gestures
- Advanced features (character diffs, export)

This UX-focused plan prioritizes user experience over technical complexity, ensuring the diff feature feels natural and enhances Pasto's existing functionality while maintaining the application's clean, minimal design aesthetic.
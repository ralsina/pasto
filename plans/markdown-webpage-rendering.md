# Markdown Webpage Rendering

**Status**: ✅ COMPLETED (2025-12-19)

## Implementation Summary

Successfully implemented client-side markdown rendering using marked.js:
- ✅ Rendered markdown view (default display)
- ✅ Toggle to source view with syntax highlighting
- ✅ Clean styling matching Pico CSS theme
- ✅ GFM support (tables, task lists, etc.)
- ✅ Proper XSS protection with DOMPurify
- ✅ Works with encryption, burn-after-reading, and all existing features

Live example: https://pasto1.ralsina.me/1b43a656-d7a0-4ffa-ace5-c257c137081b.7

---

## Overview

Add support for rendering Markdown pastes as formatted webpages instead of syntax-highlighted code blocks. This enables Pasto to serve as a quick throwaway webpage creator while maintaining all existing features (encryption, burn-after-reading, expiration, etc.).

## Use Cases

- Quick documentation/notes with shareable links
- Temporary landing pages or announcements
- Collaborative drafts (with forking feature)
- Encrypted meeting notes with burn-after-reading
- Formatted README files or changelogs
- Temporary blogs or articles

## User Experience

### Default Behavior
When viewing a paste with language="markdown":
- **Rendered View** (default): Display formatted HTML with proper styling
- **Source View** toggle: Show raw markdown in syntax-highlighted code block
- Edit mode: Always shows raw markdown in editor

### Toggle Mechanism
Add a "View Source" / "View Rendered" button in the paste controls that switches between:
1. Formatted HTML output (default)
2. Syntax-highlighted markdown source

## Technical Implementation

### Architecture: Client-Side Rendering

Using **marked.js** for client-side markdown rendering provides:
- Zero backend changes (no Crystal dependencies)
- Fast implementation (~30 minutes)
- Consistent with existing client-side features (encryption, preview)
- Easy plugin integration (Mermaid, KaTeX)
- Better API design (clients receive raw markdown)

### 1. Add JavaScript Dependencies

**Files to download/add to `src/baked/assets/`:**

1. **marked.js** (~25KB minified)
   - Source: https://cdn.jsdelivr.net/npm/marked/marked.min.js
   - Latest: v11.x
   - License: MIT

2. **DOMPurify** (~20KB minified) - for XSS protection
   - Source: https://cdn.jsdelivr.net/npm/dompurify/dist/purify.min.js
   - Latest: v3.x
   - License: Apache-2.0

Or use CDN links in production (with SRI hashes for security).

### 2. Update Paste Display Logic

**File**: `src/views/show.ecr`

Add conditional rendering based on language detection:

```ecr
<% if paste.language == "markdown" %>
  <!-- Rendered markdown view (default) -->
  <div id="markdown-rendered" class="markdown-content">
    <%== Pasto::MarkdownHelper.render_markdown(paste.content) %>
  </div>
  
  <!-- Source view (hidden by default) -->
  <div id="markdown-source" style="display: none;">
    <pre><code class="language-markdown"><%= HTML.escape(paste.content) %></code></pre>
  </div>
<% else %>
  <!-- Existing syntax highlighting code -->
  <pre><code class="language-<%= paste.language %>">
    <%= paste.highlighted_content %>
  </code></pre>
<% end %>
```

### 5. Add Toggle Controls

**File**: `src/views/show.ecr` (controls section)

Add toggle button for markdown pastes:

```ecr
<% if paste.language == "markdown" %>
  <button id="toggle-markdown-view" 
          onclick="toggleMarkdownView()" 
          class="controls-button"
          title="View Source">
    <i data-lucide="code"></i>
  </button>
<% end %>
```

JavaScript function (add to show.ecr or shared JS file):

```javascript
function toggleMarkdownView() {
  const rendered = document.getElementById('markdown-rendered');
  const source = document.getElementById('markdown-source');
  const button = document.getElementById('toggle-markdown-view');
  const icon = button.querySelector('i');
  
  if (rendered.style.display === 'none') {
    // Switch to rendered view
    rendered.style.display = 'block';
    source.style.display = 'none';
    icon.setAttribute('data-lucide', 'eye');
    button.title = 'View Source';
    lucide.createIcons(); // Refresh Lucide icons
  } else {
    // Switch to source view
    rendered.style.display = 'none';
    source.style.display = 'block';
    icon.setAttribute('data-lucide', 'code');
    button.title = 'View Rendered';
    lucide.createIcons();
  }
}
```

### 6. Style Markdown Content

**File**: `src/views/show.ecr` or dedicated CSS

Add styling for rendered markdown to match Pico CSS theme:

```css
.markdown-content {
  padding: var(--pico-spacing);
  line-height: 1.6;
  max-width: 100%;
}

.markdown-content h1,
.markdown-content h2,
.markdown-content h3,
.markdown-content h4,
.markdown-content h5,
.markdown-content h6 {
  margin-top: 1.5em;
  margin-bottom: 0.5em;
  font-weight: 600;
}

.markdown-content code {
  background: var(--pico-code-background-color);
  padding: 0.2em 0.4em;
  border-radius: 3px;
  font-family: var(--pico-font-family-monospace);
  font-size: 0.9em;
}

.markdown-content pre {
  background: var(--pico-code-background-color);
  padding: 1em;
  border-radius: 5px;
  overflow-x: auto;
  margin: 1em 0;
}

.markdown-content pre code {
  background: none;
  padding: 0;
}

.markdown-content table {
  width: 100%;
  border-collapse: collapse;
  margin: 1em 0;
}

.markdown-content th,
.markdown-content td {
  border: 1px solid var(--pico-muted-border-color);
  padding: 0.5em;
  text-align: left;
}

.markdown-content th {
  background: var(--pico-card-background-color);
  font-weight: 600;
}

.markdown-content blockquote {
  border-left: 4px solid var(--pico-primary);
  padding-left: 1em;
  margin: 1em 0;
  color: var(--pico-muted-color);
  font-style: italic;
}

.markdown-content a {
  color: var(--pico-primary);
  text-decoration: underline;
}

.markdown-content a:hover {
  text-decoration: none;
}

.markdown-content img {
  max-width: 100%;
  height: auto;
  border-radius: 5px;
}

.markdown-content ul,
.markdown-content ol {
  padding-left: 2em;
  margin: 1em 0;
}

.markdown-content li {
  margin: 0.5em 0;
}

.markdown-content hr {
  border: none;
  border-top: 1px solid var(--pico-muted-border-color);
  margin: 2em 0;
}

/* GFM Extensions */
.markdown-content input[type="checkbox"] {
  margin-right: 0.5em;
}

.markdown-content del {
  color: var(--pico-muted-color);
}
```

## Code Highlighting in Markdown

### Option 1: Use Highlight.js (Recommended for client-side)

Add highlight.js for automatic code block syntax highlighting:

```html
<!-- Add to layout.ecr -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/styles/github-dark.min.css">
<script src="https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/highlight.min.js"></script>
```

Then in the markdown rendering script:

```javascript
function highlightMarkdownCodeBlocks() {
  document.querySelectorAll('#markdown-rendered pre code').forEach((block) => {
    hljs.highlightElement(block);
  });
}
```

### Option 2: Use Tartrazine via API

## Preview Support

Update the existing preview feature to render markdown:

**File**: `src/baked/assets/editor-shared.js` or inline in editor template

```javascript
// In the preview rendering function
function renderPreview(code, language, theme) {
  if (language === 'markdown') {
    // Render markdown client-side
    const renderedHTML = marked.parse(code);
    const cleanHTML = DOMPurify.sanitize(renderedHTML);
    previewContainer.innerHTML = cleanHTML;
    
    // Apply syntax highlighting to code blocks in preview
    highlightMarkdownCodeBlocks();
  } else {
    // Existing syntax highlighting preview
    fetchHighlightedCode(code, language, theme);
  }
}
```
  for (const block of codeBlocks) {
    const language = block.className.replace('language-', '') || 'text';
    const code = block.textContent;
    
    try {
      const response = await fetch('/api/v1/highlight', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ language, code, theme: getCurrentTheme() })
      });
      
      const data = await response.json();
      block.innerHTML = data.highlighted_html;
    } catch (err) {
      console.error('Failed to highlight code block:', err);
    }
  }
}
```

### Option 3: Keep it Simple

Just apply basic styling without syntax highlighting:

```css
.markdown-content pre code {
  display: block;
  background: var(--pico-code-background-color);
  color: var(--pico-code-color);
  font-family: var(--pico-font-family-monospace);
## API Considerations

The REST API returns raw markdown (no changes needed):

```json
{
  "id": "abc123",
  "content": "# Hello World\n\nThis is markdown.",
  "language": "markdown",
  "content_type": "text/markdown"
}
```

**Benefits of client-side approach:**
- API clients receive source markdown (more flexible)
- Clients can render markdown themselves if needed
- No server-side rendering overhead
- API response stays simple and cacheable

**Optional enhancement:**
Add `?render=html` query parameter for clients that want pre-rendered HTML:

```crystal
# In server.cr API endpoint
if params["render"]? == "html" && paste.language == "markdown"
  # Use markd to render server-side only when explicitly requested
  rendered_html = Pasto::MarkdownHelper.render_markdown(paste.content)
  response["rendered_html"] = rendered_html
end
```
- Updates in real-time as user types

## API Considerations

The REST API should indicate when markdown rendering is available:

```json
{
  "id": "abc123",
  "content": "# Hello World\n\nThis is markdown.",
  "language": "markdown",
  "rendered_html": "<h1>Hello World</h1><p>This is markdown.</p>",
  "content_type": "text/markdown"
}
```

Add optional `?render=true` parameter to GET requests for markdown pastes.

## Testing Checklist

## Implementation Phases

### Phase 1: Add JavaScript Libraries (15 minutes)
- Download marked.min.js and purify.min.js
- Add to `src/baked/assets/` directory
- Add script tags to layout.ecr or show.ecr
- Or use CDN with SRI hashes

### Phase 2: Update Template (30 minutes)
- Modify `show.ecr` with markdown containers
- Add hidden script tag with raw content
- Add rendering JavaScript inline
- Add toggle button to controls

### Phase 3: Styling (30 minutes)
- Add CSS for `.markdown-content` class
- Match Pico CSS theme variables
- Ensure responsive design
- Test dark/light theme compatibility

### Phase 4: Code Highlighting (30 minutes)
- Choose approach (highlight.js vs Tartrazine API vs simple)
- Implement `highlightMarkdownCodeBlocks()` function
- Test with various languages
- Ensure theme consistency

### Phase 5: Preview Integration (15 minutes)
- Update editor preview to render markdown
- Test live preview functionality
- Ensure preview matches final rendering

### Phase 6: Testing & Polish (30 minutes)
- Test all markdown features (GFM, tables, etc.)
- XSS security testing
- Mobile responsive testing
- Cross-browser testing
- Performance optimization

**Total Estimated Time**: 2.5-3 hours (down from 4-6 hours with server-side)
- Icon state management

### Phase 3: Code Highlighting (1 hour)
- Integrate Tartrazine with markdown code blocks
- Theme consistency
- Server-side vs client-side decision

### Phase 4: Polish & Testing (1-2 hours)
- Comprehensive CSS styling
- Security audit
- Cross-browser testing
- Mobile testing
- Edge case handling

**Total Estimated Time**: 4-6 hours

## Future Enhancements

- **Mermaid Diagrams**: Add diagram rendering support
- **LaTeX Math**: KaTeX integration for equations
- **Custom Themes**: Markdown-specific styling themes
- **Table of Contents**: Auto-generate TOC for long documents
- **Anchor Links**: Auto-add anchor links to headings
- **Print Stylesheet**: Optimize for printing/PDF export
- **Embed Support**: Safe embedding of videos/media
- **Custom Extensions**: Add custom markdown extensions

## Related Features

This feature complements:
- **Encryption**: Secure temporary documents
- **Burn After Reading**: One-time view documents
- **Expiration**: Auto-delete temporary pages
- **Forking**: Collaborative editing workflow
- **Version History**: Track document changes
- **SSH Interface**: Create markdown pages from terminal

## Documentation Updates

Update user documentation:
- Add markdown rendering to feature list
- Create example markdown paste
- Document toggle controls
- Add to SSH interface docs
- Update API documentation

## Success Metrics

- Number of markdown pastes created
- Ratio of rendered vs source views
- User retention for markdown feature
- Feedback on GitHub/issues

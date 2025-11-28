require "sepia"
require "hansa"
require "tartrazine"
require "html"

module Pasto
  class Paste < Sepia::Object
    include Sepia::Serializable

    property content : String
    property language : String?
    property theme : String
    property created_at : Time
    property updated_at : Time
    property user_id : String?

    def initialize(@content : String, @language : String? = nil, @theme : String = "default-dark", @user_id : String? = nil)
      @created_at = Time.utc
      @updated_at = Time.utc

      # Auto-detect language if not provided
      if @language.nil?
        @language = self.class.get_best_supported_language(@content)
      end
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        content:    @content,
        language:   @language,
        theme:      @theme,
        created_at: @created_at.to_rfc3339,
        updated_at: @updated_at.to_rfc3339,
        user_id:    @user_id,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : Paste
      data = Hash(String, JSON::Any).from_json(sepia_string)
      paste = new(
        content: data["content"].as_s,
        language: data["language"]?.try(&.as_s?),
        theme: data["theme"]?.try(&.as_s?) || "default-dark",
        user_id: data["user_id"]?.try(&.as_s?)
      )
      paste.created_at = Time.parse_rfc3339(data["created_at"].as_s)
      paste.updated_at = Time.parse_rfc3339(data["updated_at"].as_s)
      paste
    end

    # Compatibility methods
    def self.from_file(id : String) : Paste?
      Sepia::Storage.load(Paste, id)
    rescue ex
      nil
    end

    def save : Bool
      @updated_at = Time.utc
      begin
        Sepia::Storage.save(self)
        true
      rescue ex
        false
      end
    end

    def language_for_extension(ext : String?) : String
      return @language || "text" if ext.nil?

      # If ext is already a language name (not starting with dot), use it directly
      if !ext.starts_with?(".")
        return ext
      end

      # Map extensions to language names
      language_mapping = {
        ".cr"         => "crystal",
        ".py"         => "python",
        ".js"         => "javascript",
        ".ts"         => "typescript",
        ".rb"         => "ruby",
        ".php"        => "php",
        ".java"       => "java",
        ".cpp"        => "cpp",
        ".c"          => "c",
        ".cs"         => "csharp",
        ".go"         => "go",
        ".rs"         => "rust",
        ".sh"         => "bash",
        ".bash"       => "bash",
        ".zsh"        => "zsh",
        ".sql"        => "sql",
        ".html"       => "html",
        ".css"        => "css",
        ".scss"       => "scss",
        ".sass"       => "sass",
        ".json"       => "json",
        ".yaml"       => "yaml",
        ".yml"        => "yaml",
        ".xml"        => "xml",
        ".md"         => "markdown",
        ".dockerfile" => "dockerfile",
        ".makefile"   => "makefile",
        ".rust"       => "rust",
        ".toml"       => "toml",
        ".ini"        => "ini",
        ".vim"        => "vim",
        ".lua"        => "lua",
        ".perl"       => "perl",
        ".r"          => "r",
        ".scala"      => "scala",
        ".swift"      => "swift",
        ".kt"         => "kotlin",
        ".dart"       => "dart",
        ".elm"        => "elm",
        ".hs"         => "haskell",
        ".ml"         => "ocaml",
        ".clj"        => "clojure",
        ".fs"         => "fsharp",
        ".vb"         => "visualbasic",
        ".ps1"        => "powershell",
        ".bat"        => "batch",
        ".cmd"        => "batch",
        ".fish"       => "fish",
        ".ex"         => "elixir",
        ".exs"        => "elixir",
        ".erl"        => "erlang",
        ".astro"      => "astro",
        ".svelte"     => "svelte",
        ".vue"        => "vue",
        ".jsx"        => "jsx",
        ".tsx"        => "tsx",
      }

      # Normalize extension (ensure it starts with .)
      normalized_ext = ext.starts_with?('.') ? ext.downcase : ".#{ext.downcase}"

      language_mapping[normalized_ext]? || @language || "text"
    end

    def highlight(language_override : String? = nil) : {String, String}
      lang = language_override || @language || "text"

      begin
        puts "DEBUG: Highlighting with language: #{lang}, theme: #{@theme}"
        formatter = Tartrazine::Html.new(theme: Tartrazine.theme(@theme))
        lexer = Tartrazine.lexer(name: lang)
        result = formatter.format(@content, lexer)
        css = formatter.style_defs
        puts "DEBUG: Highlighting successful"
        {result, css}
      rescue ex
        puts "DEBUG: Highlighting failed for language '#{lang}' with theme '#{@theme}': #{ex.message}"
        # Fallback: escape HTML and wrap in pre
        {HTML.escape(@content), ""}
      end
    end

    def to_html(language_override : String? = nil) : String
      highlighted_content, _css_styles = highlight(language_override)

      # Get saved theme preferences or use defaults
      saved_pico_theme = "auto"
      saved_pico_color = "slate"

      # Modern HTML template matching main page design
      <<-HTML
      <!DOCTYPE html>
      <html lang="en" data-theme="#{saved_pico_theme}">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Paste #{sepia_id} - Pasto</title>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.#{saved_pico_color}.min.css">
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Chivo:wght@400;700&family=Chivo+Mono:wght@400;700&display=swap" rel="stylesheet">
        <style>
          /* Chivo fonts */
          body {
            font-family: 'Chivo', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          }

          code, pre {
            font-family: 'Chivo Mono', 'Fira Code', 'Monaco', 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
          }

          /* CSS Grid Layout */
          .app-container {
            display: grid;
            grid-template-columns: 300px 1fr;
            min-height: 100vh;
            margin: 0;
          }

          /* Sidebar */
          .sidebar {
            background-color: var(--background-color);
            border-right: 1px solid var(--border-color);
            padding: 1.5rem;
            overflow-y: auto;
          }

          .sidebar.collapsed {
            display: none;
          }

          .sidebar h3 {
            margin: 0 0 1.5rem 0;
            font-size: 1rem;
            color: var(--muted-color);
            text-transform: uppercase;
            letter-spacing: 0.05em;
          }

          .theme-group {
            margin-bottom: 1.5rem;
          }

          .theme-group label {
            display: block;
            margin-bottom: 0.5rem;
            font-size: 0.875rem;
            font-weight: 600;
          }

          /* Main Content */
          .main-content {
            padding: 1.5rem;
            overflow-y: auto;
          }

          .main-content.sidebar-collapsed {
            grid-column: 1 / -1;
          }

          /* Paste Header */
          .paste-header {
            background-color: var(--background-color);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            padding: 1.5rem;
            margin-bottom: 1.5rem;
          }

          .paste-header h2 {
            margin: 0 0 0.5rem 0;
            color: var(--primary);
          }

          .paste-header p {
            margin: 0.25rem 0;
            color: var(--muted-color);
            font-size: 0.875rem;
          }

          /* Language Selector */
          .language-selector {
            margin-top: 1rem;
          }

          .language-selector label {
            display: block;
            margin-bottom: 0.5rem;
            font-size: 0.875rem;
            font-weight: 600;
          }

          .language-selector select {
            width: 100%;
            min-width: 200px;
          }

          /* Paste Content */
          .paste-content {
            background-color: var(--background-color);
            border: 1px solid var(--border-color);
            border-radius: var(--border-radius);
            padding: 1.5rem;
            overflow-x: auto;
          }

          .paste-content pre {
            margin: 0;
            white-space: pre-wrap;
            word-wrap: break-word;
            font-family: 'Chivo Mono', 'Fira Code', 'Monaco', 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
          }

          .paste-content code {
            background: none;
            padding: 0;
            font-size: 0.875rem;
            line-height: 1.5;
          }

          /* Navigation */
          .paste-navigation {
            text-align: center;
            margin-top: 2rem;
          }

          .paste-navigation a {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            padding: 0.75rem 1.5rem;
            background-color: var(--primary);
            color: white;
            text-decoration: none;
            border-radius: var(--border-radius);
            font-weight: 600;
            transition: all 0.2s ease;
          }

          .paste-navigation a:hover {
            background-color: var(--primary-hover);
            transform: translateY(-1px);
          }

          /* Mobile Responsive */
          .mobile-menu-toggle {
            display: none;
            position: fixed;
            top: 1rem;
            left: 1rem;
            z-index: 1000;
            background-color: var(--primary);
            color: white;
            border: none;
            border-radius: 50%;
            width: 3rem;
            height: 3rem;
            cursor: pointer;
            box-shadow: var(--card-box-shadow);
          }

          .overlay {
            display: none;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: rgba(0, 0, 0, 0.5);
            z-index: 999;
          }

          @media (max-width: 768px) {
            .app-container {
              grid-template-columns: 1fr;
            }

            .sidebar {
              position: fixed;
              top: 0;
              left: 0;
              bottom: 0;
              z-index: 1000;
              width: 280px;
              transform: translateX(-100%);
              transition: transform 0.3s ease;
            }

            .sidebar.active {
              transform: translateX(0);
            }

            .sidebar.collapsed {
              display: block;
              transform: translateX(-100%);
            }

            .main-content {
              padding: 4rem 1rem 1rem;
            }

            .mobile-menu-toggle {
              display: flex;
              align-items: center;
              justify-content: center;
            }

            .overlay.active {
              display: block;
            }
          }

          /* Icon animations */
          .icon {
            display: inline-block;
            width: 1.2em;
            height: 1.2em;
            margin-right: 0.5rem;
          }

          /* Syntax highlighting improvements */
          .paste-content .line {
            display: block;
            min-height: 1.5em;
          }

          .paste-content .code {
            background: none;
            border: none;
            padding: 0;
            margin: 0;
          }
        </style>
      </head>
      <body>
        <div class="app-container">
          <!-- Mobile Menu Toggle -->
          <button class="mobile-menu-toggle" onclick="toggleSidebar()" aria-label="Toggle sidebar">
            ☰
          </button>

          <!-- Overlay for mobile -->
          <div class="overlay" onclick="toggleSidebar()"></div>

          <!-- Sidebar -->
          <aside class="sidebar" id="sidebar">
            <div class="theme-group">
              <h3>Pasto</h3>
              <p>Code pastebin with live preview</p>
            </div>

            <div class="theme-group">
              <h3>Theme Preferences</h3>

              <div>
                <label for="pico-theme">UI Theme:</label>
                <select id="pico-theme" onchange="updateThemes()">
                  <option value="auto" selected>Auto (System)</option>
                  <option value="light">Light</option>
                  <option value="dark">Dark</option>
                </select>
              </div>

              <div>
                <label for="pico-color">Color Scheme:</label>
                <select id="pico-color" onchange="updateThemes()">
                  <option value="slate" selected>Slate</option>
                  <option value="blue">Blue</option>
                  <option value="purple">Purple</option>
                  <option value="pink">Pink</option>
                  <option value="red">Red</option>
                  <option value="orange">Orange</option>
                  <option value="yellow">Yellow</option>
                  <option value="green">Green</option>
                  <option value="teal">Teal</option>
                  <option value="cyan">Cyan</option>
                  <option value="grey">Grey</option>
                  <option value="indigo">Indigo</option>
                  <option value="zinc">Zinc</option>
                  <option value="neutral">Neutral</option>
                  <option value="stone">Stone</option>
                </select>
              </div>

              <div>
                <label for="syntax-theme">Syntax Highlighting:</label>
                <select id="syntax-theme" onchange="updateSyntaxTheme()">
                  #{Pasto::Paste.generate_theme_options(@theme)}
                </select>
              </div>
            </div>
          </aside>

          <!-- Main Content -->
          <main class="main-content" id="main-content">
            <div class="paste-header">
              <hgroup>
                <h2>Paste #{sepia_id}</h2>
                <p>Created: #{@created_at.to_s("%Y-%m-%d %H:%M:%S UTC")}</p>
                <p>Language: #{language_override || @language || "text"}</p>
              </hgroup>

              <div class="language-selector">
                <label for="language">View as different language:</label>
                <select id="language" onchange="changeLanguage(this.value)">
                  <option value="">Auto-detect</option>
                  #{Pasto::Paste.generate_language_options(language_override)}
                </select>
              </div>
            </div>

            <div class="paste-content">
              #{highlighted_content}
            </div>

            <div class="paste-navigation">
              <a href="/">
                <span class="icon">←</span>
                Create New Paste
              </a>
            </div>
          </main>
        </div>

        <script>
          // Load saved themes from localStorage
          function loadSavedThemes() {
            const savedPicoTheme = localStorage.getItem('pasto_pico_theme') || 'auto';
            const savedPicoColor = localStorage.getItem('pasto_pico_color') || 'slate';
            const savedSyntaxTheme = localStorage.getItem('pasto_syntax_theme') || '#{@theme}';

            document.getElementById('pico-theme').value = savedPicoTheme;
            document.getElementById('pico-color').value = savedPicoColor;
            document.getElementById('syntax-theme').value = savedSyntaxTheme;

            applyThemes(savedPicoTheme, savedPicoColor, savedSyntaxTheme);
            updateSyntaxCSS(savedSyntaxTheme);
          }

          // Apply theme changes
          function updateThemes() {
            const picoTheme = document.getElementById('pico-theme').value;
            const picoColor = document.getElementById('pico-color').value;
            const syntaxTheme = document.getElementById('syntax-theme').value;

            // Save to localStorage
            localStorage.setItem('pasto_pico_theme', picoTheme);
            localStorage.setItem('pasto_pico_color', picoColor);
            localStorage.setItem('pasto_syntax_theme', syntaxTheme);

            // Apply to current page
            applyThemes(picoTheme, picoColor, syntaxTheme);
          }

          // Update syntax theme
          function updateSyntaxTheme() {
            const syntaxTheme = document.getElementById('syntax-theme').value;
            localStorage.setItem('pasto_syntax_theme', syntaxTheme);

            // Update syntax CSS dynamically
            updateSyntaxCSS(syntaxTheme);
          }

          function updateSyntaxCSS(themeName) {
            // Remove existing syntax CSS if present
            const existingSyntaxCSS = document.getElementById('syntax-theme-css');
            if (existingSyntaxCSS) {
              existingSyntaxCSS.remove();
            }

            // Add new syntax CSS
            const syntaxCSSLink = document.createElement('link');
            syntaxCSSLink.id = 'syntax-theme-css';
            syntaxCSSLink.rel = 'stylesheet';
            syntaxCSSLink.href = `/syntax-theme.css?theme=${themeName}`;
            document.head.appendChild(syntaxCSSLink);
          }

          function applyThemes(picoTheme, picoColor, syntaxTheme) {
            // Apply Pico theme
            document.documentElement.setAttribute('data-theme', picoTheme);

            // Update CSS link
            const cssLink = document.querySelector('link[href*="picocss"]');
            if (cssLink) {
              cssLink.href = `https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.${picoColor}.min.css`;
            }
          }

          function changeLanguage(lang) {
            if (lang) {
              window.location.href = '/#{sepia_id}.' + lang;
            } else {
              window.location.href = '/#{sepia_id}';
            }
          }

          // Toggle sidebar for mobile
          function toggleSidebar() {
            const sidebar = document.getElementById('sidebar');
            const overlay = document.querySelector('.overlay');
            const mainContent = document.getElementById('main-content');

            sidebar.classList.toggle('active');
            overlay.classList.toggle('active');
            mainContent.classList.toggle('sidebar-collapsed');
          }

          // Initialize themes on page load
          document.addEventListener('DOMContentLoaded', function() {
            loadSavedThemes();

            // Check for mobile view and start collapsed
            if (window.innerWidth <= 768) {
              const mainContent = document.getElementById('main-content');
              mainContent.classList.add('sidebar-collapsed');
            }
          });

          // Handle window resize
          window.addEventListener('resize', function() {
            const sidebar = document.getElementById('sidebar');
            const overlay = document.querySelector('.overlay');
            const mainContent = document.getElementById('main-content');

            if (window.innerWidth > 768) {
              // Desktop view
              sidebar.classList.remove('active');
              overlay.classList.remove('active');
              mainContent.classList.remove('sidebar-collapsed');
            } else if (!sidebar.classList.contains('active')) {
              // Mobile view, sidebar not active
              mainContent.classList.add('sidebar-collapsed');
            }
          });
        </script>
      </body>
      </html>
      HTML
    end

    def self.available_themes : Array(String)
      Tartrazine.themes.sort
    end

    def self.available_languages : Array(String)
      # Get all available lexers from Tartrazine
      ["Auto-detect"] + Tartrazine.lexers.sort
    end

    def self.generate_language_options(current_language : String? = nil) : String
      languages = available_languages

      # Map display names to Tartrazine lexer names
      language_mapping = {
        "C"            => "c",
        "C++"          => "cpp",
        "C#"           => "csharp",
        "Go"           => "go",
        "Rust"         => "rust",
        "Python"       => "python",
        "Python 2"     => "python_2",
        "Ruby"         => "ruby",
        "PHP"          => "php",
        "Perl"         => "perl",
        "JavaScript"   => "javascript",
        "TypeScript"   => "typescript",
        "ActionScript" => "actionscript",
        "Java"         => "java",
        "Kotlin"       => "kotlin",
        "Scala"        => "scala",
        "HTML"         => "html",
        "CSS"          => "css",
        "SCSS"         => "scss",
        "Sass"         => "sass",
        "SQL"          => "sql",
        "MySQL"        => "mysql",
        "PostgreSQL"   => "pl_pgsql",
        "Transact-SQL" => "transact-sql",
        "Bash"         => "bash",
        "Shell"        => "bash",
        "PowerShell"   => "powershell",
        "JSON"         => "json",
        "YAML"         => "yaml",
        "XML"          => "xml",
        "CSV"          => "csv",
        "Markdown"     => "markdown",
        "Dockerfile"   => "dockerfile",
        "Plain Text"   => "text",
      }

      options = [] of String

      languages.each do |lang|
        value = language_mapping[lang]? || lang.downcase.gsub(/[^a-z0-9]/, "_").gsub(/_+/, "_")
        selected = current_language && (current_language == lang || current_language == value) ? " selected" : ""

        # Handle special cases
        case lang
        when "Plain Text"
          options << %{<option value="text"#{selected}>#{lang}</option>}
        else
          options << %{<option value="#{value}"#{selected}>#{lang}</option>}
        end
      end

      options.join("\n          ")
    end

    # Get the best Tartrazine-supported language from Hansa's probable languages
    def self.get_best_supported_language(content : String) : String?
      return nil if content.empty?

      begin
        # Get all probable languages from Hansa (sorted by confidence, lowest first)
        scored_languages = Hansa::CLASSIFIER.classify(content)

        # Sort by score (highest first) to get most probable languages first
        scored_languages = scored_languages.sort_by { |lang| -lang[1] }

        # List of Tartrazine-supported lexers
        supported_lexers = Set{
          "c", "cpp", "csharp", "go", "rust",
          "python", "python_2", "ruby", "php", "perl",
          "javascript", "typescript", "actionscript",
          "java", "kotlin", "scala", "html", "css",
          "scss", "sass", "sql", "mysql", "pl_pgsql",
          "transact-sql", "bash", "powershell", "json",
          "yaml", "xml", "csv", "markdown", "dockerfile",
          "text",
        }

        # Map common Hansa language names to Tartrazine lexer names
        language_mappings = {
          "C++"        => "cpp",
          "C#"         => "csharp",
          "JavaScript" => "javascript",
          "TypeScript" => "typescript",
          "Python"     => "python",
          "Ruby"       => "ruby",
          "PHP"        => "php",
          "Java"       => "java",
          "Go"         => "go",
          "Rust"       => "rust",
          "HTML"       => "html",
          "CSS"        => "css",
          "SCSS"       => "scss",
          "SQL"        => "sql",
          "JSON"       => "json",
          "YAML"       => "yaml",
          "XML"        => "xml",
          "Markdown"   => "markdown",
          "Bash"       => "bash",
          "Shell"      => "bash",
        }

        # Find the best supported language
        scored_languages.each do |hansa_lang, score|
          # Map Hansa language name to Tartrazine lexer name
          mapped_lang = language_mappings[hansa_lang]? || hansa_lang.downcase.gsub(/[^a-z0-9_]/, "_")

          # Check if this language is supported by Tartrazine
          if supported_lexers.includes?(mapped_lang)
            puts "DEBUG: Hansa detected '#{hansa_lang}' -> mapped to '#{mapped_lang}' (score: #{score})"
            return mapped_lang
          else
            puts "DEBUG: Hansa detected '#{hansa_lang}' -> mapped to '#{mapped_lang}' but not supported by Tartrazine"
          end
        end

        # No supported language found
        puts "DEBUG: No Tartrazine-supported language found in Hansa results"
        nil
      rescue ex
        puts "DEBUG: Error getting language from Hansa: #{ex.message}"
        nil
      end
    end

    def self.popular_themes : Array(String)
      [
        "default-dark", "default-light",
        "github", "github-dark",
        "monokai", "monokailight",
        "nord", "nord-light",
        "dracula",
        "solarized-dark", "solarized-light", "solarized-dark256",
        "material", "material-darker", "material-lighter", "material-palenight", "material-vivid",
        "catppuccin-frappe", "catppuccin-latte", "catppuccin-macchiato", "catppuccin-mocha",
        "tokyonight-day", "tokyonight-moon", "tokyonight-night", "tokyonight-storm",
        "rose-pine", "rose-pine-dawn", "rose-pine-moon",
        "gruvbox-dark-hard", "gruvbox-dark-medium", "gruvbox-dark-pale", "gruvbox-dark-soft", "gruvbox-light",
        "pygments",
      ]
    end

    def self.generate_theme_options(current_theme : String? = nil) : String
      themes = available_themes
      popular = popular_themes

      # Separate popular themes from the rest
      popular_html = popular.map do |theme|
        selected = (current_theme == theme) ? "selected" : ""
        %{<option value="#{theme}" #{selected}>#{theme}</option>}
      end.join("\n                ")

      # Generate other themes (exclude popular ones)
      other_themes = themes.reject { |theme| popular.includes?(theme) }
      other_html = other_themes.map do |theme|
        selected = (current_theme == theme) ? "selected" : ""
        %{<option value="#{theme}" #{selected}>#{theme}</option>}
      end.join("\n                ")

      # Combine with optgroups for better organization
      <<-HTML
                <optgroup label="Popular Themes">
                  #{popular_html}
                </optgroup>
                <optgroup label="All Themes (A-Z)">
                  #{other_html}
                </optgroup>
      HTML
    end

    private def generate_id : String
      # Generate a short random ID
      Random::Secure.urlsafe_base64(6).gsub(/[-_]/, "").chars.first(8).join
    end
  end
end

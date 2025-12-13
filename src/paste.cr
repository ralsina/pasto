require "json"
require "sepia"
require "hansa"
require "tartrazine"
require "html"
require "./mimetypes"
require "./data/tartrazine_hljs_mapping"

module Pasto
  # Add highlight.js classes to Tartrazine CSS for compatibility
  def self.add_highlightjs_classes(css : String, theme_name : String? = nil) : String
    # Tartrazine returns minified CSS, so we need to parse it differently
    # Group selectors by highlight.js class to avoid duplicates
    hljs_to_selectors = Hash(String, Array(String)).new
    original_rules = Hash(String, String).new
    unmapped_rules = [] of String

    css.split("}").each do |rule|
      # Remove any leading/trailing whitespace and skip empty rules
      rule = rule.strip
      next if rule.empty?

      # Look for CSS selectors like ".k { color: #ff79c6; " or ".k {color: #ff79c6;"
      if match = rule.match(/^([a-z.]+)\s*\{\s*([^}]+)$/)
        tartrazine_selector = match[1]
        properties = match[2]

        # Store the original rule for this selector
        original_rules[tartrazine_selector] = properties

        # Find the corresponding highlight.js class
        if hljs_class = TARTRAZINE_TO_HLJS_MAPPING[tartrazine_selector]?
          # Group selectors by highlight.js class
          hljs_to_selectors[hljs_class] ||= [] of String
          hljs_to_selectors[hljs_class] << tartrazine_selector
        else
          # No mapping found, keep original
          unmapped_rules << "#{tartrazine_selector} { #{properties} }"
        end
      else
        # Not a CSS rule, keep as-is (add back the closing brace if it was removed)
        unmapped_rules << (rule.includes?("{") ? "#{rule}}" : rule)
      end
    end

    # Build consolidated CSS
    result = [] of String

    # Add consolidated rules for each highlight.js class
    hljs_to_selectors.each do |hljs_class, selectors|
      # Find the most generic selector (shortest, usually the base one)
      # For comments, this will be ".c" instead of ".ch", ".cp", etc.
      generic_selector = selectors.min_by(&.size)

      if properties = original_rules[generic_selector]?
        # Use only the generic selector with the hljs class
        result << "#{generic_selector}, #{hljs_class} { #{properties} }"
      end
    end

    # Add unmapped rules
    result.concat(unmapped_rules)

    # Add background color rule for editor if theme name is provided
    if theme_name
      # Add background color rule for editor - handle both base theme and full theme name
      css_class_name = theme_name.gsub("/", "-")
      base_theme_name = theme_name.split("/").first

      # Get the actual background color from the .b class (background)
      bg_color = nil
      css.split("}").each do |rule|
        rule = rule.strip
        if rule.includes?(".b") && rule.includes?("background-color:")
          if match = rule.match(/background-color:\s*#([a-fA-F0-9]{6})/)
            bg_color = "##{match[1]}"
            break
          end
        end
      end

      # Use the actual theme background color, or fallback to Pico CSS background variable
      final_bg_color = bg_color || "var(--pico-background-color)"

      # Add background color rule for editor element directly by ID
      result << "#editor { background-color: #{final_bg_color} !important; }"

      # Fix editor-wrapper margin and height
      result << ".editor-wrapper { margin: 0 !important; height: 100% !important; }"

      # Ensure editor element has proper padding and height
      result << "#editor { padding: 12px !important; height: 100% !important; min-height: 400px !important; font-size: 0.875rem !important; }"

      # Ensure preview uses same font size as editor
      result << "#preview pre, #preview pre code, #preview code, .preview-content pre, .preview-content code { font-size: 18px !important; }"
    end

    result.join("")
  end

  class Paste < Sepia::Object
    include JSON::Serializable
    include Sepia::Serializable

    property content : String
    property title : String?
    property filename : String?
    property language : String?
    property theme : String
    property created_at : Time
    property updated_at : Time
    property ssh_fingerprint : String?
    property ssh_ip : String?
    property user_id : String?

    # Encryption fields - all nullable to handle existing JSON
    property encrypted_content : String?
    property? is_encrypted : Bool = false
    property encryption_iv : String?
    property encryption_tag : String?
    property encryption_salt : String?
    property encryption_iterations : Int32 = 100000
    property? password_based : Bool = false

    # Security features
    property expires_at : Time = Time.utc(9999, 1, 1)
    property? burn_after_reading : Bool = false
    property view_count : Int32 = 0
    property? private : Bool = false

    def initialize(content : String, @language : String? = nil, @theme : String = "default-dark", @ssh_fingerprint : String? = nil, @ssh_ip : String? = nil, @user_id : String? = nil, @title : String? = nil, @filename : String? = nil)
      # Normalize line endings to just '\n'
      @content = content.gsub("\r\n", "\n").gsub("\r", "\n")

      @created_at = Time.utc
      @updated_at = Time.utc

      # Default to far-future date (1/1/9999) for no expiration
      @expires_at = Time.utc(9999, 1, 1)

      # Auto language: first from filename, then from content
      if @language.nil?
        if @filename
          ext = File.extname(@filename.as(String))
          detected = language_for_extension(ext)
          @language = detected unless detected == "text"
        end
        # If still nil, try content-based detection
        if @language.nil?
          @language = self.class.get_best_supported_language(@content)
        end
      end
    end

    # Get display title - returns explicit title or auto-generated from content
    def display_title : String
      if @title && !@title.as(String).strip.empty?
        return @title.as(String)
      end

      # Generate from first line of content
      first_line = @content.split('\n').first?.try(&.strip) || ""

      # Clean up the line (remove common comment prefixes)
      cleaned = first_line
        .gsub(/^(\/\/|#|--|\/\*|\*|;|%|--|<!--|REM\s)/i, "")
        .strip

      # Limit to ~50 chars, break at word boundary
      if cleaned.size > 50
        truncated = cleaned[0..50]
        # Try to break at last space
        if last_space = truncated.rindex(' ')
          truncated = truncated[0...last_space]
        end
        cleaned = truncated + "..."
      end

      cleaned.empty? ? "Untitled paste" : cleaned
    end

    # Sepia serialization methods
    def to_sepia : String
      to_json()
    end

    def self.from_sepia(sepia_string : String) : Paste
      from_json(sepia_string)
    end

    # Compatibility methods
    def self.from_file(id : String) : Paste?
      # Try to load latest generation first, fall back to any generation

      latest_obj = Paste.latest(id)
      paste = latest_obj ? latest_obj : Sepia::Storage.load(Paste, id)

      # Check if paste has expired - if so, delete it and return nil
      if paste && paste.expired?
        puts "⏰ Paste #{id} has expired - deleting permanently"
        paste.delete_completely!
        return nil
      end

      paste
    rescue Enumerable::EmptyError
      # If latest() fails with empty enumerable, try direct load
      paste = Sepia::Storage.load(Paste, id)
      # Check if paste has expired - if so, delete it and return nil
      if paste && paste.expired?
        puts "⏰ Paste #{id} has expired - deleting permanently"
        paste.delete_completely!
        return nil
      end
      paste
    rescue
      # Catch any other exceptions (e.g., "not found in storage")
      nil
    end

    # Safe loading method that handles exceptions
    def self.safe_load(id : String) : Paste?
      from_file(id)
    rescue
      nil
    end

    def save(force_new_generation : Bool = false) : Bool
      @updated_at = Time.utc
      begin
        Sepia::Storage.save(self, force_new_generation: force_new_generation)
        true
      rescue ex
        false
      end
    end

    # Build extension -> language lookup table from Tartrazine
    @@extension_to_language : Hash(String, String)?

    def self.extension_to_language : Hash(String, String)
      @@extension_to_language ||= begin
        mapping = {} of String => String
        Tartrazine.lexers.each do |lexer_name|
          Tartrazine.lexer_extensions(lexer_name).each do |ext|
            # Store with leading dot, lowercase
            normalized = ext.downcase
            normalized = ".#{normalized}" unless normalized.starts_with?(".")
            mapping[normalized] = lexer_name.downcase
          end
        end
        mapping
      end
    end

    def language_for_extension(ext : String?) : String
      return @language || "text" if ext.nil?

      # If ext is already a language name (not starting with dot), use it directly
      if !ext.starts_with?(".")
        return ext
      end

      # Normalize and lookup in the extension table
      normalized = ext.downcase
      normalized = ".#{normalized}" unless normalized.starts_with?(".")

      self.class.extension_to_language[normalized]? || @language || "text"
    end

    def highlight(language_override : String? = nil) : {String, String}
      lang = language_override || @language || "text"

      begin
        # Handle "Auto" language by using Hansa to detect
        if lang == "Auto" || lang == "auto"
          detected = self.class.get_best_supported_language(@content)
          lang = detected if detected
        end

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

    # Class method for highlighting without creating a paste object
    def self.highlight_content(content : String, language : String? = nil, theme : String = "default-dark", line_numbers : Bool = false) : {String, String}
      lang = language || "text"

      begin
        # Handle "Auto" language by using Hansa to detect
        if lang == "Auto" || lang == "auto"
          detected = get_best_supported_language(content)
          lang = detected if detected
        end

        puts "DEBUG: Direct highlighting with language: #{lang}, theme: #{theme}, line_numbers: #{line_numbers}"
        formatter = Tartrazine::Html.new(theme: Tartrazine.theme(theme), line_numbers: line_numbers)
        lexer = Tartrazine.lexer(name: lang)
        result = formatter.format(content, lexer)
        css = formatter.style_defs
        puts "DEBUG: Direct highlighting successful"
        {result, css}
      rescue ex
        puts "DEBUG: Direct highlighting failed for language '#{lang}' with theme '#{theme}': #{ex.message}"
        # Fallback: escape HTML and wrap in pre
        {HTML.escape(content), ""}
      end
    end

    def self.available_themes : Array(String)
      Tartrazine.themes.sort
    end

    def self.available_languages : Array(String)
      # Get all available lexers from Tartrazine
      ["Auto"] + Tartrazine.lexers.sort
    end

    # Get the best Tartrazine-supported language from Hansa's probable languages
    def self.get_best_supported_language(content : String) : String?
      return nil if content.empty?

      begin
        # Get all probable languages from Hansa (sorted by confidence, lowest first)
        scored_languages = Hansa::CLASSIFIER.classify(content)

        # Sort by score (highest first) to get most probable languages first
        scored_languages = scored_languages.sort_by { |lang| -lang[1] }

        # Find the best supported language
        scored_languages.each do |hansa_lang, _|
          # Check if tartrazine has a lexer for this language
          begin
            return hansa_lang.downcase if Tartrazine.lexer(name: hansa_lang)
          rescue Exception
            # No lexer found, skip
            next
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

    # Override user_id getter to check SSH key ownership when user_id is nil
    # If ownership is found via SSH key, updates the paste's user_id for future requests
    def user_id : String?
      # Return cached user_id if already set
      return @user_id if @user_id

      # Check SSH key ownership if no direct user_id
      if ssh_fingerprint = @ssh_fingerprint
        ssh_key = SSHKey.find(ssh_fingerprint)
        if ssh_key && ssh_key.owner_id
          # Update this paste with the correct user_id for future requests
          @user_id = ssh_key.owner_id
          save
        end
      end

      @user_id
    end

    # Decrypt encrypted content using AES-256-GCM
    def decrypt_content(encryption_key : String) : String
      return @content unless is_encrypted? && @encrypted_content && @encryption_iv

      begin
        # Decode the base64 encrypted content
        encrypted_data = Base64.decode_string(@encrypted_content.as(String))

        # Split into ciphertext and auth_tag (last 16 bytes)
        ciphertext = encrypted_data[0...-16]
        auth_tag = encrypted_data[-16..]

        # Setup decryption
        decipher = OpenSSL::Cipher.new("aes-256-gcm")
        decipher.decrypt
        decipher.key = Base64.decode_string(encryption_key)
        decipher.iv = Base64.decode_string(@encryption_iv.as(String))

        # Set the authentication tag before decryption
        decipher.auth_tag = auth_tag

        # Decrypt the content
        decrypted_content = decipher.update(ciphertext) + decipher.final

        decrypted_content
      rescue ex
        raise "Failed to decrypt content: #{ex.message}"
      end
    end

    # Encrypt content using AES-256-GCM (for client-side encryption compatibility)
    def encrypt_content(encryption_key : String, encryption_iv : String) : String
      return @content if @content.empty?

      begin
        cipher = OpenSSL::Cipher.new("aes-256-gcm")
        cipher.encrypt
        cipher.key = Base64.decode_string(encryption_key)
        cipher.iv = Base64.decode_string(encryption_iv)

        # Encrypt the content
        encrypted_data = cipher.update(@content) + cipher.final

        # Get the authentication tag (16 bytes for GCM)
        auth_tag = cipher.auth_tag

        # Combine ciphertext + auth_tag for Web Crypto API compatibility
        webcrypto_compatible_data = encrypted_data + auth_tag

        # Return as Base64 for storage/transmission
        Base64.strict_encode(webcrypto_compatible_data)
      rescue ex
        raise "Failed to encrypt content: #{ex.message}"
      end
    end

    # Parse expiration string (e.g., "10m", "1h", "1d", "1w", "1M", "view-once") and return Time
    def self.parse_expiration(expiration_str : String?) : Time
      # Return far-future date if no expiration specified
      return Time.utc(9999, 1, 1) if expiration_str.nil? || expiration_str.empty?

      case expiration_str.downcase
      when "10m"
        Time.utc + 10.minutes
      when "1h"
        Time.utc + 1.hour
      when "1d"
        Time.utc + 1.day
      when "1w"
        Time.utc + 1.week
      when "1m"
        Time.utc + 1.month
      when "1M"
        Time.utc + 1.month
      when "view-once"
        # Special case for view-once - use far-future date for expires_at
        # The actual burning logic is handled by burn_after_reading? flag
        Time.utc(9999, 1, 1)
      else
        # Unknown expiration string - use far-future date as default
        Time.utc(9999, 1, 1)
      end
    end

    # Check if expiration string indicates burn_after_reading
    def self.burn_after_reading?(expiration_str : String?) : Bool
      expiration_str == "view-once"
    end

    # Check if paste has expired
    def expired? : Bool
      Time.utc > expires_at
    end

    # Check if paste should be burned after reading
    def should_burn_after_reading? : Bool
      burn_after_reading?
    end

    # Delete paste completely (for burn-after-reading)
    def burn_now! : Nil
      puts "🔥 Burning paste #{@sepia_id} (burn-after-reading) - deleting permanently"
      delete_completely!
    end

    # Completely delete this paste and all its versions
    def delete_completely! : Nil
      # Invalidate cache for this paste
      Pasto::Cache.invalidate(@sepia_id)

      # Delete all versions of this paste
      versions = self.class.versions(@sepia_id)
      versions.each do |version|
        Pasto::Cache.invalidate(version.sepia_id)
        Sepia::Storage.delete(version)
      end

      # Delete this paste itself
      Sepia::Storage.delete(self)
    end

    private def generate_id : String
      # Generate a short random ID
      Random::Secure.urlsafe_base64(6).gsub(/[-_]/, "").chars.first(8).join
    end
  end
end

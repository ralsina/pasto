require "../paste"
require "../theme_helper"
require "../time_helper"
require "../logging"
require "../rate_limit_helper"
require "../preview_generator"
require "../mimetypes"
require "../meta"

module Pasto
  # Register all paste viewing/management routes
  def self.register_paste_routes
    base_path = Pasto.config.base_path

    get Pasto::PathHelper.with_base_path("/:id/edit", base_path) do |env|
      # Use the existing access validation function
      access = Pasto.validate_paste_access(env, require_owner: true)
      unless access.allowed?
        halt env, access.status_code
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        halt env, 404
      end

      # Prevent editing burn-after-reading pastes
      if paste.burn_after_reading?
        env.response.status_code = 403
        next "Burn-after-reading pastes cannot be edited"
      end

      current_user = Pasto.get_current_user(env)

      # Get all theme-related template variables
      theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

      # Set template variables
      is_home_page = false
      page_title = "Edit Paste #{paste.sepia_id}"

      # Social media metadata for edit page
      meta_title = "Pasto - Edit Paste #{paste.sepia_id}"
      meta_description = "Edit paste with live syntax highlighting and SSH access"
      meta_url = "/#{paste.sepia_id}"
      meta_image = "/assets/favicon.png"

      # Set variables for unified template
      mode = "edit"
      initial_content = paste.content
      initial_language = paste.language
      initial_title = paste.title
      paste_id = paste.sepia_id

      content = render "src/views/_editor_unified.ecr"
      render "src/views/layout.ecr"
    end

    # Edit paste submission (POST)
    post Pasto::PathHelper.with_base_path("/:id/edit", base_path) do |env|
      # Validate access
      access = Pasto.validate_paste_access(env, require_owner: true)

      unless access.allowed?
        halt env, access.status_code
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        halt env, 404
      end

      # Extract and validate paste parameters
      params = PasteParams.new(env)

      # Validate content and size
      is_valid, error_message = validate_paste_content(params.content)
      unless is_valid
        if error_message && error_message.includes?("too large")
          env.response.status_code = 413
        else
          env.response.status_code = 400
        end
        next error_message || "Invalid content"
      end

      # Apply parameters to existing paste (with line ending normalization and versioning)
      apply_paste_params(paste, params)
      paste.updated_at = Time.utc

      # Save with versioning to keep edit history
      if paste.save(force_new_generation: true)
        # Invalidate cache
        Pasto::Cache.invalidate(paste.sepia_id)

        # Redirect to the paste view
        env.redirect "/#{paste.sepia_id}"
      else
        env.response.status_code = 500
        "Failed to save paste"
      end
    end

    # Fork paste (create a copy owned by current user)
    post Pasto::PathHelper.with_base_path("/:id/fork", base_path) do |env|
      id = env.params.url["id"]

      # Must be logged in to fork
      current_user = Pasto.get_current_user(env)
      unless current_user
        env.response.status_code = 401
        next "You must be logged in to fork a paste"
      end

      # Rate limit forks the same as paste creation
      allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :paste, current_user.sepia_id)
      unless allowed
        next rate_limit_response
      end

      original_paste = Pasto::Paste.from_file(id)
      if original_paste.nil?
        halt env, 404
      end

      # Create new paste with same content
      forked_paste = Pasto::Paste.new(
        original_paste.content,
        original_paste.language,
        original_paste.theme,
        user_id: current_user.sepia_id,
        title: original_paste.title,
        filename: original_paste.filename
      )

      if forked_paste.save
        # If user has SSH keys, associate with first key
        if !current_user.keys.empty?
          ssh_key = current_user.keys.first
          forked_paste.ssh_fingerprint = ssh_key.sepia_id
          forked_paste.save
          ssh_key.add_paste(forked_paste)
          ssh_key.save
        end

        env.redirect "/#{forked_paste.sepia_id}"
      else
        env.response.status_code = 500
        "Failed to fork paste"
      end
    end

    # Delete paste (owner only)
    post Pasto::PathHelper.with_base_path("/:id/delete", base_path) do |env|
      # Validate access
      access = Pasto.validate_paste_access(env, require_owner: true)

      unless access.allowed?
        env.response.content_type = "application/json"
        env.response.status_code = access.status_code
        next {"success" => false, "error" => "Access denied"}.to_json
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        # Paste doesn't exist, return success for idempotent behavior
        env.response.content_type = "application/json"
        next {"success" => true, "message" => "Paste already deleted"}.to_json
      end

      # Remove paste from user's SSH key pastes array
      if user = Pasto.get_current_user(env)
        user.keys.each do |ssh_key|
          ssh_key.pastes.reject! { |paste_item| paste_item.sepia_id == paste.sepia_id || paste_item.base_id == paste.base_id }
          ssh_key.save
        end
      end

      # Delete the paste completely (handles all versions automatically)
      paste.delete_completely!

      # Return JSON response
      env.response.content_type = "application/json"
      {"success" => true, "message" => "Paste deleted successfully"}.to_json
    end

    # View paste history (list of versions)
    get Pasto::PathHelper.with_base_path("/:id/history", base_path) do |env|
      id = env.params.url["id"]

      # Get the base ID (strip any generation suffix)
      base_id = if id.includes?(".")
                  parts = id.split(".")
                  if parts.last.matches?(/^\d+$/)
                    parts[0..-2].join(".")
                  else
                    id
                  end
                else
                  id
                end

      # Validate access using centralized function
      access = Pasto.validate_paste_access(env)

      unless access.allowed?
        halt env, access.status_code
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        halt env, 404
      end

      # Get all versions of the paste
      versions = Pasto::Paste.versions(paste.base_id)

      if versions.empty?
        halt env, 404
      end

      # Get current user for theme setup
      current_user = Pasto.get_current_user(env)

      # Get all theme-related template variables
      theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

      # Sort by generation (newest first)
      versions = versions.reverse

      # Set template variables
      is_home_page = false
      page_title = "History: #{paste.display_title}"

      # Social media metadata (generic for history pages)
      meta_title = "Pasto - Paste History"
      meta_description = "Modern pastebin with live syntax highlighting and SSH access"
      meta_url = "/#{paste.sepia_id}/history"
      meta_image = "/favicon.png"

      content = render "src/views/history.ecr"
      render "src/views/layout.ecr"
    end

    # View a specific version of a paste
    get Pasto::PathHelper.with_base_path("/:id/version/:gen", base_path) do |env|
      id = env.params.url["id"]
      gen = env.params.url["gen"].to_i

      # Construct the versioned ID
      versioned_id = "#{id}.#{gen}"

      # Validate access using centralized function
      access = Pasto.validate_paste_access(env)

      unless access.allowed?
        halt env, access.status_code
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        halt env, 404
      end

      # Load the specific version
      begin
        version_paste = Pasto::Paste.load(versioned_id)
        # Use the versioned content but keep access-controlled paste metadata
        paste_content = version_paste
      rescue
        halt env, 404
      end

      # Get current user
      current_user = Pasto.get_current_user(env)

      # Get all theme-related template variables
      theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

      # Get language override from URL parameter if present
      url_lang_override = env.params.query["lang"]?
      language_override = nil
      if url_lang_override && !url_lang_override.empty?
        language_override = url_lang_override
      end

      # Generate highlighted content from versioned paste with language override
      highlighted_content = paste_content.highlight(language_override)[0]

      # Version count for the history button (owner can see history)
      version_count = 0
      if current_user && paste.user_id == current_user.sepia_id
        version_count = Pasto::Paste.versions(id).size
      end

      # Set template variables
      is_home_page = false
      page_title = paste.display_title
      is_version_view = true
      base_paste_id = id

      # Generate social media metadata for version view
      meta_title = "#{paste.display_title} (v#{paste.generation})"
      meta_description = generate_meta_description(paste.content)
      host = env.request.headers["Host"]? || "localhost:3000"
      meta_url = "http://#{host}#{env.request.path}"
      meta_image = "http://#{host}/preview/#{paste.sepia_id}.png"

      content = render "src/views/show.ecr"
      render "src/views/layout.ecr"
    end

    # Error handling for other 404 cases
    error 404 do |env|
      current_user = Pasto.get_current_user(env)
      theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)
      page_title = "404 - Not Found"
      is_home_page = false

      # Social media metadata
      meta_title = "404 - Not Found - Pasto"
      meta_description = "The requested paste could not be found on Pasto"
      meta_url = "/404"
      meta_image = "/favicon.png"

      # Set 404 status code
      env.response.status_code = 404

      reason = "not_found"

      content = render "src/views/404.ecr"
      render "src/views/layout.ecr"
    end

    # Error handling for 403 Forbidden cases
    error 403 do |env|
      current_user = Pasto.get_current_user(env)
      theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)
      page_title = "403 - Access Denied"
      is_home_page = false

      # Social media metadata
      meta_title = "403 - Access Denied - Pasto"
      meta_description = "Access to this paste is restricted"
      meta_url = "/403"
      meta_image = "/favicon.png"

      # Set 403 status code
      env.response.status_code = 403

      reason = "access_denied"

      content = render "src/views/403.ecr"
      render "src/views/layout.ecr"
    end

    # Preview image route for social media cards (must come before catch-all routes)
    get Pasto::PathHelper.with_base_path("/preview/:id", base_path) do |env|
      # Rate limiting for preview generation (use existing highlight limiter)
      allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :highlight)
      unless allowed
        next "Rate limit exceeded for preview generation"
      end

      # Validate access using centralized function
      access = Pasto.validate_paste_access(env)

      unless access.allowed?
        halt env, access.status_code
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        # Generate and serve 404 placeholder
        placeholder_path = generate_placeholder_file("Paste not found")
        env.response.status_code = 404
        env.response.headers["Cache-Control"] = "public, max-age=300" # 5 minutes for errors
        next send_file env, placeholder_path
      end

      cache_path = PreviewGenerator.get_cache_path(paste.sepia_id)

      # Generate cached image if it doesn't exist
      unless File.exists?(cache_path) && File.info(cache_path).modification_time > paste.updated_at
        begin
          PreviewGenerator.save_preview_image(paste, cache_path)
        rescue ex
          # Generate and serve error placeholder
          placeholder_path = generate_placeholder_file("Error generating preview")
          env.response.headers["Cache-Control"] = "public, max-age=300" # 5 minutes for errors
          next send_file env, placeholder_path
        end
      end

      # Serve the cached image using Kemal's optimized send_file helper
      env.response.headers["Cache-Control"] = "public, max-age=3600" # 1 hour
      send_file env, cache_path
    end

    # Raw paste endpoint
    get Pasto::PathHelper.with_base_path("/:id/raw", base_path) do |env|
      id = env.params.url["id"]

      # Load the paste
      paste = Pasto::Paste.from_file(id)
      if paste.nil?
        halt env, 404
      end

      # Note: For burn-after-reading pastes in raw endpoint, we'll increment after sending content

      # Check access permissions using the centralized validation function
      access_result = Pasto.validate_paste_access(env)
      unless access_result.success?
        halt env, access_result.status_code
      end

      # Set content type and filename using Crystal's MIME module
      filename = Pasto::MimeTypes.generate_filename(paste)
      mime_type = MIME.from_filename(filename) || "text/plain"

      # Ensure charset is included for text types
      if mime_type.starts_with?("text/")
        mime_type += "; charset=utf-8"
      end

      env.response.content_type = mime_type
      env.response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""

      # Mark paste for burning after response if it's burn-after-reading
      if paste.burn_after_reading?
        env.response.headers["X-Burn-After-Reading"] = paste.sepia_id
      end

      # For encrypted pastes, return the encrypted content
      # For regular pastes, return the raw content
      content = if paste.is_encrypted? && paste.responds_to?(:encrypted_content) && paste.encrypted_content
                  paste.encrypted_content
                else
                  paste.content
                end

      content
    end

    # Embed endpoint for iframe embedding (must come before /:id route)
    get Pasto::PathHelper.with_base_path("/:id/embed", base_path) do |env|
      id = env.params.url["id"]

      # Validate access using centralized function
      access = Pasto.validate_paste_access(env)
      unless access.allowed?
        halt env, access.status_code
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        halt env, 404
      end

      # Disallow embeds for burn-after-reading pastes
      if paste.burn_after_reading?
        env.response.status_code = 403
        next "Burn-after-reading pastes cannot be embedded"
      end

      # Disallow embeds for encrypted pastes
      if paste.is_encrypted?
        env.response.status_code = 403
        next "Encrypted pastes cannot be embedded"
      end

      # Parse embed options from query parameters
      embed_theme = env.params.query["theme"]? || paste.theme
      embed_mode = env.params.query["mode"]? || "auto" # "auto", "light", or "dark"
      embed_lines = env.params.query["lines"]? == "true"
      embed_ui = env.params.query["ui"]? != "false" # default true
      embed_width = env.params.query["width"]?.try(&.to_i) || 600
      embed_height = env.params.query["height"]?.try(&.to_i) || 400
      embed_lang = env.params.query["lang"]?
      embed_base_path = Pasto.config.base_path

      # Generate highlighted content
      highlighted_content = paste.highlight(embed_lang)[0]

      # Calculate base URL for "View on Pasto" link
      # Respect reverse proxy headers
      scheme = env.request.headers["X-Forwarded-Proto"]? || "http"
      host = env.request.headers["X-Forwarded-Host"]? || env.request.headers["Host"]? || "localhost"
      base_url = "#{scheme}://#{host}"

      # Render the embed view
      # kemal-cache middleware handles caching automatically for anonymous users
      content = render "src/views/embed.ecr"

      next content

      # Render embed view (minimal layout, no sidebar)
      render "src/views/embed.ecr"
    end

    get Pasto::PathHelper.with_base_path("/:id", base_path) do |env|
      id = env.params.url["id"]
      request_path = env.request.path
      language_override = nil

      # Check if the path contains an extension (a dot followed by more characters)
      if request_path.includes?(".") && request_path.count('.') > 0
        # Split by the last dot to separate ID from extension
        parts = request_path.split(".")
        if parts.size >= 2
          paste_id = parts[0..-2].join(".")
          ext = parts[-1]

          # Check if extension is numeric (version number) or file extension
          if ext.match(/^\d+$/)
            # This is a versioned URL like {id}.{gen}, don't treat as file extension
            id = paste_id
            # Don't set stored_ext - let paste use its own language detection
          else
            # This is a file extension for language override
            id = paste_id
            # Store extension for language mapping after access control
            stored_ext = ext
          end
        end
      end

      # Validate access using centralized function
      access = Pasto.validate_paste_access(env)

      unless access.allowed?
        halt env, access.status_code
      end

      if access.paste
        paste = access.paste.as(Pasto::Paste)
      else
        halt env, 404
      end

      # Get current user for theme setup
      current_user = Pasto.get_current_user(env)

      # kemal-cache middleware handles caching automatically for anonymous users

      # Apply language mapping from stored extension if present
      if stored_ext
        language_override = paste.language_for_extension(stored_ext)
      end

      # Get all theme-related template variables
      theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

      # Get language override from URL parameter if present
      url_lang_override = env.params.query["lang"]?
      if url_lang_override && !url_lang_override.empty?
        language_override = url_lang_override
      end

      # Generate highlighted content
      highlighted_content = paste.highlight(language_override)[0]

      # Get version count for history button (only if user owns the paste)
      version_count = 0
      if current_user && paste.user_id == current_user.sepia_id
        version_count = Pasto::Paste.versions(paste.base_id).size
      end

      # Set version view flags (not a version view in main route)
      is_version_view = false
      base_paste_id = paste.base_id

      # Set template variables (ECR template will have access to these)
      is_home_page = false
      page_title = "Paste #{paste.sepia_id}"

      # Generate social media metadata with preview images
      meta_title = paste.display_title.size > 60 ? paste.display_title[0..57] + "..." : paste.display_title
      meta_description = generate_meta_description(paste.content)
      host = env.request.headers["Host"]? || "localhost:3000"
      meta_url = "http://#{host}#{env.request.path}"
      meta_image = "http://#{host}/preview/#{paste.sepia_id}.png"

      # Mark paste for burning after response if it's burn-after-reading
      if paste.burn_after_reading?
        env.response.headers["X-Burn-After-Reading"] = paste.sepia_id
      end

      # Render the content
      content = render "src/views/show.ecr"
      rendered_html = render "src/views/layout.ecr"

      # kemal-cache middleware handles caching automatically for anonymous users

      rendered_html
    end
  end
end

# Profile management endpoints for Pasto application

module Pasto
  # Update user profile
  post "/profile" do |env|
    current_user = Pasto.get_current_user(env)

    unless current_user
      env.response.status_code = 401
      next "Unauthorized"
    end

    # Check if this is an AJAX request (for theme updates)
    is_ajax = env.request.headers["X-Requested-With"]? == "XMLHttpRequest"

    # Get the new name from form
    if env.params.body.has_key?("name")
      new_name = env.params.body["name"]?.try(&.strip)
      if new_name && !new_name.empty?
        new_name = new_name.gsub(/<[^>]*>/, "") # Remove HTML tags
        new_name = new_name[0..50]              # Limit to 50 chars
        current_user.name = new_name
      else
        current_user.name = nil
      end
    end

    # Update theme preferences
    if env.params.body.has_key?("pico_theme")
      current_user.pico_theme = env.params.body["pico_theme"]?.try(&.strip)
    end
    if env.params.body.has_key?("pico_color")
      current_user.pico_color = env.params.body["pico_color"]?.try(&.strip)
    end
    if env.params.body.has_key?("syntax_theme")
      current_user.syntax_theme = env.params.body["syntax_theme"]?.try(&.strip)
    end

    if current_user.save
      puts "User #{current_user.sepia_id} updated"
      if is_ajax
        env.response.content_type = "application/json"
        {"status" => "ok"}.to_json
      else
        env.redirect "/profile?updated=true"
      end
    else
      if is_ajax
        env.response.status_code = 500
        env.response.content_type = "application/json"
        {"status" => "error"}.to_json
      else
        env.redirect "/profile?error=save_failed"
      end
    end
  end

  # API Key revocation route
  post "/profile/api-keys/revoke" do |env|
    current_user = Pasto.get_current_user(env)
    unless current_user
      env.response.status_code = 401
      next "Unauthorized"
    end

    api_key_id = env.params.body["api_key_id"]?
    if api_key_id.nil? || api_key_id.empty?
      env.response.status_code = 400
      next "API key ID is required"
    end

    # Find the API key
    api_key = Pasto::ApiKey.find(api_key_id)
    if api_key.nil?
      env.response.status_code = 404
      next "API key not found"
    end

    # Verify the key belongs to the current user
    if api_key.user_id != current_user.sepia_id
      env.response.status_code = 403
      next "You can only revoke your own API keys"
    end

    # Remove the API key from user's key list
    current_user.api_keys.delete(api_key_id)

    # Save user changes
    if current_user.save
      # Delete the API key file
      begin
        api_key_file_path = "data/Pasto::ApiKey/#{api_key_id}"
        if File.exists?(api_key_file_path)
          File.delete(api_key_file_path)
        end
      rescue ex
        puts "Error deleting API key file #{api_key_id}: #{ex.message}"
      end

      puts "User #{current_user.sepia_id} revoked API key #{api_key_id}"

      # Check if this is an AJAX request
      if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
        env.response.content_type = "application/json"
        {"status" => "success", "message" => "API key revoked successfully"}.to_json
      else
        env.redirect "/profile?updated=true"
      end
    else
      env.response.status_code = 500
      if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
        env.response.content_type = "application/json"
        {"status" => "error", "message" => "Failed to revoke API key"}.to_json
      else
        env.redirect "/profile?error=save_failed"
      end
    end
  end

  # SSH Key revocation route
  post "/profile/ssh-keys/revoke" do |env|
    current_user = Pasto.get_current_user(env)
    unless current_user
      env.response.status_code = 401
      next "Unauthorized"
    end

    fingerprint = env.params.body["fingerprint"]?
    if fingerprint.nil? || fingerprint.empty?
      env.response.status_code = 400
      next "SSH key fingerprint is required"
    end

    # Convert URL-safe fingerprint back to file-safe format
    file_safe_fingerprint = fingerprint.gsub("/", "_")

    # Find the SSH key
    ssh_key = Pasto::SSHKey.find(file_safe_fingerprint)
    if ssh_key.nil?
      env.response.status_code = 404
      next "SSH key not found"
    end

    # Verify the key belongs to the current user
    if ssh_key.owner_id != current_user.sepia_id
      env.response.status_code = 403
      next "You can only revoke your own SSH keys"
    end

    # Prevent revoking the last SSH key (user needs at least one for SSH access)
    if current_user.keys.size <= 1
      env.response.status_code = 400
      next "You cannot revoke your last SSH key. You must have at least one SSH key for access."
    end

    # Remove the SSH key from user's key list
    current_user.keys.delete(ssh_key)

    # Save user changes
    if current_user.save
      # Delete the SSH key file
      begin
        ssh_key_file_path = "data/Pasto::SSHKey/#{file_safe_fingerprint}"
        if File.exists?(ssh_key_file_path)
          File.delete(ssh_key_file_path)
        end
      rescue ex
        puts "Error deleting SSH key file #{file_safe_fingerprint}: #{ex.message}"
      end

      puts "User #{current_user.sepia_id} revoked SSH key #{file_safe_fingerprint}"

      # Check if this is an AJAX request
      if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
        env.response.content_type = "application/json"
        {"status" => "success", "message" => "SSH key revoked successfully"}.to_json
      else
        env.redirect "/profile?updated=true"
      end
    else
      env.response.status_code = 500
      if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
        env.response.content_type = "application/json"
        {"status" => "error", "message" => "Failed to revoke SSH key"}.to_json
      else
        env.redirect "/profile?error=save_failed"
      end
    end
  end

  # User profile page
  get "/profile" do |env|
    # Validate session to get current user
    current_user = Pasto.get_current_user(env)

    # Get SSH connection info from config
    config = Pasto.config
    ssh_host = config.try(&.bind) || "localhost"
    # Use base_url host if bind is 0.0.0.0
    if ssh_host == "0.0.0.0" && config
      # Extract host from base_url
      base_url = config.base_url
      if match = base_url.match(%r{https?://([^:/]+)})
        ssh_host = match[1]
      else
        ssh_host = "localhost"
      end
    end
    ssh_port = config.try(&.ssh_port) || 2222
    ssh_enabled = config.try(&.ssh_enabled?) || false

    # Get theme preferences with priority: user config > cookie > defaults
    saved_pico_theme = current_user.try(&.pico_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_theme=([^;]+)/, 1]? } || "auto"
    saved_pico_color = current_user.try(&.pico_color) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_pico_color=([^;]+)/, 1]? } || "slate"
    saved_syntax_theme = current_user.try(&.syntax_theme) || env.request.headers["Cookie"]?.try { |cookie| cookie[/pasto_syntax_theme=([^;]+)/, 1]? } || "default"

    # Resolve "auto" theme to prevent flashing - default to dark for server-side
    resolved_pico_theme = saved_pico_theme == "auto" ? "dark" : saved_pico_theme

    # Set template variables (ECR template will have access to these)
    page_title = "Profile"
    is_home_page = false
    pico_theme = saved_pico_theme
    pico_color = saved_pico_color
    syntax_theme = saved_syntax_theme

    # Social media metadata (generic for profile pages)
    meta_title = "Pasto - User Profile"
    meta_description = "Modern pastebin with live syntax highlighting and SSH access"
    meta_url = ""
    meta_image = ""

    content = render "src/views/profile_content.ecr"
    render "src/views/layout.ecr"
  end
end

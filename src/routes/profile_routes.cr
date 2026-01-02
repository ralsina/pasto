require "../logging"
require "../rate_limit_helper"
require "../models/backup"
require "../user_session"
require "../profile"

module Pasto
  # Register all profile/user management routes
  def self.register_profile_routes
    base_path = Pasto.config.base_path

    post Pasto::PathHelper.with_base_path("/profile/backups/create", base_path) do |env|
      current_user = Pasto.get_current_user(env)

      unless current_user
        env.response.status_code = 401
        if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
          env.response.content_type = "application/json"
          {"status" => "error", "message" => "Unauthorized"}.to_json
        else
          env.redirect "/profile?error=unauthorized"
        end
        next
      end

      # Check backup rate limiting (skip if rate limiting is disabled)
      unless Pasto.config.disable_rate_limit?
        allowed, rate_limit_result = RateLimits.allow_backup?(current_user.sepia_id)
        unless allowed
          Pasto::Logging.warn("Backup rate limit exceeded for user #{current_user.sepia_id}")
          env.response.status_code = 429
          if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
            env.response.content_type = "application/json"
            {"status" => "error", "message" => "Rate limit exceeded. You can create one backup per day."}.to_json
          else
            env.redirect "/profile?error=rate_limit"
          end
          next
        end
      end

      # Get config for storage directory
      config = Pasto.config

      # Spawn backup process asynchronously
      spawn do
        backup_binary = File.join(Dir.current, "bin", "pasto-backup")
        args = [
          "--user-id=#{current_user.sepia_id}",
          "--storage-dir=#{config.storage_dir}",
          "--log-level=#{config.log_level || "info"}",
        ]

        result = Process.run(
          backup_binary,
          args,
          output: Process::Redirect::Pipe,
          error: Process::Redirect::Pipe
        )

        unless result.success?
          Pasto::Logging.error("Backup creation failed for user #{current_user.sepia_id}: exit code #{result.exit_code}")
        end
      end

      # Return immediate response
      if env.request.headers["X-Requested-With"]? == "XMLHttpRequest"
        env.response.content_type = "application/json"
        {"status" => "success", "message" => "Backup creation started. This may take a few minutes to complete."}.to_json
      else
        env.redirect "/profile?backup=started"
      end
    end

    # Get backup status for current user
    get Pasto::PathHelper.with_base_path("/profile/backups", base_path) do |env|
      current_user = Pasto.get_current_user(env)

      unless current_user
        env.response.status_code = 401
        next {"status" => "error", "message" => "Unauthorized"}.to_json
      end

      backup_status = Pasto::BackupManager.get_backup_status(current_user.sepia_id)

      case backup_status[:status]
      when "available"
        backup = backup_status[:backup]
        if backup
          env.response.content_type = "application/json"
          {
            "status"       => "available",
            "created_at"   => backup["created_at"].as_s,
            "file_size"    => backup["file_size"].as_i64,
            "download_url" => "/profile/backups/download",
          }.to_json
        else
          {"status" => "none", "message" => "No backup available"}.to_json
        end
      when "in_progress"
        {"status" => "in_progress", "message" => "Backup creation in progress"}.to_json
      when "none"
        {"status" => "none", "message" => "No backup available"}.to_json
      when "corrupted"
        {"status" => "corrupted", "message" => "Backup file is corrupted: #{backup_status[:error]}"}.to_json
      when "error"
        env.response.status_code = 500
        {"status" => "error", "message" => "Error checking backup status: #{backup_status[:error]}"}.to_json
      else
        env.response.status_code = 500
        {"status" => "error", "message" => "Unknown backup status"}.to_json
      end
    end

    # Download backup for current user
    get Pasto::PathHelper.with_base_path("/profile/backups/download", base_path) do |env|
      current_user = Pasto.get_current_user(env)

      Pasto::Logging.info("Download request - current_user: #{current_user ? current_user.sepia_id : "nil"}")

      unless current_user
        env.response.status_code = 401
        next "Unauthorized"
      end

      # Get backup status
      backup_status = Pasto::BackupManager.get_backup_status(current_user.sepia_id)

      if backup_status[:status] != "available" || !backup_status[:backup]
        env.response.status_code = 404
        next "No backup available for download"
      end

      backup = backup_status[:backup]

      Pasto::Logging.info("Download validation - backup_status: #{backup_status[:status]}, backup: #{backup ? "exists" : "nil"}")

      # Verify backup accessibility
      unless backup && backup["user_id"].as_s == current_user.sepia_id
        env.response.status_code = 403
        Pasto::Logging.warn("Unauthorized backup download attempt by user #{current_user.sepia_id} - backup_user_id: #{backup ? backup["user_id"].as_s : "nil"}")
        next "Access denied"
      end

      # Get backup file path
      backup_file_path = backup["file_path"].as_s

      # Verify backup file exists
      unless File.exists?(backup_file_path)
        env.response.status_code = 404
        Pasto::Logging.warn("Backup file not found for user #{current_user.sepia_id}: #{backup_file_path}")
        next "Backup file not found"
      end

      # Serve backup file
      begin
        env.response.content_type = "application/gzip"
        env.response.headers["Content-Disposition"] = "attachment; filename=\"pasto_backup_#{current_user.sepia_id}.sepia.tar.gz\""
        env.response.headers["Content-Length"] = File.size(backup_file_path).to_s

        Pasto::Logging.info("User #{current_user.sepia_id} downloaded backup: #{backup_file_path}")

        # Stream file content
        File.open(backup_file_path, "rb") do |file|
          IO.copy(file, env.response)
        end
      rescue ex
        env.response.status_code = 500
        Pasto::Logging.error("Error serving backup file: #{ex.message}")
        "Error downloading backup file"
      end
    end

    # Logout route - clear session
    post Pasto::PathHelper.with_base_path("/logout", base_path) do |env|
      # Clear the session using kemal-session
      env.session.destroy

      Pasto::Logging.info("User logged out")

      env.redirect "/?logout=success"
    end

    # SSH Auth token route - validate token and create session
    get Pasto::PathHelper.with_base_path("/auth/:token", base_path) do |env|
      token_id = env.params.url["token"]
      client_ip = Pasto.get_client_ip(env)

      # Rate limit login attempts
      allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :login)
      unless allowed
        next rate_limit_response
      end

      token = Pasto::AuthToken.find(token_id)

      if token.nil? || token.expired?
        # Delete expired token if it exists
        token.try(&.delete)

        env.response.status_code = 404
        current_user = Pasto.get_current_user(env)
        theme_vars = Pasto::ThemeHelper.setup_vars(current_user, Pasto.config)

        # Set individual variables
        page_title = "Invalid Token"
        is_home_page = false
        meta_title = "Pasto - Authentication Error"
        meta_description = "Modern pastebin with live syntax highlighting and SSH access"
        meta_url = "/auth/error"
        meta_image = "/favicon.png"

        content = render "src/views/auth_error.ecr"
        render "src/views/layout.ecr"
        next
      end

      # Load or create SSHKey
      ssh_key = Pasto::SSHKey.find_or_create(token.fingerprint)

      # Check if key already has an owner
      user = if owner_id = ssh_key.owner_id
               Pasto::User.find(owner_id)
             else
               nil
             end

      # If no user exists, create one and link the key
      if user.nil?
        user = Pasto::User.new
        user.save             # Save first to get sepia_id
        user.add_key(ssh_key) # This sets owner_id and adds to keys array
        user.save             # Save again with the key added
        Pasto::Logging.info("Created new user #{user.sepia_id} for SSH key #{token.fingerprint}")
      else
        # Make sure the key is in the user's keys array (in case of data inconsistency)
        unless user.keys.any? { |k| k.sepia_id == ssh_key.sepia_id }
          user.add_key(ssh_key)
          user.save
          Pasto::Logging.info("Added SSH key #{token.fingerprint} to existing user #{user.sepia_id}")
        end
        Pasto::Logging.info("Existing user #{user.sepia_id} logging in via SSH key #{token.fingerprint}")
      end

      # Create session
      user_session = Pasto::UserSession.new(user.sepia_id, nil, client_ip)
      env.session.object("user", user_session)

      # Delete the token (one-time use)
      token.delete

      Pasto::Logging.info("SSH auth successful for user #{user.sepia_id} from #{client_ip}")

      # Redirect to home with success message
      env.redirect "/?ssh_login=success"
    end
  end
end

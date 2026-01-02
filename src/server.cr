require "openssl"
require "./api"
require "./assets"
require "pasto-cache"
require "./filters"
require "./health"
require "./help"
require "./mimetypes"
require "./models/*"
require "./paste"
require "./logging"
require "./path_helper"
require "./preview_generator"
require "qr-code"
require "./profile"
require "./ratelimit"
require "./rate_limit_helper"
require "./ssh_utils"
require "./theme_helper"
require "./time_helper"
require "./user_session"
require "./mcp_server"
require "ecr"
require "file_utils"
require "http"
require "kemal-session"
require "kemal"
require "qr-code/export/png"
require "tartrazine"

module Pasto
  include TimeHelper

  # Cached debug user for auth debug mode
  @@debug_user : User?

  # Creates or retrieves the debug user for auth debug mode
  private def self.debug_user : User
    if debug_user = @@debug_user
      return debug_user
    end

    # Look for existing debug SSH key first
    debug_fingerprint = "SHA256:debug_auth_debug_mode_key_for_testing"
    if existing_ssh_key = SSHKey.find_or_create(debug_fingerprint)
      if owner_id = existing_ssh_key.owner_id
        # Found existing debug user, load it
        if existing_user = User.find(owner_id)
          # Rebuild SSH key's paste references by finding pastes with this fingerprint
          existing_ssh_key.pastes.clear

          # Find all pastes that belong to this user
          if Dir.exists?("./data/Pasto::Paste/")
            Dir.each_child("./data/Pasto::Paste/") do |paste_id|
              begin
                paste = Paste.from_file(paste_id)
                if paste && paste.ssh_fingerprint == debug_fingerprint
                  existing_ssh_key.add_paste(paste)
                end
              rescue
                # Skip invalid paste files
              end
            end
          end

          existing_ssh_key.save

          @@debug_user = existing_user
          return existing_user
        end
      end
    end

    # Create new debug user and cache it
    debug_user = User.new("Debug User")
    debug_user.save

    # Create a debug SSH key so pastes can be associated with the user
    debug_ssh_key = SSHKey.new(debug_fingerprint)
    debug_ssh_key.owner_id = debug_user.sepia_id
    debug_ssh_key.save
    debug_user.add_key(debug_ssh_key)

    @@debug_user = debug_user
    debug_user
  end

  # Extracts UserSession from Kemal session and fetches User from Sepia storage
  # Returns nil for unauthenticated users or invalid sessions
  # In auth debug mode, always returns the debug user
  def self.get_current_user(env) : User?
    # Auth debug mode: always return debug user
    if Pasto.config.auth_debug_mode?
      return debug_user
    end

    # Normal authentication logic
    if user_session = env.session.object?("user").as(Pasto::UserSession?)
      User.find(user_session.user_id)
    else
      nil
    end
  end

  # Unified access control result
  struct AccessResult
    property? allowed : Bool
    property paste : Pasto::Paste?
    property status_code : Int32

    def initialize(@allowed : Bool, @paste : Pasto::Paste? = nil, @status_code : Int32 = 200)
    end

    def success? : Bool
      @allowed && @paste != nil
    end
  end

  # Validates paste access control and returns structured access result
  #
  # This function consolidates paste access validation logic including existence checks,
  # user authentication, and permission verification. Used by both middleware filters
  # and route handlers for consistent access control.
  #
  # Arguments:
  #   env - HTTP request environment containing session and routing information
  #   require_owner - If true, only allows access to paste owners (used for edit/delete operations)
  #
  # Returns:
  #   AccessResult with success status, paste object (if accessible), and appropriate HTTP status code
  #   - 400 for missing or empty paste IDs in URL parameters
  #   - 403 for permission/ownership violations
  #   - 404 for non-existent pastes
  #   - 200 for successful access
  def self.validate_paste_access(env, require_owner : Bool = false) : AccessResult
    id = extract_paste_id(env)

    return AccessResult.new(false, status_code: 400) if id.nil? || id.empty?

    # Load the paste
    paste = Pasto::Paste.from_file(id)
    return AccessResult.new(false, status_code: 404) if paste.nil?

    # Only get current user if we need to check ownership or private access
    if require_owner || paste.private?
      current_user = get_current_user(env)
      current_user_id = current_user.try(&.sepia_id)

      # Check ownership requirement
      # Anonymous pastes (paste.user_id is nil) cannot be owned/deleted by anyone
      # Logged-in users can only access pastes where user_id matches
      if current_user_id && paste.user_id && current_user_id == paste.user_id
        return AccessResult.new(true, paste: paste)
      else
        # Access denied - ownership required or paste is private and user is not owner
        return AccessResult.new(false, status_code: 403)
      end
    end

    # Access granted - public paste and no ownership requirement
    AccessResult.new(true, paste: paste)
  rescue
    AccessResult.new(false, status_code: 404)
  end

  # Extract paste ID from various URL patterns
  private def self.extract_paste_id(env) : String?
    # Try the simple case first
    id = env.params.url["id"]?
    return nil unless id

    # Handle special cases only when needed
    path = env.request.path

    # Remove .png from preview URLs
    if path.includes?("/preview/")
      return id.gsub(/\.png$/, "")
    end

    # Handle file extensions in main paste view (/:id.py)
    if path.count('.') > 1 && !path.includes?("/api/")
      return id.split(".")[0..-2].join(".")
    end

    id
  end

  # /help endpoint: render the help markdown using the ECR template

  # Helper to extract client IP from request
  def self.get_client_ip(env) : String
    if forwarded = env.request.headers["X-Forwarded-For"]?
      forwarded.split(",")[0].strip
    elsif real_ip = env.request.headers["X-Real-IP"]?
      real_ip
    else
      env.request.remote_address.to_s.split(":")[0]
    end
  end

  # Helper to build base URL respecting reverse proxy headers
  # Returns scheme://host (without port if behind reverse proxy)
  def self.build_base_url(env) : String
    # Get scheme from reverse proxy header or default to http
    scheme = env.request.headers["X-Forwarded-Proto"]? || "http"

    # Get host from reverse proxy header or fall back to Host header
    host = env.request.headers["X-Forwarded-Host"]? || env.request.headers["Host"]? || "localhost"

    # Only add port if NOT behind a reverse proxy and port is non-standard
    behind_proxy = env.request.headers["X-Forwarded-Proto"]? || env.request.headers["X-Forwarded-Host"]?

    unless behind_proxy
      # Extract port from Host header if present
      if host_match = host.match(/^(.+):(\d+)$/)
        host_without_port = host_match[1]
        port = host_match[2].to_i
        host = host_without_port

        # Add port back if it's non-standard
        if port != 80 && port != 443
          return "#{scheme}://#{host_without_port}:#{port}"
        end
      end
    end

    "#{scheme}://#{host}"
  end

  # Helper to build full URL for a paste
  def self.build_paste_url(env, paste_id : String) : String
    base_path = Pasto.config.base_path
    paste_path = PathHelper.with_base_path("/#{paste_id}", base_path)
    "#{build_base_url(env)}#{paste_path}"
  end

  # Apply security headers and rate limiting to all requests
  before_all do |env|
    Pasto::Filters.add_security_headers(env)
    next unless Pasto::Filters.apply_rate_limiting(env)
  end

  # Handle burn-after-reading pastes after response is sent
  after_all do |env|
    Pasto::Filters.handle_burn_after_reading(env)
  end

  # Unified access control filters for paste content endpoints

  # Apply access control to all GET routes that might access paste content
  before_get do |env|
    next unless Pasto::Filters.apply_paste_access_control(env)
  end

  # Apply access control to POST routes for paste management
  before_post do |env|
    path = env.request.path

    # Only apply to paste management routes
    unless path.includes?("/edit") || path.includes?("/delete") || path.includes?("/fork")
      next
    end

    # Determine access requirements
    if path.includes?("/fork")
      # Fork doesn't require ownership, just login
      current_user = Pasto.get_current_user(env)
      unless current_user
        env.response.status_code = 401
        next "You must be logged in to fork a paste"
      end
      # Validate the original paste exists and is accessible
      access_result = Pasto.validate_paste_access(env)
      unless access_result.success?
        halt env, access_result.status_code
      end
    else
      # edit and delete require ownership
      access_result = Pasto.validate_paste_access(env, require_owner: true)
      unless access_result.success?
        # Return JSON for delete API routes, plain text for web UI
        if path.includes?("/delete")
          env.response.content_type = "application/json"
          error_response = {"success" => false, "error" => "Access denied"}.to_json
          halt env, access_result.status_code, error_response
        else
          halt env, access_result.status_code
        end
      end
    end
  end
end

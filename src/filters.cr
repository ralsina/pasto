require "../src/paste"

# ============================================================================
# Request Filters and Middleware
# ============================================================================

module Pasto
  module Filters
    # Security headers filter
    def self.add_security_headers(env)
      env.response.headers["X-Content-Type-Options"] = "nosniff"
      env.response.headers["X-Frame-Options"] = "DENY"
      env.response.headers["X-XSS-Protection"] = "1; mode=block"
    end

    # HTTP rate limiting filter
    def self.apply_rate_limiting(env)
      # Skip rate limiting for static assets and endpoints with their own limiters
      path = env.request.path
      skip_http_limit = path.starts_with?("/cache/") ||
                        path == "/favicon.ico" ||
                        path == "/syntax-theme.css" ||
                        path == "/highlight"

      unless skip_http_limit
        client_ip = Pasto.get_client_ip(env)
        allowed, result = Pasto::RateLimits.allow_http?(client_ip)
        add_rate_limit_headers(env, result)

        unless allowed
          retry_after = Math.max(1, (result.reset_time - Time.utc).total_seconds.ceil.to_i)
          env.response.headers["Retry-After"] = retry_after.to_s
          env.response.status_code = 429
          env.response.content_type = "text/plain"
          env.response.print "Too many requests. Please slow down. Retry after #{retry_after} seconds."
          env.response.close
          return false
        end
      end
      true
    end

    # Burn-after-reading handling
    def self.handle_burn_after_reading(env)
      # Check if paste needs to be burned after reading
      if burn_id = env.response.headers["X-Burn-After-Reading"]?
        # Remove the header so it's not sent to client
        env.response.headers.delete("X-Burn-After-Reading")

        # Burn the paste (after_all runs after response is sent, so no need for async)
        begin
          if paste = Pasto::Paste.from_file(burn_id)
            paste.burn_now!
          end
        rescue ex
          puts "Error burning paste #{burn_id}: #{ex.message}"
        end
      end
    end

    # Paths that should skip paste access control
    SKIP_ACCESS_CONTROL = [
      "/help", "/profile", "/", "/api-docs", "/openapi.yaml",
      "/favicon", "/favicon.ico", "/favicon.png", "/syntax-theme.css"
    ]

    # Path prefixes that should skip paste access control
    SKIP_ACCESS_CONTROL_PREFIXES = [
      "/auth/", "/api/", "/assets/", "/cache/", "/preview/",
      "/api/qr/", "/api/languages", "/api/themes"
    ]

    # Check if path needs paste access control
    def self.needs_paste_access_control?(path : String) : Bool
      # Skip explicitly listed paths
      return false if SKIP_ACCESS_CONTROL.includes?(path)

      # Skip paths with certain prefixes
      SKIP_ACCESS_CONTROL_PREFIXES.each do |prefix|
        return false if path.starts_with?(prefix)
      end

      # Check if path looks like a paste endpoint
      path_parts = path.split("/")
      return false if path_parts.size < 2

      # First part should be empty (leading slash), second should be paste ID
      paste_id = path_parts[1]?
      return false if paste_id.nil? || paste_id.empty?

      true
    end

    # Apply paste access control
    def self.apply_paste_access_control(env)
      path = env.request.path

      # Check if this path needs access control
      unless needs_paste_access_control?(path)
        return true
      end

      # Determine access requirements based on path
      require_owner = path.ends_with?("/edit") || path.ends_with?("/history")
      allow_raw_encrypted = path.ends_with?("/raw")

      access_result = Pasto.validate_paste_access(env, require_owner: require_owner, allow_raw_encrypted: allow_raw_encrypted)
      unless access_result.success?
        env.response.status_code = access_result.status_code
        env.response.content_type = "text/plain"
        env.response.print access_result.reason || "Access denied"
        env.response.close
        return false
      end

      true
    end

    # API authentication result
    struct AuthResult
      property? success : Bool
      property user : User?
      property error : String?
      property message : String?

      def initialize(@success : Bool, @user : User?, @error : String?, @message : String?)
      end

      def self.success(user : User) : AuthResult
        new(success: true, user: user, error: nil, message: nil)
      end

      def self.failure(error : String, message : String) : AuthResult
        new(success: false, user: nil, error: error, message: message)
      end
    end

    # Helper to validate API key and get current user via API authentication
    def self.get_api_user(env) : User?
      # Extract Authorization header
      auth_header = env.request.headers["Authorization"]?
      return nil unless auth_header

      # Parse Bearer token
      if auth_header.starts_with?("Bearer ")
        api_key_string = auth_header[7..-1] # Remove "Bearer " prefix
      else
        return nil
      end

      # Validate API key format (pasto_ak_*)
      return nil unless api_key_string.starts_with?("pasto_ak_")

      # Fast lookup: find API key by its actual key string
      begin
        api_key = ApiKey.find_by_key(api_key_string)
        return nil unless api_key

        # Increment usage counter
        api_key.increment_usage

        # Find the associated user
        user = User.find(api_key.user_id)
        user
      rescue
        nil
      end
    end

    # API authentication middleware
    def self.require_api_auth(env) : AuthResult
      api_user = get_api_user(env)
      unless api_user
        return AuthResult.failure("Unauthorized", "Valid API key required. Use: Authorization: Bearer your-api-key")
      end

      # Store user ID in context for route handlers (Kemal context only supports simple types)
      env.set("api_user_id", api_user.sepia_id)
      AuthResult.success(api_user)
    end

    # Helper to get API user from stored ID
    def self.get_api_user_from_context(env) : User?
      user_id = env.get?("api_user_id").try(&.as(String))
      user_id ? User.find(user_id) : nil
    end

    # Apply API authentication with proper response handling
    def self.apply_api_auth(env) : Bool
      auth_result = require_api_auth(env)
      unless auth_result.success?
        env.response.status_code = 401
        env.response.content_type = "application/json"
        env.response.print({
          error: auth_result.error,
          message: auth_result.message
        }.to_json)
        env.response.close
        return false
      end
      true
    end
  end
end
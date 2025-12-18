require "../src/paste"
require "../src/ratelimit"
require "kemal"
require "uri"
require "./logging"

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

    # CORS headers filter for API endpoints
    def self.add_cors_headers(env)
      origin = env.request.headers["Origin"]?
      return unless origin

      allowed_origin = determine_allowed_origin(origin)
      return unless allowed_origin

      set_cors_headers(env, allowed_origin)
    end

    # Determines if the origin is allowed for CORS
    private def self.determine_allowed_origin(origin : String) : String?
      server_url = server_origin
      return origin if server_url && origin == server_url
      return origin if origin_allowed_for_development?(origin)
      nil
    end

    # Gets the server's base URL origin for CORS comparison
    private def self.server_origin : String?
      config = Pasto.config
      return nil if !config || config.base_url.empty?

      begin
        uri = URI.parse(config.base_url)
        "#{uri.scheme}://#{uri.host}#{uri.port && uri.port != 80 && uri.port != 443 ? ":#{uri.port}" : ""}"
      rescue
        nil
      end
    end

    # Checks if origin is allowed for development purposes
    private def self.origin_allowed_for_development?(origin : String) : Bool
      origin.matches?(/https?:\/\/localhost(:\d+)?/) || origin.matches?(/https?:\/\/127\.0\.0\.1(:\d+)?/)
    end

    # Sets the actual CORS headers on the response
    private def self.set_cors_headers(env, origin : String)
      env.response.headers["Access-Control-Allow-Origin"] = origin
      env.response.headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, DELETE, OPTIONS, HEAD"
      env.response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, X-Requested-With"
      env.response.headers["Access-Control-Allow-Credentials"] = "false"
      env.response.headers["Access-Control-Max-Age"] = "86400" # 24 hours
    end

    # Handle preflight OPTIONS requests for CORS
    def self.handle_cors_preflight(env) : Bool
      if env.request.method == "OPTIONS"
        env.response.status_code = 204
        env.response.content_type = "text/plain"
        env.response.headers["Content-Length"] = "0"
        add_cors_headers(env)
        return false # Signal that request is handled
      end
      true
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
        allowed, rate_limit_response = Pasto::RateLimitHelper.check_and_handle_rate_limit(env, :http)
        unless allowed
          env.response.print rate_limit_response
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
          Pasto::Logging.error("Error burning paste #{burn_id}: #{ex.message}")
        end
      end
    end

    # Paths that should skip paste access control
    SKIP_ACCESS_CONTROL = [
      "/help", "/profile", "/", "/api-docs", "/openapi.yaml",
      "/favicon", "/favicon.ico", "/favicon.png", "/syntax-theme.css",
    ]

    # Path prefixes that should skip paste access control
    SKIP_ACCESS_CONTROL_PREFIXES = [
      "/auth/", "/api/", "/assets/", "/cache/", "/preview/",
      "/api/qr/", "/api/languages", "/api/themes",
      "/syntax",
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

      access_result = Pasto.validate_paste_access(env, require_owner: require_owner)
      unless access_result.success?
        if access_result.status_code == 404
          raise Kemal::Exceptions::RouteNotFound.new(env)
        elsif access_result.status_code == 403
          # Set status code and raise a custom exception to trigger the 403 error handler
          env.response.status_code = 403
          raise Kemal::Exceptions::CustomException.new(env, "Access denied")
        else
          env.response.status_code = access_result.status_code
          env.response.content_type = "text/plain"
          env.response.print "Access denied"
          env.response.close
          return false
        end
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
          error:   auth_result.error,
          message: auth_result.message,
        }.to_json)
        env.response.close
        return false
      end
      true
    end
  end
end

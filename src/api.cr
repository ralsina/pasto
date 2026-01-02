require "./logging"
require "./routes/api_routes"

module Pasto
  # CORS middleware for API endpoints (must run first)
  before_all do |env|
    # Check if the request path starts with /api/ (considering base_path)
    base_path = Pasto.config.base_path
    request_path = env.request.path

    # Remove base_path from request path for checking
    path_without_base = if base_path != "/" && request_path.starts_with?(base_path)
                          request_path[base_path.size..-1]
                        else
                          request_path
                        end

    # Only apply to API routes
    if path_without_base.starts_with?("/api/")
      # Handle preflight OPTIONS requests
      continue = Pasto::Filters.handle_cors_preflight(env)
      unless continue
        next # Skip further processing for OPTIONS requests
      end

      # Add CORS headers to all API responses
      Pasto::Filters.add_cors_headers(env)
    end
  end

  # API v1 authentication middleware
  before_all do |env|
    # Check if the request path starts with /api/v1/ (considering base_path)
    base_path = Pasto.config.base_path
    request_path = env.request.path

    # Remove base_path from request path for checking
    path_without_base = if base_path != "/" && request_path.starts_with?(base_path)
                          request_path[base_path.size..-1]
                        else
                          request_path
                        end

    if path_without_base.starts_with?("/api/v1/")
      next unless Pasto::Filters.apply_api_auth(env)
    end
  end
end

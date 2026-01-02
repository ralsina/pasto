module Pasto
  # Path helper for base_path support
  module PathHelper
    # Normalize base path to ensure it starts with / and doesn't end with /
    # Returns "/" for empty input
    def self.normalize_base_path(path : String) : String
      return "/" if path.empty? || path.blank?

      # Ensure it starts with /
      normalized = path.starts_with?("/") ? path : "/#{path}"

      # Remove trailing slash unless it's just "/"
      normalized = normalized.rstrip("/") unless normalized == "/"

      normalized
    end

    # Prepend base_path to a route path
    # Prevents double slashes and ensures proper formatting
    def self.with_base_path(path : String, base_path : String) : String
      # Normalize the route path to ensure it starts with /
      route_path = path.starts_with?("/") ? path : "/#{path}"

      # If base_path is just "/", return the route path as-is
      return route_path if base_path == "/"

      # Remove leading slash from route_path to avoid double slashes
      route_without_slash = route_path.lstrip("/")

      # Combine base_path and route path
      "#{base_path}/#{route_without_slash}"
    end

    # Extract the route path from a full path (removes base_path)
    # Useful for getting the paste ID from a URL
    def self.remove_base_path(full_path : String, base_path : String) : String
      return full_path if base_path == "/"

      # Remove base_path prefix if present
      if full_path.starts_with?(base_path)
        remaining = full_path[base_path.size..-1]

        # Ensure the result starts with /
        return remaining.starts_with?("/") ? remaining : "/#{remaining}"
      end

      full_path
    end
  end
end

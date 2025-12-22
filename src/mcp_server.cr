require "mcp"
require "json"
require "./models/*"
require "./filters"
require "./logging"
require "./mcp_tools/*"

module Pasto
  # MCP Auth Provider implementation for Pasto
  # Handles authentication using existing Pasto authentication system
  class PastoMCPAuthProvider < MCP::AuthProvider
    def get_user_id(env) : String
      # Try API key authentication first
      user = Pasto::Filters.get_api_user(env)

      # Fallback to session authentication
      user ||= Pasto.get_current_user(env)

      # Raise error if not authenticated
      raise "Unauthorized: No valid authentication found" unless user

      # Return user ID as string
      user.sepia_id.to_s
    end

    def authenticate?(env) : Bool
      # Try API key authentication first
      user = Pasto::Filters.get_api_user(env)

      # Fallback to session authentication
      user ||= Pasto.get_current_user(env)

      # Return true if user is authenticated
      !!user
    end
  end

  # MCP Log Provider implementation for Pasto
  # Uses Pasto's existing logging system
  class PastoMCPLogProvider < MCP::LogProvider
    def info(&)
      Pasto::Logging.info(yield)
    end

    def error(message : String, exception : Exception? = nil)
      if exception
        Pasto::Logging.error("#{message}: #{exception.message}")
      else
        Pasto::Logging.error(message)
      end
    end

    def debug(message : String)
      Pasto::Logging.debug(message)
    end

    def warn(message : String)
      Pasto::Logging.warn(message)
    end
  end

  # MCP Configuration for Pasto
  # Provides Pasto-specific MCP configuration
  class PastoMCPConfig < MCP::DefaultMCPConfig
    def enabled? : Bool
      # Could be configurable in the future
      true
    end

    def server_name : String
      "Pasto"
    end

    def server_version : String
      # Use the same version as Pasto itself
      "0.6.0"
    end
  end

  # Helper to create MCP handler with authentication
  def self.create_mcp_handler
    auth_provider = PastoMCPAuthProvider.new
    logger = PastoMCPLogProvider.new
    config = PastoMCPConfig.new

    # Create MCP server with our config and logger
    mcp_server = MCP::Server.new(config, logger)

    MCP::Handler.new(auth_provider, logger, mcp_server)
  end

  # Helper to extract current user from authentication
  def self.extract_user_from_mcp_auth(env) : User?
    # Try API key authentication first
    user = Filters.get_api_user(env)

    # Fallback to session authentication
    user ||= get_current_user(env)

    user
  end
end
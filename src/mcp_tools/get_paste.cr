require "mcp"
require "../models/*"
require "../filters"

module Pasto
  # MCP Tool for retrieving paste content by ID
  class GetPasteTool < MCP::AbstractTool
    @@tool_name = "get_paste"
    @@tool_description = "Retrieve paste content and metadata by ID"
    @@tool_input_schema = {
      "type"       => "object",
      "properties" => {
        "id" => {
          "type"        => "string",
          "description" => "The paste ID to retrieve (required)",
        },
      },
      "required" => ["id"],
    }.to_json

    def invoke(params : Hash(String, JSON::Any), env : HTTP::Server::Context? = nil) : Hash
      # Extract current user from authentication
      user = extract_authenticated_user(env)

      # Get paste ID
      id = params["id"]?.try(&.as_s)
      if id.nil? || id.empty?
        return error_response("Paste ID is required")
      end

      # Load the paste
      paste = Paste.from_file(id)
      if paste.nil?
        return error_response("Paste not found: #{id}")
      end

      # Check access permissions
      unless can_access_paste(paste, user)
        return error_response("Access denied: You don't have permission to access this paste")
      end

      # Check if paste has expired
      if paste.expired?
        return error_response("Paste has expired")
      end

      # Handle burn-after-reading
      content = if paste.is_encrypted?
                  # For encrypted pastes, return the encrypted content
                  paste.encrypted_content || paste.content
                else
                  paste.content
                end

      # Note: For burn-after-reading pastes, the view count increment
      # will be handled by the main server when the paste is actually viewed

      # Build response text
      expires_text = paste.expires_at || "Never"
      response_text = <<-TEXT
        📄 Paste Information:

        🆔 ID: #{paste.sepia_id}
        🏷️  Title: #{paste.display_title}
        🔤 Language: #{paste.language}
        🔐 Private: #{paste.private?}
        🔒 Encrypted: #{paste.is_encrypted?}
        🔥 Burn after reading: #{paste.burn_after_reading?}
        ⏰ Created: #{paste.created_at}
        📅 Expires: #{expires_text}

        ---

        📝 Content:
        #{content}
        TEXT

      # Return paste information
      {
        "content" => [
          {
            "type" => "text",
            "text" => response_text,
          },
        ],
      }
    rescue ex
      Pasto::Logging.error("GetPasteTool error: #{ex.message}")
      error_response("Failed to retrieve paste: #{ex.message}")
    end

    private def extract_authenticated_user(env : HTTP::Server::Context?) : User
      # Check if env is available
      return extract_authenticated_user_fallback unless env

      # Try API key authentication first
      user = Pasto::Filters.get_api_user(env)

      # Fallback to session authentication
      user ||= Pasto.get_current_user(env)

      # Raise error if not authenticated
      raise "Unauthorized: No valid authentication found" unless user

      user
    end

    private def extract_authenticated_user_fallback : User
      raise "Unauthorized: No valid authentication found"
    end

    private def can_access_paste(paste : Paste, user : User?) : Bool
      # Public pastes can be accessed by anyone
      return true unless paste.private?

      # Private pastes require user to be the owner
      return false unless user

      # Check if user owns the paste
      paste.user_id == user.sepia_id
    end

    private def error_response(message : String) : Hash
      {
        "content" => [
          {
            "type" => "text",
            "text" => "❌ Error: #{message}",
          },
        ],
      }
    end
  end
end

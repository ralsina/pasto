require "mcp"
require "../models/*"
require "../filters"

module Pasto
  # MCP Tool for permanently deleting pastes
  class DeletePasteTool < MCP::AbstractTool
    @@tool_name = "delete_paste"
    @@tool_description = "Permanently delete a paste"
    @@tool_input_schema = {
      "type" => "object",
      "properties" => {
        "id" => {
          "type" => "string",
          "description" => "The paste ID to delete (required)"
        },
        "confirm" => {
          "type" => "boolean",
          "description" => "Confirmation that you want to permanently delete this paste",
          "default" => false
        }
      },
      "required" => ["id", "confirm"]
    }.to_json

    def invoke(params : Hash(String, JSON::Any), env : HTTP::Server::Context? = nil) : Hash
      # Extract current user from authentication
      user = extract_authenticated_user(env)

      # Get required parameters
      id = params["id"]?.try(&.as_s)
      confirm = params["confirm"]?.try(&.as_bool) || false

      if id.nil? || id.empty?
        return error_response("Paste ID is required")
      end

      unless confirm
        return error_response("You must confirm the deletion by setting 'confirm' to true")
      end

      # Load the paste
      paste = Paste.from_file(id)
      if paste.nil?
        return error_response("Paste not found: #{id}")
      end

      # Verify ownership (user must own the paste to delete it)
      unless can_delete_paste(paste, user)
        return error_response("Access denied: You don't have permission to delete this paste")
      end

      begin
        # Store paste details for confirmation response
        paste_title = paste.display_title
        paste_language = paste.language || "Unknown"
        paste_created = paste.created_at
        is_private = paste.private?
        is_encrypted = paste.is_encrypted?
        is_burn_after_reading = paste.burn_after_reading?

        # Delete the paste
        paste.delete

        # Build confirmation response
        response_text = build_delete_response(id, paste_title, paste_language, paste_created, is_private, is_encrypted, is_burn_after_reading)

        {
          "content" => [
            {
              "type" => "text",
              "text" => response_text
            }
          ]
        }
      rescue ex
        Pasto::Logging.error("DeletePasteTool error: #{ex.message}")
        error_response("Failed to delete paste: #{ex.message}")
      end
    end

    private def extract_authenticated_user(env : HTTP::Server::Context?) : User
      # Try API key authentication first
      user = Pasto::Filters.get_api_user(env.not_nil!)

      # Fallback to session authentication
      user ||= Pasto.get_current_user(env.not_nil!)

      # Raise error if not authenticated
      raise "Unauthorized: No valid authentication found" unless user

      user
    end

    private def can_delete_paste(paste : Paste, user : User) : Bool
      # User can delete their own pastes
      paste.user_id == user.sepia_id
    end

    private def build_delete_response(
      id : String,
      title : String,
      language : String,
      created_at : Time,
      is_private : Bool,
      is_encrypted : Bool,
      is_burn_after_reading : Bool
    ) : String
      privacy_icon = is_private ? "🔐" : "🌐"
      encryption_icon = is_encrypted ? "🔒" : ""
      burn_icon = is_burn_after_reading ? "🔥" : ""

      <<-TEXT
      ✅ **Paste Deleted Successfully!**

      🗑️ **Deleted Paste Details:**
      🆔 ID: #{id}
      #{privacy_icon}#{encryption_icon}#{burn_icon} **Title:** #{title}
      🔤 **Language:** #{language}
      📅 **Created:** #{created_at}
      ⏰ **Deleted:** #{Time.utc}

      ⚠️ This action is permanent and cannot be undone. The paste has been removed from the system.
      TEXT
    end

    private def error_response(message : String) : Hash
      {
        "content" => [
          {
            "type" => "text",
            "text" => "❌ Error: #{message}"
          }
        ]
      }
    end
  end
end
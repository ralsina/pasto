require "mcp"
require "../models/*"
require "../filters"

module Pasto
  # MCP Tool for updating existing pastes (creates new version)
  class UpdatePasteTool < MCP::AbstractTool
    @@tool_name = "update_paste"
    @@tool_description = "Update an existing paste's content or metadata (creates new version)"
    @@tool_input_schema = {
      "type"       => "object",
      "properties" => {
        "id" => {
          "type"        => "string",
          "description" => "The paste ID to update (required)",
        },
        "content" => {
          "type"        => "string",
          "description" => "New content for the paste (required)",
        },
        "title" => {
          "type"        => "string",
          "description" => "New title for the paste (optional)",
        },
        "language" => {
          "type"        => "string",
          "description" => "New programming language for syntax highlighting (optional)",
        },
        "filename" => {
          "type"        => "string",
          "description" => "New filename for language detection (optional)",
        },
        "private" => {
          "type"        => "boolean",
          "description" => "Make paste private (optional)",
        },
        "burn_after_reading" => {
          "type"        => "boolean",
          "description" => "Set burn-after-reading flag (optional)",
        },
        "expires_in" => {
          "type"        => "string",
          "description" => "Update expiration: 1h, 1d, 1w, 1m, never (optional)",
          "enum"        => ["1h", "1d", "1w", "1m", "never"],
        },
      },
      "required" => ["id", "content"],
    }.to_json

    def invoke(params : Hash(String, JSON::Any), env : HTTP::Server::Context? = nil) : Hash
      # Extract current user from authentication
      user = extract_authenticated_user(env)

      # Get required parameters
      id = params["id"]?.try(&.as_s)
      content = params["content"]?.try(&.as_s)

      if id.nil? || id.empty?
        return error_response("Paste ID is required")
      end

      if content.nil? || content.empty?
        return error_response("Content is required")
      end

      # Load the existing paste
      paste = Paste.from_file(id)
      if paste.nil?
        return error_response("Paste not found: #{id}")
      end

      # Verify ownership (user must own the paste to update it)
      unless can_update_paste(paste, user)
        return error_response("Access denied: You don't have permission to update this paste")
      end

      # Check if paste has expired
      if paste.expired?
        return error_response("Cannot update expired paste")
      end

      # Get optional parameters
      title = params["title"]?.try(&.as_s)
      language = params["language"]?.try(&.as_s)
      filename = params["filename"]?.try(&.as_s)
      private_flag = params["private"]?.try(&.as_bool)
      burn_after_reading = params["burn_after_reading"]?.try(&.as_bool)
      expires_in = params["expires_in"]?.try(&.as_s)

      # Validate content size
      max_size = Pasto.config.max_paste_size || 102400
      if content.bytesize > max_size
        return error_response("Content too large. Maximum size is #{max_size} bytes")
      end

      begin
        # Get user's SSH key for the update
        ssh_key = user.keys.first?
        unless ssh_key
          return error_response("You need an SSH key to update pastes")
        end

        # Create new version of the paste
        updated_paste = create_paste_version(
          ssh_key,
          content,
          title,
          language,
          filename,
          private_flag,
          burn_after_reading,
          expires_in
        )

        # Build response URL
        host = env.try(&.request.headers["Host"]?) || "localhost:3000"
        scheme = env.try(&.request.headers["X-Forwarded-Proto"]?) || "http"
        paste_url = "#{scheme}://#{host}/#{updated_paste.sepia_id}"

        response_text = build_update_response(updated_paste, paste_url, paste.sepia_id)

        {
          "content" => [
            {
              "type" => "text",
              "text" => response_text,
            },
          ],
        }
      rescue ex
        Pasto::Logging.error("UpdatePasteTool error: #{ex.message}")
        error_response("Failed to update paste: #{ex.message}")
      end
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

    private def can_update_paste(paste : Paste, user : User) : Bool
      # User can update their own pastes
      paste.user_id == user.sepia_id
    end

    private def create_paste_version(
      ssh_key : SSHKey,
      content : String,
      title : String?,
      language : String?,
      filename : String?,
      private_flag : Bool?,
      burn_after_reading : Bool?,
      expires_in : String?,
    ) : Paste
      # Create new paste version
      new_paste = ssh_key.create_paste(
        content: content,
        theme: "default", # Keep current theme or use default
        language: language,
        filename: filename,
        title: title,
        encrypted: false # New versions are not encrypted by default
      )

      # Apply updated properties
      new_paste.private = private_flag if private_flag
      new_paste.burn_after_reading = burn_after_reading if burn_after_reading

      # Handle expiration
      case expires_in
      when "1h"
        new_paste.expires_at = Time.utc + 1.hour
      when "1d"
        new_paste.expires_at = Time.utc + 1.day
      when "1w"
        new_paste.expires_at = Time.utc + 1.week
      when "1m"
        new_paste.expires_at = Time.utc + 1.month
      when "never"
        new_paste.expires_at = Time.utc(9999, 1, 1)
      end

      # Save the new version
      unless new_paste.save
        raise "Failed to save updated paste"
      end

      new_paste
    end

    private def build_update_response(new_paste : Paste, paste_url : String, original_id : String) : String
      expires_text = if new_paste.expires_at
                       "⏰ Expires: #{new_paste.expires_at}"
                     else
                       "⏰ Never expires"
                     end

      <<-TEXT
      ✅ **Paste Updated Successfully!**

      🔗 **New Version URL:** #{paste_url}
      📝 **New ID:** #{new_paste.sepia_id}
      🔄 **Original ID:** #{original_id}

      **Updated Paste Details:**
      🏷️  Title: #{new_paste.display_title}
      🔤 Language: #{new_paste.language}
      🔐 Private: #{new_paste.private?}
      🔒 Encrypted: #{new_paste.is_encrypted?}
      🔥 Burn after reading: #{new_paste.burn_after_reading?}
      #{expires_text}
      📅 Updated: #{Time.utc}

      Note: This creates a new version of the paste. The original paste (#{original_id}) remains unchanged.
      TEXT
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

require "mcp"
require "../models/*"
require "../filters"

module Pasto
  # MCP Tool for creating new pastes
  class CreatePasteTool < MCP::AbstractTool
    @@tool_name = "create_paste"
    @@tool_description = "Create a new paste with content and optional metadata"
    @@tool_input_schema = {
      "type" => "object",
      "properties" => {
        "content" => {
          "type" => "string",
          "description" => "The paste content (required)"
        },
        "title" => {
          "type" => "string",
          "description" => "Optional paste title"
        },
        "language" => {
          "type" => "string",
          "description" => "Programming language for syntax highlighting"
        },
        "filename" => {
          "type" => "string",
          "description" => "Filename for language detection"
        },
        "private" => {
          "type" => "boolean",
          "description" => "Make paste private (default: false)",
          "default" => false
        },
        "encrypted" => {
          "type" => "boolean",
          "description" => "Encrypt paste content (default: false)",
          "default" => false
        },
        "burn_after_reading" => {
          "type" => "boolean",
          "description" => "Delete after first view (default: false)",
          "default" => false
        },
        "expires_in" => {
          "type" => "string",
          "description" => "Expiration time: 1h, 1d, 1w, 1m, never (default: never)",
          "enum" => ["1h", "1d", "1w", "1m", "never"],
          "default" => "never"
        }
      },
      "required" => ["content"]
    }.to_json

    def invoke(params : Hash(String, JSON::Any), env : HTTP::Server::Context? = nil) : Hash
      begin
        # Extract current user from authentication
        user = extract_authenticated_user(env)

        # Validate content size
        content = params["content"]?.try(&.as_s) || ""
        if content.empty?
          return error_response("Content is required")
        end

        max_size = Pasto.config.max_paste_size || 102400
        if content.bytesize > max_size
          return error_response("Content too large. Maximum size is #{max_size} bytes")
        end

        # Extract optional parameters
        title = params["title"]?.try(&.as_s)
        language = params["language"]?.try(&.as_s)
        filename = params["filename"]?.try(&.as_s)
        is_private = params["private"]?.try(&.as_bool) || false
        is_encrypted = params["encrypted"]?.try(&.as_bool) || false
        burn_after_reading = params["burn_after_reading"]?.try(&.as_bool) || false
        expires_in = params["expires_in"]?.try(&.as_s) || "never"

        # Check user has SSH key (required for paste creation)
        ssh_key = user.keys.first?
        unless ssh_key
          return error_response("You need an SSH key to create pastes. Add one in your profile.")
        end

        # Create the paste
        paste = ssh_key.create_paste(
          content: content,
          theme: user.syntax_theme || "default",
          language: language,
          filename: filename,
          title: title,
          encrypted: is_encrypted
        )

        # Set additional properties
        paste.private = is_private
        paste.burn_after_reading = burn_after_reading
        paste.user_id = user.sepia_id

        # Handle expiration
        case expires_in
        when "1h"
          paste.expires_at = Time.utc + 1.hour
        when "1d"
          paste.expires_at = Time.utc + 1.day
        when "1w"
          paste.expires_at = Time.utc + 1.week
        when "1m"
          paste.expires_at = Time.utc + 1.month
        when "never"
          # No expiration
        end

        # Save paste
        unless paste.save
          return error_response("Failed to save paste")
        end

        # Build URL
        host = env.try(&.request.headers["Host"]?) || "localhost:3000"
        scheme = env.try(&.request.headers["X-Forwarded-Proto"]?) || "http"
        paste_url = "#{scheme}://#{host}/#{paste.sepia_id}"

        # Return success response
        {
          "content" => [
            {
              "type" => "text",
              "text" => "✅ Paste created successfully!\n\n🔗 URL: #{paste_url}\n📝 ID: #{paste.sepia_id}\n🏷️  Title: #{paste.display_title}\n🔐 Private: #{paste.private?}\n🔒 Encrypted: #{paste.is_encrypted?}\n🔥 Burn after reading: #{paste.burn_after_reading?}\n⏰ Expires: #{expires_in}"
            }
          ]
        }
      rescue ex
        Pasto::Logging.error("CreatePasteTool error: #{ex.message}")
        error_response("Failed to create paste: #{ex.message}")
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
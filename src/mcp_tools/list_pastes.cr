require "mcp"
require "../models/*"
require "../filters"

module Pasto
  # MCP Tool for listing user's pastes with pagination
  class ListPastesTool < MCP::AbstractTool
    @@tool_name = "list_pastes"
    @@tool_description = "List user's pastes with pagination and filtering options"
    @@tool_input_schema = {
      "type" => "object",
      "properties" => {
        "page" => {
          "type" => "integer",
          "description" => "Page number (default: 1)",
          "minimum" => 1,
          "default" => 1
        },
        "limit" => {
          "type" => "integer",
          "description" => "Items per page (default: 20, max: 100)",
          "minimum" => 1,
          "maximum" => 100,
          "default" => 20
        },
        "private_only" => {
          "type" => "boolean",
          "description" => "Filter to private pastes only (default: false)",
          "default" => false
        },
        "public_only" => {
          "type" => "boolean",
          "description" => "Filter to public pastes only (default: false)",
          "default" => false
        },
        "encrypted_only" => {
          "type" => "boolean",
          "description" => "Filter to encrypted pastes only (default: false)",
          "default" => false
        },
        "language" => {
          "type" => "string",
          "description" => "Filter by programming language (optional)"
        }
      }
    }.to_json

    def invoke(params : Hash(String, JSON::Any), env : HTTP::Server::Context? = nil) : Hash
      # Extract current user from authentication
      user = extract_authenticated_user(env)

      # Parse pagination parameters
      page = get_parameter(params, "page", 1)
      limit = get_parameter(params, "limit", 20)
      private_only = get_parameter_bool(params, "private_only", false)
      public_only = get_parameter_bool(params, "public_only", false)
      encrypted_only = get_parameter_bool(params, "encrypted_only", false)
      language_filter = get_parameter(params, "language", "")

      # Validate parameters
      if limit > 100
        limit = 100
      end

      if page < 1
        page = 1
      end

      # Get user's pastes with pagination
      user_pastes = get_user_pastes_with_pagination(user, page, limit)

      # Apply filters
      filtered_pastes = apply_filters(user_pastes, private_only, public_only, encrypted_only, language_filter)

      # Build response
      if filtered_pastes.empty?
        return {
          "content" => [
            {
              "type" => "text",
              "text" => "📄 No pastes found matching your criteria."
            }
          ]
        }
      end

      # Build paste summaries
      paste_summaries = filtered_pastes.map do |paste|
        paste_summary(paste)
      end.join("\n")

      # Calculate pagination info
      total_pastes = get_total_user_pastes_count(user)
      total_pages = (total_pastes.to_f / limit).ceil.to_i
      current_page = page

      response_text = build_response_text(paste_summaries, current_page, total_pages, total_pastes, limit)

      {
        "content" => [
          {
            "type" => "text",
            "text" => response_text
          }
        ]
      }
    rescue ex
      Pasto::Logging.error("ListPastesTool error: #{ex.message}")
      error_response("Failed to list pastes: #{ex.message}")
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

    private def get_parameter(params : Hash(String, JSON::Any), key : String, default : Int32) : Int32
      params[key]?.try(&.as_i) || default
    end

    private def get_parameter_bool(params : Hash(String, JSON::Any), key : String, default : Bool) : Bool
      params[key]?.try(&.as_bool) || default
    end

    private def get_parameter(params : Hash(String, JSON::Any), key : String, default : String) : String
      params[key]?.try(&.as_s) || default
    end

    private def get_user_pastes_with_pagination(user : User, page : Int32, limit : Int32) : Array(Paste)
      # Calculate range for pagination (get more than needed to account for filtering)
      # Use a large range to get all user pastes, then we'll filter and paginate
      all_pastes = user.get_pastes_for_range(0, 10000)

      # Sort by creation date (newest first)
      all_pastes.sort_by(&.created_at).reverse

      # Apply pagination
      offset = (page - 1) * limit
      all_pastes[offset, limit] || [] of Paste
    end

    private def apply_filters(pastes : Array(Paste), private_only : Bool, public_only : Bool, encrypted_only : Bool, language_filter : String?) : Array(Paste)
      pastes.select do |paste|
        # Skip expired pastes
        next false if paste.expired?

        # Apply private/public filter
        if private_only && !paste.private?
          next false
        end

        if public_only && paste.private?
          next false
        end

        # Apply encrypted filter
        if encrypted_only && !paste.is_encrypted?
          next false
        end

        # Apply language filter
        if language_filter && !language_filter.empty?
          paste_lang = paste.language.to_s.downcase
          filter_lang = language_filter.downcase
          lang_match = paste_lang.includes?(filter_lang)
          next false unless lang_match
        end

        true
      end.to_a
    end

    private def paste_summary(paste : Paste) : String
      privacy_icon = paste.private? ? "🔐" : "🌐"
      encryption_icon = paste.is_encrypted? ? "🔒" : ""
      burn_icon = paste.burn_after_reading? ? "🔥" : ""

      expires_text = if paste.expires_at
                      "⏰ Expires: #{paste.expires_at}"
                    else
                      "⏰ Never expires"
                    end

      "#{privacy_icon}#{encryption_icon}#{burn_icon} **#{paste.display_title}** (#{paste.sepia_id})
🔤 #{paste.language}
📅 #{paste.created_at}
#{expires_text}"
    end

    private def build_response_text(paste_summaries : String, current_page : Int32, total_pages : Int32, total_pastes : Int32, limit : Int32) : String
      header = "📄 **Your Pastes (Page #{current_page} of #{total_pages})**"
      header += "\n📊 Total: #{total_pastes} pastes | Showing: #{limit} per page"
      header += "\n\n"

      footer = if current_page < total_pages
                 "\n\n---\n📖 Use page #{current_page + 1} to see more pastes"
               elsif total_pages > 1
                 "\n\n---\n📖 Use page numbers 1-#{total_pages} to navigate"
               else
                 ""
               end

      "#{header}#{paste_summaries}#{footer}"
    end

    private def get_total_user_pastes_count(user : User) : Int32
      # Get all pastes for the user and count non-expired ones
      all_pastes = user.get_pastes_for_range(0, 10000)
      all_pastes.count { |paste| !paste.expired? }
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
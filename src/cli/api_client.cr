require "http"
require "json"
require "../cli/config"

module PastoCLI
  class APIClient
    @base_url : String
    @api_host : String
    @api_port : Int32

    def initialize(@config : Config)
      # Load credentials to get the server URL
      creds = Credentials.load

      # Use saved server_url if available, otherwise use config
      @base_url = creds.server_url || @config.server_url

      # Extract host and port from server URL for HTTP::Client
      uri = URI.parse(@base_url)
      @api_host = uri.host || "localhost"

      # Handle default ports
      @api_port = uri.port || begin
        if @base_url.starts_with?("https://")
          443
        elsif @base_url.starts_with?("http://")
          80
        else
          3000
        end
      end
    end

    # Expose base_url for constructing paste URLs
    def base_url : String
      @base_url
    end

    def me : JSON::Any
      get("/api/v1/me")
    end

    def list_pastes(page : Int32 = 1, limit : Int32 = 20) : JSON::Any
      get("/api/v1/pastes?page=#{page}&limit=#{limit}")
    end

    def get_paste(id : String) : JSON::Any
      get("/api/v1/pastes/#{id}")
    end

    def get_paste_content(id : String) : String
      headers = auth_headers
      headers["Content-Type"] = "text/plain"

      response = http_client.get("#{@base_url}/api/v1/pastes/#{id}/content", headers)

      check_response(response)

      response.body
    end

    def create_paste(content : String, title : String? = nil, language : String? = nil,
                     filename : String? = nil, is_private : Bool = false, encrypted : Bool = false,
                     burn_after_reading : Bool = false) : JSON::Any
      data = Hash(String, JSON::Any::Type | Bool).new
      data["content"] = content

      data["title"] = title if title
      data["language"] = language if language
      data["filename"] = filename if filename
      data["private"] = is_private if is_private
      data["encrypted"] = encrypted if encrypted
      data["burn_after_reading"] = burn_after_reading if burn_after_reading

      post("/api/v1/pastes", data)
    end

    def delete_paste(id : String) : JSON::Any
      delete("/api/v1/pastes/#{id}")
    end

    private def get(path : String) : JSON::Any
      response = http_client.get("#{@base_url}#{path}", auth_headers)
      check_response(response)
      JSON.parse(response.body)
    end

    private def post(path : String, data : Hash(String, JSON::Any::Type | Bool)) : JSON::Any
      headers = auth_headers
      headers["Content-Type"] = "application/json"

      body = data.to_json
      response = http_client.post("#{@base_url}#{path}", headers, body)
      check_response(response)
      JSON.parse(response.body)
    end

    private def delete(path : String) : JSON::Any
      response = http_client.delete("#{@base_url}#{path}", auth_headers)
      check_response(response)
      JSON.parse(response.body)
    end

    private def auth_headers : HTTP::Headers
      creds = Credentials.load

      unless creds.api_key?
        raise "Not logged in. Please run 'pasto-cli login' first."
      end

      HTTP::Headers{
        "Authorization" => "Bearer #{creds.api_key}",
      }
    end

    private def http_client : HTTP::Client
      # Use TLS for HTTPS URLs
      use_tls = @base_url.starts_with?("https://")

      client = HTTP::Client.new(@api_host, @api_port, tls: use_tls)
      client.connect_timeout = @config.timeout.seconds
      client.read_timeout = @config.timeout.seconds
      client
    end

    private def check_response(response : HTTP::Client::Response) : Nil
      case response.status_code
      when 200..299
        # Success
      when 401
        raise "Authentication failed. Please run 'pasto-cli login' again."
      when 403
        raise "Permission denied. #{error_message(response)}"
      when 404
        raise "Not found. #{error_message(response)}"
      when 413
        raise "Content too large. #{error_message(response)}"
      when 400..499
        raise "Client error: #{response.status_code}. #{error_message(response)}"
      when 500..599
        raise "Server error: #{response.status_code}. #{error_message(response)}"
      else
        raise "Unexpected response: #{response.status_code}"
      end
    end

    private def error_message(response : HTTP::Client::Response) : String
      begin
        json = JSON.parse(response.body)
        if error = json["message"]?
          return error.as_s
        end
      rescue
        # Not JSON or no message field
      end

      response.body.strip.empty? ? "HTTP #{response.status_code}" : response.body.strip
    end
  end
end

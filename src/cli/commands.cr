require "../cli/config"
require "../cli/ssh_client"
require "../cli/api_client"
require "../time_helper"

module PastoCLI::Commands
  abstract class Base
    @config : Config
    @api_client : APIClient

    def initialize(@config : Config)
      @api_client = APIClient.new(@config)
    end

    private def terminal_supports_hyperlinks? : Bool
      # Check for common terminal environment variables
      # Terminals that support hyperlinks: KDE Konsole, GNOME Terminal, iTerm2, Windows Terminal, Alacritty, kitty, VS Code, etc.
      term_program = ENV["TERM_PROGRAM"]?       # iTerm2, VS Code
      term = ENV["TERM"]?                       # Terminal type
      konsole_version = ENV["KONSOLE_VERSION"]? # KDE Konsole
      wt_session = ENV["WT_SESSION"]?           # Windows Terminal

      # These terminals are known to support hyperlinks
      !!(term_program || konsole_version || wt_session ||
        (term && term.includes?("konsole")) ||
        (term && term.includes?("gnome-terminal")) ||
        (term && term.includes?("alacritty")) ||
        (term && term.includes?("kitty")))
    end

    private def terminal_link(url : String, text : String) : String
      if terminal_supports_hyperlinks?
        # ANSI hyperlink escape sequence
        # Format: \033]8;;url\033\\text\033]8;;\033\\
        "\033]8;;#{url}\033\\#{text}\033]8;;\033\\"
      else
        # Fallback to plain text for unsupported terminals
        text
      end
    end

    private def humanize_date(iso_date : String) : String
      # Parse ISO 8601 date string
      match = iso_date.match(/(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/)
      return iso_date unless match

      year, month, day, hour, minute, second = match[1], match[2], match[3], match[4], match[5], match[6]
      time = Time.utc(year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, second.to_i)

      Pasto::TimeHelper.relative_time(time)
    rescue
      iso_date
    end
  end

  class Login < Base
    def execute : Nil
      puts "Logging in to #{@config.server_url} via SSH..."
      puts "SSH Host: #{@config.ssh_host}:#{@config.ssh_port}"
      puts ""

      # Use SSH client to create API key directly
      ssh_client = SSHClient.new(@config)
      api_key = ssh_client.execute_login

      if api_key.empty?
        raise "Failed to get API key from server"
      end

      # Validate API key format
      unless api_key.starts_with?("pasto_ak_")
        puts "Warning: API key doesn't start with 'pasto_ak_': #{api_key}" if @config.verbose?
      end

      # Store credentials (ensure server_url has protocol)
      server_url = @config.server_url
      unless server_url.starts_with?("http://") || server_url.starts_with?("https://")
        server_url = "https://#{server_url}"
      end

      creds = Credentials.new(api_key, server_url, @config.ssh_host, @config.ssh_port)
      creds.save

      puts "✓ Successfully logged in!"
      puts "  API Key: #{api_key}"
      puts "  Server: #{@config.server_url}"
      puts "  SSH Host: #{@config.ssh_host}:#{@config.ssh_port}"
      puts "  Credentials saved to: #{PastoCLI.credentials_file}"
    end
  end

  class Logout < Base
    def execute : Nil
      creds = Credentials.load

      if creds.api_key?
        creds.clear
        puts "✓ Logged out successfully"
        puts "  Credentials cleared from: #{PastoCLI.credentials_file}"
      else
        puts "Not logged in"
        exit 1
      end
    end
  end

  class Web < Base
    def execute : Nil
      puts "Opening web interface via SSH login..."
      puts "SSH Host: #{@config.ssh_host}:#{@config.ssh_port}"
      puts ""

      # Use SSH client to execute login command (not api-key create)
      ssh_client = SSHClient.new(@config)
      output = ssh_client.execute_login_web

      # Extract the auth URL from the output
      # Format: "To complete login, open this URL in your browser:\nhttps://server/auth/token\n..."
      if match = output.match(/https:\/\/[^\s]+/)
        auth_url = match[0]

        puts "✓ Auth URL generated!"
        puts "  Opening browser..."
        puts ""

        # Open browser using xdg-open
        Process.new("xdg-open", [auth_url])

        puts "The link will expire in 10 minutes."
        puts "After completing login in your browser, you can use 'pasto-cli login' to get an API key."
      else
        puts "Error: Could not extract auth URL from response"
        puts "Output: #{output}"
        exit 1
      end
    end
  end

  class Paste < Base
    def execute : Nil
      content = read_content

      puts "Creating paste..." if @config.verbose?

      result = @api_client.create_paste(
        content: content,
        title: @config.title.empty? ? nil : @config.title,
        language: @config.language.empty? ? nil : @config.language,
        is_private: @config.private?,
        encrypted: @config.encrypted?
      )

      paste_id = result["id"].as_s
      url = result["url"].as_s

      puts "✓ Paste created successfully!"
      puts "  ID: #{paste_id}"
      puts "  URL: #{url}"
      puts "  Raw URL: #{result["raw_url"].as_s}"

      if @config.encrypted?
        puts "  ✓ Encrypted paste"
      end

      if @config.private?
        puts "  🔒 Private paste"
      end
    end

    private def read_content : String
      # Use file from config if provided
      if !@config.file.empty?
        file_path = @config.file

        unless File.exists?(file_path)
          raise "File not found: #{file_path}"
        end

        puts "Reading from file: #{file_path}" if @config.verbose?
        File.read(file_path)
      else
        # Read from stdin
        if STDIN.tty?
          raise "No input provided. Use: pasto-cli paste <file> or echo 'data' | pasto-cli paste"
        end

        puts "Reading from stdin..." if @config.verbose?
        STDIN.gets_to_end
      end
    end
  end

  class Get < Base
    def execute : Nil
      if @config.id.empty?
        raise "Usage: pasto-cli get <id>"
      end

      id = @config.id

      puts "Fetching paste: #{id}" if @config.verbose?

      # Get paste metadata
      paste_data = @api_client.get_paste(id)

      # Display paste info
      puts ""
      puts "=== #{paste_data["title"].as_s} ==="
      puts "ID: #{paste_data["id"].as_s}"
      puts "Language: #{paste_data["language"].as_s}"
      puts "Created: #{paste_data["created_at"].as_s}"
      puts "URL: #{paste_data["url"].as_s}"

      if paste_data["private"].as_bool
        puts "🔒 Private"
      end

      if paste_data["encrypted"].as_bool
        puts "🔐 Encrypted (use web UI to decrypt)"
        puts ""
        puts "This paste is encrypted. Please open the URL in a browser to decrypt."
        return
      end

      puts ""

      # Get paste content
      content = @api_client.get_paste_content(id)
      puts content
    end
  end

  class List < Base
    def execute : Nil
      page = @config.page
      limit = @config.limit

      puts "Fetching pastes (page #{page})..." if @config.verbose?

      result = @api_client.list_pastes(page, limit)

      pastes = result["pastes"].as_a
      pagination = result["pagination"].as_h

      if pastes.empty?
        puts "No pastes found"
        return
      end

      # Display pastes in compact format
      pastes.each do |paste|
        title = paste["title"].as_s
        id = paste["id"].as_s
        language = paste["language"].as_s
        created = paste["created_at"].as_s

        # Construct URL from the API base URL
        url = "#{@api_client.base_url}/#{id}"

        # Collect flags
        flags = [] of String
        flags << "🔒" if paste["private"].as_bool
        flags << "🔐" if paste["encrypted"].as_bool
        flags << "🔥" if paste["burn_after_reading"].as_bool

        flags_str = flags.empty? ? "" : " #{flags.join(" ")}"

        # Make the ID a clickable link
        id_link = terminal_link(url, id)
        puts "#{title} (#{id_link}) - #{language}#{flags_str}"
        puts "  #{humanize_date(created)}"
        puts ""
      end

      # Show pagination info if there are more pages
      total_pages = pagination["pages"].as_i
      if total_pages > 1
        puts "Page #{pagination["page"].as_i} of #{total_pages} (#{pagination["total"].as_i} total)"
      end
    end
  end

  class Delete < Base
    def execute : Nil
      if @config.id.empty?
        raise "Usage: pasto-cli delete <id>"
      end

      id = @config.id

      puts "Deleting paste: #{id}" if @config.verbose?

      @api_client.delete_paste(id)

      puts "✓ Paste deleted successfully: #{id}"
    end
  end
end

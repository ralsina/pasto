require "../src/models/ssh_key"
require "../src/models/auth_token"
require "shirk"
require "sepia"
require "uri"
require "docopt"
require "rate_limiter"

module PastoSSH
  @@current_fingerprint = ""
  @@storage_dir = "./data"
  @@base_url = "http://localhost:5000"

  # Rate limiters for SSH operations
  @@paste_limiter : RateLimiter?
  @@login_limiter : RateLimiter?
  @@conn_limiter : RateLimiter?
  @@rate_mutex = Mutex.new

  def self.storage_dir=(dir : String)
    @@storage_dir = dir
    Sepia::Storage.configure(:filesystem, {"path" => dir})
  end

  def self.base_url=(url : String)
    @@base_url = url
  end

  def self.init_rate_limiters(paste_limit : Int32, paste_window : Int32,
                              login_limit : Int32, login_window : Int32,
                              conn_limit : Int32, conn_window : Int32)
    @@rate_mutex.synchronize do
      @@paste_limiter = RateLimiter.new(paste_limit, paste_window)
      @@login_limiter = RateLimiter.new(login_limit, login_window)
      @@conn_limiter = RateLimiter.new(conn_limit, conn_window)
    end
  end

  # Check connection rate limit
  private def self.allow_connection?(fingerprint : String) : Bool
    @@rate_mutex.synchronize do
      if limiter = @@conn_limiter
        allowed = limiter.allow?(fingerprint)
        unless allowed
          puts "⚠️  SSH rate limit hit: connection limit (Key: #{fingerprint})"
        end
        allowed
      else
        true
      end
    end
  end

  # Check paste rate limit
  private def self.allow_paste?(fingerprint : String) : Bool
    @@rate_mutex.synchronize do
      if limiter = @@paste_limiter
        allowed = limiter.allow?(fingerprint)
        unless allowed
          puts "⚠️  SSH rate limit hit: paste limit (Key: #{fingerprint})"
        end
        allowed
      else
        true
      end
    end
  end

  # Check login rate limit
  private def self.allow_login?(fingerprint : String) : Bool
    @@rate_mutex.synchronize do
      if limiter = @@login_limiter
        allowed = limiter.allow?(fingerprint)
        unless allowed
          puts "⚠️  SSH rate limit hit: login limit (Key: #{fingerprint})"
        end
        allowed
      else
        true
      end
    end
  end

  def self.create_server(host_key : String, port : Int32, bind_address : String)
    server = Shirk::Server.new(
      host: bind_address,
      port: port,
      host_key: host_key
    )

    # Accept all public keys and store the fingerprint (with rate limiting)
    server.on_auth_pubkey do |user, fingerprint|
      puts "SSH auth: user '#{user}' with key #{fingerprint}"

      # Check connection rate limit
      unless allow_connection?(fingerprint)
        puts "SSH auth: rejected due to rate limit"
        next false
      end

      @@current_fingerprint = fingerprint
      true # Accept key
    end

    # Handle exec requests (ssh host command)
    server.on_exec do |ctx|
      puts "SSH exec: command='#{ctx.command}' from user='#{ctx.user}'"

      # Parse command and arguments
      parts = ctx.command.split(/\s+/, 2)
      cmd = parts[0]? || ""
      args = parts[1]? || ""

      case cmd
      when "paste"
        handle_paste(ctx, @@current_fingerprint, @@base_url, args)
      when "login"
        handle_login(ctx, @@current_fingerprint, @@base_url)
      when "list"
        handle_list(ctx, @@current_fingerprint, @@base_url)
      when "help"
        handle_help(ctx, @@base_url)
      else
        ctx.write_stderr("Unknown command: #{ctx.command}\n")
        ctx.write_stderr("Use 'help' for usage information.\n")
        1
      end
    end

    # Handle shell requests (ssh host without command - treat as paste)
    server.on_shell do |ctx|
      puts "SSH shell: from user='#{ctx.user}' (treating as paste)"
      handle_paste(ctx, @@current_fingerprint, @@base_url, "")
    end

    server
  end

  PASTE_DOC = <<-DOC
Create a paste.

Usage:
  paste [-l LANG] [-f FILE] [-t TITLE]

Options:
  -l LANG, --language LANG   Set the language for syntax highlighting
  -f FILE, --filename FILE   Set a filename (used for language detection)
  -t TITLE, --title TITLE    Set a title for the paste

DOC

  # Handle paste command
  private def self.handle_paste(ctx, fingerprint : String, base_url : String, args : String) : Int32
    # Check paste rate limit
    unless allow_paste?(fingerprint)
      ctx.write_stderr("Rate limit exceeded. Please wait before creating another paste.\n")
      return 1
    end

    content = ctx.stdin

    puts "SSH: received #{content.bytesize} bytes of content"

    if content.strip.empty?
      ctx.write_stderr("No content provided. Usage: echo 'text' | ssh host\n")
      return 1
    end

    # Parse options with docopt
    language : String? = nil
    filename : String? = nil
    title : String? = nil

    unless args.empty?
      begin
        # Split args into array for docopt
        argv = args.split(/\s+/)
        opts = Docopt.docopt(PASTE_DOC, argv: argv, exit: false)

        # Docopt returns long option names as keys
        language = opts["--language"]?.try(&.to_s)
        language = nil if language.nil? || language == "false" || language == "" || language == "nil"

        filename = opts["--filename"]?.try(&.to_s)
        filename = nil if filename.nil? || filename == "false" || filename == "" || filename == "nil"

        title = opts["--title"]?.try(&.to_s)
        title = nil if title.nil? || title == "false" || title == "" || title == "nil"

        puts "SSH: parsed options - language=#{language.inspect}, filename=#{filename.inspect}, title=#{title.inspect}"
      rescue ex : Docopt::DocoptException
        ctx.write_stderr("Invalid options: #{ex.message}\n")
        ctx.write_stderr(PASTE_DOC)
        return 1
      end
    end

    # Load or create SSHKey, create paste through it
    ssh_key = Pasto::SSHKey.find_or_create(fingerprint)

    # Create paste - language detection from filename happens in Paste constructor
    paste = ssh_key.create_paste(
      content: content,
      theme: "default-dark",
      language: language,
      filename: filename,
      title: title
    )

    # Save the paste as a standalone object (so web server can find it)
    unless paste.save
      ctx.write_stderr("Failed to save paste\n")
      return 1
    end

    # Save the SSHKey (with reference to the paste)
    if ssh_key.save
      url = "#{base_url}/#{paste.sepia_id}\n"
      ctx.write(url)
      puts "SSH: created paste #{paste.sepia_id} (key has #{ssh_key.pastes.size} pastes)"
      0
    else
      ctx.write_stderr("Failed to save SSH key\n")
      1
    end
  end

  # Handle login command
  private def self.handle_login(ctx, fingerprint : String, base_url : String) : Int32
    # Check login rate limit
    unless allow_login?(fingerprint)
      ctx.write_stderr("Too many login attempts. Please wait before trying again.\n")
      return 1
    end

    # Create auth token for this fingerprint
    token = Pasto::AuthToken.new(fingerprint)

    if token.save
      url = "#{base_url}/auth/#{token.sepia_id}"
      ctx.write("To complete login, open this URL in your browser:\n")
      ctx.write("#{url}\n")
      ctx.write("\nThis link expires in 10 minutes.\n")
      puts "SSH: created auth token #{token.sepia_id} for #{fingerprint}"
      0
    else
      ctx.write_stderr("Failed to create login token\n")
      1
    end
  end

  # Handle help command
  private def self.handle_help(ctx, base_url : String) : Int32
    # Extract host and port from base_url for examples
    uri = URI.parse(base_url)
    host = uri.host || "localhost"

    ctx.write("Pasto SSH Interface\n")
    ctx.write("===================\n\n")
    ctx.write("Create a paste (two equivalent methods):\n")
    ctx.write("  echo 'Hello World' | ssh #{host}\n")
    ctx.write("  echo 'Hello World' | ssh #{host} paste\n\n")
    ctx.write("Create paste from file:\n")
    ctx.write("  cat file.txt | ssh #{host}\n")
    ctx.write("  ssh #{host} < file.txt\n\n")
    ctx.write("Paste options:\n")
    ctx.write("  -l LANG      Set language (e.g., -l python)\n")
    ctx.write("  -f FILE      Set filename (used for language detection)\n")
    ctx.write("  -t TITLE     Set title\n\n")
    ctx.write("Examples with options:\n")
    ctx.write("  cat code.py | ssh #{host} paste -l python\n")
    ctx.write("  cat code | ssh #{host} paste -f script.rb\n")
    ctx.write("  echo 'test' | ssh #{host} paste -t 'My Test'\n\n")
    ctx.write("List your pastes:\n")
    ctx.write("  ssh #{host} list\n\n")
    ctx.write("Login to associate pastes with your account:\n")
    ctx.write("  ssh #{host} login\n\n")
    ctx.write("Show this help:\n")
    ctx.write("  ssh #{host} help\n")
    0
  end

  # Handle list command - show all pastes for this SSH key
  private def self.handle_list(ctx, fingerprint : String, base_url : String) : Int32
    ssh_key = Pasto::SSHKey.find(Pasto::SSHKey.sanitize_fingerprint(fingerprint))

    unless ssh_key
      ctx.write("No pastes found for this SSH key.\n")
      ctx.write("Create one with: echo 'text' | ssh host\n")
      return 0
    end

    pastes = ssh_key.pastes
    if pastes.empty?
      ctx.write("No pastes found for this SSH key.\n")
      ctx.write("Create one with: echo 'text' | ssh host\n")
      return 0
    end

    ctx.write("Your pastes (#{pastes.size} total):\n")
    ctx.write("=" * 50 + "\n\n")

    pastes.reverse.each do |paste|
      # Format the date nicely
      created = paste.created_at.to_s("%Y-%m-%d %H:%M UTC")

      # Get a preview of the content (first line, truncated)
      preview = paste.content.lines.first?.try(&.strip) || ""
      preview = preview[0, 40] + "..." if preview.size > 40

      # Show language if detected
      lang = paste.language.try { |l| " [#{l}]" } || ""

      ctx.write("#{base_url}/#{paste.sepia_id}\n")
      ctx.write("  Created: #{created}#{lang}\n")
      ctx.write("  Preview: #{preview}\n\n")
    end

    0
  end
end

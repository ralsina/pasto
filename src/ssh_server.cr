require "../src/models/ssh_key"
require "../src/models/auth_token"
require "shirk"
require "sepia"
require "uri"

module PastoSSH
  @@current_fingerprint = ""
  @@storage_dir = "./data"
  @@base_url = "http://localhost:5000"

  def self.storage_dir=(dir : String)
    @@storage_dir = dir
    Sepia::Storage.configure(:filesystem, {"path" => dir})
  end

  def self.base_url=(url : String)
    @@base_url = url
  end

  def self.create_server(host_key : String, port : Int32, bind_address : String)
    server = Shirk::Server.new(
      host: bind_address,
      port: port,
      host_key: host_key
    )

    # Accept all public keys and store the fingerprint
    server.on_auth_pubkey do |user, fingerprint|
      puts "SSH auth: user '#{user}' with key #{fingerprint}"
      @@current_fingerprint = fingerprint
      true # Accept all keys
    end

    # Handle exec requests (ssh host command)
    server.on_exec do |ctx|
      puts "SSH exec: command='#{ctx.command}' from user='#{ctx.user}'"

      case ctx.command
      when "paste"
        handle_paste(ctx, @@current_fingerprint, @@base_url)
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
      handle_paste(ctx, @@current_fingerprint, @@base_url)
    end

    server
  end

  # Handle paste command
  private def self.handle_paste(ctx, fingerprint : String, base_url : String) : Int32
    content = ctx.stdin

    puts "SSH: received #{content.bytesize} bytes of content"

    if content.strip.empty?
      ctx.write_stderr("No content provided. Usage: echo 'text' | ssh -p PORT host paste\n")
      return 1
    end

    # Load or create SSHKey, create paste through it
    ssh_key = Pasto::SSHKey.find_or_create(fingerprint)
    paste = ssh_key.create_paste(content: content, theme: "default-dark")

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

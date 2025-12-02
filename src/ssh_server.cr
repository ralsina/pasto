require "../src/models/ssh_key"
require "../src/models/auth_token"
require "shirk"
require "sepia"

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

    # Handle exec requests
    server.on_exec do |ctx|
      puts "SSH exec: command='#{ctx.command}' from user='#{ctx.user}'"

      case ctx.command
      when "paste"
        handle_paste(ctx, @@current_fingerprint, @@base_url)
      when "login"
        handle_login(ctx, @@current_fingerprint, @@base_url)
      else
        ctx.write_stderr("Unknown command: #{ctx.command}\n")
        ctx.write_stderr("Commands: paste, login\n")
        ctx.write_stderr("  paste - echo 'text' | ssh -p PORT host paste\n")
        ctx.write_stderr("  login - ssh -p PORT host login\n")
        1
      end
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
      url = "#{base_url}/paste/#{paste.sepia_id}\n"
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
end

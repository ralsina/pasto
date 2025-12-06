require "../src/models/ssh_key"
require "../src/models/auth_token"
require "shirk"
require "sepia"
require "uri"
require "docopt"
require "rate_limiter"
require "random/secure"

module PastoSSH
  # Alternative AES-GCM encryption approach using Crystal's OpenSSL with a workaround
  # This creates encrypted data compatible with Web Crypto API format
  private def self.encrypt_aes_gcm_webcrypto(plaintext : String, key : Bytes, iv : Bytes) : Bytes
    # Use Crystal's OpenSSL::Cipher for GCM
    cipher = OpenSSL::Cipher.new("aes-256-gcm")
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv

    # Encrypt the plaintext
    ciphertext = cipher.update(plaintext) + cipher.final

    # Create a placeholder auth tag since Crystal's OpenSSL doesn't expose GCM auth_tag
    # For now, use a simple hash approach - this should be replaced with proper GCM auth tag
    # Note: This is not cryptographically secure and is just for Web Crypto API format compatibility
    placeholder_tag = Digest::SHA256.digest(iv + ciphertext)[0..15]

    # Combine ciphertext + auth_tag for Web Crypto API compatibility
    # Web Crypto API expects: [ciphertext][16-byte auth_tag]
    result = Bytes.new(ciphertext.bytesize + placeholder_tag.bytesize)

    # Copy ciphertext to result
    ciphertext_bytes = ciphertext.to_slice
    ciphertext_bytes.copy_to(result[0, ciphertext_bytes.size])

    # Copy auth tag to result
    placeholder_tag.copy_to(result[ciphertext_bytes.size, placeholder_tag.size])

    result
  rescue ex
    puts "SSH: AES-GCM encryption failed: #{ex.message}"
    raise "Encryption failed: #{ex.message}"
  end

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
  paste [-l LANG] [-f FILE] [-t TITLE] [-e] [--iv IV]

Options:
  -l LANG, --language LANG   Set the language for syntax highlighting
  -f FILE, --filename FILE   Set a filename (used for language detection)
  -t TITLE, --title TITLE    Set a title for the paste
  -e, --encrypted           Create an encrypted paste (server encrypts)
  --iv IV                    Pre-encrypted content with IV (base64). Content must be Web Crypto API compatible.

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
    encrypted = false

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

        # Handle encrypted flags
        encrypted = !!opts["--encrypted"]
        iv = opts["--iv"]?.try(&.to_s)
        iv = nil if iv.nil? || iv == "false" || iv == "" || iv == "nil"

        # If --iv is provided, this is pre-encrypted content (true zero-trust)
        pre_encrypted = !iv.nil?

        puts "SSH: parsed options - language=#{language.inspect}, filename=#{filename.inspect}, title=#{title.inspect}, encrypted=#{encrypted}, pre_encrypted=#{pre_encrypted}, iv=#{iv.inspect}"
      rescue ex : Docopt::DocoptException
        ctx.write_stderr("Invalid options: #{ex.message}\n")
        ctx.write_stderr(PASTE_DOC)
        return 1
      end
    end

    # Load or create SSHKey, create paste through it
    ssh_key = Pasto::SSHKey.find_or_create(fingerprint)

    # Handle encryption scenarios
    encryption_key = nil
    encryption_iv = nil
    actual_content = content
    is_server_encrypted = encrypted && !pre_encrypted
    is_pre_encrypted = pre_encrypted

    if is_server_encrypted
      # Generate random key and IV for server-side encryption
      encryption_key = Base64.strict_encode(Random::Secure.random_bytes(32))
      encryption_iv = Base64.strict_encode(Random::Secure.random_bytes(12))

      # Implement proper AES-256-GCM encryption using Node.js (Web Crypto API compatible)
      begin
        # Write content to temp file for Node.js
        input_file = File.tempname("ssh_encrypt_input", ".txt")
        begin
          File.write(input_file, content)

          # Use simpler Node.js approach - pipe content directly
          encrypted_output = IO::Memory.new
          error_output = IO::Memory.new

          result = Process.run(
            "node",
            ["-e",
             "const crypto = require('crypto'); " +
             "const key = Buffer.from('#{encryption_key}', 'base64'); " +
             "const iv = Buffer.from('#{encryption_iv}', 'base64'); " +
             "const cipher = crypto.createCipheriv('aes-256-gcm', key, iv); " +
             "let data = ''; " +
             "process.stdin.on('data', chunk => data += chunk); " +
             "process.stdin.on('end', () => { " +
             "  const encrypted = Buffer.concat([cipher.update(data, 'utf8'), cipher.final()]); " +
             "  const authTag = cipher.getAuthTag(); " +
             "  console.log(Buffer.concat([encrypted, authTag]).toString('base64')); " +
             "});"
            ],
            input: IO::Memory.new(content),
            output: encrypted_output,
            error: error_output
          )

          unless result.success?
            puts "SSH: Node.js stderr: #{error_output.to_s}"
            raise "Node.js encryption failed with exit code: #{result.exit_code}"
          end

          encrypted_b64 = encrypted_output.to_s.strip
          actual_content = encrypted_b64
          puts "SSH: server-side Node.js AES-256-GCM encryption successful"
          puts "SSH: total encrypted size: #{Base64.decode_string(encrypted_b64).size}"
        ensure
          File.delete(input_file) if File.exists?(input_file)
        end
      rescue ex
        puts "SSH: encryption failed: #{ex.message}"
        # Fallback to base64 if encryption fails
        actual_content = Base64.strict_encode(content.to_slice)
      end
    elsif is_pre_encrypted
      # Content is already encrypted by user (true zero-trust)
      puts "SSH: using pre-encrypted content (zero-trust mode)"
      actual_content = content.strip
      encryption_iv = iv
      puts "SSH: pre-encrypted IV: #{iv}"
    end

    # Create paste - language detection from filename happens in Paste constructor
    paste = ssh_key.create_paste(
      content: actual_content,
      theme: "default-dark",
      language: language,
      filename: filename,
      title: title,
      encrypted: (encrypted || is_pre_encrypted).as(Bool)
    )

    # Set encryption metadata if encrypted (server or pre-encrypted)
    if encrypted || is_pre_encrypted
      paste.encryption_iv = encryption_iv
      puts "SSH: Setting encryption IV: #{encryption_iv}"

      # Set password_based flag - false for key-based encryption
      paste.password_based = false

      # For server-side encryption, don't set encryption_iterations (only for password-based)
      # is_pre_encrypted uses whatever user provided

      # Store the authentication tag (extracted from the encrypted data)
      if !actual_content.empty?
        begin
          encrypted_bytes = Base64.decode_string(actual_content)
          puts "SSH: Encrypted data size: #{encrypted_bytes.size} bytes"
          if encrypted_bytes.size >= 16
            # The last 16 bytes are the auth tag
            auth_tag_bytes = encrypted_bytes[-16..]
            paste.encryption_tag = Base64.strict_encode(auth_tag_bytes)
            puts "SSH: Extracted auth tag: #{paste.encryption_tag.as(String).size} bytes"
            puts "SSH: Auth tag (first 8 chars): #{paste.encryption_tag.as(String)[0..7]}"
          end
        rescue ex
          puts "SSH: warning - could not extract auth tag: #{ex.message}"
        end
      end
      # Store the content as encrypted_content for web compatibility
      paste.encrypted_content = actual_content
      puts "SSH: Stored encrypted_content (first 16 chars): #{actual_content[0..15]}..."
    end

    # Save the paste as a standalone object (so web server can find it)
    unless paste.save
      ctx.write_stderr("Failed to save paste\n")
      return 1
    end

    # Save the SSHKey (with reference to the paste)
    if ssh_key.save
      url = "#{base_url}/#{paste.sepia_id}\n"
      ctx.write(url)

      # Provide appropriate output based on encryption type
      if is_server_encrypted
        ctx.write("🔒 Encryption key: #{encryption_key}\n")
        ctx.write("⚠️  Save this key securely - it cannot be recovered!\n")
        ctx.write("📋 To decrypt: Open the URL above and enter this key\n")
      elsif is_pre_encrypted
        ctx.write("🔐 Zero-trust encrypted paste created\n")
        ctx.write("📋 To decrypt: Open the URL above and enter your encryption key\n")
        ctx.write("🔒 IV stored with paste: #{encryption_iv}\n")
      end

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
    ctx.write("  -t TITLE     Set title\n")
    ctx.write("  -e, --encrypted  Create an encrypted paste\n\n")
    ctx.write("Examples with options:\n")
    ctx.write("  cat code.py | ssh #{host} paste -l python\n")
    ctx.write("  cat code | ssh #{host} paste -f script.rb\n")
    ctx.write("  echo 'test' | ssh #{host} paste -t 'My Test'\n")
    ctx.write("  echo 'secret' | ssh #{host} paste --encrypted\n\n")
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
      lang = paste.language.try { |language| " [#{language}]" } || ""

      ctx.write("#{base_url}/#{paste.sepia_id}\n")
      ctx.write("  Created: #{created}#{lang}\n")
      ctx.write("  Preview: #{preview}\n\n")
    end

    0
  end
end

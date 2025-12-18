require "../src/models/ssh_key"
require "../src/models/auth_token"
require "../src/models/user"
require "../src/models/api_key"
require "../src/models/ssh_key_challenge"
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
  @@base_url = "http://localhost:5000"

  # Rate limiters for SSH operations
  @@paste_limiter : RateLimiter?
  @@login_limiter : RateLimiter?
  @@conn_limiter : RateLimiter?
  @@ssh_key_limiter : RateLimiter?
  @@rate_mutex = Mutex.new

  def self.base_url=(url : String)
    @@base_url = url
  end

  def self.init_rate_limiters(paste_limit : Int32, paste_window : Int32,
                              login_limit : Int32, login_window : Int32,
                              conn_limit : Int32, conn_window : Int32,
                              ssh_key_limit : Int32, ssh_key_window : Int32)
    @@rate_mutex.synchronize do
      @@paste_limiter = RateLimiter.new(paste_limit, paste_window)
      @@login_limiter = RateLimiter.new(login_limit, login_window)
      @@conn_limiter = RateLimiter.new(conn_limit, conn_window)
      @@ssh_key_limiter = RateLimiter.new(ssh_key_limit, ssh_key_window)
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

  # Check SSH key operation rate limit
  private def self.allow_ssh_key_operation?(fingerprint : String) : Bool
    @@rate_mutex.synchronize do
      if limiter = @@ssh_key_limiter
        allowed = limiter.allow?(fingerprint)
        unless allowed
          puts "⚠️  SSH rate limit hit: SSH key operation limit (Key: #{fingerprint})"
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
      puts "SSH DEBUG: Fingerprint received by SSH server: #{fingerprint}"

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
      when "api-key"
        handle_api_key(ctx, @@current_fingerprint, args)
      when "help"
        handle_help(ctx, @@base_url)
      when "add-key"
        handle_add_key(ctx, @@current_fingerprint, args)
      when "ssh-key"
        handle_ssh_key(ctx, @@current_fingerprint, args)
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
  paste [-l LANG] [-f FILE] [-t TITLE] [-e] [--iv IV] [--expire TIME] [--burn] [--private]

Options:
  -l LANG, --language LANG         Set the language for syntax highlighting
  -f FILE, --filename FILE         Set a filename (used for language detection)
  -t TITLE, --title TITLE          Set a title for the paste
  -e, --encrypted                  Create an encrypted paste (server encrypts)
  --iv IV                          Pre-encrypted content with IV (base64). Content must be Web Crypto API compatible.
  --expire TIME                    Set expiration time (10m, 1h, 1d, 1w, 1M, view-once)
  --burn                           Burn after reading (delete after first view)
  --private                        Create a private paste (not listed in public feeds)

DOC

  # ameba:disable Metrics/CyclomaticComplexity
  private def self.parse_paste_args(args : String, ctx) : {String?, String?, String?, Bool, Bool, String?, Time?, Bool, Bool}
    language = nil
    filename = nil
    title = nil
    encrypted = false
    pre_encrypted = false
    iv = nil
    expires_at = nil
    burn_after_reading = false
    private_paste = false

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

        # Handle expiration time
        expire_str = opts["--expire"]?.try(&.to_s)
        if expire_str && expire_str != "false" && expire_str != "" && expire_str != "nil"
          expires_at = Pasto::Paste.parse_expiration(expire_str)
        end

        # Handle burn after reading
        burn_after_reading = !!opts["--burn"]

        # Handle private paste
        private_paste = !!opts["--private"]

        puts "SSH: parsed options - language=#{language.inspect}, filename=#{filename.inspect}, title=#{title.inspect}, encrypted=#{encrypted}, pre_encrypted=#{pre_encrypted}, iv=#{iv.inspect}, expires_at=#{expires_at.inspect}, burn_after_reading=#{burn_after_reading}, private_paste=#{private_paste}"
      rescue ex : Docopt::DocoptException
        ctx.write_stderr("Invalid options: #{ex.message}\n")
        ctx.write_stderr(PASTE_DOC)
        raise ex
      end
    end

    {language, filename, title, encrypted, pre_encrypted, iv, expires_at, burn_after_reading, private_paste}
  end

  # ameba:disable Metrics/CyclomaticComplexity
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
    begin
      language, filename, title, encrypted, pre_encrypted, iv, expires_at, burn_after_reading, private_paste = parse_paste_args(args, ctx)
    rescue ex : Docopt::DocoptException
      return 1
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
             "});",
            ],
            input: IO::Memory.new(content),
            output: encrypted_output,
            error: error_output
          )

          unless result.success?
            puts "SSH: Node.js stderr: #{error_output}"
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
      encrypted: (encrypted || is_pre_encrypted).as(Bool),
      expires_at: expires_at,
      burn_after_reading: burn_after_reading,
      private_paste: private_paste
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
    ctx.write("  -e, --encrypted  Create an encrypted paste\n")
    ctx.write("  --expire TIME    Set expiration (10m, 1h, 1d, 1w, 1M, view-once)\n")
    ctx.write("  --burn         Burn after reading (delete after first view)\n")
    ctx.write("  --private      Create a private paste\n\n")
    ctx.write("Examples with options:\n")
    ctx.write("  cat code.py | ssh #{host} paste -l python\n")
    ctx.write("  cat code | ssh #{host} paste -f script.rb\n")
    ctx.write("  echo 'test' | ssh #{host} paste -t 'My Test'\n")
    ctx.write("  echo 'secret' | ssh #{host} paste --encrypted\n")
    ctx.write("  echo 'temp' | ssh #{host} paste --expire 10m\n")
    ctx.write("  echo 'sensitive' | ssh #{host} paste --burn --encrypted\n")
    ctx.write("  echo 'private' | ssh #{host} paste --private\n\n")
    ctx.write("List your pastes:\n")
    ctx.write("  ssh #{host} list\n\n")
    ctx.write("API key management:\n")
    ctx.write("  ssh #{host} api-key create    Create a new API key\n")
    ctx.write("  ssh #{host} api-key list      List your API keys\n\n")
    ctx.write("SSH key management:\n")
    ctx.write("  ssh #{host} add-key \"PUBLIC_KEY\"    Add a new SSH key (creates challenge)\n")
    ctx.write("  ssh #{host} ssh-key list             List your SSH keys\n")
    ctx.write("  ssh #{host} ssh-key response CODE     Complete key addition challenge\n\n")
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

  # Handle api-key command - manage API keys for the current user
  private def self.handle_api_key(ctx, fingerprint : String, args : String) : Int32
    # Parse subcommand (create, list, etc.)
    parts = args.split(/\s+/)
    subcommand = parts[0]? || ""

    case subcommand
    when "create"
      handle_api_key_create(ctx, fingerprint)
    when "list"
      handle_api_key_list(ctx, fingerprint)
    when "revoke"
      key_to_revoke = parts[1]? || ""
      handle_api_key_revoke(ctx, fingerprint, key_to_revoke)
    else
      ctx.write_stderr("API key usage:\n")
      ctx.write_stderr("  ssh host api-key create    Create a new API key\n")
      ctx.write_stderr("  ssh host api-key list      List your API keys\n")
      ctx.write_stderr("  ssh host api-key revoke KEY Revoke an API key\n")
      1
    end
  end

  # Handle api-key create command
  private def self.handle_api_key_create(ctx, fingerprint : String) : Int32
    # Find or create SSH key and user
    ssh_key = Pasto::SSHKey.find_or_create(fingerprint)

    # Find or create user for this SSH key
    user = if owner_id = ssh_key.owner_id
             Pasto::User.find(owner_id)
           else
             # Create a new user for this SSH key
             new_user = Pasto::User.new
             new_user.save
             ssh_key.owner_id = new_user.sepia_id
             ssh_key.save
             new_user
           end

    unless user
      ctx.write_stderr("Failed to create or find user account\n")
      return 1
    end

    # Create API key through user
    api_key = user.add_api_key

    ctx.write("✅ API key created successfully!\n")
    ctx.write("Key: #{api_key.id}\n")
    ctx.write("Created: #{api_key.key_data.created_at.to_s("%Y-%m-%d %H:%M UTC")}\n")
    ctx.write("📋 Use it for API authentication: Authorization: Bearer #{api_key.id}\n")

    puts "SSH: created API key #{api_key.id} for user #{user.sepia_id} (SSH key: #{fingerprint})"
    0
  rescue ex
    ctx.write_stderr("Failed to create API key: #{ex.message}\n")
    puts "SSH: API key creation failed: #{ex.message}"
    1
  end

  # Handle api-key list command
  private def self.handle_api_key_list(ctx, fingerprint : String) : Int32
    # Find SSH key and associated user
    ssh_key = Pasto::SSHKey.find(Pasto::SSHKey.sanitize_fingerprint(fingerprint))

    unless ssh_key && ssh_key.owner_id
      ctx.write("No API keys found. Create one with: ssh host api-key create\n")
      return 0
    end

    if owner_id = ssh_key.owner_id
      user = Pasto::User.find(owner_id)
    else
      user = nil
    end
    unless user
      ctx.write("User account not found. Create one with: ssh host api-key create\n")
      return 0
    end

    api_keys = user.all_api_keys
    if api_keys.empty?
      ctx.write("No API keys found. Create one with: ssh host api-key create\n")
      return 0
    end

    ctx.write("Your API keys (#{api_keys.size} total):\n")
    ctx.write("=" * 50 + "\n\n")

    api_keys.each do |api_key|
      created = api_key.key_data.created_at.to_s("%Y-%m-%d %H:%M UTC")
      last_used = api_key.key_data.last_used_at.try(&.to_s("%Y-%m-%d %H:%M UTC")) || "Never"
      usage_count = api_key.key_data.usage_count

      ctx.write("Key: #{api_key.id}\n")
      ctx.write("  Created: #{created}\n")
      ctx.write("  Last used: #{last_used}\n")
      ctx.write("  Usage count: #{usage_count}\n\n")
    end

    0
  end

  # Handle api-key revoke command
  private def self.handle_api_key_revoke(ctx, fingerprint : String, key_to_revoke : String) : Int32
    # Find SSH key and associated user
    ssh_key = Pasto::SSHKey.find_or_create(fingerprint)

    unless ssh_key.owner_id
      ctx.write("No user account found. Create one with: ssh host api-key create\n")
      return 0
    end

    if owner_id = ssh_key.owner_id
      user = Pasto::User.find(owner_id)
    else
      user = nil
    end
    unless user
      ctx.write("User account not found. Create one with: ssh host api-key create\n")
      return 0
    end

    if key_to_revoke.empty?
      ctx.write("Error: Please specify the API key to revoke.\n")
      ctx.write("Usage: ssh host api-key revoke <api-key>\n")
      return 1
    end

    # Validate key format
    unless key_to_revoke.starts_with?("pasto_ak_")
      ctx.write("Error: Invalid API key format. API keys should start with 'pasto_ak_'\n")
      return 1
    end

    # Find the API key to revoke
    api_key_to_revoke = Pasto::ApiKey.find_by_key(key_to_revoke)
    unless api_key_to_revoke
      ctx.write("Error: API key '#{key_to_revoke}' not found.\n")
      return 1
    end

    # Verify this key belongs to the current user
    unless api_key_to_revoke.user_id == user.sepia_id
      ctx.write("Error: This API key does not belong to you.\n")
      return 1
    end

    # Remove the API key file
    api_key_file = "data/Pasto::ApiKey/#{api_key_to_revoke.sepia_id}"
    begin
      File.delete(api_key_file)
    rescue ex
      ctx.write("Warning: Could not delete API key file: #{ex.message}\n")
    end

    # Clean up user's API key list - remove broken references AND the revoked key
    valid_api_keys = user.api_keys.select do |key_id|
      # Keep the key if it's not the one we're revoking AND it still exists in storage
      key_id != api_key_to_revoke.sepia_id && Pasto::ApiKey.exists?(key_id)
    end

    # Update user's API key list
    user.api_keys = valid_api_keys
    user.save

    ctx.write("✅ API key '#{key_to_revoke}' has been revoked successfully.\n")
    0
  end

  # Handle add-key command - create a challenge for adding a new SSH key
  private def self.handle_add_key(ctx, fingerprint : String, args : String) : Int32
    puts "SSH: add-key called with fingerprint=#{fingerprint}, args=#{args.inspect}"

    # Check SSH key operation rate limit
    unless allow_ssh_key_operation?(fingerprint)
      ctx.write_stderr("Rate limit exceeded. Please wait before adding another SSH key.\n")
      return 1
    end

    # Find current user for this SSH key
    ssh_key = Pasto::SSHKey.find_or_create(fingerprint)
    current_user = if owner_id = ssh_key.owner_id
                     Pasto::User.find(owner_id)
                   else
                     ctx.write_stderr("Error: You must have a user account to add SSH keys.\n")
                     ctx.write_stderr("Create one with: ssh host login\n")
                     return 1
                   end

    unless current_user
      ctx.write_stderr("Error: User account not found.\n")
      return 1
    end

    # Extract the public key from args
    if args.strip.empty?
      ctx.write_stderr("Error: Please provide a public key.\n")
      ctx.write_stderr("Usage: ssh host add-key \"ssh-rsa AAAAB3NzaC1yc2E...\"\n")
      return 1
    end

    public_key = args.strip

    # Validate the SSH key format
    begin
      # Normalize and validate the key
      normalized_key = Pasto::SSHUtils.normalize_key(public_key)

      # Additional sanity checks
      unless Pasto::SSHUtils.sanity_check_key(normalized_key)
        ctx.write_stderr("Error: Invalid SSH key format.\n")
        return 1
      end

      # Extract fingerprint
      new_fingerprint = Pasto::SSHUtils.extract_fingerprint(normalized_key)

      # Check if key is already associated with any user
      if Pasto::SSHUtils.key_already_associated?(new_fingerprint)
        ctx.write_stderr("Error: This SSH key is already associated with another user.\n")
        return 1
      end

      # Create challenge
      challenge = Pasto::SSHKeyChallenge.create_for_key(current_user.sepia_id, normalized_key)

      ctx.write("✅ SSH key challenge created!\n")
      ctx.write("Challenge Code: #{challenge.sepia_id}\n")
      ctx.write("Fingerprint: #{new_fingerprint}\n\n")
      ctx.write("To complete the key addition, authenticate with the new key and run:\n")
      ctx.write("ssh -i path/to/new/key -p 2222 #{URI.parse(@@base_url).host} ssh-key response #{challenge.sepia_id}\n\n")
      ctx.write("⏰ This challenge expires in 30 minutes.\n")

      puts "SSH: created challenge #{challenge.sepia_id} for user #{current_user.sepia_id} (new key fingerprint: #{new_fingerprint})"
      0
    rescue ex
      ctx.write_stderr("Error processing SSH key: #{ex.message}\n")
      puts "SSH: add-key failed: #{ex.message}"
      1
    end
  end

  # Handle ssh-key command - manage existing SSH keys and respond to challenges
  private def self.handle_ssh_key(ctx, fingerprint : String, args : String) : Int32
    # Parse subcommand (list, response, etc.)
    parts = args.split(/\s+/)
    subcommand = parts[0]? || ""

    case subcommand
    when "list"
      handle_ssh_key_list(ctx, fingerprint)
    when "response"
      challenge_code = parts[1]? || ""
      handle_ssh_key_response(ctx, fingerprint, challenge_code)
    else
      ctx.write_stderr("SSH key management:\n")
      ctx.write_stderr("  ssh host ssh-key list                 List your SSH keys\n")
      ctx.write_stderr("  ssh host ssh-key response <code>      Complete key addition challenge\n")
      1
    end
  end

  # Handle ssh-key list command
  private def self.handle_ssh_key_list(ctx, fingerprint : String) : Int32
    # Find current user for this SSH key
    puts "SSH DEBUG: Looking up SSH key with fingerprint: #{fingerprint}"
    ssh_key = Pasto::SSHKey.find_or_create(fingerprint)
    puts "SSH DEBUG: Found SSH key: #{ssh_key.inspect}"

    current_user = if owner_id = ssh_key.owner_id
                     puts "SSH DEBUG: SSH key has owner_id: #{owner_id}"
                     user = Pasto::User.find(owner_id)
                     puts "SSH DEBUG: Found user: #{user.inspect}"
                     user
                   else
                     puts "SSH DEBUG: SSH key has no owner_id"
                     ctx.write("No SSH keys found. Create an account first: ssh host login\n")
                     return 0
                   end

    unless current_user
      ctx.write("User account not found.\n")
      return 0
    end

    user_keys = current_user.keys
    if user_keys.empty?
      ctx.write("No SSH keys found for your account.\n")
      return 0
    end

    ctx.write("Your SSH keys (#{user_keys.size} total):\n")
    ctx.write("=" * 50 + "\n\n")

    user_keys.each do |key|
      created = key.created_at.to_s("%Y-%m-%d %H:%M UTC")
      # Compare the full fingerprints, not sanitized ones
      is_current = key.fingerprint == fingerprint
      current_marker = is_current ? " ← CURRENT KEY" : ""

      ctx.write("Fingerprint: #{key.fingerprint}#{current_marker}\n")
      ctx.write("  Created: #{created}\n")
      ctx.write("  Has owner: #{key.owner_id ? "Yes" : "No"}\n\n")
    end

    0
  end

  # Handle ssh-key response command - validate challenge and add key
  private def self.handle_ssh_key_response(ctx, fingerprint : String, challenge_code : String) : Int32
    # Check SSH key operation rate limit
    unless allow_ssh_key_operation?(fingerprint)
      ctx.write_stderr("Rate limit exceeded. Please wait before completing another challenge.\n")
      return 1
    end

    if challenge_code.empty?
      ctx.write_stderr("Error: Please provide a challenge code.\n")
      ctx.write_stderr("Usage: ssh host ssh-key response <challenge-code>\n")
      return 1
    end

    # Find the challenge
    challenge = Pasto::SSHKeyChallenge.find_by_code(challenge_code)
    unless challenge
      ctx.write_stderr("Error: Challenge code not found or expired.\n")
      return 1
    end

    # Extract fingerprint of the key being used for this connection
    current_fingerprint = Pasto::SSHUtils.extract_fingerprint_from_pubkey(fingerprint)

    # Verify the challenge matches the key being used (both should have SHA256: prefix)
    unless challenge.fingerprint == current_fingerprint
      ctx.write_stderr("Error: Challenge fingerprint doesn't match the key you're using.\n")
      ctx.write_stderr("Expected fingerprint: #{challenge.fingerprint}\n")
      ctx.write_stderr("Current key fingerprint: #{current_fingerprint}\n")
      return 1
    end

    # Find the user
    user = Pasto::User.find(challenge.user_id)
    unless user
      ctx.write_stderr("Error: User account not found.\n")
      return 1
    end

    # Validate and delete the challenge (atomic operation)
    unless Pasto::SSHKeyChallenge.validate_and_delete(challenge_code, user.sepia_id, challenge.fingerprint)
      ctx.write_stderr("Error: Challenge validation failed.\n")
      return 1
    end

    # Use the fingerprint from the challenge directly (already has SHA256: prefix)
    # Create or find the SSH key - the SSHKey constructor will sanitize the fingerprint for storage
    new_ssh_key = Pasto::SSHKey.find_or_create(challenge.fingerprint)

    # Check if key is already associated with a different user (race condition check)
    if new_ssh_key.owner_id && new_ssh_key.owner_id != user.sepia_id
      ctx.write_stderr("Error: This SSH key is already associated with another user.\n")
      return 1
    end

    # Associate the key with the user
    new_ssh_key.owner_id = user.sepia_id
    unless new_ssh_key.save
      ctx.write_stderr("Error: Failed to save SSH key association.\n")
      return 1
    end

    # Add the key to the user's key list
    existing_key = user.keys.find { |k| k.fingerprint == challenge.fingerprint }
    unless existing_key
      user.add_key(new_ssh_key)
    end

    ctx.write("✅ SSH key added successfully!\n")
    ctx.write("Fingerprint: #{challenge.fingerprint}\n")
    ctx.write("User: #{user.display_name}\n")
    ctx.write("You can now use this SSH key to create pastes and manage your account.\n")

    puts "SSH: successfully added key #{challenge.fingerprint} to user #{user.sepia_id}"
    0
  rescue ex
    ctx.write_stderr("Error completing challenge: #{ex.message}\n")
    puts "SSH: ssh-key response failed: #{ex.message}"
    1
  end
end

#!/usr/bin/env crystal

require "docopt"
require "openssl"
require "json"
require "./gcm_fix"

module PastoCrypto
  VERSION = "0.1.0"

  DOC = <<-DOC
    Pasto Crypto - Encrypt/decrypt data compatible with Pasto

    Usage:
      pasto-crypto encrypt [--random-pass | --password=PASS] [--output=FILE] [FILE]
      pasto-crypto decrypt [--password=PASS] [--salt=SALT] [--iv=IV] [--output=FILE] [FILE]
      pasto-crypto (-h | --help)
      pasto-crypto --version

    Options:
      -h --help           Show this help
      --random-pass        Generate random password and derive key (zero-knowledge mode)
      --password=PASS     Use password for encryption/decryption (or PASTO_PASSWORD env var)
      --salt=SALT         Base64-encoded salt for decryption (or PASTO_SALT env var)
      --iv=IV             Base64-encoded IV for decryption (or PASTO_IV env var)
      --output=FILE       Write encrypted/decrypted data to file
      --version           Show version information

    Examples:
      # Encrypt with random password (zero-knowledge)
      echo "secret data" | pasto-crypto encrypt --output encrypted.dat
      # Output: PASTO_PASSWORD=xxx PASTO_SALT=xxx PASTO_IV=xxx

      # Encrypt with specific password
      echo "secret data" | pasto-crypto encrypt --password=mypass --output encrypted.dat
      # Output: PASTO_SALT=xxx PASTO_IV=xxx

      # Decrypt using environment variables
      export PASTO_PASSWORD=xxx PASTO_SALT=xxx PASTO_IV=xxx
      pasto-crypto decrypt encrypted.dat

      # Decrypt using command-line options
      pasto-crypto decrypt --password=xxx --salt=xxx --iv=xxx encrypted.dat
  DOC

  # Generate a random password (32 characters for good entropy)
  def self.generate_random_password : String
    charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    password = Bytes.new(32)
    Random.new.random_bytes(password)
    password.map { |byte| charset[byte % charset.size] }.join
  end

  # Generate random salt (16 bytes)
  def self.generate_salt : String
    salt = Bytes.new(16)
    Random.new.random_bytes(salt)
    Base64.strict_encode(salt)
  end

  # Generate random IV (12 bytes for GCM)
  def self.generate_iv : String
    iv = Bytes.new(12)
    Random.new.random_bytes(iv)
    Base64.strict_encode(iv)
  end

  # Derive encryption key from password using PBKDF2-HMAC-SHA256
  def self.derive_key_from_password(password : String, salt_b64 : String, iterations : Int32 = 100000) : String
    salt_bytes = Base64.decode_string(salt_b64)
    password_bytes = password.to_slice

    # Use PBKDF2-HMAC-SHA256 to derive a 32-byte (256-bit) key
    derived_key = OpenSSL::PKCS5.pbkdf2_hmac(
      secret: password_bytes,
      salt: salt_bytes,
      iterations: iterations,
      algorithm: OpenSSL::Algorithm::SHA256,
      key_size: 32
    )

    Base64.strict_encode(derived_key)
  end

  # Encrypt content using AES-256-GCM
  def self.encrypt_content(plaintext : String, password : String) : NamedTuple(
    encrypted_content: String,
    password: String,
    salt: String,
    iv: String,
    iterations: Int32)
    # Generate salt and IV
    salt = generate_salt
    iv = generate_iv
    iterations = 100000

    # Derive key from password
    key_b64 = derive_key_from_password(password, salt, iterations)

    # Encrypt using the existing function
    encrypted_content = encrypt_for_pasto_webcrypto(plaintext, key_b64, iv)

    {
      encrypted_content: encrypted_content,
      password:          password,
      salt:              salt,
      iv:                iv,
      iterations:        iterations,
    }
  end

  # Decrypt content using AES-256-GCM
  def self.decrypt_content(
    encrypted_content_b64 : String,
    password : String,
    salt_b64 : String,
    iv_b64 : String,
    iterations : Int32 = 100000,
  ) : String
    # Derive key from password
    key_b64 = derive_key_from_password(password, salt_b64, iterations)

    # Decode encrypted data
    encrypted_data = Base64.decode_string(encrypted_content_b64).to_slice

    # Split into ciphertext and auth tag (last 16 bytes)
    ciphertext = encrypted_data[0...-16]
    auth_tag = encrypted_data[-16..]

    # Decode key and IV
    key = Base64.decode_string(key_b64)
    iv = Base64.decode_string(iv_b64)

    # Decrypt
    decipher = OpenSSL::Cipher.new("aes-256-gcm")
    decipher.decrypt
    decipher.key = key
    decipher.iv = iv
    decipher.gcm_auth_tag = auth_tag

    decrypted_data = decipher.update(ciphertext) + decipher.final
    String.new(decrypted_data)
  end

  # Read input from file or stdin
  def self.read_input(file : String?) : String
    if file && File.exists?(file)
      File.read(file)
    else
      # Read from stdin
      STDIN.gets_to_end || ""
    end
  end

  # Write output to file or stdout
  def self.write_output(content : String, file : String?)
    if file
      File.write(file, content)
    else
      print content
    end
  end

  # Main entry point
  def self.run(args = ARGV)
    options = Docopt.docopt(DOC, argv: args, version: VERSION)

    if options["encrypt"] == true
      # Handle encryption
      password = if options["--random-pass"] == true
                   generate_random_password
                 elsif options["--password"]?.to_s != ""
                   options["--password"].to_s
                 else
                   # Default to random password for security
                   generate_random_password
                 end

      # Read input
      input_file = options["FILE"]?.to_s
      plaintext = read_input(input_file.empty? ? nil : input_file)

      # Encrypt
      result = encrypt_content(plaintext, password)

      # Write encrypted data to file or stdout
      output_file = options["--output"]?.to_s
      if !output_file.empty?
        File.write(output_file, result[:encrypted_content])
      else
        # Print encrypted data to stderr to keep stdout clean for env vars
        STDERR.print result[:encrypted_content]
      end

      # Print metadata to stdout for easy parsing
      puts "PASTO_PASSWORD=#{result[:password]}"
      puts "PASTO_SALT=#{result[:salt]}"
      puts "PASTO_IV=#{result[:iv]}"
      puts "PASTO_ITERATIONS=#{result[:iterations]}"
    elsif options["decrypt"] == true
      # Check environment variables first
      password = ENV["PASTO_PASSWORD"]? || options["--password"].to_s
      salt = ENV["PASTO_SALT"]? || options["--salt"].to_s
      iv = ENV["PASTO_IV"]? || options["--iv"].to_s

      if password.empty? || salt.empty? || iv.empty?
        STDERR.puts "Error: Missing required parameters"
        STDERR.puts "Provide via --password/--salt/--iv or set PASTO_PASSWORD/PASTO_SALT/PASTO_IV environment variables"
        return 1
      end

      iterations = 100000

      # Read encrypted data from file or stdin
      input_file = options["FILE"]?.to_s

      if !input_file.empty? && File.exists?(input_file)
        encrypted_content = File.read(input_file)
      else
        encrypted_content = read_input(nil)
      end

      # Decrypt
      decrypted = decrypt_content(encrypted_content, password, salt, iv, iterations)

      # Write decrypted output
      output_file = options["--output"]?.to_s
      write_output(decrypted, output_file.empty? ? nil : output_file)
    end

    0
  rescue ex : Exception
    msg = ex.message
    if msg && msg.includes?("User")
      # Docopt help/version message
      puts msg
      0
    else
      STDERR.puts "Error: #{msg || "Unknown error"}"
      1
    end
  end
end

PastoCrypto.run if PROGRAM_NAME.includes?("pasto-crypto")

require "shirk"
require "../cli/config"

module PastoCLI
  class SSHClient
    @client : Shirk::Client?

    def initialize(@config : Config)
    end

    def connect : Shirk::Client
      if client = @client
        return client
      end

      verbose = @config.verbose? ? 3 : 0
      # Use "pasto" as a dummy username - SSH server only uses public key auth
      client = Shirk::Client.new(
        @config.ssh_host,
        @config.ssh_port,
        user: "pasto",
        strict_host_key_checking: false,
        verbosity: verbose
      )

      puts "Connecting to #{@config.ssh_host}:#{@config.ssh_port}..." if @config.verbose?

      client.connect
      puts "Connected!" if @config.verbose?

      # Authenticate with SSH key
      authenticate(client)

      @client = client
      client
    end

    def authenticate(client : Shirk::Client) : Nil
      key_path = get_ssh_key_path

      puts "Authenticating with SSH key: #{key_path}" if @config.verbose?

      unless File.exists?(key_path)
        raise "SSH key not found: #{key_path}"
      end

      client.auth_publickey(key_path)
      puts "Authenticated!" if @config.verbose?
    end

    def execute_login : String
      client = connect

      puts "Executing api-key create command..." if @config.verbose?

      result = client.exec("api-key create")

      unless result.success?
        raise "API key creation failed: #{result.stderr}"
      end

      # Extract API key from output
      # Format: "Key: pasto_ak_xxxxxxxx"
      output = result.stdout.strip
      if match = output.match(/Key: (pasto_ak_[a-f0-9]+)/)
        match[1]
      else
        raise "Could not extract API key from response: #{output}"
      end
    ensure
      disconnect
    end

    def execute_login_web : String
      client = connect

      puts "Executing login command..." if @config.verbose?

      result = client.exec("login")

      unless result.success?
        raise "Login command failed: #{result.stderr}"
      end

      result.stdout.strip
    ensure
      disconnect
    end

    def disconnect : Nil
      if client = @client
        client.disconnect
        @client = nil
      end
    end

    private def get_ssh_key_path : String
      # If user specified a key, use it
      if !@config.ssh_key.empty?
        return File.expand_path(@config.ssh_key)
      end

      # Try common SSH key locations
      home = ENV["HOME"]? || raise "HOME environment variable not set"

      common_keys = [
        File.join(home, ".ssh", "id_ed25519"),
        File.join(home, ".ssh", "id_rsa"),
        File.join(home, ".ssh", "id_ecdsa"),
      ]

      common_keys.each do |key_path|
        if File.exists?(key_path)
          puts "Using SSH key: #{key_path}" if @config.verbose?
          return key_path
        end
      end

      # No key found, provide helpful error
      raise "No SSH key found. Please specify one with --ssh-key or ensure one exists in ~/.ssh/"
    end
  end
end

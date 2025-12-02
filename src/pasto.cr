require "docopt-config"
require "sepia"
require "kemal"
require "./paste"
require "./server"
require "./models/user"
require "kemal-session"

module Pasto
  VERSION = "0.1.0"

  @@config : Config?

  def self.config
    @@config
  end

  def self.config=(config : Config)
    @@config = config
  end

  DOC = <<-DOC
Pasto - Crystal Pastebin Web App

Usage:
  pasto [options]
  pasto -h | --help
  pasto --version

Options:
  -h --help                 Show this screen.
  --version                 Show version.
  --port=<port>             Port to listen on [default: 3000].
  --bind=<address>          Address to bind to [default: 0.0.0.0].
  --storage-dir=<dir>       Directory to store pastes [default: ./data].
  --cache-dir=<dir>         Directory for cached files [default: ./public/cache].
  --env=<environment>       Environment (development or production) [default: development].
  --theme=<theme>           Syntax highlighting theme [default: default-dark].
  --max-paste-size=<size>   Maximum paste size in bytes [default: 102400].
  --base-url=<url>          Base URL for web interface [default: http://bind:port].
  --ssh-enabled=<bool>      Enable SSH server [default: false].
  --ssh-port=<port>         SSH port to listen on [default: 2222].
  --ssh-bind=<address>      SSH address to bind to [default: 0.0.0.0].
  --host-key=<file>         SSH host key file [default: ssh_host_rsa_key].

DOC

  class Config
    property port : Int32
    property bind : String
    property storage_dir : String
    property cache_dir : String
    property environment : String
    property theme : String
    property max_paste_size : Int32
    property base_url : String
    property ssh_enabled : Bool
    property ssh_port : Int32
    property ssh_bind : String
    property host_key : String

    def initialize(args)
      docopt_options = Docopt.docopt_config(
        DOC,
        argv: args,
        config_file_path: "pasto.yml",
        env_prefix: "PASTO",
        version: VERSION
      )

      @port = docopt_options["--port"].to_s.to_i
      @bind = docopt_options["--bind"].to_s
      @storage_dir = docopt_options["--storage-dir"].to_s
      @cache_dir = docopt_options["--cache-dir"].to_s
      @environment = docopt_options["--env"].to_s
      @theme = docopt_options["--theme"].to_s
      @max_paste_size = docopt_options["--max-paste-size"].to_s.to_i
      @ssh_enabled = docopt_options["--ssh-enabled"].to_s.downcase.in?("true", "yes", "1")
      @ssh_port = docopt_options["--ssh-port"].to_s.to_i
      @ssh_bind = docopt_options["--ssh-bind"].to_s
      @host_key = docopt_options["--host-key"].to_s

      # Handle base_url - use provided value or construct default
      base_url_option = docopt_options["--base-url"].to_s
      if base_url_option.empty? || base_url_option == "http://bind:port"
        @base_url = "http://#{@bind}:#{@port}"
      else
        @base_url = base_url_option.rstrip("/")
      end
    end

    def add_kemal_config
      Kemal.config.port = port
      Kemal.config.host_binding = bind

      # Different settings for development vs production
      if environment == "production"
        Kemal.config.env = "production"
        Kemal.config.logging = false
      else
        Kemal.config.env = "development"
        Kemal.config.logging = true
      end
    end
  end

  # SSH server process management
  @@ssh_process : Process?

  def self.start_ssh_server(config : Config)
    return unless config.ssh_enabled

    # Find the pasto-ssh binary
    ssh_binary = find_ssh_binary
    unless ssh_binary
      puts "⚠️  SSH server enabled but pasto-ssh binary not found. Skipping SSH server."
      return
    end

    # Generate host keys if they don't exist
    generate_host_keys(config.host_key) unless File.exists?(config.host_key)

    spawn do
      loop do
        puts "🔐 Starting SSH server on #{config.ssh_bind}:#{config.ssh_port}"

        # Build command arguments
        args = [
          "--ssh-port=#{config.ssh_port}",
          "--ssh-bind=#{config.ssh_bind}",
          "--storage-dir=#{config.storage_dir}",
          "--host-key=#{config.host_key}",
          "--base-url=#{config.base_url}",
        ]

        # Start the SSH server process
        process = Process.new(
          ssh_binary,
          args,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )
        @@ssh_process = process

        # Wait for the process to exit
        status = process.wait
        @@ssh_process = nil

        if status.success?
          puts "✅ SSH server stopped normally."
          break
        else
          puts "⚠️  SSH server exited with code #{status.exit_code}. Restarting in 5 seconds..."
          sleep 5.seconds
        end
      end
    end
  end

  def self.stop_ssh_server
    if process = @@ssh_process
      puts "🛑 Stopping SSH server..."
      process.signal(:term)
    end
  end

  private def self.find_ssh_binary : String?
    # Check common locations
    candidates = [
      File.join(File.dirname(Process.executable_path || ""), "pasto-ssh"),
      "./bin/pasto-ssh",
      "pasto-ssh",
    ]

    candidates.each do |path|
      return path if File.exists?(path) && File.info(path).permissions.owner_execute?
    end

    # Try to find in PATH
    result = Process.run("which", ["pasto-ssh"], output: Process::Redirect::Pipe)
    if result.success?
      return "pasto-ssh"
    end

    nil
  end

  private def self.generate_host_keys(host_key_file : String)
    puts "🔐 Generating SSH host keys at #{host_key_file}..."
    system("ssh-keygen -t rsa -f #{host_key_file} -N '' -q")

    if File.exists?(host_key_file)
      puts "✅ SSH host keys generated successfully."
    else
      puts "❌ Failed to generate SSH host keys."
    end
  end

  private def self.get_or_create_session_secret(config_file : String = "pasto.yml") : String
    # Check environment variable first
    if secret = ENV["PASTO_SESSION_SECRET"]?
      return secret
    end

    # Try to read from config file
    if File.exists?(config_file)
      content = File.read(config_file)
      if match = content.match(/^session_secret:\s*["']?([^"'\n]+)["']?\s*$/m)
        secret = match[1].strip
        return secret unless secret.empty?
      end
    end

    # Generate new secret and append to config file
    secret = Random::Secure.hex(64)
    
    if File.exists?(config_file)
      File.open(config_file, "a") do |f|
        f.puts ""
        f.puts "# Session secret (auto-generated, do not share)"
        f.puts "session_secret: \"#{secret}\""
      end
      puts "🔑 Generated new session secret (saved to #{config_file})"
    else
      puts "🔑 Generated new session secret (config file not found, using in-memory)"
    end
    
    secret
  end

  def self.run(args)
    # Parse config first before Kemal interferes with ARGV
    config = Config.new(args)
    @@config = config

    # Clear ARGV to prevent Kemal from interfering
    ARGV.clear

    # Ensure directories exist
    Dir.mkdir_p(config.storage_dir)
    Dir.mkdir_p(config.cache_dir)

    # Initialize Sepia storage
    Sepia::Storage.configure(:filesystem, {"path" => config.storage_dir})

    # Get or generate session secret (persisted to config file for consistency across restarts)
    session_secret = get_or_create_session_secret()

    # Configure kemal-session
    Kemal::Session.config do |sess_config|
      sess_config.cookie_name = "pasto_session"
      sess_config.secret = session_secret
      sess_config.timeout = 24.hours
      sess_config.engine = Kemal::Session::FileEngine.new({
        :sessions_dir => "./sessions/"
      })
      sess_config.gc_interval = 30.minutes
    end

    # Initialize cache
    init_cache(config.cache_dir)

    # Configure Kemal
    config.add_kemal_config

    # Start SSH server if enabled
    start_ssh_server(config)

    # Handle graceful shutdown
    Signal::INT.trap do
      puts "\n🛑 Shutting down..."
      stop_ssh_server
      Kemal.stop
      exit
    end

    Signal::TERM.trap do
      puts "\n🛑 Shutting down..."
      stop_ssh_server
      Kemal.stop
      exit
    end

    # Start the web server
    puts "🌐 Starting Pasto on #{config.bind}:#{config.port}"
    puts "📁 Storage: #{config.storage_dir}"
    puts "🎨 Theme: #{config.theme}"
    if config.ssh_enabled
      puts "🔐 SSH: #{config.ssh_bind}:#{config.ssh_port}"
    end
    Kemal.run
  end

  # Initialize the cache system
  private def self.init_cache(cache_dir : String)
    Cache.cache_dir = cache_dir
  end
end

Pasto.run(ARGV)
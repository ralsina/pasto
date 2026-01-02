require "docopt-config"
require "sepia"
require "kemal"
require "./paste"
require "./logging"
require "./preview_generator"
require "./server"
require "./api"
require "./path_helper"
require "./routes/create_routes"
require "./routes/paste_routes"
require "./routes/profile_routes"
require "./routes/utility_routes"
require "./theme_helper"
require "./rate_limit_helper"
require "pasto-cache"
require "./models/user"
require "kemal-session"

module Pasto
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}

  @@config : Config?

  def self.config : Config
    if config = @@config
      return config
    end
    raise "Pasto config not initialized"
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
  --log-level=<level>       Log level (debug, info, warn, error, fatal) [default: info in production, debug in development].
  --theme=<theme>           Syntax highlighting theme [default: default-dark].
  --max-paste-size=<size>   Maximum paste size in bytes [default: 102400].
  --base-url=<url>          Base URL for web interface [default: http://bind:port].
  --base-path=<path>        Base path for URL routing (e.g., /pasto) [default: /].
  --auth-debug-mode         Enable authentication debug mode - auto-authenticate all requests (DO NOT USE IN PRODUCTION).
  --ssh-enabled=<bool>      Enable SSH server [default: false].
  --ssh-port=<port>         SSH port to listen on [default: 2222].
  --ssh-bind=<address>      SSH address to bind to [default: ::].
  --host-key=<file>         SSH host key file [default: ssh_host_rsa_key].
  --disable-rate-limit      DISABLE ALL RATE LIMITING - ONLY FOR TESTING (DO NOT USE IN PRODUCTION).
  --instances=<n>           Number of worker instances to run [default: 1].

Rate Limiting Options:
  --rate-paste-limit=<n>              Paste creation limit per IP [default: 10].
  --rate-paste-window=<s>             Paste rate limit window in seconds [default: 60].
  --rate-paste-user-limit=<n>         Paste creation limit per user [default: 30].
  --rate-paste-user-window=<s>        User paste rate limit window in seconds [default: 60].
  --rate-paste-global-limit=<n>       Global paste creation limit [default: 100].
  --rate-paste-global-window=<s>      Global paste rate limit window in seconds [default: 60].
  --rate-highlight-limit=<n>          Highlight API limit per IP [default: 300].
  --rate-highlight-window=<s>         Highlight rate limit window in seconds [default: 60].
  --rate-login-limit=<n>              Login attempt limit per IP [default: 5].
  --rate-login-window=<s>             Login rate limit window in seconds [default: 300].
  --rate-http-limit=<n>               HTTP request limit per IP [default: 200].
  --rate-http-window=<s>              HTTP rate limit window in seconds [default: 60].
  --rate-backup-limit=<n>             Backup creation limit per user [default: 1].
  --rate-backup-window=<s>            Backup rate limit window in seconds [default: 86400].

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
    property base_path : String
    property? auth_debug_mode : Bool
    property? ssh_enabled : Bool
    property ssh_port : Int32
    property ssh_bind : String
    property host_key : String
    property? disable_rate_limit : Bool
    property instances : Int32

    # Rate limiting settings
    property rate_paste_limit : Int32
    property rate_paste_window : Int32
    property rate_paste_user_limit : Int32
    property rate_paste_user_window : Int32
    property rate_paste_global_limit : Int32
    property rate_paste_global_window : Int32
    property rate_highlight_limit : Int32
    property rate_highlight_window : Int32
    property rate_login_limit : Int32
    property rate_login_window : Int32
    property rate_http_limit : Int32
    property rate_http_window : Int32
    property rate_backup_limit : Int32
    property rate_backup_window : Int32
    property log_level : String?

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
      log_level_option = docopt_options["--log-level"].to_s
      @log_level = log_level_option.empty? ? nil : log_level_option
      @theme = docopt_options["--theme"].to_s
      @max_paste_size = docopt_options["--max-paste-size"].to_s.to_i
      @auth_debug_mode = docopt_options["--auth-debug-mode"]?.to_s.downcase.in?("true", "yes", "1")
      @ssh_enabled = docopt_options["--ssh-enabled"].to_s.downcase.in?("true", "yes", "1")
      @ssh_port = docopt_options["--ssh-port"].to_s.to_i
      @ssh_bind = docopt_options["--ssh-bind"].to_s
      @host_key = docopt_options["--host-key"].to_s
      @disable_rate_limit = docopt_options["--disable-rate-limit"]?.to_s.downcase.in?("true", "yes", "1")
      @instances = docopt_options["--instances"].to_s.to_i

      # Rate limiting settings
      @rate_paste_limit = docopt_options["--rate-paste-limit"].to_s.to_i
      @rate_paste_window = docopt_options["--rate-paste-window"].to_s.to_i
      @rate_paste_user_limit = docopt_options["--rate-paste-user-limit"].to_s.to_i
      @rate_paste_user_window = docopt_options["--rate-paste-user-window"].to_s.to_i
      @rate_paste_global_limit = docopt_options["--rate-paste-global-limit"].to_s.to_i
      @rate_paste_global_window = docopt_options["--rate-paste-global-window"].to_s.to_i
      @rate_highlight_limit = docopt_options["--rate-highlight-limit"].to_s.to_i
      @rate_highlight_window = docopt_options["--rate-highlight-window"].to_s.to_i
      @rate_login_limit = docopt_options["--rate-login-limit"].to_s.to_i
      @rate_login_window = docopt_options["--rate-login-window"].to_s.to_i
      @rate_http_limit = docopt_options["--rate-http-limit"].to_s.to_i
      @rate_http_window = docopt_options["--rate-http-window"].to_s.to_i
      @rate_backup_limit = docopt_options["--rate-backup-limit"].to_s.to_i
      @rate_backup_window = docopt_options["--rate-backup-window"].to_s.to_i

      # Handle base_url - use provided value or construct default
      base_url_option = docopt_options["--base-url"].to_s
      if base_url_option.empty? || base_url_option == "http://bind:port"
        @base_url = "http://#{@bind}:#{@port}"
      else
        @base_url = base_url_option.rstrip("/")
      end

      # Handle base_path - ensure it starts with / and doesn't end with /
      base_path_option = docopt_options["--base-path"].to_s
      @base_path = PathHelper.normalize_base_path(base_path_option)
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

  # Worker process management
  @@worker_processes = [] of Process

  # ameba:disable Metrics/CyclomaticComplexity
  def self.start_ssh_server(config : Config)
    return unless config.ssh_enabled?

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
        # Include base_path in base_url for SSH server
        ssh_base_url = config.base_url + (config.base_path == "/" ? "" : config.base_path)
        args = [
          "--ssh-port=#{config.ssh_port}",
          "--ssh-bind=#{config.ssh_bind}",
          "--storage-dir=#{config.storage_dir}",
          "--host-key=#{config.host_key}",
          "--base-url=#{ssh_base_url}",
        ]

        # Start the SSH server process with filtered stderr
        # Filter out the epoll_ctl error which is a known Crystal/libssh conflict
        process = Process.new(
          ssh_binary,
          args,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Pipe
        )
        @@ssh_process = process

        # Filter stderr in a separate fiber
        err_io = process.error
        spawn do
          if err = err_io
            begin
              while line = err.gets
                # Skip the epoll_ctl error and its stack trace
                next if line.includes?("epoll_ctl(EPOLL_CTL_ADD): File exists")
                next if line.includes?("signal-loop")
                next if line.includes?("/usr/lib/crystal/")
                next if line.includes?("from ???")
                STDERR.puts line
              end
            rescue IO::Error
              # Pipe closed, process exited
            end
          end
        end

        # Wait for the process to exit
        status = process.wait
        err_io.try &.close rescue nil
        @@ssh_process = nil

        if status.success?
          puts "✅ SSH server stopped normally."
          break
        elsif status.signal_exit?
          puts "⚠️  SSH server killed by signal #{status.exit_signal?}. Restarting in 5 seconds..."
          sleep 5.seconds
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

  def self.spawn_worker_instances(config : Config)
    return if config.instances <= 1

    worker_count = config.instances - 1
    Logging.info("Spawning #{worker_count} additional worker instances...", "🔧")

    # Build command arguments for worker instances
    # We need to pass all the same flags but with SSH disabled
    args = [
      "--port=#{config.port}",
      "--bind=#{config.bind}",
      "--storage-dir=#{config.storage_dir}",
      "--cache-dir=#{config.cache_dir}",
      "--env=#{config.environment}",
      "--theme=#{config.theme}",
      "--max-paste-size=#{config.max_paste_size}",
      "--base-url=#{config.base_url}",
      "--ssh-enabled=false",
      "--instances=1", # Workers don't spawn more workers
    ]

    # Add optional flags
    args << "--log-level=#{config.log_level}" if config.log_level
    args << "--auth-debug-mode" if config.auth_debug_mode?
    args << "--disable-rate-limit" if config.disable_rate_limit?

    # Add rate limiting flags
    args << "--rate-paste-limit=#{config.rate_paste_limit}"
    args << "--rate-paste-window=#{config.rate_paste_window}"
    args << "--rate-paste-user-limit=#{config.rate_paste_user_limit}"
    args << "--rate-paste-user-window=#{config.rate_paste_user_window}"
    args << "--rate-paste-global-limit=#{config.rate_paste_global_limit}"
    args << "--rate-paste-global-window=#{config.rate_paste_global_window}"
    args << "--rate-highlight-limit=#{config.rate_highlight_limit}"
    args << "--rate-highlight-window=#{config.rate_highlight_window}"
    args << "--rate-login-limit=#{config.rate_login_limit}"
    args << "--rate-login-window=#{config.rate_login_window}"
    args << "--rate-http-limit=#{config.rate_http_limit}"
    args << "--rate-http-window=#{config.rate_http_window}"
    args << "--rate-backup-limit=#{config.rate_backup_limit}"
    args << "--rate-backup-window=#{config.rate_backup_window}"

    # Find the pasto binary
    pasto_binary = Process.executable_path || "./bin/pasto"

    # Spawn worker instances
    worker_count.times do |i|
      spawn do
        process = Process.new(
          pasto_binary,
          args,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )
        @@worker_processes << process
        Logging.info("Worker instance #{i + 1} started (PID: #{process.pid})", "✓")
      end
    end

    # Give workers a moment to start
    sleep 0.5.seconds
  end

  def self.stop_worker_instances
    return if @@worker_processes.empty?

    Logging.info("Stopping worker instances...", "🛑")
    @@worker_processes.each do |process|
      begin
        process.signal(:term)
      rescue
        # Process may have already exited
      end
    end
    @@worker_processes.clear
  end

  private def self.find_ssh_binary : String?
    # Check common locations
    candidates = [
      File.join(File.dirname(Process.executable_path || ""), "pasto-ssh"),
      "./bin/pasto-ssh",
      "pasto-ssh",
    ]

    puts "🔍 Looking for pasto-ssh binary..."
    candidates.each do |path|
      puts "   Trying: #{path}"
      if File.exists?(path) && File.info(path).permissions.owner_execute?
        return path
      end
    end
    # Try to find in PATH
    puts "   Trying: PATH (which pasto-ssh)"
    status = Process.run("which", ["pasto-ssh"], output: Process::Redirect::Pipe)
    if status.success?
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
      File.open(config_file, "a") do |file|
        file.puts ""
        file.puts "# Session secret (auto-generated, do not share)"
        file.puts "session_secret: \"#{secret}\""
      end
      puts "🔑 Generated new session secret (saved to #{config_file})"
    else
      puts "🔑 Generated new session secret (config file not found, using in-memory)"
    end

    secret
  end

  private def self.setup_storage_watcher
    backend = Sepia::Storage.backend
    return unless backend.is_a?(Sepia::FileStorage)

    file_storage = backend.as(Sepia::FileStorage)
    return unless file_storage.watcher_running?

    file_storage.on_watcher_change do |event|
      # Log external changes for debugging
      puts "📂 External change detected: #{event.type} #{event.object_class}:#{event.object_id}"

      # The watcher automatically invalidates Sepia's cache
      # No additional action needed - next load will fetch fresh data
    end

    Logging.info("File system watcher enabled for external changes", "👁️")
  end

  def self.run(args)
    # Parse config first before Kemal interferes with ARGV
    self.config = Config.new(args)

    # Initialize logging system
    Logging.configure(config.environment, config.log_level)

    # Clear ARGV to prevent Kemal from interfering
    ARGV.clear

    # Ensure directories exist
    Dir.mkdir_p(config.storage_dir)
    Dir.mkdir_p(config.cache_dir)

    # Initialize Sepia storage with file system watching enabled
    Sepia::Storage.configure(:filesystem, {"path" => config.storage_dir, "watch" => true})

    # Set up watcher callback for external changes (e.g., from pasto-ssh)
    setup_storage_watcher()

    # Get or generate session secret (persisted to config file for consistency across restarts)
    session_secret = get_or_create_session_secret()

    # Ensure sessions directory exists
    Dir.mkdir_p("./sessions")

    # Configure kemal-session with file-based storage
    # Note: SepiaEngine has issues with StorableObject serialization
    Kemal::Session.config do |sess_config|
      sess_config.cookie_name = "pasto_session"
      sess_config.secret = session_secret
      sess_config.timeout = 24.hours
      sess_config.engine = Kemal::Session::FileEngine.new({
        :sessions_dir => "./sessions/",
      })
      sess_config.gc_interval = 30.minutes
    end

    # Initialize cache
    Pasto::Cache.cache_dir = config.cache_dir

    # Configure cacheable endpoints
    # Syntax highlighting API - cache for 1 hour
    Pasto::Cache.add_cache_config(/^\/highlight$/, "application/json", 3600)

    # CSS syntax themes - cache for 24 hours
    Pasto::Cache.add_cache_config(/^\/syntax\/[^\/]+\/[^\/]+$/, "text/css", 86400)

    # Paste image previews for social media - cache for 6 hours
    Pasto::Cache.add_cache_config(/^\/paste\/[^\/]+\/preview$/, "image/png", 21600)

    # Cache test endpoint - cache for 5 seconds
    Pasto::Cache.add_cache_config(/^\/api\/cache-test$/, "text/x-cache-test", 5)

    # Add caching middleware (backup routes will bypass cache automatically if no config matches)
    PastoCache.add_cache_middleware

    # Initialize rate limiters with config values
    RateLimits.init(config)

    # Print web server rate limits
    Logging.info("HTTP Rate limits: paste=#{config.rate_paste_limit}/#{config.rate_paste_window}s, paste-user=#{config.rate_paste_user_limit}/#{config.rate_paste_user_window}s, highlight=#{config.rate_highlight_limit}/#{config.rate_highlight_window}s, login=#{config.rate_login_limit}/#{config.rate_login_window}s, http=#{config.rate_http_limit}/#{config.rate_http_window}s", "⚡")

    # Configure Kemal
    config.add_kemal_config

    # Start SSH server if enabled
    start_ssh_server(config)

    # Spawn worker instances if configured
    spawn_worker_instances(config)

    # Handle graceful shutdown
    Signal::INT.trap do
      puts "\n🛑 Shutting down..."
      stop_worker_instances
      stop_ssh_server
      Kemal.stop
      exit
    end

    Signal::TERM.trap do
      puts "\n🛑 Shutting down..."
      stop_worker_instances
      stop_ssh_server
      Kemal.stop
      exit
    end

    # Start the web server
    Logging.info("Starting Pasto on #{config.bind}:#{config.port}", "🌐")
    Logging.info("Storage: #{config.storage_dir}", "📁")
    Logging.info("Theme: #{config.theme}", "🎨")
    if config.instances > 1
      Logging.info("Instances: #{config.instances} workers (SO_REUSEPORT enabled)", "🔧")
    end
    if config.ssh_enabled?
      Logging.info("SSH: #{config.ssh_bind}:#{config.ssh_port}", "🔐")
    end

    # Prominent warning for auth debug mode
    if config.auth_debug_mode?
      puts "\n" + "="*80
      puts "🚨🚨🚨  AUTHENTICATION DEBUG MODE IS ENABLED  🚨🚨🚨".center(80)
      puts "".center(80)
      puts "⚠️  ALL REQUESTS WILL BE AUTOMATICALLY AUTHENTICATED  ⚠️".center(80)
      puts "⚠️  THIS BYPASSES ALL NORMAL AUTHENTICATION MECHANISMS  ⚠️".center(80)
      puts "".center(80)
      puts "🛑 DO NOT USE IN PRODUCTION - SERIOUS SECURITY RISK 🛑".center(80)
      puts "="*80 + "\n"
    end

    # Prominent warning for rate limit disable
    if config.disable_rate_limit?
      puts "\n" + "="*80
      puts "🚨🚨🚨  ALL RATE LIMITING IS DISABLED  🚨🚨🚨".center(80)
      puts "".center(80)
      puts "⚠️  ALL API ENDPOINTS HAVE UNLIMITED ACCESS  ⚠️".center(80)
      puts "⚠️  NO PROTECTION AGAINST ABUSE OR DoS ATTACKS  ⚠️".center(80)
      puts "".center(80)
      puts "🛑 DO NOT USE IN PRODUCTION - SERIOUS ABUSE RISK 🛑".center(80)
      puts "="*80 + "\n"
    end

    # Register all routes (must happen after config is initialized)
    register_create_routes
    register_paste_routes
    register_profile_routes
    register_utility_routes
    register_api_routes

    # Register BakedFileHandler for assets with base_path support
    assets_mount_path = PathHelper.with_base_path("/assets", config.base_path)
    add_handler BakedFileHandler::BakedFileHandler.new(Pasto::PastoAssets, mount_path: assets_mount_path)

    # Allow multiple instances to bind to the same port (SO_REUSEPORT)
    Kemal.run do |config|
      # Get the server instance from the config
      if server = config.server
        # Bind the server to configured address and port with reuse_port enabled
        # reuse_port: true allows multiple processes to listen on the same port
        # This is useful for load balancing across multiple worker processes
        server.bind_tcp Pasto.config.bind, Pasto.config.port, reuse_port: true
      end
    end
  end
end

Pasto.run(ARGV)

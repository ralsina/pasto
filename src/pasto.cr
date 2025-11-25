require "docopt-config"
require "sepia"
require "kemal"
require "./paste"
require "./server"

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

DOC

  class Config
    property port : Int32
    property bind : String
    property storage_dir : String
    property cache_dir : String
    property environment : String
    property theme : String
    property max_paste_size : Int32

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

    # Initialize cache
    init_cache(config.cache_dir)

    # Configure Kemal
    config.add_kemal_config

    # Start the server
    puts "Starting Pasto on #{config.bind}:#{config.port} with theme: #{config.theme} (max paste size: #{config.max_paste_size} bytes)"
    Kemal.run
  end
end

Pasto.run(ARGV)

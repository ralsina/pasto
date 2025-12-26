require "docopt-config"
require "file_utils"
require "uri"

module PastoCLI
  VERSION = {{ `shards version #{__DIR__}/../..`.chomp.stringify }}

  @@config_dir : String = ""
  @@config_file : String = ""

  def self.config_dir
    if @@config_dir.empty?
      # Use XDG_CONFIG_HOME or ~/.config
      config_home = ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config"))
      @@config_dir = File.join(config_home, "pasto")
      Dir.mkdir_p(@@config_dir) unless Dir.exists?(@@config_dir)
    end
    @@config_dir
  end

  def self.config_file
    if @@config_file.empty?
      @@config_file = File.join(config_dir, "config.yml")
    end
    @@config_file
  end

  def self.credentials_file
    File.join(config_dir, "credentials.yml")
  end

  # Configuration class for docopt-config
  class Config
    property server_url : String = "http://localhost:3000"
    property ssh_host : String = "localhost"
    property ssh_port : Int32 = 2222
    property ssh_key : String = "" # Path to SSH private key
    property timeout : Int32 = 30
    property? verbose : Bool = false

    # Command flags from docopt
    property? login : Bool = false
    property? web : Bool = false
    property? paste : Bool = false
    property? get : Bool = false
    property? list : Bool = false
    property? delete : Bool = false
    property? logout : Bool = false

    # Command arguments
    property file : String = ""
    property id : String = ""
    property title : String = ""
    property language : String = ""
    property? private : Bool = false
    property? encrypted : Bool = false
    property iv : String = ""
    property salt : String = ""
    property iterations : Int32 = 100000
    property page : Int32 = 1
    property limit : Int32 = 20

    def initialize(args : Array(String))
      doc = <<-DOC
Pasto CLI - Command-line client for Pasto pastebin

Usage:
  pasto-cli login [options]
  pasto-cli web [options]
  pasto-cli paste [options] [<file>]
  pasto-cli get <id> [options]
  pasto-cli list [options] [--page=<n>] [--limit=<n>]
  pasto-cli delete <id> [options]
  pasto-cli logout [options]
  pasto-cli -h | --help
  pasto-cli --version

Options:
  -h --help                 Show this screen.
  --version                 Show version.
  --server=<url>            Pasto server URL [default: http://localhost:3000].
  --ssh-host=<host>         SSH server host [default: localhost].
  --ssh-port=<port>         SSH server port [default: 2222].
  --ssh-key=<path>          SSH private key file to use.
  --timeout=<seconds>       Request timeout [default: 30].
  -v --verbose              Show verbose output.
  --title=<title>           Paste title.
  --private                 Make paste private.
  --language=<lang>         Programming language for syntax highlighting.
  --encrypted               Encrypt paste (requires --iv, --salt, --iterations).
  --iv=<iv>                 Encryption IV (for encrypted pastes).
  --salt=<salt>             Encryption salt (for encrypted pastes).
  --iterations=<n>          PBKDF2 iterations [default: 100000].

DOC

      docopt_options = Docopt.docopt_config(
        doc,
        argv: args,
        config_file_path: File.join(PastoCLI.config_dir, "config.yml"),
        env_prefix: "PASTO_CLI",
        version: VERSION
      )

      # Load saved credentials for defaults
      creds = Credentials.load

      # Parse options (use saved credentials if not explicitly provided and still at default)
      server_opt = docopt_options["--server"].to_s
      if server_opt == "http://localhost:3000" && (saved_url = creds.server_url)
        @server_url = saved_url
      else
        @server_url = server_opt
      end

      ssh_host_opt = docopt_options["--ssh-host"].to_s
      if ssh_host_opt == "localhost" && (saved_host = creds.ssh_host)
        @ssh_host = saved_host
      else
        @ssh_host = ssh_host_opt
      end

      ssh_port_opt = parse_int(docopt_options["--ssh-port"])
      if ssh_port_opt == 0 && (saved_port = creds.ssh_port)
        @ssh_port = saved_port
      else
        @ssh_port = ssh_port_opt == 0 ? 2222 : ssh_port_opt
      end

      @ssh_key = docopt_options["--ssh-key"].to_s
      @timeout = parse_int(docopt_options["--timeout"])
      @verbose = docopt_options["--verbose"]?.to_s.in?("true", "yes", "1")

      # Parse commands
      @login = docopt_options["login"]?.to_s.in?("true", "yes", "1")
      @web = docopt_options["web"]?.to_s.in?("true", "yes", "1")
      @paste = docopt_options["paste"]?.to_s.in?("true", "yes", "1")
      @get = docopt_options["get"]?.to_s.in?("true", "yes", "1")
      @list = docopt_options["list"]?.to_s.in?("true", "yes", "1")
      @delete = docopt_options["delete"]?.to_s.in?("true", "yes", "1")
      @logout = docopt_options["logout"]?.to_s.in?("true", "yes", "1")

      # For login/web commands, make --server and --ssh-host default to each other if not specified
      if @login || @web
        # Check if --ssh-host was explicitly provided
        ssh_host_was_provided = docopt_options["--ssh-host"].to_s != "localhost"

        # If server is set but ssh-host wasn't explicitly provided, derive ssh-host from server
        if @server_url != "http://localhost:3000" && !ssh_host_was_provided
          # Extract host from server URL
          # Ensure server_url has a protocol for parsing
          url_to_parse = @server_url.starts_with?("http://") || @server_url.starts_with?("https://") ? @server_url : "https://#{@server_url}"
          uri = URI.parse(url_to_parse)
          @ssh_host = uri.host || "localhost"
          # If ssh-host is set but server is at default, derive server from ssh-host
        elsif @ssh_host != "localhost" && @server_url == "http://localhost:3000"
          # Construct server URL from SSH host
          if @ssh_host.starts_with?("http://") || @ssh_host.starts_with?("https://")
            @server_url = @ssh_host
          else
            @server_url = "https://#{@ssh_host}:3000"
          end
        end
      end

      # Parse command arguments
      @file = docopt_options["<file>"]?.to_s || ""
      @id = docopt_options["<id>"]?.to_s || ""
      @title = docopt_options["--title"]?.to_s || ""
      @language = docopt_options["--language"]?.to_s || ""
      @private = docopt_options["--private"]?.to_s.in?("true", "yes", "1")
      @encrypted = docopt_options["--encrypted"]?.to_s.in?("true", "yes", "1")
      @iv = docopt_options["--iv"]?.to_s || ""
      @salt = docopt_options["--salt"]?.to_s || ""
      @iterations = parse_int(docopt_options["--iterations"])

      @page = parse_int_with_default(docopt_options["--page"], 1)
      @limit = parse_int_with_default(docopt_options["--limit"], 20)
    end

    private def parse_int(value) : Int32
      str_value = value.to_s
      str_value.to_i? || 0
    end

    private def parse_int_with_default(value, default : Int32) : Int32
      result = parse_int(value)
      result == 0 ? default : result
    end
  end

  # Credentials storage (API keys)
  class Credentials
    include YAML::Serializable

    property api_key : String?
    property server_url : String?
    property ssh_host : String?
    property ssh_port : Int32?

    def initialize(@api_key : String? = nil, @server_url : String? = nil, @ssh_host : String? = nil, @ssh_port : Int32? = nil)
    end

    def self.load : Credentials
      creds = Credentials.new

      if File.exists?(PastoCLI.credentials_file)
        creds = Credentials.from_yaml(File.read(PastoCLI.credentials_file))
      end

      creds
    end

    def save : Nil
      File.write(PastoCLI.credentials_file, to_yaml)
    end

    def clear : Nil
      if File.exists?(PastoCLI.credentials_file)
        File.delete(PastoCLI.credentials_file)
      end
    end

    def api_key? : Bool
      if key = api_key
        !key.empty?
      else
        false
      end
    end
  end
end

require "docopt-config"
require "sepia"
require "./models/paste"
require "./ssh_server"

module PastoSshServer
  VERSION = "0.1.0"

  SSH_DOC = <<-DOC
Pasto SSH Server - Crystal Pastebin SSH Server

Usage:
  pasto-ssh [options]
  pasto-ssh -h | --help
  pasto-ssh --version

Options:
  -h --help                 Show this screen.
  --version                 Show version.
  --port=<port>             SSH port to listen on [default: 2222].
  --bind=<address>          SSH address to bind to [default: 0.0.0.0].
  --storage-dir=<dir>       Directory to store pastes [default: ./data].
  --host-key=<file>         SSH host key file [default: ssh_host_rsa_key].
  --base-url=<url>          Base URL for paste links [default: http://localhost:5000].

DOC

  class Config
    property port : Int32
    property bind : String
    property storage_dir : String
    property host_key : String
    property base_url : String

    def initialize(args)
      docopt_options = Docopt.docopt_config(
        SSH_DOC,
        argv: args,
        config_file_path: "pasto_ssh.yml",
        env_prefix: "PASTO_SSH",
        version: VERSION
      )

      @port = docopt_options["--port"].to_s.to_i
      @bind = docopt_options["--bind"].to_s
      @storage_dir = docopt_options["--storage-dir"].to_s
      @host_key = docopt_options["--host-key"].to_s
      @base_url = docopt_options["--base-url"].to_s
    end
  end

  def self.run(args)
    config = Config.new(args)

    # Clear ARGV to prevent interference
    ARGV.clear

    # Ensure storage directory exists
    Dir.mkdir_p(config.storage_dir)

    # Initialize Sepia storage
    Sepia::Storage.configure(:filesystem, {"path" => config.storage_dir})

    # Generate host keys if they don't exist
    generate_host_keys(config.host_key) unless File.exists?(config.host_key)

    # Set base URL for paste links
    PastoSSH.base_url = config.base_url

    puts "🔐 Starting Pasto SSH server on #{config.bind}:#{config.port}"
    puts "📁 Storing pastes in: #{config.storage_dir}"
    puts "🔑 Using host key: #{config.host_key}"
    puts "🔗 Base URL: #{config.base_url}"
    puts ""
    puts "Usage examples:"
    puts "  echo 'Hello World' | ssh -p #{config.port} #{config.bind}"
    puts "  cat file.txt | ssh -p #{config.port} #{config.bind}"

    # Create and start SSH server
    ssh_server = PastoSSH.create_server(config.host_key, config.port, config.bind)

    # Keep main thread alive
    puts "✅ SSH server started. Press Ctrl+C to stop."

    # Run the server (this blocks)
    ssh_server.run

    puts "✅ SSH server stopped."
  end

  private def self.generate_host_keys(host_key_file : String)
    puts "🔐 Generating SSH host keys at #{host_key_file}..."

    # Generate RSA host key
    system("ssh-keygen -t rsa -f #{host_key_file} -N '' -q")

    if File.exists?(host_key_file)
      puts "✅ SSH host keys generated successfully."
    else
      puts "❌ Failed to generate SSH host keys."
      exit 1
    end
  end
end

PastoSshServer.run(ARGV)

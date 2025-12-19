require "docopt-config"
require "sepia"
require "./backup_manager"
require "./logging"

module PastoBackup
  VERSION = "0.1.0"

  DOC = <<-DOC
Pasto Backup Tool - Create backups for user data

Usage:
  pasto-backup [options]
  pasto-backup -h | --help
  pasto-backup --version

Options:
  -h --help                 Show this screen.
  --version                 Show version.
  --user-id=<user_id>       User ID to create backup for (required).
  --storage-dir=<dir>       Directory to store pastes [default: ./data].
  --log-level=<level>       Log level (debug, info, warn, error, fatal) [default: info].

Examples:
  pasto-backup --user-id=user_12345
  pasto-backup --user-id=user_12345 --storage-dir=/var/lib/pasto/data
DOC

  class Config
    property user_id : String
    property storage_dir : String
    property log_level : String?

    def initialize(args)
      docopt_options = Docopt.docopt_config(
        DOC,
        argv: args,
        config_file_path: "pasto.yml",
        env_prefix: "PASTO_BACKUP",
        version: VERSION
      )

      @user_id = docopt_options["--user-id"].to_s
      @storage_dir = docopt_options["--storage-dir"].to_s
      log_level_option = docopt_options["--log-level"].to_s
      @log_level = log_level_option.empty? ? nil : log_level_option

      # Validate required options
      if @user_id.empty?
        puts "Error: --user-id is required"
        exit 1
      end
    end
  end

  def self.run(args)
    config = Config.new(args)

    # Initialize logging system
    environment = ENV["KEMAL_ENV"]? || "development"
    Pasto::Logging.configure(environment, config.log_level)

    # Ensure storage directory exists
    Dir.mkdir_p(config.storage_dir)

    # Initialize Sepia storage
    Sepia::Storage.configure(:filesystem, {"path" => config.storage_dir})

    Pasto::Logging.info("Starting backup creation for user: #{config.user_id}")

    # Create backup
    result = Pasto::BackupManager.create_user_backup(config.user_id, config.storage_dir)

    if result[:success]
      Pasto::Logging.info("Backup completed successfully: #{result[:backup_path]}")
      puts "Backup created successfully: #{result[:backup_path]}"
      exit 0
    else
      Pasto::Logging.error("Backup failed: #{result[:error]}")
      puts "Error: #{result[:error]}"
      exit 1
    end
  rescue ex
    puts "Unexpected error: #{ex.message}"
    Pasto::Logging.error("Unexpected error: #{ex.message}")
    puts ex.backtrace.join("\n") if ENV["DEBUG"]?
    exit 1
  end
end

# Run the backup tool if this file is executed directly
if PROGRAM_NAME.includes?("pasto-backup")
  PastoBackup.run(ARGV)
end

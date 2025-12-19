require "log"

module Pasto
  # Centralized logging configuration for the Pasto application
  module Logging
    # Configure the application logger
    def self.configure(environment : String? = nil, log_level : String? = nil)
      env = environment || ENV["KEMAL_ENV"]? || "development"

      # Determine log level based on environment or explicit setting
      level = case log_level
              when "debug"
                Log::Severity::Debug
              when "info"
                Log::Severity::Info
              when "warn"
                Log::Severity::Warn
              when "error"
                Log::Severity::Error
              when "fatal"
                Log::Severity::Fatal
              else
                case env
                when "production"
                  Log::Severity::Info
                when "test"
                  Log::Severity::Error
                else
                  Log::Severity::Info
                end
              end

      # Configure the global logger backend
      Log.setup do |config|
        config.bind "*", level, Log::IOBackend.new
      end

      # Store the environment for context
      @@environment = env
    end

    # Get the current environment
    def self.environment
      @@environment
    end

    @@environment : String?

    # Helper method to format messages with emojis while maintaining log levels
    private def self.format_message(message : String, emoji : String? = nil)
      if emoji && environment != "production"
        "#{emoji} #{message}"
      else
        message
      end
    end

    # Convenience methods for different log levels with emoji support
    def self.debug(message : String, emoji : String? = nil)
      Log.debug { format_message(message, emoji) }
    end

    def self.info(message : String, emoji : String? = nil)
      Log.info { format_message(message, emoji) }
    end

    def self.warn(message : String, emoji : String? = nil)
      Log.warn { format_message(message, emoji) }
    end

    def self.error(message : String, emoji : String? = nil)
      Log.error { format_message(message, emoji) }
    end

    def self.fatal(message : String, emoji : String? = nil)
      Log.fatal { format_message(message, emoji) }
    end
  end
end

require "./cli/config"
require "./cli/ssh_client"
require "./cli/api_client"
require "./cli/commands"

module PastoCLI
  def self.run(args : Array(String))
    config = Config.new(args)

    # Execute command based on parsed args
    if config.login?
      Commands::Login.new(config).execute
    elsif config.web?
      Commands::Web.new(config).execute
    elsif config.paste?
      Commands::Paste.new(config).execute
    elsif config.get?
      Commands::Get.new(config).execute
    elsif config.list?
      Commands::List.new(config).execute
    elsif config.delete?
      Commands::Delete.new(config).execute
    elsif config.logout?
      Commands::Logout.new(config).execute
    else
      # Show help if no command recognized
      puts "Usage: pasto-cli <command> [options]"
      puts ""
      puts "Commands:"
      puts "  login    Authenticate via SSH and store API key"
      puts "  web      Open web interface in browser (via SSH login)"
      puts "  paste    Create a paste (from file or stdin)"
      puts "  get      Retrieve and display a paste"
      puts "  list     List your pastes"
      puts "  delete   Delete a paste"
      puts "  logout   Clear stored credentials"
      puts ""
      puts "Run 'pasto-cli --help' for full usage"
      exit 1
    end
  rescue ex : Exception
    puts "Error: #{ex.message}"
    puts ex.backtrace.join("\n") if ENV["DEBUG"]?
    exit 1
  end
end

PastoCLI.run(ARGV)

# paste_helper.cr - Helper binary for SSH paste creation
# Reads stdin and creates a paste, outputs the URL
#
# Usage: paste_helper [fingerprint] [storage_dir]

require "sepia"
require "./models/paste"

STDERR.puts "DEBUG: paste_helper started"
STDERR.flush

# Get arguments
fingerprint = ARGV[0]? || "unknown"
storage_dir = ARGV[1]? || "./data"

STDERR.puts "DEBUG: fingerprint=#{fingerprint}, storage_dir=#{storage_dir}"
STDERR.flush

# Initialize storage
Sepia::Storage.configure(:filesystem, {"path" => storage_dir})

STDERR.puts "DEBUG: storage configured"
STDERR.flush

# Read all stdin
STDERR.puts "DEBUG: reading stdin..."
STDERR.flush

content = STDIN.gets_to_end

STDERR.puts "DEBUG: read #{content.size} bytes"
STDERR.flush

if content.strip.empty?
  STDERR.puts "No content provided"
  exit 1
end

# Create the paste
paste = Pasto::Paste.new(
  content: content,
  theme: "default-dark",
  ssh_fingerprint: fingerprint,
  ssh_ip: "ssh_client"
)

if paste.save
  puts "Paste created: http://localhost:3000/paste/#{paste.sepia_id}"
  exit 0
else
  STDERR.puts "Failed to create paste"
  exit 1
end

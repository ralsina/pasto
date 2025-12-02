require "../src/models/paste"
require "shirk"
require "sepia"

module PastoSSH
  @@current_fingerprint = ""
  @@storage_dir = "./data"
  @@base_url = "http://localhost:3000"

  def self.storage_dir=(dir : String)
    @@storage_dir = dir
    Sepia::Storage.configure(:filesystem, {"path" => dir})
  end

  def self.base_url=(url : String)
    @@base_url = url
  end

  def self.create_server(host_key : String, port : Int32, bind_address : String)
    server = Shirk::Server.new(
      host: bind_address,
      port: port,
      host_key: host_key
    )

    # Accept all public keys and store the fingerprint
    server.on_auth_pubkey do |user, fingerprint|
      puts "SSH auth: user '#{user}' with key #{fingerprint}"
      @@current_fingerprint = fingerprint
      true # Accept all keys
    end

    # Handle exec requests - only "paste" command is supported
    server.on_exec do |ctx|
      puts "SSH exec: command='#{ctx.command}' from user='#{ctx.user}'"

      if ctx.command != "paste"
        ctx.write_stderr("Unknown command: #{ctx.command}\n")
        ctx.write_stderr("Usage: echo 'text' | ssh -p PORT host paste\n")
        next 1
      end

      # ctx.stdin contains ALL data the client sent (already collected by shirk)
      content = ctx.stdin

      puts "SSH: received #{content.bytesize} bytes of content"

      if content.strip.empty?
        ctx.write_stderr("No content provided. Usage: echo 'text' | ssh -p PORT host paste\n")
        next 1
      end

      # Create paste
      paste = Pasto::Paste.new(
        content: content,
        theme: "default-dark",
        ssh_fingerprint: @@current_fingerprint,
        ssh_ip: "ssh_client"
      )

      if paste.save
        url = "#{@@base_url}/paste/#{paste.sepia_id}\n"
        ctx.write(url)
        puts "SSH: created paste #{paste.sepia_id}"
        0
      else
        ctx.write_stderr("Failed to create paste\n")
        1
      end
    end

    server
  end
end

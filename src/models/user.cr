require "sepia"
require "./ssh_key"

module Pasto
  class User < Sepia::Object
    include Sepia::Serializable

    property name : String?
    property keys : Array(SSHKey)
    property created_at : Time
    
    # Theme preferences
    property pico_theme : String?
    property pico_color : String?
    property syntax_theme : String?

    def initialize(@name : String? = nil)
      @keys = [] of SSHKey
      @created_at = Time.utc
      @pico_theme = nil
      @pico_color = nil
      @syntax_theme = nil
    end

    # Display name - returns name or a friendly default
    def display_name : String
      @name.presence || "Anonymous User"
    end

    # Add an SSH key to this user
    # Updates both sides of the relationship
    def add_key(key : SSHKey) : SSHKey
      key.owner_id = @sepia_id
      @keys << key
      key.save  # Save the key with updated owner_id
      key
    end

    # Add a key by fingerprint (loads or creates it)
    def add_key_by_fingerprint(fingerprint : String) : SSHKey
      key = SSHKey.find_or_create(fingerprint)
      add_key(key)
    end

    # Get all pastes for this user (from SSH keys)
    def all_pastes : Array(Paste)
      @keys.flat_map(&.pastes)
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        name:         @name,
        keys:         @keys.map(&.sepia_id),  # Store only key fingerprints
        created_at:   @created_at.to_rfc3339,
        pico_theme:   @pico_theme,
        pico_color:   @pico_color,
        syntax_theme: @syntax_theme,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : User
      data = Hash(String, JSON::Any).from_json(sepia_string)

      user = new(name: data["name"]?.try(&.as_s?))
      user.created_at = Time.parse_rfc3339(data["created_at"].as_s)
      user.pico_theme = data["pico_theme"]?.try(&.as_s?)
      user.pico_color = data["pico_color"]?.try(&.as_s?)
      user.syntax_theme = data["syntax_theme"]?.try(&.as_s?)

      # Load keys by their fingerprints
      if keys_data = data["keys"]?.try(&.as_a?)
        user.keys = keys_data.compact_map do |fingerprint|
          SSHKey.find_or_create(fingerprint.as_s)
        end
      end

      user
    end

    def save : Bool
      begin
        Sepia::Storage.save(self)
        true
      rescue ex
        false
      end
    end

    def self.find(id : String) : User?
      Sepia::Storage.load(User, id)
    rescue
      nil
    end
  end
end

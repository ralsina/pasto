require "sepia"
require "./ssh_key"
require "./api_key"

module Pasto
  class User < Sepia::Object
    include Sepia::Serializable

    property name : String?
    property keys : Array(SSHKey)
    property api_keys : Array(String) = [] of String # Stores ApiKey IDs
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
      key.save # Save the key with updated owner_id
      save     # Save the user with updated keys array
      key
    end

    # Add an API key to this user
    def add_api_key : ApiKey
      api_key = ApiKey.create_for_user(@sepia_id)
      @api_keys << api_key.sepia_id
      save
      api_key
    end

    # Get all API keys for this user
    def all_api_keys : Array(ApiKey)
      @api_keys.compact_map do |key_id|
        begin
          ApiKey.find(key_id)
        rescue
          nil
        end
      end
    end

    # Get all pastes for this user (latest versions from storage)
    def all_pastes : Array(Paste)
      @keys.flat_map(&.pastes).compact_map do |paste|
        begin
          loaded_paste = Paste.from_file(paste.sepia_id)
          loaded_paste
        rescue
          nil # Skip pastes that can't be loaded
        end
      end.compact
    end

    # Return all related objects for Sepia backup traversal
    def sepia_references : Array(Sepia::Object)
      references = [] of Sepia::Object

      # Add SSH keys
      references.concat(@keys)

      # Add API keys
      references.concat(all_api_keys)

      references
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        name:         @name,
        keys:         @keys.map(&.sepia_id), # Store only key fingerprints
        api_keys:     @api_keys,             # Store API key IDs
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

      # Load API keys by their IDs
      if api_keys_data = data["api_keys"]?.try(&.as_a?)
        user.api_keys = api_keys_data.compact_map(&.as_s)
      end

      user
    end

    def save : Bool
      Sepia::Storage.save(self)
      true
    rescue ex
      false
    end

    def self.find(id : String) : User?
      Sepia::Storage.load(User, id)
    rescue
      nil
    end
  end
end

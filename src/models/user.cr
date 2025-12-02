require "sepia"
require "./ssh_key"

module Pasto
  class User < Sepia::Object
    include Sepia::Serializable

    property name : String?
    property keys : Array(SSHKey)
    property created_at : Time

    def initialize(@name : String? = nil)
      @keys = [] of SSHKey
      @created_at = Time.utc
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

    # Get all pastes across all keys for this user
    def all_pastes : Array(Paste)
      @keys.flat_map(&.pastes)
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        name:       @name,
        keys:       @keys.map(&.sepia_id),  # Store only key fingerprints
        created_at: @created_at.to_rfc3339,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : User
      data = Hash(String, JSON::Any).from_json(sepia_string)

      user = new(name: data["name"]?.try(&.as_s?))
      user.created_at = Time.parse_rfc3339(data["created_at"].as_s)

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

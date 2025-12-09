require "sepia"
require "random/secure"

struct ApiKeyData
  include JSON::Serializable

  property created_at : Time
  property usage_count : Int32 = 0
  property last_used_at : Time?

  def initialize
    @created_at = Time.utc
  end
end

module Pasto
  class ApiKey < Sepia::Object
    include Sepia::Serializable

    property user_id : String
    property key_data : ApiKeyData

    # Override sepia_id to return the API key itself
    def sepia_id : String
      # The Sepia ID is the API key itself (generated on creation)
      @sepia_id ||= self.class.generate_api_key
    end

    def initialize(@user_id : String, @key_data : ApiKeyData)
      # Generate the API key as the Sepia ID
      @sepia_id = self.class.generate_api_key
    end

    # Initialize from existing data with known key
    def initialize(@user_id : String, @key_data : ApiKeyData, @sepia_id : String)
    end

    # Helper methods
    def id : String
      sepia_id
    end

    # Generate a new API key
    def self.generate_api_key : String
      "pasto_ak_#{Random::Secure.hex(16)}"
    end

    def increment_usage
      @key_data.usage_count += 1
      @key_data.last_used_at = Time.utc
      save
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        user_id: @user_id,
        key_data: @key_data,
        sepia_id: @sepia_id,  # Store the key in the data too
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : ApiKey
      data = Hash(String, JSON::Any).from_json(sepia_string)
      new(
        data["user_id"].as_s,
        ApiKeyData.from_json(data["key_data"].to_json),
        data["sepia_id"].as_s
      )
    end

    def save : Bool
      Sepia::Storage.save(self)
      true
    rescue ex
      false
    end

    # Find by Sepia ID (standard Sepia pattern)
    def self.find(id : String) : ApiKey?
      Sepia::Storage.load(ApiKey, id)
    rescue
      nil
    end

    # Direct lookup by API key - now O(1) instead of O(n)!
    def self.find_by_key(key_string : String) : ApiKey?
      # Direct lookup using the API key as the Sepia ID
      find(key_string)
    rescue
      nil
    end

    # Create a new API key for a user
    def self.create_for_user(user_id : String) : ApiKey
      key_data = ApiKeyData.new
      api_key = new(user_id, key_data)
      api_key.save
      api_key
    end
  end
end
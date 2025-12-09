require "sepia"

struct ApiKeyData
  include JSON::Serializable

  property id : String            # "pasto_ak_" + random
  property created_at : Time
  property usage_count : Int32 = 0
  property last_used_at : Time?

  def initialize(@id : String)
    @created_at = Time.utc
  end
end

module Pasto
  class ApiKey < Sepia::Object
    include Sepia::Serializable

    property user_id : String
    property key_data : ApiKeyData

    def initialize(@user_id : String, @key_data : ApiKeyData)
    end

    # Helper methods
    def id : String
      @key_data.id
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
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : ApiKey
      data = Hash(String, JSON::Any).from_json(sepia_string)
      new(
        data["user_id"].as_s,
        ApiKeyData.from_json(data["key_data"].to_json)
      )
    end

    def save : Bool
      Sepia::Storage.save(self)
      true
    rescue ex
      false
    end

    def self.find(id : String) : ApiKey?
      Sepia::Storage.load(ApiKey, id)
    rescue
      nil
    end

    # Find API key by the actual key string (pasto_ak_*)
    def self.find_by_key(key_string : String) : ApiKey?
      # For now, we need to search through all API keys since we don't have an index
      # This is inefficient but works for the current scale
      api_key_dir = "data/Pasto::ApiKey"
      if Dir.exists?(api_key_dir)
        Dir.children(api_key_dir).each do |file_id|
          api_key = find(file_id)
          if api_key && api_key.key_data.id == key_string
            return api_key
          end
        end
      end
      nil
    rescue
      nil
    end
  end
end
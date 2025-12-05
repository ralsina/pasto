require "sepia"

module Pasto
  class AuthToken < Sepia::Object
    include Sepia::Serializable

    property fingerprint : String
    property created_at : Time
    property expires_at : Time

    # Token valid for 10 minutes
    TOKEN_LIFETIME = 10.minutes

    def initialize(@fingerprint : String)
      @created_at = Time.utc
      @expires_at = @created_at + TOKEN_LIFETIME
    end

    def expired? : Bool
      Time.utc > @expires_at
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        fingerprint: @fingerprint,
        created_at:  @created_at.to_rfc3339,
        expires_at:  @expires_at.to_rfc3339,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : AuthToken
      data = Hash(String, JSON::Any).from_json(sepia_string)

      token = new(fingerprint: data["fingerprint"].as_s)
      token.created_at = Time.parse_rfc3339(data["created_at"].as_s)
      token.expires_at = Time.parse_rfc3339(data["expires_at"].as_s)
      token
    end

    def save : Bool
      Sepia::Storage.save(self)
      true
    rescue ex
      false
    end

    def delete : Bool
      Sepia::Storage.delete(self)
      true
    rescue ex
      false
    end

    def self.find(id : String) : AuthToken?
      Sepia::Storage.load(AuthToken, id)
    rescue
      nil
    end
  end
end

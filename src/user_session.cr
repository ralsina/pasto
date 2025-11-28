require "sepia"
require "kemal-session"

module Pasto
  class UserSession
    include JSON::Serializable
    include Kemal::Session::StorableObject

    property session_id : String
    property user_id : String
    property created_at : Time
    property last_accessed : Time
    property fingerprint : String?
    property ip_address : String?

    def initialize(@user_id : String, @fingerprint : String? = nil, @ip_address : String? = nil)
      @session_id = generate_session_id
      @created_at = Time.utc
      @last_accessed = @created_at
    end

    def touch
      @last_accessed = Time.utc
    end

    def expired?(max_age : Time::Span = 24.hours) : Bool
      Time.utc > @last_accessed + max_age
    end

    private def generate_session_id : String
      # Generate a cryptographically secure session ID
      Random::Secure.hex(32)
    end
  end
end
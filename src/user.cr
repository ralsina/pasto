require "sepia"

module Pasto
  class User < Sepia::Object
    include Sepia::Serializable

    property username : String
    property display_name : String
    property email : String?
    property created_at : Time
    property updated_at : Time
    property? is_active : Bool

    def initialize(@username : String, @display_name : String, @email : String? = nil, @is_active : Bool = true)
      @created_at = Time.utc
      @updated_at = Time.utc
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        username:     @username,
        display_name: @display_name,
        email:        @email,
        created_at:   @created_at.to_rfc3339,
        updated_at:   @updated_at.to_rfc3339,
        is_active:    @is_active,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : User
      data = Hash(String, JSON::Any).from_json(sepia_string)
      user = new(
        username: data["username"].as_s,
        display_name: data["display_name"].as_s,
        email: data["email"]?.try(&.as_s?),
        is_active: data["is_active"]?.try(&.as_bool?) || true
      )
      user.created_at = Time.parse_rfc3339(data["created_at"].as_s)
      user.updated_at = Time.parse_rfc3339(data["updated_at"].as_s)
      user
    end

    # Compatibility methods
    def self.from_file(username : String) : User?
      Sepia::Storage.load(User, username)
    rescue ex
      nil
    end

    def save : Bool
      @updated_at = Time.utc
      begin
        Sepia::Storage.save(self)
        true
      rescue ex
        false
      end
    end

    def public_user? : Bool
      @username == "public"
    end

    def display_name_for_ui : String
      @display_name.empty? ? @username : @display_name
    end

    # Generate a unique username for new users
    def self.generate_unique_username(base_name : String? = nil) : String
      base_name ||= "user"
      counter = 0
      username = base_name

      while Sepia::Storage.exists?(User, username)
        counter += 1
        username = "#{base_name}#{counter}"
      end

      username
    end

    # Sanitize username to only contain valid characters
    def self.sanitize_username(username : String) : String
      # Remove invalid characters and replace with underscores
      sanitized = username.gsub(/[^a-zA-Z0-9_-]/, "_")

      # Remove leading/trailing underscores and dashes
      sanitized = sanitized.gsub(/^[_-]+|[_-]+$/, "")

      # Ensure it's not empty
      sanitized = "user_#{Random::Secure.hex(4)}" if sanitized.empty?

      # Limit length
      sanitized[0..31]
    end
  end
end
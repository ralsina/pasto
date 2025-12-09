require "sepia"
require "random/secure"
require "../ssh_utils"

module Pasto
  class SSHKeyChallenge < Sepia::Object
    include Sepia::Serializable

    property user_id : String
    property fingerprint : String
    property public_key : String
    property expires_at : Time

    def initialize(@user_id : String, @fingerprint : String, @public_key : String)
      @expires_at = Time.utc + 30.minutes # Challenges expire after 30 minutes
      @sepia_id = self.class.generate_challenge_code
    end

    # Initialize from existing data with known challenge code
    def initialize(@user_id : String, @fingerprint : String, @public_key : String, @sepia_id : String, @expires_at : Time)
    end

    # Helper methods
    def id : String
      sepia_id
    end

    # Check if challenge is still valid
    def valid? : Bool
      Time.utc < @expires_at
    end

    # Generate a new challenge code
    def self.generate_challenge_code : String
      Random::Secure.hex(4).upcase # 8-character hex code, uppercase
    end

    # Create a new challenge for a user and SSH key
    def self.create_for_key(user_id : String, public_key : String) : SSHKeyChallenge
      # Keep the full fingerprint with SHA256: prefix for consistency
      fingerprint = SSHUtils.extract_fingerprint(public_key)
      challenge = new(user_id, fingerprint, public_key)
      challenge.save
      challenge
    end

    # Find a challenge by its code
    def self.find_by_code(code : String) : SSHKeyChallenge?
      find(code)
    rescue
      nil
    end

    # Find all challenges for a user
    def self.find_for_user(user_id : String) : Array(SSHKeyChallenge)
      # This is inefficient but we don't have a better way with Sepia storage
      # In practice, users should have very few active challenges
      all_challenges = [] of SSHKeyChallenge

      # We can't easily iterate all SSHKeyChallenge objects with Sepia
      # For now, we'll rely on the fact that challenges are short-lived
      # and users will only have a few at a time

      all_challenges
    end

    # Clean up expired challenges
    def self.cleanup_expired
      # In a real implementation, we'd iterate and delete expired ones
      # For now, we rely on the file system cleanup or manual cleanup
      # This is a limitation of the current Sepia storage approach
    end

    # Validate challenge response and delete if successful
    def self.validate_and_delete(code : String, expected_user_id : String, expected_fingerprint : String) : Bool
      challenge = find_by_code(code)
      return false unless challenge

      # Verify challenge details match
      return false unless challenge.user_id == expected_user_id
      return false unless challenge.fingerprint == expected_fingerprint
      return false unless challenge.valid?

      # Delete the challenge (immediate deletion as requested)
      begin
        challenge_file_path = "data/Pasto::SSHKeyChallenge/#{code}"
        if File.exists?(challenge_file_path)
          File.delete(challenge_file_path)
        end
        true
      rescue
        false
      end
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        user_id:     @user_id,
        fingerprint: @fingerprint,
        public_key:  @public_key,
        expires_at:  @expires_at.to_rfc3339,
        sepia_id:    @sepia_id,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : SSHKeyChallenge
      data = Hash(String, JSON::Any).from_json(sepia_string)
      new(
        data["user_id"].as_s,
        data["fingerprint"].as_s,
        data["public_key"].as_s,
        data["sepia_id"].as_s,
        Time.parse_rfc3339(data["expires_at"].as_s)
      )
    end

    def save : Bool
      Sepia::Storage.save(self)
      true
    rescue ex
      false
    end

    def self.find(id : String) : SSHKeyChallenge?
      Sepia::Storage.load(SSHKeyChallenge, id)
    rescue
      nil
    end
  end
end

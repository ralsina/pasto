require "sepia"

module Pasto
  class LoginToken < Sepia::Object
    include Sepia::Serializable

    property token : String
    property user_id : String
    property fingerprint : String
    property created_at : Time
    property expires_at : Time

    def initialize(@user_id : String, @fingerprint : String, @expires_in : Time::Span = 15.minutes)
      @token = generate_secure_token
      @created_at = Time.utc
      @expires_at = @created_at + @expires_in

      # Set the Sepia ID to the token for direct lookup
      @sepia_id = @token
    end

    def expired? : Bool
      Time.utc > @expires_at
    end

    def valid?(fingerprint : String? = nil) : Bool
      return false if expired?
      return false if fingerprint && @fingerprint != fingerprint
      true
    end

    private def generate_secure_token : String
      # Generate a cryptographically secure random token
      Random::Secure.urlsafe_base64(32)
    end

    # Sepia compatibility methods
    def self.from_file(token_id : String) : LoginToken?
      Sepia::Storage.load(LoginToken, token_id)
    rescue ex
      nil
    end

    def save : Bool
      begin
        Sepia::Storage.save(self)
        true
      rescue ex
        false
      end
    end

    def destroy
      Sepia::Storage.delete(self)
    end
  end

  class LoginTokenService
    @@cleanup_mutex = Mutex.new

    TOKEN_LIFETIME = 15.minutes
    MAX_TOKENS_PER_USER = 5

    def self.generate_token(user : User, fingerprint : String) : String
      token = LoginToken.new(user.username, fingerprint, TOKEN_LIFETIME)
      token.save

      puts "Generated login token for user #{user.username} (fingerprint: #{fingerprint[0..11]}...)"
      token.token
    end

    def self.validate_token(token : String, fingerprint : String? = nil) : User?
      # Use token string as the Sepia ID to look up directly
      begin
        login_token = LoginToken.from_file(token)
        return nil unless login_token

        # Check if token is valid and not expired
        return nil unless login_token.valid?(fingerprint)

        # Token is valid - remove it to prevent reuse
        login_token.destroy

        puts "Validated login token for user #{login_token.user_id}"
        UserService.get_user_by_username(login_token.user_id)
      rescue ex
        # Token not found or corrupted
        nil
      end
    end

    # Token cleanup happens automatically during validation (lazy cleanup)
  end
end
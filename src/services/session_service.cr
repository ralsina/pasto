require "openssl/hmac"

module Pasto
  class UserSession
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

  class SessionService
    @@sessions = {} of String => UserSession
    @@session_mutex = Mutex.new
    @@session_secret = ENV["PASTO_SESSION_SECRET"]? || Random::Secure.hex(64)

    SESSION_COOKIE_NAME = "pasto_session"
    SESSION_LIFETIME = 24.hours
    MAX_SESSIONS_PER_USER = 10

    def self.generate_session_cookie(user : User, fingerprint : String? = nil, ip_address : String? = nil) : HTTP::Cookie
      cleanup_expired_sessions

      # Remove old sessions for this user to prevent session accumulation
      cleanup_user_sessions(user.username)

      session = UserSession.new(user.username, fingerprint, ip_address)
      @@sessions[session.session_id] = session

      # Create secure session cookie with HMAC signature
      cookie_value = create_signed_session_data(session.session_id, user.username)

      HTTP::Cookie.new(
        name: SESSION_COOKIE_NAME,
        value: cookie_value,
        path: "/",
        expires: Time.utc + SESSION_LIFETIME,
        http_only: true,
        secure: false,  # Set to true in production with HTTPS
        samesite: HTTP::Cookie::SameSite::Lax
      )
    end

    def self.validate_session(request : HTTP::Request) : User?
      session_cookie = request.cookies[SESSION_COOKIE_NAME]?

      return nil unless session_cookie

      begin
        session_id, username = verify_signed_session_data(session_cookie.value)

        session = @@sessions[session_id]?
        return nil unless session

        return nil if session.expired?(SESSION_LIFETIME)
        return nil if session.user_id != username

        # Update last accessed time
        session.touch

        puts "Validated session for user #{session.user_id} (last accessed: #{session.last_accessed})"
        UserService.get_user_by_username(session.user_id)
      rescue ex
        puts "Session validation error: #{ex.message}"
        nil
      end
    end

    def self.logout_user(session_cookie_value : String) : Bool
      begin
        session_id, _ = verify_signed_session_data(session_cookie_value)
        session = @@sessions.delete(session_id)

        if session
          puts "Logged out user #{session.user_id}"
          true
        else
          false
        end
      rescue ex
        puts "Logout error: #{ex.message}"
        false
      end
    end

    def self.cleanup_expired_sessions
      @@session_mutex.synchronize do
        expired_sessions = @@sessions.select { |_, session| session.expired?(SESSION_LIFETIME) }
        expired_sessions.each do |session_id, _|
          @@sessions.delete(session_id)
        end

        puts "Cleaned up #{expired_sessions.size} expired sessions" unless expired_sessions.empty?
      end
    end

    def self.cleanup_user_sessions(username : String)
      # Remove oldest sessions for this user, keeping only MAX_SESSIONS_PER_USER
      user_sessions = @@sessions.select { |_, session| session.user_id == username }

      if user_sessions.size > MAX_SESSIONS_PER_USER
        # Sort by last accessed time (oldest first) and remove excess
        sorted_sessions = user_sessions.to_a.sort_by { |_, session| session.last_accessed }
        excess_count = sorted_sessions.size - MAX_SESSIONS_PER_USER

        excess_count.times do |i|
          session_id_to_remove = sorted_sessions[i][0]
          @@sessions.delete(session_id_to_remove)
        end

        puts "Cleaned up #{excess_count} excess sessions for user #{username}"
      end
    end

    def self.session_count : Int32
      @@sessions.size
    end

    def self.start_cleanup_task
      # Start background task to clean up expired sessions every 30 minutes
      spawn do
        loop do
          sleep(30.minutes)
          cleanup_expired_sessions
        end
      end
    end

    private def self.create_signed_session_data(session_id : String, username : String) : String
      # Create HMAC signature for session data
      data = "#{session_id}:#{username}:#{Time.utc.to_unix}"
      signature = OpenSSL::HMAC.hexdigest(:sha256, @@session_secret, data)

      "#{Base64.urlsafe_encode(data)}:#{signature}"
    end

    private def self.verify_signed_session_data(cookie_value : String) : Tuple(String, String)
      parts = cookie_value.split(":")

      if parts.size != 2
        raise "Invalid cookie format"
      end

      encoded_data = parts[0]
      provided_signature = parts[1]

      begin
        data = Base64.decode_string(encoded_data)
        data_parts = data.split(":")

        if data_parts.size != 3
          raise "Invalid data format"
        end

        session_id = data_parts[0]
        username = data_parts[1]
        timestamp = data_parts[2].to_i64

        # Verify timestamp is not too old (prevent replay attacks)
        if Time.utc - Time.unix(timestamp) > SESSION_LIFETIME
          raise "Session timestamp too old"
        end

        # Verify HMAC signature
        expected_signature = OpenSSL::HMAC.hexdigest(:sha256, @@session_secret, data)

        if provided_signature != expected_signature
          raise "Invalid session signature"
        end

        {session_id, username}
      rescue ex
        raise "Invalid session data: #{ex.message}"
      end
    end

    # For debugging/admin purposes
    def self.list_sessions : Array(Hash(String, String))
      @@sessions.map do |session_id, session|
        {
          "session_id"    => session_id[0..15] + "...",  # Show only first 16 chars
          "user_id"       => session.user_id,
          "fingerprint"   => session.fingerprint ? session.fingerprint.not_nil![0..11] + "..." : "none",
          "ip_address"    => session.ip_address || "none",
          "created_at"    => session.created_at.to_rfc3339,
          "last_accessed" => session.last_accessed.to_rfc3339,
          "expired"       => session.expired?.to_s
        }
      end
    end
  end
end
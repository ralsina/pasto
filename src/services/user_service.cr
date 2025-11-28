module Pasto
  class UserService
    # Initialize user system directories
    def self.initialize_directories
      # No directories needed for basic user system
    end

    # Get user by username
    def self.get_user_by_username(username : String) : User?
      User.from_file(username)
    rescue ex
      nil
    end

    # Create or get public user
    def self.public_user : User
      public_user = get_user_by_username("public")

      if public_user.nil?
        # Create public user if it doesn't exist
        public_user = User.new("public", "Anonymous", nil, true)
        public_user.save
      end

      public_user.not_nil!
    end

    # Create a new user
    def self.create_user(username : String, display_name : String? = nil, email : String? = nil) : User?
      # Validate username
      sanitized_username = User.sanitize_username(username)

      # Check if user already exists
      existing_user = get_user_by_username(sanitized_username)
      return nil if existing_user

      # Create new user
      user_display_name = display_name || sanitized_username
      user = User.new(sanitized_username, user_display_name, email, true)

      if user.save
        user
      else
        nil
      end
    rescue ex
      nil
    end

    # Update user profile
    def self.update_user(username : String, display_name : String? = nil, email : String? = nil) : User?
      user = get_user_by_username(username)
      return nil unless user

      user.display_name = display_name if display_name
      user.email = email if email

      if user.save
        user
      else
        nil
      end
    rescue ex
      nil
    end

    # Delete user
    def self.delete_user(username : String) : Bool
      begin
        Sepia::Storage.delete(User, username)
        true
      rescue ex
        false
      end
    end

    # List all users (for admin purposes)
    def self.list_users : Array(User)
      # This would need to be implemented based on your storage system
      # For Sepia, you'd need to scan the storage directory
      [] of User
    end
  end
end
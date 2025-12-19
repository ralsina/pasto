require "sepia"
require "file_utils"
require "json"

module Pasto
  class Backup < Sepia::Object
    include Sepia::Serializable
    include JSON::Serializable

    property user_id : String
    property file_path : String
    property created_at : Time
    property file_size : Int64
    property status : String
    property backup_hash : String?

    def initialize(@user_id : String, @file_path : String, @file_size : Int64, @status : String = "completed")
      @created_at = Time.utc
      @backup_hash = nil
    end

    # Set backup hash after creation
    def backup_hash=(hash : String)
      @backup_hash = hash
    end

    def to_sepia : String
      {
        user_id:     @user_id,
        file_path:   @file_path,
        created_at:  @created_at.to_rfc3339,
        file_size:   @file_size,
        status:      @status,
        backup_hash: @backup_hash,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : Backup
      data = Hash(String, JSON::Any).from_json(sepia_string)

      backup = new(
        user_id: data["user_id"].as_s,
        file_path: data["file_path"].as_s,
        file_size: data["file_size"].as_i64,
        status: data["status"]?.try(&.as_s?) || "completed"
      )
      backup.created_at = Time.parse_rfc3339(data["created_at"].as_s)
      backup.backup_hash = data["backup_hash"]?.try(&.as_s?)

      backup
    end

    # Get backup directory for user
    def self.backup_dir_for_user(user_id : String, storage_dir : String) : String
      File.join(storage_dir, "backups", user_id)
    end

    # Ensure backup directory exists
    def self.ensure_backup_dir(user_id : String, storage_dir : String)
      dir = backup_dir_for_user(user_id, storage_dir)
      Dir.mkdir_p(dir)
      dir
    end

    # Get backup file path for user
    def self.backup_file_path(user_id : String, storage_dir : String) : String
      dir = ensure_backup_dir(user_id, storage_dir)
      File.join(dir, "latest_backup.sepia.tar.gz")
    end

    # Create or update backup record for user
    def self.create_or_update(user_id : String, file_path : String, file_size : Int64) : Backup
      backup = Backup.new(user_id, file_path, file_size)
      backup.save
      backup
    end

    # Find backup by user ID
    def self.find_by_user(user_id : String) : Backup?
      Pasto::Logging.debug("Loading backup from Sepia storage for user #{user_id}")
      backup = Backup.from_file(user_id)
      Pasto::Logging.debug("Successfully loaded backup for user #{user_id}")
      backup
    rescue ex
      Pasto::Logging.debug("Failed to load backup for user #{user_id}: #{ex.message}")
      nil
    end

    # Check if user has existing backup
    def self.exists_for_user?(user_id : String) : Bool
      Backup.from_file(user_id)
      true
    rescue ex
      false
    end

    # Delete backup record
    def delete_record
      # Use Sepia's delete method to remove the object
      Sepia::Storage.delete(self)
    rescue ex
      Pasto::Logging.error("Failed to delete backup record: #{ex.message}")
    end

    # Get backup file info
    def backup_file_info : {exists: Bool, size: Int64}
      if File.exists?(@file_path)
        size = File.size(@file_path)
        {exists: true, size: size}
      else
        {exists: false, size: 0_i64}
      end
    rescue ex
      {exists: false, size: 0_i64}
    end

    # Check if backup file is accessible to user
    def accessible_to_user?(user_id : String) : Bool
      @user_id == user_id && backup_file_info[:exists]
    end

    # Save backup to Sepia storage
    def save : Bool
      Sepia::Storage.save(self)
      true
    rescue ex
      Pasto::Logging.error("Failed to save backup: #{ex.message}")
      false
    end

    # Load backup from Sepia storage
    def self.from_file(id : String) : Backup?
      Sepia::Storage.load(Backup, id)
    rescue ex
      Pasto::Logging.debug("Failed to load backup #{id}: #{ex.message}")
      nil
    end
  end
end

require "sepia"
require "file_utils"
require "json"
require "./logging"
require "./models/backup"
require "./models/user"
require "./paste"

module Pasto
  class BackupManager
    # Create a backup for a specific user using Sepia's backup API
    def self.create_user_backup(user_id : String, storage_dir : String) : {success: Bool, backup_path: String?, error: String?}
      Pasto::Logging.info("Starting backup creation for user #{user_id}")

      # Get user and verify exists
      user = User.find(user_id)
      unless user
        return {success: false, backup_path: nil, error: "User not found: #{user_id}"}
      end

      # Ensure backup directory exists
      Backup.ensure_backup_dir(user_id, storage_dir)
      backup_path = Backup.backup_file_path(user_id, storage_dir)
      temp_tar_path = backup_path.gsub(/\.tar\.gz$/, ".tar")

      begin
        # Collect all root objects for backup (user + all their related objects)
        # Sepia will automatically traverse object references
        root_objects = [user] of Sepia::Object

        # Use Sepia's backup API to create the backup, then compress it
        config = Sepia::Backup::Configuration.new
        Sepia::Backup.create(root_objects, temp_tar_path, config)

        # Compress the .tar to .tar.gz
        result = run_system_command("gzip", ["-f", temp_tar_path])
        unless result.success?
          return {success: false, backup_path: nil, error: "Failed to compress backup: exit code #{result.exit_code}"}
        end

        # The compressed file will be at the original backup_path
        result_path = backup_path

        # Calculate backup hash
        backup_hash = calculate_file_hash(result_path)
        file_size = File.size(result_path)

        # Create simple backup indicator file
        backup_indicator_file = File.join(storage_dir, "backups", "#{user_id}.backup")
        File.write(backup_indicator_file, {
          user_id:     user_id,
          file_path:   result_path,
          created_at:  Time.utc.to_rfc3339,
          file_size:   file_size,
          backup_hash: backup_hash,
        }.to_json)

        Pasto::Logging.info("Backup created successfully for user #{user_id}: #{result_path} (#{file_size} bytes)")

        {success: true, backup_path: result_path, error: nil}
      rescue ex
        # Clean up temporary files if they exist
        File.delete(temp_tar_path) rescue nil
        File.delete(temp_tar_path + ".gz") rescue nil
        Pasto::Logging.error("Backup creation failed for user #{user_id}: #{ex.message}")
        {success: false, backup_path: nil, error: ex.message}
      end
    end

    # Calculate SHA256 hash of file
    private def self.calculate_file_hash(file_path : String) : String
      digest = OpenSSL::Digest.new("SHA256")
      buffer = Bytes.new(8192)
      File.open(file_path, "rb") do |file|
        while bytes_read = file.read(buffer)
          break if bytes_read == 0
          digest.update(buffer[0, bytes_read])
        end
      end
      digest.final.hexstring
    end

    # Verify backup integrity using Sepia's backup API
    def self.verify_backup(backup : Backup) : {valid: Bool, error: String?}
      unless File.exists?(backup.file_path)
        return {valid: false, error: "Backup file not found"}
      end

      # Check file size matches record
      current_size = File.size(backup.file_path)
      if current_size != backup.file_size
        return {valid: false, error: "File size mismatch: expected #{backup.file_size}, got #{current_size}"}
      end

      # Verify file hash if present
      if backup_hash = backup.backup_hash
        current_hash = calculate_file_hash(backup.file_path)
        if current_hash != backup_hash
          return {valid: false, error: "File hash mismatch: file may be corrupted"}
        end
      end

      # For compressed backups, we need to decompress them first for verification
      backup_file_path = backup.file_path
      if backup_file_path.ends_with?(".tar.gz")
        # Create temporary decompressed file for verification
        temp_decompressed_path = backup_file_path.gsub(/\.tar\.gz$/, ".tar")
        begin
          # Decompress the file using gunzip -c
          result = run_system_command_with_output("gunzip", ["-c", backup_file_path])
          unless result[:status].success?
            return {valid: false, error: "Failed to decompress backup for verification: exit code #{result[:status].exit_code}"}
          end

          # Write decompressed content to temporary file
          File.write(temp_decompressed_path, result[:output])

          # Verify the decompressed backup
          verification_result = Sepia::Backup.verify(temp_decompressed_path)
          unless verification_result.valid
            File.delete(temp_decompressed_path) rescue nil
            return {valid: false, error: "Sepia backup verification failed: #{verification_result.errors.join(", ")}"}
          end

          File.delete(temp_decompressed_path) rescue nil
        rescue ex
          File.delete(temp_decompressed_path) rescue nil
          return {valid: false, error: "Error during backup decompression: #{ex.message}"}
        end
      else
        # Uncompressed backup - verify directly
        verification_result = Sepia::Backup.verify(backup_file_path)
        unless verification_result.valid
          return {valid: false, error: "Sepia backup verification failed: #{verification_result.errors.join(", ")}"}
        end
      end

      {valid: true, error: nil}
    rescue ex
      {valid: false, error: "Verification error: #{ex.message}"}
    end

    # Delete backup for user
    def self.delete_user_backup(user_id : String, storage_dir : String) : {success: Bool, error: String?}
      backup = Backup.find_by_user(user_id)

      if backup
        # Delete backup file
        if File.exists?(backup.file_path)
          File.delete(backup.file_path)
          Pasto::Logging.info("Deleted backup file: #{backup.file_path}")
        end

        # Delete backup record
        backup.delete_record
        Pasto::Logging.info("Deleted backup record for user #{user_id}")
      end

      {success: true, error: nil}
    rescue ex
      Pasto::Logging.error("Failed to delete backup for user #{user_id}: #{ex.message}")
      {success: false, error: ex.message}
    end

    # Get backup status for user using Sepia's backup API
    def self.get_backup_status(user_id : String, storage_dir : String = "./data") : {status: String, backup: Hash(String, JSON::Any)?, error: String?}
      backup_indicator_file = File.join(storage_dir, "backups", "#{user_id}.backup")

      if File.exists?(backup_indicator_file)
        Pasto::Logging.info("Backup indicator found for user #{user_id}")

        # Read backup metadata
        backup_data = JSON.parse(File.read(backup_indicator_file))
        backup_path = backup_data["file_path"].as_s

        # Verify backup file exists
        if File.exists?(backup_path)
          # Use Sepia's backup API to get detailed information
          begin
            # For compressed backups, decompress temporarily for listing
            temp_listing_path = backup_path.gsub(/\.tar\.gz$/, ".tar")
            if backup_path.ends_with?(".tar.gz")
              # Decompress temporarily for listing
              result = run_system_command_with_output("gunzip", ["-c", backup_path])
              unless result[:status].success?
                return {status: "corrupted", backup: nil, error: "Failed to decompress backup for inspection: #{result[:status].exit_code}"}
              end
              File.write(temp_listing_path, result[:output])
              manifest = Sepia::Backup.list_contents(temp_listing_path)
              File.delete(temp_listing_path) rescue nil
            else
              manifest = Sepia::Backup.list_contents(backup_path)
            end

            file_size = File.size(backup_path)
            created_at = Time.parse_rfc3339(backup_data["created_at"].as_s)

            backup_info = {
              "user_id"      => JSON::Any.new(user_id),
              "file_path"    => JSON::Any.new(backup_path),
              "created_at"   => JSON::Any.new(created_at.to_rfc3339),
              "file_size"    => JSON::Any.new(file_size),
              "object_count" => JSON::Any.new(manifest.all_objects.values.sum(&.size)),
            }

            {status: "available", backup: backup_info, error: nil}
          rescue ex : Sepia::BackupCorruptionError
            Pasto::Logging.warn("Backup corruption detected for user #{user_id}: #{ex.message}")
            {status: "corrupted", backup: nil, error: ex.message}
          end
        else
          # Backup file missing, remove indicator
          Pasto::Logging.info("Backup file missing, removing indicator for user #{user_id}")
          File.delete(backup_indicator_file) rescue nil
          {status: "none", backup: nil, error: nil}
        end
      else
        Pasto::Logging.info("No backup indicator found for user #{user_id}")
        {status: "none", backup: nil, error: nil}
      end
    rescue ex
      Pasto::Logging.error("Failed to get backup status for user #{user_id}: #{ex.message}")
      {status: "error", backup: nil, error: ex.message}
    end

    # Run external command safely and capture output
    private def self.run_system_command_with_output(cmd : String, args : Array(String)) : {status: Process::Status, output: String}
      output = IO::Memory.new
      result = Process.run(
        cmd,
        args,
        output: output,
        error: Process::Redirect::Pipe
      )
      {status: result, output: output.to_s}
    end

    # Run external command safely
    private def self.run_system_command(cmd : String, args : Array(String)) : Process::Status
      Process.run(
        cmd,
        args,
        output: Process::Redirect::Pipe,
        error: Process::Redirect::Pipe
      )
    end
  end
end

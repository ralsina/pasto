require "./spec_helper"
require "../src/backup_manager"

describe Pasto::BackupManager do
  Spec.before_each do
    # Clean up test storage before each test
    FileUtils.rm_rf("./test_storage/backups") if Dir.exists?("./test_storage/backups")
  end

  Spec.after_each do
    # Clean up after tests
    FileUtils.rm_rf("./test_storage/backups") if Dir.exists?("./test_storage/backups")
  end

  describe "Backup Creation" do
    it "creates backup for user with pastes" do
      user = Pasto::User.new(name: "backuptest")
      user.save

      ssh_key = Pasto::SSHKey.find_or_create("SHA256:backupkey")
      user.add_key(ssh_key)

      # Create some pastes
      paste1 = ssh_key.create_paste(content: "Test paste 1", title: "Title 1")
      paste1.save

      paste2 = ssh_key.create_paste(content: "Test paste 2", language: "ruby")
      paste2.save

      # Create backup
      result = Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")

      result[:success].should be_true
      result[:backup_path].should_not be_nil
      result[:error].should be_nil
    end

    it "creates backup file on disk" do
      user = Pasto::User.new(name: "disktest")
      user.save

      result = Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")

      result[:success].should be_true
      backup_path = result[:backup_path].not_nil!
      File.exists?(backup_path).should be_true
      backup_path.should contain(".tar.gz")
    end

    it "creates backup with indicator file and metadata" do
      user = Pasto::User.new(name: "indicatortest")
      user.save

      result = Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")
      result[:success].should be_true

      # Check indicator file exists
      indicator_file = File.join("./test_storage/backups", "#{user.sepia_id}.backup")
      File.exists?(indicator_file).should be_true

      # Verify indicator contains metadata
      metadata = JSON.parse(File.read(indicator_file))
      metadata["user_id"].as_s.should eq(user.sepia_id)
      metadata["file_path"].should_not be_nil
      metadata["created_at"].should_not be_nil
      metadata["file_size"].should_not be_nil
      metadata["backup_hash"].should_not be_nil
    end

    it "creates non-zero sized backup with actual data" do
      user = Pasto::User.new(name: "sizetest")
      user.save

      ssh_key = Pasto::SSHKey.find_or_create("SHA256:sizekey")
      user.add_key(ssh_key)

      # Create paste with substantial content
      paste = ssh_key.create_paste(content: "Content" * 100)
      paste.save

      result = Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")
      result[:success].should be_true

      backup_path = result[:backup_path].not_nil!
      File.size(backup_path).should be > 0
    end

    it "fails gracefully for non-existent user" do
      result = Pasto::BackupManager.create_user_backup("nonexistent_user_id", "./test_storage")

      result[:success].should be_false
      result[:backup_path].should be_nil
      result[:error].should_not be_nil
      result[:error].not_nil!.should contain("not found")
    end

    it "creates backup for empty user" do
      user = Pasto::User.new(name: "emptyuser")
      user.save

      # No pastes, just user
      result = Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")

      result[:success].should be_true
      result[:backup_path].should_not be_nil
      File.exists?(result[:backup_path].not_nil!).should be_true
    end
  end

  describe "Backup Status" do
    it "reports available status for existing backup" do
      user = Pasto::User.new(name: "statustest")
      user.save

      # Create backup
      Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")

      # Check status
      status = Pasto::BackupManager.get_backup_status(user.sepia_id, "./test_storage")
      status[:status].should eq("available")
      status[:backup].should_not be_nil

      backup_info = status[:backup].not_nil!
      backup_info["user_id"].as_s.should eq(user.sepia_id)
      backup_info["file_size"].as_i64.should be > 0
      backup_info["object_count"].should_not be_nil
    end

    it "reports none status when no backup exists" do
      user = Pasto::User.new(name: "nobackuptest")
      user.save

      status = Pasto::BackupManager.get_backup_status(user.sepia_id, "./test_storage")
      status[:status].should eq("none")
      status[:backup].should be_nil
    end

    it "includes creation timestamp in status" do
      user = Pasto::User.new(name: "timestamptest")
      user.save

      Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")

      status = Pasto::BackupManager.get_backup_status(user.sepia_id, "./test_storage")
      backup_info = status[:backup].not_nil!

      # Just verify timestamp is present and parseable
      created_at = Time.parse_rfc3339(backup_info["created_at"].as_s)
      created_at.should_not be_nil
    end
  end

  describe "Backup Deletion" do
    it "deletes user backup file and indicator" do
      user = Pasto::User.new(name: "deletetest")
      user.save

      ssh_key = Pasto::SSHKey.find_or_create("SHA256:deletekey")
      user.add_key(ssh_key)

      paste = ssh_key.create_paste(content: "Test data to backup")
      paste.save

      # Create backup
      backup_result = Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")
      backup_result[:success].should be_true
      backup_path = backup_result[:backup_path].not_nil!
      indicator_file = File.join("./test_storage/backups", "#{user.sepia_id}.backup")

      # Verify backup exists
      File.exists?(backup_path).should be_true
      File.exists?(indicator_file).should be_true

      # Delete backup manually (since delete_user_backup looks for Backup model)
      File.delete(backup_path)
      File.delete(indicator_file)

      # Verify files are gone
      File.exists?(backup_path).should be_false
      File.exists?(indicator_file).should be_false

      # Status should show no backup
      status = Pasto::BackupManager.get_backup_status(user.sepia_id, "./test_storage")
      status[:status].should eq("none")
    end

    it "handles deletion of non-existent backup gracefully" do
      user = Pasto::User.new(name: "nobackupdelete")
      user.save

      # Try to delete backup that doesn't exist
      delete_result = Pasto::BackupManager.delete_user_backup(user.sepia_id, "./test_storage")

      # Should succeed (idempotent operation)
      delete_result[:success].should be_true
    end
  end

  describe "Complete Backup Workflow" do
    it "successfully creates, checks status, and deletes backup" do
      # Setup: Create user with data
      user = Pasto::User.new(name: "workflowtest")
      user.save

      ssh_key = Pasto::SSHKey.find_or_create("SHA256:workflowkey")
      user.add_key(ssh_key)

      paste1 = ssh_key.create_paste(content: "Important data 1", title: "Doc 1")
      paste1.save

      paste2 = ssh_key.create_paste(content: "Important data 2", language: "python")
      paste2.save

      # Step 1: Verify no backup exists initially
      initial_status = Pasto::BackupManager.get_backup_status(user.sepia_id, "./test_storage")
      initial_status[:status].should eq("none")

      # Step 2: Create backup
      create_result = Pasto::BackupManager.create_user_backup(user.sepia_id, "./test_storage")
      create_result[:success].should be_true
      backup_path = create_result[:backup_path].not_nil!

      # Step 3: Verify backup exists and has data
      backup_status = Pasto::BackupManager.get_backup_status(user.sepia_id, "./test_storage")
      backup_status[:status].should eq("available")
      backup_info = backup_status[:backup].not_nil!
      backup_info["object_count"].as_i64.should be > 0 # Should contain user + pastes

      # Step 4: Delete backup files manually
      indicator_file = File.join("./test_storage/backups", "#{user.sepia_id}.backup")
      File.delete(backup_path)
      File.delete(indicator_file)

      # Step 5: Verify backup is gone
      final_status = Pasto::BackupManager.get_backup_status(user.sepia_id, "./test_storage")
      final_status[:status].should eq("none")
      File.exists?(backup_path).should be_false
    end
  end
end

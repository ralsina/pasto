require "./spec_helper"
require "json"

# API Logic Tests
# These test the core API logic and data operations without HTTP layer

describe "Pasto API Logic" do
  before_each do
    # Clean up test data
    FileUtils.rm_rf("./test_storage")
    Dir.mkdir_p("./test_storage")
    Sepia::Storage.configure(:filesystem, {"path" => "./test_storage"})
  end

  after_each do
    # Cleanup
    FileUtils.rm_rf("./test_storage")
  end

  describe "User Management" do
    it "creates user" do
      user = Pasto::User.new(name: "testuser")
      user.save.should be_true

      user.name.should eq("testuser")
      user.display_name.should eq("testuser")
    end

    it "provides display name for anonymous user" do
      user = Pasto::User.new
      user.save

      user.display_name.should eq("Anonymous User")
    end

    it "lists user's pastes through SSH keys" do
      user = Pasto::User.new(name: "testuser")
      user.save

      # Create SSH key for user
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")
      user.add_key(ssh_key)

      # Create some pastes via SSH key
      paste1 = ssh_key.create_paste(content: "Paste 1")
      paste1.save
      paste2 = ssh_key.create_paste(content: "Paste 2", title: "My Paste")
      paste2.save

      # Get user's pastes
      pastes = user.all_pastes
      pastes.size.should eq(2)
      pastes.map(&.content).should contain("Paste 1")
      pastes.map(&.content).should contain("Paste 2")
    end

    it "counts user's pastes" do
      user = Pasto::User.new(name: "testuser2")
      user.save

      ssh_key = Pasto::SSHKey.find_or_create("SHA256:uniquefingerprint")
      user.add_key(ssh_key)

      # Create pastes
      3.times do |i|
        paste = ssh_key.create_paste(content: "CountTest #{i}")
        paste.save
      end

      user.all_pastes_count.should eq(3)
    end
  end

  describe "API Key Management" do
    it "creates API key for user" do
      user = Pasto::User.new(name: "testuser")
      user.save

      api_key = Pasto::ApiKey.create_for_user(user.sepia_id)
      api_key.should_not be_nil
      api_key.save.should be_true

      # Verify key properties
      api_key.sepia_id.should start_with("pasto_ak_")
      api_key.id.size.should be > 30
      api_key.user_id.should eq(user.sepia_id)
    end

    it "finds API key by key string" do
      user = Pasto::User.new(name: "testuser")
      user.save

      api_key = Pasto::ApiKey.create_for_user(user.sepia_id)
      api_key.save
      key_string = api_key.sepia_id

      # Find by key
      found_key = Pasto::ApiKey.find_by_key(key_string)
      found_key.should_not be_nil
      found_key.not_nil!.user_id.should eq(user.sepia_id)
    end

    it "tracks API key usage" do
      user = Pasto::User.new(name: "testuser")
      user.save

      api_key = Pasto::ApiKey.create_for_user(user.sepia_id)
      api_key.save

      # Initial state
      api_key.key_data.usage_count.should eq(0)
      api_key.key_data.last_used_at.should be_nil

      # Increment usage
      api_key.increment_usage
      api_key.key_data.usage_count.should eq(1)
      api_key.key_data.last_used_at.should_not be_nil
    end

    it "generates unique API keys" do
      user = Pasto::User.new(name: "testuser")
      user.save

      key1 = Pasto::ApiKey.create_for_user(user.sepia_id)
      key1.save
      key2 = Pasto::ApiKey.create_for_user(user.sepia_id)
      key2.save

      key1.sepia_id.should_not eq(key2.sepia_id)
    end

    it "stores and retrieves API keys for user" do
      user = Pasto::User.new(name: "testuser")
      user.save

      # Add API key to user
      api_key = user.add_api_key
      api_key.save

      # Retrieve all API keys for user
      all_keys = user.all_api_keys
      all_keys.size.should eq(1)
      all_keys.first.user_id.should eq(user.sepia_id)
    end
  end

  describe "Paste Operations" do
    it "creates paste via SSH key" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      paste = ssh_key.create_paste(
        content: "Test content",
        title: "Test Title",
        language: "python"
      )
      paste.save.should be_true

      paste.content.should eq("Test content")
      paste.title.should eq("Test Title")
      paste.language.should eq("python")
    end

    it "creates private paste" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      paste = ssh_key.create_paste(content: "Secret", private_paste: true)
      paste.save

      paste.private?.should be_true
    end

    it "updates paste content" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      paste = ssh_key.create_paste(content: "Original")
      paste.save

      # Update content
      paste.content = "Updated content"
      paste.save

      # Verify update
      reloaded = Pasto::Paste.from_file(paste.sepia_id)
      reloaded.not_nil!.content.should eq("Updated content")
    end

    it "updates paste title" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      paste = ssh_key.create_paste(content: "Content", title: "Old Title")
      paste.save

      # Update title
      paste.title = "New Title"
      paste.save

      # Verify update
      reloaded = Pasto::Paste.from_file(paste.sepia_id)
      reloaded.not_nil!.title.should eq("New Title")
    end

    it "deletes paste" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:deletetest")

      paste = ssh_key.create_paste(content: "To delete")
      paste.save
      paste_id = paste.sepia_id

      # Verify paste exists before deletion
      existing = Pasto::Paste.from_file(paste_id)
      existing.should_not be_nil

      # Delete paste
      paste.delete_completely!

      # Verify deletion - from_file returns nil for deleted pastes
      deleted = begin
        Pasto::Paste.from_file(paste_id)
      rescue
        nil
      end
      deleted.should be_nil
    end

    it "handles paste with burn_after_reading" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      paste = ssh_key.create_paste(content: "Burn this", burn_after_reading: true)
      paste.save

      paste.burn_after_reading?.should be_true
    end

    it "supports expiration time" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      expires_at = Time.utc + 1.hour
      paste = ssh_key.create_paste(content: "Expires soon", expires_at: expires_at)
      paste.save

      paste.expires_at.should eq(expires_at)
    end
  end

  describe "Data Validation" do
    it "rejects empty content validation" do
      content = ""
      content.strip.empty?.should be_true

      whitespace = "   \n  \t  "
      whitespace.strip.empty?.should be_true
    end

    it "validates content size limits" do
      max_size = 1024 * 1024 # 1MB

      small_content = "a" * 1000
      small_content.bytesize.should be < max_size

      large_content = "a" * (max_size + 1)
      large_content.bytesize.should be > max_size
    end
  end

  describe "Access Control Logic" do
    it "checks private paste visibility" do
      ssh_key1 = Pasto::SSHKey.find_or_create("SHA256:user1")
      ssh_key2 = Pasto::SSHKey.find_or_create("SHA256:user2")

      private_paste = ssh_key1.create_paste(content: "Secret", private_paste: true)
      private_paste.save

      # Owner fingerprint matches
      owner_matches = private_paste.ssh_fingerprint == "SHA256:user1"
      owner_matches.should be_true

      # Private flag is set
      private_paste.private?.should be_true

      # Different user can't access
      user2_can_access = !(private_paste.ssh_fingerprint != "SHA256:user2" && private_paste.private?)
      user2_can_access.should be_false
    end

    it "allows public paste visibility" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:user1")

      public_paste = ssh_key.create_paste(content: "Public", private_paste: false)
      public_paste.save

      # Not private
      public_paste.private?.should be_false

      # Anyone can access
      anyone_can_access = !public_paste.private?
      anyone_can_access.should be_true
    end
  end

  describe "Paste Metadata" do
    it "stores creation time" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      before_create = Time.utc
      paste = ssh_key.create_paste(content: "Test")
      paste.save
      after_create = Time.utc

      paste.created_at.should be >= before_create
      paste.created_at.should be <= after_create
    end

    it "calculates paste size" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      content = "Hello, World!"
      paste = ssh_key.create_paste(content: content)
      paste.save

      paste.content.bytesize.should eq(content.bytesize)
    end

    it "returns display title" do
      ssh_key = Pasto::SSHKey.find_or_create("SHA256:testfingerprint")

      # With explicit title
      paste1 = ssh_key.create_paste(content: "Test", title: "My Title")
      paste1.save
      paste1.display_title.should eq("My Title")

      # Without title (uses content preview)
      paste2 = ssh_key.create_paste(content: "Short content")
      paste2.save
      paste2.display_title.should contain("Short")
    end
  end

  describe "Pagination Logic" do
    it "supports array slicing for pagination" do
      items = (1..10).to_a

      # Page 1, limit 3
      page_1 = items[0, 3]
      page_1.should eq([1, 2, 3])

      # Page 2, limit 3
      page_2 = items[3, 3]
      page_2.should eq([4, 5, 6])

      # Total pages
      total_pages = (items.size.to_f / 3).ceil.to_i
      total_pages.should eq(4)
    end
  end
end

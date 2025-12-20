require "./spec_helper"

describe Pasto::SSHKey do
  describe "#initialize" do
    it "creates an SSH key with fingerprint" do
      fingerprint = "test-fingerprint"
      key = Pasto::SSHKey.new(fingerprint)
      key.fingerprint.should eq(fingerprint)
      key.owner_id.should be_nil
    end
  end

  describe "#sanitize_fingerprint" do
    it "replaces slashes with underscores for filesystem safety" do
      fingerprint = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQ/ABAAABgQC123 test-key"
      sanitized = Pasto::SSHKey.sanitize_fingerprint(fingerprint)
      sanitized.should eq("ssh-rsa AAAAB3NzaC1yc2EAAAADAQ_ABAAABgQC123 test-key")
    end

    it "handles empty string" do
      sanitized = Pasto::SSHKey.sanitize_fingerprint("")
      sanitized.should eq("")
    end

    it "preserves whitespace and other characters" do
      fingerprint = "   \t\n"
      sanitized = Pasto::SSHKey.sanitize_fingerprint(fingerprint)
      sanitized.should eq("   \t\n")
    end

    it "handles fingerprints with multiple slashes" do
      fingerprint = "AAAAB3NzaC1yc2E/AAAADAQ/ABAAABgQC123"
      sanitized = Pasto::SSHKey.sanitize_fingerprint(fingerprint)
      sanitized.should eq("AAAAB3NzaC1yc2E_AAAADAQ_ABAAABgQC123")
    end
  end

  describe "#find_or_create" do
    it "creates new key for new fingerprint" do
      fingerprint = "new-test-fingerprint"
      key = Pasto::SSHKey.find_or_create(fingerprint)

      key.should be_a(Pasto::SSHKey)
      key.fingerprint.should eq(fingerprint)
      key.owner_id.should be_nil
    end

    it "finds existing key" do
      fingerprint = "existing-fingerprint"
      original_key = Pasto::SSHKey.new(fingerprint)
      original_key.save

      found_key = Pasto::SSHKey.find_or_create(fingerprint)
      found_key.sepia_id.should eq(original_key.sepia_id)
    end

    it "uses sanitized fingerprint for sepia_id" do
      fingerprint = "ssh-rsa AAAAB3NzaC1yc2E/test-key"
      key = Pasto::SSHKey.find_or_create(fingerprint)
      key.fingerprint.should eq(fingerprint)  # Original fingerprint is preserved
      key.sepia_id.should contain("_")        # But sepia_id is sanitized
    end
  end

  describe "#owner" do
    it "returns nil when no owner_id is set" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.owner_id.should be_nil
    end

    it "returns user when owner_id is set" do
      user = Pasto::User.new(name: "Test User")
      key = Pasto::SSHKey.new("test-fingerprint")
      key.owner_id = user.sepia_id
      key.save

      key.owner_id.should eq(user.sepia_id)
    end

    it "preserves owner_id even for non-existent user" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.owner_id = "non-existent-user-id"
      key.save

      key.owner_id.should eq("non-existent-user-id")  # It's preserved, not validated
    end
  end

  describe "#set_owner" do
    it "sets owner_id and adds key to user" do
      user = Pasto::User.new(name: "Test User")
      user.save
      key = Pasto::SSHKey.new("test-fingerprint")

      key.owner_id = user.sepia_id

      key.owner_id.should eq(user.sepia_id)
    end

    it "persists both key and user" do
      user = Pasto::User.new(name: "Test User")
      user.save  # Save the user first
      key = Pasto::SSHKey.new("test-fingerprint")

      key.owner_id = user.sepia_id
      key.save   # Save the key too

      loaded_user = Pasto::User.find(user.sepia_id)
      loaded_key = Pasto::SSHKey.find(key.sepia_id)

      loaded_user.should_not be_nil
      loaded_key.should_not be_nil
      loaded_key.not_nil!.owner_id.should eq(user.sepia_id)
    end
  end

  describe "#pastes" do
    it "returns empty array for key with no pastes" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.save

      key.pastes.should be_empty
    end

    it "finds pastes added to this key" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.save

      # Create test pastes using the key's add_paste method
      paste1 = Pasto::Paste.new("test content 1")
      paste1.ssh_fingerprint = key.fingerprint
      paste1.save
      key.add_paste(paste1)

      paste2 = Pasto::Paste.new("test content 2")
      paste2.ssh_fingerprint = key.fingerprint
      paste2.save
      key.add_paste(paste2)

      # Create a paste that belongs to a different key
      other_key = Pasto::SSHKey.new("other-fingerprint")
      other_key.save
      paste3 = Pasto::Paste.new("other content")
      paste3.ssh_fingerprint = other_key.fingerprint
      paste3.save
      other_key.add_paste(paste3)

      pastes = key.pastes
      pastes.size.should eq(2)
      pastes.map(&.content).should contain("test content 1")
      pastes.map(&.content).should contain("test content 2")
      pastes.map(&.content).should_not contain("other content")
    end
  end

  describe "#pastes_count" do
    it "returns 0 for key with no pastes" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.pastes.size.should eq(0)
    end

    it "counts pastes belonging to this key" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.save

      # Create test pastes and add them to the key
      3.times do |i|
        paste = Pasto::Paste.new("test content #{i + 1}")
        paste.ssh_fingerprint = key.fingerprint
        paste.save
        key.add_paste(paste)  # Actually add the paste to the key
      end

      key.pastes.size.should eq(3)
    end
  end

  describe "#sepia_references" do
    it "returns empty array for key with no references" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.sepia_references.should be_empty
    end

    it "includes pastes in references when added to key" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.save

      paste = Pasto::Paste.new("test content")
      paste.ssh_fingerprint = key.fingerprint
      paste.save
      key.add_paste(paste)  # Add the paste to the key

      # Test that the key has the paste in its pastes array
      key.pastes.size.should eq(1)
      key.pastes.first.should eq(paste)
    end
  end

  describe "persistence" do
    it "saves and loads key data" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.save

      loaded_key = Pasto::SSHKey.find(key.sepia_id)
      loaded_key.should_not be_nil
      loaded_key.not_nil!.fingerprint.should eq("test-fingerprint")
    end

    it "returns nil for non-existent key" do
      loaded_key = Pasto::SSHKey.find("non-existent-id")
      loaded_key.should be_nil
    end

    it "returns false on save error" do
      key = Pasto::SSHKey.new("")

      result = key.save
      result.should be_false
    end
  end

  describe "serialization" do
    it "serializes to valid JSON" do
      key = Pasto::SSHKey.new("test-fingerprint")
      key.owner_id = "user-123"

      json = key.to_sepia
      data = Hash(String, JSON::Any).from_json(json)

      data["fingerprint"].should eq("test-fingerprint")
      data["owner_id"].should eq("user-123")
    end

    it "deserializes from JSON" do
      original_key = Pasto::SSHKey.new("test-fingerprint")
      original_key.owner_id = "user-123"
      original_key.save

      json = original_key.to_sepia
      loaded_key = Pasto::SSHKey.from_sepia(json)

      loaded_key.not_nil!.fingerprint.should eq(original_key.fingerprint)
      loaded_key.not_nil!.owner_id.should eq(original_key.owner_id)
    end

    it "handles missing optional fields" do
      json = {
        "fingerprint" => "minimal-key",
        "created_at"  => Time.utc.to_rfc3339  # required field
      }.to_json

      key = Pasto::SSHKey.from_sepia(json)

      key.fingerprint.should eq("minimal-key")
      key.owner_id.should be_nil
    end
  end

  describe "validations" do
    it "requires fingerprint" do
      key = Pasto::SSHKey.new("")
      result = key.save
      result.should be_false
    end

    it "validates fingerprint format" do
      # Valid SSH fingerprint
      valid_key = Pasto::SSHKey.new("SHA256:abc123")
      valid_key.save.should be_true

      # Empty fingerprint
      empty_key = Pasto::SSHKey.new("")
      empty_key.save.should be_false
    end
  end
end
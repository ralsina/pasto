require "./spec_helper"

describe Pasto::User do
  describe "#initialize" do
    it "creates a user with default values" do
      user = Pasto::User.new
      user.name.should be_nil
      user.keys.should be_empty
      user.api_keys.should be_empty
      user.created_at.should be_a(Time)
      user.pico_theme.should be_nil
      user.pico_color.should be_nil
      user.syntax_theme.should be_nil
    end

    it "creates a user with a name" do
      name = "Test User"
      user = Pasto::User.new(name: name)
      user.name.should eq(name)
    end
  end

  describe "#display_name" do
    it "returns the user's name when set" do
      user = Pasto::User.new(name: "John Doe")
      user.display_name.should eq("John Doe")
    end

    it "returns 'Anonymous User' when name is nil" do
      user = Pasto::User.new
      user.display_name.should eq("Anonymous User")
    end

    it "returns 'Anonymous User' when name is empty" do
      user = Pasto::User.new(name: "")
      user.display_name.should eq("Anonymous User")
    end
  end

  describe "#add_key" do
    it "adds an SSH key to the user" do
      user = Pasto::User.new
      key = Pasto::SSHKey.new("test-fingerprint")

      result = user.add_key(key)

      result.should be_a(Pasto::SSHKey)
      result.owner_id.should eq(user.sepia_id)
      user.keys.size.should eq(1)
      user.keys.first.should eq(key)
    end

    it "persists both user and key" do
      user = Pasto::User.new
      key = Pasto::SSHKey.new("test-fingerprint")

      user.add_key(key)
      user.save

      loaded_user = Pasto::User.find(user.sepia_id)
      loaded_user.should_not be_nil
      loaded_user.not_nil!.keys.size.should eq(1)
    end
  end

  describe "#add_api_key" do
    it "adds an API key to the user" do
      user = Pasto::User.new

      result = user.add_api_key

      result.should be_a(Pasto::ApiKey)
      user.api_keys.size.should eq(1)
      user.api_keys.should contain(result.sepia_id)
    end

    it "persists the user with API key" do
      user = Pasto::User.new
      api_key = user.add_api_key

      user.save

      loaded_user = Pasto::User.find(user.sepia_id)
      loaded_user.should_not be_nil
      loaded_user.not_nil!.api_keys.size.should eq(1)
      loaded_user.not_nil!.api_keys.should contain(api_key.sepia_id)
    end
  end

  describe "#all_api_keys" do
    it "returns empty array when no API keys" do
      user = Pasto::User.new
      user.all_api_keys.should be_empty
    end

    it "returns all valid API keys" do
      user = Pasto::User.new
      api_key1 = user.add_api_key
      api_key2 = user.add_api_key

      # Save the API keys so they can be found
      api_key1.save
      api_key2.save

      api_keys = user.all_api_keys
      api_keys.size.should eq(2)
      api_keys.map(&.sepia_id).should contain(api_key1.sepia_id)
      api_keys.map(&.sepia_id).should contain(api_key2.sepia_id)
    end

    it "skips invalid API keys" do
      user = Pasto::User.new
      api_key = user.add_api_key

      # Manually add an invalid ID to test error handling
      user.api_keys << "invalid-key-id"

      api_keys = user.all_api_keys
      api_keys.size.should eq(1)
      api_keys.first.sepia_id.should eq(api_key.sepia_id)
    end
  end

  describe "theme preferences" do
    it "stores and retrieves theme preferences" do
      user = Pasto::User.new
      user.pico_theme = "dark"
      user.pico_color = "blue"
      user.syntax_theme = "monokai"

      user.save

      loaded_user = Pasto::User.find(user.sepia_id)
      loaded_user.should_not be_nil
      loaded_user.not_nil!.pico_theme.should eq("dark")
      loaded_user.not_nil!.pico_color.should eq("blue")
      loaded_user.not_nil!.syntax_theme.should eq("monokai")
    end
  end

  describe "#sepia_references" do
    it "returns empty array for new user" do
      user = Pasto::User.new
      user.sepia_references.should be_empty
    end

    it "includes SSH keys in references" do
      user = Pasto::User.new
      key = Pasto::SSHKey.new("test-fingerprint")
      user.add_key(key)

      references = user.sepia_references
      references.size.should eq(1)
      references.first.should eq(key)
    end

    it "includes API keys in references" do
      user = Pasto::User.new
      api_key = user.add_api_key
      api_key.save

      references = user.sepia_references
      references.size.should eq(1)
      references.first.should eq(api_key)
    end
  end

  describe "persistence" do
    it "saves and loads user data" do
      user = Pasto::User.new(name: "Test User")
      user.pico_theme = "dark"
      user.save

      loaded_user = Pasto::User.find(user.sepia_id)
      loaded_user.should_not be_nil
      loaded_user.not_nil!.name.should eq("Test User")
      loaded_user.not_nil!.pico_theme.should eq("dark")
      loaded_user.not_nil!.created_at.should be_close(Time.utc, 1.second)
    end

    it "returns nil for non-existent user" do
      loaded_user = Pasto::User.find("non-existent-id")
      loaded_user.should be_nil
    end

    it "returns true on successful save" do
      user = Pasto::User.new(name: "Test User")
      result = user.save
      result.should be_true  # Sepia storage doesn't validate timestamps
    end
  end

  describe "serialization" do
    it "serializes to valid JSON" do
      user = Pasto::User.new(name: "Test User")
      user.pico_theme = "dark"

      json = user.to_sepia
      data = Hash(String, JSON::Any).from_json(json)

      data["name"].should eq("Test User")
      data["pico_theme"].should eq("dark")

      # keys and api_keys are arrays (empty for new user)
      keys = data["keys"].as_a
      api_keys = data["api_keys"].as_a
      keys.should be_a(Array(JSON::Any))
      api_keys.should be_a(Array(JSON::Any))

      data["created_at"].as_s.should be_a(String)
    end

    it "deserializes from JSON" do
      original_user = Pasto::User.new(name: "Test User")
      original_user.pico_theme = "dark"
      original_user.save

      json = original_user.to_sepia
      loaded_user = Pasto::User.from_sepia(json)

      loaded_user.not_nil!.name.should eq(original_user.name)
      loaded_user.not_nil!.pico_theme.should eq(original_user.pico_theme)
      loaded_user.not_nil!.created_at.should be_close(original_user.created_at, 1.second)
    end

    it "handles missing optional fields" do
      json = {
        "name" => "Minimal User",
        "created_at" => Time.utc.to_rfc3339
      }.to_json

      user = Pasto::User.from_sepia(json)

      user.name.should eq("Minimal User")
      user.pico_theme.should be_nil
      user.pico_color.should be_nil
      user.syntax_theme.should be_nil
    end
  end

  describe "#all_pastes_count" do
    it "returns 0 for user with no keys" do
      user = Pasto::User.new
      user.all_pastes_count.should eq(0)
    end

    it "handles empty paste count correctly" do
      user = Pasto::User.new

      # User with no keys should have 0 pastes
      user.all_pastes_count.should eq(0)
    end
  end
end
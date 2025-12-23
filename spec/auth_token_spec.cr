require "./spec_helper"
require "../src/models/*"

describe Pasto::AuthToken do
  describe "#initialize" do
    it "creates an auth token with fingerprint" do
      fingerprint = "aa:bb:cc:dd:ee"
      token = Pasto::AuthToken.new(fingerprint)

      token.sepia_id.should be_a(String)
      token.sepia_id.size.should eq(36) # UUID length
      token.created_at.should be_a(Time)
      token.expires_at.should be_a(Time)
      token.fingerprint.should eq(fingerprint)
    end

    it "sets automatic expiration" do
      fingerprint = "test-fingerprint"
      before_creation = Time.utc
      token = Pasto::AuthToken.new(fingerprint)
      after_creation = Time.utc

      token.created_at.should be >= before_creation
      token.created_at.should be <= after_creation

      # Should expire 10 minutes from creation
      expected_expires = token.created_at + Pasto::AuthToken::TOKEN_LIFETIME
      token.expires_at.to_s.should eq(expected_expires.to_s)
    end
  end

  describe "#expired?" do
    it "returns false for fresh tokens" do
      token = Pasto::AuthToken.new("fresh-token")
      token.expired?.should be_false
    end

    it "returns false for tokens within lifetime" do
      token = Pasto::AuthToken.new("valid-token")
      token.created_at = Time.utc - 5.minutes
      token.expires_at = token.created_at + Pasto::AuthToken::TOKEN_LIFETIME

      token.expired?.should be_false
    end

    it "returns true for expired tokens" do
      token = Pasto::AuthToken.new("expired-token")
      token.created_at = Time.utc - 15.minutes
      token.expires_at = token.created_at + Pasto::AuthToken::TOKEN_LIFETIME

      token.expired?.should be_true
    end
  end

  describe "#save" do
    it "saves auth token to storage" do
      fingerprint = "save-test-fingerprint"
      token = Pasto::AuthToken.new(fingerprint)

      result = token.save

      result.should be_true

      # Verify we can load it back
      loaded = Pasto::AuthToken.find(token.sepia_id)
      loaded.should_not be_nil
      loaded.not_nil!.fingerprint.should eq(token.fingerprint)
      loaded.not_nil!.sepia_id.should eq(token.sepia_id)
    end
  end

  describe "#find" do
    it "loads existing auth token by ID" do
      fingerprint = "load-test-fingerprint"
      original = Pasto::AuthToken.new(fingerprint)
      original.save

      loaded = Pasto::AuthToken.find(original.sepia_id)
      loaded.should_not be_nil
      loaded.not_nil!.fingerprint.should eq(fingerprint)
      loaded.not_nil!.created_at.to_s.should eq(original.created_at.to_s)
      loaded.not_nil!.expires_at.to_s.should eq(original.expires_at.to_s)
    end

    it "returns nil for non-existent auth token" do
      loaded = Pasto::AuthToken.find("non-existent-token-id")
      loaded.should be_nil
    end
  end

  describe "#delete" do
    it "removes auth token from storage" do
      fingerprint = "delete-test-fingerprint"
      token = Pasto::AuthToken.new(fingerprint)
      token.save

      # Verify it exists
      found = Pasto::AuthToken.find(token.sepia_id)
      found.should_not be_nil

      # Delete it
      result = token.delete
      result.should be_true

      # Verify it's gone
      found_after = Pasto::AuthToken.find(token.sepia_id)
      found_after.should be_nil
    end
  end

  describe "serialization" do
    it "serializes to and from sepia format" do
      fingerprint = "serialization-test"
      original = Pasto::AuthToken.new(fingerprint)
      original.save

      # Convert to sepia string
      sepia_string = original.to_sepia
      sepia_string.should be_a(String)
      sepia_string.should contain(fingerprint)

      # Load from sepia string
      restored = Pasto::AuthToken.from_sepia(sepia_string)
      restored.fingerprint.should eq(original.fingerprint)
      restored.created_at.to_s.should eq(original.created_at.to_s)
      restored.expires_at.to_s.should eq(original.expires_at.to_s)
    end
  end

  describe "persistence" do
    it "persists and loads all fields correctly" do
      fingerprint = "persistence-test-fingerprint"
      token = Pasto::AuthToken.new(fingerprint)

      token.save

      loaded = Pasto::AuthToken.find(token.sepia_id)
      loaded.should_not be_nil

      loaded_token = loaded.not_nil!
      loaded_token.fingerprint.should eq(token.fingerprint)
      loaded_token.created_at.to_s.should eq(token.created_at.to_s)
      loaded_token.expires_at.to_s.should eq(token.expires_at.to_s)
    end
  end

  describe "TOKEN_LIFETIME" do
    it "has correct lifetime value" do
      Pasto::AuthToken::TOKEN_LIFETIME.should eq(10.minutes)
    end

    it "uses token lifetime for expiration calculation" do
      token = Pasto::AuthToken.new("lifetime-test")
      expected_expires = token.created_at + 10.minutes

      token.expires_at.to_s.should eq(expected_expires.to_s)
    end
  end

  describe "timestamp handling" do
    it "sets created_at on initialization" do
      before_creation = Time.utc
      token = Pasto::AuthToken.new("timestamp-test")
      after_creation = Time.utc

      token.created_at.should_not be_nil
      token.created_at.should be >= before_creation
      token.created_at.should be <= after_creation
    end

    it "sets expires_at based on created_at" do
      token = Pasto::AuthToken.new("expires-test")
      time_diff = token.expires_at - token.created_at

      time_diff.should eq(Pasto::AuthToken::TOKEN_LIFETIME)
    end
  end

  describe "edge cases" do
    it "handles different fingerprint formats" do
      fingerprints = [
        "aa:bb:cc:dd:ee",
        "SHA256:abc123",
        "simple-fingerprint",
        "123456789",
        "special-chars-!@#$%^&*()",
      ]

      fingerprints.each do |fp|
        token = Pasto::AuthToken.new(fp)
        token.fingerprint.should eq(fp)

        token.save
        loaded = Pasto::AuthToken.find(token.sepia_id)
        loaded.should_not be_nil
        loaded.not_nil!.fingerprint.should eq(fp)
      end
    end

    it "handles empty fingerprint" do
      token = Pasto::AuthToken.new("")
      token.fingerprint.should eq("")
    end

    it "handles long fingerprint strings" do
      long_fingerprint = "a" * 1000
      token = Pasto::AuthToken.new(long_fingerprint)
      token.fingerprint.should eq(long_fingerprint)
    end
  end

  describe "find method error handling" do
    it "handles exceptions gracefully" do
      # This should not crash even with invalid IDs
      invalid_ids = ["", "nonexistent", "../path/traversal", "null"]

      invalid_ids.each do |id|
        result = Pasto::AuthToken.find(id)
        result.should be_nil
      end
    end
  end

  describe "save and delete return values" do
    it "returns true on successful save" do
      token = Pasto::AuthToken.new("save-success-test")
      result = token.save
      result.should be_true
    end

    it "returns true on successful delete" do
      token = Pasto::AuthToken.new("delete-success-test")
      token.save

      result = token.delete
      result.should be_true
    end
  end

  describe "token uniqueness" do
    it "generates unique sepia_ids" do
      fingerprint = "uniqueness-test"
      token1 = Pasto::AuthToken.new(fingerprint)
      token2 = Pasto::AuthToken.new(fingerprint)

      token1.sepia_id.should_not eq(token2.sepia_id)
    end

    it "creates distinct tokens with same fingerprint" do
      fingerprint = "same-fingerprint"
      token1 = Pasto::AuthToken.new(fingerprint)
      token2 = Pasto::AuthToken.new(fingerprint)

      token1.fingerprint.should eq(token2.fingerprint)
      token1.sepia_id.should_not eq(token2.sepia_id)
      token1.created_at.should_not eq(token2.created_at)
      token1.expires_at.should_not eq(token2.expires_at)
    end
  end
end

require "sepia"
require "./paste"

module Pasto
  class SSHKey < Sepia::Object
    include Sepia::Serializable

    property owner_id : String?
    property pastes : Array(Paste)
    property created_at : Time

    def initialize(fingerprint : String)
      @sepia_id = self.class.sanitize_fingerprint(fingerprint)
      @owner_id = nil
      @pastes = [] of Paste
      @created_at = Time.utc
    end

    # Sanitize fingerprint for use as filesystem-safe ID
    def self.sanitize_fingerprint(fingerprint : String) : String
      fingerprint.gsub("/", "_")
    end

    # Add a paste to this key
    def add_paste(paste : Paste) : Paste
      @pastes << paste
      paste
    end

    # Create a paste and add it to this key
    def create_paste(content : String, theme : String = "default-dark", language : String? = nil) : Paste
      paste = Paste.new(
        content: content,
        theme: theme,
        language: language,
        ssh_fingerprint: @sepia_id
      )
      add_paste(paste)
      paste
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        owner_id:   @owner_id,
        pastes:     @pastes.map { |p| {id: p.sepia_id, content: p.content, language: p.language, theme: p.theme, created_at: p.created_at.to_rfc3339, updated_at: p.updated_at.to_rfc3339} },
        created_at: @created_at.to_rfc3339,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : SSHKey
      data = Hash(String, JSON::Any).from_json(sepia_string)

      key = new("")  # Placeholder, sepia_id set by Sepia
      key.owner_id = data["owner_id"]?.try(&.as_s?)
      key.created_at = Time.parse_rfc3339(data["created_at"].as_s)

      if pastes_data = data["pastes"]?.try(&.as_a?)
        key.pastes = pastes_data.map do |p|
          paste = Paste.new(
            content: p["content"].as_s,
            language: p["language"]?.try(&.as_s?),
            theme: p["theme"]?.try(&.as_s?) || "default-dark"
          )
          paste.sepia_id = p["id"].as_s
          paste.created_at = Time.parse_rfc3339(p["created_at"].as_s)
          paste.updated_at = Time.parse_rfc3339(p["updated_at"].as_s)
          paste
        end
      end

      key
    end

    # Load or create an SSHKey by fingerprint
    def self.find_or_create(fingerprint : String) : SSHKey
      sanitized = sanitize_fingerprint(fingerprint)
      if existing = Sepia::Storage.load(SSHKey, sanitized)
        existing
      else
        new(fingerprint)
      end
    rescue
      new(fingerprint)
    end

    # Find an SSHKey by sanitized fingerprint/ID
    def self.find(id : String) : SSHKey?
      Sepia::Storage.load(SSHKey, id)
    rescue
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
  end
end

require "sepia"
require "../paste"
require "../ssh_utils"

module Pasto
  class SSHKey < Sepia::Object
    include Sepia::Serializable

    property owner_id : String?
    property pastes : Array(Paste)
    property fingerprint : String
    property created_at : Time

    def initialize(fingerprint : String)
      @fingerprint = fingerprint
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

    # Create a paste and add it to this key with modern security features
    def create_paste(content : String, theme : String = "default-dark", language : String? = nil, filename : String? = nil, title : String? = nil, encrypted : Bool = false, expires_at : Time? = nil, burn_after_reading : Bool = false, private_paste : Bool = false, encryption_password : String? = nil) : Paste
      paste = Paste.new(
        content: content,
        theme: theme,
        language: language,
        ssh_fingerprint: @sepia_id,
        filename: filename,
        title: title
      )

      # Set security features
      paste.expires_at = expires_at if expires_at
      paste.burn_after_reading = burn_after_reading
      paste.private = private_paste

      # Handle encryption (always password-based with PBKDF2)
      if encrypted
        paste.is_encrypted = true
        paste.encrypted_content = content

        # For password-based encryption, the server should handle encryption
        # For key-based encryption (SSH), this is handled in ssh_server.cr
        if encryption_password
          # This would be handled by password-based encryption logic
          # For now, mark as password-based but don't encrypt here
          paste.content = "" # Clear plain content for encrypted pastes
        else
          # SSH key-based encryption - handled in ssh_server.cr
          paste.content = "" # Clear plain content for encrypted pastes
        end
      end

      add_paste(paste)
      paste
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        owner_id:    @owner_id,
        fingerprint: @fingerprint,
        pastes:      @pastes.map { |paste_item| {id: paste_item.sepia_id, content: paste_item.content, language: paste_item.language, theme: paste_item.theme, title: paste_item.title, filename: paste_item.filename, created_at: paste_item.created_at.to_rfc3339, updated_at: paste_item.updated_at.to_rfc3339} },
        created_at:  @created_at.to_rfc3339,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : SSHKey
      data = Hash(String, JSON::Any).from_json(sepia_string)

      fingerprint = data["fingerprint"]?.try(&.as_s) || ""
      key = new(fingerprint) # sepia_id set by Sepia
      key.owner_id = data["owner_id"]?.try(&.as_s?)
      key.created_at = Time.parse_rfc3339(data["created_at"].as_s)

      if pastes_data = data["pastes"]?.try(&.as_a?)
        key.pastes = pastes_data.map do |paste_data|
          paste = Paste.new(
            content: paste_data["content"].as_s,
            language: paste_data["language"]?.try(&.as_s?),
            theme: paste_data["theme"]?.try(&.as_s?) || "default-dark",
            title: paste_data["title"]?.try(&.as_s?),
            filename: paste_data["filename"]?.try(&.as_s?)
          )
          paste.sepia_id = paste_data["id"].as_s
          paste.created_at = Time.parse_rfc3339(paste_data["created_at"].as_s)
          paste.updated_at = Time.parse_rfc3339(paste_data["updated_at"].as_s)
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
      Sepia::Storage.save(self)
      true
    rescue ex
      false
    end
  end
end

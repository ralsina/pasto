require "sepia"
require "hansa"

module Pasto
  class Paste < Sepia::Object
    include Sepia::Serializable

    property content : String
    property language : String?
    property theme : String
    property created_at : Time
    property updated_at : Time
    property ssh_fingerprint : String?
    property ssh_ip : String?
    property user_id : String?

    def initialize(@content : String, @language : String? = nil, @theme : String = "default-dark", @ssh_fingerprint : String? = nil, @ssh_ip : String? = nil, @user_id : String? = nil)
      @created_at = Time.utc
      @updated_at = Time.utc

      # Auto-detect language if not provided - simplified version for SSH
      if @language.nil?
        @language = "text"  # Default to text for SSH, can be enhanced later
      end
    end

    # Sepia serialization methods
    def to_sepia : String
      {
        content:         @content,
        language:        @language,
        theme:           @theme,
        created_at:      @created_at.to_rfc3339,
        updated_at:      @updated_at.to_rfc3339,
        ssh_fingerprint: @ssh_fingerprint,
        ssh_ip:          @ssh_ip,
        user_id:         @user_id,
      }.to_json
    end

    def self.from_sepia(sepia_string : String) : Paste
      data = Hash(String, JSON::Any).from_json(sepia_string)
      paste = new(
        content: data["content"].as_s,
        language: data["language"]?.try(&.as_s?),
        theme: data["theme"]?.try(&.as_s?) || "default-dark",
        ssh_fingerprint: data["ssh_fingerprint"]?.try(&.as_s?),
        ssh_ip: data["ssh_ip"]?.try(&.as_s?),
        user_id: data["user_id"]?.try(&.as_s?)
      )
      paste.created_at = Time.parse_rfc3339(data["created_at"].as_s)
      paste.updated_at = Time.parse_rfc3339(data["updated_at"].as_s)
      paste
    end

    # Compatibility methods
    def self.from_file(id : String) : Paste?
      Sepia::Storage.load(Paste, id)
    rescue ex
      nil
    end

    def save : Bool
      @updated_at = Time.utc
      begin
        Sepia::Storage.save(self)
        true
      rescue ex
        false
      end
    end

    # Simple language detection - can be enhanced later
    private def self.get_best_supported_language(content : String) : String
      # Basic heuristics for language detection
      case content
      when .includes?("def "), .includes?("class "), .includes?("import ")
        "python"
      when .includes?("function "), .includes?("const "), .includes?("let ")
        "javascript"
      when .includes?("class "), .includes?("def initialize"), .includes?("require ")
        "crystal"
      else
        "text"
      end
    end
  end
end
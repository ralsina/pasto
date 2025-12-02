require "kemal-session"
require "sepia"

module Pasto
  # Session data stored via Sepia
  #
  # This class stores the raw session data (hashes of each type)
  # and is persisted using Sepia's file-based storage.
  class SessionData < Sepia::Object
    include Sepia::Serializable
    include JSON::Serializable

    property ints : Hash(String, Int32) = {} of String => Int32
    property bigints : Hash(String, Int64) = {} of String => Int64
    property strings : Hash(String, String) = {} of String => String
    property floats : Hash(String, Float64) = {} of String => Float64
    property bools : Hash(String, Bool) = {} of String => Bool
    property objects : Hash(String, Kemal::Session::StorableObject::StorableObjectContainer) = {} of String => Kemal::Session::StorableObject::StorableObjectContainer

    def initialize
    end

    def to_sepia : String
      to_json
    end

    def self.from_sepia(json : String) : self
      from_json(json)
    end
  end
end

module Kemal
  class Session
    # Sepia-based storage engine for kemal-session
    #
    # This engine uses Sepia's file-based storage to persist session data,
    # allowing session data to live alongside other Sepia objects in the
    # same data directory.
    class SepiaEngine < Engine
      @cache : Pasto::SessionData
      @cached_session_id : String
      @cached_session_read_time : Time

      def initialize(options : Hash(Symbol, String) = {} of Symbol => String)
        @cache = Pasto::SessionData.new
        @cached_session_read_time = Time.utc
        @cached_session_id = ""
      end

      def run_gc
        each_session do |session|
          # Check the modification time of the session file
          begin
            data = Pasto::SessionData.load(session.id)
            file_path = data.canonical_path
            if File.exists?(file_path)
              age = Time.utc - File.info(file_path).modification_time
              session.destroy if age.total_seconds > Session.config.timeout.total_seconds
            end
          rescue
            # Session file doesn't exist or is corrupted, destroy it
            session.destroy
          end
        end
      end

      def clear_cache
        @cache = Pasto::SessionData.new
        @cached_session_id = ""
      end

      def load_into_cache(session_id : String) : Pasto::SessionData
        @cached_session_id = session_id
        @cache = read_or_create_storage_instance(session_id)
        @cache
      end

      def is_in_cache?(session_id : String) : Bool
        if (@cached_session_read_time.to_unix / 60) < (Time.utc.to_unix / 60)
          @cached_session_read_time = Time.utc
          # Touch the file to update modification time for GC purposes
          begin
            file_path = File.join(Sepia::Storage::INSTANCE.path, "Pasto::SessionData", session_id)
            if File.exists?(file_path)
              File.utime(Time.local, Time.local, file_path)
            end
          rescue
            # Ignore errors updating file time
          end
        end
        session_id == @cached_session_id
      end

      def save_cache
        @cache.sepia_id = @cached_session_id
        @cache.save
      end

      def read_or_create_storage_instance(session_id : String) : Pasto::SessionData
        if session_exists?(session_id)
          begin
            data = Pasto::SessionData.load(session_id)
            @cached_session_read_time = Time.utc
            return data
          rescue
            # If loading fails, create new instance
          end
        end
        instance = Pasto::SessionData.new
        instance.sepia_id = session_id
        @cached_session_read_time = Time.utc
        instance.save
        instance
      end

      def session_exists?(session_id : String) : Bool
        Pasto::SessionData.exists?(session_id)
      end

      def create_session(session_id : String)
        read_or_create_storage_instance(session_id)
      end

      def get_session(session_id : String) : Session?
        return Session.new(session_id) if session_exists?(session_id)
        nil
      end

      def destroy_session(session_id : String)
        if session_exists?(session_id)
          begin
            data = Pasto::SessionData.new
            data.sepia_id = session_id
            data.delete
          rescue
            # Ignore errors during deletion
          end
        end
        clear_cache if @cached_session_id == session_id
      end

      def destroy_all_sessions
        each_session do |session|
          session.destroy
        end
      end

      def all_sessions : Array(Session)
        array = [] of Session
        each_session do |session|
          array << session
        end
        array
      end

      def each_session(&)
        session_dir = File.join(Sepia::Storage::INSTANCE.path, "Pasto::SessionData")
        return unless Dir.exists?(session_dir)

        Dir.each_child(session_dir) do |f|
          full_path = File.join(session_dir, f)
          if File.file?(full_path)
            yield Session.new(f)
          end
        end
      end

      # Type-specific accessors using macros
      macro define_delegators(vars)
        {% for name, type in vars %}

          def {{name.id}}(session_id : String, k : String) : {{type}}
            load_into_cache(session_id) unless is_in_cache?(session_id)
            @cache.{{name.id}}s[k]
          end

          def {{name.id}}?(session_id : String, k : String) : {{type}}?
            load_into_cache(session_id) unless is_in_cache?(session_id)
            @cache.{{name.id}}s[k]?
          end

          def {{name.id}}(session_id : String, k : String, v : {{type}})
            load_into_cache(session_id) unless is_in_cache?(session_id)
            @cache.{{name.id}}s[k] = v
            save_cache
          end

          def {{name.id}}s(session_id : String) : Hash(String, {{type}})
            load_into_cache(session_id) unless is_in_cache?(session_id)
            @cache.{{name.id}}s
          end

          def delete_{{name.id}}(session_id : String, k : String)
            load_into_cache(session_id) unless is_in_cache?(session_id)
            @cache.{{name.id}}s.delete(k) if @cache.{{name.id}}s[k]?
            save_cache
          end
        {% end %}
      end

      define_delegators({
        int:    Int32,
        bigint: Int64,
        string: String,
        float:  Float64,
        bool:   Bool,
        object: Session::StorableObject::StorableObjectContainer,
      })
    end
  end
end

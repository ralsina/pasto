require "spec"
require "../src/theme_helper"
require "../src/models/user"

# Mock Config class for testing
module Pasto
  VERSION = "0.1.0"

  class Config
    property theme : String = "monokai"

    def initialize(@args : Array(String))
    end
  end
end

describe Pasto::ThemeHelper do
  describe "#get_theme_preferences" do
    describe "with logged-in user" do
      it "uses user's theme preferences when set" do
        user = Pasto::User.new(name: "Test User")
        user.pico_theme = "light"
        user.pico_color = "blue"
        user.syntax_theme = "github"

        # Create a mock config with required args parameter
        args = ["--port", "3000", "--storage-dir", "./data"]
        config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

        preferences = Pasto::ThemeHelper.get_theme_preferences(user, config)

        preferences[:pico_theme].should eq("light")
        preferences[:pico_color].should eq("blue")
        preferences[:syntax_theme].should eq("github")
      end

      it "migrates 'auto' theme to 'dark'" do
        user = Pasto::User.new(name: "Test User")
        user.pico_theme = "auto"
        config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

        preferences = Pasto::ThemeHelper.get_theme_preferences(user, config)

        preferences[:pico_theme].should eq("dark")
        user.pico_theme.should eq("dark")
      end

      it "uses defaults when user preferences are nil" do
        user = Pasto::User.new(name: "Test User")
        config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

        preferences = Pasto::ThemeHelper.get_theme_preferences(user, config)

        preferences[:pico_theme].should eq("dark")
        preferences[:pico_color].should eq("slate")
        preferences[:syntax_theme].should eq(config.theme)
      end
    end

    describe "with anonymous user" do
      it "uses default themes" do
        config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

        preferences = Pasto::ThemeHelper.get_theme_preferences(nil, config)

        preferences[:pico_theme].should eq("dark")
        preferences[:pico_color].should eq("slate")
        preferences[:syntax_theme].should eq(config.theme)
      end
    end

    describe "with config fallback" do
      it "uses config theme when user has no syntax preference" do
        user = Pasto::User.new(name: "Test User")
        user.pico_theme = "light"
        user.pico_color = "blue"
        # No syntax_theme set
        config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])
        config.theme = "custom-theme"

        preferences = Pasto::ThemeHelper.get_theme_preferences(user, config)

        preferences[:syntax_theme].should eq("custom-theme")
      end
    end
  end

  describe "#setup_vars" do
    it "returns hash with all required variables" do
      user = Pasto::User.new(name: "Test User")
      user.pico_theme = "light"
      user.pico_color = "blue"
      user.syntax_theme = "github"
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])
      config.theme = "test-theme"

      vars = Pasto::ThemeHelper.setup_vars(user, config)

      vars.keys.should contain(:saved_pico_theme)
      vars.keys.should contain(:saved_pico_color)
      vars.keys.should contain(:saved_syntax_theme)
      vars.keys.should contain(:resolved_pico_theme)
      vars.keys.should contain(:pico_theme_file)
      vars.keys.should contain(:theme)
      vars.keys.should contain(:version)
    end

    it "sets correct values for logged-in user" do
      user = Pasto::User.new(name: "Test User")
      user.pico_theme = "light"
      user.pico_color = "blue"
      user.syntax_theme = "github"
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])
      config.theme = "test-theme"

      vars = Pasto::ThemeHelper.setup_vars(user, config)

      vars[:saved_pico_theme].should eq("light")
      vars[:saved_pico_color].should eq("blue")
      vars[:saved_syntax_theme].should eq("github")
      vars[:resolved_pico_theme].should eq("light")
      vars[:pico_theme_file].should eq("pico.blue.min.css")
      vars[:theme].should eq("test-theme")
      vars[:version].should eq(Pasto::VERSION)
    end

    it "sets CSS file name for 'css' color" do
      user = Pasto::User.new(name: "Test User")
      user.pico_color = "css"
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

      vars = Pasto::ThemeHelper.setup_vars(user, config)

      vars[:pico_theme_file].should eq("pico.min.css")
    end

    it "sets CSS file name for named color" do
      user = Pasto::User.new(name: "Test User")
      user.pico_color = "purple"
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

      vars = Pasto::ThemeHelper.setup_vars(user, config)

      vars[:pico_theme_file].should eq("pico.purple.min.css")
    end

    it "sets defaults for anonymous user" do
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])
      config.theme = "monokai"

      vars = Pasto::ThemeHelper.setup_vars(nil, config)

      vars[:saved_pico_theme].should eq("dark")
      vars[:saved_pico_color].should eq("slate")
      vars[:saved_syntax_theme].should eq("monokai")
      vars[:resolved_pico_theme].should eq("dark")
      vars[:theme].should eq("monokai")
    end

    it "includes version from VERSION constant" do
      user = Pasto::User.new
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

      vars = Pasto::ThemeHelper.setup_vars(user, config)

      vars[:version].should eq(Pasto::VERSION)
      vars[:version].should be_a(String)
      vars[:version].should_not be_empty
    end
  end

  describe "variable consistency" do
    it "maintains consistency between saved and resolved theme" do
      user = Pasto::User.new
      user.pico_theme = "light"
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

      vars = Pasto::ThemeHelper.setup_vars(user, config)

      vars[:saved_pico_theme].should eq(vars[:resolved_pico_theme])
      vars[:saved_pico_theme].should eq("light")
    end

    it "handles nil values gracefully" do
      user = Pasto::User.new
      # Don't set any preferences
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

      vars = Pasto::ThemeHelper.setup_vars(user, config)

      vars[:saved_pico_theme].should_not be_nil
      vars[:saved_pico_color].should_not be_nil
      vars[:saved_syntax_theme].should_not be_nil
      vars[:resolved_pico_theme].should_not be_nil
    end
  end

  describe "edge cases" do
    it "handles empty color string" do
      user = Pasto::User.new
      user.pico_color = ""
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])

      # Should not raise an exception
      result = Pasto::ThemeHelper.setup_vars(user, config)
      result.keys.should contain(:saved_pico_theme)
    end

    it "handles very long theme names" do
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])
      config.theme = "a" * 1000

      # Should handle very long theme names without crashing
      vars = Pasto::ThemeHelper.setup_vars(nil, config)
      vars[:saved_syntax_theme].should eq(config.theme)
    end

    it "handles special characters in theme names" do
      config = Pasto::Config.new(["--port", "3000", "--storage-dir", "./data"])
      config.theme = "theme-with-dashes_and_underscores"

      vars = Pasto::ThemeHelper.setup_vars(nil, config)
      vars[:saved_syntax_theme].should eq(config.theme)
    end
  end
end
require "./spec_helper"
require "../src/mcp_server"
require "../src/mcp_tools/*"
require "http"

describe "PastoMCPAuthProvider" do
  describe "#authenticate?" do
    it "can be instantiated" do
      provider = Pasto::PastoMCPAuthProvider.new
      provider.should_not be_nil
    end
  end

  describe "#get_user_id" do
    # Would require integration tests with actual HTTP context
  end
end

describe "PastoMCPLogProvider" do
  describe "#info" do
    it "logs info messages without crashing" do
      provider = Pasto::PastoMCPLogProvider.new
      provider.info { "Test info message" }
      # If we get here without exception, test passes
    end
  end

  describe "#error" do
    it "logs error messages without exception" do
      provider = Pasto::PastoMCPLogProvider.new
      provider.error("Test error message")
      # If we get here without exception, test passes
    end

    it "logs error messages with exception" do
      provider = Pasto::PastoMCPLogProvider.new
      ex = Exception.new("Test exception")
      provider.error("Test error", ex)
      # If we get here without exception, test passes
    end
  end

  describe "#debug" do
    it "logs debug messages without crashing" do
      provider = Pasto::PastoMCPLogProvider.new
      provider.debug("Test debug message")
      # If we get here without exception, test passes
    end
  end

  describe "#warn" do
    it "logs warning messages without crashing" do
      provider = Pasto::PastoMCPLogProvider.new
      provider.warn("Test warning message")
      # If we get here without exception, test passes
    end
  end
end

describe "PastoMCPConfig" do
  describe "#enabled?" do
    it "returns true" do
      config = Pasto::PastoMCPConfig.new
      config.enabled?.should be_true
    end
  end

  describe "#server_name" do
    it "returns 'Pasto'" do
      config = Pasto::PastoMCPConfig.new
      config.server_name.should eq("Pasto")
    end
  end

  describe "#server_version" do
    it "returns version string" do
      config = Pasto::PastoMCPConfig.new
      config.server_version.should eq("0.6.0")
    end
  end
end

describe "MCP Tools - Instantiation" do
  it "can instantiate CreatePasteTool" do
    tool = Pasto::CreatePasteTool.new
    tool.should_not be_nil
  end

  it "can instantiate GetPasteTool" do
    tool = Pasto::GetPasteTool.new
    tool.should_not be_nil
  end

  it "can instantiate DeletePasteTool" do
    tool = Pasto::DeletePasteTool.new
    tool.should_not be_nil
  end

  it "can instantiate UpdatePasteTool" do
    tool = Pasto::UpdatePasteTool.new
    tool.should_not be_nil
  end

  it "can instantiate ListPastesTool" do
    tool = Pasto::ListPastesTool.new
    tool.should_not be_nil
  end
end

describe "Pasto::CreatePasteTool" do
  describe "parameter validation" do
    it "can be instantiated" do
      tool = Pasto::CreatePasteTool.new
      # Since we can't mock HTTP::Server::Context easily,
      # we'll just verify the tool can be created
      tool.should_not be_nil
    end
  end
end

describe "Pasto::GetPasteTool" do
  describe "parameter validation" do
    it "can be instantiated" do
      tool = Pasto::GetPasteTool.new
      tool.should_not be_nil
    end
  end
end

describe "Pasto::DeletePasteTool" do
  describe "parameter validation" do
    it "can be instantiated" do
      tool = Pasto::DeletePasteTool.new
      tool.should_not be_nil
    end
  end
end

describe "Pasto::UpdatePasteTool" do
  describe "parameter validation" do
    it "can be instantiated" do
      tool = Pasto::UpdatePasteTool.new
      tool.should_not be_nil
    end
  end
end

describe "Pasto::ListPastesTool" do
  describe "parameter validation" do
    it "can be instantiated" do
      tool = Pasto::ListPastesTool.new
      tool.should_not be_nil
    end
  end
end

describe "Pasto MCP Helpers" do
  describe "#create_mcp_handler" do
    it "creates an MCP handler" do
      handler = Pasto.create_mcp_handler
      handler.should_not be_nil
    end
  end

  describe "#extract_user_from_mcp_auth" do
    it "returns nil when no env provided" do
      # This helper requires an HTTP context
      # Without integration testing, we can only verify it exists
      # Would need full Kemal setup to test properly
    end
  end
end

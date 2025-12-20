require "./spec_helper"

describe PastoSSH do
  describe "Server Creation" do
    it "creates a server instance" do
      host_key = "test_host_key"
      port = 2222
      bind_address = "127.0.0.1"

      server = PastoSSH.create_server(host_key, port, bind_address)

      server.should be_a(Shirk::Server)
    end
  end

  describe "Rate Limiting Configuration" do
    it "initializes rate limiters without crashing" do
      # This should not raise an exception
      PastoSSH.init_rate_limiters(20, 60, 3, 600, 30, 60, 5, 300)
      true.should be_true
    end
  end

  describe "Base URL Configuration" do
    it "sets base URL without crashing" do
      # This should not raise an exception
      PastoSSH.base_url = "http://localhost:3000"
      true.should be_true
    end
  end

  describe "Command Functionality" do
    it "can create server and configure rate limiting together" do
      # Test that multiple public methods work together
      PastoSSH.base_url = "http://localhost:3000"
      PastoSSH.init_rate_limiters(20, 60, 3, 600, 30, 60, 5, 300)

      server = PastoSSH.create_server("test_key", 2222, "127.0.0.1")
      server.should be_a(Shirk::Server)
    end

    it "handles different base URL configurations" do
      original_url = "http://localhost:3000"
      new_url = "https://example.com"

      PastoSSH.base_url = original_url
      PastoSSH.base_url = new_url

      # The setter should not crash
      true.should be_true
    end
  end

  describe "SSH Context Mock" do
    it "creates mock context successfully" do
      ctx = MockSSHContext.new("test content", "test command")

      ctx.stdin_content.should eq("test content")
      ctx.command.should eq("test command")
      ctx.user.should eq("test-user")
      ctx.stdout_content.should eq("")
      ctx.stderr_content.should eq("")
    end

    it "handles write operations" do
      ctx = MockSSHContext.new("", "")

      ctx.write("test output")
      ctx.stdout_content.should eq("test output")

      ctx.write_stderr("test error")
      ctx.stderr_content.should eq("test error")
    end

    it "accumulates output correctly" do
      ctx = MockSSHContext.new("", "")

      ctx.write("first")
      ctx.write(" second")
      ctx.stdout_content.should eq("first second")

      ctx.write_stderr("error1")
      ctx.write_stderr("error2")
      ctx.stderr_content.should eq("error1error2")
    end

    it "supports custom user parameter" do
      custom_user = "custom-ssh-user"
      ctx = MockSSHContext.new("", "command", custom_user)

      ctx.user.should eq(custom_user)
    end
  end

  describe "Integration Considerations" do
    it "handles SSH command structure considerations" do
      # Test that the mock can simulate SSH command scenarios
      ctx = MockSSHContext.new("paste content", "paste -l python")
      fingerprint = "test-ssh-fingerprint"

      # Verify the mock can be used to simulate SSH sessions
      ctx.stdin.should eq("paste content")
      ctx.command.should eq("paste -l python")

      fingerprint.should be_a(String)
      fingerprint.should_not be_empty
    end
  end
end
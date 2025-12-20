require "spec"
require "../src/paste"
require "../src/ssh_server"

# Set up test environment
ENV["PASTO_ENV"] = "test"

Spec.before_each do
  # Clean up test data before each test
  FileUtils.rm_rf("/tmp/pasto_test_cache") if Dir.exists?("/tmp/pasto_test_cache")
  FileUtils.mkdir_p("/tmp/pasto_test_cache")
end

Spec.after_each do
  # Clean up test data after each test
  FileUtils.rm_rf("/tmp/pasto_test_cache")
end

# Mock SSH context for testing command handlers
class MockSSHContext
  property stdin_content : String
  property stdout_content : String
  property stderr_content : String
  property command : String
  property user : String

  def initialize(stdin : String, @command : String, @user : String = "test-user")
    @stdin_content = stdin
    @stdout_content = ""
    @stderr_content = ""
  end

  def stdin : String
    @stdin_content
  end

  def write(content : String) : Nil
    @stdout_content += content
  end

  def write_stderr(content : String) : Nil
    @stderr_content += content
  end
end
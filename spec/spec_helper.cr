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
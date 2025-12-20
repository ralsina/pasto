require "./spec_helper"

# Tests for SSH command handlers
# These test the individual command handlers that process SSH commands

describe "SSH Command Handlers" do
  before_each do
    # Initialize rate limiters and base URL for tests
    PastoSSH.init_rate_limiters(100, 60, 100, 600, 100, 60, 100, 300)
    PastoSSH.base_url = "http://localhost:3000"
    
    # Clean up test data
    FileUtils.rm_rf("./test_storage")
    Dir.mkdir_p("./test_storage")
    Sepia::Storage.configure(:filesystem, {"path" => "./test_storage"})
  end

  after_each do
    # Cleanup
    FileUtils.rm_rf("./test_storage")
  end

  describe "paste command" do
    it "creates a paste with basic content" do
      ctx = MockSSHContext.new("Hello, World!", "paste")
      fingerprint = "SHA256:test-fingerprint-paste"

      exit_code = PastoSSH.handle_paste(ctx, fingerprint, "http://localhost:3000", [] of String)

      exit_code.should eq(0)
      ctx.stdout_content.should contain("http://localhost:3000/")
      ctx.stderr_content.should be_empty
    end

    it "creates a paste with language option" do
      ctx = MockSSHContext.new("def hello\n  puts 'hi'\nend", "paste -l ruby")
      fingerprint = "SHA256:test-fingerprint-ruby"

      exit_code = PastoSSH.handle_paste(ctx, fingerprint, "http://localhost:3000", ["-l", "ruby"])

      exit_code.should eq(0)
      ctx.stdout_content.should contain("http://localhost:3000/")
    end

    it "creates a paste with title" do
      ctx = MockSSHContext.new("print('test')", "paste -t 'My Script'")
      fingerprint = "SHA256:test-fingerprint-title"

      exit_code = PastoSSH.handle_paste(ctx, fingerprint, "http://localhost:3000", ["-t", "My Script"])

      exit_code.should eq(0)
      ctx.stdout_content.should contain("http://localhost:3000/")
    end

    it "creates a private paste" do
      ctx = MockSSHContext.new("private content", "paste --private")
      fingerprint = "SHA256:test-fingerprint-private"

      exit_code = PastoSSH.handle_paste(ctx, fingerprint, "http://localhost:3000", ["--private"])

      exit_code.should eq(0)
      ctx.stdout_content.should contain("http://localhost:3000/")
    end

    it "rejects empty content" do
      ctx = MockSSHContext.new("", "paste")
      fingerprint = "SHA256:test-fingerprint-empty"

      exit_code = PastoSSH.handle_paste(ctx, fingerprint, "http://localhost:3000", [] of String)

      exit_code.should eq(1)
      ctx.stderr_content.should contain("No content")
    end

    it "rejects whitespace-only content" do
      ctx = MockSSHContext.new("   \n  \t  ", "paste")
      fingerprint = "SHA256:test-fingerprint-whitespace"

      exit_code = PastoSSH.handle_paste(ctx, fingerprint, "http://localhost:3000", [] of String)

      exit_code.should eq(1)
      ctx.stderr_content.should contain("No content")
    end
  end

  describe "list command" do
    it "shows message for user with no pastes" do
      ctx = MockSSHContext.new("", "list")
      fingerprint = "SHA256:test-fingerprint-no-pastes"

      exit_code = PastoSSH.handle_list(ctx, fingerprint, "http://localhost:3000")

      exit_code.should eq(0)
      ctx.stdout_content.should contain("No pastes found")
    end

    it "lists existing pastes" do
      fingerprint = "SHA256:test-fingerprint-list"
      
      # Create a paste first
      paste_ctx = MockSSHContext.new("Test content for listing", "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", [] of String)

      # List pastes
      list_ctx = MockSSHContext.new("", "list")
      exit_code = PastoSSH.handle_list(list_ctx, fingerprint, "http://localhost:3000")

      exit_code.should eq(0)
      list_ctx.stdout_content.should contain("http://localhost:3000/")
      list_ctx.stdout_content.should contain("Test content")
    end
  end

  describe "get command" do
    it "retrieves paste content" do
      fingerprint = "SHA256:test-fingerprint-get"
      content = "Content to retrieve"
      
      # Create a paste
      paste_ctx = MockSSHContext.new(content, "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", [] of String)
      
      # Extract paste ID from URL
      paste_url = paste_ctx.stdout_content.strip
      paste_id = paste_url.split('/').last

      # Get the paste
      get_ctx = MockSSHContext.new("", "get #{paste_id}")
      exit_code = PastoSSH.handle_get(get_ctx, fingerprint, [paste_id])

      exit_code.should eq(0)
      get_ctx.stdout_content.should eq(content)
      get_ctx.stderr_content.should be_empty
    end

    it "returns error for empty paste ID" do
      fingerprint = "SHA256:test-fingerprint-get-empty"

      ctx = MockSSHContext.new("", "get")
      exit_code = PastoSSH.handle_get(ctx, fingerprint, [] of String)

      exit_code.should eq(1)
      ctx.stderr_content.should contain("Usage")
    end

    it "denies access to private paste owned by different key" do
      fingerprint1 = "SHA256:owner-fingerprint"
      fingerprint2 = "SHA256:attacker-fingerprint"
      
      # Create private paste with fingerprint1
      paste_ctx = MockSSHContext.new("Secret content", "paste --private")
      PastoSSH.handle_paste(paste_ctx, fingerprint1, "http://localhost:3000", ["--private"])
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Try to get with fingerprint2 - should fail for private pastes
      get_ctx = MockSSHContext.new("", "get #{paste_id}")
      exit_code = PastoSSH.handle_get(get_ctx, fingerprint2, [paste_id])

      exit_code.should eq(1)
      get_ctx.stderr_content.should_not be_empty
    end
  end

  describe "delete command" do
    it "deletes owned paste" do
      fingerprint = "SHA256:test-fingerprint-delete"
      
      # Create a paste
      paste_ctx = MockSSHContext.new("To be deleted", "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", [] of String)
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Delete it
      delete_ctx = MockSSHContext.new("", "delete #{paste_id}")
      exit_code = PastoSSH.handle_delete(delete_ctx, fingerprint, [paste_id])

      exit_code.should eq(0)
      delete_ctx.stdout_content.should contain("deleted")
      delete_ctx.stderr_content.should be_empty
    end

    it "denies delete of paste owned by different key" do
      fingerprint1 = "SHA256:owner-fingerprint-delete"
      fingerprint2 = "SHA256:attacker-fingerprint-delete"
      
      # Create paste with fingerprint1
      paste_ctx = MockSSHContext.new("Protected content", "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint1, "http://localhost:3000", [] of String)
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Try to delete with fingerprint2
      delete_ctx = MockSSHContext.new("", "delete #{paste_id}")
      exit_code = PastoSSH.handle_delete(delete_ctx, fingerprint2, [paste_id])

      exit_code.should eq(1)
      delete_ctx.stderr_content.should_not be_empty
    end
  end

  describe "edit command" do
    it "updates paste content" do
      fingerprint = "SHA256:test-fingerprint-edit"
      
      # Create original paste
      paste_ctx = MockSSHContext.new("Original content", "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", [] of String)
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Edit it
      edit_ctx = MockSSHContext.new("Updated content", "edit #{paste_id}")
      exit_code = PastoSSH.handle_edit(edit_ctx, fingerprint, [paste_id])

      exit_code.should eq(0)
      edit_ctx.stdout_content.should contain("updated")

      # Verify content was updated
      get_ctx = MockSSHContext.new("", "get #{paste_id}")
      PastoSSH.handle_get(get_ctx, fingerprint, [paste_id])
      get_ctx.stdout_content.should eq("Updated content")
    end

    it "rejects empty content" do
      fingerprint = "SHA256:test-fingerprint-edit-empty"
      
      # Create paste
      paste_ctx = MockSSHContext.new("Original", "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", [] of String)
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Try to edit with empty content
      edit_ctx = MockSSHContext.new("", "edit #{paste_id}")
      exit_code = PastoSSH.handle_edit(edit_ctx, fingerprint, [paste_id])

      exit_code.should eq(1)
      edit_ctx.stderr_content.should_not be_empty
    end

    it "denies edit of paste owned by different key" do
      fingerprint1 = "SHA256:owner-fingerprint-edit"
      fingerprint2 = "SHA256:attacker-fingerprint-edit"
      
      # Create paste with fingerprint1
      paste_ctx = MockSSHContext.new("Original", "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint1, "http://localhost:3000", [] of String)
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Try to edit with fingerprint2
      edit_ctx = MockSSHContext.new("Hacked", "edit #{paste_id}")
      exit_code = PastoSSH.handle_edit(edit_ctx, fingerprint2, [paste_id])

      exit_code.should eq(1)
      edit_ctx.stderr_content.should_not be_empty
    end
  end

  describe "view command" do
    it "views paste content" do
      fingerprint = "SHA256:test-fingerprint-view"
      content = "Content to view"
      
      # Create a paste
      paste_ctx = MockSSHContext.new(content, "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", [] of String)
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # View the paste
      view_ctx = MockSSHContext.new("", "view #{paste_id}")
      exit_code = PastoSSH.handle_view(view_ctx, fingerprint, [paste_id])

      exit_code.should eq(0)
      view_ctx.stdout_content.should eq(content)
    end
  end

  describe "info command" do
    it "displays paste metadata" do
      fingerprint = "SHA256:test-fingerprint-info"
      
      # Create a paste
      paste_ctx = MockSSHContext.new("Test content", "paste")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", [] of String)
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Get info
      info_ctx = MockSSHContext.new("", "info #{paste_id}")
      exit_code = PastoSSH.handle_info(info_ctx, fingerprint, [paste_id])

      exit_code.should eq(0)
      info_ctx.stdout_content.should contain("id:")
      info_ctx.stdout_content.should contain("created:")
      info_ctx.stdout_content.should contain("size:")
      info_ctx.stderr_content.should be_empty
    end

    it "shows language when set" do
      fingerprint = "SHA256:test-fingerprint-info-lang"
      
      # Create paste with language
      paste_ctx = MockSSHContext.new("def test; end", "paste -l ruby")
      PastoSSH.handle_paste(paste_ctx, fingerprint, "http://localhost:3000", ["-l", "ruby"])
      paste_id = paste_ctx.stdout_content.strip.split('/').last

      # Get info
      info_ctx = MockSSHContext.new("", "info #{paste_id}")
      exit_code = PastoSSH.handle_info(info_ctx, fingerprint, [paste_id])

      exit_code.should eq(0)
      info_ctx.stdout_content.should contain("language:")
    end
  end

  describe "help command" do
    it "displays help text" do
      ctx = MockSSHContext.new("", "help")
      
      exit_code = PastoSSH.handle_help(ctx, "http://localhost:3000")

      exit_code.should eq(0)
      ctx.stdout_content.should contain("Pasto SSH Interface")
      ctx.stdout_content.should contain("paste")
      ctx.stdout_content.should contain("list")
      ctx.stdout_content.should contain("get")
      ctx.stdout_content.should contain("delete")
      ctx.stdout_content.should contain("edit")
      ctx.stdout_content.should contain("info")
    end
  end
end

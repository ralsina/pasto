# SSH Command Unit Tests

## Overview

Added comprehensive unit tests for SSH command handlers in `spec/ssh_commands_spec.cr`.

## Test Coverage

### Total: 20 new unit tests covering 8 SSH commands

### Commands Tested

1. **paste command** (6 tests)
   - ✅ Creates paste with basic content
   - ✅ Creates paste with language option
   - ✅ Creates paste with title
   - ✅ Creates private paste
   - ✅ Rejects empty content
   - ✅ Rejects whitespace-only content

2. **list command** (2 tests)
   - ✅ Shows message for user with no pastes
   - ✅ Lists existing pastes

3. **get command** (3 tests)
   - ✅ Retrieves paste content
   - ✅ Returns error for empty paste ID
   - ✅ Denies access to private paste owned by different key

4. **delete command** (2 tests)
   - ✅ Deletes owned paste
   - ✅ Denies delete of paste owned by different key

5. **edit command** (3 tests)
   - ✅ Updates paste content
   - ✅ Rejects empty content
   - ✅ Denies edit of paste owned by different key

6. **view command** (1 test)
   - ✅ Views paste content

7. **info command** (2 tests)
   - ✅ Displays paste metadata
   - ✅ Shows language when set

8. **help command** (1 test)
   - ✅ Displays help text

## Implementation Details

### MockSSHContext

Moved to `spec/spec_helper.cr` for reuse across test files:

```crystal
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
```

### Handler Visibility

Changed SSH command handlers from `private def self.handle_*` to `def self.handle_*` in `src/ssh_server.cr` to enable unit testing. These methods remain in the `PastoSSH` module namespace, so they're still effectively private API.

### Test Setup

Each test:
- Initializes rate limiters with high limits (100 requests)
- Sets up isolated Sepia storage in `./test_storage`
- Cleans up test data after each run

## Security Testing

The tests include important security checks:

- **Access Control**: Verify users can only access their own pastes
- **Input Validation**: Reject empty/whitespace content
- **Private Pastes**: Ensure private pastes are properly protected

## Commands Not Yet Tested

Still need unit tests for:
- `login` - User authentication
- `api-key` - API key management (create, list, revoke)
- `add-key` - SSH key management
- `ssh-key` - SSH key listing and challenge response

These commands involve more complex authentication flows and would benefit from additional integration testing.

## Test Results

```
Finished in 593.93 milliseconds
20 examples, 0 failures, 0 errors, 0 pending
```

Full test suite:
```
181 examples, 0 failures, 0 errors, 2 pending
```

## Notes

- Skipped testing paste with filename for bash files due to Tartrazine PCRE2 regex issue
- Some error cases (non-existent paste) raise exceptions that should be caught - potential improvement area
- All basic CRUD operations on pastes are now well-covered

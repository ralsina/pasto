# MCP Integration Plan for Pasto

## Overview

Integrate Model Context Protocol (MCP) support into Pasto using the `ralsina/mcp` Crystal shard, enabling AI assistants to create, retrieve, and manage pastes directly through natural language interactions.

## Goals

- **Zero Installation**: Users configure MCP client with Pasto URL and API key - no local server needed
- **Unified Authentication**: Reuse existing Bearer token and session authentication
- **Native Integration**: Pure Crystal implementation using existing API logic
- **Secure by Default**: Leverage existing rate limiting and access control

## Architecture

### HTTP Endpoint

```
POST /mcp
- Accepts JSON-RPC 2.0 requests
- Authenticates via Bearer token or session cookie
- Returns JSON-RPC 2.0 responses
```

### Authentication Flow

1. Client sends MCP request with `Authorization: Bearer pasto_ak_xxx` header OR session cookie
2. Pasto validates using existing `Pasto::Filters.get_api_user()` or `get_current_user()`
3. If unauthorized, return JSON-RPC error with code -32600
4. If authorized, create user-specific MCP server instance and process request

### Tool Design

All tools operate within authenticated user's context and respect existing access control.

## MCP Tools to Implement

### 1. create_paste
**Description**: Create a new paste with content and optional metadata

**Input Schema**:
- `content` (required): String - paste content
- `title` (optional): String - paste title
- `language` (optional): String - programming language
- `filename` (optional): String - filename for language detection
- `private` (optional): Boolean - make paste private (default: false)
- `encrypted` (optional): Boolean - encrypt paste (default: false)
- `burn_after_reading` (optional): Boolean - delete after first view (default: false)
- `expires_in` (optional): String - expiration time (1h, 1d, 1w, 1m, never)

**Implementation**:
- Find user's first SSH key (required for paste creation)
- Call existing `ssh_key.create_paste()` logic
- Set additional properties (private, burn_after_reading, etc.)
- Save paste and return URL

**Response**: Text content with paste URL and optional encryption key

### 2. get_paste
**Description**: Retrieve paste content by ID

**Input Schema**:
- `id` (required): String - paste ID

**Implementation**:
- Load paste using `Paste.from_file(id)`
- Check access permissions (private pastes require ownership)
- Check expiration status
- Return content or error

**Response**: Text content with paste data

### 3. list_pastes
**Description**: List user's pastes with pagination

**Input Schema**:
- `page` (optional): Integer - page number (default: 1)
- `limit` (optional): Integer - items per page (default: 20, max: 100)
- `private_only` (optional): Boolean - filter to private pastes only

**Implementation**:
- Call `user.get_pastes_for_range()` with pagination
- Return paste summaries (id, title, language, created_at, private, encrypted)

**Response**: Structured data with paste list and pagination info

### 4. update_paste
**Description**: Update an existing paste (creates new version)

**Input Schema**:
- `id` (required): String - paste ID to update
- `content` (required): String - new content
- `title` (optional): String - new title

**Implementation**:
- Load existing paste
- Verify ownership
- Create new version using existing versioning logic
- Return updated paste URL

**Response**: Text content with updated paste URL

### 5. delete_paste
**Description**: Delete a paste permanently

**Input Schema**:
- `id` (required): String - paste ID

**Implementation**:
- Load paste
- Verify ownership
- Call `paste.delete()`
- Return confirmation

**Response**: Text content confirming deletion

## MCP Resources (Optional - Phase 2)

### paste://{id}
**Description**: Access paste content as a browsable resource

**Implementation**:
- Parse URI to extract paste ID
- Check permissions
- Return paste content with metadata

### paste://list
**Description**: Browse all user's pastes as resources

**Implementation**:
- Return list of paste URIs with titles

## Implementation Details

### File Structure

```
src/
├── mcp_tools/
│   ├── create_paste.cr     # CreatePasteTool class
│   ├── get_paste.cr        # GetPasteTool class
│   ├── list_pastes.cr      # ListPastesTool class
│   ├── update_paste.cr     # UpdatePasteTool class
│   └── delete_paste.cr     # DeletePasteTool class
├── mcp_server.cr           # MCP server setup and routing
└── server.cr               # Add POST /mcp endpoint
```

### Tool Class Pattern

Each tool inherits from `MCP::AbstractTool` and implements:
- `@@tool_name`: Tool identifier
- `@@tool_description`: User-facing description
- `@@tool_input_schema`: JSON Schema for input validation
- `invoke(params, env)`: Execute tool logic with user context

### User Context Handling

**Option A**: Extract user from env in each tool
```crystal
def invoke(params, env)
  user = Pasto::Filters.get_api_user(env) || Pasto.get_current_user(env)
  raise "Unauthorized" unless user
  # ... use user
end
```

**Option B**: Create user-specific MCP server (recommended)
- Pre-authenticate in POST /mcp handler
- Pass user context to tool constructor or as instance variable
- Tools access `@user` directly

### Error Handling

- Use JSON-RPC error codes:
  - `-32600`: Invalid Request (auth failure)
  - `-32601`: Method Not Found (unknown tool)
  - `-32602`: Invalid Params (validation failure)
  - `-32603`: Internal Error (server error)
- Return structured error messages
- Log errors using existing `Pasto::Logging`

### Rate Limiting

Apply existing rate limiters:
- HTTP rate limit for /mcp endpoint
- Paste creation rate limit for create_paste tool
- User-specific limits where applicable

## Security Considerations

### Authentication
- Require either Bearer token or valid session
- No anonymous MCP access
- Validate API key format (`pasto_ak_*`)

### Authorization
- Respect private paste access control
- Verify ownership for update/delete operations
- Apply same rules as web/API interfaces

### HTTPS Enforcement
- Require HTTPS in production (check `X-Forwarded-Proto`)
- Reject HTTP requests to /mcp in production mode

### Input Validation
- Validate all input parameters against JSON Schema
- Sanitize content (reuse existing sanitization)
- Enforce size limits (max_paste_size from config)

### CORS
- Apply existing CORS headers for API endpoints
- Only allow configured origins

## User Documentation

### Configuration Example

```json
{
  "mcpServers": {
    "pasto": {
      "transport": "http",
      "url": "https://your-pasto-instance.com/mcp",
      "headers": {
        "Authorization": "Bearer pasto_ak_xxxxxxxxxxxx"
      }
    }
  }
}
```

### Getting Started

1. Visit Pasto instance at `/profile`
2. Click "Generate API Key"
3. Copy API key (starts with `pasto_ak_`)
4. Add to MCP client configuration
5. Restart MCP client
6. Test with: "Create a paste with this code: console.log('hello')"

## Testing Plan

### Unit Tests
- Test each tool class independently
- Mock user context and paste operations
- Verify input validation
- Test error conditions

### Integration Tests
- Test full MCP request/response cycle
- Verify authentication (valid/invalid tokens, sessions)
- Test rate limiting behavior
- Verify CORS headers

### E2E Tests
- Create paste via MCP, verify via web interface
- Create paste via web, retrieve via MCP
- Test private paste access control
- Test encrypted paste creation

### Security Tests
- Attempt unauthorized access
- Test HTTPS enforcement
- Verify rate limiting kicks in
- Test malicious input handling

## Implementation Phases

### Phase 1: Core Tools (1-2 days)
- Add `mcp` dependency to shard.yml
- Implement CreatePasteTool and GetPasteTool
- Add POST /mcp endpoint with authentication
- Basic error handling and logging
- Documentation for configuration

### Phase 2: Full CRUD (1 day)
- Implement ListPastesTool
- Implement UpdatePasteTool
- Implement DeletePasteTool
- Enhanced error messages

### Phase 3: Resources (Optional)
- Implement paste:// URI scheme
- Resource browsing support
- Enhanced discoverability

### Phase 4: Polish (1 day)
- Comprehensive testing
- Rate limiting refinement
- Documentation updates
- Example use cases

## Success Metrics

- Users can create pastes from AI chat without leaving conversation
- Zero installation required beyond MCP client configuration
- Response time < 500ms for typical operations
- No security regressions
- Positive user feedback on ease of use

## Future Enhancements

- **Prompts**: Pre-defined paste templates (e.g., "Create Python script paste")
- **Search**: MCP tool for searching user's pastes
- **Collaboration**: Share pastes with other users via MCP
- **Batch Operations**: Create multiple pastes in one request
- **Webhooks**: Notify on paste creation/updates
- **Analytics**: Track MCP usage patterns

## Dependencies

- `ralsina/mcp` shard (already created)
- Existing Pasto authentication system
- Existing API logic for paste operations
- No external dependencies

## Documentation Updates

- Add MCP section to README.md
- Create MCP.md with detailed setup instructions
- Update API documentation to mention MCP support
- Add examples to help system
- Include in OpenAPI spec (if applicable)

## Marketing Angle

**"Pasto: The AI-Native Pastebin"**

- SSH for terminal workflows ✓
- MCP for AI coding assistants ✓
- REST API for automation ✓
- Web interface for humans ✓
- Zero-knowledge encryption ✓

Position Pasto at the intersection of developer tools, AI-assisted coding, and privacy-first services.

## Risk Assessment

**Low Risk**:
- Leverages existing, tested API logic
- No new attack surface (reuses auth/rate limiting)
- Isolated feature (can be disabled if issues arise)
- Pure Crystal (no external runtime dependencies)

**Mitigation**:
- Comprehensive testing before release
- Feature flag for easy rollback
- Monitor MCP usage patterns
- Rate limit conservatively at launch

## Timeline Estimate

- **Phase 1**: 2 days (core tools + endpoint)
- **Phase 2**: 1 day (full CRUD)
- **Testing**: 1 day
- **Documentation**: 0.5 days
- **Total**: ~4-5 days of focused work

## Conclusion

MCP integration is a high-value, low-risk addition that significantly expands Pasto's accessibility to AI-powered development workflows. With the `ralsina/mcp` shard already created and Pasto's well-structured API, implementation is straightforward and leverages existing infrastructure.

This positions Pasto as a forward-thinking pastebin that embraces emerging AI workflows while maintaining security, privacy, and performance standards.

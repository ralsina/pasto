# Webhook System for Pasto

## TL;DR

Add webhook integration to Pasto for automated paste creation from external services (GitHub, GitLab, Jenkins, Sentry, etc.). Leverages existing REST API - just needs transformation layer.

**Effort**: 2-3 hours (MVP) → 4-6 hours (Full) → 8-12 hours (Polished)

---

## Why Webhooks?

Webhooks enable automated workflows:
- **CI/CD**: Automatically paste build logs on failure
- **GitHub/GitLab**: Paste code diffs on push/PR
- **Monitoring**: Paste error traces from Sentry/DataDog
- **ChatOps**: Create pastes from bot commands
- **Automation**: IFTTT/Zapier integration

---

## Architecture

### Current State (What We Have)

```
External Service → (no integration) → Pasto
```

### Proposed State

```
GitHub/GitLab/Jenkins/etc → Webhook Endpoint → Transformer → Existing API → Paste
```

### Key Insight

**We're not building new paste creation logic** - just a **translation layer**:
- Accept webhook payload
- Extract relevant content
- Transform to API format
- Call existing `POST /api/v1/pastes`
- Return service-specific response

---

## Implementation Plan

### Phase 1: MVP (2-3 hours)

**Core Infrastructure:**
1. Generic webhook endpoint (`/webhook/:service`)
2. Simple content extraction
3. Basic authentication (API key in header)
4. Generic JSON transformer
5. Response formatting

**Services:**
- Generic (any JSON payload)
- GitHub (push events)

**Files:**
```
src/webhooks/
├── handler.cr           # Main webhook router
├── transformers/
│   ├── generic.cr       # Generic JSON transformer
│   └── github.cr        # GitHub-specific transformer
└── webhook.cr           # Webhook model (secrets, config)

src/server.cr            # Add webhook routes
```

**API Endpoints:**
```
POST /webhook/generic    # Create paste from any JSON
POST /webhook/github     # GitHub push events
GET  /webhook/config     # List configured webhooks (future)
```

### Phase 2: Full Version (4-6 hours)

**Additional Transformers:**
- GitLab push/merge events
- Jenkins build notifications
- Sentry error alerts
- CircleCI build events
- Travis CI builds
- Discord/Slack webhook format

**Features:**
- Webhook signature verification (HMAC)
- Service-specific secrets storage
- Event filtering (only on failure, only PRs, etc.)
- Richer content extraction (diffs, stack traces)

**UI:**
- Webhook configuration page
- Webhook history/logs
- Test webhook button

### Phase 3: Polished (8-12 hours)

**Advanced Features:**
- Webhook retry logic with exponential backoff
- Async processing for large payloads
- Webhook delivery status tracking
- Per-user webhook quotas
- Custom transformation rules (user-defined)
- Webhook event log with search/filter

**UX:**
- Webhook setup wizard
- Integration guides for each service
- Webhook testing playground
- Real-time delivery status (WebSocket)

---

## Technical Implementation

### 1. Webhook Model

```crystal
# src/models/webhook.cr
class Webhook < Sepia::Model
  property user_id : String
  property service : String          # "github", "gitlab", etc.
  property secret : String?          # HMAC verification secret
  property events : Array(String)    # ["push", "pull_request"]
  property filters : JSON::Any?      # Custom filters
  property active : Bool = true
  property created_at : Time = Time.utc
  property last_triggered : Time?

  # Verify webhook signature
  def verify_signature(payload : String, signature : String) : Bool
    # HMAC-SHA256 verification
  end

  # Check if event matches filters
  def matches_event?(event : String) : Bool
    events.includes?(event) || events.includes?("*")
  end
end
```

### 2. Webhook Handler

```crystal
# src/webhooks/handler.cr
class WebhookHandler
  def self.handle(env : HTTP::Server::Context, service : String)
    # 1. Extract service name from URL
    # 2. Find transformer for service
    # 3. Verify signature (if configured)
    # 4. Transform payload to paste content
    # 5. Create paste via API
    # 6. Return service-specific response
  end

  private def self.find_transformer(service : String)
    case service
    when "github" then GithubTransformer
    when "gitlab" then GitlabTransformer
    when "generic" then GenericTransformer
    else
      raise UnknownServiceError.new(service)
    end
  end
end
```

### 3. Transformer Interface

```crystal
# src/webhooks/transformers/base.cr
abstract class WebhookTransformer
  abstract def extract_title(payload : JSON::Any) : String
  abstract def extract_content(payload : JSON::Any) : String
  abstract def extract_language(payload : JSON::Any) : String?
  abstract def extract_metadata(payload : JSON::Any) : Hash(String, String)?

  def transform(payload : JSON::Any) : PasteData
    PasteData.new(
      title: extract_title(payload),
      content: extract_content(payload),
      language: extract_language(payload),
      metadata: extract_metadata(payload)
    )
  end
end

record PasteData,
  title : String,
  content : String,
  language : String?,
  metadata : Hash(String, String)?

# Example: GitHub Transformer
# src/webhooks/transformers/github.cr
class GithubTransformer < WebhookTransformer
  def extract_title(payload : JSON::Any) : String
    ref = payload.dig?("repository", "full_name").as_s || "Unknown"
    action = payload.dig?("head_commit", "message").as_s || "Push"
    "#{ref}: #{action}"
  end

  def extract_content(payload : JSON::Any) : String
    commits = payload.dig("commits").as_a
    commits.map do |commit|
      message = commit["message"].as_s
      added = commit.dig?("added", 0).try { |a| a.as_a.join("\n") } || ""
      modified = commit.dig?("modified", 0).try { |m| m.as_a.join("\n") } || ""
      <<-EOF
      Commit: #{message}

      Added files:
      #{added}

      Modified files:
      #{modified}
      EOF
    end.join("\n\n---\n\n")
  end

  def extract_language(payload : JSON::Any) : String?
    # Detect from file extensions in commits
    nil
  end

  def extract_metadata(payload : JSON::Any) : Hash(String, String)?
    {
      "service"     => "github",
      "pusher"      => payload.dig?("pusher", "name").as_s,
      "ref"         => payload.dig?("ref").as_s,
      "repository"  => payload.dig?("repository", "full_name").as_s,
      "github_url"  => payload.dig?("repository", "html_url").as_s,
    }
  end
end
```

### 4. Server Routes

```crystal
# Add to src/server.cr

# Webhook endpoints (no auth - use API key in header)
post "/webhook/:service" do |env|
  service = env.params.url["service"]

  # Extract API key from header (optional, for anonymous webhooks)
  api_key = env.request.headers["X-Pasto-Api-Key"]?

  # Get service transformer
  transformer = WebhookHandler.find_transformer(service)

  # Parse webhook payload
  body = env.request.body.as(IO).gets_to_end
  payload = JSON.parse(body)

  # Transform to paste format
  paste_data = transformer.transform(payload)

  # Create paste (with or without user context)
  if api_key
    # Authenticated webhook - create as user
    user = lookup_user_by_api_key(api_key)
    ssh_key = user.keys.first?
    paste = ssh_key.create_paste(
      content: paste_data.content,
      title: paste_data.title,
      language: paste_data.language
    )
    paste.user_id = user.sepia_id
  else
    # Anonymous webhook - create as system user
    # Or require webhook secret verification
  end

  paste.save

  # Return service-specific response
  {
    "paste_url" => Pasto.build_paste_url(env, paste.sepia_id),
    "paste_id"  => paste.sepia_id,
    "service"   => service,
    "created_at" => paste.created_at.to_rfc3339,
  }.to_json
end
```

---

## Service-Specific Implementations

### GitHub Webhooks

**Events to support:**
- `push` - Code pushed to repository
- `pull_request` - PR opened/updated
- `issues` - Issue created (paste issue body)

**Payload extraction:**
- Repository name
- Commit messages
- Changed files
- Diff content (if requested)

**Signature verification:**
```crystal
def verify_github_signature(payload : String, signature : String, secret : String) : Bool
  hmac = OpenSSL::HMAC.hexdigest(:sha256, secret, payload)
  "sha256=#{hmac}" == signature
end
```

### GitLab Webhooks

**Similar to GitHub but different payload structure:**
- Different JSON schema
- Different header format (`X-Gitlab-Token` vs `X-Hub-Signature`)
- Support merge requests (not just PRs)

### Generic Webhook

**For any service:**
```json
POST /webhook/generic
{
  "title": "Custom Webhook",
  "content": "Paste content here",
  "language": "python",
  "private": true,
  "metadata": {
    "source": "custom-script",
    "environment": "production"
  }
}
```

**Just forwards to existing API**

### Jenkins Webhooks

**Extract from Jenkins notification plugin:**
- Build status
- Console output (truncated if needed)
- Build log URL
- Project name

### Sentry Webhooks

**Extract error information:**
- Exception message
- Stack trace
- Request data
- Tags/environment

---

## Configuration Options

### Server Configuration (pasto.yml)

```yaml
webhooks:
  enabled: true
  anonymous: false           # Allow webhooks without API key
  max_payload_size: 10485760  # 10MB
  timeout: 30                # Request timeout in seconds
  async_processing: false    # Process webhooks asynchronously (future)
  require_signature: false   # Require HMAC signature
```

### Per-User Configuration (in database)

```crystal
class UserWebhookConfig
  property user_id : String
  property service : String
  property enabled : Bool
  property auto_private : Bool = true
  property default_language : String?
  property filters : JSON::Any?
end
```

---

## Authentication Methods

### Option 1: API Key in Header (Recommended for MVP)

```bash
curl -X POST https://pasto.example.com/webhook/github \
  -H "X-Pasto-Api-Key: pasto_ak_xxxxx" \
  -H "Content-Type: application/json" \
  -d @payload.json
```

**Pros:**
- Simple to implement
- Leverages existing auth
- Works for all services

**Cons:**
- All webhooks under one user
- No per-service isolation

### Option 2: Webhook Secrets (More Secure)

Each webhook has unique secret:

```bash
# GitHub webhook configuration
Secret: webhook_secret_abc123

# Verify signature
X-Hub-Signature-256: sha256=<hmac>
```

**Pros:**
- Standard webhook security
- Per-webhook isolation
- Industry standard

**Cons:**
- More complex to implement
- Need UI for secret management

### Option 3: Hybrid (Both)

Support both methods:
- API key for simple integrations
- Webhook secrets for production use

---

## Security Considerations

### Rate Limiting

- Apply existing rate limits to webhook endpoints
- Per-user quotas (e.g., 100 webhooks/hour)
- Global quotas (e.g., 1000 webhooks/hour)

### Payload Size Limits

```crystal
max_size = 10 * 1024 * 1024 # 10MB
if body.bytesize > max_size
  env.response.status_code = 413
  next {"error": "Payload too large"}.to_json
end
```

### Signature Verification

```crystal
unless verify_signature(payload, signature, secret)
  env.response.status_code = 403
  next {"error": "Invalid signature"}.to_json
end
```

### Content Sanitization

- Strip sensitive headers from metadata
- Truncate large payloads
- Validate JSON structure
- Prevent ReDoS attacks

### Authentication

- Require API key OR valid webhook signature
- Never allow truly anonymous webhooks
- Log all webhook attempts
- Monitor for abuse patterns

---

## Testing Strategy

### Unit Tests

```crystal
# spec/webhooks/transformers/github_spec.cr
describe GithubTransformer do
  it "extracts title from push event" do
    payload = load_fixture("github_push.json")
    transformer = GithubTransformer.new
    title = transformer.extract_title(payload)

    title.should eq("user/repo: Fix bug")
  end

  it "extracts commit content" do
    # ...
  end
end
```

### Integration Tests

```bash
# Test webhook endpoints
curl -X POST http://localhost:3000/webhook/generic \
  -H "Content-Type: application/json" \
  -H "X-Pasto-Api-Key: $API_KEY" \
  -d '{"title":"Test","content":"Hello world"}'

# Expected response:
{
  "paste_url": "http://localhost:3000/abc123",
  "paste_id": "abc123",
  "service": "generic"
}
```

### Webhook Testing Tools

- **GitHub**: Use smee.io for testing GitHub webhooks locally
- **Generic**: Use curl/Postman
- **UI**: Build webhook testing playground (phase 3)

---

## Documentation

### User Documentation

1. **Webhook Setup Guide** (`docs/src/user-guide/webhooks.md`)
   - What are webhooks?
   - How to configure webhooks
   - Per-service setup instructions
   - Troubleshooting

2. **Service Integration Guides**
   - GitHub: Create webhook → URL configuration
   - GitLab: Project settings → Webhooks
   - Jenkins: Notification plugin setup
   - Sentry: Alert rules → Webhook

### Developer Documentation

1. **Adding New Transformers** (`docs/src/developer-guide/webhooks.md`)
   - Transformer interface
   - Testing guidelines
   - Common patterns

2. **API Reference**
   - Webhook endpoints
   - Request/response formats
   - Error codes

---

## Success Metrics

### MVP Success Criteria
- ✅ Generic webhook endpoint works
- ✅ GitHub push events create pastes
- ✅ API key authentication works
- ✅ Basic error handling
- ✅ Returns paste URL in response

### Full Version Success Criteria
- ✅ 6+ service integrations
- ✅ Signature verification
- ✅ Per-user configuration
- ✅ Webhook logging
- ✅ UI for webhook management

### Usage Goals
- 100+ webhooks configured in first month
- <500ms average webhook processing time
- 99.9% uptime for webhook endpoints
- <1% webhook failure rate

---

## Future Enhancements

### Advanced Features (Phase 4+)

1. **Async Processing**
   - Background job queue for large payloads
   - WebSocket updates for long-running webhooks

2. **Webhub Marketplace**
   - Community-contributed transformers
   - Plugin system for custom transformers

3. **Conditional Pasting**
   - Only create paste on failure
   - Only paste specific file types
   - Regex-based content filtering

4. **Enrichment**
   - Auto-detect language from file extensions
   - Extract syntax from stack traces
   - Add metadata from CI context

5. **Notifications**
   - Notify on paste creation
   - Webhook status updates
   - Failed webhook alerts

---

## Migration Path

### Step 1: Add webhook routes (MVP)
- No database changes needed
- Add new folder `src/webhooks/`
- Add routes to `src/server.cr`

### Step 2: Add webhook model (Full)
- Create `Webhook` model in `src/models/webhook.cr`
- Database migration for webhooks table
- Add webhook management UI

### Step 3: Add async processing (Polished)
- Background job queue (Spawn?)
- Webhook delivery tracking
- Retry logic

---

## Rollout Plan

### Alpha (MVP)
- Deploy to staging
- Test with GitHub webhooks
- Document issues

### Beta (Full)
- Enable on production
- Invite friendly users to test
- Gather feedback

### Production (Polished)
- Official launch
- Marketing/documentation
- Community contributions

---

## Alternatives Considered

### Alternative 1: Use Webhook.site Integration
**Pros:**
- No server-side code needed
- Easy to set up

**Cons:**
- Depends on third-party service
- Limited customization
- Not self-hosted

**Decision:** Build native webhook system for self-hosted solution

### Alternative 2: Use Integromat/Zapier
**Pros:**
- Visual workflow builder
- Many integrations out of box

**Cons:**
- External dependency
- Cost (paid tiers)
- Less control

**Decision:** Native webhooks are simpler and more flexible

### Alternative 3: Email-to-Paste Gateway
**Pros:**
- Universal (every service can email)

**Cons:**
- Async (delayed)
- Parsing complexity
- SMTP server overhead

**Decision:** Webhooks are real-time and simpler

---

## Conclusion

Webhook support is **low-hanging fruit** that provides **high value**:

**Why Easy:**
- ✅ Existing API does the heavy lifting
- ✅ Just need transformation layer
- ✅ No new storage (initially)
- ✅ No new authentication (use API keys)

**Why Valuable:**
- ✅ CI/CD integration
- ✅ Automation workflows
- ✅ Monitoring/alerting
- ✅ ChatOps integration

**Effort:**
- MVP: 2-3 hours
- Full: 4-6 hours
- Polished: 8-12 hours

**Recommendation:** Start with MVP (generic + GitHub), iterate based on user feedback.

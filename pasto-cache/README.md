# Pasto::Cache

A Crystal shard that provides middleware-based HTTP response caching for Kemal applications.

## Features

- **Middleware-based caching**: Automatically caches HTTP responses using Kemal's `before_all` and `after_all` handlers
- **Flexible cache configuration**: Configure cacheable endpoints with regex patterns, MIME types, and TTL
- **JSON-based cache storage**: Persistent cache with metadata support including expiration
- **Concurrent-safe**: Handles multiple simultaneous requests safely
- **Response capture**: Uses IO::Memory buffer replacement to capture response content
- **Cache key generation**: Generates unique cache keys based on HTTP method, path, query parameters, and request body hash

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  pasto-cache:
    path: ../pasto-cache  # or use git repository
```

## Usage

### Easy Setup (Recommended)

```crystal
require "pasto-cache"

# Configure cache directory
Pasto::Cache.cache_dir = "./cache"

# Configure cacheable endpoints
# Syntax highlighting API - cache for 1 hour
Pasto::Cache.add_cache_config(/^\/highlight$/, "application/json", 3600)

# CSS themes - cache for 24 hours
Pasto::Cache.add_cache_config(/^\/syntax\/[^\/]+\/[^\/]+$/, "text/css", 86400)

# Add the middleware to your Kemal app (one-liner)
PastoCache.add_cache_middleware

# Your Kemal routes go here
Kemal.run
```

### Manual Setup (More Control)

If you need more control over the middleware behavior, you can set up the `before_all` and `after_all` blocks manually:

```crystal
require "pasto-cache"

# Configure cache directory and endpoints
Pasto::Cache.cache_dir = "./cache"
Pasto::Cache.add_cache_config(/^\/api\/cache-test$/, "text/x-cache-test", 5)

# Manual middleware setup
before_all do |env|
  if cached = PastoCache.handle_before_request(env)
    env.response.content_type = cached.mime_type
    halt env, 200, cached.content
  end
end

after_all do |env|
  PastoCache.handle_after_request(env)
end

# Your Kemal routes go here
Kemal.run
```

### API Reference

#### `PastoCache.handle_before_request(env) : Pasto::CacheEntry?`

Called in a `before_all` block to check for cached content and set up response capture.

- **Returns**: `Pasto::CacheEntry` if cached content is found, `nil` otherwise
- **Side effects**: Sets up response capture for cacheable requests

#### `PastoCache.handle_after_request(env)`

Called in an `after_all` block to cache successful responses and restore original output.

- **Side effects**:
  - Caches the response content if status is 200
  - Restores the original response output
  - Writes the captured content to the response

#### `PastoCache.add_cache_middleware`

Convenience method that sets up both `before_all` and `after_all` blocks automatically. Equivalent to the manual setup shown above.

### Cache Configuration

The `add_cache_config` method takes three parameters:

1. `path_regex`: A regex pattern to match request paths
2. `mime_type`: The MIME type to set for cached responses
3. `ttl`: Time-to-live in seconds (optional, `nil` means no expiration)

### Cache Key Generation

Cache keys are automatically generated based on:
- HTTP method (GET, POST, etc.)
- Request path
- Query parameters (sorted alphabetically)
- Request body hash (for POST/PUT requests)

### Cache Storage

Cache entries are stored as JSON files with metadata:

```crystal
class CacheEntry
  property content : String
  property mime_type : String
  property created_at : Time
  property ttl : Int32?

  def expired? : Bool
    return false unless ttl_val = ttl
    (Time.utc - @created_at).total_seconds > ttl_val
  end
end
```

### Manual Cache Operations

```crystal
# Get cached entry
if cached_entry = Pasto::Cache.get(cache_key)
  env.response.content_type = cached_entry.mime_type
  halt env, 200, cached_entry.content
end

# Set cache entry
Pasto::Cache.set(cache_key, content, mime_type, ttl)

# Invalidate cache by pattern
Pasto::Cache.invalidate(paste_id)
```

## How It Works

1. **Before Request**: The middleware checks if the request path matches a cache configuration
2. **Cache Hit**: If cached content exists and isn't expired, it returns the cached response immediately
3. **Cache Miss**: If no cache exists, it replaces the response output with an IO::Memory buffer
4. **After Response**: The middleware captures the response content, stores it in cache, and writes it back to the original response

## Example

Here's a complete example with a test endpoint:

```crystal
require "kemal"
require "pasto-cache"

# Configure cache
Pasto::Cache.cache_dir = "./public/cache"

# Cache test endpoint - cache for 5 seconds
Pasto::Cache.add_cache_config(/^\/api\/cache-test$/, "text/x-cache-test", 5)

# Add middleware
PastoCache.add_cache_middleware

# Test endpoint
get "/api/cache-test" do |env|
  {
    "timestamp" => Time.utc.to_unix,
    "message" => "This response is cached for 5 seconds",
    "random" => rand(1000)
  }.to_json
end

Kemal.run
```

Test with curl:

```bash
$ curl -i http://localhost:3000/api/cache-test
HTTP/1.1 200 OK
Content-Type: text/x-cache-test
Cache-Control: max-age=5

{"timestamp":1640995200,"message":"This response is cached for 5 seconds","random":42}

# Immediate second request returns the same cached response
$ curl -i http://localhost:3000/api/cache-test
HTTP/1.1 200 OK
Content-Type: text/x-cache-test
Cache-Control: max-age=5

{"timestamp":1640995200,"message":"This response is cached for 5 seconds","random":42}
```

## Requirements

- Crystal 1.0.0 or higher
- Kemal web framework

## Development

- Install dependencies: `shards install`
- Run tests: `crystal spec`
- Run linter: `./bin/ameba src/`
- Format code: `crystal tool format src/`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a Pull Request

## License

MIT License - see LICENSE file for details.
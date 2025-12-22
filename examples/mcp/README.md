# Pasto MCP Integration Examples

This directory contains configuration examples and usage examples for integrating Pasto with AI assistants using the Model Context Protocol (MCP).

## Quick Setup

1. **Generate an API Key**: Visit `/profile` on your Pasto instance
2. **Replace `your-pasto-instance.com`** with your Pasto URL
3. **Replace `pasto_ak_your_api_key_here`** with your actual API key

## Configuration Files

### Claude Desktop

Copy `claude_desktop.json` to your Claude Desktop configuration directory.

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows**: `%APPDATA%/Claude/claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`

## Usage Examples

### Creating a Paste

```
User: Create a paste with this Python code:
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print(factorial(5))

Claude: I'll create a paste with that Python factorial function for you.
✅ Paste created successfully!

🔗 URL: https://your-pasto-instance.com/abc123
📝 ID: abc123
🏷️ Title: Untitled
🔐 Private: false
🔒 Encrypted: false
🔥 Burn after reading: false
⏰ Expires: Never

The factorial function calculates 5! = 120.
```

### Listing Pastes with Filters

```
User: Show me my private Python pastes from the last month

Claude: 📄 **Your Pastes (Page 1 of 1)**
📊 Total: 3 pastes | Showing: 20 per page

🔐**Data Processing Script** (xyz789)
🔤 python
📅 2024-11-15T10:30:00Z
⏰ Expires: 2024-12-15T10:30:00Z

🔐**API Client** (abc456)
🔤 python
📅 2024-11-20T14:20:00Z
⏰ Never expires

🔐**Configuration Helper** (def111)
🔤 python
📅 2024-11-10T09:45:00Z
⏰ Expires: 2024-11-17T09:45:00Z
```

### Updating a Paste

```
User: Update paste abc123 with optimized version and keep it private

Claude: ✅ **Paste Updated Successfully!**

🔄 **New Version URL:** https://your-pasto-instance.com/def456
📝 **New ID:** def456
🔄 **Original ID:** abc123

**Updated Paste Details:**
🏷️  Title: Optimized Factorial Function
🔤 Language: python
🔐 Private: true
🔒 Encrypted: false
🔥 Burn after reading: false
⏰ Expires: Never
📅 Updated: 2024-12-22T15:45:00Z

Note: This creates a new version of the paste. The original paste (abc123) remains unchanged.
```

### Retrieving a Paste

```
User: Get the details of paste def456

Claude: 📄 Paste Information:

🆔 ID: def456
🏷️  Title: Optimized Factorial Function
🔤 Language: python
🔐 Private: true
🔒 Encrypted: false
🔥 Burn after reading: false
⏰ Created: 2024-12-22T15:45:00Z
📅 Expires: Never

---

📝 Content:
def factorial(n):
    if n <= 1:
        return 1
    return n * factorial(n - 1)

print(factorial(5))

# Optimized version with memoization would be more efficient
# for multiple calls with the same n value
```

## Advanced Features

### Encryption Support

```
User: Create an encrypted paste with this secret API key:
SECRET_API_KEY = "abc123xyz"
```

### Burn After Reading

```
User: Create a burn-after-reading paste with this one-time message:
This message will self-destruct after reading.
```

### Expiration Control

```
User: Create a paste that expires in 24 hours
```

## Security Notes

- **API Keys**: Keep your `pasto_ak_*` keys secure and never share them publicly
- **HTTPS**: Always use HTTPS URLs in production environments
- **Access Control**: MCP tools can only access pastes you own
- **Rate Limiting**: MCP requests respect your instance's rate limits

## Troubleshooting

### Authentication Errors
- Ensure your API key starts with `pasto_ak_`
- Check that the API key is still valid
- Verify the URL points to your Pasto instance

### Connection Issues
- Check that your Pasto instance is running
- Verify the MCP endpoint is accessible at `/mcp`
- Ensure no firewall blocks the connection

### Permission Denied
- Verify you're trying to access your own pastes
- Check that your SSH key is properly linked to your account

## More Information

For complete documentation, see the main [README.md](../../README.md) in the Pasto repository.
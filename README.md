# Pasto

A Crystal-based pastebin application with live syntax highlighting preview and extensive theme support.

![Pasto](https://img.shields.io/badge/Crystal-000000?style=for-the-badge&logo=crystal&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

## Features

- 🚀 **Fast & Lightweight**: Built with Crystal for excellent performance
- 🎨 **Live Preview**: Real-time syntax highlighting as you type
- 🌈 **Extensive Theming**: 321+ syntax highlighting themes from Tartrazine
- 🎭 **Smart Language Detection**: Filters unsupported languages (no more X10 errors!)
- 📱 **Responsive Design**: Works beautifully on desktop and mobile
- 🔒 **Built-in Security**: Rate limiting and size validation
- 🎯 **Clean UI**: Modern interface with Pico CSS

## Live Preview

Pasto provides an innovative split-pane interface where you can:

- **Type code** in the left pane
- **See instant syntax highlighting** in the right pane
- **Switch languages** and watch the preview update immediately
- **Change themes** and see the highlighting update in real-time
- **Resize panels** for your preferred viewing ratio

### Theme Support

- **15 Pico CSS color schemes** for UI styling
- **321 Tartrazine syntax themes** for code highlighting
- **Light/Dark modes** with system preference detection
- **Instant switching** with localStorage persistence

## Smart Language Filtering

Pasto intelligently handles language detection:

- **Hansa Integration**: Uses advanced language classification
- **Tartrazine Filtering**: Only shows languages that actually work with syntax highlighting
- **Graceful Fallback**: Automatically selects the best supported language
- **No More Errors**: Eliminates unsupported language errors like "X10"

## Installation

### Prerequisites

- Crystal 1.0 or higher
- Shards (Crystal package manager)

### Build from Source

```bash
# Clone the repository
git clone https://github.com/ralsina/pasto.git
cd pasto

# Install dependencies
shards install

# Build the application
shards build

# Run the server
./bin/pasto --port 3000
```

## Usage

### Running the Server

```bash
# Start on default port 3000
./bin/pasto

# Start on custom port
./bin/pasto --port 8080

# Set maximum paste size (default: 100KB)
./bin/pasto --max-paste-size 5242880  # 5MB

# Specify default theme
./bin/pasto --theme dracula
```

### Configuration

Pasto can be configured via:

- **Command line arguments**
- **Environment variables**
- **Configuration file** (`pasto.yml`)

#### Environment Variables

```bash
export PASTO_PORT=3000
export PASTO_MAX_PASTE_SIZE=102400
export PASTO_THEME=monokai
export PASTO_RATE_LIMIT=10
export PASTO_RATE_WINDOW=60
```

#### Configuration File

Create `pasto.yml`:

```yaml
port: 3000
max_paste_size: 102400  # 100KB
theme: monokai
rate_limit:
  requests: 10
  window: 60
```

## API Endpoints

### Create Paste

```bash
curl -X POST http://localhost:3000 \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "content=print('Hello, World!')&language=python&theme=dracula"
```

### Get Paste

```bash
curl http://localhost:3000/{paste-id}
```

### Live Syntax Highlighting API

```bash
curl -X POST http://localhost:3000/highlight \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "content=def hello(): pass&language=python&theme=monokai"
```

## Security Features

- **Rate Limiting**: 10 requests per minute per IP (configurable)
- **Size Validation**: Configurable maximum paste size limits
- **Input Sanitization**: Proper HTML escaping for all content
- **Error Handling**: Graceful fallbacks for unsupported languages

## Supported Languages

Pasto supports 32+ programming languages including:

- **Popular**: Python, JavaScript, TypeScript, Java, C, C++, C#, Go, Rust
- **Web**: HTML, CSS, SCSS, JSON, XML, Markdown
- **Systems**: Bash, Shell, PowerShell
- **Data**: SQL, MySQL, PostgreSQL
- **Many more**: PHP, Ruby, Perl, Kotlin, Scala, and more

*Note: Only languages with working Tartrazine lexers are shown in the dropdown.*

## Development

### Project Structure

```
pasto/
├── src/
│   ├── pasto.cr          # Main application logic
│   ├── server.cr         # Web server and routes
│   └── paste.cr          # Paste model and highlighting
├── shards.yml            # Crystal dependencies
├── pasto.yml             # Configuration file
└── README.md
```

### Development Commands

```bash
# Install dependencies
shards install

# Run tests
crystal spec

# Check formatting
crystal tool format src/

# Linting
ameba src/

# Build in development mode
shards build

# Build with release optimizations
shards build --release
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests and ensure they pass
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Tartrazine**: Crystal syntax highlighting library with 321+ themes
- **Hansa**: Language classification for smart detection
- **Kemal**: Crystal web framework
- **Pico CSS**: Minimalist CSS framework
- **Sepia**: Data serialization library

## Author

Created by [Roberto Alsina](https://github.com/ralsina)

---

**Pasto** - The modern pastebin with live preview.
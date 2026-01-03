#!/bin/bash

# Anonymous User E2E Test Runner
# This script runs only anonymous user Playwright tests

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Print header
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║            Anonymous User E2E Test Runner                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Node.js is installed
if ! command_exists node; then
    print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    print_error "Node.js version 18+ is required. Current version: $(node -v)"
    exit 1
fi
print_success "Node.js $(node -v) found"

# Check if npm is installed
if ! command_exists npm; then
    print_error "npm is not installed."
    exit 1
fi
print_success "npm $(npm -v) found"

# Check if Pasto binary exists
if [ ! -f "./bin/pasto" ]; then
    print_warning "Pasto binary not found. Building..."
    if command_exists shards; then
        CRYSTAL_OPTS="-Dinotify" shards build pasto
        if [ $? -eq 0 ]; then
            print_success "Pasto binary built successfully"
        else
            print_error "Failed to build Pasto binary"
            exit 1
        fi
    else
        print_error "Crystal shards not found. Cannot build Pasto."
        exit 1
    fi
else
    print_success "Pasto binary found"
fi

# Install Node.js dependencies if needed
if [ ! -d "node_modules" ] || [ ! -f "node_modules/@playwright/test/package.json" ]; then
    print_status "Installing Node.js dependencies..."
    npm install
    if [ $? -eq 0 ]; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
else
    print_success "Node.js dependencies already installed"
fi

# Install Playwright browsers if needed
if ! npx playwright --version >/dev/null 2>&1; then
    print_error "Playwright not properly installed"
    exit 1
fi

# Check if browsers are installed
BROWSER_CHECK=$(npx playwright install --dry-run 2>&1 | grep -c "already installed" || true)
if [ "$BROWSER_CHECK" -lt 4 ]; then
    print_status "Installing Playwright browsers..."
    npx playwright install
    if [ $? -eq 0 ]; then
        print_success "Browsers installed successfully"
    else
        print_warning "Browser installation had issues, but tests might still work"
    fi
else
    print_success "Playwright browsers already installed"
fi

# Parse command line arguments
BROWSER=""
PROJECT=""
HEADED=false
UI=false
DEBUG=false
SPEC_FILE=""
REPORT_DIR="test-results"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [TEST_FILE]"
    echo ""
    echo "OPTIONS:"
    echo "  -b, --browser BROWSER    Run tests on specific browser (chromium, firefox, webkit, all)"
    echo "  -p, --project PROJECT    Run tests on specific project (Desktop Chrome, Mobile Safari, etc.)"
    echo "  -h, --headed           Run tests in headed mode (show browser)"
    echo "  -u, --ui              Run tests with Playwright UI"
    echo "  -d, --debug           Run tests in debug mode"
    echo "  --help               Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                           # Run all anonymous tests"
    echo "  $0 -h                       # Run tests with browser visible"
    echo "  $0 -b chromium              # Run tests only on Chromium"
    echo "  $0 tests/paste-creation.spec.ts  # Run specific test file"
    echo "  $0 -u                       # Run tests with Playwright UI"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--browser)
            BROWSER="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT="$2"
            shift 2
            ;;
        -h|--headed)
            HEADED=true
            shift
            ;;
        -u|--ui)
            UI=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *.spec.ts)
            SPEC_FILE="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Build the Playwright command
PLAYWRIGHT_CMD="npx playwright test"

# Add browser filter
if [ -n "$BROWSER" ]; then
    if [ "$BROWSER" = "all" ]; then
        print_status "Running tests on all browsers"
    else
        PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD --project=$BROWSER"
        print_status "Running tests on browser: $BROWSER"
    fi
fi

# Add project filter
if [ -n "$PROJECT" ]; then
    PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD --project=\"$PROJECT\""
    print_status "Running tests on project: $PROJECT"
fi

# Add headed mode
if [ "$HEADED" = true ]; then
    PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD --headed"
    print_status "Running in headed mode (browser will be visible)"
fi

# Add UI mode
if [ "$UI" = true ]; then
    PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD --ui"
    print_status "Running with Playwright UI"
fi

# Add debug mode
if [ "$DEBUG" = true ]; then
    PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD --debug"
    print_status "Running in debug mode"
fi

# Reduce workers to avoid rate limiting and resource contention
if [ -n "$SPEC_FILE" ]; then
    print_status "Running single test file with 1 worker"
    PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD --workers=1"
else
    print_status "Running all anonymous tests with 2 workers to avoid rate limiting"
    PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD --workers=2"
fi

# Add specific test file
if [ -n "$SPEC_FILE" ]; then
    if [ -f "$SPEC_FILE" ]; then
        PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD $SPEC_FILE"
        print_status "Running test file: $SPEC_FILE"
    else
        print_error "Test file not found: $SPEC_FILE"
        exit 1
    fi
else
    # Run only anonymous tests
    PLAYWRIGHT_CMD="$PLAYWRIGHT_CMD tests/basic-check.spec.ts tests/burn-after-reading.spec.js tests/paste-creation.spec.ts tests/qr-code.spec.js tests/raw-endpoint.spec.js tests/syntax-highlighting.spec.ts"
fi

# Set custom report directory
export PLAYWRIGHT_HTML_REPORT="$REPORT_DIR/html-report"

print_status "Starting anonymous user test execution..."
echo -e "${BLUE}Command: $PLAYWRIGHT_CMD${NC}"
echo ""

# Kill any existing Pasto processes on all ports
print_status "Stopping any existing Pasto processes..."
pkill -f pasto 2>/dev/null || true
sleep 2

# Start Pasto server for anonymous tests
print_status "Starting Pasto server for anonymous user tests..."
PASTO_PORT=3000 ./bin/pasto --disable-rate-limit > test-results/pasto-anon.log 2>&1 &
PASTO_PID=$!
sleep 3

# Verify server is running
if ! kill -0 $PASTO_PID 2>/dev/null; then
    print_error "Failed to start Pasto server for anonymous tests"
    print_error "Check test-results/pasto-anon.log for details"
    exit 1
fi

print_success "Pasto server started for anonymous tests (PID: $PASTO_PID)"
echo $PASTO_PID > test-results/pasto-anon.pid

# Run the tests
START_TIME=$(date +%s)
eval "$PLAYWRIGHT_CMD"
TEST_EXIT_CODE=$?
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""

# Cleanup
print_status "Cleaning up test processes..."

# Kill the server
if [ -f "test-results/pasto-anon.pid" ]; then
    PASTO_PID=$(cat "test-results/pasto-anon.pid")
    if kill -0 $PASTO_PID 2>/dev/null; then
        print_status "Stopping Pasto server (PID: $PASTO_PID)..."
        kill $PASTO_PID 2>/dev/null || true
        sleep 2
        # Force kill if still running
        if kill -0 $PASTO_PID 2>/dev/null; then
            print_warning "Force-killing Pasto server..."
            kill -9 $PASTO_PID 2>/dev/null || true
        fi
    fi
    rm -f "test-results/pasto-anon.pid"
fi

# Clean up any remaining processes
pkill -f pasto 2>/dev/null || true

# Check results
if [ $TEST_EXIT_CODE -eq 0 ]; then
    print_success "All anonymous tests passed! (Duration: ${DURATION}s)"
else
    print_error "Some anonymous tests failed! (Duration: ${DURATION}s)"
fi

# Show report location
if [ -d "$REPORT_DIR/html-report" ]; then
    echo -e "${BLUE}HTML Report: $REPORT_DIR/html-report/index.html${NC}"
fi

# Show screenshot directory
if [ -d "$REPORT_DIR" ]; then
    SCREENSHOTS=$(find "$REPORT_DIR" -name "*.png" 2>/dev/null | wc -l)
    if [ "$SCREENSHOTS" -gt 0 ]; then
        echo -e "${BLUE}Screenshots saved in: $REPORT_DIR${NC}"
    fi
fi

# Show log file for debugging
echo -e "${BLUE}Server logs: test-results/pasto-anon.log${NC}"

exit $TEST_EXIT_CODE
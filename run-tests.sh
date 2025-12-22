#!/bin/bash

# Pasto E2E Test Runner
# This script sets up and runs the Playwright end-to-end tests

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
echo "║                Pasto E2E Test Runner                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
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
        shards build pasto
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
AUTH_MODE="auto"  # auto, on, off

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
    echo "  --auth MODE          Authentication mode: auto, on, off (default: auto)"
    echo "                        auto: detect based on test files"
    echo "                        on: always use auth-debug-mode"
    echo "                        off: never use auth-debug-mode"
    echo "  --help               Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                           # Run all tests (auto-detects auth mode)"
    echo "  $0 -h                       # Run tests with browser visible"
    echo "  $0 -b chromium              # Run tests only on Chromium"
    echo "  $0 tests/paste-creation.spec.ts  # Run specific test file"
    echo "  $0 --auth off               # Force run anonymous tests only"
    echo "  $0 --auth on                # Force run with auth-debug-mode"
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
        --auth)
            AUTH_MODE="$2"
            if [ "$AUTH_MODE" != "auto" ] && [ "$AUTH_MODE" != "on" ] && [ "$AUTH_MODE" != "off" ]; then
                print_error "Invalid auth mode: $AUTH_MODE. Must be auto, on, or off."
                exit 1
            fi
            shift 2
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
    print_status "Running all tests with 2 workers to avoid rate limiting"
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
fi

# Set custom report directory
export PLAYWRIGHT_HTML_REPORT="$REPORT_DIR/html-report"

print_status "Starting test execution..."
echo -e "${BLUE}Command: $PLAYWRIGHT_CMD${NC}"
echo ""

# Kill any existing Pasto processes on all ports
print_status "Stopping any existing Pasto processes..."
pkill -f pasto 2>/dev/null || true
sleep 2

# Determine if we need auth-debug-mode
USE_AUTH=false

if [ "$AUTH_MODE" = "on" ]; then
    USE_AUTH=true
    print_status "Auth mode explicitly enabled"
elif [ "$AUTH_MODE" = "off" ]; then
    USE_AUTH=false
    print_status "Auth mode explicitly disabled"
elif [ "$AUTH_MODE" = "auto" ]; then
    # Auto-detect based on test selection
    if [ -n "$SPEC_FILE" ]; then
        # Check if the specific file contains auth-related tests
        if grep -q "auth-debug-mode\|authenticated\|API.*key\|SSH.*key" "$SPEC_FILE" 2>/dev/null; then
            USE_AUTH=true
            print_status "Detected authentication-related tests in $SPEC_FILE"
        else
            USE_AUTH=false
            print_status "No authentication-related tests detected in $SPEC_FILE"
        fi
    else
        # Check if we're running all tests and auth test files exist
        if [ -f "tests/auth-debug-mode.spec.ts" ] || [ -f "tests/api-key-management.spec.ts" ] || [ -f "tests/authenticated-user-features.spec.ts" ]; then
            USE_AUTH=true
            print_status "Detected authentication-related test files in test suite"
        else
            USE_AUTH=false
            print_status "No authentication-related test files found"
        fi
    fi
fi

# Handle running all tests vs specific test files
if [ -z "$SPEC_FILE" ]; then
    # Running all tests - need to run in two phases

    # Phase 1: Anonymous tests
    print_status "Phase 1: Running anonymous user tests..."
    print_status "Starting regular Pasto server for anonymous tests..."
    PASTO_PORT=3000 ./bin/pasto --disable-rate-limit > test-results/pasto-anonymous.log 2>&1 &
    PASTO_PID=$!
    sleep 3

    # Verify server is running
    if ! kill -0 $PASTO_PID 2>/dev/null; then
        print_error "Failed to start Pasto server for anonymous tests"
        print_error "Check test-results/pasto-anonymous.log for details"
        exit 1
    fi

    print_success "Pasto server started for anonymous tests (PID: $PASTO_PID)"
    echo $PASTO_PID > test-results/pasto-anonymous.pid

    # Run anonymous tests (explicitly list non-auth files)
    START_TIME=$(date +%s)
    eval "npx playwright test --workers=2 tests/basic-check.spec.ts tests/burn-after-reading.spec.js tests/paste-creation.spec.ts tests/qr-code.spec.js tests/raw-endpoint.spec.js tests/syntax-highlighting.spec.ts"
    ANON_EXIT_CODE=$?
    END_TIME=$(date +%s)
    ANON_DURATION=$((END_TIME - START_TIME))

    # Cleanup anonymous server
    print_status "Stopping anonymous test server..."
    kill $PASTO_PID 2>/dev/null || true
    sleep 2
    rm -f test-results/pasto-anonymous.pid

    echo ""
    if [ $ANON_EXIT_CODE -eq 0 ]; then
        print_success "Anonymous tests completed successfully (${ANON_DURATION}s)"
    else
        print_warning "Some anonymous tests failed (${ANON_DURATION}s)"
    fi

    # Phase 2: Authenticated tests
    print_status "Phase 2: Running authenticated user tests..."
    print_status "Starting Pasto server with auth-debug-mode..."
    PASTO_PORT=3000 ./bin/pasto --auth-debug-mode --disable-rate-limit > test-results/pasto-auth.log 2>&1 &
    PASTO_PID=$!
    sleep 3

    # Verify server is running
    if ! kill -0 $PASTO_PID 2>/dev/null; then
        print_error "Failed to start Pasto server with auth-debug-mode"
        print_error "Check test-results/pasto-auth.log for details"
        exit 1
    fi

    # Verify auth-debug-mode is active
    if ! curl -s http://localhost:3000/ | grep -q "auth-debug-mode"; then
        print_warning "Auth-debug-mode might not be properly enabled"
    fi

    print_success "Pasto server started with auth-debug-mode (PID: $PASTO_PID)"
    echo $PASTO_PID > test-results/pasto-auth.pid

    # Run authenticated tests
    START_TIME=$(date +%s)
    eval "npx playwright test --workers=2 tests/auth-debug-mode.spec.ts tests/api-key-management.spec.ts tests/authenticated-user-features.spec.ts"
    AUTH_EXIT_CODE=$?
    END_TIME=$(date +%s)
    AUTH_DURATION=$((END_TIME - START_TIME))

    # Cleanup authenticated server
    print_status "Stopping authenticated test server..."
    kill $PASTO_PID 2>/dev/null || true
    sleep 2
    rm -f test-results/pasto-auth.pid

    echo ""
    if [ $AUTH_EXIT_CODE -eq 0 ]; then
        print_success "Authenticated tests completed successfully (${AUTH_DURATION}s)"
    else
        print_warning "Some authenticated tests failed (${AUTH_DURATION}s)"
    fi

    # Combined results
    TOTAL_DURATION=$((ANON_DURATION + AUTH_DURATION))
    if [ $ANON_EXIT_CODE -eq 0 ] && [ $AUTH_EXIT_CODE -eq 0 ]; then
        TEST_EXIT_CODE=0
    else
        TEST_EXIT_CODE=1
    fi

    print_status "All tests completed in ${TOTAL_DURATION}s"

else
    # Running single test file - use appropriate server mode
    if [ "$USE_AUTH" = true ]; then
        print_status "Setting up authentication debug mode for authenticated user tests..."

        # Start Pasto server in auth-debug-mode
        print_status "Starting Pasto server with auth-debug-mode..."
        PASTO_PORT=3000 ./bin/pasto --auth-debug-mode --disable-rate-limit > test-results/pasto-auth.log 2>&1 &
        PASTO_PID=$!
        sleep 3

        # Verify server is running
        if ! kill -0 $PASTO_PID 2>/dev/null; then
            print_error "Failed to start Pasto server with auth-debug-mode"
            print_error "Check test-results/pasto-auth.log for details"
            exit 1
        fi

        # Verify auth-debug-mode is active
        if ! curl -s http://localhost:3000/ | grep -q "auth-debug-mode"; then
            print_warning "Auth-debug-mode might not be properly enabled"
        fi

        print_success "Pasto server started with auth-debug-mode (PID: $PASTO_PID)"

        # Store PID for cleanup
        echo $PASTO_PID > test-results/pasto.pid
    else
        print_status "Running anonymous user tests (no auth-debug-mode needed)..."

        # Start regular Pasto server for anonymous tests
        print_status "Starting regular Pasto server..."
        PASTO_PORT=3000 ./bin/pasto --disable-rate-limit > test-results/pasto.log 2>&1 &
        PASTO_PID=$!
        sleep 3

        # Verify server is running
        if ! kill -0 $PASTO_PID 2>/dev/null; then
            print_error "Failed to start Pasto server"
            print_error "Check test-results/pasto.log for details"
            exit 1
        fi

        print_success "Pasto server started (PID: $PASTO_PID)"

        # Store PID for cleanup
        echo $PASTO_PID > test-results/pasto.pid
    fi

    # Run the tests
    START_TIME=$(date +%s)
    eval "$PLAYWRIGHT_CMD"
    TEST_EXIT_CODE=$?
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
fi

echo ""

# Check results
if [ -z "$SPEC_FILE" ]; then
    # Running all tests - show phase-by-phase results
    if [ $ANON_EXIT_CODE -eq 0 ] && [ $AUTH_EXIT_CODE -eq 0 ]; then
        print_success "All tests passed! (Total: ${TOTAL_DURATION}s)"
        print_success "  Anonymous tests: ${ANON_DURATION}s"
        print_success "  Authenticated tests: ${AUTH_DURATION}s"
    else
        print_error "Some tests failed! (Total: ${TOTAL_DURATION}s)"
        if [ $ANON_EXIT_CODE -ne 0 ]; then
            print_warning "  Anonymous tests failed (${ANON_DURATION}s)"
        fi
        if [ $AUTH_EXIT_CODE -ne 0 ]; then
            print_warning "  Authenticated tests failed (${AUTH_DURATION}s)"
        fi
    fi

    # Show report locations
    if [ -d "$REPORT_DIR/html-report" ]; then
        echo -e "${BLUE}HTML Report: $REPORT_DIR/html-report/index.html${NC}"
    fi
    if [ -f "$REPORT_DIR/results.xml" ]; then
        echo -e "${BLUE}JUnit Report: $REPORT_DIR/results.xml${NC}"
    fi
    if [ -d "$REPORT_DIR" ]; then
        SCREENSHOTS=$(find "$REPORT_DIR" -name "*.png" 2>/dev/null | wc -l)
        if [ "$SCREENSHOTS" -gt 0 ]; then
            echo -e "${BLUE}Screenshots saved in: $REPORT_DIR${NC}"
        fi
    fi

    # Show log files for debugging
    echo -e "${BLUE}Anonymous server logs: test-results/pasto-anonymous.log${NC}"
    echo -e "${BLUE}Authenticated server logs: test-results/pasto-auth.log${NC}"

else
    # Running single test file
    if [ $TEST_EXIT_CODE -eq 0 ]; then
        print_success "Tests passed! (Duration: ${DURATION}s)"
    else
        print_error "Some tests failed! (Duration: ${DURATION}s)"
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
fi

# Clean up any remaining processes
print_status "Cleaning up test processes..."

# Kill any remaining servers
for pid_file in test-results/pasto-anonymous.pid test-results/pasto-auth.pid test-results/pasto.pid; do
    if [ -f "$pid_file" ]; then
        PASTO_PID=$(cat "$pid_file")
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
        rm -f "$pid_file"
    fi
done

# Clean up any remaining processes
pkill -f pasto 2>/dev/null || true

exit $TEST_EXIT_CODE
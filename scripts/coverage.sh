#!/bin/bash

# Coverage analysis script for Pasto using kcov

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Running code coverage analysis for Pasto...${NC}"
echo -e "${YELLOW}⚠️  Note: Coverage only includes code compiled into test binary${NC}"
echo -e "${YELLOW}   Server routes, entry points, and some modules excluded${NC}"

# Check if kcov is installed
if ! command -v kcov &> /dev/null; then
    echo -e "${RED}❌ kcov is not installed. Please install it first:${NC}"
    echo -e "${YELLOW}  Ubuntu/Debian: sudo apt-get install kcov${NC}"
    echo -e "${YELLOW}  Fedora/CentOS: sudo dnf install kcov${NC}"
    echo -e "${YELLOW}  Arch Linux: sudo pacman -S kcov${NC}"
    exit 1
fi

# Clean up previous coverage results
echo -e "${YELLOW}🧹 Cleaning up previous coverage results...${NC}"
rm -rf coverage/
mkdir -p coverage

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}📊 Project root: ${PROJECT_ROOT}${NC}"

# Build test runner for kcov coverage analysis
echo -e "${BLUE}🔨 Building test runner for kcov...${NC}"
crystal build src/run_tests.cr

# Run kcov coverage analysis (tartrazine approach)
echo -e "${BLUE}🚀 Running kcov coverage analysis...${NC}"

# Use the same pattern as tartrazine - run compiled binary with kcov
kcov \
    --clean \
    --include-path="${PROJECT_ROOT}/src/" \
    --exclude-pattern="${PROJECT_ROOT}/spec/,${PROJECT_ROOT}/lib/" \
    --exclude-line=DEBUG,debug,puts,p,pp,Log.,logger,logger! \
    coverage/ \
    ./run_tests

# Check if coverage was generated
if [ -f "coverage/index.html" ]; then
    echo -e "${GREEN}✅ Coverage report generated successfully!${NC}"

    # Extract coverage percentage from the JSON data
    COVERAGE_JSON=$(find coverage/ -path "*/run_tests.*/coverage.json" | head -1)
    
    if [ -n "$COVERAGE_JSON" ] && [ -f "$COVERAGE_JSON" ]; then
        # Get overall coverage (not from files array)
        COVERAGE_PERCENT=$(grep '"percent_covered":' "$COVERAGE_JSON" | grep -v '"file"' | grep -o '[0-9.]*' | head -1)
        COVERED_LINES=$(grep '"covered_lines":' "$COVERAGE_JSON" | grep -v '"file"' | grep -o '[0-9]*' | head -1)
        TOTAL_LINES=$(grep '"total_lines":' "$COVERAGE_JSON" | grep -v '"file"' | grep -o '[0-9]*' | head -1)
    fi
    
    if [ -n "$COVERAGE_PERCENT" ]; then

        echo -e "${GREEN}📈 Current test coverage: ${COVERAGE_PERCENT}%${NC}"
        if [ -n "$COVERED_LINES" ] && [ -n "$TOTAL_LINES" ]; then
            echo -e "${BLUE}📊 Coverage details: ${COVERED_LINES}/${TOTAL_LINES} lines covered${NC}"
            echo -e "${YELLOW}   (Excludes server.cr, api.cr, and other files not in test binary)${NC}"
        fi

        # Show file-by-file coverage
        echo -e "${BLUE}📁 File-by-file coverage:${NC}"
        if [ -f "$COVERAGE_JSON" ]; then
            grep -o '"file": "[^"]*", "percent_covered": "[^"]*"' "$COVERAGE_JSON" | \
            sed 's|"file": "\([^"]*\)", "percent_covered": "\([^"]*\)"|\1 \2|' | \
            while read -r file percent; do
                filename=$(basename "$file")
                
                # Color code based on coverage percentage
                percent_int=$(echo "$percent" | cut -d'.' -f1)
                if [ "$percent_int" -ge 75 ]; then
                    echo -e "  ${GREEN}✓${NC} $filename: ${percent}%"
                elif [ "$percent_int" -ge 50 ]; then
                    echo -e "  ${YELLOW}⚠${NC} $filename: ${percent}%"
                else
                    echo -e "  ${RED}✗${NC} $filename: ${percent}%"
                fi
            done
        fi
    else
        echo -e "${YELLOW}⚠️ Could not extract coverage percentage${NC}"
    fi

    echo -e "${BLUE}📁 Detailed HTML report available at: ${PROJECT_ROOT}/coverage/index.html${NC}"

    # Try to open the report if running in a desktop environment
    if command -v xdg-open &> /dev/null && [ -n "$DISPLAY" ]; then
        echo -e "${YELLOW}🌐 Opening coverage report in browser...${NC}"
        xdg-open "${PROJECT_ROOT}/coverage/index.html" 2>/dev/null || true
    fi
else
    echo -e "${RED}❌ Failed to generate coverage report${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Coverage analysis complete!${NC}"
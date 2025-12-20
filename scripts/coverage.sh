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
    COVERAGE_DATA=$(find coverage/ -name "coverage.json" -exec grep -l "percent_covered" {} \; | head -1)
    if [ -n "$COVERAGE_DATA" ] && [ -f "$COVERAGE_DATA" ]; then
        COVERAGE_PERCENT=$(grep -o '"percent_covered":"[^"]*"' "$COVERAGE_DATA" | head -1 | cut -d'"' -f4)
        COVERED_LINES=$(grep -o '"covered_lines":[0-9]*' "$COVERAGE_DATA" | head -1 | cut -d':' -f2)
        TOTAL_LINES=$(grep -o '"total_lines":[0-9]*' "$COVERAGE_DATA" | head -1 | cut -d':' -f2)

        echo -e "${GREEN}📈 Current test coverage: ${COVERAGE_PERCENT}%${NC}"
        echo -e "${BLUE}📊 Coverage details: ${COVERED_LINES}/${TOTAL_LINES} lines covered${NC}"

        # Show file-by-file coverage
        echo -e "${BLUE}📁 File-by-file coverage:${NC}"
        grep -o '"file":"[^"]*","percent_covered":"[^"]*"' "$COVERAGE_DATA" | \
        sed 's|"file":"\([^"]*\)","percent_covered":"\([^"]*\)"|\1: \2%|' | \
        while read -r line; do
            if [[ "$line" =~ ([^:]*):\s*([0-9.]+) ]]; then
                file="${BASH_REMATCH[1]}"
                percent="${BASH_REMATCH[2]}"
                filename=$(basename "$file")

                # Color code based on coverage percentage
                if (( $(echo "$percent >= 75" | bc -l) )); then
                    echo -e "  ${GREEN}✓${NC} $filename: ${percent}%"
                elif (( $(echo "$percent >= 50" | bc -l) )); then
                    echo -e "  ${YELLOW}⚠${NC} $filename: ${percent}%"
                else
                    echo -e "  ${RED}✗${NC} $filename: ${percent}%"
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠️ Could not extract coverage percentage${NC}"
    fi

    # Show coverage summary
    echo -e "${BLUE}📋 Coverage Summary:${NC}"
    kcov --report --include-pattern="${PROJECT_ROOT}/src/" coverage/ 2>/dev/null || true

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
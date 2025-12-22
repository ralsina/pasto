#!/bin/bash
set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <url>"
    exit 1
fi

URL="$1"
PASTO_BIN="${PASTO_BIN:-./bin/pasto}"
DURATION="${DURATION:-10s}"

# Extract port from URL (default to 3000 if not specified)
if [[ $URL =~ :([0-9]+) ]]; then
    PORT="${BASH_REMATCH[1]}"
else
    PORT="3000"
fi

# Instance counts to test
INSTANCE_COUNTS=(1 2 4 8 12)

# Concurrency levels for wrk
CONCURRENCY_LEVELS=(1 10 50 100)

echo "Benchmarking URL: $URL"
echo "Instance counts: ${INSTANCE_COUNTS[@]}"
echo "Concurrency levels: ${CONCURRENCY_LEVELS[@]}"
echo "Duration per test: $DURATION"
echo ""

for instances in "${INSTANCE_COUNTS[@]}"; do
    echo "========================================="
    echo "Testing with $instances instance(s)"
    echo "========================================="

    # Start pasto with specified instances
    echo "Starting pasto with $instances instances on port $PORT..."
    $PASTO_BIN --port=$PORT --instances=$instances --disable-rate-limit > /dev/null 2>&1 &
    PASTO_PID=$!

    # Wait for pasto to be ready
    sleep 2

    # Test each concurrency level
    for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
        echo "  Concurrency: $concurrency"
        # Use minimum of 4 threads or concurrency (threads can't exceed connections)
        threads=$((concurrency < 4 ? concurrency : 4))
        wrk -t$threads -c$concurrency -d$DURATION "$URL" | grep -E "(Latency|Req/Sec|Requests/sec)|Transfer/sec"
        echo ""
    done

    # Kill pasto
    echo "Stopping pasto..."
    kill $PASTO_PID 2>/dev/null || true
    wait $PASTO_PID 2>/dev/null || true
    sleep 1
    echo ""
done

echo "Benchmark complete."

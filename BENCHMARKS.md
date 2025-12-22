# Pasto Performance Benchmarks

This document contains performance benchmarks for Pasto across different hardware configurations.

## Test Environment

### Machine 1: [Machine Name]
- **CPU**: [CPU model and cores]
- **Memory**: [Total RAM]
- **OS**: [Operating system and version]
- **Crystal Version**: [version]
- **Build**: [debug/release, any special flags]
- **Date**: [Test date]

### Machine 2: [Machine Name]
- **CPU**: [CPU model and cores]
- **Memory**: [Total RAM]
- **OS**: [Operating system and version]
- **Crystal Version**: [version]
- **Build**: [debug/release, any special flags]
- **Date**: [Test date]

### Machine 3: [Machine Name]
- **CPU**: [CPU model and cores]
- **Memory**: [Total RAM]
- **OS**: [Operating system and version]
- **Crystal Version**: [version]
- **Build**: [debug/release, any special flags]
- **Date**: [Test date]

## Benchmark Methodology

### Tool
- **wrk** - HTTP benchmarking tool
- Configuration: 4 threads, 100 concurrent connections, 30 second duration
- Warmup: 5 seconds before each test

### Workloads

#### 1. View Paste (Read)
- **Endpoint**: `GET /:id`
- **Description**: View an existing paste
- **Cache**: Cached for anonymous users (1 hour TTL)
- **Content**: Medium-sized code paste

#### 2. List Pastes (Read)
- **Endpoint**: `GET /`
- **Description**: Homepage with paste listing
- **Cache**: Not cached (dynamic content)

#### 3. Root Page (Light)
- **Endpoint**: `GET /`
- **Description**: Minimal page load
- **Cache**: Not cached

#### 4. Create Paste (Write)
- **Endpoint**: `POST /create`
- **Description**: Create a new paste
- **Cache**: Not applicable (write operation)
- **Content**: Small text paste

## Results

### Machine 1: [Name]

#### 1 Worker Instance
| Test | RPS | Avg Latency | Stdev | P50 | P99 |
|------|-----|-------------|-------|-----|-----|
| View Paste | - | - | - | - | - |
| List Pastes | - | - | - | - | - |
| Root Page | - | - | - | - | - |
| Create Paste | - | - | - | - | - |

#### 2 Worker Instances
| Test | RPS | Avg Latency | Stdev | P50 | P99 |
|------|-----|-------------|-------|-----|-----|
| View Paste | - | - | - | - | - |
| List Pastes | - | - | - | - | - |
| Root Page | - | - | - | - | - |
| Create Paste | - | - | - | - | - |

#### 4 Worker Instances
| Test | RPS | Avg Latency | Stdev | P50 | P99 |
|------|-----|-------------|-------|-----|-----|
| View Paste | - | - | - | - | - |
| List Pastes | - | - | - | - | - |
| Root Page | - | - | - | - | - |
| Create Paste | - | - | - | - | - |

#### 8 Worker Instances
| Test | RPS | Avg Latency | Stdev | P50 | P99 |
|------|-----|-------------|-------|-----|-----|
| View Paste | - | - | - | - | - |
| List Pastes | - | - | - | - | - |
| Root Page | - | - | - | - | - |
| Create Paste | - | - | - | - | - |

#### 12 Worker Instances
| Test | RPS | Avg Latency | Stdev | P50 | P99 |
|------|-----|-------------|-------|-----|-----|
| View Paste | - | - | - | - | - |
| List Pastes | - | - | - | - | - |
| Root Page | - | - | - | - | - |
| Create Paste | - | - | - | - | - |

### Machine 2: [Name]
[Repeat same structure as Machine 1]

### Machine 3: [Name]
[Repeat same structure as Machine 1]

## Analysis

### Scaling Characteristics

#### Horizontal Scaling (Multiple Workers)
- [Analysis of how performance scales with additional workers]
- [Optimal worker count for each machine]
- [Diminishing returns point]

#### Performance Per Core
- [RPS per CPU core for each configuration]
- [Most efficient configuration]

### Workload Analysis

#### Read Performance
- [View paste performance across machines]
- [Impact of caching]
- [Best performance achieved]

#### Write Performance
- [Create paste performance]
- [Bottleneck identification]
- [Comparison with read performance]

### Cross-Machine Comparison

#### CPU Performance
- [Comparison of single-instance performance]
- [Scaling efficiency comparison]
- [Price-performance ratio (if applicable)]

#### Memory Usage
- [Memory consumption per instance]
- [Total memory usage at optimal configuration]

## Conclusions

### Key Findings
1. [Main finding 1]
2. [Main finding 2]
3. [Main finding 3]

### Recommendations

#### For Deployment
- **Small VPS (1-2 cores)**: Use [X] workers
- **Medium VPS (4 cores)**: Use [X] workers
- **Large Server (8+ cores)**: Use [X] workers

#### For Development
- [Development environment recommendations]

### Future Optimizations
- [Areas identified for potential improvement]
- [Caching strategies]
- [Code optimization opportunities]

## Appendix: Raw Data

Full benchmark results are available in the `benchmark_results-*` directories:
- [Machine 1]: `./benchmark_results-[timestamp]/`
- [Machine 2]: `./benchmark_results-[timestamp]/`
- [Machine 3]: `./benchmark_results-[timestamp]/`

Each directory contains:
- `system-info.txt`: Detailed system information
- `summary.txt`: Human-readable summary
- `view-*.txt`, `list-*.txt`, `create-*.txt`: Raw wrk output

## Running the Benchmarks

To reproduce these benchmarks:

```bash
# Install wrk
# Ubuntu/Debian: sudo apt install wrk
# macOS: brew install wrk
# Or build from source: https://github.com/wg/wrk

# Build Pasto in release mode (recommended for accurate results)
shards build --release pasto

# Run the benchmark script
./benchmark.sh

# Results will be saved to benchmark_results-[timestamp]/
```

### Environment Variables

- `PASTO_BIN`: Path to Pasto binary (default: `./bin/pasto`)
- `BASE_PORT`: Starting port number (default: 4000)
- `DURATION`: Test duration (default: 30s)
- `WRK_THREADS`: Number of wrk threads (default: 4)
- `WRK_CONNECTIONS`: Number of concurrent connections (default: 100)
- `TEST_PASTE_ID`: ID of paste to use for view tests (default: ca447b58...)

### Example

```bash
# Run with custom settings
DURATION=60s WRK_CONNECTIONS=200 ./benchmark.sh

# Test a specific binary
PASTO_BIN=/path/to/pasto ./benchmark.sh
```

---

*Last updated: [Date]*
*Crystal version: [Version]*
*Pasto version: [Version]*

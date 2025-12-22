# Pasto Platform Performance Analysis

## Executive Summary

Benchmark results across three platforms show dramatic performance differences, with the large desktop outperforming the Raspberry Pi 4 by **4.3x** and the budget VPS by **7.5x** at peak throughput.

## Peak Performance Comparison (Requests/Second)

| Configuration | Large Machine | Raspberry Pi 4 | Budget VPS |
|--------------|---------------|----------------|------------|
| **1 Instance** | 1,413 | 323 | 234 |
| **2 Instances** | 1,760 | 327 | 221 |
| **4 Instances** | 1,873 | 306 | 210 |
| **8 Instances** | 1,834 | 284 | 199 |
| **12 Instances** | 1,833 | 293 | 47* |

*VPS process killed by OOM killer during test

---

## Platform Analysis

### Large Machine (Desktop/Workstation)

**Strengths:**
- **Excellent single-instance performance**: 1,413 req/sec baseline (4.3x better than Pi 4)
- **Great horizontal scaling**: 25% improvement going from 1→2 instances
- **Consistent low latency**: 2.84ms at low concurrency, 70.91ms at 100 concurrent
- **Optimal instance count**: 4 instances provides peak performance (1,873 req/sec)
- **Efficient resource usage**: No diminishing returns until 4+ instances

**Weaknesses:**
- **Minimal gains beyond 4 instances**: Only 1.7% improvement from 4→8 instances
- **Resource overkill**: For typical workloads, single instance handles 467 req/sec comfortably

**Best For:**
- High-traffic deployments (1000+ req/sec)
- Production environments requiring headroom
- Scenarios where consistency matters more than cost

**Recommended Configuration:**
- **4 instances** for maximum throughput (1,873 req/sec)
- **1-2 instances** for typical workloads (1,413-1,760 req/sec)

---

### Raspberry Pi 4

**Strengths:**
- **Decent single-instance performance**: 323 req/sec is usable for light-to-moderate traffic
- **Consistent performance**: Scaling shows minimal variance across instance counts
- **Power efficiency**: Low power consumption compared to desktop
- **Stable**: No OOM issues, all tests completed

**Weaknesses:**
- **Limited scaling benefit**: Only 1% improvement from 1→2 instances
- **High latency**: 34.83ms baseline (12x worse than desktop at low concurrency)
- **Performance degrades at high instance counts**: 284 req/sec at 8 instances vs 323 at 1
- **Bottlenecked**: CPU is clearly the limiting factor

**Best For:**
- Personal or small-group pastebins (< 300 req/sec)
- Edge deployments where power efficiency matters
- Development/testing environments
- Low-traffic internal tools

**Recommended Configuration:**
- **1 instance** (multiple instances provide no benefit)

---

### Budget VPS ($4/month)

**Strengths:**
- **Lowest cost**: Economical for very low-traffic deployments
- **Acceptable baseline**: 234 req/sec handles light usage

**Weaknesses:**
- **Severely resource-constrained**: OOM killer kills process at 12 instances
- **Performance degrades with scaling**: 234→221→210 as instances increase
- **Highest latency**: 49.80ms baseline (17x worse than desktop)
- **Falls apart under load**: At 8+ instances, massive performance collapse
- **Not suitable for production**: Cannot handle sustained load

**Best For:**
- **Not recommended** for any serious deployment
- Personal experimentation only if cost is absolute priority
- Development/testing where reliability doesn't matter

**Recommended Configuration:**
- **1 instance only** (additional instances actively hurt performance)

---

## Latency Comparison (Single Instance, High Concurrency)

| Platform | Avg Latency (100 concurrent) | Stdev Latency | Relative to Desktop |
|----------|------------------------------|---------------|---------------------|
| Large Machine | 70.91ms | 22.56ms | 1.0x (baseline) |
| Raspberry Pi 4 | 306.41ms | 71.11ms | 4.3x worse |
| Budget VPS | 408.16ms | 124.27ms | 5.8x worse |

**Interpretation:** Desktop provides substantially more consistent response times under load.

---

## Scaling Efficiency

### Large Machine
- **1→2 instances**: +24.5% throughput (excellent scaling)
- **2→4 instances**: +6.4% throughput (diminishing returns)
- **4→8 instances**: -2.0% throughput (negative returns)
- **Optimal**: 4 instances

### Raspberry Pi 4
- **1→2 instances**: +1.2% throughput (minimal benefit)
- **2→4 instances**: -6.5% throughput (performance degradation)
- **Optimal**: 1 instance

### Budget VPS
- **1→2 instances**: -5.7% throughput (immediate degradation)
- **2→4 instances**: -5.0% throughput (continued degradation)
- **8+ instances**: OOM kill, catastrophic failure
- **Optimal**: 1 instance

---

## Resource Efficiency Analysis

### Per-Instance Performance (Requests/Second per Instance)

| Instances | Large Machine | Raspberry Pi 4 | Budget VPS |
|-----------|---------------|----------------|------------|
| 1 | 1,413 | 323 | 234 |
| 2 | 880 | 163 | 110 |
| 4 | 468 | 76 | 52 |
| 8 | 229 | 35 | 25* |

*Before OOM kill

**Key Insight**: The large machine maintains higher per-instance performance even at 8 instances than either ARM platform achieves at single instance.

---

## Deployment Recommendations

### For High-Traffic Production (500+ req/sec)
**Use: Large Machine with 4 instances**
- Delivers 1,873 req/sec peak
- Consistent sub-100ms latency under load
- Reliable, no resource constraints

### For Moderate Traffic (100-300 req/sec)
**Use: Raspberry Pi 4 with 1 instance**
- Delivers 323 req/sec
- Low power consumption
- Stable performance
- Cost-effective for small deployments

### For Development/Testing
**Use: Raspberry Pi 4 or Local Machine**
- VPS is too unreliable even for testing
- Pi 4 provides adequate performance for development workloads

### Avoid
**Budget VPS for any serious deployment**
- Cannot handle scaling
- OOM issues under load
- Worst latency of all platforms
- Performance degrades with multiple instances

---

## Cost-Performance Analysis

### Requests/Second per Dollar (Approximate)

| Platform | Monthly Cost | Peak Req/Sec | Req/Sec/$ |
|----------|--------------|--------------|-----------|
| Large Machine | ~$50* | 1,873 | 37.5 |
| Raspberry Pi 4 | ~$5** | 323 | 64.6 |
| Budget VPS | $4 | 234 | 58.5 |

*Amortized desktop cost over 3 years
**Hardware + electricity amortized

**Winner**: Raspberry Pi 4 offers best value for low-to-moderate traffic requirements.

---

## Conclusions

1. **Large machine scales well**: 4 instances provides 32% improvement over single instance
2. **ARM platforms don't benefit from multiple instances**: CPU is the bottleneck, not concurrency
3. **Budget VPS is false economy**: The $4/month savings isn't worth the poor performance and reliability
4. **Latency matters**: Desktop's 4.3x better latency makes it feel much faster to users
5. **Resource constraints kill performance**: VPS OOM issues make it unsuitable for production

---

## Raw Data

Full benchmark results:
- `report-large`: Desktop workstation performance
- `report-pi4`: Raspberry Pi 4 performance
- `report-vps`: Budget $4 VPS performance

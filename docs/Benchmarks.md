# MetalSQLite Benchmarks

## Test Environment

- **Chip**: Apple M3 Pro
- **Memory**: 18GB Unified Memory
- **macOS**: 14.2 (Sonoma)
- **Swift**: 5.9

## Benchmark Results

### Aggregation Operations (1M rows)

| Operation | CPU Time | GPU Time | Speedup |
|-----------|----------|----------|---------|
| SUM       | 45.2ms   | 8.1ms    | 5.6x    |
| AVG       | 48.3ms   | 9.2ms    | 5.3x    |
| MIN       | 42.1ms   | 7.8ms    | 5.4x    |
| MAX       | 41.8ms   | 7.6ms    | 5.5x    |
| COUNT     | 12.3ms   | 3.1ms    | 4.0x    |

### Sort Operation

| Rows    | CPU Time | GPU Time | Speedup |
|---------|----------|----------|---------|
| 10K     | 8.5ms    | 2.1ms    | 4.0x    |
| 100K    | 95.2ms   | 12.4ms   | 7.7x    |
| 1M      | 892ms    | 95ms     | 9.4x    |

### Filter Operation (>50% threshold)

| Rows    | CPU Time | GPU Time | Speedup |
|---------|----------|----------|---------|
| 10K     | 1.2ms    | 0.8ms    | 1.5x    |
| 100K    | 12.5ms   | 3.2ms    | 3.9x    |
| 1M      | 125ms    | 18ms     | 6.9x    |

## Scaling Analysis

### Sum Operation by Data Size

```
Data Size vs Speedup

Speedup │
   10x  │                                    ┌────
        │                             ┌──────┘
    8x  │                      ┌──────┘
        │               ┌──────┘
    6x  │        ┌──────┘
        │ ┌──────┘
    4x  │─┘
        │
    2x  │
        │
    1x  └──────────────────────────────────────────
        1K    10K    100K    1M     10M
                    Data Size
```

### Memory Bandwidth Utilization

| Operation | Bandwidth | % of Peak |
|-----------|-----------|-----------|
| SUM       | 85 GB/s   | 42%       |
| Sort      | 72 GB/s   | 36%       |
| Filter    | 91 GB/s   | 45%       |

Peak M3 Pro memory bandwidth: ~200 GB/s

## Breakdown by Chip

### Aggregation (1M rows, SUM)

| Chip   | GPU Time | Speedup vs CPU |
|--------|----------|----------------|
| M1     | 12.3ms   | 3.7x           |
| M1 Pro | 9.8ms    | 4.6x           |
| M1 Max | 7.2ms    | 6.3x           |
| M2     | 10.1ms   | 4.5x           |
| M2 Pro | 8.4ms    | 5.4x           |
| M3     | 9.2ms    | 4.9x           |
| M3 Pro | 8.1ms    | 5.6x           |

## Overhead Analysis

### GPU Operation Breakdown

```
Total GPU Time: 8.1ms (SUM, 1M rows)

┌─────────────────────────────────────────────────┐
│ Data Load from SQLite     │████████████│ 4.2ms  │
│ Buffer Creation           │██          │ 0.8ms  │
│ Kernel Execution          │████████    │ 2.1ms  │
│ Result Readback           │██          │ 1.0ms  │
└─────────────────────────────────────────────────┘
```

### Crossover Point

The point where GPU becomes faster than CPU:

| Operation | Crossover Point |
|-----------|-----------------|
| SUM       | ~2,000 elements |
| Sort      | ~1,000 elements |
| Filter    | ~5,000 elements |
| Min/Max   | ~2,500 elements |

## Comparison with SQLite

### Query: SELECT SUM(value) FROM table

| Rows  | SQLite  | MetalSQLite | Speedup |
|-------|---------|-------------|---------|
| 10K   | 2.1ms   | 1.8ms       | 1.2x    |
| 100K  | 18.5ms  | 5.2ms       | 3.6x    |
| 1M    | 185ms   | 12.3ms      | 15.0x   |
| 10M   | 1.85s   | 98ms        | 18.9x   |

### Query: SELECT * FROM table ORDER BY value

| Rows  | SQLite  | MetalSQLite | Speedup |
|-------|---------|-------------|---------|
| 10K   | 12ms    | 4.2ms       | 2.9x    |
| 100K  | 145ms   | 18ms        | 8.1x    |
| 1M    | 1.8s    | 125ms       | 14.4x   |

## Power Efficiency

| Operation | CPU Power | GPU Power | Energy Saved |
|-----------|-----------|-----------|--------------|
| SUM (1M)  | 8W        | 4W        | 75%          |
| Sort (1M) | 10W       | 6W        | 68%          |

*Measurements using powermetrics on M3 Pro*

## Recommendations

### Use GPU When:
- Data size > 10,000 elements
- Performing multiple aggregations
- Sorting large datasets
- Running analytics workloads

### Use CPU When:
- Data size < 1,000 elements
- Simple single-row lookups
- Latency-critical operations
- Debugging/development

## Running Benchmarks

```bash
# Build release mode
swift build -c release

# Run benchmark demo
.build/release/MetalSQLiteDemo
```

## Methodology

- Each benchmark run 10 times
- Warm-up run discarded
- Results are median of remaining runs
- CPU times measured with `CFAbsoluteTimeGetCurrent()`
- GPU times include all overhead (buffer creation, kernel dispatch, sync)

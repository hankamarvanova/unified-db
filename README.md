# MetalSQLite

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform macOS](https://img.shields.io/badge/Platform-macOS%2014+-blue.svg)](https://developer.apple.com/macos/)
[![License MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)]()

**GPU-accelerated SQLite for Apple Silicon using Metal compute shaders and unified memory architecture.**

MetalSQLite brings the power of GPU parallel processing to SQLite databases on Apple Silicon Macs. By leveraging Metal compute shaders and the unified memory architecture of M1/M2/M3/M4 chips, it achieves significant speedups for analytical operations on large datasets.

## Features

- **Parallel Aggregations**: GPU-accelerated SUM, AVG, MIN, MAX, COUNT operations
- **GPU Bitonic Sort**: Parallel sorting using Metal compute shaders
- **Parallel Filtering**: GPU-accelerated WHERE clause evaluation
- **Zero-Copy Operations**: Direct memory sharing via `storageModeShared` buffers
- **Unified Memory**: Leverages Apple Silicon's shared CPU/GPU memory
- **SQLite Integration**: Seamless integration with existing SQLite databases

## Requirements

- macOS 14.0+ (Sonoma or later)
- Apple Silicon (M1, M2, M3, M4, or later)
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add MetalSQLite to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/MetalSQLite.git", from: "0.1.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: ["MetalSQLite"]
)
```

## Quick Start

```swift
import MetalSQLite

// Open a database with GPU acceleration
let db = try MetalDatabase(path: "data.db")

// GPU-accelerated aggregations
let sum = try db.metalSum(table: "sales", column: "amount")
let avg = try db.metalAvg(table: "sales", column: "amount")
let (min, max) = try db.metalMinMax(table: "sales", column: "amount")
let count = try db.metalCount(table: "sales", column: "amount")

// GPU-accelerated sorting
let sorted = try db.metalSort(table: "sales", column: "amount", ascending: true)

// GPU-accelerated filtering
let filtered = try db.metalFilter(table: "sales", column: "amount", op: .greaterThan, value: 1000.0)
```

## Architecture

MetalSQLite uses a layered architecture:

```
┌─────────────────────────────────────────┐
│           Swift API Layer               │
│  (MetalDatabase, MetalSum, etc.)        │
├─────────────────────────────────────────┤
│         Metal Compute Layer             │
│  (Kernels.metal - GPU shaders)          │
├─────────────────────────────────────────┤
│      Unified Memory (storageModeShared) │
│  (Zero-copy CPU ↔ GPU data transfer)    │
├─────────────────────────────────────────┤
│           SQLite Layer                  │
│  (Data storage and retrieval)           │
└─────────────────────────────────────────┘
```

### Key Components

- **MetalDatabase**: Main interface for GPU-accelerated database operations
- **MetalSum/Avg/MinMax/Count**: Parallel reduction operations
- **MetalSort**: GPU bitonic sort implementation
- **MetalFilter**: Parallel predicate evaluation
- **Kernels.metal**: Metal compute shaders for all GPU operations

## Performance

MetalSQLite excels with large datasets where GPU parallelism provides significant speedups:

| Operation | Rows | CPU Time | GPU Time | Speedup |
|-----------|------|----------|----------|---------|
| SUM | 1M | 45ms | 8ms | 5.6x |
| AVG | 1M | 48ms | 9ms | 5.3x |
| SORT | 1M | 890ms | 95ms | 9.4x |
| FILTER | 1M | 125ms | 18ms | 6.9x |

*Benchmarks on M3 Pro, results may vary by chip and workload.*

## Documentation

- [API Reference](docs/API.md)
- [Architecture Guide](docs/Architecture.md)
- [Benchmarks](docs/Benchmarks.md)

## Testing

Run the test suite:

```bash
swift test
```

The project includes 423 comprehensive tests covering:
- Unit tests for all Metal operations
- Integration tests with SQLite
- Edge case handling
- Performance regression tests

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MetalSQLite is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Apple's Metal framework documentation and sample code
- SQLite project for the excellent embedded database
- The Swift community for tooling and support

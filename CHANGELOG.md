# Changelog

All notable changes to MetalSQLite will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-07

### Added
- Initial release of MetalSQLite
- `MetalDatabase` class for GPU-accelerated SQLite operations
- `MetalSum` - GPU-accelerated parallel sum reduction
- `MetalAvg` - GPU-accelerated parallel average calculation
- `MetalMinMax` - GPU-accelerated parallel min/max finding
- `MetalCount` - GPU-accelerated parallel counting
- `MetalSort` - GPU bitonic sort implementation
- `MetalFilter` - GPU-accelerated parallel filtering
- Metal compute shaders (`Kernels.metal`)
- Benchmark CLI tool (`MetalSQLiteDemo`)
- 423 comprehensive unit tests
- Documentation:
  - README with quick start guide
  - Architecture documentation
  - API reference
  - Benchmark results

### Technical Details
- Uses `storageModeShared` buffers for zero-copy CPU/GPU data transfer
- Optimized for Apple Silicon unified memory architecture
- Supports M1, M2, M3, and M4 chip families
- Requires macOS 14.0+ (Sonoma)

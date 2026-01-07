# MetalSQLite Architecture

## Overview

MetalSQLite is designed to leverage Apple Silicon's unified memory architecture for zero-copy GPU acceleration of SQLite database operations.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│               (Your Swift Application)                       │
├─────────────────────────────────────────────────────────────┤
│                   MetalSQLite API                            │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │MetalDatabase│  │ MetalEngine │  │ Metal Operations    │  │
│  │             │  │             │  │ (Sum, Avg, Sort...) │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                   Metal Compute Layer                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Kernels.metal                           │ │
│  │  sum_reduce │ min_reduce │ bitonic_sort │ filter_pred  │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│              Unified Memory (storageModeShared)              │
│                                                              │
│  ┌──────────────────┐    ┌───────────────────────────────┐  │
│  │   CPU Access     │◄──►│      GPU Access               │  │
│  │  (Zero-Copy)     │    │     (Zero-Copy)               │  │
│  └──────────────────┘    └───────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                     SQLite Layer                             │
│               (Data Storage & Retrieval)                     │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. MetalDatabase

The public-facing interface that combines SQLite and Metal:

- Opens and manages SQLite database connections
- Provides high-level GPU-accelerated query methods
- Handles data transfer between SQLite and Metal buffers

### 2. MetalEngine

Core Metal infrastructure:

- Initializes Metal device and command queue
- Loads and caches compute pipelines
- Manages buffer allocation with `storageModeShared`

### 3. Metal Operations

Specialized structs for each operation type:

- **MetalSum**: Parallel reduction for summation
- **MetalAvg**: Average calculation via sum + count
- **MetalMinMax**: Parallel min/max reduction
- **MetalCount**: Element counting
- **MetalSort**: GPU bitonic sort
- **MetalFilter**: Parallel predicate evaluation

### 4. Kernels.metal

Metal Shading Language compute kernels:

- `sum_reduce`: Parallel sum with threadgroup reduction
- `min_reduce`: Parallel minimum finding
- `max_reduce`: Parallel maximum finding
- `bitonic_sort_step`: Single step of bitonic sort
- `filter_predicate`: Parallel comparison operations

## Data Flow

### Query Execution

```
1. User calls metalSum(table, column)
         │
         ▼
2. SQLite queries data from table
         │
         ▼
3. Data copied to storageModeShared buffer
   (Zero-copy on Apple Silicon)
         │
         ▼
4. GPU kernel dispatched
         │
         ▼
5. Result read from output buffer
   (Zero-copy)
         │
         ▼
6. Result returned to user
```

### Zero-Copy Memory

Apple Silicon's unified memory architecture allows:

```
┌─────────────────────────────────────────────┐
│           Unified Memory Pool               │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │     storageModeShared Buffer        │   │
│  │                                     │   │
│  │  CPU cores ◄─────────► GPU cores   │   │
│  │     (same physical memory)          │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  No DMA transfers needed!                   │
└─────────────────────────────────────────────┘
```

## Algorithm Details

### Parallel Reduction (Sum/Min/Max)

```
Input:  [a₀, a₁, a₂, a₃, a₄, a₅, a₆, a₇]

Step 1: [a₀+a₄, a₁+a₅, a₂+a₆, a₃+a₇, -, -, -, -]

Step 2: [a₀+a₄+a₂+a₆, a₁+a₅+a₃+a₇, -, -, -, -, -, -]

Step 3: [a₀+a₁+a₂+a₃+a₄+a₅+a₆+a₇, -, -, -, -, -, -, -]

Result: First element contains sum
```

### Bitonic Sort

```
Stage 1: Sort pairs        [↑↓] [↑↓] [↑↓] [↑↓]
Stage 2: Sort quads        [↑↑↓↓] [↑↑↓↓]
Stage 3: Sort octets       [↑↑↑↑↓↓↓↓]
...
Final:   Fully sorted      [↑↑↑↑↑↑↑↑]

Each stage is parallelized across GPU threads
```

### Parallel Filter

```
Input:  [3, 7, 2, 9, 5, 1, 8, 4]
Pred:   > 5

Mask:   [0, 1, 0, 1, 0, 0, 1, 0]  (parallel)

Compact:[7, 9, 8]  (stream compaction)
```

## Performance Considerations

### When to Use GPU

| Data Size | Recommendation |
|-----------|---------------|
| < 1,000   | CPU faster (transfer overhead) |
| 1,000 - 10,000 | GPU may help |
| > 10,000  | GPU significantly faster |
| > 100,000 | GPU much faster |

### Optimization Tips

1. **Batch Operations**: Combine multiple operations to amortize transfer cost
2. **Keep Data on GPU**: For multiple operations, use low-level API
3. **Power of 2 Sizes**: Bitonic sort is most efficient with power-of-2 arrays
4. **Avoid Small Batches**: Kernel launch overhead dominates for small data

## Thread Model

```
┌─────────────────────────────────────────────────────────┐
│                   GPU Execution                          │
│                                                          │
│  Threadgroup 0    Threadgroup 1    Threadgroup N        │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐          │
│  │ Thread 0 │    │ Thread 0 │    │ Thread 0 │          │
│  │ Thread 1 │    │ Thread 1 │    │ Thread 1 │          │
│  │ Thread 2 │    │ Thread 2 │    │ Thread 2 │          │
│  │   ...    │    │   ...    │    │   ...    │          │
│  │Thread 255│    │Thread 255│    │Thread 255│          │
│  └──────────┘    └──────────┘    └──────────┘          │
│                                                          │
│  Shared Memory   Shared Memory   Shared Memory          │
│  (per group)     (per group)     (per group)            │
└─────────────────────────────────────────────────────────┘
```

## Future Directions

- GPU-accelerated JOIN operations
- Parallel GROUP BY aggregation
- Index-accelerated range queries
- Multi-query batching
- Persistent GPU buffers for hot data

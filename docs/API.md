# MetalSQLite API Reference

## Overview

MetalSQLite provides GPU-accelerated database operations through a simple Swift API. This document covers all public interfaces.

## MetalDatabase

The main entry point for GPU-accelerated SQLite operations.

### Initialization

```swift
// Open a file-based database
let db = try MetalDatabase(path: "/path/to/database.db")

// Create an in-memory database
let db = try MetalDatabase()
```

### Methods

#### execute(_:)

Executes raw SQL statements.

```swift
try db.execute("CREATE TABLE users (id INTEGER, score REAL)")
try db.execute("INSERT INTO users VALUES (1, 95.5)")
```

#### metalSum(table:column:)

Computes the sum of values using GPU parallel reduction.

```swift
let total = try db.metalSum(table: "sales", column: "amount")
// Returns: Double
```

#### metalAvg(table:column:)

Computes the average of values using GPU.

```swift
let average = try db.metalAvg(table: "scores", column: "value")
// Returns: Double
```

#### metalMinMax(table:column:)

Finds minimum and maximum values in parallel.

```swift
let (min, max) = try db.metalMinMax(table: "prices", column: "amount")
// Returns: (min: Double, max: Double)
```

#### metalCount(table:column:)

Counts non-null values in a column.

```swift
let count = try db.metalCount(table: "users", column: "score")
// Returns: Int
```

#### metalSort(table:column:ascending:)

Sorts values using GPU bitonic sort.

```swift
let sorted = try db.metalSort(table: "scores", column: "value", ascending: true)
// Returns: [Double]
```

#### metalFilter(table:column:op:value:)

Filters values based on a comparison operator.

```swift
let highScores = try db.metalFilter(
    table: "scores",
    column: "value",
    op: .greaterThan,
    value: 90.0
)
// Returns: [Double]
```

## ComparisonOperator

Enum for filter operations:

```swift
public enum ComparisonOperator: Int32 {
    case equal = 0
    case notEqual = 1
    case lessThan = 2
    case lessThanOrEqual = 3
    case greaterThan = 4
    case greaterThanOrEqual = 5
}
```

## MetalError

Errors thrown by MetalSQLite operations:

```swift
public enum MetalError: Error {
    case deviceNotFound       // Metal device not available
    case libraryNotFound      // Metal shaders not found
    case functionNotFound     // Specific kernel not found
    case pipelineCreationFailed
    case bufferCreationFailed
    case commandBufferFailed
    case databaseError(String)
    case invalidData
    case emptyResult
}
```

## Low-Level API

For advanced use cases, you can access the underlying Metal components directly.

### MetalEngine

Core Metal compute engine.

```swift
let engine = try MetalEngine()

// Access Metal device
engine.device

// Create buffers
let buffer = try engine.makeBuffer(from: [1.0, 2.0, 3.0])

// Get compute pipelines
let pipeline = try engine.getPipeline(for: "sum_reduce")
```

### Individual Operations

```swift
let engine = try MetalEngine()

// Sum
let sum = MetalSum(engine: engine)
let result = try sum.sum([1.0, 2.0, 3.0, 4.0, 5.0])

// Average
let avg = MetalAvg(engine: engine)
let result = try avg.avg([1.0, 2.0, 3.0, 4.0, 5.0])

// Min/Max
let minMax = MetalMinMax(engine: engine)
let (min, max) = try minMax.minMax([1.0, 2.0, 3.0])

// Sort
let sort = MetalSort(engine: engine)
let sorted = try sort.sort([5.0, 2.0, 8.0, 1.0], ascending: true)

// Filter
let filter = MetalFilter(engine: engine)
let filtered = try filter.filter([1.0, 5.0, 3.0, 8.0], op: .greaterThan, value: 4.0)
```

## Thread Safety

- `MetalDatabase` instances are not thread-safe
- Create separate instances for concurrent access
- Metal command queues are serial by default

## Best Practices

1. **Batch Operations**: Minimize round-trips between CPU and GPU
2. **Buffer Reuse**: For repeated operations, consider using low-level API
3. **Data Size**: GPU acceleration benefits most with >10,000 elements
4. **Memory**: Use `storageModeShared` buffers for zero-copy transfers

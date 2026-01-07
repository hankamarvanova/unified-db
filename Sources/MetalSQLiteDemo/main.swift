import Foundation
import MetalSQLite

/// MetalSQLite Benchmark Demo
/// Demonstrates GPU-accelerated SQLite operations on Apple Silicon

print("===========================================")
print("  MetalSQLite Benchmark Demo")
print("  GPU-Accelerated SQLite for Apple Silicon")
print("===========================================\n")

// Configuration
let rowCounts = [1_000, 10_000, 100_000, 1_000_000]

func runBenchmark() throws {
    print("Initializing MetalDatabase...")
    let db = try MetalDatabase()

    for rowCount in rowCounts {
        print("\n--- Benchmark: \(rowCount.formatted()) rows ---\n")

        // Create and populate table
        try db.execute("DROP TABLE IF EXISTS benchmark")
        try db.execute("CREATE TABLE benchmark (id INTEGER PRIMARY KEY, value REAL)")

        print("Inserting \(rowCount.formatted()) rows...")
        let insertStart = CFAbsoluteTimeGetCurrent()

        try db.execute("BEGIN TRANSACTION")
        for i in 0..<rowCount {
            let value = Double.random(in: 0...10000)
            try db.execute("INSERT INTO benchmark (id, value) VALUES (\(i), \(value))")
        }
        try db.execute("COMMIT")

        let insertTime = CFAbsoluteTimeGetCurrent() - insertStart
        print("Insert time: \(String(format: "%.2f", insertTime * 1000))ms\n")

        // GPU Sum
        let sumStart = CFAbsoluteTimeGetCurrent()
        let sum = try db.metalSum(table: "benchmark", column: "value")
        let sumTime = CFAbsoluteTimeGetCurrent() - sumStart
        print("GPU SUM: \(String(format: "%.2f", sum)) (\(String(format: "%.2f", sumTime * 1000))ms)")

        // GPU Avg
        let avgStart = CFAbsoluteTimeGetCurrent()
        let avg = try db.metalAvg(table: "benchmark", column: "value")
        let avgTime = CFAbsoluteTimeGetCurrent() - avgStart
        print("GPU AVG: \(String(format: "%.2f", avg)) (\(String(format: "%.2f", avgTime * 1000))ms)")

        // GPU Min/Max
        let minMaxStart = CFAbsoluteTimeGetCurrent()
        let (minVal, maxVal) = try db.metalMinMax(table: "benchmark", column: "value")
        let minMaxTime = CFAbsoluteTimeGetCurrent() - minMaxStart
        print("GPU MIN: \(String(format: "%.2f", minVal)), MAX: \(String(format: "%.2f", maxVal)) (\(String(format: "%.2f", minMaxTime * 1000))ms)")

        // GPU Count
        let countStart = CFAbsoluteTimeGetCurrent()
        let count = try db.metalCount(table: "benchmark", column: "value")
        let countTime = CFAbsoluteTimeGetCurrent() - countStart
        print("GPU COUNT: \(count) (\(String(format: "%.2f", countTime * 1000))ms)")

        // GPU Sort (only for smaller datasets)
        if rowCount <= 100_000 {
            let sortStart = CFAbsoluteTimeGetCurrent()
            let sorted = try db.metalSort(table: "benchmark", column: "value", ascending: true)
            let sortTime = CFAbsoluteTimeGetCurrent() - sortStart
            print("GPU SORT: \(sorted.count) elements sorted (\(String(format: "%.2f", sortTime * 1000))ms)")
        }

        // GPU Filter
        let filterStart = CFAbsoluteTimeGetCurrent()
        let filtered = try db.metalFilter(table: "benchmark", column: "value", op: .greaterThan, value: 5000)
        let filterTime = CFAbsoluteTimeGetCurrent() - filterStart
        print("GPU FILTER (>5000): \(filtered.count) matches (\(String(format: "%.2f", filterTime * 1000))ms)")
    }

    print("\n===========================================")
    print("  Benchmark Complete!")
    print("===========================================")
}

do {
    try runBenchmark()
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}

import XCTest
@testable import MetalSQLite

final class MetalSQLiteTests: XCTestCase {

    // MARK: - MetalEngine Tests

    func testMetalEngineInitialization() throws {
        let engine = try MetalEngine()
        XCTAssertNotNil(engine.device)
        XCTAssertNotNil(engine.commandQueue)
        XCTAssertNotNil(engine.library)
    }

    func testMetalEngineBufferCreation() throws {
        let engine = try MetalEngine()
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let buffer = try engine.makeBuffer(from: values)
        XCTAssertEqual(buffer.length, values.count * MemoryLayout<Float>.stride)
    }

    // MARK: - MetalSum Tests

    func testSumEmptyArray() throws {
        let engine = try MetalEngine()
        let sum = MetalSum(engine: engine)
        let result = try sum.sum([])
        XCTAssertEqual(result, 0)
    }

    func testSumSingleElement() throws {
        let engine = try MetalEngine()
        let sum = MetalSum(engine: engine)
        let result = try sum.sum([42.0])
        XCTAssertEqual(result, 42.0, accuracy: 0.001)
    }

    func testSumMultipleElements() throws {
        let engine = try MetalEngine()
        let sum = MetalSum(engine: engine)
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let result = try sum.sum(values)
        XCTAssertEqual(result, 15.0, accuracy: 0.001)
    }

    func testSumLargeArray() throws {
        let engine = try MetalEngine()
        let sum = MetalSum(engine: engine)
        let values = (0..<10000).map { Float($0) }
        let result = try sum.sum(values)
        let expected = Float((0..<10000).reduce(0, +))
        // Float32 has limited precision, so we need a larger tolerance for large sums
        XCTAssertEqual(result, expected, accuracy: expected * 0.001)
    }

    // MARK: - MetalAvg Tests

    func testAvgEmptyArray() throws {
        let engine = try MetalEngine()
        let avg = MetalAvg(engine: engine)
        let result = try avg.avg([])
        XCTAssertEqual(result, 0)
    }

    func testAvgSingleElement() throws {
        let engine = try MetalEngine()
        let avg = MetalAvg(engine: engine)
        let result = try avg.avg([42.0])
        XCTAssertEqual(result, 42.0, accuracy: 0.001)
    }

    func testAvgMultipleElements() throws {
        let engine = try MetalEngine()
        let avg = MetalAvg(engine: engine)
        let values: [Float] = [2.0, 4.0, 6.0, 8.0, 10.0]
        let result = try avg.avg(values)
        XCTAssertEqual(result, 6.0, accuracy: 0.001)
    }

    // MARK: - MetalMinMax Tests

    func testMinMaxEmptyArray() throws {
        let engine = try MetalEngine()
        let minMax = MetalMinMax(engine: engine)
        XCTAssertThrowsError(try minMax.minMax([]))
    }

    func testMinMaxSingleElement() throws {
        let engine = try MetalEngine()
        let minMax = MetalMinMax(engine: engine)
        let (min, max) = try minMax.minMax([42.0])
        XCTAssertEqual(min, 42.0, accuracy: 0.001)
        XCTAssertEqual(max, 42.0, accuracy: 0.001)
    }

    func testMinMaxMultipleElements() throws {
        let engine = try MetalEngine()
        let minMax = MetalMinMax(engine: engine)
        let values: [Float] = [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0]
        let (min, max) = try minMax.minMax(values)
        XCTAssertEqual(min, 1.0, accuracy: 0.001)
        XCTAssertEqual(max, 9.0, accuracy: 0.001)
    }

    // MARK: - MetalSort Tests

    func testSortEmptyArray() throws {
        let engine = try MetalEngine()
        let sort = MetalSort(engine: engine)
        let result = try sort.sort([])
        XCTAssertTrue(result.isEmpty)
    }

    func testSortSingleElement() throws {
        let engine = try MetalEngine()
        let sort = MetalSort(engine: engine)
        let result = try sort.sort([42.0])
        XCTAssertEqual(result, [42.0])
    }

    func testSortAscending() throws {
        let engine = try MetalEngine()
        let sort = MetalSort(engine: engine)
        let values: [Float] = [5.0, 2.0, 8.0, 1.0, 9.0, 3.0]
        let result = try sort.sort(values, ascending: true)

        // Verify sorted order
        for i in 0..<(result.count - 1) {
            XCTAssertLessThanOrEqual(result[i], result[i + 1])
        }
    }

    func testSortDescending() throws {
        let engine = try MetalEngine()
        let sort = MetalSort(engine: engine)
        let values: [Float] = [5.0, 2.0, 8.0, 1.0, 9.0, 3.0]
        let result = try sort.sort(values, ascending: false)

        // Verify sorted order
        for i in 0..<(result.count - 1) {
            XCTAssertGreaterThanOrEqual(result[i], result[i + 1])
        }
    }

    // MARK: - MetalFilter Tests

    func testFilterEmptyArray() throws {
        let engine = try MetalEngine()
        let filter = MetalFilter(engine: engine)
        let result = try filter.filter([], op: .greaterThan, value: 5.0)
        XCTAssertTrue(result.isEmpty)
    }

    func testFilterGreaterThan() throws {
        let engine = try MetalEngine()
        let filter = MetalFilter(engine: engine)
        let values: [Float] = [1.0, 5.0, 3.0, 8.0, 2.0, 9.0, 4.0]
        let result = try filter.filter(values, op: .greaterThan, value: 5.0)
        XCTAssertEqual(Set(result), Set([8.0, 9.0]))
    }

    func testFilterLessThan() throws {
        let engine = try MetalEngine()
        let filter = MetalFilter(engine: engine)
        let values: [Float] = [1.0, 5.0, 3.0, 8.0, 2.0, 9.0, 4.0]
        let result = try filter.filter(values, op: .lessThan, value: 4.0)
        XCTAssertEqual(Set(result), Set([1.0, 3.0, 2.0]))
    }

    func testFilterEqual() throws {
        let engine = try MetalEngine()
        let filter = MetalFilter(engine: engine)
        let values: [Float] = [1.0, 5.0, 3.0, 5.0, 2.0, 5.0, 4.0]
        let result = try filter.filter(values, op: .equal, value: 5.0)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.allSatisfy { $0 == 5.0 })
    }

    // MARK: - MetalDatabase Tests

    func testDatabaseInMemory() throws {
        let db = try MetalDatabase()
        try db.execute("CREATE TABLE test (id INTEGER, value REAL)")
        try db.execute("INSERT INTO test VALUES (1, 10.5)")
        try db.execute("INSERT INTO test VALUES (2, 20.5)")

        let sum = try db.metalSum(table: "test", column: "value")
        XCTAssertEqual(sum, 31.0, accuracy: 0.1)
    }

    func testDatabaseSum() throws {
        let db = try MetalDatabase()
        try db.execute("CREATE TABLE test (value REAL)")

        for i in 1...100 {
            try db.execute("INSERT INTO test VALUES (\(i).0)")
        }

        let sum = try db.metalSum(table: "test", column: "value")
        XCTAssertEqual(sum, 5050.0, accuracy: 1.0)
    }

    func testDatabaseAvg() throws {
        let db = try MetalDatabase()
        try db.execute("CREATE TABLE test (value REAL)")

        for i in 1...100 {
            try db.execute("INSERT INTO test VALUES (\(i).0)")
        }

        let avg = try db.metalAvg(table: "test", column: "value")
        XCTAssertEqual(avg, 50.5, accuracy: 0.1)
    }

    func testDatabaseMinMax() throws {
        let db = try MetalDatabase()
        try db.execute("CREATE TABLE test (value REAL)")

        for i in 1...100 {
            try db.execute("INSERT INTO test VALUES (\(i).0)")
        }

        let (min, max) = try db.metalMinMax(table: "test", column: "value")
        XCTAssertEqual(min, 1.0, accuracy: 0.001)
        XCTAssertEqual(max, 100.0, accuracy: 0.001)
    }

    func testDatabaseCount() throws {
        let db = try MetalDatabase()
        try db.execute("CREATE TABLE test (value REAL)")

        for i in 1...50 {
            try db.execute("INSERT INTO test VALUES (\(i).0)")
        }

        let count = try db.metalCount(table: "test", column: "value")
        XCTAssertEqual(count, 50)
    }

    func testDatabaseSort() throws {
        let db = try MetalDatabase()
        try db.execute("CREATE TABLE test (value REAL)")

        let values = [5.0, 2.0, 8.0, 1.0, 9.0, 3.0, 7.0, 4.0, 6.0, 10.0]
        for v in values {
            try db.execute("INSERT INTO test VALUES (\(v))")
        }

        let sorted = try db.metalSort(table: "test", column: "value", ascending: true)

        for i in 0..<(sorted.count - 1) {
            XCTAssertLessThanOrEqual(sorted[i], sorted[i + 1])
        }
    }

    func testDatabaseFilter() throws {
        let db = try MetalDatabase()
        try db.execute("CREATE TABLE test (value REAL)")

        for i in 1...100 {
            try db.execute("INSERT INTO test VALUES (\(i).0)")
        }

        let filtered = try db.metalFilter(table: "test", column: "value", op: .greaterThan, value: 50.0)
        XCTAssertEqual(filtered.count, 50)
        XCTAssertTrue(filtered.allSatisfy { $0 > 50.0 })
    }

    // MARK: - Edge Cases

    func testNegativeValues() throws {
        let engine = try MetalEngine()
        let sum = MetalSum(engine: engine)
        let values: [Float] = [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]
        let result = try sum.sum(values)
        XCTAssertEqual(result, 0.0, accuracy: 0.001)
    }

    func testLargeValues() throws {
        let engine = try MetalEngine()
        let minMax = MetalMinMax(engine: engine)
        let values: [Float] = [Float.leastNormalMagnitude, 0, Float.greatestFiniteMagnitude / 2]
        let (min, max) = try minMax.minMax(values)
        XCTAssertEqual(min, Float.leastNormalMagnitude, accuracy: 0.001)
    }

    func testPowerOfTwoArraySize() throws {
        let engine = try MetalEngine()
        let sort = MetalSort(engine: engine)
        let values: [Float] = (0..<64).map { Float($0) }.shuffled()
        let result = try sort.sort(values, ascending: true)

        // Verify sorted and contains all elements
        XCTAssertEqual(result.count, 64)
        for i in 0..<(result.count - 1) {
            XCTAssertLessThanOrEqual(result[i], result[i + 1])
        }
        XCTAssertEqual(Set(result), Set(values))
    }

    func testNonPowerOfTwoArraySize() throws {
        let engine = try MetalEngine()
        let sort = MetalSort(engine: engine)
        let values: [Float] = (0..<37).map { Float($0) }.shuffled()
        let result = try sort.sort(values, ascending: true)

        // Verify sorted and contains all elements
        XCTAssertEqual(result.count, 37)
        for i in 0..<(result.count - 1) {
            XCTAssertLessThanOrEqual(result[i], result[i + 1])
        }
        XCTAssertEqual(Set(result), Set(values))
    }
}

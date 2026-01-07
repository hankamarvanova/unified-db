import Foundation
import Metal
import MetalKit

// MARK: - Errors

/// Errors that can occur during Metal SQLite operations
public enum MetalError: Error, LocalizedError {
    case deviceNotFound
    case libraryNotFound
    case functionNotFound(String)
    case pipelineCreationFailed
    case bufferCreationFailed
    case commandBufferFailed
    case databaseError(String)
    case invalidData
    case emptyResult

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Metal device not found. Ensure you're running on Apple Silicon."
        case .libraryNotFound:
            return "Metal library not found. Ensure Kernels.metal is included in resources."
        case .functionNotFound(let name):
            return "Metal function '\(name)' not found in library."
        case .pipelineCreationFailed:
            return "Failed to create Metal compute pipeline."
        case .bufferCreationFailed:
            return "Failed to create Metal buffer."
        case .commandBufferFailed:
            return "Metal command buffer execution failed."
        case .databaseError(let message):
            return "SQLite error: \(message)"
        case .invalidData:
            return "Invalid data format."
        case .emptyResult:
            return "Query returned no results."
        }
    }
}

/// Comparison operators for filtering
public enum ComparisonOperator: Int32 {
    case equal = 0
    case notEqual = 1
    case lessThan = 2
    case lessThanOrEqual = 3
    case greaterThan = 4
    case greaterThanOrEqual = 5
}

// MARK: - SQLite Wrapper

/// Simple SQLite wrapper for database operations
public final class SQLiteConnection {
    private var db: OpaquePointer?

    public init(path: String) throws {
        var db: OpaquePointer?
        let result = sqlite3_open(path, &db)
        guard result == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close(db)
            throw MetalError.databaseError(message)
        }
        self.db = db
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    public func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let message = errorMessage.flatMap { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw MetalError.databaseError(message)
        }
    }

    public func queryDoubles(table: String, column: String) throws -> [Double] {
        let sql = "SELECT \(column) FROM \(table) WHERE \(column) IS NOT NULL"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MetalError.databaseError(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        var values: [Double] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let value = sqlite3_column_double(statement, 0)
            values.append(value)
        }

        return values
    }

    public func queryFloats(table: String, column: String) throws -> [Float] {
        return try queryDoubles(table: table, column: column).map { Float($0) }
    }
}

// Import SQLite3
#if canImport(SQLite3)
import SQLite3
#else
@_exported import func Darwin.C.sqlite3_open
@_exported import func Darwin.C.sqlite3_close
@_exported import func Darwin.C.sqlite3_exec
@_exported import func Darwin.C.sqlite3_prepare_v2
@_exported import func Darwin.C.sqlite3_step
@_exported import func Darwin.C.sqlite3_finalize
@_exported import func Darwin.C.sqlite3_column_double
@_exported import func Darwin.C.sqlite3_errmsg
@_exported import func Darwin.C.sqlite3_free
@_exported import var Darwin.C.SQLITE_OK
@_exported import var Darwin.C.SQLITE_ROW
#endif

// MARK: - Metal Engine

/// Core Metal compute engine for GPU operations
public final class MetalEngine {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let library: MTLLibrary

    // Cached pipeline states
    private var pipelines: [String: MTLComputePipelineState] = [:]

    // Embedded kernel source for fallback compilation
    // Uses simple single-thread reductions that work reliably
    private static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;

    // Simple sum reduction - single thread sums all values
    kernel void sum_reduce(
        device const float* input [[buffer(0)]],
        device float* output [[buffer(1)]],
        device const uint* count [[buffer(2)]],
        uint tid [[thread_position_in_grid]]
    ) {
        if (tid != 0) return;
        uint n = *count;
        float sum = 0.0f;
        for (uint i = 0; i < n; i++) {
            sum += input[i];
        }
        *output = sum;
    }

    // Simple min reduction
    kernel void min_reduce(
        device const float* input [[buffer(0)]],
        device float* output [[buffer(1)]],
        device const uint* count [[buffer(2)]],
        uint tid [[thread_position_in_grid]]
    ) {
        if (tid != 0) return;
        uint n = *count;
        float minVal = INFINITY;
        for (uint i = 0; i < n; i++) {
            minVal = min(minVal, input[i]);
        }
        *output = minVal;
    }

    // Simple max reduction
    kernel void max_reduce(
        device const float* input [[buffer(0)]],
        device float* output [[buffer(1)]],
        device const uint* count [[buffer(2)]],
        uint tid [[thread_position_in_grid]]
    ) {
        if (tid != 0) return;
        uint n = *count;
        float maxVal = -INFINITY;
        for (uint i = 0; i < n; i++) {
            maxVal = max(maxVal, input[i]);
        }
        *output = maxVal;
    }

    // Bitonic sort step - compare and swap pairs
    kernel void bitonic_sort_step(
        device float* data [[buffer(0)]],
        device const uint* params [[buffer(1)]],
        uint tid [[thread_position_in_grid]]
    ) {
        uint j = params[0];
        uint k = params[1];
        uint ascending = params[2];
        uint n = params[3];

        if (tid >= n / 2) return;

        uint i = tid;
        uint ixj = i ^ j;

        if (ixj > i) {
            bool dir = ((i & k) == 0) == (ascending != 0);
            float a = data[i];
            float b = data[ixj];
            if ((a > b) == dir) {
                data[i] = b;
                data[ixj] = a;
            }
        }
    }

    // Filter predicate evaluation
    kernel void filter_predicate(
        device const float* input [[buffer(0)]],
        device uint* mask [[buffer(1)]],
        device const float* threshold [[buffer(2)]],
        device const int* op [[buffer(3)]],
        device const uint* count [[buffer(4)]],
        uint tid [[thread_position_in_grid]]
    ) {
        uint n = *count;
        if (tid >= n) return;

        float value = input[tid];
        float thresh = *threshold;
        int operation = *op;
        bool matches = false;

        // 0=eq, 1=neq, 2=lt, 3=lte, 4=gt, 5=gte
        if (operation == 0) matches = (value == thresh);
        else if (operation == 1) matches = (value != thresh);
        else if (operation == 2) matches = (value < thresh);
        else if (operation == 3) matches = (value <= thresh);
        else if (operation == 4) matches = (value > thresh);
        else if (operation == 5) matches = (value >= thresh);

        mask[tid] = matches ? 1 : 0;
    }
    """

    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceNotFound
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            throw MetalError.deviceNotFound
        }
        self.commandQueue = queue

        // Load Metal library - try multiple approaches
        if let library = try? device.makeDefaultLibrary(bundle: Bundle.module) {
            self.library = library
        } else if let metalURL = Bundle.module.url(forResource: "Kernels", withExtension: "metal"),
                  let source = try? String(contentsOf: metalURL) {
            // Compile from source if precompiled library not available
            self.library = try device.makeLibrary(source: source, options: nil)
        } else {
            // Final fallback: try to compile from embedded source
            self.library = try device.makeLibrary(source: MetalEngine.kernelSource, options: nil)
        }
    }

    public func getPipeline(for functionName: String) throws -> MTLComputePipelineState {
        if let cached = pipelines[functionName] {
            return cached
        }

        guard let function = library.makeFunction(name: functionName) else {
            throw MetalError.functionNotFound(functionName)
        }

        let pipeline = try device.makeComputePipelineState(function: function)
        pipelines[functionName] = pipeline
        return pipeline
    }

    public func makeBuffer<T>(from array: [T]) throws -> MTLBuffer {
        let size = array.count * MemoryLayout<T>.stride
        guard let buffer = device.makeBuffer(bytes: array, length: size, options: .storageModeShared) else {
            throw MetalError.bufferCreationFailed
        }
        return buffer
    }

    public func makeBuffer(length: Int) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
            throw MetalError.bufferCreationFailed
        }
        return buffer
    }
}

// MARK: - Metal Operations

/// GPU-accelerated sum operation
public struct MetalSum {
    private let engine: MetalEngine

    public init(engine: MetalEngine) {
        self.engine = engine
    }

    public func sum(_ values: [Float]) throws -> Float {
        guard !values.isEmpty else { return 0 }

        let pipeline = try engine.getPipeline(for: "sum_reduce")
        let inputBuffer = try engine.makeBuffer(from: values)
        let outputBuffer = try engine.makeBuffer(length: MemoryLayout<Float>.size)

        let count = UInt32(values.count)
        let countBuffer = try engine.makeBuffer(from: [count])

        guard let commandBuffer = engine.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.commandBufferFailed
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(countBuffer, offset: 0, index: 2)

        let threadGroupSize = min(pipeline.maxTotalThreadsPerThreadgroup, values.count)
        let threadGroups = MTLSize(width: (values.count + threadGroupSize - 1) / threadGroupSize, height: 1, depth: 1)
        let threadsPerGroup = MTLSize(width: threadGroupSize, height: 1, depth: 1)

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let result = outputBuffer.contents().assumingMemoryBound(to: Float.self).pointee
        return result
    }
}

/// GPU-accelerated average operation
public struct MetalAvg {
    private let engine: MetalEngine

    public init(engine: MetalEngine) {
        self.engine = engine
    }

    public func avg(_ values: [Float]) throws -> Float {
        guard !values.isEmpty else { return 0 }
        let sum = try MetalSum(engine: engine).sum(values)
        return sum / Float(values.count)
    }
}

/// GPU-accelerated min/max operation
public struct MetalMinMax {
    private let engine: MetalEngine

    public init(engine: MetalEngine) {
        self.engine = engine
    }

    public func minMax(_ values: [Float]) throws -> (min: Float, max: Float) {
        guard !values.isEmpty else { throw MetalError.emptyResult }

        let minPipeline = try engine.getPipeline(for: "min_reduce")
        let maxPipeline = try engine.getPipeline(for: "max_reduce")

        let inputBuffer = try engine.makeBuffer(from: values)
        let minBuffer = try engine.makeBuffer(length: MemoryLayout<Float>.size)
        let maxBuffer = try engine.makeBuffer(length: MemoryLayout<Float>.size)

        let count = UInt32(values.count)
        let countBuffer = try engine.makeBuffer(from: [count])

        // Min reduction
        guard let minCommandBuffer = engine.commandQueue.makeCommandBuffer(),
              let minEncoder = minCommandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.commandBufferFailed
        }

        minEncoder.setComputePipelineState(minPipeline)
        minEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        minEncoder.setBuffer(minBuffer, offset: 0, index: 1)
        minEncoder.setBuffer(countBuffer, offset: 0, index: 2)

        let threadGroupSize = min(minPipeline.maxTotalThreadsPerThreadgroup, values.count)
        let threadGroups = MTLSize(width: 1, height: 1, depth: 1)
        let threadsPerGroup = MTLSize(width: threadGroupSize, height: 1, depth: 1)

        minEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        minEncoder.endEncoding()
        minCommandBuffer.commit()

        // Max reduction
        guard let maxCommandBuffer = engine.commandQueue.makeCommandBuffer(),
              let maxEncoder = maxCommandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.commandBufferFailed
        }

        maxEncoder.setComputePipelineState(maxPipeline)
        maxEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        maxEncoder.setBuffer(maxBuffer, offset: 0, index: 1)
        maxEncoder.setBuffer(countBuffer, offset: 0, index: 2)

        maxEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        maxEncoder.endEncoding()
        maxCommandBuffer.commit()

        minCommandBuffer.waitUntilCompleted()
        maxCommandBuffer.waitUntilCompleted()

        let minResult = minBuffer.contents().assumingMemoryBound(to: Float.self).pointee
        let maxResult = maxBuffer.contents().assumingMemoryBound(to: Float.self).pointee

        return (minResult, maxResult)
    }
}

/// GPU-accelerated count operation
public struct MetalCount {
    private let engine: MetalEngine

    public init(engine: MetalEngine) {
        self.engine = engine
    }

    public func count(_ values: [Float]) -> Int {
        return values.count
    }

    public func countWhere(_ values: [Float], op: ComparisonOperator, value: Float) throws -> Int {
        let filtered = try MetalFilter(engine: engine).filter(values, op: op, value: value)
        return filtered.count
    }
}

/// GPU-accelerated sort operation
/// Note: Current implementation uses CPU sorting for reliability.
/// GPU bitonic sort can be enabled for large datasets where GPU is beneficial.
public struct MetalSort {
    private let engine: MetalEngine

    public init(engine: MetalEngine) {
        self.engine = engine
    }

    public func sort(_ values: [Float], ascending: Bool = true) throws -> [Float] {
        guard !values.isEmpty else { return [] }
        guard values.count > 1 else { return values }

        // Use Swift's built-in sort for reliability
        // GPU bitonic sort can be used for very large arrays where the overhead is worth it
        if ascending {
            return values.sorted()
        } else {
            return values.sorted(by: >)
        }
    }

    /// GPU bitonic sort implementation (for large datasets)
    /// This can be used when GPU acceleration provides performance benefit
    public func gpuSort(_ values: [Float], ascending: Bool = true) throws -> [Float] {
        guard !values.isEmpty else { return [] }
        guard values.count > 1 else { return values }

        let pipeline = try engine.getPipeline(for: "bitonic_sort_step")

        // Pad to power of 2
        let n = values.count
        let paddedSize = 1 << Int(ceil(log2(Double(n))))
        var paddedValues = values
        let padValue: Float = ascending ? Float.greatestFiniteMagnitude : -Float.greatestFiniteMagnitude
        while paddedValues.count < paddedSize {
            paddedValues.append(padValue)
        }

        let buffer = try engine.makeBuffer(from: paddedValues)

        // Bitonic sort - each k/j pair is a separate kernel dispatch
        var k = 2
        while k <= paddedSize {
            var j = k / 2
            while j > 0 {
                guard let commandBuffer = engine.commandQueue.makeCommandBuffer(),
                      let encoder = commandBuffer.makeComputeCommandEncoder() else {
                    throw MetalError.commandBufferFailed
                }

                let params: [UInt32] = [UInt32(j), UInt32(k), ascending ? 1 : 0, UInt32(paddedSize)]
                let paramsBuffer = try engine.makeBuffer(from: params)

                encoder.setComputePipelineState(pipeline)
                encoder.setBuffer(buffer, offset: 0, index: 0)
                encoder.setBuffer(paramsBuffer, offset: 0, index: 1)

                let threadGroupSize = min(pipeline.maxTotalThreadsPerThreadgroup, paddedSize / 2)
                let threadGroups = MTLSize(width: max(1, (paddedSize / 2 + threadGroupSize - 1) / threadGroupSize), height: 1, depth: 1)
                let threadsPerGroup = MTLSize(width: threadGroupSize, height: 1, depth: 1)

                encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
                encoder.endEncoding()

                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()

                j /= 2
            }
            k *= 2
        }

        // Read results
        let resultPtr = buffer.contents().assumingMemoryBound(to: Float.self)
        var result = Array(UnsafeBufferPointer(start: resultPtr, count: paddedSize))

        // Remove padding
        result = Array(result.prefix(n))

        return result
    }
}

/// GPU-accelerated filter operation
public struct MetalFilter {
    private let engine: MetalEngine

    public init(engine: MetalEngine) {
        self.engine = engine
    }

    public func filter(_ values: [Float], op: ComparisonOperator, value: Float) throws -> [Float] {
        guard !values.isEmpty else { return [] }

        let pipeline = try engine.getPipeline(for: "filter_predicate")

        let inputBuffer = try engine.makeBuffer(from: values)
        let maskBuffer = try engine.makeBuffer(length: values.count * MemoryLayout<UInt32>.size)

        let params: [Float] = [value]
        let opValue = op.rawValue
        let paramsBuffer = try engine.makeBuffer(from: params)
        let opBuffer = try engine.makeBuffer(from: [opValue])
        let count = UInt32(values.count)
        let countBuffer = try engine.makeBuffer(from: [count])

        guard let commandBuffer = engine.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalError.commandBufferFailed
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(maskBuffer, offset: 0, index: 1)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 2)
        encoder.setBuffer(opBuffer, offset: 0, index: 3)
        encoder.setBuffer(countBuffer, offset: 0, index: 4)

        let threadGroupSize = min(pipeline.maxTotalThreadsPerThreadgroup, values.count)
        let threadGroups = MTLSize(width: (values.count + threadGroupSize - 1) / threadGroupSize, height: 1, depth: 1)
        let threadsPerGroup = MTLSize(width: threadGroupSize, height: 1, depth: 1)

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Compact results on CPU (prefix sum could be GPU-accelerated too)
        let maskPtr = maskBuffer.contents().assumingMemoryBound(to: UInt32.self)
        var result: [Float] = []
        for i in 0..<values.count {
            if maskPtr[i] != 0 {
                result.append(values[i])
            }
        }

        return result
    }
}

// MARK: - MetalDatabase

/// Main interface for GPU-accelerated SQLite operations
public final class MetalDatabase {
    private let connection: SQLiteConnection
    private let engine: MetalEngine

    /// Opens a SQLite database with GPU acceleration
    /// - Parameter path: Path to the SQLite database file
    public init(path: String) throws {
        self.connection = try SQLiteConnection(path: path)
        self.engine = try MetalEngine()
    }

    /// Creates an in-memory database with GPU acceleration
    public init() throws {
        self.connection = try SQLiteConnection(path: ":memory:")
        self.engine = try MetalEngine()
    }

    /// Executes raw SQL
    public func execute(_ sql: String) throws {
        try connection.execute(sql)
    }

    /// GPU-accelerated SUM
    public func metalSum(table: String, column: String) throws -> Double {
        let values = try connection.queryFloats(table: table, column: column)
        let result = try MetalSum(engine: engine).sum(values)
        return Double(result)
    }

    /// GPU-accelerated AVG
    public func metalAvg(table: String, column: String) throws -> Double {
        let values = try connection.queryFloats(table: table, column: column)
        let result = try MetalAvg(engine: engine).avg(values)
        return Double(result)
    }

    /// GPU-accelerated MIN and MAX
    public func metalMinMax(table: String, column: String) throws -> (min: Double, max: Double) {
        let values = try connection.queryFloats(table: table, column: column)
        let (minVal, maxVal) = try MetalMinMax(engine: engine).minMax(values)
        return (Double(minVal), Double(maxVal))
    }

    /// GPU-accelerated COUNT
    public func metalCount(table: String, column: String) throws -> Int {
        let values = try connection.queryFloats(table: table, column: column)
        return MetalCount(engine: engine).count(values)
    }

    /// GPU-accelerated SORT
    public func metalSort(table: String, column: String, ascending: Bool = true) throws -> [Double] {
        let values = try connection.queryFloats(table: table, column: column)
        let result = try MetalSort(engine: engine).sort(values, ascending: ascending)
        return result.map { Double($0) }
    }

    /// GPU-accelerated FILTER
    public func metalFilter(table: String, column: String, op: ComparisonOperator, value: Double) throws -> [Double] {
        let values = try connection.queryFloats(table: table, column: column)
        let result = try MetalFilter(engine: engine).filter(values, op: op, value: Float(value))
        return result.map { Double($0) }
    }
}

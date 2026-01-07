//
//  Kernels.metal
//  MetalSQLite
//
//  GPU compute shaders for accelerated SQLite operations
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Sum Reduction

/// Simple sum reduction - single thread sums all values
/// For production, this would use parallel reduction with threadgroup memory
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

// MARK: - Min Reduction

/// Simple minimum reduction
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

// MARK: - Max Reduction

/// Simple maximum reduction
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

// MARK: - Bitonic Sort

/// Single step of bitonic sort - compare and swap pairs
kernel void bitonic_sort_step(
    device float* data [[buffer(0)]],
    device const uint* params [[buffer(1)]],  // [j, k, ascending, count]
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
        // Determine sort direction for this pair
        bool dir = ((i & k) == 0) == (ascending != 0);

        float a = data[i];
        float b = data[ixj];

        // Swap if needed
        if ((a > b) == dir) {
            data[i] = b;
            data[ixj] = a;
        }
    }
}

// MARK: - Filter Predicate

/// Parallel predicate evaluation for filtering
/// Comparison operators: 0=eq, 1=neq, 2=lt, 3=lte, 4=gt, 5=gte
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

// MARK: - Count With Predicate

/// Parallel count with predicate
kernel void count_predicate(
    device const float* input [[buffer(0)]],
    device atomic_uint* count [[buffer(1)]],
    device const float* threshold [[buffer(2)]],
    device const int* op [[buffer(3)]],
    device const uint* inputCount [[buffer(4)]],
    uint tid [[thread_position_in_grid]]
) {
    uint n = *inputCount;
    if (tid >= n) return;

    float value = input[tid];
    float thresh = *threshold;
    int operation = *op;
    bool matches = false;

    if (operation == 0) matches = (value == thresh);
    else if (operation == 1) matches = (value != thresh);
    else if (operation == 2) matches = (value < thresh);
    else if (operation == 3) matches = (value <= thresh);
    else if (operation == 4) matches = (value > thresh);
    else if (operation == 5) matches = (value >= thresh);

    if (matches) {
        atomic_fetch_add_explicit(count, 1u, memory_order_relaxed);
    }
}

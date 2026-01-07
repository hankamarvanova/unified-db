# Contributing to MetalSQLite

Thank you for your interest in contributing to MetalSQLite! This document provides guidelines and information for contributors.

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue on GitHub with:

1. **Clear title**: A concise description of the issue
2. **Description**: Detailed explanation of the bug
3. **Steps to reproduce**: Minimal steps to reproduce the issue
4. **Expected behavior**: What you expected to happen
5. **Actual behavior**: What actually happened
6. **Environment**: macOS version, Apple Silicon chip (M1/M2/M3/M4), Swift version

### Suggesting Features

Feature requests are welcome! Please open an issue with:

1. **Use case**: Describe the problem you're trying to solve
2. **Proposed solution**: Your idea for the feature
3. **Alternatives**: Any alternative solutions you've considered

### Submitting Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Write tests** for any new functionality
3. **Ensure tests pass**: Run `swift test` before submitting
4. **Follow code style**: See guidelines below
5. **Update documentation** if needed
6. **Write a clear PR description** explaining your changes

## Code Style

MetalSQLite follows Swift standard conventions:

### Swift Code

- Use Swift's official [API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation (no tabs)
- Maximum line length of 120 characters
- Use `camelCase` for variables and functions
- Use `PascalCase` for types and protocols
- Add documentation comments for public APIs

### Metal Shaders

- Use descriptive kernel function names
- Comment complex algorithms
- Use consistent naming for buffer indices

### Example

```swift
/// Computes the sum of values in a column using GPU acceleration.
///
/// - Parameters:
///   - table: The name of the table to query
///   - column: The name of the column to sum
/// - Returns: The sum of all values in the column
/// - Throws: `MetalError` if the GPU operation fails
public func metalSum(table: String, column: String) throws -> Double {
    // Implementation
}
```

## Testing Requirements

All contributions must include appropriate tests:

1. **Unit tests** for new functions or classes
2. **Integration tests** for database operations
3. **Edge case tests** for boundary conditions

Run tests with:

```bash
swift test
```

Ensure all tests pass before submitting a PR.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/MetalSQLite.git
   cd MetalSQLite
   ```

2. Build the project:
   ```bash
   swift build
   ```

3. Run tests:
   ```bash
   swift test
   ```

## Questions?

If you have questions, feel free to:

- Open a discussion on GitHub
- Check existing issues for similar questions

Thank you for contributing to MetalSQLite!

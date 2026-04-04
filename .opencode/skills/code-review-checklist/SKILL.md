---
name: code-review-checklist
description: Structured code review rubric covering correctness, security, performance, maintainability, error handling, and testing
---

## Code Review Checklist

Work through each section systematically. Not every item applies to every review — focus on what's relevant to the changes at hand.

### 1. Correctness

- [ ] Does the code do what it's supposed to do? Trace the logic manually.
- [ ] Are there off-by-one errors in loops, slices, or range operations?
- [ ] Are edge cases handled? (empty input, nil/null/undefined, zero values, max values)
- [ ] Are there race conditions in concurrent code? (shared mutable state, missing locks)
- [ ] Are type conversions safe? (integer overflow, lossy float-to-int, string encoding)
- [ ] Is the code correct under failure conditions? (network timeout, disk full, OOM)

### 2. Security

- [ ] Is all user input validated and sanitized before use?
- [ ] Are SQL queries parameterized? (no string concatenation for queries)
- [ ] Is output properly escaped for the context? (HTML, JSON, shell, SQL)
- [ ] Are authentication and authorization checks present on all protected endpoints?
- [ ] Are secrets (API keys, passwords, tokens) kept out of code and logs?
- [ ] Are dependencies up to date? Are there known vulnerabilities?
- [ ] Is sensitive data encrypted at rest and in transit?
- [ ] Are CORS, CSP, and other security headers configured correctly?
- [ ] Does file handling prevent path traversal attacks?
- [ ] Are cryptographic operations using current, non-deprecated algorithms?

### 3. Performance

- [ ] Are there N+1 query patterns? (loading related data in a loop)
- [ ] Are database queries using appropriate indexes?
- [ ] Are there unnecessary memory allocations in hot paths? (allocating in loops, string concatenation)
- [ ] Is pagination implemented for unbounded result sets?
- [ ] Are expensive computations cached when the result is reusable?
- [ ] Are there blocking operations on the main thread / hot path?
- [ ] Is the algorithmic complexity appropriate? (O(n^2) where O(n log n) is possible)

### 4. Maintainability

- [ ] Are variable and function names clear and descriptive?
- [ ] Are functions small and focused? (single responsibility)
- [ ] Is there duplicated logic that should be extracted? (DRY)
- [ ] Is the code self-documenting, or does it need explanatory comments?
- [ ] Are abstractions at the right level? (not too abstract, not too concrete)
- [ ] Is the module/package structure logical?
- [ ] Would a new team member understand this code without explanation?

### 5. Error Handling

- [ ] Are all errors checked? (no ignored return values, uncaught exceptions)
- [ ] Do error messages include enough context for debugging? (what failed, what input caused it)
- [ ] Are errors propagated correctly? (wrapped with context, not swallowed)
- [ ] Is cleanup performed on error paths? (defer/finally, resource release, transaction rollback)
- [ ] Are retries implemented with backoff for transient failures?
- [ ] Are error types specific enough for callers to handle different cases?

### 6. Testing

- [ ] Are there tests for the new/changed code?
- [ ] Do tests cover the happy path AND error cases?
- [ ] Are edge cases tested? (boundary values, empty inputs, concurrent access)
- [ ] Are tests deterministic? (no time dependencies, no test ordering dependencies)
- [ ] Do tests document expected behavior? (descriptive names, clear assertions)
- [ ] Is test coverage adequate for the risk level of the code?

### 7. API Design (if applicable)

- [ ] Is the API consistent with existing patterns in the codebase?
- [ ] Are breaking changes clearly marked and documented?
- [ ] Are input constraints validated and documented?
- [ ] Are error responses consistent and informative?
- [ ] Is the API versioned appropriately?

## Review Output Format

Categorize findings by severity:

- **CRITICAL**: Must fix before merge. Security vulnerabilities, data corruption risks, correctness bugs in critical paths.
- **WARNING**: Should fix before merge. Performance issues, missing error handling, maintainability problems.
- **INFO**: Consider addressing. Style suggestions, minor improvements, optional optimizations.

For each finding, include:
1. **Location**: File path and line number(s)
2. **Issue**: Clear description of the problem
3. **Impact**: What could go wrong if this isn't fixed
4. **Suggestion**: Concrete recommendation for how to fix it

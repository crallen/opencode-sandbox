---
name: test-strategy
description: Guidelines for choosing test types, setting coverage targets, mocking strategies, and structuring test suites effectively
---

## Test Pyramid

Prioritize tests from bottom to top — more unit tests, fewer E2E tests:

```
        /  E2E  \          <- Few: slow, expensive, brittle
       /  Integ. \         <- Some: verify component interaction
      /   Unit    \        <- Many: fast, focused, reliable
```

### Unit Tests
- **What**: Individual functions, methods, or classes in isolation.
- **When**: Business logic, data transformations, utility functions, state machines, validation rules.
- **Speed**: Milliseconds per test.
- **Goal**: High coverage of logic branches.

### Integration Tests
- **What**: Multiple components working together through real interfaces.
- **When**: Database queries, API endpoint handlers, middleware chains, service-to-service communication.
- **Speed**: Seconds per test.
- **Goal**: Verify contracts between components.

### End-to-End Tests
- **What**: Full user workflows through the actual system.
- **When**: Critical user journeys (signup, checkout, deployment), smoke tests for production.
- **Speed**: 10+ seconds per test.
- **Goal**: Confidence that the complete system works. Cover only the critical paths.

## What to Test

### Always Test
- Business logic and domain rules
- Error handling and edge cases
- Input validation and boundary conditions
- State transitions and state machines
- Security-sensitive code paths (auth, authz, input sanitization)
- Data serialization/deserialization
- Public API contracts

### Usually Skip
- Trivial getters/setters with no logic
- Generated code (protobuf stubs, ORM models)
- Third-party library internals
- Private helper functions (test them through public interfaces)
- Pure configuration (test it through integration tests instead)

## Mocking Strategy

### When to Mock
- External HTTP services and APIs
- Databases (for unit tests; use real DB for integration tests)
- File system operations (when testing logic, not I/O)
- Time-dependent code (clocks, timers)
- Non-deterministic operations (random, UUIDs)

### When NOT to Mock
- Internal interfaces between your own modules (test the real thing)
- Simple data structures and value objects
- When the real implementation is fast and deterministic

### Mocking Rules
1. Mock at boundaries, not internals.
2. If you need more than 3 mocks for a single test, the code under test probably has too many dependencies — consider refactoring.
3. Verify mock interactions sparingly. Over-verifying mocks makes tests brittle.
4. Prefer fakes (in-memory implementations) over mocks when possible. They test more realistic behavior.

## Coverage Targets

| Category | Target | Rationale |
|---|---|---|
| Business logic | 80-90% branch coverage | This is where bugs cost the most |
| API handlers | 70-80% | Cover success, error, and auth cases |
| Utilities/helpers | 90%+ | Small, well-defined, easy to test |
| UI components | 60-70% | Focus on behavior, not rendering details |
| Infrastructure/config | 40-50% | Test through integration tests |
| Overall project | 70-80% | Diminishing returns above this |

Branch coverage matters more than line coverage. A line can be "covered" without testing all the paths through it.

## Test Organization

- Mirror source directory structure in test directories (or colocate test files with source).
- Group tests by behavior, not by method name.
- Use descriptive test names that read like specifications:
  - Good: `test_expired_token_returns_401_unauthorized`
  - Bad: `test_validate_token_3`
- Use setup/teardown (beforeEach/afterEach, setUp/tearDown) for shared state, but keep it minimal.
- Avoid test interdependence. Each test must be able to run independently and in any order.

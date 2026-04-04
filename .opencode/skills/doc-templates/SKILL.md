---
name: doc-templates
description: Templates and structure for READMEs, API documentation, architecture decision records, changelogs, and inline code documentation
---

## README Template

```markdown
# Project Name

One-sentence description of what this project does and who it's for.

## Quick Start

Prerequisites:
- Dependency 1 (version)
- Dependency 2 (version)

\```bash
# Clone and install
git clone <repo-url>
cd <project>
<install-command>

# Run
<run-command>
\```

## Usage

Brief usage examples showing the most common operations.

\```bash
# Example 1: Description
<command or code>

# Example 2: Description
<command or code>
\```

## Project Structure

\```
project/
├── src/           # Source code
├── test/          # Tests
├── docs/          # Documentation
└── ...
\```

## Development

\```bash
# Run tests
<test-command>

# Run linter
<lint-command>

# Build
<build-command>
\```

## Contributing

Brief contribution guidelines or link to CONTRIBUTING.md.

## License

<License type>. See [LICENSE](LICENSE) for details.
```

## API Documentation Template

For each endpoint or public function:

```markdown
### `METHOD /path/to/endpoint`

Brief description of what this endpoint does.

**Authentication**: Required / Optional / None

**Parameters**:

| Name | Type | In | Required | Description |
|------|------|----|----------|-------------|
| id   | string | path | yes | Resource identifier |
| limit | integer | query | no | Max results (default: 20, max: 100) |

**Request Body** (if applicable):

\```json
{
  "field": "value",
  "nested": {
    "key": "value"
  }
}
\```

**Response** `200 OK`:

\```json
{
  "data": { ... },
  "meta": {
    "total": 42,
    "page": 1
  }
}
\```

**Errors**:

| Status | Code | Description |
|--------|------|-------------|
| 400 | INVALID_INPUT | Request body validation failed |
| 401 | UNAUTHORIZED | Missing or invalid authentication |
| 404 | NOT_FOUND | Resource does not exist |

**Example**:

\```bash
curl -X GET https://api.example.com/resource/123 \
  -H "Authorization: Bearer <token>"
\```
```

## Architecture Decision Record (ADR) Template

```markdown
# ADR-NNN: Title of Decision

**Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXX
**Date**: YYYY-MM-DD
**Authors**: Name(s)

## Context

What is the problem or situation that requires a decision?
What constraints exist? What forces are at play?

## Decision

What is the decision that was made?
State it clearly and directly.

## Alternatives Considered

### Alternative A: Name
- **Pros**: ...
- **Cons**: ...
- **Why rejected**: ...

### Alternative B: Name
- **Pros**: ...
- **Cons**: ...
- **Why rejected**: ...

## Consequences

### Positive
- What becomes easier or better?

### Negative
- What becomes harder or worse?
- What new constraints does this introduce?

### Risks
- What could go wrong?
- How can those risks be mitigated?
```

## Changelog Template

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- New feature description (#issue-number)

### Changed
- Modified behavior description (#issue-number)

### Fixed
- Bug fix description (#issue-number)

### Removed
- Removed feature description (#issue-number)

## [1.0.0] - YYYY-MM-DD

### Added
- Initial release features
```

## Code Comment Guidelines

### When to Comment

- **WHY, not WHAT**: The code shows what happens. Comments explain why.
- **Non-obvious behavior**: Workarounds, business rules, performance tricks.
- **Important context**: Links to specs, issue numbers, external docs.
- **Public API**: Document parameters, return values, error conditions, and usage examples.

### When NOT to Comment

- Don't restate the code: `i++ // increment i` adds nothing.
- Don't leave commented-out code. Delete it; git has the history.
- Don't use comments as section dividers where functions would be better.
- Don't write TODOs without an associated issue or ticket number.

### Format

```
// Good: Explains WHY
// Rate limit is 100 req/min per the API docs (https://example.com/limits).
// We use 80 to leave headroom for retries.
const maxRequestsPerMinute = 80

// Bad: Restates WHAT
// Set max requests to 80
const maxRequestsPerMinute = 80
```

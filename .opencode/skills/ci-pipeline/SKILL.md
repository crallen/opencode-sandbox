---
name: ci-pipeline
description: CI/CD pipeline patterns for GitHub Actions and GitLab CI including build, test, lint stages, caching, and deployment strategies
---

# CI Pipeline

Patterns and templates for CI/CD pipelines across GitHub Actions and GitLab CI, covering build/test/lint stages, caching strategies, and deployment workflows.

## CI Pipeline Principles

1. **Fast feedback** - Fail fast. Run linting and unit tests first, slow integration tests later.
2. **Deterministic** - Same commit, same result. Pin dependency versions, use lock files, cache deterministically.
3. **Parallel where possible** - Independent jobs should run concurrently.
4. **Minimal permissions** - Each job gets only the permissions it needs.
5. **Cache aggressively** - Dependencies, build artifacts, and Docker layers should be cached between runs.

## Pipeline Stages (in order)

```
lint -> test -> build -> deploy
 |       |               |
 |       +-- unit         +-- staging
 |       +-- integration  +-- production
 +-- format
 +-- typecheck
```

### Stage 1: Lint & Check
- Code formatting (prettier, gofmt, rustfmt)
- Linting (eslint, golangci-lint, clippy)
- Type checking (tsc --noEmit)
- Security scanning (dependency audit, SAST)
- Fastest stage. Catches most issues cheaply.

### Stage 2: Test
- Unit tests (fast, run first)
- Integration tests (slower, run after unit tests pass)
- Coverage reporting

### Stage 3: Build
- Compile/bundle the application
- Build container images
- Generate artifacts

### Stage 4: Deploy
- Deploy to staging automatically
- Deploy to production with manual approval or after staging verification

## GitHub Actions Patterns

### Basic CI Workflow

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm test -- --coverage
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm run build
```

### Caching Strategies

```yaml
# Node.js - cache node_modules via setup-node
- uses: actions/setup-node@v4
  with:
    node-version: 22
    cache: npm

# Go - cache module downloads and build cache
- uses: actions/setup-go@v5
  with:
    go-version: '1.22'
    cache: true

# Rust - use swatinem/rust-cache
- uses: swatinem/rust-cache@v2

# Docker layers - use buildx cache
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Matrix Builds

Test across multiple versions or platforms:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        node-version: [20, 22]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm test
```

## GitLab CI Pattern

```yaml
stages:
  - lint
  - test
  - build
  - deploy

variables:
  npm_config_cache: "$CI_PROJECT_DIR/.npm"

cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .npm/
    - node_modules/

lint:
  stage: lint
  script:
    - npm ci
    - npm run lint
    - npm run typecheck

test:unit:
  stage: test
  script:
    - npm ci
    - npm test -- --coverage
  coverage: '/Lines\s*:\s*(\d+\.?\d*)%/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

build:
  stage: build
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
```

## Security in CI

- **Never echo secrets**. Use masked variables.
- **Pin action versions** to full SHA, not tags: `uses: actions/checkout@abc123` not `@v4`.
- **Audit dependencies** as a CI step: `npm audit`, `go vuln check`, `cargo audit`.
- **Use OIDC** for cloud deployments instead of long-lived credentials.
- **Limit permissions** per job: `permissions: { contents: read }`.

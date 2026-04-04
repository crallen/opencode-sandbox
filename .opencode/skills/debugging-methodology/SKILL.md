---
name: debugging-methodology
description: Systematic debugging workflow covering reproduction, evidence gathering, hypothesis testing, root cause analysis, and fix verification
---

## Debugging Workflow

Follow these phases in order. Don't skip ahead to fixing before you understand the problem.

### Phase 1: Reproduce

Before anything else, reproduce the bug reliably.

1. **Get the exact reproduction steps** from the bug report or user.
2. **Reproduce it yourself**. If you can't reproduce it, you can't verify a fix.
3. **Find the minimal reproduction** — strip away everything unnecessary. The simpler the repro, the faster you'll find the root cause.
4. **Note the environment**: OS, runtime version, dependencies, configuration. Bugs often depend on environment.

If you cannot reproduce the bug:
- Check if it's environment-specific (OS, version, configuration)
- Check if it's timing-dependent (race condition, timeout, load-dependent)
- Check if it's state-dependent (corrupt data, stale cache, accumulated state)
- Add logging/instrumentation and wait for it to recur

### Phase 2: Gather Evidence

Collect information before forming theories.

**Read error output carefully:**
- Stack traces tell you the call chain. Read from bottom to top.
- Error messages often contain the exact cause. Don't gloss over them.
- Log timestamps reveal ordering and timing issues.

**Check recent changes:**
```bash
git log --oneline -20           # Recent commits
git log --oneline --all -20     # Including other branches
git diff HEAD~5                 # Changes in last 5 commits
git bisect start                # Binary search for breaking commit
```

**Inspect runtime state:**
- Add targeted logging at key decision points (input values, branch taken, return values).
- Check configuration values at runtime — are they what you expect?
- Inspect database state, file contents, environment variables.

**Check external dependencies:**
- Are external services responding? Check health endpoints.
- Are dependency versions what you expect? Check lock files.
- Has an external API changed its contract?

### Phase 3: Form Hypotheses

Based on the evidence, list possible causes ranked by likelihood.

**Common root cause categories:**

| Category | Examples |
|---|---|
| Input handling | Unexpected nil/null, wrong type, missing field, encoding issue |
| State management | Stale cache, race condition, leaked state between requests |
| Logic error | Off-by-one, wrong operator, inverted condition, missing case |
| Resource issue | Connection pool exhaustion, memory leak, file descriptor leak |
| Dependency | Version mismatch, API contract change, transitive dependency conflict |
| Configuration | Wrong environment, missing env var, incorrect feature flag |
| Timing | Race condition, timeout too short, clock skew, retry storm |

For each hypothesis, write down:
1. What the hypothesis is
2. What evidence supports it
3. What evidence would confirm or rule it out

### Phase 4: Test Hypotheses

Test each hypothesis systematically, starting with the most likely.

- **Add targeted assertions or logging** to confirm or deny each hypothesis.
- **Change one thing at a time**. If you change multiple things, you won't know which fixed it.
- **Record what you tested and the result**. This prevents re-testing the same thing and helps others.

**Elimination techniques:**
- **Binary search (bisect)**: Narrow the problem space by half at each step. Works for both code history (`git bisect`) and code paths.
- **Substitution**: Replace a suspected component with a known-good version. If the bug disappears, you've found the culprit.
- **Isolation**: Remove components until the bug disappears (or add components until it appears).

### Phase 5: Fix and Verify

Once you've identified the root cause:

1. **Implement the minimal fix** that addresses the root cause. Resist the urge to refactor or improve nearby code in the same change.
2. **Verify the fix** resolves the original reproduction case.
3. **Check for variants** — search the codebase for similar patterns that might have the same bug.
4. **Add a regression test** that would catch this bug if it were reintroduced.
5. **Run the full test suite** to ensure the fix doesn't break anything else.

### Anti-Patterns to Avoid

- **Shotgun debugging**: Changing things randomly hoping something works. This wastes time and can introduce new bugs.
- **Fixing symptoms**: Adding a nil check to prevent a crash without understanding why the value is nil.
- **Blame-driven debugging**: Assuming a specific component is at fault without evidence.
- **Tunnel vision**: Getting fixated on one hypothesis and ignoring contradicting evidence.
- **Skipping reproduction**: Trying to fix a bug you can't reproduce. You'll have no way to verify the fix.

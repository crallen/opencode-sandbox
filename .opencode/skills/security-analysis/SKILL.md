---
name: security-analysis
description: Structured security assessment methodology covering vulnerability taxonomy, data flow analysis, dependency auditing, and remediation patterns
---

## Security Analysis Methodology

This skill provides a systematic approach to application security assessment. Work through each phase in order, adapting depth to the scope of the analysis.

### Phase 1: Reconnaissance

Before looking for vulnerabilities, understand what you're analyzing.

**Identify the tech stack:**
- Language(s) and framework(s) — read package.json, go.mod, Cargo.toml, requirements.txt, Gemfile, pom.xml, etc.
- Database(s) — look for connection strings, ORM configs, migration files
- External services — API clients, message queues, cache layers, cloud SDKs
- Authentication system — session-based, JWT, OAuth, API keys, SAML

**Map entry points:**
- HTTP routes / API endpoints (controllers, handlers, route files)
- CLI argument parsing
- File upload / processing endpoints
- WebSocket handlers
- Background job / queue consumers
- Cron / scheduled task definitions

**Identify trust boundaries:**
- Where does user input enter the system?
- Where does the system talk to external services?
- Where does privilege change? (auth middleware, role checks)
- What runs with elevated permissions?

### Phase 2: Data Flow Analysis

Trace data from sources to sinks. This is the core of the assessment.

**Sources** (where untrusted data enters):
- HTTP request parameters (query, body, headers, cookies)
- File uploads
- Database reads (if data was originally user-supplied)
- Environment variables (in multi-tenant or shared environments)
- External API responses
- Deserialized data (JSON, XML, YAML, protobuf)

**Sinks** (where data reaches dangerous operations):
- SQL/NoSQL queries
- OS command execution (exec, spawn, system)
- File system operations (read, write, delete, path construction)
- HTML rendering (template engines, innerHTML, dangerouslySetInnerHTML)
- HTTP requests from the server (SSRF surface)
- Deserialization calls
- Cryptographic operations
- Logging calls (PII/secret exposure)
- Email/SMS sending (injection)
- Redirect URLs (open redirect)

**For each source-to-sink path, verify:**
1. Is the input validated? (type, format, length, range, allowed values)
2. Is the input sanitized/escaped for the target context?
3. Is there a parameterized API available? (prepared statements, template engines)
4. Are there intermediate checks? (authorization, rate limiting)

### Phase 3: Vulnerability Analysis by Category

Work through each category relevant to the codebase. Skip categories that don't apply.

#### Injection (CWE-74)
- **SQL injection**: Look for string concatenation in queries. Check ORM usage for raw query escape hatches.
- **Command injection**: Look for exec/spawn/system calls with user input. Check for shell metacharacter handling.
- **Template injection**: Look for user input passed as template strings rather than template variables.
- **LDAP/XPath/NoSQL injection**: Same pattern — user input in query construction without parameterization.

#### Authentication & Session Management (CWE-287)
- Are passwords hashed with a modern algorithm? (bcrypt, scrypt, argon2 — NOT md5, sha1, sha256 alone)
- Are sessions invalidated on logout and password change?
- Is there brute-force protection? (rate limiting, account lockout)
- Are JWTs validated properly? (signature verification, expiration, issuer, audience)
- Is the `none` algorithm rejected for JWTs?
- Are session tokens generated with a CSPRNG?

#### Access Control (CWE-284)
- Is authorization checked on every protected endpoint? (not just the frontend)
- Are there IDOR vulnerabilities? (sequential IDs, user can access other users' resources by guessing IDs)
- Is the principle of least privilege followed? (minimal permissions by default)
- Are admin functions protected by role checks on the backend?
- Is CORS configured restrictively? (not `*` in production)

#### Cryptography (CWE-310)
- Are deprecated algorithms in use? (MD5, SHA1 for integrity, DES, RC4, RSA-1024)
- Are keys/IVs hardcoded?
- Is the same IV reused across encryptions?
- Are random values generated with a CSPRNG? (not Math.random, not rand())
- Is TLS enforced for all external communications?
- Are certificates validated? (no `rejectUnauthorized: false` or `InsecureSkipVerify`)

#### Sensitive Data (CWE-200)
- Search for hardcoded secrets: `grep -r "password\|secret\|api.key\|token\|private.key" --include="*.{js,ts,py,go,rb,java,yaml,yml,json,toml,env}"`
- Check `.gitignore` — are secret files excluded? (.env, *.pem, credentials.json)
- Is PII logged? (email addresses, IP addresses, auth tokens in log output)
- Are error messages verbose enough to leak internal details? (stack traces, SQL errors, file paths)
- Is sensitive data stored encrypted at rest?

#### Security Configuration
- Is debug mode disabled in production configs?
- Are security headers set? (Content-Security-Policy, X-Frame-Options, X-Content-Type-Options, Strict-Transport-Security)
- Are default credentials changed?
- Are unnecessary features/endpoints disabled? (debug endpoints, admin panels, GraphQL introspection)
- Are file upload restrictions in place? (size, type, storage location)

#### Dependencies
- Run available audit tools:
  - Node.js: `npm audit` or `yarn audit`
  - Python: `pip audit` or `pip-audit`
  - Go: `govulncheck` (if available)
  - Ruby: `bundle audit` (if available)
- Check for pinned versions in lock files
- Look for abandoned or unmaintained dependencies (last commit date, open issues)
- Check for typosquatting risk (dependencies with similar names to popular packages)

### Phase 4: Threat Modeling (for larger assessments)

For significant features or systems, consider the STRIDE model:

| Threat | Question |
|---|---|
| **S**poofing | Can an attacker impersonate another user or service? |
| **T**ampering | Can an attacker modify data they shouldn't? |
| **R**epudiation | Can actions be performed without an audit trail? |
| **I**nformation Disclosure | Can an attacker access data they shouldn't? |
| **D**enial of Service | Can an attacker make the system unavailable? |
| **E**levation of Privilege | Can an attacker gain higher permissions? |

### Phase 5: Remediation Guidance

For each finding, provide:

1. **Specific fix** - Show the exact code change needed, not generic advice
2. **Defense in depth** - Suggest additional layers (WAF rules, monitoring, etc.)
3. **Prevention** - How to prevent this class of bug in the future (linting rules, code review gates, security tests)
4. **Priority** - Based on exploitability and impact, not just theoretical severity

**Common remediation patterns:**

| Vulnerability | Remediation |
|---|---|
| SQL injection | Parameterized queries / prepared statements |
| XSS | Context-aware output encoding; use framework's auto-escaping |
| Command injection | Avoid shell execution; use array-based APIs (execFile, not exec) |
| Path traversal | Canonicalize paths and verify they're within allowed directories |
| SSRF | Allowlist permitted hosts/IPs; block internal ranges |
| Insecure deserialization | Use data-only formats (JSON); validate schema before processing |
| Hardcoded secrets | Move to environment variables or a secret manager |
| Weak crypto | Upgrade to current algorithms; use a well-reviewed crypto library |

### Severity Scoring Guide

Use a simplified CVSS-like approach:

| Factor | CRITICAL | HIGH | MEDIUM | LOW |
|---|---|---|---|---|
| **Exploitability** | Remote, unauthenticated, trivial | Remote, authenticated or needs specific conditions | Requires local access or social engineering | Requires physical access or insider |
| **Impact** | RCE, full data breach, auth bypass | Significant data access, privilege escalation | Limited data access, account takeover (single user) | Information disclosure, DoS |
| **Affected users** | All users | Subset of users | Individual user | Admin only |

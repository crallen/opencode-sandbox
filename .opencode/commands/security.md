---
description: Run a security assessment on code, configuration, and dependencies
agent: security-analyst
subtask: true
---

Perform a security assessment of the codebase.

If specific files or directories are mentioned, focus the analysis there. Otherwise, assess the overall project.

Start by identifying the tech stack and mapping the attack surface, then analyze for vulnerabilities systematically.

If dependency manifests are present, run available audit commands (npm audit, pip audit, etc.).

$ARGUMENTS

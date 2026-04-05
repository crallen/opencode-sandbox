# OpenCode Sandbox

A Dockerized OpenCode environment with a custom suite of software engineering agents, skills, and commands designed for building software across any tech stack.

## Environment

This workspace runs inside a Docker container:

- **OS**: Debian bookworm-slim (minimal CVE surface)
- **User**: `opencode` (non-root, uid/gid 1000)
- **Workspace**: `/workspace` (mounted from host, read-write)
- **Reference projects**: `/reference/<name>/` (read-only, optional — see below)
- **Tools available**: `git`, `curl`, `jq`, `ripgrep`, `openssh-client`, `node`, `npm`, `nvm`
- **Not available**: `docker`, `sudo`, `apt-get` (non-root, no package installation)
- **SSH keys**: Mounted read-only from host at `~/.ssh`
- **Git config**: Mounted read-only from host at `~/.gitconfig`

Do not attempt to install system packages or run Docker commands from within the container.

### Reference Projects

The `/reference/` directory contains optional read-only mounts of other projects from the host. These are provided via the `--ref` flag when launching the container and are intended as reference material — source code you can read, search, and learn from, but never modify.

Use reference projects when you need to:
- Understand how a dependency or sibling project implements something
- Match API contracts, types, or interfaces defined in another repo
- Follow patterns and conventions established in a shared library
- Check how a similar problem was solved elsewhere in the organization

Each reference is mounted at `/reference/<directory-name>/`. For example, if the user ran `--ref ~/projects/shared-lib`, the code is available at `/reference/shared-lib/`.

**Permissions**: You can read, search, and list files under `/reference/`. You cannot edit, write, or delete anything there. All modifications must happen in `/workspace/`.

## Agent Suite

### Primary Agent: Architect (default)

The **architect** is the default primary agent and acts as an orchestrator. It:

- Analyzes requests and breaks complex work into structured plans
- Delegates specialist work to subagents via the Task tool
- Integrates results from subagents into cohesive solutions
- Handles straightforward tasks directly without delegation

Switch to the built-in **plan** agent (Tab key) for read-only analysis and planning.

### Specialist Subagents

These are invoked automatically by the architect or manually via `@mention`:

| Agent | Purpose | Permissions |
|---|---|---|
| `@code-reviewer` | Code quality and best practices review | Read-only. Cannot modify files. |
| `@security-analyst` | Security vulnerability assessment, dependency audits, threat modeling | Read-only. Cannot modify files. |
| `@tester` | Test generation, coverage analysis, test strategy | Full access. Writes test files, runs test suites. |
| `@debugger` | Root cause analysis and systematic debugging | Full access. Reads logs, traces code, applies fixes. |
| `@documenter` | Technical documentation and API docs | Write access. Bash limited to read-only commands. |
| `@devops` | Docker, CI/CD, infrastructure configuration | Full access. Writes configs, runs build commands. |
| `@git-manager` | Commits, branches, releases, changelogs | Write access. Bash limited to git and read commands. |
| `@frontend` | UI components, styling, accessibility, responsive design | Full access. Builds and tests frontend code. |
| `@agent-builder` | Creates, modifies, and reviews agents, skills, and slash commands | Write access. Bash limited to read-only commands. |

Plus the built-in subagents:

| Agent | Purpose |
|---|---|
| `@explore` | Fast read-only codebase search and file discovery |
| `@general` | General-purpose multi-step research and tasks |

### Available Skills

Skills are loaded on-demand by agents via the `skill` tool. They provide detailed procedural knowledge without consuming context until needed.

| Skill | Description | Primary users |
|---|---|---|
| `git-conventions` | Conventional Commits format, branching model, commit hygiene | git-manager, architect |
| `test-strategy` | Test type selection, coverage targets, mocking guidelines | tester, architect |
| `code-review-checklist` | Structured review rubric across 7 categories with severity levels | code-reviewer |
| `security-analysis` | Vulnerability taxonomy, data flow analysis, dependency auditing, remediation patterns | security-analyst |
| `debugging-methodology` | 5-phase debugging workflow: reproduce, gather, hypothesize, test, fix | debugger |
| `doc-templates` | Templates for READMEs, API docs, ADRs, changelogs, code comments | documenter |
| `docker-best-practices` | Multi-stage builds, security hardening, layer caching, Compose patterns | devops |
| `ci-pipeline` | CI/CD patterns for GitHub Actions and GitLab CI with caching strategies | devops |
| `frontend-patterns` | Component architecture, state management, accessibility, responsive design | frontend |
| `agent-authoring` | Schemas, templates, and conventions for creating agents, skills, and commands | agent-builder |

### Slash Commands

Quick-access commands for common workflows:

| Command | Action | Agent |
|---|---|---|
| `/review` | Review staged or unstaged changes for quality issues | code-reviewer |
| `/security` | Run a security assessment on code and dependencies | security-analyst |
| `/test` | Run tests and analyze results | tester |
| `/debug <description>` | Start a systematic debugging session | debugger |
| `/docs` | Generate or update documentation | documenter |
| `/commit` | Create a Conventional Commits message from staged changes | git-manager |
| `/release` | Prepare release notes, changelog, and version bump | git-manager |
| `/agent` | Create or modify an agent, skill, or command | agent-builder |
| `/agent-review` | Review agents, skills, and commands for correctness and consistency | agent-builder |

## General Guidelines

- **Language-agnostic**: Agents detect and adapt to whatever tech stack is in the workspace. Read project config files (package.json, go.mod, Cargo.toml, etc.) to understand conventions before making changes.
- **Conventional Commits**: All commits follow the Conventional Commits specification. Use `/commit` or `@git-manager` for well-formed commits.
- **Review before merge**: Use `/review` to check code quality and `/security` to assess security posture before committing significant changes.
- **Test with changes**: New functionality should include tests. Use `/test` to verify the test suite passes.
- **Keep docs current**: When making significant changes, update relevant documentation. Use `/docs` to assess and fill documentation gaps.
- **Use skills lazily**: Load skills via the `skill` tool only when you need the detailed procedural knowledge. Don't preload everything.
- **Existing conventions first**: Always read existing code before writing new code. Match the project's style, patterns, and file organization.
- **Never read `.env` files**: The global config denies `.env` file reads via the Read tool. Agents with bash access must also avoid reading `.env` files via shell commands (`cat`, `grep`, `source`, etc.). Treat `.env` files as off-limits regardless of access method.

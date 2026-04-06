# opencode-sandbox

A Dockerized [OpenCode](https://opencode.ai) environment with a custom suite of software engineering agents, skills, and slash commands. Mount any project into an isolated container and get a full AI coding team that adapts to whatever tech stack it finds.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- An LLM provider API key (e.g. `ANTHROPIC_API_KEY`)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/crallen/opencode-sandbox.git
cd opencode-sandbox

# Add the script to your PATH
ln -s "$(pwd)/bin/opencode-sandbox" ~/.local/bin/opencode-sandbox

# Run against any project directory
ANTHROPIC_API_KEY=sk-... opencode-sandbox ~/projects/myapp
```

The Docker image is built automatically on first run.

## Usage

```
opencode-sandbox [options] [workspace-path] [-- opencode-args...]
```

If `workspace-path` is omitted, the current directory is used.

### Options

| Flag | Description |
|---|---|
| `-r, --ref DIR` | Mount a read-only reference directory (repeatable) |
| `--build` | Force rebuild the Docker image |
| `--pull` | Pull the latest base image before building |
| `-h, --help` | Show help |

Everything after `--` is forwarded to the `opencode` binary inside the container.

### Examples

```bash
# Workspace is the current directory
opencode-sandbox

# Explicit workspace
opencode-sandbox ~/projects/myapp

# Mount sibling projects as read-only references
opencode-sandbox -r ../shared-lib -r ../api-contracts ~/projects/myapp

# Force a rebuild (e.g. after updating agents or skills)
opencode-sandbox --build .

# Pass flags to opencode itself
opencode-sandbox . -- --version
```

### API Keys

API keys are read from your shell environment. Set them however you normally would (`.bashrc`, `.zshrc`, a secrets manager, `direnv`, etc.). Keys are passed into the container via a temporary `--env-file` (not `-e` flags) so they don't appear in host process listings. The following variables are passed through when set:

- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `GOOGLE_API_KEY` / `GEMINI_API_KEY`
- `MISTRAL_API_KEY`
- `GROQ_API_KEY`
- `XAI_API_KEY`
- `DEEPSEEK_API_KEY`
- `OPENROUTER_API_KEY`
- `TOGETHER_API_KEY`
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` / `AWS_REGION`
- `AZURE_OPENAI_API_KEY` / `AZURE_OPENAI_ENDPOINT`

### Host Mounts

The following are mounted automatically when present:

| Host Path | Container Path | Mode |
|---|---|---|
| `~/.gitconfig` | `~/.gitconfig` | read-only |
| `$SSH_AUTH_SOCK` | `/tmp/ssh-agent.sock` | read-only |
| `~/.ssh` *(fallback)* | `~/.ssh` | read-only |

SSH authentication prefers **agent forwarding** via `SSH_AUTH_SOCK` — this avoids exposing private key files inside the container. If the agent socket is not available, the `~/.ssh` directory is mounted read-only as a fallback.

The entrypoint warns at startup if git config or SSH access is missing.

## What's Inside

### Container

- **Base**: Debian bookworm-slim (minimal CVE surface)
- **User**: `opencode` (non-root, UID/GID matched to host)
- **Tools**: `git`, `curl`, `jq`, `ripgrep`, `openssh-client`
- **Node.js**: LTS release (via nvm)
- **Rust**: latest stable toolchain — `rustc`, `cargo` (via rustup, minimal profile)
- **Go**: `go` 1.26.x (official tarball, pure-Go mode by default)
- **Python**: 3.13.x — `python`, `python3` (prebuilt via uv); use `uv pip` for package installation, `uvx` for one-off tool execution
- **Workspace**: `/workspace` (read-write, your project)
- **References**: `/reference/<name>/` (read-only, via `--ref`)
- **Session data**: Persisted in a Docker named volume (`opencode-data`)
- **User state**: Persisted in a Docker named volume (`opencode-state`) — theme selection, model preference, prompt history survive restarts
- **User settings**: Persisted in a Docker named volume (`opencode-config`) — `tui.json`, `opencode.json` edits survive restarts

### Agents

A primary orchestrator and 9 specialist subagents, all language-agnostic:

| Agent | Role | Permissions |
|---|---|---|
| **architect** | Orchestrator (default agent). Plans, delegates, integrates. | Full access |
| **code-reviewer** | Code quality and best practices review | Read-only |
| **security-analyst** | Vulnerability assessment, dependency audits, threat modeling | Read-only |
| **tester** | Test generation, coverage analysis, test strategy | Full access |
| **debugger** | Systematic root cause analysis and debugging | Full access |
| **documenter** | Technical documentation and API docs | Write access, read-only bash |
| **devops** | Docker, CI/CD, infrastructure configuration | Full access |
| **git-manager** | Commits, branches, releases, changelogs | Write access, git-only bash |
| **frontend** | UI components, styling, accessibility | Full access |
| **agent-builder** | Creates, modifies, and reviews agents, skills, and commands | Write access, read-only bash |

### Skills

Lazy-loaded procedural knowledge. Agents load these on demand via the `skill` tool to keep base context lean.

| Skill | Description |
|---|---|
| `git-conventions` | Conventional Commits format, branching model |
| `test-strategy` | Test pyramid, coverage targets, mocking guidelines |
| `code-review-checklist` | 7-category review rubric with severity levels |
| `security-analysis` | Vulnerability taxonomy, data flow analysis, remediation patterns |
| `debugging-methodology` | 5-phase systematic debugging workflow |
| `doc-templates` | README, API doc, ADR, and changelog templates |
| `docker-best-practices` | Multi-stage builds, security hardening, layer caching |
| `ci-pipeline` | GitHub Actions and GitLab CI patterns |
| `frontend-patterns` | Component architecture, accessibility, responsive design |
| `agent-authoring` | Schemas, templates, and conventions for authoring agents, skills, and commands |

### Slash Commands

| Command | Description |
|---|---|
| `/review` | Review code for quality issues |
| `/security` | Run a security assessment |
| `/test` | Run tests and analyze results |
| `/debug <description>` | Start a debugging session |
| `/docs` | Generate or update documentation |
| `/commit` | Create a Conventional Commits message |
| `/release` | Prepare release notes and version bump |
| `/agent` | Create or modify an agent, skill, or command |
| `/agent-review` | Review agents, skills, and commands for correctness and consistency |

## Architecture

```
opencode-sandbox/
├── bin/
│   └── opencode-sandbox          # Launcher script (the only thing you run)
├── build/
│   ├── Dockerfile                # Debian bookworm-slim, polyglot toolchains, OpenCode
│   ├── entrypoint.sh             # UID/GID remapping, pre-flight checks, exec opencode
│   └── scripts/
│       ├── install-go.sh         # Go — pinned version, edit to upgrade
│       ├── install-rust.sh       # Rust — latest stable channel (via rustup)
│       ├── install-node.sh       # Node.js — latest LTS channel (via nvm)
│       └── install-python.sh     # Python — pinned version (via uv)
├── .opencode/
│   ├── config/
│   │   ├── opencode.json         # Global config (baked into image)
│   │   └── AGENTS.md             # Global rules and environment docs (baked into image)
│   ├── agents/                   # Agent definitions (bind-mounted read-only)
│   ├── skills/                   # Skill definitions (bind-mounted read-only)
│   └── commands/                 # Slash command definitions (bind-mounted read-only)
├── LICENSE
└── README.md
```

**Config and AGENTS.md** are baked into the Docker image and seeded into the persistent `opencode-config` volume on first run. User settings (`tui.json`, `opencode.json` edits) persist in `opencode-config`, while runtime preferences (theme selection, model choice, prompt history) persist in `opencode-state`. Agents, skills, and commands are bind-mounted read-only from this repo so edits are picked up on container restart without rebuilding.

**Projects mounted at `/workspace`** can provide their own `.opencode/` directory and `opencode.json` to layer project-specific agents, skills, and configuration on top of the global defaults. OpenCode's config precedence handles the merge automatically.

### Permissions

The global `opencode.json` sets these defaults:

- `/workspace` — full read-write access, no approval prompts
- `/reference/*` — read, search, and list allowed; edits denied
- External directories — denied by default (only `/reference/*` is allowlisted)
- `.env` files — read denied (prevents accidental secret exposure)

## Customization

### Adding agents, skills, or commands

Add files to `.opencode/agents/`, `.opencode/skills/`, or `.opencode/commands/` following the existing patterns. Changes are picked up on the next container start (no rebuild needed).

### Changing the global config

Edit `.opencode/config/opencode.json` or `.opencode/config/AGENTS.md`, then rebuild:

```bash
opencode-sandbox --build .
```

### Per-project overrides

Any project mounted at `/workspace` can include its own:
- `.opencode/agents/` — additional or overriding agents
- `.opencode/skills/` — additional skills
- `.opencode/commands/` — additional commands
- `opencode.json` — project-specific config (overrides global)
- `AGENTS.md` — project-specific rules (supplements global)

## License

[MIT](LICENSE)

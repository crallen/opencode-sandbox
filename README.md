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

The launcher pulls the image from GHCR automatically on first run.

## Usage

```
opencode-sandbox [options] [workspace-path] [-- opencode-args...]
```

If `workspace-path` is omitted, the current directory is used.

### Options

| Flag | Description |
|---|---|
| `-r, --ref DIR` | Mount a read-only reference directory (repeatable) |
| `-k, --key FILE` | SSH private key to mount for git/cargo authentication; on Linux, agent forwarding is used by default (see [Host Mounts](#host-mounts)) |
| `-V, --volume-preset P` | Mount named Docker volumes for build artifact directories, bypassing the slow gRPC FUSE workspace mount (repeatable; see [Volume Presets](#volume-presets)) |
| `--clean` | Remove workspace-scoped volumes for the current workspace, then exit |
| `--host-network` | Use the host's network stack; allows the container to reach services on `localhost` (Linux only — on macOS/Windows use `host.docker.internal` instead) |
| `--pull` | Check GHCR for a newer image and pull if the digest has changed |
| `--build` | Build the Docker image locally from source |
| `--build --pull` | Build locally, refreshing the base image first |
| `-h, --help` | Show help |

Everything after `--` is forwarded to the `opencode` binary inside the container.

### Flag Behavior

| Invocation | Behavior |
|---|---|
| `opencode-sandbox` | Use cached GHCR image if present; pull on first run |
| `opencode-sandbox --pull` | Digest-check GHCR; pull only if outdated |
| `opencode-sandbox --build` | Build locally → `opencode-sandbox` image |
| `opencode-sandbox --build --pull` | Build locally, refreshing base image first |

### Examples

```bash
# Workspace is the current directory
opencode-sandbox

# Explicit workspace
opencode-sandbox ~/projects/myapp

# Mount sibling projects as read-only references
opencode-sandbox -r ../shared-lib -r ../api-contracts ~/projects/myapp

# Use a specific SSH key (macOS default; also works on Linux via -k)
opencode-sandbox -k ~/.ssh/my_github_key ~/projects/myapp

# Fast node_modules volume (bypasses grpcfuse)
opencode-sandbox -V node ~/projects/myapp

# Multiple presets: fast node_modules and Rust target + Cargo cache
opencode-sandbox -V node -V rust ~/projects/myapp

# Remove workspace-scoped volumes (e.g. to force a clean build)
opencode-sandbox --clean ~/projects/myapp

# Reach a database running on the host (Linux only)
opencode-sandbox --host-network ~/projects/myapp

# Update to the latest GHCR image
opencode-sandbox --pull .

# Build locally from source (dev workflow)
opencode-sandbox --build .

# Pass flags to opencode itself
opencode-sandbox . -- --version
```

### I/O Performance on macOS

On macOS, Docker Desktop mounts the workspace via **gRPC FUSE**, a userspace filesystem that proxies every file operation over a gRPC socket to the host. The round-trip overhead is noticeable for anything that touches many files:

- `node_modules` — thousands of small files read during startup and builds
- `target/` — large Rust build artifacts with frequent stat/mtime checks
- `~/.cargo/registry` and `~/.cargo/git` — Cargo dependency cache
- `~/go/` — Go module cache and compiled packages

There are two complementary ways to improve this.

#### Option 1: Enable VirtioFS in Docker Desktop

VirtioFS replaces gRPC FUSE with a shared-memory transport, significantly reducing filesystem latency across the entire workspace mount — no code or flag changes needed.

To enable it: **Docker Desktop → Settings → General → Virtual file sharing implementation → VirtioFS**, then apply and restart.

VirtioFS is not enabled by default; you must opt in regardless of hardware. It requires Docker Desktop 4.6 or later.

**Tradeoffs:**
- ✅ Zero application changes — improves the whole workspace transparently
- ✅ Better file watcher reliability (Vite HMR, webpack watch mode)
- ⚠️ Still slower than a native Docker volume for the highest-churn directories
- ⚠️ macOS only (Linux hosts use the host kernel directly and are unaffected)

#### Option 2: Named volumes with `-V`/`--volume-preset`

The `-V`/`--volume-preset` flag mounts named Docker volumes over specific high-churn directories. Named volumes live on the Linux VM's native ext4 filesystem and bypass gRPC FUSE (or VirtioFS) entirely, giving the best possible I/O for build artifacts.

| Preset | Volumes mounted | Scope |
|---|---|---|
| `node` | `/workspace/node_modules` | Per-workspace |
| `rust` | `/workspace/target`, `~/.cargo/registry`, `~/.cargo/git` | `target` per-workspace; Cargo cache shared |
| `go` | `~/go` (full GOPATH) | Shared across all workspaces |

**Per-workspace** volumes are isolated per project (named with the workspace directory slug). **Shared** volumes are reused across all workspaces so downloaded packages are cached globally.

> **Note:** On first use, the volume will be empty. Run `npm install`, `cargo build`, etc. inside the container once to populate it. Subsequent runs will reuse the cached contents.

Use `--clean` to remove the workspace-scoped volumes for the current workspace (useful when you need a completely fresh `node_modules` or `target`). Shared volumes (Cargo registry, GOPATH) are never removed by `--clean`.

**Tradeoffs:**
- ✅ Fastest possible I/O for the covered directories — native ext4, no translation layer
- ✅ Works regardless of which file sharing backend Docker Desktop is using
- ⚠️ Volume contents are not visible on the host filesystem
- ⚠️ Volumes must be populated on first use
- ⚠️ Per-workspace volumes consume disk space in the Docker VM; use `--clean` to reclaim it

#### Recommendation

Enable **VirtioFS** as a baseline — it improves the whole workspace for free. Then add **`-V` presets** for the specific directories where you're doing heavy build work. The two options stack.

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
| `$SSH_AUTH_SOCK` | `/tmp/ssh-agent.sock` | read-write *(Linux hosts only)* |
| `~/.ssh/id_ed25519` or `~/.ssh/id_rsa` *(macOS hosts; or override with `-k`)* | `~/.ssh/id` | read-only |

On **Linux hosts**, the container shares the host kernel so the SSH agent socket can be bind-mounted directly and agent forwarding works normally.

On **macOS hosts**, Docker Desktop runs containers in a Linux VM and the launchd SSH agent socket cannot cross the VM boundary. Instead, the launcher mounts a single key file (`id_ed25519` preferred, falling back to `id_rsa`) and sets `GIT_SSH_COMMAND` to invoke `ssh` with that key explicitly — bypassing `~/.ssh/config` entirely, which avoids errors from macOS-specific directives (`UseKeychain`, `AddKeysToAgent`) that the Linux `ssh` binary does not understand.

The entrypoint warns at startup if git config or SSH access is missing.

### Networking

By default the container uses Docker's bridge network and has outbound internet access.

**Reaching host services (e.g. a local database):**

| Host OS | How to connect |
|---|---|
| **Linux** | Pass `--host-network`; use `localhost` as normal |
| **macOS / Windows** | Use `host.docker.internal` as the hostname; Docker Desktop resolves this to the host from within any container |

On macOS and Windows, Docker Desktop runs containers inside a Linux VM. `--network host` attaches the container to that VM's network, not the host's — so `localhost` inside the container refers to the VM, not your machine. `host.docker.internal` is the correct way to reach the host.

If the service you want to reach is another Docker container with port forwarding configured (e.g. `-p 5432:5432`), it is reachable via `host.docker.internal:5432` on macOS/Windows, or via `localhost:5432` with `--host-network` on Linux.

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
- **Session data**: Persisted in a Docker named volume scoped per workspace (`opencode-data-<workspace-name>`) — sessions and history are isolated between projects
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

## Known Limitations

### Rust / Cargo

`cargo check`, `cargo build`, and `cargo test` require a writable `~/.rustup/tmp` at runtime (rustup creates it to resolve the active toolchain before invoking `cargo`). The entrypoint fixes this automatically by chowning the relevant subdirectories at container start, so these commands work normally.

**Private SSH git dependencies** (e.g. `{ git = "ssh://git@github.com/org/repo.git" }` in `Cargo.toml`) require SSH access to GitHub. The container has outbound network access and will use either the forwarded agent socket (Linux hosts) or the mounted key file (macOS) for authentication — both work as long as the relevant key is available.

### Node.js / Vite / Rollup

Vite and Rollup ship platform-specific native binaries as optional npm packages (e.g. `@rollup/rollup-linux-arm64-gnu`). If `node_modules` was installed on a different OS/architecture (e.g. macOS), the linux/arm64 binary will be missing and `vite build` or the Vite dev server will fail with `Cannot find module @rollup/rollup-linux-arm64-gnu`.

**Fix**: run `npm install` inside the container once (the container has network access) to let npm fetch the correct native binary for the container's architecture. `eslint` and `tsc --noEmit` are unaffected and work correctly without it.

### Go

`go build` and `go test` work for projects with public module dependencies (fetched via GOPROXY over HTTPS). For private modules requiring SSH, the same key file / agent forwarding setup applies as for Cargo above.

## CI & Published Image

The image is built and published to GHCR via GitHub Actions on every `v*` tag push:

- **Registry**: `ghcr.io/crallen/opencode-sandbox`
- **Architectures**: `linux/amd64` and `linux/arm64`
- **Tags published**: `latest`, `<major>`, `<major>.<minor>`, `<major>.<minor>.<patch>`

On non-tag pushes to `main`, the workflow runs a build-only smoke test without pushing to the registry.

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

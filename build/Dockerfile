FROM debian:bookworm-slim@sha256:f06537653ac770703bc45b4b113475bd402f451e85223f0f2837acbf89ab020a

# Install system dependencies.
# build-essential + pkg-config + libssl-dev are required by Rust (linker and
# common crate build deps). The remaining packages support agentic workflows
# and gosu for runtime privilege dropping.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gosu \
    jq \
    libssl-dev \
    openssh-client \
    pkg-config \
    ripgrep \
    && rm -rf /var/lib/apt/lists/* \
    && gosu nobody true

# Create non-root user with default UID/GID (remapped at runtime by entrypoint)
RUN groupadd -g 1000 opencode \
    && useradd -m -u 1000 -g opencode -s /bin/bash opencode

# Create directories that will be used for volumes
RUN mkdir -p /home/opencode/.local/share/opencode \
             /home/opencode/.local/state/opencode \
             /home/opencode/.config/opencode \
             /workspace \
             /reference \
    && chown -R opencode:opencode /home/opencode /workspace /reference

# ---------------------------------------------------------------------------
# Toolchain installs — ordered by change frequency (least → most) so that
# bumping one toolchain's version only invalidates that layer and below.
# Each toolchain lives in its own script; edit the script to bump the version.
#
# PATH and toolchain home dirs are declared here, before the install scripts
# run, so that each script sees the correct environment (e.g. cargo/python
# binaries are findable immediately after install without per-script hacks).
# ---------------------------------------------------------------------------

ENV \
    # Rust
    RUSTUP_HOME="/home/opencode/.rustup" \
    CARGO_HOME="/home/opencode/.cargo" \
    # Go
    GOROOT="/usr/local/go" \
    GOPATH="/home/opencode/go" \
    GOTOOLCHAIN="local" \
    CGO_ENABLED="0" \
    # Node (nvm)
    NVM_DIR="/home/opencode/.nvm" \
    # Consolidated PATH — covers all toolchain bin dirs so install scripts
    # and subsequent RUN steps can invoke installed binaries directly
    PATH="/home/opencode/.local/bin:/home/opencode/.opencode/bin:/home/opencode/.cargo/bin:/home/opencode/go/bin:/usr/local/go/bin:/home/opencode/.nvm/current:${PATH}"

# Go — installed as root to /usr/local/go; creates GOPATH at ~/go
COPY build/scripts/install-go.sh /tmp/install-go.sh
RUN /tmp/install-go.sh && rm /tmp/install-go.sh

# uv — static Rust binary, no apt deps; used for Python version management
# and as a drop-in replacement for pip/virtualenv/pipx
COPY --from=ghcr.io/astral-sh/uv:0.11.3@sha256:90bbb3c16635e9627f49eec6539f956d70746c409209041800a0280b93152823 /uv /uvx /bin/

# Switch to non-root user for remaining toolchain installs
USER opencode

# Rust — latest stable channel (no pinned version; Rust's stability guarantee
# makes this safe, and it mirrors the Node LTS pattern)
COPY --chown=opencode:opencode build/scripts/install-rust.sh /tmp/install-rust.sh
RUN /tmp/install-rust.sh && rm /tmp/install-rust.sh

# Node.js — latest LTS via nvm
COPY --chown=opencode:opencode build/scripts/install-node.sh /tmp/install-node.sh
RUN /tmp/install-node.sh && rm /tmp/install-node.sh

# Python — pinned version via uv (most likely to change; kept last among
# static toolchains so version bumps only invalidate Python + OpenCode)
COPY --chown=opencode:opencode build/scripts/install-python.sh /tmp/install-python.sh
RUN /tmp/install-python.sh && rm /tmp/install-python.sh

# OpenCode — always installs the latest release; kept after all toolchains
# so upstream releases don't invalidate toolchain layers
RUN curl -fsSL https://opencode.ai/install | bash

# ---------------------------------------------------------------------------
# Terminal configuration
# ---------------------------------------------------------------------------

ENV \
    TERM=xterm-256color \
    COLORTERM=truecolor

# ---------------------------------------------------------------------------
# OpenCode configuration
# ---------------------------------------------------------------------------

# Copy global OpenCode config and AGENTS.md into the image.
# These go into both the config dir (for Docker volume auto-init on first run)
# and a separate defaults dir (used by the entrypoint to sync repo-managed
# files into the persistent config volume on every container start).
COPY --chown=opencode:opencode .opencode/config/opencode.json /home/opencode/.config/opencode/opencode.json
COPY --chown=opencode:opencode .opencode/config/AGENTS.md /home/opencode/.config/opencode/AGENTS.md

RUN mkdir -p /home/opencode/.config/opencode.defaults
COPY --chown=opencode:opencode .opencode/config/opencode.json /home/opencode/.config/opencode.defaults/opencode.json
COPY --chown=opencode:opencode .opencode/config/AGENTS.md /home/opencode/.config/opencode.defaults/AGENTS.md

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

# Switch back to root so entrypoint can remap UID/GID before dropping privileges.
# NOTE: Final USER is root intentionally — the entrypoint handles privilege
# dropping via gosu after remapping. Do not add "USER opencode" after this line.
USER root

COPY build/entrypoint.sh /home/opencode/entrypoint.sh
RUN chmod +x /home/opencode/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/home/opencode/entrypoint.sh"]

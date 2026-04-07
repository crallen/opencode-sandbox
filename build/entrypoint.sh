#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Runtime UID/GID remapping
# ---------------------------------------------------------------------------
# The image is built with opencode at 1000:1000. At runtime, the launcher
# script passes the host user's UID/GID as environment variables so that
# file ownership on bind-mounted volumes (especially /workspace) is correct.
#
# If HOST_UID/HOST_GID are not set, we detect them from /workspace ownership.
# NOTE: The stat fallback is reliable on Linux where bind mounts preserve
# host ownership. On macOS Docker Desktop, stat returns 0:0 (root), so the
# HOST_UID/HOST_GID env vars set by the launcher are required.
#
# If the detected or supplied IDs differ from the built-in 1000:1000, we
# remap the opencode user/group, fix ownership of its home directory, and
# then drop privileges with gosu.
#
# This entire block only runs when the entrypoint is invoked as root (the
# default). If the container is started with --user, we skip remapping.
# ---------------------------------------------------------------------------

TARGET_USER="opencode"
CURRENT_UID="$(id -u "$TARGET_USER")"
CURRENT_GID="$(id -g "$TARGET_USER")"

# ---------------------------------------------------------------------------
# Shared helpers — used by both root and non-root paths
# ---------------------------------------------------------------------------

info() { echo "==> $1"; }

# Sync repo-managed config files into the persistent config volume.
# Files like AGENTS.md and opencode.json are repo-managed — they define the
# agent suite and permissions and must always reflect the latest version from
# the image. User-editable files (tui.json, etc.) are NOT in the defaults
# directory and are never touched by this logic.
#
# Usage: sync_config <config_dir> <defaults_dir> [uid:gid]
sync_config() {
    local config_dir="$1" defaults_dir="$2" owner="${3:-}"
    for default_file in "$defaults_dir"/*; do
        [ -e "$default_file" ] || continue
        local filename
        filename="$(basename "$default_file")"
        cp "$default_file" "$config_dir/$filename" 2>/dev/null || true
        [ -n "$owner" ] && chown "$owner" "$config_dir/$filename" 2>/dev/null || true
    done
}

# Warn about missing git/SSH configuration and known sandbox limitations.
preflight_checks() {
    local home="$1"
    if [ ! -s "$home/.gitconfig" ]; then
        echo "WARNING: ~/.gitconfig not mounted or empty. Git operations may lack user identity."
        echo "         Ensure your host has a ~/.gitconfig file."
    fi

    if [ -z "${SSH_AUTH_SOCK:-}" ] && [ -z "${SSH_IDENTITY_FILE:-}" ]; then
        echo "WARNING: No SSH auth available. SSH-based git operations will fail."
        echo "         On macOS, ensure ~/.ssh/id_ed25519 or ~/.ssh/id_rsa exists."
        echo "         On Linux, ensure SSH_AUTH_SOCK is set to a live agent socket."
    fi

    # Warn if the workspace has a Cargo.toml with SSH git dependencies but no
    # usable SSH auth is available.
    if [ -f /workspace/Cargo.toml ] && \
       grep -q 'git = "ssh://' /workspace/Cargo.toml 2>/dev/null; then
        if [ -z "${SSH_AUTH_SOCK:-}" ] && [ -z "${SSH_IDENTITY_FILE:-}" ]; then
            echo "WARNING: Cargo.toml has SSH git dependencies but no SSH auth is available."
            echo "         Cargo fetch will fail with a public-key authentication error."
        fi
    fi
}

# ---------------------------------------------------------------------------
# Root path — remap UID/GID, fix ownership, drop privileges
# ---------------------------------------------------------------------------

if [ "$(id -u)" = "0" ]; then
    info "Preparing environment..."

    # Determine desired UID/GID — prefer explicit env vars, fall back to
    # the ownership of /workspace (which reflects the host user on Linux).
    HOST_UID="${HOST_UID:-$(stat -c '%u' /workspace 2>/dev/null || echo "$CURRENT_UID")}"
    HOST_GID="${HOST_GID:-$(stat -c '%g' /workspace 2>/dev/null || echo "$CURRENT_GID")}"

    # Validate: must be a positive integer, not root (0). Reject anything
    # else to prevent sed injection or accidental root remapping (e.g. macOS
    # Docker Desktop returns 0:0 from stat on bind mounts).
    if ! [[ "$HOST_UID" =~ ^[1-9][0-9]*$ ]]; then
        echo "WARNING: HOST_UID is invalid or root (got: '${HOST_UID}'). Falling back to ${CURRENT_UID}."
        HOST_UID="$CURRENT_UID"
    fi
    if ! [[ "$HOST_GID" =~ ^[1-9][0-9]*$ ]]; then
        echo "WARNING: HOST_GID is invalid or root (got: '${HOST_GID}'). Falling back to ${CURRENT_GID}."
        HOST_GID="$CURRENT_GID"
    fi

    NEEDS_REMAP=false

    # --- Remap GID if needed ---
    if [ "$HOST_GID" != "$CURRENT_GID" ]; then
        NEEDS_REMAP=true
        if getent group "$HOST_GID" >/dev/null 2>&1; then
            # Target GID already taken (e.g. macOS GID 20 = dialout).
            # Point the opencode user at the existing group.
            EXISTING_GROUP="$(getent group "$HOST_GID" | cut -d: -f1)"
            usermod -g "$EXISTING_GROUP" "$TARGET_USER" 2>/dev/null || \
                sed -i "s/^\(${TARGET_USER}:[^:]*:[^:]*:\)[0-9]\+/\1${HOST_GID}/" /etc/passwd
        else
            groupmod -g "$HOST_GID" opencode 2>/dev/null || \
                sed -i "s/^\(opencode:[^:]*:\)[0-9]\+/\1${HOST_GID}/" /etc/group
        fi
    fi

    # --- Remap UID if needed ---
    if [ "$HOST_UID" != "$CURRENT_UID" ]; then
        NEEDS_REMAP=true
        # Use sed to edit /etc/passwd directly — avoids usermod's attempt to
        # chown the home directory, which can fail on large trees or volumes.
        sed -i "s/^\(${TARGET_USER}:[^:]*:\)[0-9]\+/\1${HOST_UID}/" /etc/passwd
    fi

    # --- Fix file ownership if needed ---
    # Recursive chown on persistent volumes (session data, state, cache) is
    # the main startup cost and grows with usage. We use a sentinel file to
    # track whether a previous run already completed the chown for this
    # UID:GID pair. This is safe against interrupted runs — if the container
    # is killed mid-chown, the sentinel won't exist and the next run retries.
    CHOWN_SENTINEL="/home/opencode/.chown_done_${HOST_UID}_${HOST_GID}"

    if [ "$NEEDS_REMAP" = true ] && [ ! -f "$CHOWN_SENTINEL" ]; then
        info "Adjusting file ownership to ${HOST_UID}:${HOST_GID}..."

        # Fix ownership of writable paths only. We intentionally skip
        # large read-only toolchain trees baked into the image — chowning
        # them on every first run would be prohibitively slow:
        #   - .nvm/      (~5000 files) — Node.js via nvm
        #   - .rustup/   (~thousands of files) — Rust toolchain
        #   - .cargo/    — Rust binaries and registry cache
        #   - .local/share/uv/ — uv-managed Python installs
        #   - /usr/local/go — Go standard library (root-owned, never chowned)
        #   - ~/go/      — GOPATH; same tradeoff as .nvm (owned by build UID)
        # NOTE: Tools installed into these trees after container start (e.g.
        # `go install`, `cargo install`) will be owned by the runtime UID and
        # work correctly. The pre-built binaries remain usable via PATH.
        #   - Read-only bind-mounts under .config/opencode/ (agents, skills, commands)
        #
        # The home directory itself must be owned by the user so that tools
        # (opencode, npm, etc.) can create subdirs like .cache at runtime.
        chown "${HOST_UID}:${HOST_GID}" /home/opencode

        # Writable subdirectories
        for dir in \
            /home/opencode/.local \
            /home/opencode/.cache \
            /home/opencode/.opencode \
        ; do
            [ -e "$dir" ] && chown -R "${HOST_UID}:${HOST_GID}" "$dir"
        done

        # Writable files in home
        for f in \
            /home/opencode/.bashrc \
            /home/opencode/.bash_logout \
            /home/opencode/.profile \
        ; do
            [ -e "$f" ] && chown "${HOST_UID}:${HOST_GID}" "$f"
        done

        # .config — chown the directory and its direct writable contents, but
        # skip the read-only bind-mounted subdirs (agents, skills, commands).
        chown "${HOST_UID}:${HOST_GID}" /home/opencode/.config
        chown "${HOST_UID}:${HOST_GID}" /home/opencode/.config/opencode 2>/dev/null || true
        # Chown writable files in config (opencode.json, AGENTS.md, tui.json, etc.)
        find /home/opencode/.config/opencode -maxdepth 1 -type f -exec \
            chown "${HOST_UID}:${HOST_GID}" {} + 2>/dev/null || true
        # Chown the defaults dir (always writable, baked into the image)
        [ -d /home/opencode/.config/opencode.defaults ] && \
            chown -R "${HOST_UID}:${HOST_GID}" /home/opencode/.config/opencode.defaults

        # Mark chown as complete. Remove stale sentinels from previous UID/GID
        # pairs first so only the current one remains.
        rm -f /home/opencode/.chown_done_* 2>/dev/null || true
        touch "$CHOWN_SENTINEL"
        chown "${HOST_UID}:${HOST_GID}" "$CHOWN_SENTINEL"
    fi

    # --- Fix writable subdirectories inside skipped toolchain trees ---
    # The large toolchain trees (.rustup, .cargo, .nvm, go/) are deliberately
    # skipped by the chown block above for performance — chowning thousands of
    # files on every first run is prohibitively slow. However, each toolchain
    # needs to write into specific subdirectories at runtime (e.g. rustup needs
    # .rustup/tmp to resolve the active toolchain; cargo needs .cargo/git/ and
    # .cargo/registry/ to cache fetched dependencies; go needs ~/go/pkg/mod/).
    #
    # The fix: ensure those specific write-target directories exist and are
    # owned by the runtime user. We create them if missing and chown them
    # directly — no recursion needed, just the directory itself. Any files
    # already inside (from the image build) stay with their original ownership
    # but the directories are writable so the tools can create new entries.
    #
    # This runs unconditionally on every start (not gated on NEEDS_REMAP or
    # the sentinel) because these dirs may need fixing regardless of whether
    # a UID remap occurred, and the operation is cheap (a handful of chowns).

    # Top-level toolchain home dirs — chown only the directory itself so the
    # runtime user can create subdirectories (e.g. .rustup/tmp, .cargo/git/).
    for dir in \
        /home/opencode/.rustup \
        /home/opencode/.cargo \
    ; do
        chown "${HOST_UID}:${HOST_GID}" "$dir" 2>/dev/null || true
    done

    # Specific write-target subdirectories that toolchains create/use at runtime.
    # These are created if missing and chowned — no recursion into the large
    # baked-in toolchain trees.
    for dir in \
        /home/opencode/.rustup/tmp \
        /home/opencode/.rustup/toolchains \
        /home/opencode/.rustup/update-hashes \
        /home/opencode/.cargo/bin \
        /home/opencode/.cargo/git \
        /home/opencode/.cargo/registry \
        /home/opencode/go/pkg \
        /home/opencode/go/pkg/mod \
    ; do
        mkdir -p "$dir" 2>/dev/null || true
        chown "${HOST_UID}:${HOST_GID}" "$dir" 2>/dev/null || true
    done

    # --- Fix ownership of named volume mount points under /workspace ---
    # When a -V/--volume-preset volume is used (node, rust, go), Docker
    # initialises the new named volume as an empty root:root 755 directory.
    # The entrypoint runs as root before dropping privileges, so we chown any
    # of the known preset mount points that exist. This is unconditional and
    # cheap — just a handful of chowns on directory entries, no recursion.
    for dir in \
        /workspace/node_modules \
        /workspace/target \
    ; do
        [ -d "$dir" ] && chown "${HOST_UID}:${HOST_GID}" "$dir" 2>/dev/null || true
    done

    # --- Sync config & pre-flight checks ---
    sync_config "/home/opencode/.config/opencode" \
                "/home/opencode/.config/opencode.defaults" \
                "${HOST_UID}:${HOST_GID}"
    preflight_checks "/home/opencode"

    # --- Configure git safe directory ---
    # /workspace is a bind-mount owned by the host user. Git refuses to
    # operate in directories not owned by the current user, so we register
    # /workspace as a safe directory for the opencode user. This must be done
    # as root writing to the opencode user's gitconfig before dropping privs.
    gosu "$TARGET_USER" git config --global --add safe.directory /workspace 2>/dev/null || true

    # --- Configure SSH identity for git/cargo ---
    # When a specific key file is mounted (SSH_IDENTITY_FILE is set by the
    # launcher), point GIT_SSH_COMMAND at it explicitly. This bypasses
    # ~/.ssh/config entirely — no risk of macOS-specific directives
    # (UseKeychain, AddKeysToAgent) breaking the Linux ssh binary.
    if [ -n "${SSH_IDENTITY_FILE:-}" ]; then
        export GIT_SSH_COMMAND="ssh -i ${SSH_IDENTITY_FILE} -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
        export CARGO_NET_GIT_FETCH_WITH_CLI=true
    fi

    # --- Drop privileges and launch OpenCode ---
    info "Starting OpenCode..."
    # gosu replaces this process with the target user — root is gone.
    # $NVM_DIR/current is already on PATH (set in Dockerfile), so we don't
    # need to source nvm.sh (which may fail to write cache files when .nvm
    # is not owned by the remapped user).
    export HOME="/home/opencode"
    exec gosu "$TARGET_USER" opencode "$@"
fi

# ---------------------------------------------------------------------------
# Fallback: container started with --user (non-root)
# ---------------------------------------------------------------------------
# No remapping possible; just sync config, check environment, and run.

info "Preparing environment..."

sync_config "$HOME/.config/opencode" "$HOME/.config/opencode.defaults"
preflight_checks "$HOME"

# /workspace is a bind-mount that may be owned by a different UID than the
# container user. Register it as a git safe directory so git commands work.
git config --global --add safe.directory /workspace 2>/dev/null || true

# Configure SSH identity for git/cargo (see root path above).
if [ -n "${SSH_IDENTITY_FILE:-}" ]; then
    export GIT_SSH_COMMAND="ssh -i ${SSH_IDENTITY_FILE} -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
    export CARGO_NET_GIT_FETCH_WITH_CLI=true
fi

export NVM_DIR="$HOME/.nvm"
# Source nvm.sh to enable `nvm` shell functions (e.g. `nvm install`, `nvm use`).
# The `node` binary itself works without this via the $NVM_DIR/current symlink
# on PATH. Rust, Go, and Python binaries similarly work without sourcing because
# their bin directories are on PATH directly via the Dockerfile ENV.
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

info "Starting OpenCode..."
exec opencode "$@"

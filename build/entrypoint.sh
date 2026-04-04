#!/usr/bin/env bash
set -euo pipefail

# --- Sync repo-managed config files into the persistent config volume ---
#
# The config volume (opencode-config) is mounted at ~/.config/opencode/.
# Files like AGENTS.md and opencode.json are repo-managed — they define the
# agent suite and permissions.  These must always reflect the latest version
# from the image, so we overwrite them unconditionally on every container start.
#
# User-editable files (tui.json, etc.) are NOT in the defaults directory and
# are never touched by this logic.
#
# /home/opencode/.config/opencode.defaults/ holds the image-baked originals.

CONFIG_DIR="$HOME/.config/opencode"
DEFAULTS_DIR="$HOME/.config/opencode.defaults"

for default_file in "$DEFAULTS_DIR"/*; do
    [ -e "$default_file" ] || continue          # skip if glob matched nothing
    filename="$(basename "$default_file")"
    target="$CONFIG_DIR/$filename"
    cp "$default_file" "$target"
done

# --- Pre-flight checks ---

# Warn if git config is not mounted or is empty/directory
if [ ! -s "$HOME/.gitconfig" ]; then
    echo "WARNING: ~/.gitconfig not mounted or empty. Git operations may lack user identity."
    echo "         Ensure your host has a ~/.gitconfig file."
fi

# Warn if neither SSH agent forwarding nor SSH directory is available
if [ -z "${SSH_AUTH_SOCK:-}" ] && { [ ! -d "$HOME/.ssh" ] || [ -z "$(ls -A "$HOME/.ssh" 2>/dev/null)" ]; }; then
    echo "WARNING: No SSH agent or ~/.ssh directory found. SSH-based git operations will fail."
    echo "         Start an ssh-agent on the host, or ensure ~/.ssh exists with keys."
fi

# --- Launch OpenCode ---

exec opencode "$@"

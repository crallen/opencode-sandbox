#!/usr/bin/env bash
set -euo pipefail

# Runs as opencode (non-root) during Docker build.
# NVM_VERSION controls the nvm installer itself; the Node.js version is always
# the current LTS, mirroring the Rust stable pattern. Update NVM_VERSION here
# to get a newer nvm — the Node version tracks LTS automatically.
NVM_VERSION="0.40.3"

# NVM_DIR is set by the Dockerfile ENV so it's available at build time and
# runtime. Fall back to the default location if somehow unset.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash

# nvm.sh uses `unset` internally on variables that may not be set, which
# trips the `nounset` option from `set -euo pipefail`. Disable it for the
# duration of the source, then restore strict mode.
set +u
# shellcheck source=/dev/null
. "$NVM_DIR/nvm.sh"
set -u

nvm install --lts
nvm alias default lts/*
nvm cache clear

# Create a stable symlink so the Dockerfile PATH entry ($NVM_DIR/current)
# resolves without needing to source nvm.sh at runtime.
# Use parameter expansion rather than xargs to handle any path correctly.
NODE_BIN="$(nvm which default)"
ln -s "${NODE_BIN%/*}" "$NVM_DIR/current"

node --version
npm --version

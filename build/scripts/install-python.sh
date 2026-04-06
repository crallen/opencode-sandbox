#!/usr/bin/env bash
set -euo pipefail

# Runs as opencode (non-root) during Docker build.
# uv is installed separately via COPY --from in the Dockerfile.
# Pin PYTHON_VERSION here to control the cache layer — changing this value only
# invalidates this layer and those below it (unlike Go/Rust/Node which use
# rolling channels).
PYTHON_VERSION="3.13.3"

uv python install "$PYTHON_VERSION" --default

# Clean uv's download/build cache — not needed at runtime.
uv cache clean

python --version
uv pip --version

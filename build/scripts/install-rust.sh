#!/usr/bin/env bash
set -euo pipefail

# Runs as opencode (non-root) during Docker build.
# Installs the latest stable Rust toolchain via rustup. No version is pinned
# here — the stable channel is used instead, mirroring the Node LTS pattern.
# Rust's stability guarantee means this is safe: stable releases never break
# existing code. Update this script only to change the profile or add components.
#
# RUSTUP_HOME and CARGO_HOME are set by the Dockerfile ENV before this script
# runs, so rustup installs into the correct locations automatically.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- \
    -y --no-modify-path --default-toolchain stable --profile default

# Remove download/temp cache — not needed at runtime.
rm -rf "$RUSTUP_HOME/downloads" "$RUSTUP_HOME/tmp"

rustc --version
cargo --version
cargo clippy --version
rustfmt --version

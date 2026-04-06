#!/usr/bin/env bash
set -euo pipefail

# Runs as root during Docker build.
# Pin version here to control the cache layer — changing this value only
# invalidates this layer and those below it.
GO_VERSION="1.26.1"

# Map Debian architecture names to Go's release naming.
# Fail fast with a clear error on unsupported platforms rather than letting
# curl fail with a confusing 404.
case "$(dpkg --print-architecture)" in
    amd64)  GO_ARCH="amd64"  ;;
    arm64)  GO_ARCH="arm64"  ;;
    *)
        echo "error: unsupported architecture '$(dpkg --print-architecture)' for Go install" >&2
        exit 1
        ;;
esac

TARBALL="/tmp/go.tar.gz"

curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o "$TARBALL"

# Verify the tarball against the SHA-256 published by the Go release API.
# jq is available in the image from the apt layer.
EXPECTED_SHA="$(curl -fsSL "https://go.dev/dl/?mode=json" \
    | jq -r ".[] \
        | select(.version == \"go${GO_VERSION}\") \
        | .files[] \
        | select(.os == \"linux\" and .arch == \"${GO_ARCH}\") \
        | .sha256")"

if [ -z "$EXPECTED_SHA" ]; then
    echo "error: could not fetch SHA-256 for go${GO_VERSION} linux/${GO_ARCH}" >&2
    exit 1
fi

echo "${EXPECTED_SHA}  ${TARBALL}" | sha256sum --check --quiet

tar -C /usr/local -xzf "$TARBALL"
rm "$TARBALL"

# Create GOPATH bin directory for `go install` binaries, owned by opencode.
# Use $GOPATH from the Dockerfile ENV rather than a hardcoded path.
mkdir -p "$GOPATH/bin"
chown -R opencode:opencode "$GOPATH"

/usr/local/go/bin/go version

FROM debian:bookworm-slim@sha256:f06537653ac770703bc45b4b113475bd402f451e85223f0f2837acbf89ab020a

ARG UID=1000
ARG GID=1000

# Install dependencies for agentic workflows
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with configurable UID/GID
RUN groupadd -g "${GID}" opencode \
    && useradd -m -u "${UID}" -g opencode -s /bin/bash opencode

# Create directories that will be used for volumes
RUN mkdir -p /home/opencode/.local/share/opencode \
             /home/opencode/.local/state/opencode \
             /home/opencode/.config/opencode \
             /workspace \
             /reference \
    && chown -R opencode:opencode /home/opencode /workspace /reference

# Switch to non-root user for install
USER opencode

# Install OpenCode via official install script
RUN curl -fsSL https://opencode.ai/install | bash

# Ensure opencode is on PATH and configure terminal
ENV PATH="/home/opencode/.local/bin:/home/opencode/.opencode/bin:${PATH}" \
    TERM=xterm-256color \
    COLORTERM=truecolor

# Copy global OpenCode config and AGENTS.md into the image.
# These go into both the config dir (for Docker volume auto-init on first run)
# and a separate defaults dir (used by the entrypoint to sync repo-managed
# files into the persistent config volume on every container start).
COPY --chown=opencode:opencode .opencode/config/opencode.json /home/opencode/.config/opencode/opencode.json
COPY --chown=opencode:opencode .opencode/config/AGENTS.md /home/opencode/.config/opencode/AGENTS.md

RUN mkdir -p /home/opencode/.config/opencode.defaults
COPY --chown=opencode:opencode .opencode/config/opencode.json /home/opencode/.config/opencode.defaults/opencode.json
COPY --chown=opencode:opencode .opencode/config/AGENTS.md /home/opencode/.config/opencode.defaults/AGENTS.md

COPY --chown=opencode:opencode build/entrypoint.sh /home/opencode/entrypoint.sh
RUN chmod +x /home/opencode/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/home/opencode/entrypoint.sh"]

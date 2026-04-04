---
name: docker-best-practices
description: Docker image optimization, multi-stage builds, security hardening, layer caching, and Compose patterns for development and production
---

## Dockerfile Best Practices

### Use Multi-Stage Builds

Separate build dependencies from the runtime image. The final image should contain only what's needed to run the application.

```dockerfile
# Stage 1: Build
FROM node:22-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production
FROM node:22-slim
WORKDIR /app
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
USER node
CMD ["node", "dist/index.js"]
```

### Choose the Right Base Image

| Need | Image | Why |
|------|-------|-----|
| Minimal size | `*-alpine` or `distroless` | Smallest attack surface, fewest CVEs |
| Compatibility | `*-slim` (Debian) | Good balance of size and compatibility |
| Build tools needed | Full image (e.g., `node:22`) | Only for build stages, not production |

Always pin to a specific version tag. Never use `latest` in production.

```dockerfile
# Good
FROM node:22.12-slim

# Bad
FROM node:latest
```

### Optimize Layer Caching

Docker caches layers top-down. Put things that change less frequently earlier.

```dockerfile
# 1. Base image (rarely changes)
FROM node:22-slim

# 2. System dependencies (changes infrequently)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 3. Application dependencies (changes when deps change)
COPY package.json package-lock.json ./
RUN npm ci --production

# 4. Application code (changes most frequently)
COPY . .
```

### Reduce Image Size

- Use `--no-install-recommends` with `apt-get`.
- Clean up package manager caches in the same `RUN` layer: `rm -rf /var/lib/apt/lists/*`.
- Use `.dockerignore` to exclude unnecessary files (node_modules, .git, tests, docs).
- Don't install development dependencies in the production image.
- Combine related `RUN` commands to reduce layers.

### Security Hardening

```dockerfile
# Run as non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

# Don't store secrets in the image
# Use build secrets for private package registries:
RUN --mount=type=secret,id=npm_token \
    NPM_TOKEN=$(cat /run/secrets/npm_token) npm ci

# Set read-only filesystem where possible
# (in docker-compose or runtime)
```

**Security checklist:**
- [ ] Runs as non-root user
- [ ] No secrets baked into the image
- [ ] Base image is pinned and regularly updated
- [ ] Only necessary ports are exposed
- [ ] No unnecessary capabilities (drop all, add specific)
- [ ] `.dockerignore` excludes sensitive files (.env, .git, credentials)

### Health Checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

## Docker Compose Patterns

### Development Environment

```yaml
services:
  app:
    build:
      context: .
      target: development    # Use dev stage of multi-stage build
    volumes:
      - .:/app               # Mount source for hot reload
      - /app/node_modules    # Don't overwrite container's node_modules
    environment:
      - NODE_ENV=development
    ports:
      - "3000:3000"

  db:
    image: postgres:16-alpine
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=devpassword

volumes:
  db-data:
```

### Production Considerations

- Don't mount source code. Copy it into the image.
- Use `restart: unless-stopped` for resilience.
- Set memory and CPU limits.
- Use named volumes for persistent data.
- Don't expose unnecessary ports.

## .dockerignore Template

```
.git
.gitignore
node_modules
npm-debug.log
Dockerfile*
docker-compose*
.dockerignore
.env
.env.*
*.md
LICENSE
.vscode
.idea
coverage
dist
build
test
tests
__tests__
```

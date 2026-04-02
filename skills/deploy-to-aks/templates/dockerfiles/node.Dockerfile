# =============================================================================
# Node.js Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - APP_NAME:    Replace in HEALTHCHECK and comments as needed
#   - PORT:        Change EXPOSE and HEALTHCHECK port if not 3000
#   - ENTRY_POINT: Change the final CMD to your main file (e.g. dist/main.js)
#   - BUILD_CMD:   Adjust "npm run build" if your build script differs
#
# Package manager support:
#   - npm:  This file is configured for npm by default
#   - yarn: Replace "npm ci" with "yarn install --frozen-lockfile"
#           Replace "package-lock.json" with "yarn.lock"
#   - pnpm: Replace "npm ci" with "corepack enable && pnpm install --frozen-lockfile"
#           Replace "package-lock.json" with "pnpm-lock.yaml"
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM node:22-alpine AS build

WORKDIR /app

# Layer caching: copy dependency manifests first so the install layer is
# only rebuilt when dependencies change, not on every source edit.
COPY package.json package-lock.json ./

RUN npm ci

# Copy the rest of the source and build
COPY . .

RUN npm run build

# Remove dev dependencies to slim down the production node_modules
RUN npm ci --omit=dev

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM node:22-alpine

# Security: install dumb-init so Node runs as PID > 1 and signals propagate
# correctly — avoids zombie processes inside the container.
RUN apk add --no-cache dumb-init

WORKDIR /app

# Copy only production artifacts from the build stage
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/package.json ./

# AKS Deployment Safeguards DS004: never run as root.
# The "node" user (uid 1000) is built into the node-alpine image.
USER node

EXPOSE 3000

# HEALTHCHECK gives Kubernetes probes a sensible default and documents the
# health contract for operators.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD ["wget", "--quiet", "--spider", "http://localhost:3000/healthz"]

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]

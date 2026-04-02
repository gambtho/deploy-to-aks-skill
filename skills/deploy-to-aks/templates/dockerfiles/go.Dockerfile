# =============================================================================
# Go Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - APP_NAME:    Replace "app" in the binary name and CMD
#   - PORT:        Change EXPOSE and HEALTHCHECK port if not 8080
#   - MODULE_PATH: Ensure go.mod module path matches your project
#
# Notes:
#   - CGO_ENABLED=0 produces a fully static binary that runs on distroless
#   - The distroless runtime has no shell — use the exec form for CMD
#   - To debug, swap the runtime to gcr.io/distroless/static-debian12:debug
#     which includes busybox
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM golang:1.23-alpine AS build

WORKDIR /src

# Layer caching: download module dependencies before copying source.
# This layer is only rebuilt when go.mod or go.sum changes.
COPY go.mod go.sum ./

RUN go mod download && go mod verify

# Copy source and compile a static binary
COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /bin/app ./cmd/app

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/static-debian12

# Copy the compiled binary from the build stage
COPY --from=build /bin/app /app

# AKS Deployment Safeguards DS004: run as non-root.
# 65534 is the "nobody" user in distroless images.
USER 65534

EXPOSE 8080

# Distroless has no shell and no curl/wget.  Use the binary itself as the
# health probe — the app should exit 0 on GET /healthz.
# In practice Kubernetes probes (httpGet, exec) handle this; the Dockerfile
# HEALTHCHECK is a fallback for local Docker usage.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD ["/app", "healthcheck"]

ENTRYPOINT ["/app"]

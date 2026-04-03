# =============================================================================
# Rust Production Dockerfile
# =============================================================================
# Customize the following before use:
#   - APP_NAME:    Replace "app" with your binary name from Cargo.toml
#   - PORT:        Change EXPOSE port if not 8080
#
# Notes:
#   - The dependency-caching trick creates a dummy main.rs, builds
#     dependencies, then replaces it with real source — this avoids
#     rebuilding all deps on every source change
#   - The final image uses distroless/cc which includes libgcc/libstdc++
#     needed by the default Rust allocator; if you use musl
#     (--target x86_64-unknown-linux-musl) switch to distroless/static
#   - For workspace builds, copy the whole workspace in one shot and adjust
#     the binary path in the final COPY
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
FROM rust:1.83-slim AS build

WORKDIR /app

# Install build dependencies (if any native libs are needed, add them here)
RUN apt-get update \
    && apt-get install -y --no-install-recommends pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Layer caching: build dependencies separately from application code.
# 1. Copy only the manifests and create a dummy main to compile deps.
COPY Cargo.toml Cargo.lock ./

RUN mkdir src \
    && echo 'fn main() { println!("placeholder"); }' > src/main.rs \
    && cargo build --release \
    && rm -rf src target/release/deps/app* target/release/app*
    # ↑ Update "app*" if your Cargo.toml binary name differs

# 2. Copy real source and build the actual binary.
COPY src ./src

RUN cargo build --release

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
FROM gcr.io/distroless/cc-debian12

WORKDIR /app

# Copy the compiled binary from the build stage
COPY --from=build /app/target/release/app /app/app

# AKS Deployment Safeguards DS004: run as non-root.
# 65534 is the "nobody" user in distroless images.
USER 65534

EXPOSE 8080

# Distroless has no shell, curl, or wget. Kubernetes liveness/readiness probes
# (configured in deployment.yaml) handle health checking in AKS.
# For local Docker usage, consider adding a /healthz handler and using a
# statically-compiled health check binary.

ENTRYPOINT ["/app/app"]

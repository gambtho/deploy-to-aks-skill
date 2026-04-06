# Next.js Knowledge Pack

> **Applies to:** Projects detected with `package.json` containing `next` as a dependency

---

## Dockerfile Patterns

### Multi-stage build with standalone output

Next.js standalone output mode is critical for containerized deployments — it reduces the image from ~1GB to ~100MB by bundling only the files needed to run the server:

```dockerfile
# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Runtime stage
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

COPY --from=build /app/public ./public
COPY --from=build --chown=nextjs:nextjs /app/.next/standalone ./
COPY --from=build --chown=nextjs:nextjs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
```

### Key points

- **Standalone output** requires `output: 'standalone'` in `next.config.js` — without this, the build copies all of `node_modules` into the image
- **No `dumb-init` needed** — the standalone `server.js` handles `SIGTERM` signals correctly as PID 1
- **`NEXT_TELEMETRY_DISABLED=1`** prevents Next.js from sending anonymous telemetry from the build and runtime containers
- **Three COPY steps** are required: `public/` for static assets, `.next/standalone` for the server, `.next/static` for client-side JS/CSS bundles
- **`USER nextjs`** satisfies DS004 — create a dedicated non-root user since the official Node Alpine `node` user also works
- **`HOSTNAME="0.0.0.0"`** is required in Next.js 14+ (replaces the older `-H 0.0.0.0` CLI flag) to listen on all interfaces

### Enabling standalone output

In `next.config.js` (or `next.config.mjs` / `next.config.ts`):

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
};

module.exports = nextConfig;
```

### sharp for next/image optimization

If the app uses `next/image`, the standalone build may not include the `sharp` image processing library. Install it explicitly:

```dockerfile
# In the build stage, before npm run build:
RUN npm ci
# Ensure sharp is available for image optimization in production:
RUN npm install sharp
```

Without `sharp`, Next.js falls back to the slower `squoosh` library, which may cause timeout errors under load.

### Package manager variants

| Package Manager | Install Command | Lock File | Standalone COPY |
|----------------|----------------|-----------|-----------------|
| npm | `npm ci` | `package-lock.json` | Same for all |
| yarn | `yarn install --frozen-lockfile` | `yarn.lock` | Same for all |
| pnpm | `pnpm install --frozen-lockfile` | `pnpm-lock.yaml` | Same for all |

Copy the correct lock file in the Dockerfile `COPY` step to match the project's package manager.

---

## Health Endpoints

Next.js does not provide health endpoints out of the box. Add a custom API route — the implementation depends on whether the project uses App Router or Pages Router.

### App Router (Next.js 13.4+)

Create `app/api/health/route.ts`:

```ts
import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json({ status: 'UP' });
}

export const dynamic = 'force-dynamic';
```

The `force-dynamic` export prevents Next.js from statically caching the health response at build time.

### Pages Router

Create `pages/api/health.ts`:

```ts
import type { NextApiRequest, NextApiResponse } from 'next';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  res.status(200).json({ status: 'UP' });
}
```

### Probe configuration in Deployment manifest

```yaml
livenessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /api/health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

**Note:** Next.js standalone server starts in 1–3 seconds, but `initialDelaySeconds: 10` provides a safe margin for cold starts and environment variable resolution. No `startupProbe` is needed unless the app performs heavy server-side initialization.

---

## Database Profiles

Next.js apps commonly use Prisma, Drizzle, or `pg` (node-postgres) for database access. All follow the `DATABASE_URL` connection string pattern:

| Library | Connection Pattern | Config Property |
|---------|-------------------|-----------------|
| Prisma | `datasource db { url = env("DATABASE_URL") }` in `schema.prisma` | `DATABASE_URL` |
| Drizzle | `postgres(process.env.DATABASE_URL!)` or `drizzle(process.env.DATABASE_URL!)` | `DATABASE_URL` |
| `pg` (node-postgres) | `new Pool({ connectionString: process.env.DATABASE_URL })` | `DATABASE_URL` |

### Environment variables for PostgreSQL on AKS

```yaml
env:
  - name: DATABASE_URL
    value: "postgresql://{{IDENTITY_NAME}}@{{PG_SERVER_NAME}}.postgres.database.azure.com:5432/{{DB_NAME}}?sslmode=require"
  - name: PGHOST
    value: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  - name: PGDATABASE
    value: "{{DB_NAME}}"
  - name: PGUSER
    value: "{{IDENTITY_NAME}}"
  - name: PGPORT
    value: "5432"
  - name: PGSSLMODE
    value: "require"
```

For Prisma with Workload Identity (passwordless authentication), use `@prisma/adapter-pg` with `@azure/identity` to obtain Azure AD tokens instead of passwords.

### ConfigMap pattern

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{APP_NAME}}-config
data:
  NODE_ENV: "production"
  NEXT_TELEMETRY_DISABLED: "1"
  PGHOST: "{{PG_SERVER_NAME}}.postgres.database.azure.com"
  PGDATABASE: "{{DB_NAME}}"
  PGPORT: "5432"
  PGSSLMODE: "require"
```

---

## Writable Paths (DS012 Compliance)

When `readOnlyRootFilesystem: true` is set, Next.js needs **two** writable paths:

- **`/tmp`** — general-purpose temporary file storage
- **`/app/.next/cache`** — ISR (Incremental Static Regeneration) page cache and `next/image` optimization cache; without this, ISR and image optimization fail with `EROFS: read-only file system` errors

### Required volume mounts

```yaml
volumes:
  - name: tmp
    emptyDir: {}
  - name: next-cache
    emptyDir: {}
containers:
  - name: app
    volumeMounts:
      - name: tmp
        mountPath: /tmp
      - name: next-cache
        mountPath: /app/.next/cache
```

Both mounts are required. Missing the cache mount is the most common cause of ISR failures on AKS.

---

## Port Configuration

- **Default port:** 3000
- **Env var override:** `PORT=3000`
- **Hostname binding:** `HOSTNAME="0.0.0.0"` (Next.js 14+) or `-H 0.0.0.0` CLI flag (Next.js 13)

The standalone `server.js` reads the `PORT` and `HOSTNAME` environment variables automatically. No code changes are needed to customize the port.

---

## Build Commands

| Scenario | Build Command | Output | Entrypoint |
|----------|---------------|--------|------------|
| Standard build | `npm run build` | `.next/` (full) | `next start` |
| Standalone build (recommended) | `npm run build` with `output: 'standalone'` | `.next/standalone/server.js` | `node server.js` |

The `output: 'standalone'` setting in `next.config.js` changes what `npm run build` produces — no separate command is needed. The standalone `server.js` includes a built-in HTTP server and does not require the `next` CLI at runtime.

**Important:** Always use the standalone build for container deployments. The standard build requires the full `node_modules` directory at runtime, resulting in images 5-10x larger.

---

## Common Issues on AKS

| Issue | Symptom | Fix |
|-------|---------|-----|
| Image too large without standalone | Image > 1GB, slow pulls from ACR | Set `output: 'standalone'` in `next.config.js` — reduces image to ~100MB |
| Static assets 404 | CSS/JS files return 404 after deployment | Ensure `.next/static` is copied to `.next/static` in the runtime stage (not into `standalone/.next/static`) |
| ISR fails with read-only filesystem | `EROFS: read-only file system` when revalidating pages | Mount `emptyDir` volume at `/app/.next/cache` — ISR writes regenerated pages to the cache directory |
| next/image optimization fails | Images return 500 or timeout under load | Install `sharp` explicitly (`npm install sharp`); the standalone build may not include it automatically |
| Env vars undefined (`NEXT_PUBLIC_` prefix) | Client-side code sees `undefined` for environment variables | `NEXT_PUBLIC_` vars are inlined at **build time**, not runtime; set them as build args in the Dockerfile or use runtime config via `publicRuntimeConfig` |
| Telemetry calls from container | Unexpected outbound network requests to `telemetry.nextjs.org` | Set `NEXT_TELEMETRY_DISABLED=1` in both the build stage and runtime stage of the Dockerfile |

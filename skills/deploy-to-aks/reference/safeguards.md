# AKS Deployment Safeguards Reference

AKS Deployment Safeguards enforce best practices on Kubernetes manifests at admission time.
When the cluster has safeguards enabled (Enforcement level: `Warning` or `Enforcement`),
non-compliant resources are either flagged or rejected.

This reference covers every rule the skill validates **before** deployment so you never
hit a surprise rejection at `kubectl apply` time.

---

## DS001 — Resource Limits Required

| Field | Value |
|-------|-------|
| **Checks** | Every container has `resources.requests` AND `resources.limits` for both `cpu` and `memory`. |
| **Severity** | Error |
| **Why it matters** | Without limits the scheduler cannot bin-pack pods and a single container can starve the node. |
| **Auto-fixable** | Yes |

### How to detect in YAML

Look for containers missing any of these four keys:

```yaml
resources:
  requests:
    cpu: ...
    memory: ...
  limits:
    cpu: ...
    memory: ...
```

If `resources` is absent, or any of the four sub-keys is missing, the rule is violated.

### How to fix

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Adjust values to match your workload's actual needs.

---

## DS002 — Liveness Probe Required

| Field | Value |
|-------|-------|
| **Checks** | Every container has a `livenessProbe` defined. |
| **Severity** | Warning |
| **Why it matters** | Without a liveness probe, Kubernetes cannot restart a container that is deadlocked or hung. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The container spec has no `livenessProbe` key.

### How to fix

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 15
  timeoutSeconds: 3
  failureThreshold: 3
```

Choose `httpGet`, `tcpSocket`, or `exec` depending on your app.

---

## DS003 — Readiness Probe Required

| Field | Value |
|-------|-------|
| **Checks** | Every container has a `readinessProbe` defined. |
| **Severity** | Warning |
| **Why it matters** | Without a readiness probe, traffic is sent to pods that aren't ready to serve, causing user-facing errors. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The container spec has no `readinessProbe` key.

### How to fix

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

---

## DS004 — runAsNonRoot Required

| Field | Value |
|-------|-------|
| **Checks** | `securityContext.runAsNonRoot: true` is set at the **pod** level AND at each **container** level. |
| **Severity** | Error |
| **Why it matters** | Running as root inside a container dramatically increases the blast radius if the container is compromised. |
| **Auto-fixable** | Yes |

### How to detect in YAML

Check two locations:

1. `spec.template.spec.securityContext.runAsNonRoot` — must be `true`
2. Each `containers[*].securityContext.runAsNonRoot` — must be `true`

If either is missing or set to `false`, the rule is violated.

### How to fix

Pod-level:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
```

Container-level:

```yaml
securityContext:
  runAsNonRoot: true
```

---

## DS005 — No hostNetwork

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.hostNetwork` is not set to `true`. |
| **Severity** | Error |
| **Why it matters** | Host networking lets a pod see all network traffic on the node, breaking namespace isolation. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  template:
    spec:
      hostNetwork: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
spec:
  template:
    spec:
      hostNetwork: false
```

---

## DS006 — No hostPID

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.hostPID` is not set to `true`. |
| **Severity** | Error |
| **Why it matters** | Sharing the host PID namespace lets containers see and signal host processes, enabling container escapes. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  template:
    spec:
      hostPID: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
spec:
  template:
    spec:
      hostPID: false
```

---

## DS007 — No hostIPC

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.hostIPC` is not set to `true`. |
| **Severity** | Error |
| **Why it matters** | Sharing host IPC namespace allows containers to access shared memory of other host processes. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  template:
    spec:
      hostIPC: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
spec:
  template:
    spec:
      hostIPC: false
```

---

## DS008 — No Privileged Containers

| Field | Value |
|-------|-------|
| **Checks** | No container has `securityContext.privileged: true`. |
| **Severity** | Error |
| **Why it matters** | Privileged containers get full access to every host device and kernel capability — equivalent to root on the node. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
containers:
  - name: app
    securityContext:
      privileged: true   # ← violation
```

### How to fix

Remove the field entirely or set it to `false`:

```yaml
securityContext:
  privileged: false
```

---

## DS009 — No :latest Image Tag

| Field | Value |
|-------|-------|
| **Checks** | Every container image reference includes an explicit tag or digest that is NOT `:latest`. |
| **Severity** | Error |
| **Why it matters** | `:latest` is mutable — the same tag can point to different images over time, making deployments non-reproducible. |
| **Auto-fixable** | No |

### How to detect in YAML

Check each `containers[*].image` value:

- `myregistry.azurecr.io/app:latest` — violation
- `myregistry.azurecr.io/app` (no tag) — violation (defaults to :latest)
- `myregistry.azurecr.io/app:v1.2.3` — compliant
- `myregistry.azurecr.io/app@sha256:abc...` — compliant

### How to fix

```yaml
image: myregistry.azurecr.io/app:v1.2.3
```

Use a semantic version, git SHA, or digest. Never omit the tag.

---

## DS010 — Minimum 2 Replicas for HA

| Field | Value |
|-------|-------|
| **Checks** | `spec.replicas` is at least `2` for Deployments. |
| **Severity** | Warning |
| **Why it matters** | A single replica means any pod disruption (node drain, OOM kill, crash) causes downtime. |
| **Auto-fixable** | Yes |

### How to detect in YAML

```yaml
spec:
  replicas: 1   # ← violation
```

Also violated if `replicas` is omitted (defaults to 1).

### How to fix

```yaml
spec:
  replicas: 2
```

Pair with a `PodDisruptionBudget` for controlled rollouts.

---

## DS011 — allowPrivilegeEscalation Must Be False

| Field | Value |
|-------|-------|
| **Checks** | Every container has `securityContext.allowPrivilegeEscalation: false`. |
| **Severity** | Error |
| **Why it matters** | Privilege escalation lets a process gain more privileges than its parent, which is the basis of most container breakout exploits. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The field is either missing (defaults to `true`) or explicitly set to `true`:

```yaml
securityContext:
  allowPrivilegeEscalation: true   # ← violation
```

### How to fix

```yaml
securityContext:
  allowPrivilegeEscalation: false
```

---

## DS012 — readOnlyRootFilesystem Should Be True

| Field | Value |
|-------|-------|
| **Checks** | Every container has `securityContext.readOnlyRootFilesystem: true`. |
| **Severity** | Warning |
| **Why it matters** | A writable root filesystem lets attackers drop binaries or modify config inside the container at runtime. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The field is missing or set to `false`:

```yaml
securityContext:
  readOnlyRootFilesystem: false   # ← violation
```

### How to fix

```yaml
securityContext:
  readOnlyRootFilesystem: true
```

If the app needs to write to specific paths, mount `emptyDir` volumes at those paths
rather than making the entire root filesystem writable.

---

## DS013 — automountServiceAccountToken Should Be False

| Field | Value |
|-------|-------|
| **Checks** | `spec.template.spec.automountServiceAccountToken` is `false`. |
| **Severity** | Warning |
| **Why it matters** | Auto-mounted SA tokens let any compromised container call the Kubernetes API; most workloads don't need this. |
| **Auto-fixable** | Yes |

### How to detect in YAML

The field is missing (defaults to `true`) or explicitly set to `true`:

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: true   # ← violation
```

### How to fix

```yaml
spec:
  template:
    spec:
      automountServiceAccountToken: false
```

If your app genuinely needs to call the K8s API, set this to `true` on only that
specific ServiceAccount and use RBAC to scope permissions tightly.

---

## Quick Reference Table

| Rule | What | Severity | Auto-Fix |
|------|------|----------|----------|
| DS001 | Resource limits (cpu + memory requests & limits) | Error | Yes |
| DS002 | Liveness probe | Warning | Yes |
| DS003 | Readiness probe | Warning | Yes |
| DS004 | runAsNonRoot (pod + container) | Error | Yes |
| DS005 | No hostNetwork | Error | Yes |
| DS006 | No hostPID | Error | Yes |
| DS007 | No hostIPC | Error | Yes |
| DS008 | No privileged containers | Error | Yes |
| DS009 | No :latest image tag | Error | No |
| DS010 | Minimum 2 replicas | Warning | Yes |
| DS011 | allowPrivilegeEscalation: false | Error | Yes |
| DS012 | readOnlyRootFilesystem: true | Warning | Yes |
| DS013 | automountServiceAccountToken: false | Warning | Yes |

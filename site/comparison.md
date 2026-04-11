# Skill vs. Plain Copilot: Side-by-Side Comparison

How does **deploy-to-aks** compare to asking GitHub Copilot to deploy an app without the skill? We ran the same prompt against the same FastAPI project and compared everything that was generated.

**Test project:** A minimal FastAPI application with two endpoints (`/` and `/health`).

**Prompt:** Deploy this application to AKS.

---

## At a Glance

| Category | Plain Copilot | With deploy-to-aks Skill |
|----------|:---:|:---:|
| **Files generated** | 3 | 10 |
| **Multi-stage Dockerfile** | No | Yes |
| **Non-root container user** | No (runs as root) | Yes (UID 1000) |
| **.dockerignore** | Missing | Comprehensive |
| **Namespace isolation** | No | Dedicated namespace |
| **Service Account** | No | Yes (ServiceAccount provided; Workload Identity requires additional binding/annotation) |
| **Security context (pod)** | Partial (seccomp only) | Full (7 hardening controls) |
| **Read-only root filesystem** | No | Yes |
| **Capabilities dropped** | No | All dropped |
| **Privilege escalation blocked** | No | Yes |
| **Rolling update strategy** | Default | Zero-downtime (maxUnavailable: 0) |
| **HorizontalPodAutoscaler** | No | Yes (2-10 replicas) |
| **PodDisruptionBudget** | No | Yes (minAvailable: 1) |
| **Service type** | LoadBalancer (public IP) | ClusterIP + Ingress |
| **Health probes** | Yes | Yes |
| **Resource requests/limits** | Yes | Yes |
| **AKS Safeguards compliance** | 6 of 13 | 13 of 13 |

---

## Dockerfile

::: code-group

```dockerfile [Plain Copilot]
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```dockerfile [deploy-to-aks Skill]
# Multi-stage build for FastAPI
FROM python:3.12-slim AS build

WORKDIR /app

RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

# Runtime stage
FROM python:3.12-slim

WORKDIR /app

RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --shell /bin/sh --create-home appuser

COPY --from=build --chown=appuser:appuser /app /app

ENV PATH="/app/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

:::

### What the skill adds

- **Multi-stage build** -- build tooling stays out of the runtime image, reducing size and attack surface
- **Non-root user** -- container runs as `appuser` (UID 1000), not root
- **Virtual environment isolation** -- dependencies live in `/app/venv`, cleanly separated from system Python
- **Python optimizations** -- `PYTHONDONTWRITEBYTECODE=1` and `PYTHONUNBUFFERED=1` for cleaner containers and immediate log output
- **Proper file ownership** -- `--chown=appuser:appuser` ensures the non-root user owns all files

Plain Copilot's Dockerfile runs as **root** -- the single most common container security misconfiguration.

---

## .dockerignore

::: code-group

```text [Plain Copilot]
(not generated)
```

```text [deploy-to-aks Skill]
.git
.gitignore
.opencode
.claude
__pycache__
*.pyc
*.pyo
.env
.env.*
.venv
venv
k8s
*.md
Dockerfile
.dockerignore
```

:::

Without a `.dockerignore`, `COPY . .` sends the entire directory to the Docker daemon -- including `.git/` history, `.env` secrets, and Kubernetes manifests. The skill prevents accidental secret leakage and reduces build context size.

---

## Kubernetes Security Context

This is where the gap is most significant. Here is the security configuration on each Deployment:

::: code-group

```yaml [Plain Copilot]
# Pod-level: (none)
# Container-level:
securityContext:
  seccompProfile:
    type: RuntimeDefault
```

```yaml [deploy-to-aks Skill]
# Pod-level:
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

# Container-level:
securityContext:
  runAsNonRoot: true
  privileged: false
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

:::

### Security hardening breakdown

| Control | Plain Copilot | Skill | Why it matters |
|---------|:---:|:---:|---|
| `runAsNonRoot` | Missing | Yes | Prevents container from running as root even if Dockerfile changes |
| `runAsUser/Group` | Missing | 1000 | Explicit non-root UID matching the Dockerfile user |
| `seccompProfile` | RuntimeDefault | RuntimeDefault | Both restrict syscalls -- good |
| `privileged` | Not set | `false` | Explicitly blocks privileged mode |
| `allowPrivilegeEscalation` | Not set | `false` | Prevents child processes from gaining elevated privileges |
| `readOnlyRootFilesystem` | Not set | `true` | Prevents runtime filesystem modifications (with `/tmp` emptyDir for temp files) |
| `capabilities: drop ALL` | Not set | Yes | Removes all Linux capabilities the container doesn't need |
| `automountServiceAccountToken` | Not set | `false` | Prevents token mounting unless explicitly needed |

---

## Kubernetes Manifests

### What plain Copilot generated (2 files)

```text
k8s/
  deployment.yaml
  service.yaml
```

### What the skill generated (7 files)

```text
k8s/
  namespace.yaml          # Workload isolation
  serviceaccount.yaml     # Azure Workload Identity
  deployment.yaml         # Full security context
  service.yaml            # ClusterIP (internal)
  ingress.yaml            # External access via Azure Web App Routing
  hpa.yaml                # Autoscaling (2-10 replicas)
  pdb.yaml                # Disruption budget
```

---

## Service Exposure

::: code-group

```yaml [Plain Copilot]
apiVersion: v1
kind: Service
metadata:
  name: fastapi-quicktest
spec:
  type: LoadBalancer           # Direct public IP
  selector:
    app: fastapi-quicktest
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8000
```

```yaml [deploy-to-aks Skill]
# Service (internal only)
apiVersion: v1
kind: Service
metadata:
  name: fastapi-quicktest
  namespace: fastapi-quicktest
spec:
  type: ClusterIP              # Internal only
  selector:
    app: fastapi-quicktest
  ports:
    - name: http
      port: 80
      targetPort: 8000
      protocol: TCP
---
# Ingress (controlled external access)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fastapi-quicktest
  namespace: fastapi-quicktest
spec:
  ingressClassName: webapprouting.kubernetes.azure.com
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: fastapi-quicktest
                port:
                  number: 80
```

:::

Plain Copilot uses `type: LoadBalancer`, which provisions a public Azure IP address directly attached to the service -- no TLS termination, no routing rules, no shared infrastructure. The skill uses `ClusterIP` with an Ingress controller, which is the production-standard pattern for AKS.

---

## Availability and Scaling

| Feature | Plain Copilot | Skill |
|---------|:---:|:---:|
| **Replicas** | 2 (static) | 2 baseline, autoscales to 10 |
| **HPA** | None | CPU-based at 70%, conservative scale-down |
| **PDB** | None | minAvailable: 1 |
| **Rolling update strategy** | Default | maxSurge: 1, maxUnavailable: 0 |
| **Namespace** | Default namespace | Dedicated namespace |

Without an HPA, the plain Copilot deployment can't respond to load changes. Without a PDB, node drains during AKS upgrades could take down all replicas simultaneously.

The skill configures zero-downtime rolling updates (`maxUnavailable: 0`) and conservative autoscaling with a 5-minute scale-down stabilization window to prevent flapping.

---

## AKS Deployment Safeguards

AKS [Deployment Safeguards](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards) enforce best practices at admission time. On AKS Automatic, they run in **Enforcement** mode -- non-compliant workloads are rejected.

| Safeguard | ID | Plain Copilot | Skill |
|-----------|:---:|:---:|:---:|
| Resource requests | DS002 | Pass | Pass |
| Resource limits | DS003 | Pass | Pass |
| Liveness probe | DS004 | Pass | Pass |
| Readiness probe | DS005 | Pass | Pass |
| Non-root user | DS006 | **Fail** | Pass |
| Read-only root FS | DS007 | **Fail** | Pass |
| No privilege escalation | DS008 | **Fail** | Pass |
| Drop all capabilities | DS009 | **Fail** | Pass |
| Seccomp profile | DS010 | Pass | Pass |
| Container image from ACR | DS001 | Pass | Pass |
| Pod disruption budget | DS011 | **Fail** | Pass |
| HPA configured | DS012 | **Fail** | Pass |
| Service account token | DS013 | **Fail** | Pass |

**Plain Copilot: 6 of 13 safeguards pass.** On AKS Automatic, this deployment would be **rejected** by the admission controller.

**Skill: 13 of 13 safeguards pass.** The deployment is fully compliant and would be admitted on AKS clusters using AKS Automatic enforcement.

---

## The Bottom Line

Plain Copilot produces a working starting point -- it gets the basic structure right (probes, resources, correct ports). But it misses the production hardening that AKS expects:

- **Security:** Root containers, no privilege escalation controls, writable filesystem, no capability restrictions
- **Availability:** No autoscaling, no disruption budget, default rolling update strategy
- **Architecture:** Direct LoadBalancer exposure instead of Ingress, no namespace isolation, no workload identity
- **Build:** Single-stage Dockerfile, no `.dockerignore`, secrets can leak into images

The deploy-to-aks skill generates **production-grade artifacts** that pass all 13 AKS Deployment Safeguards out of the box. It's the difference between "it runs" and "it's ready for production."

---

<div class="feature-cards">
<div class="feature-card">

### Try it yourself

Install the skill and deploy your own application:

```bash
curl -fsSL https://raw.githubusercontent.com/gambtho/deploy-to-aks-skill/main/install.sh | bash
```

</div>
<div class="feature-card">

### See full examples

View complete generated artifacts for different frameworks:

- [Spring Boot + PostgreSQL](/examples/spring-boot)
- [FastAPI + Redis](/examples/fastapi)

</div>
</div>

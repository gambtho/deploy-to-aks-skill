# Phase 4 — Scaffold

## Goal

Generate production-ready Kubernetes manifests and Bicep infrastructure modules for the
architecture approved in Phase 2 (Architect). Every generated manifest must pass all 13 AKS
Deployment Safeguard rules. Every Bicep module must compose cleanly through a single
`main.bicep` entry point.

---

## Step 1 — Check for Existing Manifests

Before generating anything, scan the workspace for files that already exist.

**Search patterns:**
- `k8s/**/*.yaml` and `k8s/**/*.yml`
- `manifests/**/*.yaml` and `manifests/**/*.yml`
- `*.bicep` and `infra/**/*.bicep`
- `deploy/**/*`

**If existing files are found:**
1. List every discovered file with a one-line description of what it contains.
2. Ask the user: *"I found existing manifests. Should I (a) extend them, (b) replace
   them, or (c) generate new files alongside them?"*
3. Wait for confirmation before proceeding.

**If no files are found:**
- Continue to Step 2.

---

## Step 2 — Generate Kubernetes Manifests

Generate manifests **one file at a time** in the `k8s/` directory. After writing each
file, briefly explain what was generated and why.

### Generation order

1. `k8s/namespace.yaml` — if the target namespace is not `default`
2. `k8s/serviceaccount.yaml` — with Workload Identity annotation
   (reference: `templates/k8s/serviceaccount.yaml`)
3. `k8s/deployment.yaml` — full Deployment
   (reference: `templates/k8s/deployment.yaml`)
4. `k8s/service.yaml` — ClusterIP Service
   (reference: `templates/k8s/service.yaml`)
5. `k8s/gateway.yaml` — Gateway resource (AKS Automatic clusters)
   OR `k8s/ingress.yaml` — Ingress resource (AKS Standard clusters)
   (reference: `templates/k8s/gateway.yaml`, `templates/k8s/httproute.yaml`,
   or `templates/k8s/ingress.yaml`)
6. `k8s/httproute.yaml` — HTTPRoute (only if Gateway was generated)
7. `k8s/hpa.yaml` — HorizontalPodAutoscaler
   (reference: `templates/k8s/hpa.yaml`)
8. `k8s/pdb.yaml` — PodDisruptionBudget
   (reference: `templates/k8s/pdb.yaml`)

### Template usage

For each manifest:
1. Read the corresponding template from `templates/k8s/`.
2. Replace all `# REPLACE:` placeholders with actual values from the approved architecture.
3. Write the final manifest to `k8s/`.

---

## Step 3 — Validate Against Deployment Safeguards

After generating **all** Kubernetes manifests, validate every file against all 13
Deployment Safeguard rules.

### Procedure

1. Read `reference/safeguards.md` to load all rules.
2. For each manifest file in `k8s/`:
   a. Check every applicable rule (DS001–DS013).
   b. Record any violations found.
3. For each violation:
   a. If auto-fixable (see safeguards reference): fix it in-place and note the fix.
   b. If not auto-fixable (DS009): flag it for the user with an explanation.
4. Present a summary table:

```
| File                  | Rule  | Status | Action Taken         |
|-----------------------|-------|--------|----------------------|
| k8s/deployment.yaml   | DS001 | PASS   | —                    |
| k8s/deployment.yaml   | DS009 | FLAG   | User must set image tag |
| ...                   | ...   | ...    | ...                  |
```

5. If any non-auto-fixable violations remain, ask the user to resolve them before
   continuing to Step 4.

### Rule applicability

Not every rule applies to every resource kind:

| Rule | Applies to |
|------|-----------|
| DS001–DS004, DS008, DS009, DS011, DS012 | Deployments, StatefulSets, DaemonSets, Jobs |
| DS005–DS007 | Deployments, StatefulSets, DaemonSets |
| DS010 | Deployments |
| DS013 | Deployments, StatefulSets, DaemonSets |

Skip rules that don't apply to the resource kind being checked.

---

## Step 4 — Generate Bicep Modules

Generate Bicep infrastructure modules **one file at a time** in the `infra/` directory.

### Output directory layout

The skill's Bicep templates are flat files in `templates/bicep/`. When generating the target project's infrastructure, reorganize them into a nested structure:

```
infra/
├── main.bicep              ← orchestrator (from templates/bicep/main.bicep)
├── main.bicepparam         ← parameter file with environment-specific values
└── modules/
    ├── aks.bicep           ← from templates/bicep/aks.bicep
    ├── acr.bicep           ← from templates/bicep/acr.bicep
    ├── identity.bicep      ← from templates/bicep/identity.bicep
    └── [backing-service].bicep  ← only modules for services in the architecture contract
```

`main.bicep` and `main.bicepparam` go in `infra/`. All other modules go in `infra/modules/`. The `main.bicep` references modules via relative paths (e.g., `'modules/aks.bicep'`).

### Generation order

1. `infra/main.bicep` — orchestrator that composes all modules
2. `infra/main.bicepparam` — parameter file with environment-specific values
3. `infra/modules/aks.bicep` — AKS cluster (reference: `templates/bicep/aks.bicep`)
4. `infra/modules/acr.bicep` — Azure Container Registry
   (reference: `templates/bicep/acr.bicep`)
5. `infra/modules/keyvault.bicep` — Key Vault (if architecture includes secrets)
   (reference: `templates/bicep/keyvault.bicep`)
6. `infra/modules/postgresql.bicep` — PostgreSQL Flexible Server (if architecture
   includes a database) (reference: `templates/bicep/postgresql.bicep`)
7. `infra/modules/identity.bicep` — Managed Identity + Federated Credential
   (reference: `templates/bicep/identity.bicep`)
8. Additional modules as required by the approved architecture.

### Module selection rule

**Only generate Bicep modules for services listed in the approved architecture contract from Phase 2.** If the architecture contract does not include a database, do not generate `postgres.bicep`. If it does not include secrets management, do not generate `keyvault.bicep`. If it does not include caching, do not generate `redis.bicep`.

When customizing `main.bicep` from the template, **remove conditional module blocks** for services that are not in the architecture contract. Do not leave dead `module` declarations with `if (false)` or commented-out blocks — remove them entirely so the Bicep is clean and readable.

### Template usage

Same process as Kubernetes manifests:
1. Read the corresponding template from `templates/bicep/`.
2. Replace placeholders with actual values.
3. Wire the module into `main.bicep` with correct parameter passing.
4. Write the final module to `infra/modules/`.

### Composition rule

`main.bicep` must be the **single entry point**. Every module is invoked from
`main.bicep` using `module` declarations with explicit parameter passing. No module
should reference another module directly — all cross-module dependencies flow through
`main.bicep` outputs/parameters.

---

## Step 5 — Update Architecture Diagram

Update the architecture diagram (from Phase 2) with actual resource
names now that manifests have been generated.

### What to update

- Replace placeholder names with actual resource names (e.g., `<app-name>` → `order-api`)
- Add Kubernetes resource types next to each component (e.g., `Deployment`, `Service`)
- Add Azure resource names (e.g., `rg-myapp-prod`, `aks-myapp-prod`)
- Annotate networking paths with actual port numbers and route paths

### Format

Re-render the mermaid architecture diagram (from `templates/mermaid/architecture-diagram.md`) with actual resource names so the developer
can see the updated topology inline.

---

## Output Structure

After this phase completes, the workspace should contain:

```
k8s/
├── namespace.yaml          (if non-default namespace)
├── serviceaccount.yaml
├── deployment.yaml
├── service.yaml
├── gateway.yaml            (AKS Automatic)
│   └── httproute.yaml
│   OR
├── ingress.yaml            (AKS Standard)
├── hpa.yaml
└── pdb.yaml

infra/
├── main.bicep
├── main.bicepparam
└── modules/
    ├── aks.bicep
    ├── acr.bicep
    ├── identity.bicep
    ├── keyvault.bicep       (if needed)
    └── postgresql.bicep     (if needed)
```

---

## Completion Criteria

This phase is complete when:
- [ ] All Kubernetes manifests are generated and pass all 13 Deployment Safeguard rules
- [ ] All Bicep modules are generated and compose through `main.bicep`
- [ ] The architecture diagram is updated with actual resource names
- [ ] The user has confirmed the scaffold looks correct

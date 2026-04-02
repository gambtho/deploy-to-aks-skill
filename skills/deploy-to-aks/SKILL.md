# Deploy to AKS — OpenCode Skill

> **Status:** Skeleton — implementation pending. See the [design spec](../docs/specs/2026-04-02-deploy-to-aks-skill-design.md) for the full plan.

An OpenCode skill that guides developers through deploying applications to Azure Kubernetes Service (AKS) without requiring Kubernetes expertise.

## Checklist

The skill follows a 6-phase deployment journey. Each phase loads its own instruction file from `phases/`.

1. **Read phase file** for the current phase
2. **Execute phase** following the instructions
3. **Use visual companion** at Phases 2, 4, and 6
4. **Confirm with developer** before advancing to the next phase
5. **Track progress** via todo items

## Phases

| Phase | File | Visual? | Description |
|-------|------|---------|-------------|
| 1 | `phases/01-discover.md` | No | Scan project, detect stack, ask questions |
| 2 | `phases/02-architect.md` | Yes | Plan infrastructure, show diagram + cost |
| 3 | `phases/03-containerize.md` | No | Generate/validate Dockerfile |
| 4 | `phases/04-scaffold.md` | Yes | Generate K8s manifests + Bicep, validate safeguards |
| 5 | `phases/05-pipeline.md` | No | Generate GitHub Actions workflow |
| 6 | `phases/06-deploy.md` | Yes | Execute deployment, show summary dashboard |

## Reference Documents

Load these as needed during the relevant phases:

- `reference/aks-automatic.md` — AKS Automatic specifics
- `reference/aks-standard.md` — AKS Standard differences
- `reference/safeguards.md` — 13 Deployment Safeguard rules
- `reference/workload-identity.md` — Workload Identity patterns
- `reference/cost-reference.md` — Azure pricing data

## Execution Model

- **Generate artifacts automatically** — Dockerfiles, manifests, Bicep, workflows
- **Execute CLI commands only with confirmation** — `az`, `docker`, `kubectl`, `gh`
- Each destructive command requires explicit developer opt-in

## Adaptive Behavior

- **Detect before create** — check for existing Dockerfiles, manifests, Bicep, CI/CD
- **Validate before replace** — improve what exists rather than overwriting
- **Ask only what can't be auto-detected** — minimize questions, maximize intelligence

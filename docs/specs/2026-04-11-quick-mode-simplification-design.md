# Quick Mode Simplification Design

**Date:** 2026-04-11
**Status:** Approved
**Supersedes:** 2026-04-10-script-driven-quick-deploy-design.md (reverted)

## Problem

AI agents (particularly Copilot CLI) reliably execute functional instructions but consistently ignore procedural/presentation instructions. Two previous approaches failed:

1. **Aggressive markdown** — increasingly explicit DO/DON'T lists, CRITICAL markers, bold formatting for output suppression, progress indicators, narration suppression. Agents ignored all of it.
2. **Script-driven deploy** — moved execution into a bash script to control output. Phase 1 scanning was still chatty; agent abandoned the script on first error and went rogue with individual commands. Reverted.

The core quick mode files (`quick-01-scan-and-plan.md` at 311 lines, `quick-02-execute.md` at 556 lines) are ~60% presentation choreography that agents ignore, resulting in:
- Permission prompt explosion (21+ commands, 11+ prompts vs target of 4)
- Verbose output (dumps full files despite suppression instructions)
- Narration ("Now I'll..." despite DO NOT instructions)
- Missing progress indicators (ignores ◻/▸/✓ system)

## Decision

Stop fighting the agent's presentation layer. Restructure quick mode as a knowledge library, not a choreographed flow.

**Key insight from value analysis:** The skill's real product is AKS-specific domain knowledge (safeguards, routing, workload identity, framework-specific writable paths) and production-grade templates. An unguided agent produces 3 files that would fail AKS Deployment Safeguards. The skill produces a complete, secure, production-grade deployment. That gap exists regardless of how the agent formats its output.

## Design

### Architecture Change

Replace the 2-phase quick mode (scan-and-plan + execute) with a single phase file (`phases/quick-deploy.md`, ~150-200 lines) containing only functional instructions and domain knowledge. Strip all presentation choreography.

### Single Phase Content

#### Section 1: Detection
- Framework detection table (9 signal files → framework mapping)
- Port detection priority chain (Dockerfile EXPOSE → .env → source → defaults)
- Health endpoint grep (9 patterns: `/health`, `/healthz`, `/ready`, `/readiness`, `/liveness`, `/startup`, `/ping`, `/api/health`, `/api/healthz`)
- Azure infrastructure auto-detection:
  - `kubectl config current-context` — current cluster
  - `az aks show` — parse `nodeProvisioningProfile.mode` for Automatic vs Standard
  - `az acr list` — available registries
  - OIDC issuer extraction for workload identity
- Web App Routing addon check (Standard clusters only)
- RBAC permission pre-check (`kubectl auth can-i create namespaces`)
- Load matching knowledge pack from `knowledge-packs/frameworks/` if available
- Maximum one disambiguation question (only if genuinely ambiguous: multiple Dockerfiles, multiple ACRs, multiple identities)

#### Section 2: File Generation
Files to generate based on detection results:
- Dockerfile (from `templates/dockerfiles/`, matched to framework) + `.dockerignore`
- Namespace manifest
- Deployment manifest (from `templates/k8s/deployment.yaml`)
- Service manifest
- Gateway + HTTPRoute (AKS Automatic) OR Ingress (AKS Standard) — from `templates/k8s/`
- HPA + PDB
- ServiceAccount (if workload identity detected)

Reference templates by path. No inline YAML in the phase file. Instruct agent to write all files in a single response turn (batch file writes).

#### Section 3: Safeguards Validation
- Before deploying, validate generated manifests against DS001-DS013
- Reference `reference/safeguards.md` for the checklist
- Apply framework-specific writable path requirements from knowledge pack (e.g., Spring Boot needs `/tmp`, Next.js needs `/app/.next/cache`)

#### Section 4: Deploy
Functional sequence:
1. Create namespace, verify it exists
2. Apply remaining manifests (service, HPA, PDB, gateway/ingress, service account)
3. Build and push container image via `az acr build` (tag with `git rev-parse --short HEAD`)
4. Update deployment image with `kubectl set image`
5. Wait for rollout with `kubectl rollout status`

If a step fails, show the error and stop. No retry loops. Happy path focus.

#### Section 5: Verify
- Wait for external IP (up to 3 minutes)
- curl the health endpoint
- Show the URL to the user

### What's Removed
- Progress indicators (◻ ▸ ✓ ✗)
- Permission glob pre-warming strategy
- Celebration banners and boxed output
- Output suppression instructions
- Narration suppression instructions
- Structured approval gates (agent's native tool-approval is sufficient)
- Error recovery matrices with pattern matching
- Step retry logic
- All presentation/formatting instructions

### What's Kept
- All detection logic (AKS-specific domain knowledge)
- Template references (the real value)
- Safeguards validation (DS001-DS013)
- Knowledge pack loading
- "Max one disambiguation question" principle
- "Batch file writes in single turn" instruction
- Framework-specific writable path requirements

## File Changes

### Modified
| File | Change |
|------|--------|
| `SKILL.md` | Update quick mode phase table from 2 phases to 1. Update "Also load" column. Keep quick mode routing logic. |

### Deleted
| File | Reason |
|------|--------|
| `phases/quick-01-scan-and-plan.md` | Content merged into `quick-deploy.md`. Also fixes stray merge conflict marker at line 91. |
| `phases/quick-02-execute.md` | Content merged into `quick-deploy.md`. |

### Created
| File | Description |
|------|-------------|
| `phases/quick-deploy.md` | Single combined quick mode phase (~150-200 lines). |

### Not Changed
- All templates (`bicep/`, `dockerfiles/`, `github-actions/`, `k8s/`, `mermaid/`)
- All reference files (`safeguards.md`, `workload-identity.md`, `cost.md`, `aks-automatic.md`, `aks-standard.md`)
- All 9 knowledge packs
- All 6 full-mode phase files
- `scripts/setup-aks-prerequisites.sh`
- Install scripts

## Test Impact

- Structural tests reference quick phase files by name — tests need updating for the renamed/merged file
- Tests checking phase file count or cross-references will break and need fixes
- No template tests should be affected
- Demo documentation (`DEMO_SCRIPT.md`, `DEMO_IMPROVEMENTS.md`) references 2-phase quick mode — can be updated as follow-up, not blocking

## Success Criteria

1. Quick mode works end-to-end: agent detects framework, generates files, validates safeguards, deploys successfully
2. Generated artifacts are identical quality to current quick mode (same templates, same safeguards)
3. Phase file is under 200 lines
4. All structural tests pass (after test updates)
5. No presentation/formatting instructions remain in the quick phase file

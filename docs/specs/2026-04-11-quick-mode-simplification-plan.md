# Quick Mode Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 2-phase quick deploy mode (~870 lines of choreography-heavy instructions) with a single, streamlined phase file (~150-200 lines) containing only functional instructions and domain knowledge.

**Architecture:** Delete `quick-01-scan-and-plan.md` and `quick-02-execute.md`, create `quick-deploy.md` with 5 sections (Detection, File Generation, Safeguards Validation, Deploy, Verify). Update `SKILL.md` phase table. Update all structural tests.

**Tech Stack:** Markdown (skill files), Python/pytest (structural tests)

---

### Task 1: Create `phases/quick-deploy.md`

**Files:**
- Create: `skills/deploy-to-aks/phases/quick-deploy.md`

This is the core deliverable. Extract all functional/domain content from the two existing quick phase files, strip all presentation choreography, and combine into a single file under 200 lines.

- [ ] **Step 1: Write the new phase file**

Create `skills/deploy-to-aks/phases/quick-deploy.md` with the following content. This merges the functional content from `quick-01-scan-and-plan.md` (detection, Azure infra, knowledge packs, disambiguation) and `quick-02-execute.md` (file generation, safeguards, deploy, verify) while stripping all presentation instructions.

The file must:
- Start with `# Quick Deploy` (no "Phase N:" numbering)
- Have a `## Goal` section
- Reference all 6 Dockerfile templates by path (`templates/dockerfiles/*.Dockerfile`)
- Reference all 10 K8s templates by path (`templates/k8s/*.yaml`)
- Reference `reference/safeguards.md` and `reference/workload-identity.md`
- Reference `knowledge-packs/frameworks/` with all 9 pack names
- NOT reference `templates/bicep/` or `templates/github-actions/`
- NOT contain progress indicators (`◻`, `▸`, `✓`, `✗`), celebration banners, permission glob strategies, approval gates, error recovery matrices, output suppression instructions, or narration suppression instructions
- Keep: framework detection table, port detection, health endpoint grep, Azure infra auto-detection (AKS flavor, ACR, OIDC, Web App Routing addon, RBAC pre-check), knowledge pack loading, max 1 disambiguation question, batch file writes instruction, safeguards validation (DS001-DS013), deploy sequence, verify sequence

```markdown
# Quick Deploy

Deploy an application to an existing AKS cluster with production-grade artifacts.

## Goal

Detect the application framework and Azure infrastructure, generate production-ready deployment artifacts, validate against AKS Deployment Safeguards, deploy, and verify — with minimal questions.

---

## Section 1: Detection

Scan the project and Azure environment. Ask at most one clarifying question (only if genuinely ambiguous: multiple Dockerfiles, multiple ACRs, multiple identities).

### Framework Detection

Scan for signal files at the project root (and one level deep for monorepos):

| Signal File | Framework | Sub-framework Detection |
|---|---|---|
| `package.json` | Node.js | `express`, `fastify`, `@nestjs/core`, `next`, `@remix-run/node`, `hono`, `koa` |
| `requirements.txt` / `pyproject.toml` / `Pipfile` | Python | `fastapi`, `django`, `flask`, `starlette` |
| `pom.xml` / `build.gradle` / `build.gradle.kts` | Java | `spring-boot-starter-web`, `org.springframework.boot`, `quarkus-resteasy` |
| `go.mod` | Go | `gin-gonic/gin`, `labstack/echo`, `gofiber/fiber` |
| `*.csproj` | .NET | `Microsoft.AspNetCore.*` |
| `Cargo.toml` | Rust | `actix-web`, `axum` |

### Port Detection

Check in priority order (first match wins):

1. `Dockerfile` → `EXPOSE <port>`
2. `.env` / `.env.example` → `PORT=<number>`
3. Source code → `app.listen(<number>)`, `server.port=<number>`
4. Framework defaults → Express: 3000, FastAPI: 8000, Spring Boot: 8080, ASP.NET: 8080, Gin: 8080

### Health Endpoint Detection

Grep source tree for route registrations matching: `/health`, `/healthz`, `/ready`, `/readiness`, `/liveness`, `/startup`, `/ping`, `/api/health`, `/api/healthz`

If none found, use `/health` as default in probes.

### Existing Artifact Detection

Check for existing `Dockerfile` and `k8s/` (or `manifests/`, `deploy/`) directories.

### Azure Infrastructure Detection

```bash
kubectl config current-context
az aks show -g <rg> -n <cluster> -o json
```

Extract from cluster details:
- **AKS flavor**: `nodeProvisioningProfile.mode` — `"Auto"` = AKS Automatic, otherwise = AKS Standard
- **OIDC issuer**: `oidcIssuerProfile.issuerUrl`
- **Azure RBAC**: `aadProfile.enableAzureRBAC`

```bash
az acr list -g <rg> -o json        # ACR name and login server
az identity list -g <rg> -o json   # Managed identity name and client ID
```

**AKS Standard only** — verify Web App Routing addon:

```bash
az aks show -g <rg> -n <cluster> --query 'ingressProfile.webAppRouting.enabled' -o tsv
```

If not `true`, stop with error and provide the enable command: `az aks approuting enable -g <rg> -n <cluster>`

**RBAC check** — if Azure RBAC is enabled:

```bash
kubectl auth can-i create namespaces
```

If `no`, stop with error. Offer alternatives: provision a cluster without Azure RBAC, have admin create the namespace, or deploy to an existing namespace.

### Knowledge Pack

After framework detection, load the matching pack from `knowledge-packs/frameworks/` if available:

`spring-boot`, `express`, `nextjs`, `fastapi`, `django`, `nestjs`, `aspnet-core`, `go`, `flask`

Knowledge packs influence Dockerfile optimization, probe configuration, and writable path requirements.

---

## Section 2: File Generation

Write all files in a single response turn (batch file writes).

### Dockerfile

**If existing Dockerfile:** Validate against best practices (multi-stage build, non-root USER, pinned base tags, layer caching, .dockerignore). Apply targeted fixes for failures.

**If no Dockerfile:** Generate from the appropriate template:

| Language | Template |
|----------|----------|
| Node.js | `templates/dockerfiles/node.Dockerfile` |
| Python | `templates/dockerfiles/python.Dockerfile` |
| Java | `templates/dockerfiles/java.Dockerfile` |
| Go | `templates/dockerfiles/go.Dockerfile` |
| .NET | `templates/dockerfiles/dotnet.Dockerfile` |
| Rust | `templates/dockerfiles/rust.Dockerfile` |

Generate `.dockerignore` if missing.

### Kubernetes Manifests

Generate from `templates/k8s/` templates. Replace `<angle-bracket>` placeholders with detected values.

| Manifest | Template | Notes |
|----------|----------|-------|
| `k8s/namespace.yaml` | `templates/k8s/namespace.yaml` | |
| `k8s/serviceaccount.yaml` | `templates/k8s/serviceaccount.yaml` | Workload Identity annotation |
| `k8s/deployment.yaml` | `templates/k8s/deployment.yaml` | Image placeholder resolved at deploy time |
| `k8s/service.yaml` | `templates/k8s/service.yaml` | |
| `k8s/gateway.yaml` | `templates/k8s/gateway.yaml` | AKS Automatic only |
| `k8s/httproute.yaml` | `templates/k8s/httproute.yaml` | AKS Automatic only |
| `k8s/ingress.yaml` | `templates/k8s/ingress.yaml` | AKS Standard only |
| `k8s/hpa.yaml` | `templates/k8s/hpa.yaml` | min: 2, max: 10 |
| `k8s/pdb.yaml` | `templates/k8s/pdb.yaml` | minAvailable: 1 |
| `k8s/configmap.yaml` | `templates/k8s/configmap.yaml` | Only if app needs environment-specific config |

---

## Section 3: Safeguards Validation

Before deploying, validate all generated manifests against AKS Deployment Safeguards DS001–DS013. Reference `reference/safeguards.md` for the full checklist.

- 12 of 13 rules are auto-fixable. DS009 (no `:latest` tag) is resolved by tagging with git SHA.
- Apply framework-specific writable path requirements from the knowledge pack (e.g., Spring Boot needs `/tmp`, Next.js needs `/app/.next/cache`).
- Reference `reference/workload-identity.md` for Workload Identity configuration.

**AKS Automatic:** Safeguards are always enforced — all violations must be fixed.

**AKS Standard:** Check `safeguardsProfile.level`:
- `Enforcement`: fix all violations
- `Warning` or `Off`: mention issues as warnings, don't block

---

## Section 4: Deploy

### Build and push

```bash
IMAGE_TAG=$(git rev-parse --short HEAD)   # fallback: date +%Y%m%d%H%M%S
az acr build --registry <acr_name> --image <app-name>:$IMAGE_TAG --file Dockerfile .
```

### Deploy to cluster

```bash
# 1. Create namespace (must succeed before proceeding)
kubectl apply -f k8s/namespace.yaml
kubectl get namespace <namespace> -o name   # verify

# 2. Apply remaining manifests
kubectl apply -f k8s/ --recursive

# 3. Wait for rollout
kubectl rollout status deployment/<app-name> -n <namespace> --timeout=300s
```

If any step fails, show the error and stop.

---

## Section 5: Verify

```bash
# Pod status
kubectl get pods -n <namespace> -l app=<app-name>

# External IP (AKS Automatic)
kubectl get gateway -n <namespace> -o jsonpath='{.items[0].status.addresses[0].value}'

# External IP (AKS Standard)
kubectl get ingress -n <namespace> -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}'
```

Wait up to 3 minutes for external IP. Once available, curl the health endpoint and show the URL.
```

- [ ] **Step 2: Verify file is under 200 lines**

```bash
wc -l skills/deploy-to-aks/phases/quick-deploy.md
```

Expected: under 200 lines.

- [ ] **Step 3: Verify no presentation choreography leaked in**

Scan the file for banned patterns:

```bash
rg -c '◻|▸|✓|✗|celebration|banner|permission.*glob|CRITICAL.*output|DO NOT narrate|suppress|progress indicator|approval gate' skills/deploy-to-aks/phases/quick-deploy.md
```

Expected: 0 matches.

- [ ] **Step 4: Verify no Bicep or GitHub Actions references**

```bash
rg 'templates/bicep/|templates/github-actions/' skills/deploy-to-aks/phases/quick-deploy.md
```

Expected: 0 matches.

- [ ] **Step 5: Verify all required template references exist**

Check that all 6 Dockerfile templates and all 10 K8s templates are referenced:

```bash
for t in node.Dockerfile python.Dockerfile java.Dockerfile go.Dockerfile dotnet.Dockerfile rust.Dockerfile; do
  rg -q "$t" skills/deploy-to-aks/phases/quick-deploy.md || echo "MISSING: $t"
done
for t in namespace.yaml serviceaccount.yaml deployment.yaml service.yaml gateway.yaml httproute.yaml ingress.yaml hpa.yaml pdb.yaml configmap.yaml; do
  rg -q "$t" skills/deploy-to-aks/phases/quick-deploy.md || echo "MISSING: $t"
done
```

Expected: no "MISSING" output.

- [ ] **Step 6: Commit**

```bash
git add skills/deploy-to-aks/phases/quick-deploy.md
git commit -m "feat: create single-phase quick-deploy.md replacing 2-phase quick mode"
```

---

### Task 2: Update `SKILL.md` Quick Mode Phase Table

**Files:**
- Modify: `skills/deploy-to-aks/SKILL.md:65-71`

- [ ] **Step 1: Update the phase table**

Replace the "Quick Phase Instructions" section (lines 65-70 of SKILL.md):

Old:
```markdown
### Quick Phase Instructions

| Phase | Read | Also load |
|-------|------|-----------|
| Quick 1: Scan & Plan | `phases/quick-01-scan-and-plan.md` | `knowledge-packs/frameworks/<detected>.md` (if exists) |
| Quick 2: Execute | `phases/quick-02-execute.md` | `reference/safeguards.md`, `reference/workload-identity.md`, `templates/mermaid/summary-dashboard.md` |
```

New:
```markdown
### Quick Phase Instructions

| Phase | Read | Also load |
|-------|------|-----------|
| Quick Deploy | `phases/quick-deploy.md` | `knowledge-packs/frameworks/<detected>.md` (if exists), `reference/safeguards.md`, `reference/workload-identity.md` |
```

- [ ] **Step 2: Verify SKILL.md no longer references old files**

```bash
rg 'quick-01-scan-and-plan|quick-02-execute' skills/deploy-to-aks/SKILL.md
```

Expected: 0 matches.

- [ ] **Step 3: Verify SKILL.md still references quick-deploy.md**

```bash
rg 'quick-deploy.md' skills/deploy-to-aks/SKILL.md
```

Expected: 1 match.

- [ ] **Step 4: Commit**

```bash
git add skills/deploy-to-aks/SKILL.md
git commit -m "fix: update SKILL.md quick mode phase table for single-phase quick deploy"
```

---

### Task 3: Delete Old Quick Phase Files

**Files:**
- Delete: `skills/deploy-to-aks/phases/quick-01-scan-and-plan.md`
- Delete: `skills/deploy-to-aks/phases/quick-02-execute.md`

- [ ] **Step 1: Delete the old files**

```bash
git rm skills/deploy-to-aks/phases/quick-01-scan-and-plan.md
git rm skills/deploy-to-aks/phases/quick-02-execute.md
```

- [ ] **Step 2: Verify only quick-deploy.md remains as a quick file**

```bash
ls skills/deploy-to-aks/phases/quick-*
```

Expected: only `quick-deploy.md`.

- [ ] **Step 3: Commit**

```bash
git commit -m "fix: remove old 2-phase quick mode files (replaced by quick-deploy.md)"
```

---

### Task 4: Update `test_quick_deploy.py`

**Files:**
- Modify: `tests/structural/test_quick_deploy.py`

Every test referencing the old 2-file structure must be rewritten for the single `quick-deploy.md` file.

- [ ] **Step 1: Rewrite the test file**

Replace the entire content of `tests/structural/test_quick_deploy.py` with:

```python
"""Quick deploy mode structural tests.

Validates that the quick deploy phase file, prerequisites script, and SKILL.md
routing are internally consistent and properly cross-referenced.
"""

import re
import subprocess
from pathlib import Path


# --- Phase file existence and naming ---


def test_quick_phase_file_exists(skill_root: Path):
    """Quick deploy phase file exists in phases/."""
    phases_dir = skill_root / "phases"
    assert (phases_dir / "quick-deploy.md").is_file(), (
        f"Missing quick phase file: {phases_dir}/quick-deploy.md"
    )


def test_quick_phase_naming_convention(skill_root: Path):
    """Exactly one quick phase file exists matching quick-*.md pattern."""
    phases_dir = skill_root / "phases"
    quick_files = [f for f in phases_dir.iterdir() if f.name.startswith("quick-")]
    assert len(quick_files) == 1, f"Expected 1 quick phase file, found {len(quick_files)}: {[f.name for f in quick_files]}"
    assert quick_files[0].name == "quick-deploy.md"


def test_quick_phase_title(skill_root: Path):
    """Quick deploy phase file has a # title."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert re.search(r"^# Quick Deploy", content, re.MULTILINE), (
        "quick-deploy.md missing expected title '# Quick Deploy'"
    )


def test_quick_phase_goal_section(skill_root: Path):
    """Quick deploy phase file has a ## Goal section."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert re.search(r"^## Goal", content, re.MULTILINE), (
        "quick-deploy.md missing '## Goal' section"
    )


# --- SKILL.md routing ---


def test_skill_md_quick_mode_routing(skill_root: Path):
    """SKILL.md contains quick mode detection block and phase table."""
    skill_md = (skill_root / "SKILL.md").read_text()
    assert "Quick Deploy Mode" in skill_md, "SKILL.md missing 'Quick Deploy Mode' section"
    assert "quick-deploy.md" in skill_md, "SKILL.md missing reference to quick-deploy.md"


# --- Cross-references ---


def test_quick_mode_cross_references(skill_root: Path, repo_root: Path):
    """All file paths referenced in quick-deploy.md exist on disk."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    path_pattern = re.compile(r"`((?:templates|reference|knowledge-packs|scripts)/[a-zA-Z0-9/_.-]+)`")
    paths = path_pattern.findall(content)
    for rel_path in paths:
        if "<" in rel_path:
            continue
        if rel_path.startswith("scripts/"):
            full_path = repo_root / rel_path
        else:
            full_path = skill_root / rel_path
        assert full_path.exists(), f"quick-deploy.md references '{rel_path}' but it doesn't exist"


def test_quick_mode_no_bicep_references(skill_root: Path):
    """Quick deploy phase file does not reference any templates/bicep/ files."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert "templates/bicep/" not in content, "quick-deploy.md should not reference Bicep templates"


def test_quick_mode_no_github_actions_references(skill_root: Path):
    """Quick deploy phase file does not reference templates/github-actions/."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert "templates/github-actions/" not in content, (
        "quick-deploy.md should not reference GitHub Actions templates"
    )


# --- No presentation choreography ---


def test_quick_mode_no_presentation_choreography(skill_root: Path):
    """Quick deploy phase file contains no presentation choreography."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    banned_patterns = [
        ("progress indicators", r"[◻▸✓✗]"),
        ("celebration banner", r"celebration|🎉"),
        ("permission glob strategy", r"permission.*glob|glob.*permission"),
        ("narration suppression", r"DO NOT narrate|do not narrate"),
        ("output suppression", r"suppress.*output|output.*suppress"),
    ]
    for name, pattern in banned_patterns:
        assert not re.search(pattern, content, re.IGNORECASE), (
            f"quick-deploy.md contains {name} (pattern: {pattern})"
        )


# --- Prerequisites script ---


def test_prerequisites_script_exists(repo_root: Path):
    """scripts/setup-aks-prerequisites.sh exists and is executable."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    assert script.is_file(), "Missing prerequisites script"
    assert script.stat().st_mode & 0o111, "Prerequisites script is not executable"


def test_prerequisites_script_help_flag(repo_root: Path):
    """Script supports --help and prints usage."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    result = subprocess.run(
        [str(script), "--help"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0, f"--help exited with {result.returncode}"
    assert "Usage:" in result.stdout, "--help output missing 'Usage:'"


def test_prerequisites_script_required_args(repo_root: Path):
    """Script errors with message when --name is missing."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    result = subprocess.run(
        [str(script)],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode != 0, "Script should fail without --name"
    assert "--name" in result.stderr, "Error message should mention --name"


def test_prerequisites_script_has_cleanup(repo_root: Path):
    """Script source contains --cleanup handling."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    content = script.read_text()
    assert "--cleanup" in content, "Script missing --cleanup flag handling"
```

- [ ] **Step 2: Run the quick deploy tests to verify they pass**

```bash
make test
```

Expected: All tests pass. (Some will fail until Tasks 1-3 are completed, so this task should be executed after Tasks 1-3.)

- [ ] **Step 3: Commit**

```bash
git add tests/structural/test_quick_deploy.py
git commit -m "test: update quick deploy tests for single-phase quick-deploy.md"
```

---

### Task 5: Update `test_cross_references.py`

**Files:**
- Modify: `tests/structural/test_cross_references.py:51-64,130-149`

Three tests reference old quick phase file names and must be updated.

- [ ] **Step 1: Update `test_knowledge_packs_referenced`**

Replace lines 51-64:

Old:
```python
def test_knowledge_packs_referenced(skill_root: Path):
    """Every knowledge pack is referenced in 01-discover.md or SKILL.md."""
    skill_md = (skill_root / "SKILL.md").read_text()
    discover = (skill_root / "phases" / "01-discover.md").read_text()
    quick_scan = (skill_root / "phases" / "quick-01-scan-and-plan.md").read_text()
    combined = skill_md + discover + quick_scan
    kp_dir = skill_root / "knowledge-packs" / "frameworks"
    assert kp_dir.exists(), f"Knowledge packs directory does not exist: {kp_dir}"
    files = [f for f in sorted(kp_dir.iterdir()) if f.is_file() and f.suffix == ".md"]
    assert files, f"No files found in {kp_dir}"
    for pack in files:
        assert pack.stem in combined, (
            f"Orphan knowledge pack: {pack.name} not referenced in SKILL.md, 01-discover.md, or quick-01-scan-and-plan.md"
        )
```

New:
```python
def test_knowledge_packs_referenced(skill_root: Path):
    """Every knowledge pack is referenced in 01-discover.md, quick-deploy.md, or SKILL.md."""
    skill_md = (skill_root / "SKILL.md").read_text()
    discover = (skill_root / "phases" / "01-discover.md").read_text()
    quick_deploy = (skill_root / "phases" / "quick-deploy.md").read_text()
    combined = skill_md + discover + quick_deploy
    kp_dir = skill_root / "knowledge-packs" / "frameworks"
    assert kp_dir.exists(), f"Knowledge packs directory does not exist: {kp_dir}"
    files = [f for f in sorted(kp_dir.iterdir()) if f.is_file() and f.suffix == ".md"]
    assert files, f"No files found in {kp_dir}"
    for pack in files:
        assert pack.stem in combined, (
            f"Orphan knowledge pack: {pack.name} not referenced in SKILL.md, 01-discover.md, or quick-deploy.md"
        )
```

- [ ] **Step 2: Update `test_quick_phase_dockerfile_templates_referenced`**

Replace lines 130-138:

Old:
```python
def test_quick_phase_dockerfile_templates_referenced(skill_root: Path):
    """Every Dockerfile template is referenced in quick-02-execute.md."""
    quick_exec = (skill_root / "phases" / "quick-02-execute.md").read_text()
    docker_dir = skill_root / "templates" / "dockerfiles"
    templates = [t for t in sorted(docker_dir.iterdir()) if t.is_file()]
    assert templates, "No Dockerfile templates found"
    for template in templates:
        ref = f"templates/dockerfiles/{template.name}"
        assert ref in quick_exec, f"Dockerfile template {template.name} not referenced in quick-02-execute.md"
```

New:
```python
def test_quick_phase_dockerfile_templates_referenced(skill_root: Path):
    """Every Dockerfile template is referenced in quick-deploy.md."""
    quick_deploy = (skill_root / "phases" / "quick-deploy.md").read_text()
    docker_dir = skill_root / "templates" / "dockerfiles"
    templates = [t for t in sorted(docker_dir.iterdir()) if t.is_file()]
    assert templates, "No Dockerfile templates found"
    for template in templates:
        ref = f"templates/dockerfiles/{template.name}"
        assert ref in quick_deploy, f"Dockerfile template {template.name} not referenced in quick-deploy.md"
```

- [ ] **Step 3: Update `test_quick_phase_k8s_templates_referenced`**

Replace lines 141-149:

Old:
```python
def test_quick_phase_k8s_templates_referenced(skill_root: Path):
    """Every K8s template is referenced in quick-02-execute.md."""
    quick_exec = (skill_root / "phases" / "quick-02-execute.md").read_text()
    k8s_dir = skill_root / "templates" / "k8s"
    templates = [t for t in sorted(k8s_dir.iterdir()) if t.is_file()]
    assert templates, "No K8s templates found"
    for template in templates:
        ref = f"templates/k8s/{template.name}"
        assert ref in quick_exec, f"K8s template {template.name} not referenced in quick-02-execute.md"
```

New:
```python
def test_quick_phase_k8s_templates_referenced(skill_root: Path):
    """Every K8s template is referenced in quick-deploy.md."""
    quick_deploy = (skill_root / "phases" / "quick-deploy.md").read_text()
    k8s_dir = skill_root / "templates" / "k8s"
    templates = [t for t in sorted(k8s_dir.iterdir()) if t.is_file()]
    assert templates, "No K8s templates found"
    for template in templates:
        ref = f"templates/k8s/{template.name}"
        assert ref in quick_deploy, f"K8s template {template.name} not referenced in quick-deploy.md"
```

- [ ] **Step 4: Run all tests**

```bash
make test
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add tests/structural/test_cross_references.py
git commit -m "test: update cross-reference tests for single-phase quick-deploy.md"
```

---

### Task 6: Final Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

```bash
make test
```

Expected: All tests pass. Note the total test count (should be similar to 72 but may decrease slightly since we consolidated some tests).

- [ ] **Step 2: Verify no stale references remain**

```bash
rg -r 'quick-01-scan-and-plan|quick-02-execute' skills/ tests/
```

Expected: 0 matches anywhere in the codebase.

- [ ] **Step 3: Verify quick-deploy.md line count**

```bash
wc -l skills/deploy-to-aks/phases/quick-deploy.md
```

Expected: under 200 lines.

- [ ] **Step 4: Run lint**

```bash
make lint
```

Expected: passes clean.

- [ ] **Step 5: Review git log**

```bash
git log --oneline -5
```

Expected: 4 commits from Tasks 1-5, each with descriptive conventional commit messages.

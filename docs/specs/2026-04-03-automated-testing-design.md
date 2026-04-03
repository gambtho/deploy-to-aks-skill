# Automated Testing Design

**Goal:** Add automated testing to the deploy-to-aks skill to catch regressions, validate internal consistency, and verify the skill produces correct output when run against test projects.

**Spec:** This document.

---

## Architecture

Two-tier test suite with separate CI workflows:

- **Tier 1 — Structural tests:** Fast, deterministic, free. Validate that skill files are internally consistent. Run on every push and PR.
- **Tier 2 — LLM behavioral tests:** Slow, non-deterministic, costs premium requests. Feed fixture projects to the skill via Copilot CLI headless mode, assert properties of generated output. Run on manual trigger and weekly schedule.

Both tiers use Python + pytest. The tiers are fully independent — structural tests never invoke an LLM, and LLM tests don't duplicate structural checks.

### Platform Limitation

LLM behavioral tests use Copilot CLI as the sole test harness. This means we test the skill content through one agent only — we cannot catch platform-specific regressions on Claude Code or OpenCode. This is an accepted trade-off: the skill content is platform-neutral markdown, so the primary risk is content correctness (which Copilot tests cover), not platform-specific behavior. If platform-specific issues emerge in practice, we can add parallel test harnesses for `claude -p` or OpenCode's equivalent later.

---

## Project Structure

```
tests/
  conftest.py                       # Shared fixtures (skill root path, repo root path)

  structural/
    conftest.py                     # Auto-apply 'structural' marker to all tests
    test_cross_references.py        # SKILL.md ↔ phases/, templates/, reference/ links
    test_placeholders.py            # Placeholder convention compliance per template type
    test_templates.py               # YAML/Bicep/Dockerfile syntax validation
    test_phase_structure.py         # Phase file naming, titles, required sections
    test_install_script.py          # install.sh flag parsing, help, error handling, happy path
    test_readme.py                  # README ↔ skill content consistency
    test_agents_md.py               # AGENTS.md accuracy (repo structure, conventions)

  llm/
    conftest.py                     # Auto-apply 'llm' marker + Copilot CLI helper
    test_phase1_discover.py         # Feed fixture project → assert discovery summary
    test_phase3_containerize.py     # Feed fixture project → assert Dockerfile properties
    test_phase4_scaffold.py         # Feed fixture project → assert K8s manifest properties
    fixtures/
      spring-boot-minimal/          # pom.xml, Application.java, application.properties
      express-minimal/              # package.json, index.js
      fastapi-minimal/              # pyproject.toml, main.py
      go-gin-minimal/               # go.mod, main.go
      dotnet-minimal/               # app.csproj, Program.cs

.github/workflows/
  test.yml                          # Structural tests — every push/PR
  test-llm.yml                      # LLM tests — manual trigger + weekly schedule

Makefile                            # Convenience targets: test, test-llm, lint
pyproject.toml                      # pytest config, dependencies, ruff config
```

---

## Dependencies

```toml
[project]
name = "deploy-to-aks-skill"
requires-python = ">=3.12"

[project.optional-dependencies]
test = [
    "pytest>=8.0",
    "pyyaml>=6.0",
    "pytest-timeout>=2.3",
]
llm = [
    "deploy-to-aks-skill[test]",
    "pytest-rerunfailures>=14.0",
]
dev = [
    "deploy-to-aks-skill[test]",
    "deploy-to-aks-skill[llm]",
    "ruff>=0.8",
]

[tool.pytest.ini_options]
testpaths = ["tests"]
markers = [
    "structural: fast, deterministic structural/lint tests",
    "llm: slow, non-deterministic LLM behavioral tests (requires Copilot CLI)",
]

[tool.ruff]
target-version = "py312"
line-length = 120

[tool.ruff.lint]
select = ["E", "F", "I", "W"]
```

pytest marker auto-application is handled by per-directory `conftest.py` files:

```python
# tests/structural/conftest.py
import pytest
pytestmark = pytest.mark.structural

# tests/llm/conftest.py
import pytest
pytestmark = pytest.mark.llm
```

No `__init__.py` files are needed — pytest's rootdir discovery with `testpaths = ["tests"]` handles this. The `conftest.py` files provide both marker auto-application and shared fixtures.

### Root conftest.py Fixtures

The top-level `tests/conftest.py` provides `repo_root` and `skill_root` fixtures used by both tiers:

```python
# tests/conftest.py
from pathlib import Path
import pytest

@pytest.fixture(scope="session")
def repo_root() -> Path:
    """Resolve repo root by walking up from this file to find pyproject.toml."""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / "pyproject.toml").exists():
            return current
        current = current.parent
    raise RuntimeError("Could not find repo root (no pyproject.toml found)")

@pytest.fixture(scope="session")
def skill_root(repo_root) -> Path:
    """Path to the skill directory under repo root."""
    path = repo_root / "skills" / "deploy-to-aks"
    assert path.is_dir(), f"Skill root not found: {path}"
    return path
```

Resolution strategy: walk up from the test file's location to find `pyproject.toml` (the project marker file). This is robust against directory moves — as long as the test file is somewhere inside the repo, it will find the root. Using `pyproject.toml` as the marker is reliable because this project requires it for dependencies.

---

## Tier 1: Structural Tests

### test_cross_references.py

Parses SKILL.md's phase table and extracts all file path references. Asserts each referenced file exists on disk:

- Phase instruction files (`phases/01-discover.md` through `phases/06-deploy.md`)
- "Also load" references (`reference/cost-reference.md`, `reference/safeguards.md`, etc.)
- Template paths referenced in phase files (`templates/github-actions/deploy.yml`, etc.)
- Mermaid template paths referenced in SKILL.md's diagram section (`templates/mermaid/architecture-diagram.md`, `templates/mermaid/summary-dashboard.md`) — and that every file in `templates/mermaid/` is referenced at least once (no orphans)
- Knowledge packs listed in `01-discover.md` (`knowledge-packs/frameworks/spring-boot.md`) — and that every file in `knowledge-packs/frameworks/` is referenced in either `01-discover.md` or `SKILL.md`
- Knowledge packs follow a consistent structure: each has a `#` title and at least one `##` section

**Orphan template detection (reverse reference check):**

In addition to verifying that referenced paths exist on disk, check that every template file is referenced by at least one phase file or by `SKILL.md`. This catches orphaned templates that would drift and rot. Specifically:

- Every file in `templates/mermaid/` is referenced in `SKILL.md` (already specified above)
- Every file in `templates/k8s/` (10 files) is referenced in `phases/04-scaffold.md`
- Every file in `templates/bicep/` (8 files) is referenced in `phases/04-scaffold.md` or `phases/02-architect.md`
- Every file in `templates/dockerfiles/` (6 files) is referenced in `phases/03-containerize.md`
- Every file in `templates/github-actions/` is referenced in `phases/05-pipeline.md`

### test_placeholders.py

Scans each template directory and asserts the correct placeholder convention:

| Directory | Expected Style | Regex |
|-----------|---------------|-------|
| `templates/k8s/` | `<angle-bracket>` | `<[a-z][a-z-]+>` |
| `templates/github-actions/` | `__DOUBLE_UNDERSCORE__` | `__[A-Z_]+__` |
| `templates/mermaid/` | `{{DOUBLE_CURLY}}` | `\{\{[A-Z_]+\}\}` |
| `templates/bicep/*.bicep` | Bicep `param` declarations | No raw placeholders |
| `templates/bicep/*.bicepparam` | `using` + parameter assignments | Excluded from `param`/`resource` check |

Also asserts no mixed styles within a single template (e.g., a K8s template should not contain `__PLACEHOLDER__`).

**Exception:** `deploy.yml` contains `<image>` inside a `sed` command string (line 105: `sed -i "s|image: <image>|image: ${IMAGE}|"`). This is a K8s manifest placeholder that the workflow replaces at deploy time — it is not a user-facing `__DOUBLE_UNDERSCORE__` placeholder. The cross-contamination check must exclude angle-bracket occurrences inside shell command strings (i.e., within `sed`, `envsubst`, or similar substitution commands) to avoid false failures.

**Note on `.bicepparam` files:** The `main.bicepparam` file uses `using './main.bicep'` + `param <name> = '<value>'` syntax, which is the Bicep parameter file format — distinct from `.bicep` module files. The placeholder test must handle `.bicep` and `.bicepparam` as separate categories: `.bicep` files are checked for `param` or `resource` declarations, while `.bicepparam` files are checked for `using` declarations and `param` value assignments. Both may contain `<angle-bracket>` placeholders for values (e.g., `param appName = '<app-name>'`) — this is the expected convention for parameter files.

### test_templates.py

**Dockerfile templates:**
- All 6 Dockerfiles exist (`java.Dockerfile`, `node.Dockerfile`, `python.Dockerfile`, `dotnet.Dockerfile`, `go.Dockerfile`, `rust.Dockerfile`)
- Each has `FROM` as first non-comment instruction
- Each has at least 2 `FROM` instructions (multi-stage build)

**K8s YAML templates:**
- Parse as valid YAML (via `yaml.safe_load`)
- Each document has a `kind` and `apiVersion` field

**GitHub Actions workflow:**
- Parses as valid YAML
- Has expected top-level keys: `name`, `on`, `permissions`, `env`, `jobs`
- Has a `build-and-deploy` job
- References the 3 OIDC secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` — these appear as `${{ secrets.AZURE_CLIENT_ID }}` etc. (GitHub Actions secrets syntax), not as `__DOUBLE_UNDERSCORE__` placeholders. They are hardcoded secret reference names, not user-replaceable placeholders.
- Contains all 5 expected placeholders: `__ACR_NAME__`, `__AKS_CLUSTER__`, `__RG_NAME__`, `__APP_NAME__`, `__NAMESPACE__`

**Bicep files:**
- `.bicep` files contain at least one `param`, `resource`, or `module` declaration (e.g., `main.bicep` is an orchestrator that uses `module` to compose sub-modules)
- `.bicepparam` files contain a `using` declaration
- All 8 Bicep files are present (`acr.bicep`, `aks.bicep`, `identity.bicep`, `keyvault.bicep`, `main.bicep`, `main.bicepparam`, `postgresql.bicep`, `redis.bicep`)

### test_phase_structure.py

- All 6 phase files exist with naming pattern `0N-<name>.md`
- Each phase has a `# Phase N:` title matching its number
- Each phase has a `## Goal` section
- Phase files are within reasonable size bounds based on actual current sizes: > 4KB (smallest is `05-pipeline.md` at ~4.8KB), < 25KB (largest is `06-deploy.md` at ~19.5KB). Use 3KB floor and 30KB ceiling to allow growth without false alarms — a file below 3KB (~60 lines) would be a stub, not a real phase.

### test_install_script.py

Uses `subprocess.run` against `install.sh`:

**Error path tests:**
- `--help` exits 0, stdout contains `Usage:`
- Unknown flag exits non-zero, stderr contains `Error:`
- Running from a temp dir (no `skills/` present) exits non-zero with "Cannot find" message
- `--platform copilot --scope global` exits non-zero with error about global not supported
- Invalid `--platform` value exits non-zero

**Happy path tests:**
- `--platform copilot --scope project --project-dir <tmp>` creates `.github/skills/deploy-to-aks/SKILL.md`, `.github/skills/deploy-to-aks/phases/` (non-empty), `.github/skills/deploy-to-aks/templates/` (non-empty), and `.github/copilot-instructions.md` in the temp directory
- `--platform claude-code --scope project --project-dir <tmp>` creates `.claude/skills/deploy-to-aks/SKILL.md`, `.claude/skills/deploy-to-aks/phases/` (non-empty), and `.claude/skills/deploy-to-aks/templates/` (non-empty) in the temp directory
- `--platform opencode --scope project --project-dir <tmp>` creates `.opencode/skills/deploy-to-aks/SKILL.md`, `.opencode/skills/deploy-to-aks/phases/` (non-empty), and `.opencode/skills/deploy-to-aks/templates/` (non-empty) in the temp directory

Happy path tests use a temp directory as `--project-dir` and run the install script from the repo root (where `skills/deploy-to-aks/SKILL.md` exists). They verify the expected directory structure is created, key files are present, and the full skill directory was copied (not just `SKILL.md`). Checking that `phases/` and `templates/` are non-empty subdirectories catches a bug where only `SKILL.md` is copied.

### test_readme.py

- All three platforms ("Claude Code", "GitHub Copilot", "OpenCode") appear in the installation section
- Phase table in README matches SKILL.md's phase table (same phase names: Discover, Architect, Containerize, Scaffold, Pipeline, Deploy)
- Supported frameworks list covers all 6 languages that have Dockerfile templates. The mapping from README names to template filenames is: "Node.js" → `node.Dockerfile`, "Python" → `python.Dockerfile`, "Java" → `java.Dockerfile`, "Go" → `go.Dockerfile`, ".NET" → `dotnet.Dockerfile`, "Rust" → `rust.Dockerfile`. The test extracts language names from the README's "Supported frameworks" line and verifies a corresponding Dockerfile template exists for each.
- Project structure tree matches actual directory layout

### test_agents_md.py

- Repository structure tree matches actual top-level directories
- All three platforms mentioned (not single-platform bias)
- Placeholder convention descriptions match what `test_placeholders.py` validates
- Test scenarios table lists frameworks that have corresponding Dockerfile templates

---

## Tier 2: LLM Behavioral Tests

### Copilot CLI Helper

```python
def run_copilot(prompt: str, workdir: Path, timeout: int = 120) -> str:
    result = subprocess.run(
        ["copilot", "-p", prompt, "--allow-all-tools"],
        capture_output=True, text=True,
        cwd=workdir, timeout=timeout
    )
    if result.returncode != 0:
        raise RuntimeError(f"Copilot failed: {result.stderr}")
    return result.stdout
```

### Workspace Setup

Each test copies a fixture project to a temp directory using `shutil.copytree`, then symlinks or reuses a shared skill copy. The skill directory is copied once per session (session-scoped fixture) since tests are read-only on skill content. Each test gets its own fixture project copy to avoid cross-test contamination.

```python
@pytest.fixture(scope="session")
def shared_skill_dir(tmp_path_factory, skill_root):
    """Copy skill directory once per session — tests are read-only on it."""
    dest = tmp_path_factory.mktemp("skill") / "deploy-to-aks"
    shutil.copytree(skill_root, dest)
    return dest

@pytest.fixture
def workspace(tmp_path, shared_skill_dir, request):
    """Create a self-contained workspace with fixture project + shared skill."""
    fixture_name = request.param  # e.g., "spring-boot-minimal"
    fixture_src = Path(__file__).parent / "fixtures" / fixture_name

    # Copy fixture files to workspace root
    for item in fixture_src.iterdir():
        if item.is_dir():
            shutil.copytree(item, tmp_path / item.name)
        else:
            shutil.copy2(item, tmp_path / item.name)

    # Symlink shared skill copy into workspace
    skill_dest = tmp_path / "skills" / "deploy-to-aks"
    skill_dest.parent.mkdir(parents=True)
    skill_dest.symlink_to(shared_skill_dir)

    return tmp_path
```

This avoids copying ~40 skill files per test. With 7 LLM tests, that eliminates 6 redundant full copies. If symlinks cause issues on any platform, fall back to `shutil.copytree` per test.

### Prompt Pattern

```bash
copilot -p "Load the skill at skills/deploy-to-aks/SKILL.md. \
  I want to deploy this project to AKS. \
  Run Phase N only. Do not ask questions — use defaults. \
  Output the [expected output] and stop." \
  --allow-all-tools
```

### Test Cases

| Test | Fixture | Phase | Assertions |
|------|---------|-------|------------|
| `test_spring_boot_detection` | `spring-boot-minimal` | 1 | Output contains "Spring Boot", "8080", reference to `pom.xml` or Maven |
| `test_express_detection` | `express-minimal` | 1 | Output contains "Express", "3000", reference to `package.json` |
| `test_fastapi_detection` | `fastapi-minimal` | 1 | Output contains "FastAPI", "8000", reference to `pyproject.toml` |
| `test_go_gin_detection` | `go-gin-minimal` | 1 | Output contains "Gin" or "Go", "8080", reference to `go.mod` |
| `test_dotnet_detection` | `dotnet-minimal` | 1 | Output contains "ASP.NET" or ".NET", "5000", reference to `.csproj` |
| `test_dockerfile_generation` | `spring-boot-minimal` | 3 | Generated Dockerfile has `FROM`, multi-stage build, `EXPOSE 8080`, non-root user |
| `test_k8s_manifest_generation` | `spring-boot-minimal` | 4 | Generates Deployment + Service YAML, correct port, resource limits present |

### Phases Not Covered

Phases 2, 5, and 6 are not tested in the LLM tier:

- **Phase 2 (Architect)** requires interactive approval of architecture diagrams and cost estimates. Automating approval in headless mode is fragile and the output is highly variable (infrastructure choices depend on backing services detected).
- **Phase 5 (Pipeline)** is a high-value target but its output (a GitHub Actions workflow) depends on accumulated state from phases 1-4. Testing it in isolation would require mocking all prior phase state, which is complex and brittle. Future work could add a Phase 5 test with a pre-built state fixture.
- **Phase 6 (Deploy)** executes CLI commands against real Azure infrastructure. Cannot be tested without credentials and real resources.

### Assertion Style

All assertions are property-based — check for presence of expected patterns, not exact text. Example:

```python
assert "spring boot" in output.lower()
assert "8080" in output
```

### Retry

LLM tests get one automatic retry on failure via `--reruns 1` (from `pytest-rerunfailures`, included in the `[llm]` dependency extra). This handles non-deterministic output variation without masking real failures.

---

## Fixture Projects

Each fixture is the absolute minimum files needed for framework detection. No real build output, no dependencies downloaded. The 5 fixtures cover the 5 frameworks listed in AGENTS.md's test scenarios table. Rust is omitted because it has no knowledge pack and no AGENTS.md test scenario — structural tests verify the Dockerfile template exists, but LLM behavioral testing adds limited value for a framework with no special handling.

### spring-boot-minimal

```
pom.xml                     # spring-boot-starter-web dependency, Java 17
src/main/java/com/example/App.java  # @SpringBootApplication with /health GET endpoint
application.properties      # server.port=8080
```

### express-minimal

```
package.json                # express dependency, start script
index.js                    # Express app listening on port 3000 with /health endpoint
```

### fastapi-minimal

```
pyproject.toml              # fastapi + uvicorn dependencies
main.py                     # FastAPI app with /health endpoint on port 8000
```

### go-gin-minimal

```
go.mod                      # gin-gonic/gin dependency, Go 1.22
main.go                     # Gin app listening on port 8080 with /health endpoint
```

### dotnet-minimal

```
app.csproj                  # ASP.NET Core 8.0 project
Program.cs                  # Minimal API with /health endpoint on port 5000
```

---

## CI Workflows

### test.yml — Structural Tests

```yaml
name: Structural Tests
on:
  push:
    branches: [main]
  pull_request:

jobs:
  structural:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -e ".[test]"
      - run: pytest tests/structural/ -v
```

Runs on every push to main and every PR. Expected runtime: < 30 seconds.

### test-llm.yml — LLM Behavioral Tests

```yaml
name: LLM Behavioral Tests
on:
  workflow_dispatch:
    inputs:
      test_filter:
        description: 'pytest -k filter expression (e.g., "test_spring_boot_detection")'
        required: false
        default: ''
  schedule:
    - cron: '0 6 * * 1'    # Every Monday at 6am UTC

concurrency:
  group: llm-tests
  cancel-in-progress: true

jobs:
  llm:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - name: Install Copilot CLI
        run: npm install -g @anthropic-ai/claude-code
        # TODO: Replace with actual Copilot CLI install command once GitHub
        # publishes the official package. As of 2026-04-03, the Copilot CLI
        # distribution method is not yet documented for CI use. Track:
        # https://docs.github.com/en/copilot/github-copilot-in-the-cli
        # For now, this step will need to be updated before LLM tests can
        # run in CI. The tests themselves are designed to work with any
        # CLI that accepts: <binary> -p "<prompt>" --allow-all-tools
      - run: pip install -e ".[llm]"
      - run: >-
          pytest tests/llm/ -v --timeout=120 --reruns=1
          ${{ inputs.test_filter && format('-k "{0}"', inputs.test_filter) || '' }}
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Cost controls:**
- Manual trigger by default — no accidental token burn on PRs
- Weekly schedule catches regressions
- `concurrency` ensures only one LLM run at a time
- `timeout-minutes: 30` hard cap on entire job
- Per-test 120s timeout via pytest-timeout
- Fixture projects are minimal to reduce token usage

**Estimated cost per run:** Each test invokes the Copilot CLI once. The agent reads the skill files (SKILL.md ~100 lines + relevant phase file ~150-600 lines + reference/template files) plus the fixture project (~50-100 lines), reasons about them, and produces output. Realistic per-test token consumption is ~10,000-50,000 tokens (input + output). At current rates (~$3-15/MTok for capable models), that's ~$0.03-$0.75 per test. With 7 tests: **~$0.20-$5.00 per run**. Weekly schedule: **~$1-$20/month**. Actual cost depends on the model Copilot CLI uses and how much of the skill content it reads per phase.

---

## Convenience Targets

A `Makefile` at the repo root provides discoverable shortcuts:

```makefile
.PHONY: test test-llm test-all lint

test:                           ## Run structural tests
	pytest tests/structural/ -v

test-llm:                       ## Run LLM behavioral tests (requires Copilot CLI)
	pytest tests/llm/ -v --timeout=120 --reruns=1

test-all: test test-llm         ## Run all tests (structural + LLM)

lint:                           ## Lint test code
	ruff check tests/
	ruff format --check tests/
```

---

## Running Tests Locally

```bash
# Install structural test dependencies
pip install -e ".[test]"

# Run structural tests only (fast, free)
make test
# or: pytest tests/structural/ -v

# Install LLM test dependencies (includes pytest-rerunfailures)
pip install -e ".[llm]"

# Run LLM tests (requires Copilot CLI installed + authenticated)
make test-llm
# or: pytest tests/llm/ -v --timeout=120 --reruns=1

# Run all tests (structural + LLM)
make test-all

# Lint test code
pip install -e ".[dev]"
make lint
```

---

## What Is NOT Tested

- **Full 6-phase flow** — too slow, expensive, and fragile. Individual phase tests are sufficient.
- **Phases 2, 5, 6 in LLM tier** — Phase 2 requires interactive approval, Phase 5 depends on accumulated state from prior phases, Phase 6 requires real Azure infrastructure. See "Phases Not Covered" section above.
- **Actual Azure deployment** — requires Azure credentials and real infrastructure. Out of scope.
- **Exact LLM output text** — non-deterministic. We test structural properties only.
- **Bicep compilation** — would require Azure CLI. We validate syntax patterns only.
- **Docker image builds** — would require Docker. We validate Dockerfile structure only.
- **Platform-specific regressions** — LLM tests use Copilot CLI only. Claude Code and OpenCode are not tested. See "Platform Limitation" section above.

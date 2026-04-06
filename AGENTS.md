# AGENTS.md

## Project overview

This repository contains the **deploy-to-aks** AI coding agent skill — a phased, conversational guide that deploys web applications to Azure Kubernetes Service (AKS) without requiring Kubernetes expertise. It supports Claude Code, GitHub Copilot, and OpenCode. It is not a runnable application; it is a collection of markdown instruction files, reference documents, and templates consumed by an AI coding agent at runtime.

## Repository structure

```
skills/deploy-to-aks/
  SKILL.md                          # Coordinator — entry point the agent reads first
  phases/                           # 6 ordered instruction files (01-discover through 06-deploy)
  reference/                        # AKS domain knowledge (safeguards, cost, workload identity, AKS flavors)
  templates/
    bicep/                          # Bicep IaC module templates
    dockerfiles/                    # Multi-stage Dockerfile templates per language
    github-actions/                 # CI/CD workflow template
    k8s/                            # Kubernetes manifest templates
    mermaid/                        # Mermaid diagram templates for terminal rendering
  knowledge-packs/frameworks/       # Framework-specific deployment guidance (e.g., spring-boot.md)
docs/specs/                         # Design spec and implementation plan
```

## Key conventions

- **IaC is Bicep only.** No Terraform. All infrastructure templates use Azure Bicep modules.
- **CI/CD is GitHub Actions only.** The single workflow template lives in `templates/github-actions/deploy.yml`.
- **AKS flavors:** AKS Automatic (default/recommended) and AKS Standard. Templates and phases handle both via conditionals.
- **Diagrams are mermaid code blocks** rendered inline in the terminal. There are no HTML files or browser dependencies.
- **Placeholder styles differ by template type:**
  - Kubernetes manifests use `<angle-bracket>` placeholders (e.g., `<app-name>`, `<port>`)
  - Bicep templates use standard Bicep `param` declarations
  - GitHub Actions workflow uses `__DOUBLE_UNDERSCORE__` placeholders (e.g., `__ACR_NAME__`)
  - Mermaid diagram templates use `{{DOUBLE_CURLY}}` placeholders (e.g., `{{APP_NAME}}`)
- **Knowledge packs** are optional, framework-specific markdown files in `knowledge-packs/frameworks/`. They augment but never replace the core phase instructions.

## Editing guidelines

- **Phase files (`phases/*.md`)** are the core logic. Each phase is self-contained and references templates/references it needs. When editing a phase, also check `SKILL.md`'s phase table to ensure the "Also load" column stays accurate.
- **Templates** are meant to be copied and adapted per-project by the agent at runtime. They should remain generic with clear placeholders — never hardcode project-specific values.
- **Reference files** are factual documentation. Keep them current with Azure/AKS upstream changes. The safeguards reference (`reference/safeguards.md`) maps directly to AKS Deployment Safeguard policy IDs (DS001-DS013). Each reference file has a "Last updated" date at the top — update it when making changes.
- **Design specs** (`docs/specs/`) are historical design records. They may be stale relative to the current implementation (e.g., the spec references an HTML visual companion that was replaced by mermaid diagrams). Treat them as context, not as source of truth.
- **SKILL.md** is the coordinator file read by the agent first. Its checklist, phase table, and key principles section must stay in sync with the phase files.
- Do not add Terraform, Helm charts, or alternative CI/CD providers. Those are explicitly out of scope for v1.

## Testing

Two-tier automated test suite, plus manual integration testing:

- **Structural tests** (`make test`) — fast, deterministic, free. Validate internal consistency of skill files, templates, cross-references, placeholders, and install script. Run on every push/PR via `.github/workflows/test.yml`.
- **LLM behavioral tests** (`make test-llm`) — slow, non-deterministic, costs premium requests. Feed fixture projects to the skill via Copilot CLI headless mode and assert properties of generated output. Run on manual trigger and weekly schedule via `.github/workflows/test-llm.yml`.
- **Manual integration testing** — run the skill against real projects inside any supported agent (Claude Code, GitHub Copilot, or OpenCode) and verify the generated artifacts are correct and the phases flow properly.

```bash
pip install -e ".[dev]"   # Install all test + lint dependencies
make test                  # Run structural tests (~10s)
make test-llm              # Run LLM tests (requires Copilot CLI)
make lint                  # Lint test code with ruff
```

When making changes, run `make test` locally before pushing. Also mentally trace through the 6-phase flow to ensure consistency.

### Suggested manual test scenarios

| Scenario | Exercises |
|----------|-----------|
| Spring Boot + PostgreSQL on AKS Automatic | Java Dockerfile, PostgreSQL Bicep, Gateway API, knowledge pack |
| Node.js Express + Redis on AKS Standard | Node Dockerfile, Redis Bicep, Ingress, no knowledge pack |
| Python FastAPI (no backing services) on AKS Automatic | Python Dockerfile, minimal Bicep, Gateway API |
| .NET ASP.NET Core + Key Vault on AKS Standard | .NET Dockerfile, Key Vault Bicep, Ingress, Workload Identity |
| Go Gin (self-contained) on AKS Automatic | Go Dockerfile (distroless), minimal Bicep, Gateway API |

## Commit style

Follow conventional commits: `feat:`, `fix:`, `docs:`, `chore:`. Most changes to phase files or templates are `fix:` (improving existing behavior) or `feat:` (adding new capability like a knowledge pack).

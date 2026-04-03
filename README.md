# deploy-to-aks

An AI coding agent skill that guides developers through deploying their applications to Azure Kubernetes Service (AKS) — no Kubernetes expertise required.

Supports **Claude Code**, **GitHub Copilot**, and **OpenCode**.

## What it does

A conversational, phased deployment guide that runs inside your AI coding agent. It reads your actual project, detects your framework and dependencies, generates production-ready deployment artifacts, and optionally executes the deployment — all from your terminal.

| Phase | Name | What happens |
|-------|------|-------------|
| 1 | **Discover** | Scans your project, detects framework/language/dependencies, asks clarifying questions |
| 2 | **Architect** | Plans infrastructure, shows architecture diagram + cost estimate, gets your approval |
| 3 | **Containerize** | Generates or validates Dockerfile + .dockerignore |
| 4 | **Scaffold** | Generates K8s manifests + Bicep IaC, validates against AKS Deployment Safeguards |
| 5 | **Pipeline** | Generates GitHub Actions CI/CD workflow, optionally sets up OIDC federation |
| 6 | **Deploy** | Executes deployment commands (with confirmation at each step), shows summary dashboard |

File generation is automatic. Any CLI commands (`az`, `docker`, `kubectl`, `gh`) require your explicit confirmation before running.

## Prerequisites

- An Azure subscription (Owner or Contributor role)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in (`az login`)
- [Docker](https://docs.docker.com/get-docker/) installed
- [GitHub CLI](https://cli.github.com/) installed (for CI/CD phase)
- One of the supported AI coding agents:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)
  - [GitHub Copilot](https://docs.github.com/en/copilot) (VS Code terminal or `gh copilot`)
  - [OpenCode](https://opencode.ai)

## Installation

### Quick install (all platforms)

```bash
git clone https://github.com/<owner>/deploy-to-aks-skill.git
cd deploy-to-aks-skill
./install.sh
```

The script prompts for your platform and whether to install globally or into a specific project.

---

### Claude Code

**Global install** (available in all your projects):

```bash
git clone https://github.com/<owner>/deploy-to-aks-skill.git
ln -s "$(pwd)/deploy-to-aks-skill/skills/deploy-to-aks" ~/.claude/skills/deploy-to-aks
```

**Project install** (available only in one project):

```bash
# From your project root:
mkdir -p .claude/skills
cp -r /path/to/deploy-to-aks-skill/skills/deploy-to-aks .claude/skills/deploy-to-aks
```

---

### GitHub Copilot

Copilot does not have a global skill system. Install into each project that needs it:

```bash
# From your project root:
mkdir -p .github/skills
cp -r /path/to/deploy-to-aks-skill/skills/deploy-to-aks .github/skills/deploy-to-aks
```

Then create or append to `.github/copilot-instructions.md`:

```markdown
## AKS Deployment Skill

When the developer asks for help deploying to Azure Kubernetes Service (AKS),
follow the phased deployment guide in `.github/skills/deploy-to-aks/SKILL.md`.

Start by reading that file, then follow its instructions phase by phase.
Do not skip phases or reorder them.
```

---

### OpenCode

**Global install** (available in all your projects):

```bash
git clone https://github.com/<owner>/deploy-to-aks-skill.git
mkdir -p ~/.config/opencode/skills
ln -s "$(pwd)/deploy-to-aks-skill/skills/deploy-to-aks" ~/.config/opencode/skills/deploy-to-aks
```

**Project install** (available only in one project):

```bash
# From your project root:
mkdir -p .opencode/skills
ln -s /path/to/deploy-to-aks-skill/skills/deploy-to-aks .opencode/skills/deploy-to-aks
```

---

### Verify installation

Start your agent in the target project and ask:

```
What skills are available?
```

You should see `deploy-to-aks` in the list (Claude Code and OpenCode). For Copilot, the skill loads automatically from the instructions file — ask "help me deploy to AKS" to verify it activates.

## Usage

Navigate to the project you want to deploy and ask your agent:

```
Help me deploy this app to AKS
```

| Platform | How to invoke |
|----------|--------------|
| **Claude Code** | `/deploy-to-aks` or ask naturally: "help me deploy to AKS" |
| **GitHub Copilot** | Ask naturally: "help me deploy to AKS" (no slash command) |
| **OpenCode** | `/deploy-to-aks` or ask naturally: "help me deploy to AKS" |

The skill walks you through all 6 phases interactively. You approve the architecture and cost estimate before any resources are created.

## What it generates

- **Dockerfile** — multi-stage, non-root, optimized for your framework
- **Kubernetes manifests** — Deployment, Service, Gateway/HTTPRoute or Ingress, HPA, PDB, ServiceAccount
- **Bicep modules** — AKS, ACR, Managed Identity, backing services (PostgreSQL, Redis, Key Vault, etc.)
- **GitHub Actions workflow** — build, push, deploy with OIDC authentication

## Supported frameworks

Node.js (Express, Fastify, Next.js, Nest), Python (Flask, FastAPI, Django), Java (Spring Boot, Quarkus), Go (Gin, Echo, Fiber), .NET (ASP.NET), Rust

## AKS flavors

- **AKS Automatic** (default) — fully managed, Gateway API, Deployment Safeguards enforced
- **AKS Standard** — more control over node pools, ingress, networking

## Project structure

```
skills/deploy-to-aks/
  SKILL.md                          # Coordinator — entry point
  phases/                           # Per-phase instruction files (01–06)
  reference/                        # AKS domain knowledge docs
  templates/                        # Dockerfile, K8s, Bicep, CI/CD, mermaid templates
  knowledge-packs/frameworks/       # Framework-specific deployment guidance
docs/specs/                         # Design specifications
```

## Status

v1 complete. Tested against [spring-petclinic](https://github.com/spring-projects/spring-petclinic).

## Inspiration

Inspired by [adaptive-ui-try-aks](https://github.com/sabbour/adaptive-ui-try-aks) — a browser-based conversational deployment guide by sabbour. This skill brings the same concept to the terminal with the added power of real codebase intelligence, direct CLI execution, and zero-setup integration.

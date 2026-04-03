![deploy-to-aks](docs/images/banner.svg)

[![Claude Code](https://img.shields.io/badge/Claude_Code-supported-22c55e?logo=anthropic&logoColor=white)](https://docs.anthropic.com/en/docs/claude-code/overview)
[![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-supported-22c55e?logo=github&logoColor=white)](https://docs.github.com/en/copilot)
[![OpenCode](https://img.shields.io/badge/OpenCode-supported-22c55e)](https://opencode.ai)

A conversational AI skill that reads your project, generates production-ready deployment artifacts, and deploys to AKS — all from your terminal. No Kubernetes expertise required.

## How it works

```mermaid
graph LR
    A["🔍 Discover"] --> B["📋 Architect"] --> C["📦 Containerize"] --> D["🔧 Scaffold"] --> E["⚙️ Pipeline"] --> F["🚀 Deploy"]
```

| | Phase | What happens |
|---|---|---|
| 🔍 | **Discover** | Scans your project, detects framework and dependencies |
| 📋 | **Architect** | Plans infrastructure, shows architecture diagram + cost estimate |
| 📦 | **Containerize** | Generates production-ready Dockerfile + .dockerignore |
| 🔧 | **Scaffold** | Generates K8s manifests + Bicep IaC, validates against safeguards |
| ⚙️ | **Pipeline** | Creates GitHub Actions CI/CD with OIDC auth |
| 🚀 | **Deploy** | Executes deployment with confirmation gates, shows summary dashboard |

File generation is automatic. CLI commands (`az`, `docker`, `kubectl`, `gh`) require your explicit confirmation before running.

## What it generates

```
your-project/
├── Dockerfile                  # Multi-stage, non-root, optimized
├── .dockerignore
├── k8s/
│   ├── deployment.yaml         # Resource limits, probes, security context
│   ├── service.yaml            # ClusterIP
│   ├── gateway.yaml            # Gateway API (Automatic) or Ingress (Standard)
│   ├── httproute.yaml
│   ├── hpa.yaml                # Horizontal Pod Autoscaler
│   ├── pdb.yaml                # Pod Disruption Budget
│   └── serviceaccount.yaml     # Workload Identity
├── infra/
│   ├── main.bicep              # Orchestrator
│   ├── aks.bicep               # AKS cluster
│   ├── acr.bicep               # Container Registry
│   ├── identity.bicep          # Managed Identity + federation
│   └── postgres.bicep          # ...and any backing services
└── .github/workflows/
    └── deploy.yml              # Build → push → deploy with OIDC
```

✅ All manifests pass **AKS Deployment Safeguards** out of the box
✅ Dockerfiles follow multi-stage, non-root, layer-cached best practices
✅ CI/CD uses OIDC federation — no stored secrets
✅ Adapts to your stack — detects what exists before generating

## Installation

```bash
git clone https://github.com/<owner>/deploy-to-aks-skill.git
cd deploy-to-aks-skill
./install.sh
```

The script prompts for your platform and whether to install globally or into a specific project.

<details>

<summary>Manual install — Claude Code</summary>

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

</details>

<details>

<summary>Manual install — GitHub Copilot</summary>

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

</details>

<details>

<summary>Manual install — OpenCode</summary>

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
cp -r /path/to/deploy-to-aks-skill/skills/deploy-to-aks .opencode/skills/deploy-to-aks
```

</details>

**Verify installation:** Start your agent in the target project and ask `What skills are available?` — you should see `deploy-to-aks` in the list. For Copilot, ask "help me deploy to AKS" to verify it activates.

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

## See it in action

<!-- TODO: Add terminal recording (asciinema SVG or GIF) showing the skill deploying spring-petclinic -->
<!-- Record with: asciinema rec docs/images/demo.cast -->
<!-- Convert with: agg docs/images/demo.cast docs/images/demo.gif --theme monokai -->

*Demo recording coming soon — a 60-second walkthrough from `Help me deploy this app to AKS` to a running application.*

## Supported frameworks

Node.js (Express, Fastify, Next.js, Nest) · Python (Flask, FastAPI, Django) · Java (Spring Boot, Quarkus) · Go (Gin, Echo, Fiber) · .NET (ASP.NET) · Rust

## AKS flavors

- **AKS Automatic** (default) — fully managed, Gateway API, Deployment Safeguards enforced
- **AKS Standard** — more control over node pools, ingress, networking

## Prerequisites

- An Azure subscription (Owner or Contributor role)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in (`az login`)
- [Docker](https://docs.docker.com/get-docker/) installed
- [GitHub CLI](https://cli.github.com/) installed (for CI/CD phase)
- One of the supported AI coding agents:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview)
  - [GitHub Copilot](https://docs.github.com/en/copilot) (VS Code terminal or `gh copilot`)
  - [OpenCode](https://opencode.ai)

## Inspiration

Inspired by [adaptive-ui-try-aks](https://github.com/sabbour/adaptive-ui-try-aks) — a browser-based conversational deployment guide by sabbour. This skill brings the same concept to the terminal with the added power of real codebase intelligence, direct CLI execution, and zero-setup integration.

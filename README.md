# deploy-to-aks-skill

An OpenCode skill that guides developers through deploying their applications to Azure Kubernetes Service (AKS) — no Kubernetes expertise required.

## What is this?

A conversational, phased deployment guide that runs inside [OpenCode](https://opencode.ai). It reads your actual project, detects your framework and dependencies, generates production-ready deployment artifacts, and optionally executes the deployment — all from your terminal.

## How it works

The skill walks you through 6 phases:

| Phase | Name | What happens |
|-------|------|-------------|
| 1 | **Discover** | Scans your project, detects framework/language/dependencies, asks clarifying questions |
| 2 | **Architect** | Plans infrastructure, shows architecture diagram + cost estimate, gets your approval |
| 3 | **Containerize** | Generates or validates Dockerfile + .dockerignore |
| 4 | **Scaffold** | Generates K8s manifests + Bicep IaC, validates against AKS Deployment Safeguards |
| 5 | **Pipeline** | Generates GitHub Actions CI/CD workflow, optionally sets up OIDC federation |
| 6 | **Deploy** | Executes deployment commands (with confirmation at each step), shows summary dashboard |

## What it generates

- **Dockerfile** — multi-stage, non-root, optimized for your framework
- **Kubernetes manifests** — Deployment, Service, Gateway/HTTPRoute, HPA, PDB, ServiceAccount
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

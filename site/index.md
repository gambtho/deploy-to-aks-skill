---
layout: home

hero:
  name: deploy-to-aks
  text: Deploy to AKS from your terminal
  tagline: A conversational AI skill that reads your project, generates production-ready artifacts, and deploys to Azure Kubernetes Service - no Kubernetes expertise required.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/phases
    - theme: alt
      text: View on GitHub
      link: https://github.com/gambtho/deploy-to-aks-skill

features:
  - icon: 🔍
    title: Discover
    details: Scans your project, detects framework and dependencies automatically
  - icon: 📋
    title: Architect
    details: Plans infrastructure, shows architecture diagram with cost estimates
  - icon: 📦
    title: Containerize
    details: Generates production-ready Dockerfile with multi-stage builds
  - icon: 🔧
    title: Scaffold
    details: Creates K8s manifests and Bicep IaC, validates against safeguards
  - icon: ⚙️
    title: Pipeline
    details: Sets up GitHub Actions CI/CD with OIDC authentication
  - icon: 🚀
    title: Deploy
    details: Executes deployment with confirmation gates and summary dashboard
---

## Platform Support

<div class="platform-badges">
  <a href="https://docs.anthropic.com/en/docs/claude-code/overview" class="platform-badge">
    <span>✨</span>
    <span>Claude Code</span>
  </a>
  <a href="https://docs.github.com/en/copilot" class="platform-badge">
    <span>🐙</span>
    <span>GitHub Copilot</span>
  </a>
  <a href="https://opencode.ai" class="platform-badge">
    <span>🚀</span>
    <span>OpenCode</span>
  </a>
</div>

## Quick Start

Install with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/gambtho/deploy-to-aks-skill/main/install.sh | bash
```

Then from your project directory:

```bash
# Ask your AI agent:
Help me deploy this app to AKS
```

The skill walks you through all 6 phases interactively. You approve the architecture and cost estimate before any resources are created.

## What It Generates

Production-ready artifacts tailored to your stack:

- **Dockerfile** - Multi-stage, non-root, layer-cached
- **Kubernetes manifests** - Deployment, Service, Gateway/Ingress, HPA, PDB
- **Bicep infrastructure** - AKS cluster, ACR, Managed Identity, backing services
- **GitHub Actions workflow** - Build → Push → Deploy with OIDC (no stored secrets)

All manifests pass [AKS Deployment Safeguards](https://learn.microsoft.com/en-us/azure/aks/deployment-safeguards) out of the box.

## Framework Support

<div class="feature-cards">
  <div class="feature-card">
    <h3><span class="icon">☕</span> Java</h3>
    <p>Spring Boot, Quarkus</p>
  </div>
  <div class="feature-card">
    <h3><span class="icon">🐍</span> Python</h3>
    <p>FastAPI, Django, Flask</p>
  </div>
  <div class="feature-card">
    <h3><span class="icon">📗</span> Node.js</h3>
    <p>Express, Fastify, Next.js, NestJS</p>
  </div>
  <div class="feature-card">
    <h3><span class="icon">🔷</span> .NET</h3>
    <p>ASP.NET Core</p>
  </div>
  <div class="feature-card">
    <h3><span class="icon">🔵</span> Go</h3>
    <p>Gin, Echo, Fiber, stdlib</p>
  </div>
  <div class="feature-card">
    <h3><span class="icon">🦀</span> Rust</h3>
    <p>Actix, Axum</p>
  </div>
</div>

**9 knowledge packs** provide deeper guidance for popular frameworks - optimized Dockerfiles, health endpoints, database config, and AKS-specific troubleshooting.

## Why deploy-to-aks?

<div class="feature-cards">
  <div class="feature-card">
    <h3>✅ Production-Ready</h3>
    <p>All generated artifacts follow AKS best practices and pass Deployment Safeguards automatically.</p>
  </div>
  <div class="feature-card">
    <h3>🔒 Secure by Default</h3>
    <p>OIDC federation means no stored secrets. Workload Identity for pod-to-Azure authentication.</p>
  </div>
  <div class="feature-card">
    <h3>📚 Educational</h3>
    <p>Every step is explained. Learn AKS concepts while deploying your app.</p>
  </div>
  <div class="feature-card">
    <h3>🎯 Zero Lock-In</h3>
    <p>Generates standard Kubernetes YAML and Bicep. No proprietary formats or abstractions.</p>
  </div>
  <div class="feature-card">
    <h3>⚡ Fast Iteration</h3>
    <p>Quick deploy mode for existing clusters - containerize and deploy in ~5-7 minutes.</p>
  </div>
  <div class="feature-card">
    <h3>🔄 Multi-Platform</h3>
    <p>Works with Claude Code, GitHub Copilot, and OpenCode - use your preferred agent.</p>
  </div>
</div>

## AKS Flavors

Supports both **AKS Automatic** (fully managed, Gateway API, safeguards enforced) and **AKS Standard** (more control over node pools, ingress, networking).

[Learn about AKS flavors →](/guide/aks-flavors)

## Next Steps

- [Read the 6-phase workflow guide](/guide/phases)
- [Try quick deploy mode](/guide/quick-mode)
- [Explore example artifacts](/examples/)
- [View on GitHub](https://github.com/gambtho/deploy-to-aks-skill)

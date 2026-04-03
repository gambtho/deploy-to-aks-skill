# Multi-Platform Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the deploy-to-aks skill work with full parity on Claude Code, GitHub Copilot, and OpenCode by neutralizing platform-specific references and adding per-platform installation instructions.

**Architecture:** Single canonical source at `skills/deploy-to-aks/` with platform-neutral instructions. An install script copies/symlinks files to the correct location per platform. README provides manual installation steps for each platform.

**Tech Stack:** Bash (install script), Markdown (all skill content)

**Spec:** `docs/specs/2026-04-02-multi-platform-support-design.md`

---

### Task 1: Neutralize platform-specific language in SKILL.md

**Files:**
- Modify: `skills/deploy-to-aks/SKILL.md:12` (checklist instruction)
- Modify: `skills/deploy-to-aks/SKILL.md:95-101` (housekeeping section)

- [ ] **Step 1: Update the checklist instruction**

In `skills/deploy-to-aks/SKILL.md`, change line 12 from:

```
You MUST create a todo for each of these items and complete them in order:
```

to:

```
You MUST track each of these items as a checklist and complete them in order:
```

- [ ] **Step 2: Update the housekeeping section**

In `skills/deploy-to-aks/SKILL.md`, replace lines 95-101 from:

```markdown
At any point during execution, if the project has a `.gitignore`, check whether agent working directories are excluded. Add entries for any that are missing:

\```
# Agent working directories
.claude/
.superpowers/
\```

These directories contain session-specific data and should never be committed to the repository.
```

to:

```markdown
At any point during execution, if the project has a `.gitignore`, check whether your agent working directory is excluded (e.g., `.claude/`, `.superpowers/`, `.opencode/`). If not, add it. These directories contain session-specific data and should never be committed to the repository.
```

- [ ] **Step 3: Verify no other platform-specific references remain in SKILL.md**

Read `skills/deploy-to-aks/SKILL.md` and confirm no references to "OpenCode", "Glob", "subagent", "TodoWrite", or specific platform directories remain.

- [ ] **Step 4: Commit**

```bash
git add skills/deploy-to-aks/SKILL.md
git commit -m "fix: neutralize platform-specific language in SKILL.md"
```

---

### Task 2: Neutralize platform-specific language in phase files

**Files:**
- Modify: `skills/deploy-to-aks/phases/01-discover.md:13`
- Modify: `skills/deploy-to-aks/phases/05-pipeline.md:17`

- [ ] **Step 1: Update Phase 1 subagent reference**

In `skills/deploy-to-aks/phases/01-discover.md`, change line 13 from:

```
Dispatch an **explore subagent** to scan the project root. The subagent must collect all of the following categories in a single pass.
```

to:

```
Scan the project root thoroughly. Collect all of the following categories in a single pass.
```

- [ ] **Step 2: Update Phase 5 Glob tool reference**

In `skills/deploy-to-aks/phases/05-pipeline.md`, change line 17 from:

```
Use Glob to find `**/.github/workflows/*.yml` and `**/.github/workflows/*.yaml`. Read any matches and summarize what they do before proceeding.
```

to:

```
Search for existing workflow files matching `**/.github/workflows/*.yml` and `**/.github/workflows/*.yaml`. Read any matches and summarize what they do before proceeding.
```

- [ ] **Step 3: Verify no other platform-specific references remain in phase files**

Read all six phase files and confirm no references to "OpenCode", "Glob", "subagent", "TodoWrite", or specific platform tool names remain. The words "Read" and "Write" used as generic verbs (e.g., "Read the file", "Write the final manifest") are fine — they are natural English, not tool names.

- [ ] **Step 4: Commit**

```bash
git add skills/deploy-to-aks/phases/01-discover.md skills/deploy-to-aks/phases/05-pipeline.md
git commit -m "fix: neutralize platform-specific tool references in phase files"
```

---

### Task 3: Update AGENTS.md

**Files:**
- Modify: `AGENTS.md:5` (project overview)
- Modify: `AGENTS.md:46` (testing section)

- [ ] **Step 1: Update project overview**

In `AGENTS.md`, change line 5 from:

```
This repository contains the **deploy-to-aks** OpenCode skill — a phased, conversational guide that deploys web applications to Azure Kubernetes Service (AKS) without requiring Kubernetes expertise. It is not a runnable application; it is a collection of markdown instruction files, reference documents, and templates consumed by an AI coding agent at runtime.
```

to:

```
This repository contains the **deploy-to-aks** AI coding agent skill — a phased, conversational guide that deploys web applications to Azure Kubernetes Service (AKS) without requiring Kubernetes expertise. It supports Claude Code, GitHub Copilot, and OpenCode. It is not a runnable application; it is a collection of markdown instruction files, reference documents, and templates consumed by an AI coding agent at runtime.
```

- [ ] **Step 2: Update testing section**

In `AGENTS.md`, change line 46 from:

```
There are no automated tests. The skill is validated by running it against real projects (e.g., `spring-petclinic`) inside OpenCode and verifying the generated artifacts are correct and the phases flow properly. When making changes, mentally trace through the 6-phase flow to ensure consistency.
```

to:

```
There are no automated tests. The skill is validated by running it against real projects (e.g., `spring-petclinic`) inside any supported agent (Claude Code, GitHub Copilot, or OpenCode) and verifying the generated artifacts are correct and the phases flow properly. When making changes, mentally trace through the 6-phase flow to ensure consistency.
```

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "fix: make AGENTS.md platform-neutral"
```

---

### Task 4: Rewrite README.md

**Files:**
- Modify: `README.md` (complete rewrite)

- [ ] **Step 1: Write the new README**

Replace the entire contents of `README.md` with:

```markdown
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
```

- [ ] **Step 2: Read back and verify**

Read `README.md` and verify:
- No references to a single platform as the only option
- All three platforms have installation sections with correct paths
- Usage table shows all three platforms
- Prerequisites list all three agents

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for multi-platform support"
```

---

### Task 5: Create install.sh

**Files:**
- Create: `install.sh`

- [ ] **Step 1: Write the install script**

Create `install.sh` at the repo root with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# deploy-to-aks skill installer
# Installs the skill for Claude Code, GitHub Copilot, or OpenCode.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/skills/deploy-to-aks"

# --- Helpers ---

die() { echo "Error: $1" >&2; exit 1; }

info() { echo "==> $1"; }

prompt_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    echo ""
    echo "$prompt"
    for i in "${!options[@]}"; do
        echo "  $((i + 1))) ${options[$i]}"
    done
    while true; do
        read -rp "Choice [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            return $((choice - 1))
        fi
        echo "Invalid choice. Enter a number between 1 and ${#options[@]}."
    done
}

# --- Validation ---

if [[ ! -f "$SKILL_SOURCE/SKILL.md" ]]; then
    die "Cannot find skills/deploy-to-aks/SKILL.md. Run this script from the repo root."
fi

# --- Parse flags ---

PLATFORM=""
SCOPE=""
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform) PLATFORM="$2"; shift 2 ;;
        --scope) SCOPE="$2"; shift 2 ;;
        --project-dir) PROJECT_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: ./install.sh [--platform claude-code|copilot|opencode] [--scope global|project] [--project-dir <path>]"
            echo ""
            echo "Interactive mode: run without flags to be prompted."
            exit 0
            ;;
        *) die "Unknown flag: $1. Use --help for usage." ;;
    esac
done

# --- Interactive prompts (if flags not provided) ---

if [[ -z "$PLATFORM" ]]; then
    prompt_choice "Which platform?" "Claude Code" "GitHub Copilot" "OpenCode"
    case $? in
        0) PLATFORM="claude-code" ;;
        1) PLATFORM="copilot" ;;
        2) PLATFORM="opencode" ;;
    esac
fi

# Validate platform
case "$PLATFORM" in
    claude-code|copilot|opencode) ;;
    *) die "Unknown platform: $PLATFORM. Use claude-code, copilot, or opencode." ;;
esac

# Copilot has no global scope
if [[ "$PLATFORM" == "copilot" && "$SCOPE" == "global" ]]; then
    die "GitHub Copilot does not support global skills. Use --scope project instead."
fi

if [[ -z "$SCOPE" ]]; then
    if [[ "$PLATFORM" == "copilot" ]]; then
        info "GitHub Copilot only supports project-level installation."
        SCOPE="project"
    else
        prompt_choice "Install scope?" "Global (available in all projects)" "Project (install into a specific project)"
        case $? in
            0) SCOPE="global" ;;
            1) SCOPE="project" ;;
        esac
    fi
fi

if [[ "$SCOPE" == "project" && -z "$PROJECT_DIR" ]]; then
    read -rp "Project directory [$(pwd)]: " PROJECT_DIR
    PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
fi

if [[ "$SCOPE" == "project" && ! -d "$PROJECT_DIR" ]]; then
    die "Directory does not exist: $PROJECT_DIR"
fi

# --- Install ---

case "$PLATFORM" in
    claude-code)
        if [[ "$SCOPE" == "global" ]]; then
            TARGET="$HOME/.claude/skills/deploy-to-aks"
            mkdir -p "$(dirname "$TARGET")"
            if [[ -e "$TARGET" ]]; then
                info "Existing installation found at $TARGET"
                read -rp "Replace it? [y/N]: " confirm
                [[ "$confirm" =~ ^[yY]$ ]] || { info "Aborted."; exit 0; }
                rm -rf "$TARGET"
            fi
            ln -s "$SKILL_SOURCE" "$TARGET"
            info "Symlinked $SKILL_SOURCE → $TARGET"
            echo ""
            echo "Done! Start Claude Code in any project and use:"
            echo "  /deploy-to-aks"
            echo "  or ask: \"help me deploy to AKS\""
        else
            TARGET="$PROJECT_DIR/.claude/skills/deploy-to-aks"
            mkdir -p "$(dirname "$TARGET")"
            if [[ -e "$TARGET" ]]; then
                info "Existing installation found at $TARGET"
                read -rp "Replace it? [y/N]: " confirm
                [[ "$confirm" =~ ^[yY]$ ]] || { info "Aborted."; exit 0; }
                rm -rf "$TARGET"
            fi
            cp -r "$SKILL_SOURCE" "$TARGET"
            info "Copied skill to $TARGET"
            echo ""
            echo "Done! Start Claude Code in $PROJECT_DIR and use:"
            echo "  /deploy-to-aks"
            echo "  or ask: \"help me deploy to AKS\""
        fi
        ;;

    copilot)
        SKILL_TARGET="$PROJECT_DIR/.github/skills/deploy-to-aks"
        INSTRUCTIONS_FILE="$PROJECT_DIR/.github/copilot-instructions.md"
        INSTRUCTION_BLOCK='## AKS Deployment Skill

When the developer asks for help deploying to Azure Kubernetes Service (AKS),
follow the phased deployment guide in `.github/skills/deploy-to-aks/SKILL.md`.

Start by reading that file, then follow its instructions phase by phase.
Do not skip phases or reorder them.'

        # Copy skill directory
        mkdir -p "$(dirname "$SKILL_TARGET")"
        if [[ -e "$SKILL_TARGET" ]]; then
            info "Existing skill directory found at $SKILL_TARGET"
            read -rp "Replace it? [y/N]: " confirm
            [[ "$confirm" =~ ^[yY]$ ]] || { info "Aborted."; exit 0; }
            rm -rf "$SKILL_TARGET"
        fi
        cp -r "$SKILL_SOURCE" "$SKILL_TARGET"
        info "Copied skill to $SKILL_TARGET"

        # Create/append copilot-instructions.md
        if [[ -f "$INSTRUCTIONS_FILE" ]]; then
            if grep -q "AKS Deployment Skill" "$INSTRUCTIONS_FILE" 2>/dev/null; then
                info "copilot-instructions.md already contains AKS deployment reference. Skipping."
            else
                echo ""
                info "Appending to existing $INSTRUCTIONS_FILE:"
                echo "---"
                echo "$INSTRUCTION_BLOCK"
                echo "---"
                read -rp "Proceed? [y/N]: " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    printf '\n%s\n' "$INSTRUCTION_BLOCK" >> "$INSTRUCTIONS_FILE"
                    info "Appended instruction block."
                else
                    info "Skipped. You can manually add the instruction block to $INSTRUCTIONS_FILE."
                fi
            fi
        else
            mkdir -p "$(dirname "$INSTRUCTIONS_FILE")"
            printf '%s\n' "$INSTRUCTION_BLOCK" > "$INSTRUCTIONS_FILE"
            info "Created $INSTRUCTIONS_FILE"
        fi

        echo ""
        echo "Done! Open Copilot in $PROJECT_DIR and ask:"
        echo "  \"help me deploy to AKS\""
        echo ""
        echo "Note: GitHub Copilot does not support slash commands for custom skills."
        echo "The skill activates when you ask about AKS deployment."
        ;;

    opencode)
        if [[ "$SCOPE" == "global" ]]; then
            TARGET="$HOME/.config/opencode/skills/deploy-to-aks"
            mkdir -p "$(dirname "$TARGET")"
            if [[ -e "$TARGET" ]]; then
                info "Existing installation found at $TARGET"
                read -rp "Replace it? [y/N]: " confirm
                [[ "$confirm" =~ ^[yY]$ ]] || { info "Aborted."; exit 0; }
                rm -rf "$TARGET"
            fi
            ln -s "$SKILL_SOURCE" "$TARGET"
            info "Symlinked $SKILL_SOURCE → $TARGET"
            echo ""
            echo "Done! Start OpenCode in any project and use:"
            echo "  /deploy-to-aks"
            echo "  or ask: \"help me deploy to AKS\""
        else
            TARGET="$PROJECT_DIR/.opencode/skills/deploy-to-aks"
            mkdir -p "$(dirname "$TARGET")"
            if [[ -e "$TARGET" ]]; then
                info "Existing installation found at $TARGET"
                read -rp "Replace it? [y/N]: " confirm
                [[ "$confirm" =~ ^[yY]$ ]] || { info "Aborted."; exit 0; }
                rm -rf "$TARGET"
            fi
            ln -s "$SKILL_SOURCE" "$TARGET"
            info "Symlinked $SKILL_SOURCE → $TARGET"
            echo ""
            echo "Done! Start OpenCode in $PROJECT_DIR and use:"
            echo "  /deploy-to-aks"
            echo "  or ask: \"help me deploy to AKS\""
        fi
        ;;
esac
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x install.sh`

- [ ] **Step 3: Test the script shows help**

Run: `./install.sh --help`

Expected output:
```
Usage: ./install.sh [--platform claude-code|copilot|opencode] [--scope global|project] [--project-dir <path>]

Interactive mode: run without flags to be prompted.
```

- [ ] **Step 4: Test validation check**

Run from a temp directory (not repo root): `cd /tmp && /path/to/install.sh --platform claude-code --scope global`

Expected: Error message about not finding `skills/deploy-to-aks/SKILL.md`.

- [ ] **Step 5: Commit**

```bash
git add install.sh
git commit -m "feat: add multi-platform install script"
```

---

### Task 6: Update .gitignore

**Files:**
- Modify: `.gitignore:7-8`

- [ ] **Step 1: Update the superpowers comment and add agent directories**

In `.gitignore`, replace lines 7-8 from:

```
# Superpowers brainstorming sessions
.superpowers/
```

to:

```
# Agent working directories
.superpowers/
.claude/
.opencode/
```

- [ ] **Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add all agent working directories to .gitignore"
```

---

### Task 7: Final verification

- [ ] **Step 1: Search for remaining "OpenCode" references in skill files**

Search `skills/deploy-to-aks/` for the string "OpenCode" (case-insensitive). Expected: zero matches.

- [ ] **Step 2: Search for remaining platform-specific tool names in skill files**

Search `skills/deploy-to-aks/` for "Glob", "subagent", "TodoWrite". Expected: zero matches for all three.

- [ ] **Step 3: Verify README references all three platforms**

Read `README.md` and confirm "Claude Code", "GitHub Copilot", and "OpenCode" all appear in the installation section.

- [ ] **Step 4: Verify AGENTS.md is platform-neutral**

Read `AGENTS.md` and confirm no single-platform bias. "OpenCode" should only appear in the list of supported agents, not as the sole platform.

- [ ] **Step 5: Verify install.sh is executable and has correct shebang**

Run: `ls -la install.sh` — confirm `-rwxr-xr-x` permissions and `#!/usr/bin/env bash` shebang.

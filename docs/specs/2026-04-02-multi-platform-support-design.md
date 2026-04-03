# Multi-Platform Support for deploy-to-aks Skill — Design Spec

**Date:** 2026-04-02
**Status:** Draft
**Goal:** Make the deploy-to-aks skill work with full parity on Claude Code, GitHub Copilot, and OpenCode, with clear installation instructions for each platform.

---

## Context

The deploy-to-aks skill was originally built for OpenCode. It contains several platform-specific references (tool names like `Glob`, concepts like "explore subagent", directories like `.claude/` and `.superpowers/`) and has no installation documentation beyond OpenCode.

The skill needs to run on three terminal-based AI coding agents:

| Platform | Instruction mechanism | Skill system | Invocation |
|----------|----------------------|--------------|------------|
| **Claude Code** | `CLAUDE.md`, `.claude/rules/` | `.claude/skills/<name>/SKILL.md` with YAML frontmatter | `/skill-name` or auto-invocation |
| **GitHub Copilot** | `AGENTS.md`, `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md` | No formal skill system — instructions injected into context | Natural language only (no slash commands) |
| **OpenCode** | `AGENTS.md`, custom skill directories | `skills/<name>/SKILL.md` with YAML frontmatter | `/skill-name` or natural language |

Key insight: all three platforms can follow markdown instructions and read files from the repository. The skill content is already mostly platform-neutral — only ~5 spots reference specific tool names. The main work is (a) neutralizing those references, (b) creating installation paths for each platform, and (c) documenting everything clearly.

## Approach

**Single canonical source + per-platform installation.** One set of platform-neutral skill files serves all platforms. An install script (and manual instructions) copies files to the correct location per platform.

This was chosen over platform-specific variants (higher maintenance) and adapter wrappers (fragile indirection). It naturally evolves into registry/package distribution later.

---

## 1. Skill Content Changes

Five edits to make instructions platform-neutral using generic action verbs:

### 1a. Phase 1 — `phases/01-discover.md` line 13

**Current:**
```
Dispatch an **explore subagent** to scan the project root. The subagent must collect all of the following categories in a single pass.
```

**Proposed:**
```
Scan the project root thoroughly. Collect all of the following categories in a single pass.
```

**Rationale:** "Scan" is an action any agent can perform. Claude Code may use a subagent; Copilot will search files directly. The outcome is the same.

### 1b. Phase 5 — `phases/05-pipeline.md` line 17

**Current:**
```
Use Glob to find **/.github/workflows/*.yml and **/.github/workflows/*.yaml. Read any matches and summarize what they do before proceeding.
```

**Proposed:**
```
Search for existing workflow files matching **/.github/workflows/*.yml and **/.github/workflows/*.yaml. Read any matches and summarize what they do before proceeding.
```

**Rationale:** "Search for files matching" is a generic instruction. Every agent has file search capability.

### 1c. SKILL.md line 12

**Current:**
```
You MUST create a todo for each of these items and complete them in order:
```

**Proposed:**
```
You MUST track each of these items as a checklist and complete them in order:
```

**Rationale:** "Checklist" is a universal concept. Claude Code and OpenCode will use their TodoWrite mechanisms; Copilot will track progress however it can.

### 1d. SKILL.md lines 99-100 (housekeeping section)

**Current:**
```
.claude/
.superpowers/
```

**Proposed:**
```
Add your agent's working directory to .gitignore if not already present (e.g., .claude/, .superpowers/, .opencode/).
```

**Rationale:** Platform-neutral guidance that covers current and future agents.

### 1e. No change to "Read"/"Write" in phase files

Phrases like "Read the file", "Write the final manifest" are natural English that any agent interprets correctly. No changes needed.

### Not changing: docs/specs/

The existing design spec and implementation plan are historical documents recording decisions made during initial development. They reference OpenCode because that was the target at the time. Changing them would be revisionist. They remain as-is.

---

## 2. Repository Structure

```
deploy-to-aks-skill/
  README.md                         # Rewritten: multi-platform install guide
  AGENTS.md                         # Updated: platform-neutral project description
  install.sh                        # NEW: interactive install script
  .gitignore                        # Updated: keep .superpowers/, no other changes
  skills/
    deploy-to-aks/                  # Canonical source (unchanged location)
      SKILL.md                      # 2 edits (1c, 1d above)
      phases/
        01-discover.md              # 1 edit (1a above)
        02-architect.md             # Unchanged
        03-containerize.md          # Unchanged
        04-scaffold.md              # Unchanged
        05-pipeline.md              # 1 edit (1b above)
        06-deploy.md                # Unchanged
      reference/                    # Unchanged
      templates/                    # Unchanged
      knowledge-packs/              # Unchanged
  docs/
    specs/                          # Unchanged (historical)
```

**New file:** `install.sh` at the repo root.

**No new directories.** No adapters, no platform variants, no build step.

---

## 3. README.md

Complete rewrite. Structure:

```
# deploy-to-aks

Brief platform-neutral description.

## What it does
6-phase flow overview.

## Prerequisites
- Azure subscription (Owner or Contributor)
- Azure CLI installed and logged in
- Docker installed
- GitHub repository (for CI/CD phase)
- One of: Claude Code, GitHub Copilot, or OpenCode

## Installation

### Quick install (all platforms)
  git clone / ./install.sh

### Claude Code
  Manual steps for global (~/.claude/skills/) and project-local (.claude/skills/).

### GitHub Copilot
  Manual steps: copy skill dir + create .github/copilot-instructions.md.

### OpenCode
  Manual steps for global (~/.config/opencode/skills/) and project-local.

## Usage
  Per-platform invocation examples with expected behavior.

## How it works
  Phase overview with what each phase produces.

## Project structure
  Directory tree for contributors.
```

---

## 4. AGENTS.md

Update the contributor guide to be platform-neutral:

- Replace "OpenCode skill" → "AI coding agent skill" in the project overview
- Replace "inside OpenCode" → "inside any supported agent (Claude Code, GitHub Copilot, or OpenCode)" in the testing section
- Keep all editing guidelines, commit conventions, and structure documentation as-is

---

## 5. Install Script (`install.sh`)

### Interface

```bash
./install.sh [--platform claude-code|copilot|opencode] [--scope global|project] [--project-dir <path>]
```

Interactive mode (no flags) prompts for platform and scope.

### Behavior

1. **Verify** the script is run from the repo root (checks for `skills/deploy-to-aks/SKILL.md`).

2. **Prompt or accept** platform choice: `claude-code`, `copilot`, `opencode`.

3. **Prompt or accept** scope: `global` or `project`.
   - For `project` scope, prompt for target project directory (defaults to current directory).
   - For Copilot + global: warn that Copilot has no global skill system and suggest project scope.

4. **Execute:**

   | Platform | Global | Project |
   |----------|--------|---------|
   | Claude Code | Symlink `<repo>/skills/deploy-to-aks` → `~/.claude/skills/deploy-to-aks` | Copy `<repo>/skills/deploy-to-aks/` → `<project>/.claude/skills/deploy-to-aks/` |
   | Copilot | N/A (error with suggestion) | Copy `<repo>/skills/deploy-to-aks/` → `<project>/.github/skills/deploy-to-aks/`. Create/append `<project>/.github/copilot-instructions.md` with reference block. |
   | OpenCode | Symlink `<repo>/skills/deploy-to-aks` → `~/.config/opencode/skills/deploy-to-aks` | Symlink `<repo>/skills/deploy-to-aks` → `<project>/.opencode/skills/deploy-to-aks` |

5. **Print** confirmation message with invocation instructions.

### Design choices

- **Symlink for global** — user gets updates on `git pull`
- **Copy for project** — project is self-contained, works for teammates
- **Copilot global not supported** — platform limitation, documented clearly
- **No sudo required** — all paths are user-writable
- **No file modification without confirmation** — if `copilot-instructions.md` exists, show the proposed addition and ask before appending
- **Idempotent** — re-running detects existing installation and offers to update

---

## 6. Copilot Integration

When installed for Copilot (project scope), two things happen:

### 6a. Skill directory copied

The full `skills/deploy-to-aks/` directory is copied to `.github/skills/deploy-to-aks/` inside the target project. This puts all phases, templates, and references where Copilot can read them.

### 6b. Instruction file created/updated

`.github/copilot-instructions.md` gets this block (appended if file exists):

```markdown
## AKS Deployment Skill

When the developer asks for help deploying to Azure Kubernetes Service (AKS),
follow the phased deployment guide in `.github/skills/deploy-to-aks/SKILL.md`.

Start by reading that file, then follow its instructions phase by phase.
Do not skip phases or reorder them.
```

### Why this works

- Copilot loads `copilot-instructions.md` for every conversation automatically
- The instruction is lightweight (~5 lines) — minimal context cost when not doing AKS work
- Copilot can read any file in the repo, so it follows SKILL.md the same way Claude Code or OpenCode would
- The instruction triggers on natural language ("help me deploy to AKS") rather than slash commands

### Documented limitation

Copilot won't proactively offer the skill the way Claude Code's auto-invocation does. The user must ask about AKS deployment. The README sets this expectation.

---

## What's NOT Changing

- **Templates** (Bicep, Dockerfiles, K8s manifests, GitHub Actions, Mermaid) — already platform-neutral
- **Reference files** (AKS flavors, cost, safeguards, workload identity) — factual documentation, no tool references
- **Knowledge packs** — framework-specific guidance, no tool references
- **Phase structure** — the 6-phase flow is the core value; it stays identical
- **Placeholder conventions** — `<angle-bracket>`, `__DOUBLE_UNDERSCORE__`, Bicep `param`, `{{DOUBLE_CURLY}}` all remain
- **Confirmation gate pattern** — destructive CLI commands still require approval
- **docs/specs/** — historical design documents stay as-is

---

## Future: Package/Plugin Registry

This design naturally evolves toward registry distribution:

- **Claude Code plugins marketplace** — the `.claude/skills/deploy-to-aks/` directory structure already matches the plugin skill format. Packaging is a matter of adding a `plugin.json` manifest.
- **npm / other registries** — the install script logic becomes the `postinstall` step.
- **The canonical `skills/deploy-to-aks/` path stays the source of truth** regardless of distribution method.

No work needed now, but the structure doesn't block any of these paths.

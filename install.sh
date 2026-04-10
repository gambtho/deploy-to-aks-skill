#!/usr/bin/env bash
set -euo pipefail

# deploy-to-aks skill installer
# Installs the skill for Claude Code, GitHub Copilot, or OpenCode.

# Detect if we're running from a cloned repo or piped from curl
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
    # Running from local file
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SKILL_SOURCE="$SCRIPT_DIR/skills/deploy-to-aks"
    PIPED_INSTALL=false
else
    # Running from pipe (curl | bash)
    PIPED_INSTALL=true
    TEMP_DIR="$(mktemp -d)"
    SKILL_SOURCE="$TEMP_DIR/deploy-to-aks-skill/skills/deploy-to-aks"
    
    # Cleanup on exit
    trap 'rm -rf "$TEMP_DIR"' EXIT
fi

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

confirm_replace() {
    local target="$1"
    if [[ -e "$target" ]]; then
        info "Existing installation found at $target"
        read -rp "Replace it? [y/N]: " confirm
        [[ "$confirm" =~ ^[yY]$ ]] || { info "Aborted."; exit 0; }
        rm -rf "$target"
    fi
}

install_skill() {
    local target="$1"
    local method="$2"  # "symlink" or "copy"
    local parent
    parent="$(dirname "$target")"
    mkdir -p "$parent"
    confirm_replace "$target"
    if [[ "$method" == "symlink" ]]; then
        ln -s "$SKILL_SOURCE" "$target"
        info "Symlinked $SKILL_SOURCE → $target"
    else
        cp -r "$SKILL_SOURCE" "$target"
        info "Copied skill to $target"
    fi
}

# --- Validation ---

# If piped install, download the repository first
if [[ "$PIPED_INSTALL" == "true" ]]; then
    info "Downloading deploy-to-aks-skill repository..."
    REPO_URL="https://github.com/gambtho/deploy-to-aks-skill.git"
    
    if command -v git &> /dev/null; then
        git clone --depth 1 "$REPO_URL" "$TEMP_DIR/deploy-to-aks-skill" 2>&1 | grep -v "Cloning into" || true
    else
        die "git is required for installation. Please install git or clone the repository manually."
    fi
    
    if [[ ! -f "$SKILL_SOURCE/SKILL.md" ]]; then
        die "Failed to download skill files. Please try again or use manual installation."
    fi
    info "Download complete."
fi

if [[ ! -f "$SKILL_SOURCE/SKILL.md" ]]; then
    die "Cannot find skills/deploy-to-aks/SKILL.md. Run this script from the repo root."
fi

# --- Parse flags ---

PLATFORM=""
SCOPE=""
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            [[ $# -ge 2 ]] || die "--platform requires a value"
            PLATFORM="$2"; shift 2 ;;
        --scope)
            [[ $# -ge 2 ]] || die "--scope requires a value"
            SCOPE="$2"; shift 2 ;;
        --project-dir)
            [[ $# -ge 2 ]] || die "--project-dir requires a value"
            PROJECT_DIR="$2"; shift 2 ;;
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
    _cwd="$(pwd)"
    read -rp "Project directory [$_cwd]: " PROJECT_DIR
    PROJECT_DIR="${PROJECT_DIR:-$_cwd}"
fi

if [[ "$SCOPE" == "project" && ! -d "$PROJECT_DIR" ]]; then
    die "Directory does not exist: $PROJECT_DIR"
fi

# --- Install ---

case "$PLATFORM" in
    claude-code)
        if [[ "$SCOPE" == "global" ]]; then
            install_skill "$HOME/.claude/skills/deploy-to-aks" "symlink"
        else
            install_skill "$PROJECT_DIR/.claude/skills/deploy-to-aks" "copy"
        fi
        echo ""
        echo "Done! Start Claude Code and use:"
        echo "  /deploy-to-aks"
        echo "  or ask: \"help me deploy to AKS\""
        ;;

    copilot)
        SKILL_TARGET="$PROJECT_DIR/.github/skills/deploy-to-aks"
        INSTRUCTIONS_FILE="$PROJECT_DIR/.github/copilot-instructions.md"
        INSTRUCTION_BLOCK='## AKS Deployment Skill

When the developer asks for help deploying to Azure Kubernetes Service (AKS),
containerizing their application for AKS, generating Kubernetes manifests, or
creating Bicep infrastructure for Azure, follow the phased deployment guide
in `.github/skills/deploy-to-aks/SKILL.md`.

Trigger phrases include:
- "deploy to AKS" / "deploy to Azure Kubernetes Service"
- "containerize this for AKS" / "create a Dockerfile for AKS"
- "generate Kubernetes manifests" / "scaffold K8s for Azure"
- "create Bicep infrastructure" / "set up AKS infrastructure"
- "help me deploy to Azure"

Start by reading `.github/skills/deploy-to-aks/SKILL.md`, then follow its
instructions phase by phase. Do not skip phases or reorder them.'

        install_skill "$SKILL_TARGET" "copy"

        # Create/append copilot-instructions.md
        if [[ -f "$INSTRUCTIONS_FILE" ]]; then
            if grep -q "AKS Deployment Skill" "$INSTRUCTIONS_FILE"; then
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
            install_skill "$HOME/.config/opencode/skills/deploy-to-aks" "symlink"
        else
            install_skill "$PROJECT_DIR/.opencode/skills/deploy-to-aks" "copy"
        fi
        echo ""
        echo "Done! Start OpenCode and use:"
        echo "  /deploy-to-aks"
        echo "  or ask: \"help me deploy to AKS\""
        ;;
esac

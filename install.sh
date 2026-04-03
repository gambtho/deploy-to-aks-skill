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

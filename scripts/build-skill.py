#!/usr/bin/env python3
"""Build monolithic SKILL.copilot.md for Copilot CLI from multi-file skill source."""

import re
import sys
from pathlib import Path


def find_skill_root() -> Path:
    """Find skills/deploy-to-aks/ relative to this script's location."""
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    skill_root = repo_root / "skills" / "deploy-to-aks"
    if not skill_root.is_dir():
        print(f"Error: Skill root not found at {skill_root}", file=sys.stderr)
        sys.exit(1)
    return skill_root


def read_condensed_or_full(skill_root: Path, rel_path: str) -> str:
    """Read .condensed.md variant if it exists, otherwise read the full file."""
    full_path = skill_root / rel_path
    condensed_path = full_path.with_suffix(".condensed.md")
    if condensed_path.is_file():
        return condensed_path.read_text()
    if full_path.is_file():
        return full_path.read_text()
    print(f"Warning: File not found: {rel_path}", file=sys.stderr)
    return ""


def extract_frontmatter(content: str) -> tuple[str, str]:
    """Extract YAML frontmatter and body from markdown content."""
    if content.startswith("---"):
        end = content.index("---", 3)
        frontmatter = content[: end + 3]
        body = content[end + 3 :].strip()
        return frontmatter, body
    return "", content


def fixup_cross_references(content: str) -> str:
    """Replace file-read directives with internal anchor links."""
    replacements = [
        # Phase file references
        (r"`phases/01-discover\.md`", "[Phase 1: Discover](#phase-1-discover)"),
        (r"`phases/02-architect\.md`", "[Phase 2: Architect](#phase-2-architect)"),
        (r"`phases/03-containerize\.md`", "[Phase 3: Containerize](#phase-3-containerize)"),
        (r"`phases/04-scaffold\.md`", "[Phase 4: Scaffold](#phase-4-scaffold)"),
        (r"`phases/05-pipeline\.md`", "[Phase 5: Pipeline](#phase-5-pipeline)"),
        (r"`phases/06-deploy\.md`", "[Phase 6: Deploy](#phase-6-deploy)"),
        (r"`phases/quick-deploy\.md`", "[Quick Deploy](#quick-deploy-instructions)"),
        # Reference file references
        (r"`reference/safeguards\.md`", "[Deployment Safeguards](#reference-deployment-safeguards)"),
        (r"`reference/workload-identity\.md`", "[Workload Identity](#reference-workload-identity)"),
        (r"`reference/cost-reference\.md`", "[Cost Estimation](#reference-cost-estimation)"),
        (r"`reference/aks-automatic\.md`", "[AKS Automatic](#reference-aks-automatic)"),
        (r"`reference/aks-standard\.md`", "[AKS Standard](#reference-aks-standard)"),
        # Template directory references
        (r"`templates/k8s/([^`]+)`", r"[templates/k8s/\1](#templates-kubernetes-manifests)"),
        (r"`templates/dockerfiles/([^`]+)`", r"[templates/dockerfiles/\1](#templates-dockerfiles)"),
        (r"`templates/bicep/([^`]+)`", r"[templates/bicep/\1](#templates-bicep-modules)"),
        (r"`templates/github-actions/([^`]+)`", r"[templates/github-actions/\1](#templates-github-actions)"),
        (r"`templates/mermaid/([^`]+)`", r"[templates/mermaid/\1](#templates-mermaid-diagrams)"),
        # Knowledge pack references
        (
            r"`knowledge-packs/frameworks/([^`]+)\.md`",
            r"the [\1](#knowledge-packs) section below",
        ),
        # Generic "Read <path>" directives
        (r"[Rr]ead `phases/", "See the corresponding phase section ("),
        (r"[Rr]ead `reference/", "See the corresponding reference section ("),
    ]
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)
    return content


def strip_title_if_present(content: str, expected_prefix: str = "# ") -> str:
    """Strip the first line if it's a markdown title (will be replaced by section heading)."""
    lines = content.split("\n")
    if lines and lines[0].startswith(expected_prefix):
        return "\n".join(lines[1:]).strip()
    return content.strip()


def build_monolith(skill_root: Path) -> str:
    """Assemble the monolithic SKILL.md."""
    sections = []

    # 1. Frontmatter from SKILL.md
    skill_md = (skill_root / "SKILL.md").read_text()
    frontmatter, coordinator_body = extract_frontmatter(skill_md)
    sections.append(frontmatter)

    # 2. Title and coordinator body (with cross-refs fixed up)
    sections.append("# Deploy to AKS\n")
    coordinator_body = strip_title_if_present(coordinator_body)
    sections.append(fixup_cross_references(coordinator_body))

    # 3. Quick deploy phase
    quick_content = read_condensed_or_full(skill_root, "phases/quick-deploy.md")
    quick_content = strip_title_if_present(quick_content)
    sections.append(f"## Quick Deploy Instructions\n\n{fixup_cross_references(quick_content)}")

    # 4. Full mode phases 1-6
    phase_files = [
        ("01-discover", "Phase 1: Discover"),
        ("02-architect", "Phase 2: Architect"),
        ("03-containerize", "Phase 3: Containerize"),
        ("04-scaffold", "Phase 4: Scaffold"),
        ("05-pipeline", "Phase 5: Pipeline"),
        ("06-deploy", "Phase 6: Deploy"),
    ]
    for filename, heading in phase_files:
        content = read_condensed_or_full(skill_root, f"phases/{filename}.md")
        content = strip_title_if_present(content)
        sections.append(f"## {heading}\n\n{fixup_cross_references(content)}")

    # 5. Reference material
    reference_files = [
        ("safeguards", "Reference: Deployment Safeguards"),
        ("workload-identity", "Reference: Workload Identity"),
        ("cost-reference", "Reference: Cost Estimation"),
        ("aks-automatic", "Reference: AKS Automatic"),
        ("aks-standard", "Reference: AKS Standard"),
    ]
    for filename, heading in reference_files:
        content = read_condensed_or_full(skill_root, f"reference/{filename}.md")
        content = strip_title_if_present(content)
        sections.append(f"## {heading}\n\n{fixup_cross_references(content)}")

    # 6. Knowledge packs (all, sorted alphabetically)
    kp_dir = skill_root / "knowledge-packs" / "frameworks"
    kp_sections = ["## Knowledge Packs\n"]
    for pack_file in sorted(kp_dir.glob("*.md")):
        if pack_file.name.endswith(".condensed.md"):
            continue  # Skip condensed variants during enumeration
        content = read_condensed_or_full(skill_root, f"knowledge-packs/frameworks/{pack_file.name}")
        content = strip_title_if_present(content)
        pack_name = pack_file.stem.replace("-", " ").title()
        # Use ### for individual packs under ## Knowledge Packs
        kp_sections.append(f"### {pack_name}\n\n{fixup_cross_references(content)}")
    sections.append("\n\n".join(kp_sections))

    # 7. Templates (verbatim, grouped by type)
    template_groups = [
        ("Templates: Kubernetes Manifests", "templates/k8s", "yaml"),
        ("Templates: Dockerfiles", "templates/dockerfiles", "dockerfile"),
        ("Templates: Bicep Modules", "templates/bicep", "bicep"),
        ("Templates: GitHub Actions", "templates/github-actions", "yaml"),
        ("Templates: Mermaid Diagrams", "templates/mermaid", "markdown"),
    ]
    for heading, rel_dir, lang in template_groups:
        template_dir = skill_root / rel_dir
        if not template_dir.is_dir():
            continue
        parts = [f"## {heading}\n"]
        for template_file in sorted(template_dir.iterdir()):
            if not template_file.is_file():
                continue
            content = template_file.read_text()
            file_label = f"{rel_dir}/{template_file.name}"
            # For mermaid templates (which are markdown), include raw
            if lang == "markdown":
                parts.append(f"### `{file_label}`\n\n{content.strip()}")
            else:
                fence_lang = lang
                if template_file.suffix == ".bicepparam":
                    fence_lang = "bicep"
                elif template_file.name.endswith(".Dockerfile"):
                    fence_lang = "dockerfile"
                elif template_file.suffix in (".yaml", ".yml"):
                    fence_lang = "yaml"
                elif template_file.suffix == ".bicep":
                    fence_lang = "bicep"
                parts.append(f"### `{file_label}`\n\n```{fence_lang}\n{content.strip()}\n```")
        sections.append("\n\n".join(parts))

    return "\n\n".join(sections) + "\n"


def main():
    skill_root = find_skill_root()
    monolith = build_monolith(skill_root)
    output_path = skill_root / "SKILL.copilot.md"
    output_path.write_text(monolith)
    # Report size
    lines = monolith.count("\n")
    size_kb = len(monolith.encode()) / 1024
    print(f"Built {output_path.relative_to(skill_root.parent.parent)}")
    print(f"  {lines:,} lines, {size_kb:.1f} KB")


if __name__ == "__main__":
    main()

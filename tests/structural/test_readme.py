"""README.md ↔ skill content consistency.

Verifies the README mentions all platforms, phase names match SKILL.md,
supported frameworks map to Dockerfile templates, and the project structure
tree is accurate.
"""

import re
from pathlib import Path

PLATFORMS = ["Claude Code", "GitHub Copilot", "OpenCode"]

PHASE_NAMES = ["Discover", "Architect", "Containerize", "Scaffold", "Pipeline", "Deploy"]

# Maps README framework display names to Dockerfile template filenames
FRAMEWORK_TO_DOCKERFILE = {
    "Node.js": "node.Dockerfile",
    "Python": "python.Dockerfile",
    "Java": "java.Dockerfile",
    "Go": "go.Dockerfile",
    ".NET": "dotnet.Dockerfile",
    "Rust": "rust.Dockerfile",
}


def test_readme_mentions_all_platforms(repo_root: Path):
    """README installation section mentions all three platforms."""
    readme = (repo_root / "README.md").read_text()
    for platform in PLATFORMS:
        assert platform in readme, f"README missing platform: {platform}"


def test_readme_phase_names_match_skill_md(repo_root: Path, skill_root: Path):
    """Phase names in README match SKILL.md's phase table."""
    readme = (repo_root / "README.md").read_text()
    for name in PHASE_NAMES:
        assert name in readme, f"README missing phase name: {name}"

    skill_md = (skill_root / "SKILL.md").read_text()
    for name in PHASE_NAMES:
        assert name in skill_md, f"SKILL.md missing phase name: {name}"


def test_readme_frameworks_have_dockerfiles(repo_root: Path, skill_root: Path):
    """Each framework listed in README has a corresponding Dockerfile template."""
    readme = (repo_root / "README.md").read_text()

    # Find the supported frameworks line — contains framework names separated by ·
    pattern = r"(?:Node\.js|Python|Java|Go|\.NET|Rust).*(?:Node\.js|Python|Java|Go|\.NET|Rust)"
    frameworks_match = re.search(pattern, readme)
    assert frameworks_match, "README missing supported frameworks line"

    frameworks_line = frameworks_match.group(0)
    docker_dir = skill_root / "templates" / "dockerfiles"

    for framework, dockerfile in FRAMEWORK_TO_DOCKERFILE.items():
        if framework in frameworks_line:
            assert (docker_dir / dockerfile).is_file(), f"README lists {framework} but {dockerfile} doesn't exist"


def test_readme_output_tree_references_valid_artifacts(repo_root: Path, skill_root: Path):
    """README's generated output tree references artifact types that have templates."""
    readme = (repo_root / "README.md").read_text()

    # The README shows a "What it generates" tree with K8s manifests, Bicep files,
    # Dockerfiles, and GH Actions workflow. Verify corresponding template dirs exist.
    template_dirs = {
        "deployment.yaml": skill_root / "templates" / "k8s",
        "main.bicep": skill_root / "templates" / "bicep",
        "Dockerfile": skill_root / "templates" / "dockerfiles",
        "deploy.yml": skill_root / "templates" / "github-actions",
    }
    for artifact, template_dir in template_dirs.items():
        assert artifact in readme, f"README output tree missing: {artifact}"
        assert template_dir.is_dir(), f"Template dir doesn't exist: {template_dir}"

"""AGENTS.md accuracy validation.

Verifies the repository structure tree, platform mentions, placeholder
convention descriptions, and test scenario frameworks match reality.
"""

import re
from pathlib import Path

PLATFORMS = ["Claude Code", "GitHub Copilot", "OpenCode"]

# Placeholder conventions described in AGENTS.md — these must match the actual templates
PLACEHOLDER_CONVENTIONS = {
    "angle-bracket": "k8s",
    "__DOUBLE_UNDERSCORE__": "github-actions",
    "DOUBLE_CURLY": "mermaid",
}

# Framework keywords from the test scenarios table, mapped to Dockerfile templates
SCENARIO_FRAMEWORKS = {
    "Java": "java.Dockerfile",
    "Node": "node.Dockerfile",
    "Python": "python.Dockerfile",
    ".NET": "dotnet.Dockerfile",
    "Go": "go.Dockerfile",
}


def test_agents_md_structure_tree_matches_disk(repo_root: Path):
    """Key directories in AGENTS.md's structure tree exist on disk."""
    agents_md = (repo_root / "AGENTS.md").read_text()
    skill_root = repo_root / "skills" / "deploy-to-aks"

    # Directories that should appear in the tree and exist on disk
    expected = {
        "phases/": skill_root / "phases",
        "reference/": skill_root / "reference",
        "bicep/": skill_root / "templates" / "bicep",
        "dockerfiles/": skill_root / "templates" / "dockerfiles",
        "github-actions/": skill_root / "templates" / "github-actions",
        "k8s/": skill_root / "templates" / "k8s",
        "mermaid/": skill_root / "templates" / "mermaid",
        "knowledge-packs/": skill_root / "knowledge-packs",
    }
    for tree_name, disk_path in expected.items():
        assert tree_name in agents_md, f"AGENTS.md tree missing: {tree_name}"
        assert disk_path.is_dir(), f"Directory doesn't exist: {disk_path}"


def test_agents_md_mentions_all_platforms(repo_root: Path):
    """AGENTS.md mentions all three platforms (no single-platform bias)."""
    agents_md = (repo_root / "AGENTS.md").read_text()
    for platform in PLATFORMS:
        assert platform in agents_md, f"AGENTS.md missing platform: {platform}"


def test_agents_md_placeholder_conventions(repo_root: Path):
    """AGENTS.md describes placeholder conventions that match actual templates."""
    agents_md = (repo_root / "AGENTS.md").read_text()
    for convention, template_dir in PLACEHOLDER_CONVENTIONS.items():
        assert convention.lower() in agents_md.lower(), (
            f"AGENTS.md missing placeholder convention: {convention}"
        )


def test_agents_md_test_scenarios_have_dockerfiles(repo_root: Path):
    """Frameworks in test scenarios table have corresponding Dockerfile templates."""
    agents_md = (repo_root / "AGENTS.md").read_text()
    docker_dir = repo_root / "skills" / "deploy-to-aks" / "templates" / "dockerfiles"

    for framework, dockerfile in SCENARIO_FRAMEWORKS.items():
        # Verify framework appears in test scenarios section
        assert framework in agents_md, (
            f"AGENTS.md test scenarios missing framework: {framework}"
        )
        # Verify corresponding Dockerfile exists
        assert (docker_dir / dockerfile).is_file(), (
            f"AGENTS.md mentions {framework} but {dockerfile} doesn't exist"
        )

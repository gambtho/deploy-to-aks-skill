"""Monolithic SKILL.copilot.md validation tests.

Verifies the build artifact contains all expected content, has valid
internal links, and contains no raw file-read directives that would
cause the agent to attempt reading external files.
"""

import re
import subprocess
import sys
from pathlib import Path

import pytest


@pytest.fixture(scope="module")
def monolith(skill_root: Path) -> str:
    """Read the monolith content once for all tests in this module."""
    path = skill_root / "SKILL.copilot.md"
    assert path.is_file(), f"SKILL.copilot.md not found at {path}. Run 'python scripts/build-skill.py' first."
    return path.read_text()


# --- Existence and structure ---


def test_monolith_exists(skill_root: Path):
    """SKILL.copilot.md exists in the skill directory."""
    assert (skill_root / "SKILL.copilot.md").is_file()


def test_monolith_has_frontmatter(monolith: str):
    """Monolith starts with YAML frontmatter containing name and description."""
    assert monolith.startswith("---"), "Missing YAML frontmatter"
    end = monolith.index("---", 3)
    frontmatter = monolith[: end + 3]
    assert "name: deploy-to-aks" in frontmatter
    assert "description:" in frontmatter


def test_monolith_frontmatter_matches_source(skill_root: Path, monolith: str):
    """Monolith frontmatter matches SKILL.md frontmatter."""
    source = (skill_root / "SKILL.md").read_text()
    # Extract frontmatter from both
    source_fm = source[: source.index("---", 3) + 3]
    mono_fm = monolith[: monolith.index("---", 3) + 3]
    assert source_fm == mono_fm, "Frontmatter mismatch between SKILL.md and SKILL.copilot.md"


# --- Phase content ---


PHASE_HEADINGS = [
    "## Quick Deploy Instructions",
    "## Phase 1: Discover",
    "## Phase 2: Architect",
    "## Phase 3: Containerize",
    "## Phase 4: Scaffold",
    "## Phase 5: Pipeline",
    "## Phase 6: Deploy",
]


@pytest.mark.parametrize("heading", PHASE_HEADINGS)
def test_monolith_contains_phase(monolith: str, heading: str):
    """Each phase has a corresponding section heading in the monolith."""
    assert heading in monolith, f"Missing phase heading: {heading}"


# --- Reference content ---


REFERENCE_HEADINGS = [
    "## Reference: Deployment Safeguards",
    "## Reference: Workload Identity",
    "## Reference: Cost Estimation",
    "## Reference: AKS Automatic",
    "## Reference: AKS Standard",
]


@pytest.mark.parametrize("heading", REFERENCE_HEADINGS)
def test_monolith_contains_reference(monolith: str, heading: str):
    """Each reference file has a corresponding section heading in the monolith."""
    assert heading in monolith, f"Missing reference heading: {heading}"


# --- Knowledge packs ---


KNOWLEDGE_PACKS = [
    "Aspnet Core",
    "Django",
    "Express",
    "Fastapi",
    "Flask",
    "Go",
    "Nestjs",
    "Nextjs",
    "Spring Boot",
]


@pytest.mark.parametrize("pack", KNOWLEDGE_PACKS)
def test_monolith_contains_knowledge_pack(monolith: str, pack: str):
    """Each knowledge pack has a section under ## Knowledge Packs."""
    assert f"### {pack}" in monolith, f"Missing knowledge pack: {pack}"


# --- Template content ---


TEMPLATE_SECTIONS = [
    "## Templates: Kubernetes Manifests",
    "## Templates: Dockerfiles",
    "## Templates: Bicep Modules",
    "## Templates: GitHub Actions",
    "## Templates: Mermaid Diagrams",
]


@pytest.mark.parametrize("heading", TEMPLATE_SECTIONS)
def test_monolith_contains_template_section(monolith: str, heading: str):
    """Each template group has a section heading in the monolith."""
    assert heading in monolith, f"Missing template section: {heading}"


# Key template files that MUST be present (by their file label)
KEY_TEMPLATES = [
    "templates/k8s/deployment.yaml",
    "templates/k8s/service.yaml",
    "templates/k8s/namespace.yaml",
    "templates/k8s/ingress.yaml",
    "templates/k8s/hpa.yaml",
    "templates/k8s/pdb.yaml",
    "templates/k8s/serviceaccount.yaml",
    "templates/dockerfiles/python.Dockerfile",
    "templates/dockerfiles/node.Dockerfile",
    "templates/dockerfiles/java.Dockerfile",
    "templates/dockerfiles/go.Dockerfile",
    "templates/bicep/main.bicep",
    "templates/bicep/aks.bicep",
    "templates/bicep/acr.bicep",
    "templates/github-actions/deploy.yml",
    "templates/mermaid/architecture-diagram.md",
    "templates/mermaid/summary-dashboard.md",
]


@pytest.mark.parametrize("template", KEY_TEMPLATES)
def test_monolith_contains_template(monolith: str, template: str):
    """Key template files appear in the monolith (by their file label)."""
    assert template in monolith, f"Missing template: {template}"


# --- No file-read directives ---


FILE_READ_PATTERNS = [
    r"[Rr]ead\s+`phases/",
    r"[Rr]ead\s+`reference/",
    r"[Rr]ead\s+`templates/",
    r"[Rr]ead\s+`knowledge-packs/",
]


@pytest.mark.parametrize("pattern", FILE_READ_PATTERNS)
def test_monolith_no_file_read_directives(monolith: str, pattern: str):
    """Monolith should not contain directives telling the agent to read external files."""
    matches = re.findall(pattern, monolith)
    assert not matches, f"Found file-read directive(s) matching '{pattern}': {matches[:3]}"


# --- Internal anchor link validity ---


def test_monolith_internal_links_resolve(monolith: str):
    """Every [text](#anchor) link in the monolith resolves to an actual heading."""
    # Extract all internal anchor links
    link_pattern = re.compile(r"\[([^\]]+)\]\(#([a-z0-9-]+)\)")
    links = link_pattern.findall(monolith)
    if not links:
        return  # No internal links to validate

    # Build set of actual heading anchors
    heading_pattern = re.compile(r"^(#{1,6})\s+(.+)$", re.MULTILINE)
    anchors = set()
    for _, heading_text in heading_pattern.findall(monolith):
        # Convert heading text to GitHub-style anchor
        anchor = heading_text.strip()
        # Remove inline code backticks
        anchor = anchor.replace("`", "")
        anchor = anchor.lower()
        anchor = re.sub(r"[^\w\s-]", "", anchor)
        anchor = re.sub(r"\s+", "-", anchor)
        anchor = anchor.strip("-")
        anchors.add(anchor)

    broken = []
    for text, anchor in links:
        if anchor not in anchors:
            broken.append(f"[{text}](#{anchor})")
    assert not broken, f"Broken internal links: {broken[:5]}"


# --- Freshness check ---


def test_monolith_is_up_to_date(repo_root: Path, skill_root: Path):
    """Running the build script produces no diff in SKILL.copilot.md.

    This catches cases where source files were edited but the monolith
    was not rebuilt.
    """
    build_script = repo_root / "scripts" / "build-skill.py"
    assert build_script.is_file(), f"Build script not found: {build_script}"

    # Read current monolith
    monolith_path = skill_root / "SKILL.copilot.md"
    original = monolith_path.read_text() if monolith_path.is_file() else ""

    # Run build
    result = subprocess.run(
        [sys.executable, str(build_script)],
        capture_output=True,
        text=True,
        cwd=str(repo_root),
    )
    assert result.returncode == 0, f"Build script failed: {result.stderr}"

    # Compare
    rebuilt = monolith_path.read_text()
    # Restore original to avoid side effects
    monolith_path.write_text(original)

    assert original == rebuilt, "SKILL.copilot.md is out of date. Run 'python scripts/build-skill.py' to rebuild."

"""Quick deploy mode structural tests.

Validates that the quick deploy phase file, prerequisites script, and SKILL.md
routing are internally consistent and properly cross-referenced.
"""

import re
import subprocess
from pathlib import Path


# --- Phase file existence and naming ---


def test_quick_phase_file_exists(skill_root: Path):
    """Quick deploy phase file exists in phases/."""
    phases_dir = skill_root / "phases"
    assert (phases_dir / "quick-deploy.md").is_file(), f"Missing quick phase file: {phases_dir}/quick-deploy.md"


def test_quick_phase_naming_convention(skill_root: Path):
    """Exactly one quick phase file exists matching quick-*.md pattern."""
    phases_dir = skill_root / "phases"
    quick_files = [f for f in phases_dir.iterdir() if f.name.startswith("quick-")]
    assert len(quick_files) == 1, (
        f"Expected 1 quick phase file, found {len(quick_files)}: {[f.name for f in quick_files]}"
    )
    assert quick_files[0].name == "quick-deploy.md"


def test_quick_phase_title(skill_root: Path):
    """Quick deploy phase file has a # title."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert re.search(r"^# Quick Deploy", content, re.MULTILINE), (
        "quick-deploy.md missing expected title '# Quick Deploy'"
    )


def test_quick_phase_goal_section(skill_root: Path):
    """Quick deploy phase file has a ## Goal section."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert re.search(r"^## Goal", content, re.MULTILINE), "quick-deploy.md missing '## Goal' section"


# --- SKILL.md routing ---


def test_skill_md_quick_mode_routing(skill_root: Path):
    """SKILL.md contains quick mode detection block and phase table."""
    skill_md = (skill_root / "SKILL.md").read_text()
    assert "Quick Deploy Mode" in skill_md, "SKILL.md missing 'Quick Deploy Mode' section"
    assert "quick-deploy.md" in skill_md, "SKILL.md missing reference to quick-deploy.md"


# --- Cross-references ---


def test_quick_mode_cross_references(skill_root: Path, repo_root: Path):
    """All file paths referenced in quick-deploy.md exist on disk."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    path_pattern = re.compile(r"`((?:templates|reference|knowledge-packs|scripts)/[a-zA-Z0-9/_.-]+)`")
    paths = path_pattern.findall(content)
    for rel_path in paths:
        if "<" in rel_path:
            continue
        if rel_path.startswith("scripts/"):
            full_path = repo_root / rel_path
        else:
            full_path = skill_root / rel_path
        assert full_path.exists(), f"quick-deploy.md references '{rel_path}' but it doesn't exist"


def test_quick_mode_no_bicep_references(skill_root: Path):
    """Quick deploy phase file does not reference any templates/bicep/ files."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert "templates/bicep/" not in content, "quick-deploy.md should not reference Bicep templates"


def test_quick_mode_no_github_actions_references(skill_root: Path):
    """Quick deploy phase file does not reference templates/github-actions/."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    assert "templates/github-actions/" not in content, "quick-deploy.md should not reference GitHub Actions templates"


# --- No presentation choreography ---


def test_quick_mode_no_presentation_choreography(skill_root: Path):
    """Quick deploy phase file contains no presentation choreography."""
    content = (skill_root / "phases" / "quick-deploy.md").read_text()
    banned_patterns = [
        ("progress indicators", r"[◻▸✓✗]"),
        ("celebration banner", r"celebration|🎉"),
        ("permission glob strategy", r"permission.*glob|glob.*permission"),
        ("narration suppression", r"DO NOT narrate|do not narrate"),
        ("output suppression", r"suppress.*output|output.*suppress"),
    ]
    for name, pattern in banned_patterns:
        assert not re.search(pattern, content, re.IGNORECASE), f"quick-deploy.md contains {name} (pattern: {pattern})"


# --- Prerequisites script ---


def test_prerequisites_script_exists(repo_root: Path):
    """scripts/setup-aks-prerequisites.sh exists and is executable."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    assert script.is_file(), "Missing prerequisites script"
    assert script.stat().st_mode & 0o111, "Prerequisites script is not executable"


def test_prerequisites_script_help_flag(repo_root: Path):
    """Script supports --help and prints usage."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    result = subprocess.run(
        [str(script), "--help"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 0, f"--help exited with {result.returncode}"
    assert "Usage:" in result.stdout, "--help output missing 'Usage:'"


def test_prerequisites_script_required_args(repo_root: Path):
    """Script errors with message when --name is missing."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    result = subprocess.run(
        [str(script)],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode != 0, "Script should fail without --name"
    assert "--name" in result.stderr, "Error message should mention --name"


def test_prerequisites_script_has_cleanup(repo_root: Path):
    """Script source contains --cleanup handling."""
    script = repo_root / "scripts" / "setup-aks-prerequisites.sh"
    content = script.read_text()
    assert "--cleanup" in content, "Script missing --cleanup flag handling"

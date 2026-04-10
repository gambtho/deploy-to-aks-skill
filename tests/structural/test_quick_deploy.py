"""Quick deploy mode structural tests.

Validates that quick phase files, prerequisites script, and SKILL.md
routing are internally consistent and properly cross-referenced.
"""

import re
import subprocess
from pathlib import Path


# --- Phase file existence and naming ---


def test_quick_phase_files_exist(skill_root: Path):
    """Both quick phase files exist in phases/."""
    phases_dir = skill_root / "phases"
    assert (phases_dir / "quick-01-scan-and-plan.md").is_file(), (
        "Missing quick phase file: quick-01-scan-and-plan.md"
    )
    assert (phases_dir / "quick-02-execute.md").is_file(), (
        "Missing quick phase file: quick-02-execute.md"
    )


def test_quick_phase_naming_convention(skill_root: Path):
    """Quick phase files follow quick-NN-<name>.md pattern."""
    phases_dir = skill_root / "phases"
    quick_files = sorted(f for f in phases_dir.iterdir() if f.name.startswith("quick-"))
    assert len(quick_files) == 2, f"Expected 2 quick phase files, found {len(quick_files)}"
    pattern = re.compile(r"^quick-\d{2}-[a-z-]+\.md$")
    for f in quick_files:
        assert pattern.match(f.name), f"Quick phase file '{f.name}' doesn't match naming pattern"


def test_quick_phase_titles(skill_root: Path):
    """Each quick phase file has a # title matching its purpose."""
    phases_dir = skill_root / "phases"
    checks = {
        "quick-01-scan-and-plan.md": r"^# Quick Phase 1:",
        "quick-02-execute.md": r"^# Quick Phase 2:",
    }
    for filename, pattern in checks.items():
        content = (phases_dir / filename).read_text()
        assert re.search(pattern, content, re.MULTILINE), (
            f"{filename} missing expected title matching '{pattern}'"
        )


def test_quick_phase_goal_sections(skill_root: Path):
    """Each quick phase file has a ## Goal section."""
    phases_dir = skill_root / "phases"
    for filename in ["quick-01-scan-and-plan.md", "quick-02-execute.md"]:
        content = (phases_dir / filename).read_text()
        assert re.search(r"^## Goal", content, re.MULTILINE), (
            f"{filename} missing '## Goal' section"
        )


# --- SKILL.md routing ---


def test_skill_md_quick_mode_routing(skill_root: Path):
    """SKILL.md contains quick mode detection block and phase table."""
    skill_md = (skill_root / "SKILL.md").read_text()
    assert "Quick Deploy Mode" in skill_md, "SKILL.md missing 'Quick Deploy Mode' section"
    assert "quick-01-scan-and-plan.md" in skill_md, (
        "SKILL.md missing reference to quick-01-scan-and-plan.md"
    )
    assert "quick-02-execute.md" in skill_md, (
        "SKILL.md missing reference to quick-02-execute.md"
    )


# --- Cross-references ---


def test_quick_mode_cross_references(skill_root: Path, repo_root: Path):
    """All file paths referenced in quick phase files exist on disk."""
    phases_dir = skill_root / "phases"
    path_pattern = re.compile(
        r"`((?:templates|reference|knowledge-packs|scripts)/[^`]+)`"
    )
    for filename in ["quick-01-scan-and-plan.md", "quick-02-execute.md"]:
        content = (phases_dir / filename).read_text()
        paths = path_pattern.findall(content)
        for rel_path in paths:
            # Skip pattern paths like <detected>.md
            if "<" in rel_path:
                continue
            # Scripts are under repo root, everything else under skill_root
            if rel_path.startswith("scripts/"):
                full_path = repo_root / rel_path
            else:
                full_path = skill_root / rel_path
            assert full_path.exists(), (
                f"{filename} references '{rel_path}' but it doesn't exist"
            )


def test_quick_mode_no_bicep_references(skill_root: Path):
    """Quick phase files do not reference any templates/bicep/ files."""
    phases_dir = skill_root / "phases"
    for filename in ["quick-01-scan-and-plan.md", "quick-02-execute.md"]:
        content = (phases_dir / filename).read_text()
        assert "templates/bicep/" not in content, (
            f"{filename} should not reference Bicep templates"
        )


def test_quick_mode_no_github_actions_references(skill_root: Path):
    """Quick phase files do not reference templates/github-actions/."""
    phases_dir = skill_root / "phases"
    for filename in ["quick-01-scan-and-plan.md", "quick-02-execute.md"]:
        content = (phases_dir / filename).read_text()
        assert "templates/github-actions/" not in content, (
            f"{filename} should not reference GitHub Actions templates"
        )


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

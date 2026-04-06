"""install.sh validation.

Tests error paths (help, unknown flags, missing skill dir, invalid platform,
copilot global) and happy paths (all 3 platforms with --scope project).
"""

import shutil
import subprocess
from pathlib import Path


def _run_install(args: list[str], cwd: str | Path | None = None) -> subprocess.CompletedProcess:
    """Run install.sh with given arguments."""
    try:
        return subprocess.run(
            ["bash", "install.sh", *args],
            capture_output=True,
            text=True,
            cwd=cwd,
            timeout=30,
        )
    except subprocess.TimeoutExpired as e:
        raise RuntimeError(f"install.sh timed out after 30s with args: {args}") from e


# --- Error path tests ---


def test_help_exits_zero(repo_root: Path):
    """--help exits 0 and prints usage."""
    result = _run_install(["--help"], cwd=repo_root)
    assert result.returncode == 0
    assert "Usage:" in result.stdout


def test_unknown_flag_exits_nonzero(repo_root: Path):
    """Unknown flag exits non-zero with error message."""
    result = _run_install(["--bogus"], cwd=repo_root)
    assert result.returncode != 0
    assert "Error:" in result.stderr


def test_missing_skill_dir_exits_nonzero(tmp_path: Path, repo_root: Path):
    """Running from a directory without skills/ exits non-zero."""
    # Copy just the script to a temp dir (no skills/ directory)
    shutil.copy2(repo_root / "install.sh", tmp_path / "install.sh")
    try:
        result = subprocess.run(
            [
                "bash",
                "install.sh",
                "--platform",
                "copilot",
                "--scope",
                "project",
                "--project-dir",
                str(tmp_path / "target"),
            ],
            capture_output=True,
            text=True,
            cwd=tmp_path,
            timeout=30,
        )
    except subprocess.TimeoutExpired as e:
        raise RuntimeError("install.sh timed out after 30s") from e
    assert result.returncode != 0
    assert "Cannot find" in result.stderr


def test_copilot_global_scope_exits_nonzero(repo_root: Path):
    """--platform copilot --scope global exits non-zero."""
    result = _run_install(["--platform", "copilot", "--scope", "global"], cwd=repo_root)
    assert result.returncode != 0
    assert "global" in result.stderr.lower()


def test_invalid_platform_exits_nonzero(repo_root: Path):
    """Invalid --platform value exits non-zero."""
    result = _run_install(["--platform", "invalid"], cwd=repo_root)
    assert result.returncode != 0
    assert "Error:" in result.stderr


# --- Happy path tests ---


def test_copilot_project_install(tmp_path: Path, repo_root: Path):
    """Copilot project install creates full skill directory + instructions file."""
    project_dir = tmp_path / "project"
    project_dir.mkdir()
    result = _run_install(
        ["--platform", "copilot", "--scope", "project", "--project-dir", str(project_dir)],
        cwd=repo_root,
    )
    assert result.returncode == 0, f"Install failed: {result.stderr}"

    skill_dir = project_dir / ".github" / "skills" / "deploy-to-aks"
    assert (skill_dir / "SKILL.md").is_file(), "SKILL.md not copied"
    assert any((skill_dir / "phases").iterdir()), "phases/ is empty"
    assert any((skill_dir / "templates").iterdir()), "templates/ is empty"
    assert (project_dir / ".github" / "copilot-instructions.md").is_file(), "copilot-instructions.md not created"


def test_claude_code_project_install(tmp_path: Path, repo_root: Path):
    """Claude Code project install creates full skill directory."""
    project_dir = tmp_path / "project"
    project_dir.mkdir()
    result = _run_install(
        ["--platform", "claude-code", "--scope", "project", "--project-dir", str(project_dir)],
        cwd=repo_root,
    )
    assert result.returncode == 0, f"Install failed: {result.stderr}"

    skill_dir = project_dir / ".claude" / "skills" / "deploy-to-aks"
    assert (skill_dir / "SKILL.md").is_file(), "SKILL.md not copied"
    assert any((skill_dir / "phases").iterdir()), "phases/ is empty"
    assert any((skill_dir / "templates").iterdir()), "templates/ is empty"


def test_opencode_project_install(tmp_path: Path, repo_root: Path):
    """OpenCode project install creates full skill directory."""
    project_dir = tmp_path / "project"
    project_dir.mkdir()
    result = _run_install(
        ["--platform", "opencode", "--scope", "project", "--project-dir", str(project_dir)],
        cwd=repo_root,
    )
    assert result.returncode == 0, f"Install failed: {result.stderr}"

    skill_dir = project_dir / ".opencode" / "skills" / "deploy-to-aks"
    assert (skill_dir / "SKILL.md").is_file(), "SKILL.md not copied"
    assert any((skill_dir / "phases").iterdir()), "phases/ is empty"
    assert any((skill_dir / "templates").iterdir()), "templates/ is empty"

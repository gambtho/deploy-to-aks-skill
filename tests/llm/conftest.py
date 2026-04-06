"""LLM behavioral test fixtures.

Provides Copilot CLI helper, session-scoped skill copy, and per-test
workspace setup.
"""

import shutil
import subprocess
from pathlib import Path
from typing import Callable

import pytest

pytestmark = pytest.mark.llm


def _run_copilot(prompt: str, workdir: Path, timeout: int = 120) -> str:
    """Run Copilot CLI in headless mode and return stdout.

    Raises RuntimeError if the command fails or times out.

    Security note: --allow-all-tools grants the CLI full filesystem access
    within the CI runner. Tests should run in isolated temp directories
    (the workspace fixture handles this) and CI runners are ephemeral.
    """
    try:
        result = subprocess.run(
            ["copilot", "-p", prompt, "--allow-all-tools"],
            capture_output=True,
            text=True,
            cwd=workdir,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as e:
        raise RuntimeError(f"Copilot CLI timed out after {timeout}s") from e
    if result.returncode != 0:
        raise RuntimeError(f"Copilot CLI failed (rc={result.returncode}): {result.stderr}")
    return result.stdout


@pytest.fixture(scope="session")
def run_copilot() -> Callable[..., str]:
    """Provide the Copilot CLI runner function as a fixture."""
    return _run_copilot


@pytest.fixture(scope="session")
def shared_skill_dir(tmp_path_factory, skill_root):
    """Copy skill directory once per session — tests are read-only on it."""
    dest = tmp_path_factory.mktemp("skill") / "deploy-to-aks"
    shutil.copytree(skill_root, dest)
    return dest


@pytest.fixture
def workspace(tmp_path, shared_skill_dir, request):
    """Create a self-contained workspace with fixture project + shared skill.

    Usage: @pytest.mark.parametrize("workspace", ["fixture-name"], indirect=True)
    """
    fixture_name = request.param
    fixture_src = Path(__file__).parent / "fixtures" / fixture_name

    assert fixture_src.is_dir(), f"Fixture not found: {fixture_name}"

    # Copy fixture files to workspace root
    for item in fixture_src.iterdir():
        if item.is_dir():
            shutil.copytree(item, tmp_path / item.name)
        else:
            shutil.copy2(item, tmp_path / item.name)

    # Symlink shared skill copy into workspace
    skill_dest = tmp_path / "skills" / "deploy-to-aks"
    skill_dest.parent.mkdir(parents=True)
    skill_dest.symlink_to(shared_skill_dir)

    return tmp_path

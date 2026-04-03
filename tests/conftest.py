from pathlib import Path

import pytest


@pytest.fixture(scope="session")
def repo_root() -> Path:
    """Resolve repo root by walking up from this file to find pyproject.toml."""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / "pyproject.toml").exists():
            return current
        current = current.parent
    raise RuntimeError("Could not find repo root (no pyproject.toml found)")


@pytest.fixture(scope="session")
def skill_root(repo_root: Path) -> Path:
    """Path to the skill directory under repo root."""
    path = repo_root / "skills" / "deploy-to-aks"
    assert path.is_dir(), f"Skill root not found: {path}"
    return path

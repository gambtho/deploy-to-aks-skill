"""Phase file structure validation.

Verifies all 6 phase files exist with correct naming, titles, required
sections, and reasonable size bounds.
"""

import re
from pathlib import Path

PHASES = {
    1: "discover",
    2: "architect",
    3: "containerize",
    4: "scaffold",
    5: "pipeline",
    6: "deploy",
}

MIN_SIZE_BYTES = 3 * 1024  # 3KB — below this is a stub, not a real phase
MAX_SIZE_BYTES = 30 * 1024  # 30KB — above this is probably too large


def test_all_phase_files_exist(skill_root: Path):
    """All 6 phase files exist with the expected naming pattern."""
    phases_dir = skill_root / "phases"
    for num, name in PHASES.items():
        path = phases_dir / f"0{num}-{name}.md"
        assert path.is_file(), f"Missing phase file: {path.name}"


def test_phase_titles_match_numbers(skill_root: Path):
    """Each phase file starts with '# Phase N: <Name>'."""
    phases_dir = skill_root / "phases"
    for num, name in PHASES.items():
        path = phases_dir / f"0{num}-{name}.md"
        content = path.read_text()
        pattern = rf"^# Phase {num}: "
        assert re.search(pattern, content, re.MULTILINE), f"{path.name} missing '# Phase {num}: ...' title"


def test_phase_files_have_goal_section(skill_root: Path):
    """Each phase file contains a '## Goal' section."""
    phases_dir = skill_root / "phases"
    for num, name in PHASES.items():
        path = phases_dir / f"0{num}-{name}.md"
        content = path.read_text()
        assert re.search(r"^## Goal", content, re.MULTILINE), f"{path.name} missing '## Goal' section"


def test_phase_file_sizes_within_bounds(skill_root: Path):
    """Phase files are between 3KB and 30KB."""
    phases_dir = skill_root / "phases"
    for num, name in PHASES.items():
        path = phases_dir / f"0{num}-{name}.md"
        size = path.stat().st_size
        assert size >= MIN_SIZE_BYTES, (
            f"{path.name} is {size} bytes — below {MIN_SIZE_BYTES} minimum (likely truncated)"
        )
        assert size <= MAX_SIZE_BYTES, (
            f"{path.name} is {size} bytes — above {MAX_SIZE_BYTES} maximum (likely too large)"
        )

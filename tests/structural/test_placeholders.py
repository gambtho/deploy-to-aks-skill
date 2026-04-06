"""Placeholder convention compliance per template type.

Verifies each template directory uses the correct placeholder style and
that no template mixes styles (cross-contamination).
"""

import re
from pathlib import Path

ANGLE_BRACKET_RE = re.compile(r"<[a-z][a-z0-9-]+>")
DOUBLE_UNDERSCORE_RE = re.compile(r"__[A-Z][A-Z0-9_]+__")
DOUBLE_CURLY_RE = re.compile(r"\{\{[A-Z][A-Z0-9_]+\}\}")

# Lines containing these commands may legitimately have <angle-bracket>
# values that are K8s manifest placeholders, not GA workflow placeholders.
SED_COMMAND_RE = re.compile(r"\bsed\b|\benvsubst\b|\bawk\b")


def test_k8s_templates_use_angle_brackets(skill_root: Path):
    """K8s templates use <angle-bracket> placeholders."""
    k8s_dir = skill_root / "templates" / "k8s"
    files = [f for f in sorted(k8s_dir.iterdir()) if f.is_file()]
    assert len(files) > 0, f"No files found in {k8s_dir}"
    for template in files:
        content = template.read_text()
        matches = ANGLE_BRACKET_RE.findall(content)
        assert len(matches) > 0, f"{template.name} has no <angle-bracket> placeholders"


def test_github_actions_uses_double_underscore(skill_root: Path):
    """GitHub Actions workflow uses __DOUBLE_UNDERSCORE__ placeholders."""
    deploy = skill_root / "templates" / "github-actions" / "deploy.yml"
    content = deploy.read_text()
    matches = DOUBLE_UNDERSCORE_RE.findall(content)
    assert len(matches) > 0, "deploy.yml has no __DOUBLE_UNDERSCORE__ placeholders"


def test_mermaid_templates_use_double_curly(skill_root: Path):
    """Mermaid templates use {{DOUBLE_CURLY}} placeholders."""
    mermaid_dir = skill_root / "templates" / "mermaid"
    files = [f for f in sorted(mermaid_dir.iterdir()) if f.is_file()]
    assert len(files) > 0, f"No files found in {mermaid_dir}"
    for template in files:
        content = template.read_text()
        matches = DOUBLE_CURLY_RE.findall(content)
        assert len(matches) > 0, f"{template.name} has no {{{{DOUBLE_CURLY}}}} placeholders"


def test_no_mixed_placeholders_in_k8s(skill_root: Path):
    """K8s templates should not contain __DOUBLE_UNDERSCORE__ or {{CURLY}} placeholders."""
    k8s_dir = skill_root / "templates" / "k8s"
    files = [f for f in sorted(k8s_dir.iterdir()) if f.is_file()]
    assert len(files) > 0, f"No files found in {k8s_dir}"
    for template in files:
        content = template.read_text()
        assert not DOUBLE_UNDERSCORE_RE.search(content), (
            f"{template.name} contains __DOUBLE_UNDERSCORE__ placeholder (wrong style for K8s)"
        )
        assert not DOUBLE_CURLY_RE.search(content), (
            f"{template.name} contains {{{{DOUBLE_CURLY}}}} placeholder (wrong style for K8s)"
        )


def test_no_mixed_placeholders_in_github_actions(skill_root: Path):
    """deploy.yml should not contain {{CURLY}} placeholders.

    Note: <angle-bracket> values inside sed/envsubst commands are excluded —
    these are K8s manifest placeholders the workflow replaces at deploy time.
    """
    deploy = skill_root / "templates" / "github-actions" / "deploy.yml"
    content = deploy.read_text()

    # Check no double-curly (mermaid-style) placeholders
    assert not DOUBLE_CURLY_RE.search(content), (
        "deploy.yml contains {{DOUBLE_CURLY}} placeholder (wrong style for GH Actions)"
    )

    # Check for angle-bracket placeholders outside sed/envsubst lines
    for i, line in enumerate(content.splitlines(), 1):
        if SED_COMMAND_RE.search(line):
            continue  # Skip lines with sed/envsubst — <image> there is expected
        angle_matches = ANGLE_BRACKET_RE.findall(line)
        assert not angle_matches, (
            f"deploy.yml line {i} contains <angle-bracket> placeholder outside a sed/envsubst command: {angle_matches}"
        )


def test_no_mixed_placeholders_in_mermaid(skill_root: Path):
    """Mermaid templates should not contain __DOUBLE_UNDERSCORE__ or <angle-bracket> placeholders."""
    mermaid_dir = skill_root / "templates" / "mermaid"
    files = [f for f in sorted(mermaid_dir.iterdir()) if f.is_file()]
    assert len(files) > 0, f"No files found in {mermaid_dir}"
    for template in files:
        content = template.read_text()
        assert not DOUBLE_UNDERSCORE_RE.search(content), (
            f"{template.name} contains __DOUBLE_UNDERSCORE__ placeholder (wrong style for mermaid)"
        )
        assert not ANGLE_BRACKET_RE.search(content), (
            f"{template.name} contains <angle-bracket> placeholder (wrong style for mermaid)"
        )

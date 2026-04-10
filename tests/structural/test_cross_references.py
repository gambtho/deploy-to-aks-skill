"""Cross-reference integrity between SKILL.md, phases, templates, and references.

Verifies forward references (paths mentioned in docs exist on disk) and
reverse references (every template file is referenced by at least one phase
or SKILL.md — no orphans).
"""

import re
from pathlib import Path


def _extract_phase_table_paths(skill_md: str) -> list[str]:
    """Extract file paths from SKILL.md's phase table rows."""
    paths: list[str] = []
    # Match backtick-quoted relative paths like `phases/01-discover.md`
    for match in re.finditer(r"`((?:phases|reference|templates|knowledge-packs)/[^`]+)`", skill_md):
        path = match.group(1)
        # Skip pattern paths like <detected>.md
        if "<" not in path:
            paths.append(path)
    return paths


# --- Forward reference tests ---


def test_skill_md_phase_table_paths_exist(skill_root: Path):
    """Every file path in SKILL.md's phase table exists on disk."""
    skill_md = (skill_root / "SKILL.md").read_text()
    paths = _extract_phase_table_paths(skill_md)
    assert len(paths) > 0, "No paths extracted from SKILL.md phase table"
    for rel_path in paths:
        full_path = skill_root / rel_path
        assert full_path.exists(), f"SKILL.md references '{rel_path}' but it doesn't exist"


def test_mermaid_templates_referenced_in_skill_md(skill_root: Path):
    """Every mermaid template is referenced in SKILL.md."""
    skill_md = (skill_root / "SKILL.md").read_text()
    mermaid_dir = skill_root / "templates" / "mermaid"
    files = [f for f in sorted(mermaid_dir.iterdir()) if f.is_file()]
    assert len(files) > 0, f"No files found in {mermaid_dir}"
    for template in files:
        rel = f"templates/mermaid/{template.name}"
        assert rel in skill_md, f"Orphan mermaid template: {template.name} not referenced in SKILL.md"


def test_knowledge_packs_referenced(skill_root: Path):
    """Every knowledge pack is referenced in 01-discover.md or SKILL.md."""
    skill_md = (skill_root / "SKILL.md").read_text()
    discover = (skill_root / "phases" / "01-discover.md").read_text()
    quick_scan = (skill_root / "phases" / "quick-01-scan-and-plan.md").read_text()
    combined = skill_md + discover + quick_scan
    kp_dir = skill_root / "knowledge-packs" / "frameworks"
    assert kp_dir.exists(), f"Knowledge packs directory does not exist: {kp_dir}"
    files = [f for f in sorted(kp_dir.iterdir()) if f.is_file() and f.suffix == ".md"]
    assert len(files) > 0, f"No files found in {kp_dir}"
    for pack in files:
        assert pack.stem in combined, f"Orphan knowledge pack: {pack.name} not referenced in SKILL.md or 01-discover.md"


def test_knowledge_pack_structure(skill_root: Path):
    """Each knowledge pack has a # title and at least one ## section."""
    kp_dir = skill_root / "knowledge-packs" / "frameworks"
    assert kp_dir.exists(), f"Knowledge packs directory does not exist: {kp_dir}"
    files = [f for f in sorted(kp_dir.iterdir()) if f.is_file() and f.suffix == ".md"]
    assert len(files) > 0, f"No files found in {kp_dir}"
    for pack in files:
        content = pack.read_text()
        assert re.search(r"^# ", content, re.MULTILINE), f"{pack.name} missing '# ' title"
        assert re.search(r"^## ", content, re.MULTILINE), f"{pack.name} missing '## ' section heading"


# --- Reverse reference (orphan detection) tests ---


def test_k8s_templates_referenced_in_phase4(skill_root: Path):
    """Every K8s template in templates/k8s/ is referenced in phases/04-scaffold.md."""
    phase4 = (skill_root / "phases" / "04-scaffold.md").read_text()
    k8s_dir = skill_root / "templates" / "k8s"
    templates = [t for t in sorted(k8s_dir.iterdir()) if t.is_file()]
    assert len(templates) > 0, "No K8s templates found"
    for template in templates:
        ref = f"templates/k8s/{template.name}"
        assert ref in phase4, f"Orphan K8s template: {template.name} not referenced in 04-scaffold.md"


def test_bicep_templates_referenced_in_phases(skill_root: Path):
    """Every Bicep template is referenced in phases/04-scaffold.md or phases/02-architect.md."""
    phase4 = (skill_root / "phases" / "04-scaffold.md").read_text()
    phase2 = (skill_root / "phases" / "02-architect.md").read_text()
    combined = phase4 + phase2
    bicep_dir = skill_root / "templates" / "bicep"
    templates = [t for t in sorted(bicep_dir.iterdir()) if t.is_file()]
    assert len(templates) > 0, "No Bicep templates found"
    for template in templates:
        ref = f"templates/bicep/{template.name}"
        assert ref in combined, (
            f"Orphan Bicep template: {template.name} not referenced in 04-scaffold.md or 02-architect.md"
        )


def test_dockerfile_templates_referenced_in_phase3(skill_root: Path):
    """Every Dockerfile template is referenced in phases/03-containerize.md."""
    phase3 = (skill_root / "phases" / "03-containerize.md").read_text()
    docker_dir = skill_root / "templates" / "dockerfiles"
    templates = [t for t in sorted(docker_dir.iterdir()) if t.is_file()]
    assert len(templates) > 0, "No Dockerfile templates found"
    for template in templates:
        ref = f"templates/dockerfiles/{template.name}"
        assert ref in phase3, f"Orphan Dockerfile template: {template.name} not referenced in 03-containerize.md"


def test_github_actions_templates_referenced_in_phase5(skill_root: Path):
    """Every GitHub Actions template is referenced in phases/05-pipeline.md."""
    phase5 = (skill_root / "phases" / "05-pipeline.md").read_text()
    ga_dir = skill_root / "templates" / "github-actions"
    templates = [t for t in sorted(ga_dir.iterdir()) if t.is_file()]
    assert len(templates) > 0, "No GitHub Actions templates found"
    for template in templates:
        ref = f"templates/github-actions/{template.name}"
        assert ref in phase5, f"Orphan GH Actions template: {template.name} not referenced in 05-pipeline.md"


def test_quick_phase_dockerfile_templates_referenced(skill_root: Path):
    """Every Dockerfile template is referenced in quick-02-execute.md."""
    quick_exec = (skill_root / "phases" / "quick-02-execute.md").read_text()
    docker_dir = skill_root / "templates" / "dockerfiles"
    templates = [t for t in sorted(docker_dir.iterdir()) if t.is_file()]
    assert len(templates) > 0, "No Dockerfile templates found"
    for template in templates:
        ref = f"templates/dockerfiles/{template.name}"
        assert ref in quick_exec, (
            f"Dockerfile template {template.name} not referenced in quick-02-execute.md"
        )


def test_quick_phase_k8s_templates_referenced(skill_root: Path):
    """Every K8s template is referenced in quick-02-execute.md."""
    quick_exec = (skill_root / "phases" / "quick-02-execute.md").read_text()
    k8s_dir = skill_root / "templates" / "k8s"
    templates = [t for t in sorted(k8s_dir.iterdir()) if t.is_file()]
    assert len(templates) > 0, "No K8s templates found"
    for template in templates:
        ref = f"templates/k8s/{template.name}"
        assert ref in quick_exec, (
            f"K8s template {template.name} not referenced in quick-02-execute.md"
        )

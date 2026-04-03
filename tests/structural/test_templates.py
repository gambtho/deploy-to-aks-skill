"""Template syntax validation.

Validates Dockerfiles, K8s YAML, GitHub Actions workflow, and Bicep files
have expected structural properties.
"""

import re
from pathlib import Path

import yaml

EXPECTED_DOCKERFILES = [
    "java.Dockerfile",
    "node.Dockerfile",
    "python.Dockerfile",
    "dotnet.Dockerfile",
    "go.Dockerfile",
    "rust.Dockerfile",
]

EXPECTED_BICEP_FILES = [
    "acr.bicep",
    "aks.bicep",
    "identity.bicep",
    "keyvault.bicep",
    "main.bicep",
    "main.bicepparam",
    "postgresql.bicep",
    "redis.bicep",
]

EXPECTED_GA_PLACEHOLDERS = [
    "__ACR_NAME__",
    "__AKS_CLUSTER__",
    "__RG_NAME__",
    "__APP_NAME__",
    "__NAMESPACE__",
]

EXPECTED_OIDC_SECRETS = [
    "secrets.AZURE_CLIENT_ID",
    "secrets.AZURE_TENANT_ID",
    "secrets.AZURE_SUBSCRIPTION_ID",
]


# --- Dockerfile tests ---


def test_all_dockerfiles_exist(skill_root: Path):
    """All 6 Dockerfile templates exist."""
    docker_dir = skill_root / "templates" / "dockerfiles"
    for name in EXPECTED_DOCKERFILES:
        assert (docker_dir / name).is_file(), f"Missing Dockerfile: {name}"


def test_dockerfiles_start_with_from(skill_root: Path):
    """Each Dockerfile has FROM as first non-comment instruction."""
    docker_dir = skill_root / "templates" / "dockerfiles"
    for name in EXPECTED_DOCKERFILES:
        content = (docker_dir / name).read_text()
        # Find first non-comment, non-blank line
        for line in content.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            assert stripped.upper().startswith("FROM"), (
                f"{name}: first instruction is '{stripped}', expected FROM"
            )
            break


def test_dockerfiles_are_multistage(skill_root: Path):
    """Each Dockerfile has at least 2 FROM instructions (multi-stage build)."""
    docker_dir = skill_root / "templates" / "dockerfiles"
    for name in EXPECTED_DOCKERFILES:
        content = (docker_dir / name).read_text()
        from_count = len(re.findall(r"^FROM\s", content, re.MULTILINE | re.IGNORECASE))
        assert from_count >= 2, (
            f"{name} has {from_count} FROM instruction(s) — expected at least 2 (multi-stage)"
        )


# --- K8s YAML tests ---


def test_k8s_templates_parse_as_yaml(skill_root: Path):
    """K8s templates parse as valid YAML."""
    k8s_dir = skill_root / "templates" / "k8s"
    for template in sorted(k8s_dir.iterdir()):
        if not template.suffix == ".yaml":
            continue
        content = template.read_text()
        try:
            data = yaml.safe_load(content)
            assert data is not None, f"{template.name} parsed as empty YAML"
        except yaml.YAMLError as e:
            raise AssertionError(f"{template.name} is not valid YAML: {e}")


def test_k8s_templates_have_kind_and_apiversion(skill_root: Path):
    """Each K8s template has 'kind' and 'apiVersion' fields."""
    k8s_dir = skill_root / "templates" / "k8s"
    for template in sorted(k8s_dir.iterdir()):
        if not template.suffix == ".yaml":
            continue
        data = yaml.safe_load(template.read_text())
        assert "kind" in data, f"{template.name} missing 'kind' field"
        assert "apiVersion" in data, f"{template.name} missing 'apiVersion' field"


# --- GitHub Actions workflow tests ---


def test_deploy_yml_parses_as_yaml(skill_root: Path):
    """deploy.yml parses as valid YAML."""
    deploy = skill_root / "templates" / "github-actions" / "deploy.yml"
    data = yaml.safe_load(deploy.read_text())
    assert data is not None, "deploy.yml parsed as empty YAML"


def test_deploy_yml_has_expected_top_level_keys(skill_root: Path):
    """deploy.yml has name, on, permissions, env, jobs keys.

    Note: YAML parses 'on' as boolean True, so we check for True.
    """
    deploy = skill_root / "templates" / "github-actions" / "deploy.yml"
    data = yaml.safe_load(deploy.read_text())
    expected_keys = {"name", True, "permissions", "env", "jobs"}
    actual_keys = set(data.keys())
    missing = expected_keys - actual_keys
    assert not missing, f"deploy.yml missing top-level keys: {missing}"


def test_deploy_yml_has_build_and_deploy_job(skill_root: Path):
    """deploy.yml has a 'build-and-deploy' job."""
    deploy = skill_root / "templates" / "github-actions" / "deploy.yml"
    data = yaml.safe_load(deploy.read_text())
    assert "build-and-deploy" in data.get("jobs", {}), (
        "deploy.yml missing 'build-and-deploy' job"
    )


def test_deploy_yml_references_oidc_secrets(skill_root: Path):
    """deploy.yml references the 3 OIDC secrets in ${{ secrets.* }} syntax."""
    deploy = skill_root / "templates" / "github-actions" / "deploy.yml"
    content = deploy.read_text()
    for secret in EXPECTED_OIDC_SECRETS:
        assert secret in content, (
            f"deploy.yml missing OIDC secret reference: {secret}"
        )


def test_deploy_yml_contains_all_placeholders(skill_root: Path):
    """deploy.yml contains all 5 expected __PLACEHOLDER__ values."""
    deploy = skill_root / "templates" / "github-actions" / "deploy.yml"
    content = deploy.read_text()
    for placeholder in EXPECTED_GA_PLACEHOLDERS:
        assert placeholder in content, (
            f"deploy.yml missing placeholder: {placeholder}"
        )


# --- Bicep tests ---


def test_all_bicep_files_exist(skill_root: Path):
    """All 8 Bicep files are present."""
    bicep_dir = skill_root / "templates" / "bicep"
    for name in EXPECTED_BICEP_FILES:
        assert (bicep_dir / name).is_file(), f"Missing Bicep file: {name}"


def test_bicep_files_have_declarations(skill_root: Path):
    """.bicep files contain at least one param, resource, or module declaration."""
    bicep_dir = skill_root / "templates" / "bicep"
    for template in sorted(bicep_dir.iterdir()):
        if template.suffix != ".bicep":
            continue
        content = template.read_text()
        has_param = re.search(r"^param\s", content, re.MULTILINE)
        has_resource = re.search(r"^resource\s", content, re.MULTILINE)
        has_module = re.search(r"^module\s", content, re.MULTILINE)
        assert has_param or has_resource or has_module, (
            f"{template.name} has no param, resource, or module declaration"
        )


def test_bicepparam_files_have_using(skill_root: Path):
    """.bicepparam files contain a 'using' declaration."""
    bicep_dir = skill_root / "templates" / "bicep"
    for template in sorted(bicep_dir.iterdir()):
        if template.suffix != ".bicepparam":
            continue
        content = template.read_text()
        assert re.search(r"^using\s", content, re.MULTILINE), (
            f"{template.name} missing 'using' declaration"
        )

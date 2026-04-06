"""LLM behavioral tests for Phase 1: Discover.

Each test feeds a minimal fixture project to the skill via Copilot CLI
and asserts the discovery output contains expected framework-specific
properties.
"""

import pytest

DISCOVER_PROMPT = (
    "Load the skill at skills/deploy-to-aks/SKILL.md. "
    "I want to deploy this project to AKS. "
    "Run Phase 1 only. Do not ask questions — use defaults. "
    "Output the discovery summary and stop."
)


@pytest.mark.parametrize("workspace", ["spring-boot-minimal"], indirect=True)
def test_spring_boot_detection(workspace, run_copilot):
    """Phase 1 detects Spring Boot, port 8080, and Maven/pom.xml."""
    output = run_copilot(DISCOVER_PROMPT, workdir=workspace)
    output_lower = output.lower()
    assert "spring boot" in output_lower, f"Missing 'Spring Boot' in output:\n{output}"
    assert "8080" in output, f"Missing port '8080' in output:\n{output}"
    assert "pom.xml" in output_lower or "maven" in output_lower, f"Missing 'pom.xml' or 'Maven' in output:\n{output}"


@pytest.mark.parametrize("workspace", ["express-minimal"], indirect=True)
def test_express_detection(workspace, run_copilot):
    """Phase 1 detects Express, port 3000, and package.json."""
    output = run_copilot(DISCOVER_PROMPT, workdir=workspace)
    output_lower = output.lower()
    assert "express" in output_lower, f"Missing 'Express' in output:\n{output}"
    assert "3000" in output, f"Missing port '3000' in output:\n{output}"
    assert "package.json" in output_lower, f"Missing 'package.json' in output:\n{output}"


@pytest.mark.parametrize("workspace", ["fastapi-minimal"], indirect=True)
def test_fastapi_detection(workspace, run_copilot):
    """Phase 1 detects FastAPI, port 8000, and pyproject.toml."""
    output = run_copilot(DISCOVER_PROMPT, workdir=workspace)
    output_lower = output.lower()
    assert "fastapi" in output_lower, f"Missing 'FastAPI' in output:\n{output}"
    assert "8000" in output, f"Missing port '8000' in output:\n{output}"
    assert "pyproject.toml" in output_lower, f"Missing 'pyproject.toml' in output:\n{output}"


@pytest.mark.parametrize("workspace", ["go-gin-minimal"], indirect=True)
def test_go_gin_detection(workspace, run_copilot):
    """Phase 1 detects Gin/Go, port 8080, and go.mod."""
    output = run_copilot(DISCOVER_PROMPT, workdir=workspace)
    output_lower = output.lower()
    assert "gin" in output_lower or "go" in output_lower, f"Missing 'Gin' or 'Go' in output:\n{output}"
    assert "8080" in output, f"Missing port '8080' in output:\n{output}"
    assert "go.mod" in output_lower, f"Missing 'go.mod' in output:\n{output}"


@pytest.mark.parametrize("workspace", ["dotnet-minimal"], indirect=True)
def test_dotnet_detection(workspace, run_copilot):
    """Phase 1 detects ASP.NET/.NET, port 5000, and .csproj."""
    output = run_copilot(DISCOVER_PROMPT, workdir=workspace)
    output_lower = output.lower()
    assert "asp.net" in output_lower or ".net" in output_lower, f"Missing 'ASP.NET' or '.NET' in output:\n{output}"
    assert "5000" in output, f"Missing port '5000' in output:\n{output}"
    assert ".csproj" in output_lower, f"Missing '.csproj' in output:\n{output}"

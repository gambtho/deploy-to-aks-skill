"""LLM behavioral tests for Phase 3: Containerize.

Feeds a Spring Boot fixture project and asserts the generated Dockerfile
has expected properties: FROM instructions, multi-stage build, correct port,
non-root user.
"""

import pytest

CONTAINERIZE_PROMPT = (
    "Load the skill at skills/deploy-to-aks/SKILL.md. "
    "I want to deploy this project to AKS. "
    "Run Phase 3 only. The project is a Spring Boot app on port 8080 using Java 17 and Maven. "
    "Do not ask questions — use defaults. "
    "Generate the Dockerfile content and output it. Stop after outputting the Dockerfile."
)


@pytest.mark.parametrize("workspace", ["spring-boot-minimal"], indirect=True)
def test_dockerfile_generation(workspace, run_copilot):
    """Phase 3 generates a multi-stage Dockerfile with correct port and non-root user."""
    output = run_copilot(CONTAINERIZE_PROMPT, workdir=workspace)
    output_upper = output.upper()

    # Must have FROM instruction
    assert "FROM" in output_upper, f"Missing FROM instruction in output:\n{output}"

    # Must be multi-stage (at least 2 FROM instructions)
    from_count = output_upper.count("\nFROM ") + (1 if output_upper.lstrip().startswith("FROM ") else 0)
    assert from_count >= 2, (
        f"Expected multi-stage build (>=2 FROM), found {from_count} in output:\n{output}"
    )

    # Must expose port 8080
    assert "8080" in output, f"Missing port 8080 in output:\n{output}"

    # Should have non-root user setup (USER instruction or adduser/useradd/groupadd)
    output_lower = output.lower()
    has_user = "user " in output_lower or "adduser" in output_lower or "useradd" in output_lower
    assert has_user, f"Missing non-root user setup in output:\n{output}"

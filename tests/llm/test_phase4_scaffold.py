"""LLM behavioral tests for Phase 4: Scaffold.

Feeds a Spring Boot fixture project and asserts the generated K8s manifests
have expected properties: Deployment + Service, correct port, resource limits.
"""

import pytest

SCAFFOLD_PROMPT = (
    "Load the skill at skills/deploy-to-aks/SKILL.md. "
    "I want to deploy this project to AKS. "
    "Run Phase 4 only. The project is a Spring Boot app named 'demo' on port 8080. "
    "AKS flavor is Automatic. No backing services. "
    "Do not ask questions — use defaults. "
    "Generate the Kubernetes manifests and output them. Stop after outputting the manifests."
)


@pytest.mark.parametrize("workspace", ["spring-boot-minimal"], indirect=True)
def test_k8s_manifest_generation(workspace, run_copilot):
    """Phase 4 generates Deployment + Service YAML with correct port and resource limits."""
    output = run_copilot(SCAFFOLD_PROMPT, workdir=workspace)
    output_lower = output.lower()

    # Must contain Deployment manifest
    assert "kind: deployment" in output_lower, (
        f"Missing 'kind: Deployment' in output:\n{output}"
    )

    # Must contain Service manifest
    assert "kind: service" in output_lower, (
        f"Missing 'kind: Service' in output:\n{output}"
    )

    # Must reference port 8080
    assert "8080" in output, f"Missing port 8080 in output:\n{output}"

    # Should have resource limits (resources.limits or resources.requests)
    has_resources = "resources:" in output_lower and ("limits:" in output_lower or "requests:" in output_lower)
    assert has_resources, f"Missing resource limits/requests in output:\n{output}"

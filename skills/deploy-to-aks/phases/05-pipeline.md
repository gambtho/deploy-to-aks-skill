# Phase 5: Pipeline

## Goal

Generate a GitHub Actions workflow for CI/CD and optionally configure OIDC federation for passwordless Azure authentication.

---

## Step 1: Check for existing workflows

Scan `.github/workflows/` for any existing workflow files.

- **If a deploy workflow already exists** — validate its structure, check for correctness against current infrastructure values, and extend it rather than replacing it.
- **If only a build/test workflow exists** — add a new deployment workflow alongside it. Do not modify the existing build/test workflow.
- **If no workflows exist** — create `.github/workflows/` directory and generate a fresh deploy workflow.

Use Glob to find `**/.github/workflows/*.yml` and `**/.github/workflows/*.yaml`. Read any matches and summarize what they do before proceeding.

---

## Step 2: Generate deploy workflow

Reference `templates/github-actions/deploy.yml` from this skill.

Customize all placeholders with real values discovered in Phase 1 and scaffolded in Phase 4:

| Placeholder       | Source                                      |
| ----------------- | ------------------------------------------- |
| `__ACR_NAME__`    | ACR name from Phase 1 discovery or Phase 4  |
| `__AKS_CLUSTER__` | AKS cluster name from Phase 1               |
| `__RG_NAME__`     | Resource group from Phase 1                 |
| `__NAMESPACE__`   | Kubernetes namespace from Phase 4 scaffold  |
| `__APP_NAME__`    | Application name from Phase 1               |

### Workflow filename

Choose the filename based on what already exists in `.github/workflows/`:

- **No existing deploy workflow:** use `deploy.yml`
- **Existing workflow named `deploy.yml`:** use `deploy-aks-<flavor>.yml` (e.g., `deploy-aks-automatic.yml`)
- **Developer chose to create alongside existing workflows (Phase 1):** use `deploy-aks-<flavor>.yml` to avoid any naming collision

Write the customized workflow to `.github/workflows/<chosen-filename>`.

Show the developer the final workflow content and confirm before writing.

---

## Step 3: Explain OIDC

Before offering OIDC setup, explain why it is the recommended approach:

- **No passwords to rotate** — federated credentials use short-lived tokens issued by Azure AD, eliminating the need for client secrets with expiration dates.
- **Time-limited tokens** — each token is scoped to a single workflow run and expires automatically, reducing the blast radius of any compromise.
- **No secret sprawl** — only three non-sensitive IDs are stored in GitHub (client ID, tenant ID, subscription ID), none of which grant access on their own.
- **Azure AD-backed** — authentication flows through Azure AD's full policy engine, including conditional access and audit logging.

---

## Step 4: Optional OIDC setup

Ask the developer: *"Would you like to configure OIDC federation for passwordless Azure auth from GitHub Actions?"*

If yes, proceed through each command below with a **confirmation gate** — show the command, explain what it does, and wait for approval before executing. The developer can choose to run any command manually instead.

### 4a. Create Azure AD application

```bash
az ad app create --display-name "<app-name>-github-deploy"
```

Capture the `appId` from the output for subsequent steps.

### 4b. Create service principal

```bash
az ad sp create --id <app-id>
```

Capture the `id` (object ID) of the service principal from the output.

### 4c. Create federated credential

```bash
az ad app federated-credential create --id <app-id> --parameters '{
  "name": "github-actions-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<org>/<repo>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "GitHub Actions deploy from main branch"
}'
```

Replace `<org>/<repo>` with the actual GitHub repository path detected from `git remote`.

### 4d. Assign Contributor role

```bash
az role assignment create \
  --assignee <sp-id> \
  --role Contributor \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg-name>
```

This grants the service principal permission to manage resources within the target resource group.

### 4e. Store IDs in GitHub secrets

```bash
gh secret set AZURE_CLIENT_ID --body "<app-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
```

Verify secrets were set:

```bash
gh secret list
```

Confirm that `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` all appear in the output.

---

## Step 5: Verify

Offer to trigger a manual workflow run to validate the full pipeline end-to-end:

```bash
gh workflow run <workflow-filename>
```

Then monitor the run:

```bash
gh run watch
```

If the run fails, read the logs with `gh run view --log-failed` and work through the failure with the developer before marking this phase complete.

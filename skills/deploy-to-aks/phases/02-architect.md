# Phase 2: Architect

## Goal

Present the full infrastructure plan **visually** before generating any Bicep or workflow files. The developer must see exactly what will be provisioned, how services connect, and what it will cost — then explicitly approve before proceeding.

**No files are generated in this phase.** This phase produces only a visual diagram, a cost estimate, and developer approval.

---

## Step 1: Select Azure Services

Using the application profile collected in Phase 1 (backing services, app type, scale expectations), map each need to a concrete Azure resource. Use the decision matrix below.

### Service Decision Matrix

| Application Need | Azure Service | Dev Tier | Production Tier |
|---|---|---|---|
| App hosting | AKS | Automatic (simplest) or Standard (if developer chose) | Same — tier choice persists |
| Container registry | Azure Container Registry (ACR) | Basic | Standard |
| PostgreSQL database | Azure Database for PostgreSQL Flexible Server | Burstable B1ms (1 vCore, 2 GiB) | General Purpose D2s_v3 (2 vCores, 8 GiB) |
| MongoDB database | Azure Cosmos DB (MongoDB API) | Serverless | Provisioned (400+ RU/s) |
| Redis / caching | Azure Cache for Redis | Basic C0 (250 MB) | Standard C1 (1 GB, replicated) |
| Secrets / key management | Azure Key Vault | Standard | Standard |
| Blob / file storage | Azure Storage Account | Standard LRS | Standard ZRS |
| Monitoring (always included) | Log Analytics Workspace + Application Insights | Per-GB ingestion (5 GB free) | Per-GB ingestion (5 GB free) |
| Container identity | Managed Identity (User-Assigned) | Free | Free |

### Selection Rules

1. **AKS + ACR + Monitoring are always selected.** Every deployment gets these three.
2. **Managed Identity is always selected.** Workload Identity federation is the only supported auth pattern — no connection strings in environment variables.
3. **Key Vault is selected whenever the app has secrets** (API keys, third-party credentials, certificates). If the only secrets are Azure service connections, Workload Identity handles those and Key Vault can be omitted.
4. **Only select backing services the app actually uses.** Do not provision a PostgreSQL server for an app that has no database.
5. **Default to dev tiers.** Only use production tiers if the developer explicitly requests production-grade infrastructure or indicates high availability requirements.
6. **Document every selection.** Record each service, its tier, and the reason it was selected in a structured list that will feed into the cost estimate.

### Output: Selected Services List

After applying the matrix, produce a list in this format (store in memory for subsequent steps):

```
Selected Services:
- AKS Automatic (control plane + 2 vCPU compute) — app hosting
- ACR Basic — container image storage
- PostgreSQL Flexible Server Burstable B1ms — primary database (detected in Phase 1)
- Azure Cache for Redis Basic C0 — session store (detected in Phase 1)
- Key Vault Standard — app holds third-party API keys
- Managed Identity (User-Assigned) — workload identity for all service connections
- Log Analytics + Application Insights — monitoring (always included)
```

---

## Step 2: Generate Architecture Diagram

Generate a mermaid architecture diagram so the developer can see the full topology before any infrastructure code is written.

### 2a: Read the Template

Read the file `templates/mermaid/architecture-diagram.md` from the skill's directory. This template contains a mermaid flowchart with placeholder tokens.

### 2b: Replace Placeholders

Substitute every placeholder with actual values derived from Phase 1 discovery and Step 1 selections:

| Placeholder | Source | Example |
|---|---|---|
| `{{APP_NAME}}` | Application name from Phase 1 | `contoso-api` |
| `{{ACR_NAME}}` | Derived: app name sanitized for ACR (lowercase, no hyphens, 5-50 chars) | `contosoapiacr` |
| `{{AKS_TYPE}}` | Developer's AKS mode choice | `Automatic` or `Standard` |
| `{{AKS_CLUSTER_NAME}}` | Derived: `aks-{app-name}` | `aks-contoso-api` |
| `{{RESOURCE_GROUP}}` | Derived: `rg-{app-name}` | `rg-contoso-api` |
| `{{NAMESPACE}}` | Kubernetes namespace for the app | `contoso-api` |
| `{{BACKING_SERVICES}}` | Comma-separated list of Azure backing services | `PostgreSQL, Redis, Key Vault` |
| `{{INGRESS_TYPE}}` | `Gateway API` for Automatic, `Ingress Controller` for Standard | `Gateway API` |
| `{{ENVIRONMENT}}` | `dev` or `production` | `dev` |

### 2c: Diagram Topology Requirements

The generated diagram **must** show:

1. **External users** on the left, with an arrow into the cluster boundary.
2. **Ingress layer** — labeled "Gateway API" (Automatic) or "Ingress Controller / Load Balancer" (Standard) — as the entry point inside the cluster boundary.
3. **AKS cluster boundary** — a visible box labeled with the cluster name and AKS type containing:
   - The ingress layer.
   - One or more **Deployment** boxes (one per container/service discovered in Phase 1).
   - A **Managed Identity** badge attached to the deployments.
4. **ACR** — positioned above or beside the cluster box, with:
   - A "push" arrow from GitHub Actions (CI/CD) to ACR.
   - A "pull" arrow from ACR into the AKS cluster.
5. **Backing Azure services** — each as a separate box outside the cluster boundary (PostgreSQL, Cosmos DB, Redis, Key Vault, Storage, etc.), connected to the relevant Deployment(s) via dashed arrows labeled "Workload Identity".
6. **Monitoring** — Log Analytics + Application Insights shown as a box receiving telemetry from the cluster and backing services.

### 2d: Render the Diagram

Output the fully-resolved mermaid diagram as a fenced code block in the terminal. The developer sees the architecture inline — no browser required.

If the diagram is complex (many backing services), also output a simplified text version as a fallback.

### 2e: Validate

After rendering, verify the mermaid syntax is valid by checking that all node references are consistent (no dangling edges to undefined nodes). If a backing service was removed from the architecture contract, ensure its node and edges are also removed from the diagram.

---

## Step 3: Compute Cost Estimate

### 3a: Load Pricing Reference

Read the file `reference/cost-reference.md` from the skill's directory. This contains per-service monthly cost estimates for dev and production tiers.

### 3b: Sum Selected Services

For each service selected in Step 1, look up its monthly cost from the reference. Apply these rules:

1. **Always include AKS control plane cost** (Automatic: ~$117/mo, Standard: ~$73/mo).
2. **Always include default compute** — assume 2 vCPU / 4 GiB baseline unless the developer specified otherwise. Use the per-vCPU cost from the reference.
3. **Always include ACR** at the selected tier.
4. **Always include monitoring** — assume 5 GB/month ingestion (within free tier) unless the developer expects higher volume.
5. **Add each backing service** at its selected tier.
6. **Round each line item to the nearest dollar.**
7. **Sum for a total monthly estimate.**

### 3c: Format the Estimate

Produce a cost breakdown in table format:

```
┌─────────────────────────────────────────────┬───────────┐
│ Service                                     │ Est. $/mo │
├─────────────────────────────────────────────┼───────────┤
│ AKS Automatic (control plane)               │      $117 │
│ Compute (2 vCPU / 4 GiB)                   │       $44 │
│ ACR Basic                                   │        $5 │
│ PostgreSQL Flexible Server (B1ms)           │       $13 │
│ Azure Cache for Redis (Basic C0)            │       $16 │
│ Key Vault (estimated ops)                   │        $1 │
│ Managed Identity                            │     Free  │
│ Log Analytics (≤5 GB free tier)             │     Free  │
│ Application Insights (≤5 GB free tier)      │     Free  │
├─────────────────────────────────────────────┼───────────┤
│ TOTAL (estimated)                           │     ~$196 │
└─────────────────────────────────────────────┴───────────┘
```

**Always append the disclaimer:** *Costs are estimates based on published Azure pricing. Actual costs depend on usage. Verify at [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/).*

---

## Step 4: Present to Developer

### 4a: Show the Diagram

The mermaid diagram was already rendered inline in Step 2d. Reference it here — do not re-render unless the developer requested changes in Step 5.

### 4b: Terminal Summary

Print a concise summary in the terminal covering:

1. **Selected services** — bulleted list with tier and purpose.
2. **Architecture highlights** — e.g., "Traffic enters via Gateway API, routed to 1 deployment in namespace `contoso-api`. PostgreSQL and Redis accessed via Workload Identity. Images pulled from ACR `contosoapiacr`."
3. **Cost estimate table** — the table from Step 3.
4. **Explicit prompt:** "Review the architecture diagram and cost estimate above. Do you want to make any changes, or shall I proceed to Phase 3 (Containerize)?"

---

## Step 5: Iterate

If the developer requests changes:

1. **Update the selected services list** — add, remove, or change tiers as requested.
2. **Regenerate the architecture diagram** — repeat Step 2 with the updated topology.
3. **Recompute the cost estimate** — repeat Step 3 with the updated services.
4. **Re-present** — repeat Step 4.

Common change requests:
- "Switch to AKS Standard" → update AKS type, change ingress to Ingress Controller, adjust control plane cost.
- "Drop Redis" → remove from services, diagram, and cost.
- "Add blob storage" → add Storage Account to services, diagram, and cost.
- "Use production tiers" → upgrade all tiers, recompute costs.
- "That's too expensive" → suggest dropping optional services or switching to cheaper tiers; recompute.

Loop through Steps 1-4 until the developer is satisfied. There is no limit on iterations.

---

## Step 6: Get Approval

### HARD GATE

**Do NOT proceed to Phase 3 until the developer gives explicit approval.**

Acceptable approval signals:
- "Looks good, proceed"
- "Approved"
- "Go ahead"
- "LGTM"
- "Yes, generate the files"
- Any clear affirmative that references proceeding or generating

**Not** acceptable:
- Silence (do not assume approval — ask again)
- "Maybe" or "I think so" (ask for a definitive yes/no)
- "Let me think about it" (wait)
- Asking an unrelated question (answer it, then re-prompt for approval)

### On Approval

When the developer approves:

1. Record the final selected services list, tiers, AKS type, and all derived names as the **Architecture Contract**. This contract is the single source of truth for Phase 3.
2. Confirm: "Architecture approved. Moving to Phase 3: Containerize."
3. Transition to Phase 3.

### On Rejection

If the developer says "stop", "cancel", or "start over":

1. Confirm whether they want to restart from Phase 1 or just redo Phase 2.
2. Act accordingly.

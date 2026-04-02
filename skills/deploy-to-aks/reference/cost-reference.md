# Azure Cost Reference

> **Last updated:** 2025-06  
> **Region basis:** East US (prices vary by region — East US is used as the baseline)  
> **Currency:** USD  
> **Billing period:** Monthly estimates (730 hours/month)

This document provides estimated monthly costs for Azure services commonly provisioned by the deploy-to-AKS skill. Use these figures for Phase 2 cost estimation. Always direct developers to the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for precise, up-to-date quotes.

---

## AKS (Azure Kubernetes Service)

### Control Plane

| Mode | Monthly Cost | Notes |
|---|---|---|
| AKS Automatic | ~$116.80/mo | Includes managed node provisioning, Gateway API, managed Prometheus & Grafana |
| AKS Standard (Free tier) | $0/mo | No SLA, no uptime guarantee — suitable for dev/test only |
| AKS Standard (Standard tier) | ~$73/mo | Includes uptime SLA (99.95% with availability zones), recommended for production |
| AKS Standard (Premium tier) | ~$146/mo | Includes long-term support, advanced networking features |

### Compute (Node Pool)

Costs depend on the VM SKU backing the node pool. For AKS Automatic, Azure selects VMs automatically but the per-vCPU cost still applies.

| SKU | vCPUs | Memory (GiB) | Monthly Cost | Per-vCPU/mo |
|---|---|---|---|---|
| Standard_B2s | 2 | 4 | ~$30.37/mo | ~$15.19 |
| Standard_B2ms | 2 | 8 | ~$60.74/mo | ~$30.37 |
| Standard_D2s_v5 | 2 | 8 | ~$70.08/mo | ~$35.04 |
| Standard_D4s_v5 | 4 | 16 | ~$140.16/mo | ~$35.04 |
| Standard_D2as_v5 | 2 | 8 | ~$62.78/mo | ~$31.39 |
| Standard_D4as_v5 | 4 | 16 | ~$125.56/mo | ~$31.39 |

**Default assumption for cost estimates:** 2 vCPU / 4 GiB node (Standard_B2s) at ~$30/mo for dev; 2 vCPU / 8 GiB node (Standard_D2s_v5) at ~$70/mo for production.

---

## Container Registry (ACR)

| Tier | Monthly Cost | Included Storage | Notes |
|---|---|---|---|
| Basic | ~$5/mo | 10 GiB | Suitable for dev/test, limited throughput |
| Standard | ~$20/mo | 100 GiB | Recommended for production, geo-replication not included |
| Premium | ~$50/mo | 500 GiB | Geo-replication, content trust, private link |

**Default:** Basic for dev, Standard for production.

---

## Database — PostgreSQL

### Azure Database for PostgreSQL Flexible Server

| Tier / SKU | vCores | Memory (GiB) | Monthly Cost | Notes |
|---|---|---|---|---|
| Burstable B1ms | 1 | 2 | ~$13/mo | Dev/test workloads, variable CPU |
| Burstable B2s | 2 | 4 | ~$26/mo | Small production workloads |
| General Purpose D2s_v3 | 2 | 8 | ~$100/mo | Production, consistent performance |
| General Purpose D4s_v3 | 4 | 16 | ~$200/mo | Larger production workloads |
| Memory Optimized E2s_v3 | 2 | 16 | ~$130/mo | Memory-heavy queries, analytics |

**Storage:** ~$0.115/GiB/mo (provisioned). Minimum 32 GiB (~$3.68/mo).

**Backup:** Locally redundant backup included. Geo-redundant backup adds ~$0.10/GiB/mo.

**Default:** Burstable B1ms + 32 GiB storage (~$17/mo) for dev; GP D2s_v3 + 64 GiB (~$107/mo) for production.

---

## Database — MongoDB (Cosmos DB)

### Azure Cosmos DB for MongoDB (vCore-based or RU-based)

#### Serverless (RU-based)

| Metric | Cost | Notes |
|---|---|---|
| Request Units | ~$0.25 per 1 million RU | Pay only for consumed throughput |
| Storage | ~$0.25/GiB/mo | Per GiB of data stored |

**Typical dev cost:** $1-5/mo depending on usage. Ideal for low-traffic, bursty workloads.

#### Provisioned Throughput (RU-based)

| Provisioned RU/s | Monthly Cost | Notes |
|---|---|---|
| 400 RU/s (minimum) | ~$23/mo | Single region, manual throughput |
| 1,000 RU/s | ~$58/mo | Single region |
| 4,000 RU/s (autoscale max) | ~$87/mo | Autoscale bills at 10% of max when idle |

**Storage:** ~$0.25/GiB/mo.

#### vCore-based

| Tier | vCores | Memory (GiB) | Monthly Cost | Notes |
|---|---|---|---|---|
| M25 (Burstable) | Shared | 2 | ~$14/mo | Dev/test |
| M30 | 2 | 8 | ~$109/mo | Small production |
| M40 | 4 | 16 | ~$218/mo | Production |

**Default:** Serverless for dev; Provisioned 400 RU/s or vCore M25 for production (developer choice).

---

## Cache — Azure Cache for Redis

| Tier / SKU | Size | Monthly Cost | Notes |
|---|---|---|---|
| Basic C0 | 250 MB | ~$16/mo | No SLA, no replication — dev/test only |
| Basic C1 | 1 GB | ~$34/mo | No SLA, no replication |
| Standard C0 | 250 MB | ~$40/mo | Replicated, 99.9% SLA |
| Standard C1 | 1 GB | ~$68/mo | Replicated, 99.9% SLA |
| Premium P1 | 6 GB | ~$225/mo | Clustering, persistence, VNet |

**Default:** Basic C0 (~$16/mo) for dev; Standard C1 (~$68/mo) for production.

---

## Security

### Azure Key Vault

| Operation | Cost | Notes |
|---|---|---|
| Secrets operations | ~$0.03 per 10,000 operations | Standard tier |
| Key operations (RSA 2048) | ~$0.03 per 10,000 operations | Software-protected |
| Key operations (HSM) | ~$1.00 per 10,000 operations | HSM-protected |
| Certificate operations | ~$3.00 per renewal | Auto-renewal |
| Storage | Included | Up to 25,000 objects per vault |

**Typical monthly cost:** $0.30 - $3.00/mo for most applications (well under 100K ops/mo).

**Default estimate:** ~$1/mo for cost planning purposes.

### Managed Identity

| Component | Cost |
|---|---|
| User-Assigned Managed Identity | **Free** |
| System-Assigned Managed Identity | **Free** |
| Workload Identity Federation | **Free** |
| Token requests | **Free** |

Managed Identity has **zero cost**. Always include it, never charge for it.

---

## Monitoring

### Log Analytics Workspace

| Tier | Cost | Notes |
|---|---|---|
| Per-GB ingestion | ~$2.76/GiB | First 5 GiB/mo free per billing account |
| Data retention (31 days) | Included | Default 31-day retention, no extra charge |
| Data retention (90 days) | ~$0.10/GiB/mo | Extended retention beyond 31 days |
| Data retention (180+ days) | ~$0.20/GiB/mo | Long-term retention |

### Application Insights

| Component | Cost | Notes |
|---|---|---|
| Data ingestion | ~$2.76/GiB | Shares the 5 GiB free allowance with Log Analytics |
| Multi-step web tests | ~$10/test/mo | Optional, not included by default |
| Continuous export | ~$0.25/GiB | Optional, not included by default |

**Default estimate for dev:** Free (assuming <=5 GiB/mo ingestion across Log Analytics + App Insights).

**Default estimate for production:** ~$14/mo (assuming ~10 GiB/mo ingestion, minus 5 GiB free = 5 GiB * $2.76).

---

## Networking

### AKS Automatic

| Component | Cost | Notes |
|---|---|---|
| Gateway API (managed) | Included | Part of AKS Automatic, no extra charge |
| Managed public IP | Included | Provisioned automatically |
| Egress (first 5 GB/mo) | Free | Outbound data transfer |
| Egress (5-10 TB/mo) | ~$0.087/GiB | Standard inter-region pricing |

### AKS Standard

| Component | Monthly Cost | Notes |
|---|---|---|
| Standard Load Balancer | ~$18/mo | Base charge ($0.025/hr) |
| Load Balancer rules (first 5) | Included | Additional rules ~$7.30/mo each |
| Public IP (Standard SKU) | ~$3.60/mo | $0.005/hr static IP |
| Egress (first 5 GB/mo) | Free | Outbound data transfer |
| Egress (5-10 TB/mo) | ~$0.087/GiB | Standard inter-region pricing |

**Default for AKS Automatic:** $0 additional networking cost (included in control plane).

**Default for AKS Standard:** ~$22/mo (Load Balancer + 1 Public IP).

---

## Storage — Azure Storage Account

| Tier | Redundancy | Cost per GiB/mo | Transaction Cost (per 10K ops) | Notes |
|---|---|---|---|---|
| Hot | LRS | ~$0.018/GiB | ~$0.05 (write), ~$0.004 (read) | Frequently accessed data |
| Hot | ZRS | ~$0.023/GiB | ~$0.05 (write), ~$0.004 (read) | Zone-redundant for production |
| Cool | LRS | ~$0.01/GiB | ~$0.10 (write), ~$0.01 (read) | Infrequently accessed |
| Archive | LRS | ~$0.002/GiB | ~$0.10 (write), ~$5.00 (read) | Rarely accessed, high retrieval cost |

**Default estimate:** ~$1-2/mo for dev (small storage, Hot LRS); scales with data volume in production.

---

## Cost Estimation Rules

When computing cost estimates in Phase 2, follow these rules:

### Always Include (Every Deployment)

1. **AKS control plane** — Automatic (~$117) or Standard ($0 free tier / ~$73 standard tier)
2. **Compute** — At least one node; default to Standard_B2s (~$30/mo) for dev
3. **ACR** — Basic ($5) for dev, Standard ($20) for production
4. **Monitoring** — Log Analytics + App Insights (Free if <=5 GiB/mo, otherwise ~$2.76/GiB)
5. **Managed Identity** — Free (always list it, always show $0)

### Add If Selected

6. **Backing databases** — PostgreSQL, Cosmos DB, etc. at appropriate tier
7. **Cache** — Redis at appropriate tier
8. **Key Vault** — ~$1/mo estimate
9. **Storage Account** — Per estimated volume
10. **Networking** — Only for AKS Standard (LB + Public IP ~$22/mo)

### Formatting Rules

- **Round each line item to the nearest dollar** for the summary table.
- **Always show monthly estimates** — not hourly, not annual.
- **Show "Free" explicitly** for zero-cost services (Managed Identity, monitoring within free tier). Do not omit them.
- **Total line uses "~" prefix** to indicate approximation: `~$196`.
- **Always append the disclaimer:** *"Costs are estimates based on published Azure pricing for East US region as of 2025-06. Actual costs vary by region, usage, and reserved instance discounts. Verify with the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)."*

### Quick Reference: Common Stacks

| Stack | Dev Estimate | Production Estimate |
|---|---|---|
| AKS Automatic + ACR + PostgreSQL | ~$165/mo | ~$310/mo |
| AKS Automatic + ACR + Cosmos DB (Serverless) | ~$155/mo | ~$280/mo |
| AKS Automatic + ACR + PostgreSQL + Redis | ~$180/mo | ~$380/mo |
| AKS Standard + ACR + PostgreSQL | ~$70/mo | ~$285/mo |
| AKS Standard (Free tier) + ACR + PostgreSQL | ~$50/mo | N/A (no SLA) |
| AKS Automatic + ACR only (no backing services) | ~$150/mo | ~$210/mo |

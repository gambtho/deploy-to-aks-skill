# Deploy to AKS Skill - Demo Script

Complete workflow for recording an asciinema demo of the deploy-to-aks skill (quick mode).

## Pre-Demo Setup

### 1. Provision AKS Automatic Test Infrastructure

```bash
cd /home/tng/workspace/deploy-to-aks-skill
./scripts/setup-aks-prerequisites.sh --cluster-name demo-aks-auto --location eastus
```

**Important**: The script will output a Portal link for granting RBAC permissions. You MUST:
1. Click the link to open Azure Portal
2. Grant yourself "Azure Kubernetes Service RBAC Cluster Admin" role
3. Wait ~2 minutes for permissions to propagate
4. Verify with: `kubectl auth can-i create namespaces`

Expected output after permission grant:
```
✓ Azure RBAC check passed - you can create namespaces
```

### 2. Refresh Installed Skill with Latest Fixes

```bash
# Sync updated skill from fix/demo-improvements branch
rsync -av --delete \
  /home/tng/workspace/deploy-to-aks-skill/skills/deploy-to-aks/ \
  ~/.config/opencode/skills/deploy-to-aks/

# Verify the update
ls -la ~/.config/opencode/skills/deploy-to-aks/phases/quick-02-execute.md
```

### 3. Prepare Demo Project

```bash
# Clone a simple web app (or use existing project)
cd ~/demo
git clone https://github.com/your-org/sample-app.git
cd sample-app
```

## Recording the Demo

### 1. Start asciinema Recording

```bash
# Use descriptive filename with timestamp
asciinema rec deploy-aks-demo-$(date +%Y%m%d-%H%M%S).cast
```

### 2. Run the Skill (Quick Mode)

```bash
# Start OpenCode in the project directory
opencode .
```

**In the OpenCode session:**

```
Let's deploy this to my existing AKS cluster using the deploy-to-aks skill in quick mode.

Cluster name: demo-aks-auto
Resource group: demo-aks-auto-rg
```

### 3. Expected Flow (60-90 seconds)

**Phase 1: Scan and Plan (~15-20s)**
- ✅ Project detection (language, framework, dependencies)
- ✅ Azure RBAC check (verify namespace permissions)
- ✅ Architecture diagram (mermaid rendering)
- ✅ Approval prompt

**Phase 2: Execute (~40-60s)**
- 📦 Batch file write (single permission prompt for all files):
  - Multi-stage Dockerfile
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - gateway.yaml (AKS Automatic uses Gateway API)
- 🔨 Docker build and push to ACR
- ☸️ kubectl apply (with streaming output)
- ✅ Verification (pod status, service endpoints)
- 🎉 Success summary

### 4. Stop Recording

```
# Exit OpenCode
exit

# Stop asciinema (Ctrl+D or exit)
```

## Post-Demo Capture

### 1. Export OpenCode Session

```bash
# List recent sessions
opencode session list

# Export the demo session with descriptive name
opencode export <sessionID> > deploy-aks-demo-session-$(date +%Y%m%d-%H%M%S).json
```

### 2. Review the Recording

```bash
# Play back the recording
asciinema play deploy-aks-demo-*.cast

# If satisfied, upload to asciinema.org (optional)
asciinema upload deploy-aks-demo-*.cast
```

### 3. Save Artifacts

```bash
# Create demo artifacts directory
mkdir -p ~/demo-artifacts/$(date +%Y%m%d)
cp deploy-aks-demo-*.cast ~/demo-artifacts/$(date +%Y%m%d)/
cp deploy-aks-demo-session-*.json ~/demo-artifacts/$(date +%Y%m%d)/

# Optional: commit generated files for reference
cd sample-app
git add Dockerfile k8s/
git commit -m "demo: generated deployment artifacts"
```

## Success Criteria

- ✅ Single permission prompt (not 10+)
- ✅ Emojis and progress indicators appear in output
- ✅ Namespace created properly (not default namespace)
- ✅ Docker build succeeds
- ✅ Deployment succeeds
- ✅ Gateway API resource created (not Ingress)
- ✅ Total time: 60-90 seconds
- ✅ No manual intervention required after initial approval

## Troubleshooting

### Permission Issues

If you see repeated permission prompts:
- Check that you're using the refreshed skill (step 2 in Pre-Demo Setup)
- Verify `quick-02-execute.md` contains batch write instructions

### Azure RBAC Errors

If `kubectl auth can-i create namespaces` returns "no":
- Re-run the Portal link from setup script output
- Grant "Azure Kubernetes Service RBAC Cluster Admin" role
- Wait 2 minutes and re-check

### Conditional Access Blocks

If `az role assignment create` fails:
- This is expected and handled by the setup script
- Use the Portal link instead (script provides this automatically)

### Gateway API CRDs Missing

If Gateway resource fails to create:
- AKS Automatic should have Gateway API CRDs pre-installed
- Verify with: `kubectl get crd gateways.gateway.networking.k8s.io`
- If missing, the skill will detect and provide instructions

## Cleanup After Demo

```bash
# Delete the demo cluster (saves cost)
az group delete --name demo-aks-auto-rg --yes --no-wait

# Or keep it for multiple demo takes
az aks stop --name demo-aks-auto --resource-group demo-aks-auto-rg
```

## Next Steps After Successful Demo

1. Merge `fix/demo-improvements` branch to main
2. Embed the asciinema recording in VitePress documentation site
3. Update README.md with link to demo video
4. Tag a new release with demo improvements

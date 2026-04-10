#!/usr/bin/env bash
set -euo pipefail

# setup-aks-prerequisites.sh
#
# Provisions AKS infrastructure (Automatic or Standard) for testing and demoing
# the deploy-to-aks quick deploy mode. Handles Conditional Access environments.
#
# Usage:
#   ./scripts/setup-aks-prerequisites.sh --name myapp --location eastus
#   ./scripts/setup-aks-prerequisites.sh --name myapp --flavor standard
#   ./scripts/setup-aks-prerequisites.sh --name myapp --non-interactive
#   ./scripts/setup-aks-prerequisites.sh --name myapp --cleanup
#   ./scripts/setup-aks-prerequisites.sh --help

# ── Defaults ──────────────────────────────────────────────────────
NAME=""
LOCATION="eastus"
NAMESPACE=""
FLAVOR="automatic"
NON_INTERACTIVE=false
CLEANUP=false

# ── Usage ─────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage: setup-aks-prerequisites.sh [OPTIONS]

Provision AKS infrastructure for quick deploy mode.
Handles Conditional Access environments with interactive portal fallbacks.

Required:
  --name <name>           Base name for all resources

Optional:
  --location <region>     Azure region (default: eastus)
  --flavor <type>         AKS flavor: automatic or standard (default: automatic)
  --namespace <ns>        Kubernetes namespace (default: <name>)
  --non-interactive       Fail fast without portal prompts (for CI/CD)
  --cleanup               Delete the resource group and all resources
  --help                  Show this help message

Examples:
  # Provision AKS Automatic infrastructure
  ./scripts/setup-aks-prerequisites.sh --name myapp --location eastus

  # Provision AKS Standard infrastructure
  ./scripts/setup-aks-prerequisites.sh --name myapp --flavor standard

  # CI/CD mode (no interactive prompts)
  ./scripts/setup-aks-prerequisites.sh --name myapp --non-interactive

  # Clean up everything
  ./scripts/setup-aks-prerequisites.sh --name myapp --cleanup
EOF
    exit 0
}

# ── Argument Parsing ──────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            if [[ $# -lt 2 ]]; then
                echo "Error: --name requires a value." >&2
                exit 1
            fi
            NAME="$2"
            shift 2
            ;;
        --location)
            if [[ $# -lt 2 ]]; then
                echo "Error: --location requires a value." >&2
                exit 1
            fi
            LOCATION="$2"
            shift 2
            ;;
        --flavor)
            if [[ $# -lt 2 ]]; then
                echo "Error: --flavor requires a value." >&2
                exit 1
            fi
            FLAVOR="$2"
            shift 2
            ;;
        --namespace)
            if [[ $# -lt 2 ]]; then
                echo "Error: --namespace requires a value." >&2
                exit 1
            fi
            NAMESPACE="$2"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            echo "Run with --help for usage information." >&2
            exit 1
            ;;
    esac
done

# ── Validation ────────────────────────────────────────────────────
if [[ -z "$NAME" ]]; then
    echo "Error: --name is required." >&2
    echo "Run with --help for usage information." >&2
    exit 1
fi

# Validate flavor
FLAVOR=$(echo "$FLAVOR" | tr '[:upper:]' '[:lower:]')
if [[ "$FLAVOR" != "automatic" && "$FLAVOR" != "standard" ]]; then
    echo "Error: --flavor must be 'automatic' or 'standard' (got: '$FLAVOR')" >&2
    exit 1
fi

# Default namespace to name
NAMESPACE="${NAMESPACE:-$NAME}"

# Derived resource names
RG_NAME="${NAME}-rg"
AKS_NAME="${NAME}-aks"
ACR_NAME="${NAME//[^a-z0-9]/}acr"
IDENTITY_NAME="${NAME}-identity"

# Validate ACR name (Azure requires 5-50 chars, lowercase alphanumeric only)
if [[ ${#ACR_NAME} -lt 5 || ${#ACR_NAME} -gt 50 ]]; then
    echo "Error: Derived ACR name '${ACR_NAME}' must be 5-50 characters (currently ${#ACR_NAME})." >&2
    echo "Adjust --name '${NAME}' so that '${ACR_NAME}' meets this constraint." >&2
    exit 1
fi
if [[ ! "$ACR_NAME" =~ ^[a-z0-9]+$ ]]; then
    echo "Error: Derived ACR name '${ACR_NAME}' must contain only lowercase letters and digits." >&2
    echo "Adjust --name '${NAME}' to use only lowercase alphanumeric characters." >&2
    exit 1
fi

# ── Prerequisite Checks ──────────────────────────────────────────
# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_prerequisites() {
    local missing=()
    command -v az   >/dev/null 2>&1 || missing+=("az (Azure CLI)")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v jq   >/dev/null 2>&1 || missing+=("jq")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required tools:" >&2
        for tool in "${missing[@]}"; do
            echo "  - $tool" >&2
        done
        exit 1
    fi

    # Verify Azure login
    if ! az account show >/dev/null 2>&1; then
        echo "Error: Not logged in to Azure. Run 'az login' first." >&2
        exit 1
    fi
}

# Wait for user to complete portal steps
wait_for_portal_completion() {
    if [[ "$NON_INTERACTIVE" == true ]]; then
        echo -e "${RED}✗${NC} Non-interactive mode: Cannot proceed with manual portal steps" >&2
        exit 1
    fi
    echo ""
    read -p "Press ENTER when you've completed the portal steps to continue..." -r </dev/tty
    echo ""
}

# ── Cleanup ───────────────────────────────────────────────────────
if [[ "$CLEANUP" == true ]]; then
    echo "Deleting resource group '$RG_NAME' and all contained resources..."
    az group delete --name "$RG_NAME" --yes --no-wait
    echo "Deletion initiated (running in background)."
    echo "Removing kubectl context..."
    kubectl config delete-context "$AKS_NAME" 2>/dev/null || true
    kubectl config delete-cluster "$AKS_NAME" 2>/dev/null || true
    kubectl config delete-user "clusterUser_${RG_NAME}_${AKS_NAME}" 2>/dev/null || true
    echo "Done."
    exit 0
fi

# ── Provision ─────────────────────────────────────────────────────
check_prerequisites

TENANT_ID=$(az account show --query tenantId -o tsv)

echo ""
echo "Provisioning AKS ${FLAVOR^} prerequisites..."
echo "  Name:       $NAME"
echo "  Location:   $LOCATION"
echo "  Flavor:     $FLAVOR"
echo "  Namespace:  $NAMESPACE"
echo ""

# 1. Resource Group
echo "▸ Creating resource group '$RG_NAME'..."
az group create \
    --name "$RG_NAME" \
    --location "$LOCATION" \
    --output none

# 2. Azure Container Registry
# Create ACR first so we can attach it during cluster creation
echo "▸ Creating ACR '$ACR_NAME'..."
az acr create \
    --name "$ACR_NAME" \
    --resource-group "$RG_NAME" \
    --sku Basic \
    --output none

# 3. AKS Cluster with ACR attached
# Note: --attach-acr configures AcrPull role automatically, avoiding conditional access issues
# Note: Do NOT enable Azure RBAC - it requires token exchanges that fail with conditional access policies
echo "▸ Creating AKS ${FLAVOR^} cluster '$AKS_NAME' (this takes 5-10 minutes)..."

ACR_ATTACH_FAILED=false

if [[ "$FLAVOR" == "automatic" ]]; then
    if ! az aks create \
        --name "$AKS_NAME" \
        --resource-group "$RG_NAME" \
        --location "$LOCATION" \
        --sku automatic \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --attach-acr "$ACR_NAME" \
        --generate-ssh-keys \
        --output none 2>/tmp/aks-create-error.log; then
        
        # Check if error is due to conditional access
        if grep -q "AADSTS530084\|conditional\|access policy" /tmp/aks-create-error.log 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Cluster created but ACR attachment failed (Conditional Access detected)"
            ACR_ATTACH_FAILED=true
        else
            echo -e "${RED}✗${NC} Cluster creation failed:"
            cat /tmp/aks-create-error.log >&2
            exit 1
        fi
    fi
else
    # AKS Standard with web app routing addon
    if ! az aks create \
        --name "$AKS_NAME" \
        --resource-group "$RG_NAME" \
        --location "$LOCATION" \
        --tier standard \
        --node-count 2 \
        --node-vm-size Standard_D2s_v3 \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --enable-app-routing \
        --attach-acr "$ACR_NAME" \
        --generate-ssh-keys \
        --output none 2>/tmp/aks-create-error.log; then
        
        # Check if error is due to conditional access
        if grep -q "AADSTS530084\|conditional\|access policy" /tmp/aks-create-error.log 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Cluster created but ACR attachment failed (Conditional Access detected)"
            ACR_ATTACH_FAILED=true
        else
            echo -e "${RED}✗${NC} Cluster creation failed:"
            cat /tmp/aks-create-error.log >&2
            exit 1
        fi
    fi
fi

# If ACR attachment failed, provide portal instructions
if [[ "$ACR_ATTACH_FAILED" == true ]]; then
    echo ""
    echo -e "${YELLOW}⚠${NC} CLI role assignment failed due to Conditional Access policy"
    echo ""
    echo "Please complete ACR access in Azure Portal:"
    echo ""
    
    ACR_ID=$(az acr show --name "$ACR_NAME" --resource-group "$RG_NAME" --query id -o tsv)
    AKS_KUBELET_ID=$(az aks show --name "$AKS_NAME" --resource-group "$RG_NAME" --query "identityProfile.kubeletidentity.objectId" -o tsv)
    AKS_KUBELET_NAME=$(az aks show --name "$AKS_NAME" --resource-group "$RG_NAME" --query "identityProfile.kubeletidentity.resourceId" -o tsv | awk -F/ '{print $NF}')
    
    echo "  1. Open: https://portal.azure.com/#@${TENANT_ID}/resource${ACR_ID}/access"
    echo "  2. Click 'Access control (IAM)' → '+ Add' → 'Add role assignment'"
    echo "  3. Select role: AcrPull"
    echo "  4. Click 'Next' → '+ Select members'"
    echo "  5. Search and select: ${AKS_KUBELET_NAME}"
    echo "  6. Click 'Select' → 'Review + assign' (twice)"
    
    wait_for_portal_completion
    
    # Validate role assignment
    echo "▸ Validating ACR role assignment..."
    ROLE_CHECK=$(az role assignment list \
        --scope "$ACR_ID" \
        --query "[?roleDefinitionName=='AcrPull' && principalId=='$AKS_KUBELET_ID']" \
        --output tsv)
    
    if [[ -z "$ROLE_CHECK" ]]; then
        echo -e "${RED}✗${NC} ACR role assignment not found. Please verify the portal steps." >&2
        exit 1
    fi
    echo -e "${GREEN}✓${NC} ACR role assignment validated"
fi

# 4. Managed Identity
echo "▸ Creating managed identity '$IDENTITY_NAME'..."
az identity create \
    --name "$IDENTITY_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --output none

# 5. Federated Identity Credential
# Note: Subject must match the serviceAccount name in k8s/serviceaccount.yaml (defaults to ${NAME})
echo "▸ Creating federated identity credential..."
OIDC_ISSUER=$(az aks show \
    --name "$AKS_NAME" \
    --resource-group "$RG_NAME" \
    --query "oidcIssuerProfile.issuerUrl" \
    --output tsv)
az identity federated-credential create \
    --name "${NAME}-federated" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RG_NAME" \
    --issuer "$OIDC_ISSUER" \
    --subject "system:serviceaccount:${NAMESPACE}:${NAME}" \
    --audiences "api://AzureADTokenExchange" \
    --output none

# 6. Configure kubectl
echo "▸ Configuring kubectl context..."
az aks get-credentials \
    --name "$AKS_NAME" \
    --resource-group "$RG_NAME" \
    --overwrite-existing

# Validate kubectl access
echo "▸ Validating kubectl access..."
if ! kubectl get nodes --request-timeout=10s >/dev/null 2>/tmp/kubectl-error.log; then
    # Check if it's an auth error
    if grep -q "Unauthorized\|Forbidden\|AADSTS\|authentication" /tmp/kubectl-error.log 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} kubectl authentication failed (likely Conditional Access)"
        echo ""
        echo "Azure RBAC requires additional configuration:"
        echo ""
        
        AKS_RESOURCE_ID=$(az aks show --name "$AKS_NAME" --resource-group "$RG_NAME" --query id -o tsv)
        CURRENT_USER=$(az account show --query user.name -o tsv)
        
        echo "Option 1: Grant RBAC via Azure Portal (recommended)"
        echo "  1. Open: https://portal.azure.com/#@${TENANT_ID}/resource${AKS_RESOURCE_ID}/access"
        echo "  2. Click 'Access control (IAM)' → '+ Add' → 'Add role assignment'"
        echo "  3. Select role: 'Azure Kubernetes Service Cluster Admin Role'"
        echo "  4. Assign to: ${CURRENT_USER}"
        echo "  5. Click 'Save'"
        echo ""
        echo "Option 2: Use kubelogin for interactive authentication"
        
        if command -v kubelogin >/dev/null 2>&1; then
            echo "  kubelogin convert-kubeconfig -l azurecli"
            echo "  kubectl get nodes"
        else
            echo "  Install kubelogin: https://github.com/Azure/kubelogin#installation"
            echo "  kubelogin convert-kubeconfig -l azurecli"
            echo "  kubectl get nodes"
        fi
        
        echo ""
        echo "You can complete these steps later. Continuing with setup..."
    else
        echo -e "${RED}✗${NC} kubectl validation failed:"
        cat /tmp/kubectl-error.log >&2
        echo ""
        echo "You may need to troubleshoot kubectl connectivity."
    fi
else
    echo -e "${GREEN}✓${NC} kubectl access validated"
fi

# ── Summary ───────────────────────────────────────────────────────
ACR_LOGIN_SERVER=$(az acr show \
    --name "$ACR_NAME" \
    --resource-group "$RG_NAME" \
    --query loginServer \
    --output tsv)
IDENTITY_CLIENT_ID=$(az identity show \
    --name "$IDENTITY_NAME" \
    --resource-group "$RG_NAME" \
    --query clientId \
    --output tsv)
AKS_RESOURCE_ID=$(az aks show \
    --name "$AKS_NAME" \
    --resource-group "$RG_NAME" \
    --query id \
    --output tsv)
CURRENT_USER=$(az account show --query user.name -o tsv)

echo ""
echo "╭──────────────────────────────────────────────────╮"
echo "│  ✓ Prerequisites Ready                            │"
echo "╰──────────────────────────────────────────────────╯"
echo ""
echo "  Resource Group:   $RG_NAME"
echo "  AKS Cluster:      $AKS_NAME (${FLAVOR^})"
echo "  ACR:              $ACR_LOGIN_SERVER"
echo "  Identity:         $IDENTITY_NAME (client: $IDENTITY_CLIENT_ID)"
echo "  Namespace:        $NAMESPACE"
echo "  kubectl context:  $AKS_NAME"
echo ""
echo "  ⚠️  Note: If kubectl access failed above, you need to grant RBAC permissions"
echo ""
echo "  This cluster uses Azure RBAC. If you haven't already, grant yourself"
echo "  cluster-admin permissions via the Azure Portal:"
echo ""
echo "  1. Go to: https://portal.azure.com/#@${TENANT_ID}/resource${AKS_RESOURCE_ID}/access"
echo "  2. Click 'Add' → 'Add role assignment'"
echo "  3. Role: 'Azure Kubernetes Service Cluster Admin Role'"
echo "  4. Assign to: $CURRENT_USER"
echo "  5. Click 'Save'"
echo ""
echo "  After granting permissions, run quick deploy:"
echo "    \"Deploy my app to my existing AKS cluster\""
echo ""
echo "  Clean up later:"
echo "    ./scripts/setup-aks-prerequisites.sh --name $NAME --cleanup"
echo ""

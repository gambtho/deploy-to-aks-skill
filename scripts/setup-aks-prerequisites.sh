#!/usr/bin/env bash
set -euo pipefail

# setup-aks-prerequisites.sh
#
# Provisions AKS infrastructure (Automatic or Standard) for testing and demoing
# the deploy-to-aks quick deploy mode.
#
# Usage:
#   ./scripts/setup-aks-prerequisites.sh --name myapp --location eastus
#   ./scripts/setup-aks-prerequisites.sh --name myapp --flavor standard
#   ./scripts/setup-aks-prerequisites.sh --name myapp --cleanup
#   ./scripts/setup-aks-prerequisites.sh --help

# ── Defaults ──────────────────────────────────────────────────────
NAME=""
LOCATION="eastus"
NAMESPACE=""
FLAVOR="automatic"
CLEANUP=false

# ── Usage ─────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
Usage: setup-aks-prerequisites.sh [OPTIONS]

Provision AKS infrastructure for quick deploy mode.

Required:
  --name <name>         Base name for all resources

Optional:
  --location <region>   Azure region (default: eastus)
  --flavor <type>       AKS flavor: automatic or standard (default: automatic)
  --namespace <ns>      Kubernetes namespace (default: <name>)
  --cleanup             Delete the resource group and all resources
  --help                Show this help message

Examples:
  # Provision AKS Automatic infrastructure
  ./scripts/setup-aks-prerequisites.sh --name myapp --location eastus

  # Provision AKS Standard infrastructure
  ./scripts/setup-aks-prerequisites.sh --name myapp --flavor standard

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

# 3. AKS Cluster
# Note: --attach-acr configures AcrPull role automatically, avoiding conditional access issues
# Note: Do NOT enable Azure RBAC - it requires token exchanges that fail with conditional access policies
echo "▸ Creating AKS ${FLAVOR^} cluster '$AKS_NAME' (this takes 5-10 minutes)..."

if [[ "$FLAVOR" == "automatic" ]]; then
    az aks create \
        --name "$AKS_NAME" \
        --resource-group "$RG_NAME" \
        --location "$LOCATION" \
        --sku automatic \
        --enable-oidc-issuer \
        --enable-workload-identity \
        --attach-acr "$ACR_NAME" \
        --generate-ssh-keys \
        --output none
else
    # AKS Standard with web app routing addon
    az aks create \
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
        --output none
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
echo "  Run quick deploy:"
echo "    \"Deploy my app to my existing AKS cluster\""
echo ""
echo "  Clean up later:"
echo "    ./scripts/setup-aks-prerequisites.sh --name $NAME --cleanup"
echo ""

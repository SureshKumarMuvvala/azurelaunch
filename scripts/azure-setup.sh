#!/usr/bin/env bash
# ============================================================
# ONE-TIME Azure setup — run this locally before first deploy
# Prerequisites: Azure CLI installed + `az login` completed
# ============================================================
set -euo pipefail

# ── EDIT THESE BEFORE RUNNING ─────────────────────────────
SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
RESOURCE_GROUP="azurelaunch-rg"
LOCATION="eastus"
ACR_NAME="azurelaunchacr$RANDOM"        # must be globally unique
GITHUB_ORG="YOUR_GITHUB_USERNAME"
GITHUB_REPO="azurelaunch"
# ──────────────────────────────────────────────────────────

echo "▶ Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

echo "▶ Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "▶ Creating Azure Container Registry (Basic)..."
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  --admin-enabled false

ACR_ID=$(az acr show --name "$ACR_NAME" --query id --output tsv)
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)

echo "▶ Creating App Registration for GitHub Actions OIDC..."
APP_NAME="azurelaunch-github-actions"
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId --output tsv)
SP_OBJ_ID=$(az ad sp create --id "$APP_ID" --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

echo "▶ Assigning roles..."
RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id --output tsv)

az role assignment create --assignee "$SP_OBJ_ID" --role "Contributor" --scope "$RG_ID"
az role assignment create --assignee "$SP_OBJ_ID" --role "AcrPush" --scope "$ACR_ID"

echo "▶ Setting up federated credentials (OIDC)..."
az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"github-main\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Done! Add these secrets to your GitHub repo:"
echo "════════════════════════════════════════════════"
echo "  AZURE_CLIENT_ID       = $APP_ID"
echo "  AZURE_TENANT_ID       = $TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID"
echo "  ACR_NAME              = $ACR_NAME"
echo "  ACR_LOGIN_SERVER      = $ACR_LOGIN_SERVER"
echo ""
echo "Go to: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo "════════════════════════════════════════════════"

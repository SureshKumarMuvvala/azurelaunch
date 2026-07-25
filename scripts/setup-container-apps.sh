#!/usr/bin/env bash
# ============================================================
# ONE-TIME Container Apps setup — run this once before first deploy
# Prerequisites: az login done, ACR already set up
# ============================================================
set -euo pipefail

# ── EDIT THESE ────────────────────────────────────────────
SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
RESOURCE_GROUP="azurelaunch-rg"
LOCATION="eastus"
ACR_NAME="azurelaunchacr10033"        # your ACR name
BACKEND_APP="azurelaunch-backend"
FRONTEND_APP="azurelaunch-frontend"
ENVIRONMENT_NAME="azurelaunch-env"
# ──────────────────────────────────────────────────────────

az account set --subscription "$SUBSCRIPTION_ID"

echo "▶ Installing Container Apps extension..."
az extension add --name containerapp --upgrade --only-show-errors

echo "▶ Registering providers..."
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait

echo "▶ Creating Container Apps environment..."
az containerapp env create \
  --name "$ENVIRONMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION"

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)

echo "▶ Creating backend Container App..."
az containerapp create \
  --name "$BACKEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/$BACKEND_APP:latest" \
  --target-port 8000 \
  --ingress external \
  --registry-server "$ACR_LOGIN_SERVER" \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.25 --memory 0.5Gi

echo "▶ Creating frontend Container App..."
az containerapp create \
  --name "$FRONTEND_APP" \
  --resource-group "$RESOURCE_GROUP" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/$FRONTEND_APP:latest" \
  --target-port 80 \
  --ingress external \
  --registry-server "$ACR_LOGIN_SERVER" \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.25 --memory 0.5Gi

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Container Apps created! Live URLs:"
BACKEND_FQDN=$(az containerapp show --name "$BACKEND_APP" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn --output tsv)
FRONTEND_FQDN=$(az containerapp show --name "$FRONTEND_APP" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn --output tsv)
echo "  Backend  → https://$BACKEND_FQDN"
echo "  Frontend → https://$FRONTEND_FQDN"
echo "════════════════════════════════════════════════"
echo ""
echo "From now on every git push to main will auto-deploy via CD workflow!"
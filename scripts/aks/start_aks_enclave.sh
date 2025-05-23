#!/usr/bin/env bash
set -ex

if [[ ! -f ${TEMPLATE_FILE} ]]; then
  echo "TEMPLATE_FILE does not exist"
  exit 1
fi

ROOT="./uid2-shared-actions/scripts"

# below resources should be prepared ahead
export RESOURCE_GROUP="pipeline-vn-aks"
export LOCATION="eastus"
export VNET_NAME="pipeline-vnet"
export PUBLIC_IP_ADDRESS_NAME="pipeline-public-ip"
export NAT_GATEWAY_NAME="pipeline-nat-gateway"
export AKS_CLUSTER_NAME="pipelinevncluster"
export KEYVAULT_NAME="pipeline-vn-aks-vault"
export KEYVAULT_SECRET_NAME="pipeline-vn-aks-opr-key-name"
export MANAGED_IDENTITY="pipeline-vn-aks-opr-id"
export AKS_NODE_RESOURCE_GROUP="MC_${RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_${LOCATION}"
export SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export DEPLOYMENT_ENV="integ"

source "${ROOT}/healthcheck.sh"

# --- Deploy operator service and make sure it starts ---
az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
kubectl apply -f ${TEMPLATE_FILE}

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
  exit 1
fi

# Get public IP, need to trim quotes
IP=$(az network public-ip list --resource-group ${AKS_NODE_RESOURCE_GROUP} --query "[?starts_with(name, 'kubernetes')].ipAddress" --output tsv)

echo "Instance IP: ${IP}"
echo "uid2_pipeline_e2e_operator_url=http://${IP}" >> ${GITHUB_OUTPUT}

HEALTHCHECK_URL="http://${IP}/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

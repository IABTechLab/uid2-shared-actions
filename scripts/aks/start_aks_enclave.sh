#!/usr/bin/env bash
set -ex

if [[ ! -f ${TEMPLATE_FILE} ]]; then
  echo "TEMPLATE_FILE does not exist"
  exit 1
fi

ROOT="./uid2-shared-actions/scripts"

source "${ROOT}/aks/aks_env.sh"
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

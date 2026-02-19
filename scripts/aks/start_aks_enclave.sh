#!/usr/bin/env bash
set -ex

if [[ ! -f ${TEMPLATE_FILE} ]]; then
  echo "TEMPLATE_FILE does not exist"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/aks_env.sh"
source "${SCRIPT_DIR}/../healthcheck.sh"

# --- Deploy operator service and make sure it starts ---
az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
kubectl apply -f ${TEMPLATE_FILE}

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
  exit 1
fi

# Wait for public IP to be assigned (LoadBalancer provisioning can take time)
echo "Waiting for public IP to be assigned..."
for i in {1..30}; do
  IP=$(az network public-ip list --resource-group ${AKS_NODE_RESOURCE_GROUP} --query "[?starts_with(name, 'kubernetes')].ipAddress" --output tsv)
  if [ -n "${IP}" ]; then
    echo "Public IP found: ${IP}"
    break
  fi
  echo "Attempt ${i}/30: Public IP not yet available, waiting 10 seconds..."
  sleep 10
done

if [ -z "${IP}" ]; then
  echo "ERROR: Failed to get public IP after 5 minutes"
  echo "Checking available public IPs in resource group:"
  az network public-ip list --resource-group ${AKS_NODE_RESOURCE_GROUP} --output table
  exit 1
fi

echo "Instance IP: ${IP}"
echo "uid2_pipeline_e2e_operator_url=http://${IP}" >> ${GITHUB_OUTPUT}

HEALTHCHECK_URL="http://${IP}/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

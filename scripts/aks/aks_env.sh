#!/usr/bin/env bash
# Common AKS environment variables used by multiple scripts

# Set the correct subscription for AKS E2E tests
az account set --subscription "63e97a70-d825-4b08-af6d-c0d8ad98bed3"

export LOCATION="eastus"
export SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export DEPLOYMENT_ENV="integ"

# Find an available resource group name
BASE_RESOURCE_GROUP="opr-e2e-vn-aks"
SUFFIX=""
COUNTER=0

while true; do
  CANDIDATE="${BASE_RESOURCE_GROUP}${SUFFIX}"
  if ! az group exists --name "${CANDIDATE}" | grep -q true; then
    export RESOURCE_GROUP="${CANDIDATE}"
    echo "Using resource group: ${RESOURCE_GROUP}"
    break
  fi
  echo "Resource group '${CANDIDATE}' already exists, trying next..."
  COUNTER=$((COUNTER + 1))
  SUFFIX="-${COUNTER}"
done

# Set dependent variables based on resource group
export VNET_NAME="${RESOURCE_GROUP}-vnet"
export PUBLIC_IP_ADDRESS_NAME="${RESOURCE_GROUP}-public-ip"
export NAT_GATEWAY_NAME="${RESOURCE_GROUP}-nat-gateway"
export AKS_CLUSTER_NAME="${RESOURCE_GROUP}-cluster"
export KEYVAULT_NAME="${RESOURCE_GROUP}-vault"
export KEYVAULT_SECRET_NAME="${RESOURCE_GROUP}-opr-key"
export MANAGED_IDENTITY="${RESOURCE_GROUP}-opr-id"
export AKS_NODE_RESOURCE_GROUP="MC_${RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_${LOCATION}"
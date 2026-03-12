#!/usr/bin/env bash
# Common AKS environment variables used by multiple scripts

# Set the correct subscription for AKS E2E tests
az account set --subscription "63e97a70-d825-4b08-af6d-c0d8ad98bed3"

# RUN_ID should be set by the caller (e.g., github.run_id)
# Use short suffix to stay within Azure naming limits (e.g., Key Vault max 24 chars)
if [ -z "${RUN_ID}" ]; then
  echo "Warning: RUN_ID not set, using default names (may cause conflicts)"
  RUN_SUFFIX=""
else
  # Use last 8 digits of RUN_ID to keep names short
  RUN_SUFFIX="-${RUN_ID: -8}"
fi

export RESOURCE_GROUP="opr-e2e-aks${RUN_SUFFIX}"
export LOCATION="eastus"
export VNET_NAME="opr-e2e-vnet${RUN_SUFFIX}"
export PUBLIC_IP_ADDRESS_NAME="opr-e2e-ip${RUN_SUFFIX}"
export NAT_GATEWAY_NAME="opr-e2e-nat${RUN_SUFFIX}"
export AKS_CLUSTER_NAME="opr-e2e-cluster${RUN_SUFFIX}"
export KEYVAULT_NAME="opre2evault${RUN_SUFFIX}"
export KEYVAULT_SECRET_NAME="opr-key${RUN_SUFFIX}"
export MANAGED_IDENTITY="opr-e2e-id${RUN_SUFFIX}"
export AKS_NODE_RESOURCE_GROUP="MC_${RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_${LOCATION}"
export SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export DEPLOYMENT_ENV="integ"
#!/usr/bin/env bash
# Common AKS environment variables used by multiple scripts

# Set the correct subscription for AKS E2E tests
az account set --subscription "63e97a70-d825-4b08-af6d-c0d8ad98bed3"

export RESOURCE_GROUP="opr-e2e-vn-aks"
export LOCATION="eastus"
export VNET_NAME="opr-e2e-vnet"
export PUBLIC_IP_ADDRESS_NAME="opr-e2e-public-ip"
export NAT_GATEWAY_NAME="opr-e2e-nat-gateway"
export AKS_CLUSTER_NAME="opr-e2evncluster"
export KEYVAULT_NAME="opr-e2e-vn-aks-vault"
export KEYVAULT_SECRET_NAME="opr-e2e-vn-aks-opr-key-name"
export MANAGED_IDENTITY="opr-e2e-vn-aks-opr-id"
export AKS_NODE_RESOURCE_GROUP="MC_${RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_${LOCATION}"
export SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export DEPLOYMENT_ENV="integ"


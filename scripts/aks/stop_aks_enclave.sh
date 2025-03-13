#!/usr/bin/env bash
set -ex

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

az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
if kubectl get deployment operator-deployment -o name > /dev/null 2>&1; then
  kubectl delete deployment operator-deployment
  echo "Deployment 'operator-deployment' deleted."
else
  echo "Deployment 'operator-deployment' does not exist."
fi
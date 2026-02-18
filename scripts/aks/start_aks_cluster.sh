#!/usr/bin/env bash
set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks_env.sh"

# Setup AKS & Node Pool
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"

az network vnet create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${VNET_NAME} \
    --location ${LOCATION} \
    --address-prefixes 10.0.0.0/8

# Default Subnet (10.0.0.0/24)
az network vnet subnet create \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET_NAME} \
    --name default \
    --address-prefixes 10.0.0.0/24

# AKS Subnet (CIDR /16)
az network vnet subnet create \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET_NAME} \
    --name aks \
    --address-prefixes 10.1.0.0/16

# Container Groups Subnet (CIDR /16) with Delegation
az network vnet subnet create \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET_NAME} \
    --name cg \
    --address-prefixes 10.2.0.0/16 \
    --delegations Microsoft.ContainerInstance/containerGroups

az network public-ip create --name ${PUBLIC_IP_ADDRESS_NAME} --resource-group ${RESOURCE_GROUP} --sku standard --allocation static

az network nat gateway create \
    --resource-group ${RESOURCE_GROUP} \
    --name ${NAT_GATEWAY_NAME} \
    --public-ip-addresses ${PUBLIC_IP_ADDRESS_NAME} \
    --idle-timeout 4

az network vnet subnet update \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET_NAME} \
    --name cg \
    --nat-gateway ${NAT_GATEWAY_NAME}

export AKS_SUBNET_ID=$(az network vnet subnet show \
    --resource-group ${RESOURCE_GROUP} \
    --vnet-name ${VNET_NAME} \
    --name aks \
    --query id \
    --output tsv)

# Create the AKS cluster if it doesn't exist
if az aks show --resource-group ${RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} &>/dev/null; then
  echo "AKS cluster '${AKS_CLUSTER_NAME}' already exists, skipping creation."
else
  echo "Creating AKS cluster '${AKS_CLUSTER_NAME}'..."
  az aks create \
      --resource-group ${RESOURCE_GROUP} \
      --name ${AKS_CLUSTER_NAME} \
      --location ${LOCATION} \
      --kubernetes-version 1.33 \
      --network-plugin azure \
      --network-policy calico \
      --vnet-subnet-id ${AKS_SUBNET_ID} \
      --service-cidr 10.4.0.0/16 \
      --dns-service-ip 10.4.0.10 \
      --node-vm-size Standard_D4d_v5 \
      --node-count 2 \
      --enable-cluster-autoscaler \
      --min-count 2 \
      --max-count 5 \
      --auto-upgrade-channel patch \
      --enable-managed-identity \
      --nodepool-name oprnodepool \
      --os-sku Ubuntu
fi

# Get the managed identity object ID for role assignments
export MANAGED_IDENTITY_OBJECT_ID="$(az aks show --resource-group ${RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --query "identityProfile.kubeletidentity.objectId" --output tsv)"

# Wait for managed identity to be available in AAD and create role assignments
echo "Waiting for managed identity to be available in AAD..."
until az role assignment create \
  --assignee-object-id ${MANAGED_IDENTITY_OBJECT_ID} \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${AKS_NODE_RESOURCE_GROUP} \
  --role Contributor 2>/dev/null; do
  echo "Managed identity not yet available, waiting 10 seconds..."
  sleep 10
done
echo "First role assignment created successfully."

az role assignment create \
  --assignee-object-id ${MANAGED_IDENTITY_OBJECT_ID} \
  --assignee-principal-type ServicePrincipal \
  --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} \
  --role Contributor

# Setup AKS Cluster
az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
az provider register -n Microsoft.ContainerInstance
git clone git@github.com:microsoft/virtualnodesOnAzureContainerInstances.git
helm install virtualnode virtualnodesOnAzureContainerInstances/Helm/virtualnode
# Wait for virtualnode-0 to appear
echo "Waiting for virtualnode-0 to be ready..."
while ! kubectl get nodes | grep -q "virtualnode-0"; do
  echo "virtualnode-0 not found yet, waiting 10 seconds..."
  sleep 10
done
echo "virtualnode-0 is ready!"
kubectl get nodes
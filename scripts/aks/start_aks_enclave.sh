#!/usr/bin/env bash
set -ex

ROOT="uid2-shared-actions/scripts"

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

# # --- Setup AKS & Node Pool ---
# # Create Resource Group
# az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"

# # Create Virtual Network
# az network vnet create \
#     --resource-group ${RESOURCE_GROUP} \
#     --name ${VNET_NAME} \
#     --location ${LOCATION} \
#     --address-prefixes 10.0.0.0/8

# # Create Subnets
# # Default Subnet (10.0.0.0/24)
# az network vnet subnet create \
#     --resource-group ${RESOURCE_GROUP} \
#     --vnet-name ${VNET_NAME} \
#     --name default \
#     --address-prefixes 10.0.0.0/24

# # AKS Subnet (CIDR /16)
# az network vnet subnet create \
#     --resource-group ${RESOURCE_GROUP} \
#     --vnet-name ${VNET_NAME} \
#     --name aks \
#     --address-prefixes 10.1.0.0/16

# # Container Groups Subnet (CIDR /16) with Delegation
# az network vnet subnet create \
#     --resource-group ${RESOURCE_GROUP} \
#     --vnet-name ${VNET_NAME} \
#     --name cg \
#     --address-prefixes 10.2.0.0/16 \
#     --delegations Microsoft.ContainerInstance/containerGroups

# # Create Public IP Address
# az network public-ip create --name ${PUBLIC_IP_ADDRESS_NAME} --resource-group ${RESOURCE_GROUP} --sku standard --allocation static

# # Create NAT Gateway
# az network nat gateway create \
#     --resource-group ${RESOURCE_GROUP} \
#     --name ${NAT_GATEWAY_NAME} \
#     --public-ip-addresses ${PUBLIC_IP_ADDRESS_NAME} \
#     --idle-timeout 4

# # Configure NAT service for source subnet
# az network vnet subnet update \
#     --resource-group ${RESOURCE_GROUP} \
#     --vnet-name ${VNET_NAME} \
#     --name cg \
#     --nat-gateway ${NAT_GATEWAY_NAME}

# # Get the AKS Subnet ID
# export AKS_SUBNET_ID=$(az network vnet subnet show \
#     --resource-group ${RESOURCE_GROUP} \
#     --vnet-name ${VNET_NAME} \
#     --name aks \
#     --query id \
#     --output tsv)

# # Create an AKS Service
# # Create the AKS cluster
# az aks create \
#     --resource-group ${RESOURCE_GROUP} \
#     --name ${AKS_CLUSTER_NAME} \
#     --location ${LOCATION} \
#     --kubernetes-version 1.29.13 \
#     --network-plugin azure \
#     --network-policy calico \
#     --vnet-subnet-id ${AKS_SUBNET_ID} \
#     --service-cidr 10.4.0.0/16 \
#     --dns-service-ip 10.4.0.10 \
#     --node-vm-size Standard_D4d_v5 \
#     --node-count 2 \
#     --enable-cluster-autoscaler \
#     --min-count 2 \
#     --max-count 5 \
#     --auto-upgrade-channel patch \
#     --enable-managed-identity \
#     --nodepool-name oprnodepool \
#     --os-sku Ubuntu

# # Get Managed Identity Principle ID
# export MANAGED_IDENTITY_PRINCIPAL_ID="$(az aks show --resource-group ${RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --query "identityProfile.kubeletidentity.clientId" --output tsv)"

# # Create contributor role for the two resource groups
# az role assignment create \
#   --assignee ${MANAGED_IDENTITY_PRINCIPAL_ID} \
#   --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${AKS_NODE_RESOURCE_GROUP} \
#   --role Contributor

# az role assignment create \
#   --assignee ${MANAGED_IDENTITY_PRINCIPAL_ID} \
#   --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} \
#   --role Contributor
# # --- Finished setting up AKS & Node Pool ---

# # --- Setup AKS Cluster ---
# az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
# az provider register -n Microsoft.ContainerInstance
# git clone git@github.com:microsoft/virtualnodesOnAzureContainerInstances.git
# helm install virtualnode virtualnodesOnAzureContainerInstances/Helm/virtualnode
# # Wait for ~1 minute for virtualnode-0 to appear.
# sleep 60
# kubectl get nodes
# # --- Finished setting up AKS Cluster ---

# # --- Create Key Vault & Managed Identity ---
# if [ -z "${AKS_OPERATOR_KEY}" ]; then
#   echo "AKS_OPERATOR_KEY can not be empty"
#   exit 1
# fi

# az identity create --name "${MANAGED_IDENTITY}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}"
# az keyvault create --name "${KEYVAULT_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --enable-purge-protection --enable-rbac-authorization
# export KEYVAULT_RESOURCE_ID="$(az keyvault show --resource-group "${RESOURCE_GROUP}" --name "${KEYVAULT_NAME}" --query id --output tsv)"
# az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name "${KEYVAULT_SECRET_NAME}" --value "${AKS_OPERATOR_KEY}"
# export IDENTITY_PRINCIPAL_ID="$(az identity show --name "${MANAGED_IDENTITY}" --resource-group "${RESOURCE_GROUP}" --query principalId --output tsv)"
# az role assignment create --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" --role "Key Vault Secrets User" --scope "${KEYVAULT_RESOURCE_ID}" --assignee-principal-type ServicePrincipal
# # --- Finished setting up Key Vault & Managed Identity ---

# --- Update yaml file with resources ---
source "${ROOT}/healthcheck.sh"

if [ -z "${BORE_URL_CORE}" ]; then
  echo "BORE_URL_CORE can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_OPTOUT}" ]; then
  echo "BORE_URL_OPTOUT can not be empty"
  exit 1
fi

if [[ ! -f ${OUTPUT_TEMPLATE_FILE} ]]; then
  echo "OUTPUT_TEMPLATE_FILE does not exist"
  exit 1
fi

# Replace virtualnode identity with the managed identity created above
export MANAGED_IDENTITY_ID="$(az identity show --name "${MANAGED_IDENTITY}" --resource-group "${RESOURCE_GROUP}" --query id --output tsv)"
echo $MANAGED_IDENTITY_ID
sed -i "s#IDENTITY_PLACEHOLDER#$MANAGED_IDENTITY_ID#g" "${OUTPUT_TEMPLATE_FILE}"
cat ${OUTPUT_TEMPLATE_FILE}

sudo apt-get update
sudo apt-get install yq
yq -iy '.spec.template.spec.containers[] | select(.name == "uid2-operator").env += [{"name": "CORE_BASE_URL", "value": "http://BORE_URL_CORE_PLACEHOLDER"}, {"name": "OPTOUT_BASE_URL", "value": "http://BORE_URL_OPTOUT_PLACEHOLDER"}, {"name": "SKIP_VALIDATIONS", "value": "true"}]' "${OUTPUT_TEMPLATE_FILE}"
sed -i "s#BORE_URL_CORE_PLACEHOLDER#$BORE_URL_CORE#g" "${OUTPUT_TEMPLATE_FILE}"
sed -i "s#BORE_URL_OPTOUT_PLACEHOLDER#$BORE_URL_OPTOUT#g" "${OUTPUT_TEMPLATE_FILE}"
cat ${OUTPUT_TEMPLATE_FILE}
# --- Finished updating yaml file with resources ---

# --- Deploy operator service and make sure it starts ---
kubectl apply -f ${OUTPUT_TEMPLATE_FILE}

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
  exit 1
fi

# Wait for the service to be ready
kubectl wait --for=condition=Ready service/operator-svc --timeout=300s

# Get public IP, need to trim quotes
IP=$(az network public-ip list --resource-group ${AKS_NODE_RESOURCE_GROUP} --query "[?starts_with(name, 'kubernetes')].ipAddress" --output tsv)

echo "Instance IP: ${IP}"
echo "uid2_e2e_pipeline_operator_url=http://${IP}:8080" >> ${GITHUB_OUTPUT}

HEALTHCHECK_URL="http://${IP}:8080/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

#!/usr/bin/env bash
set -ex

if [ -z "${BORE_URL_CORE}" ]; then
  echo "BORE_URL_CORE can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_OPTOUT}" ]; then
  echo "BORE_URL_OPTOUT can not be empty"
  exit 1
fi

if [ -z "${IMAGE_VERSION}" ]; then
  echo "IMAGE_VERSION can not be empty"
  exit 1
fi

if [ -z "${TARGET_ENVIRONMENT}" ]; then
  echo "TARGET_ENVIRONMENT can not be empty"
  exit 1
fi

if [ -z "${OPERATOR_KEY}" ]; then
  echo "OPERATOR_KEY can not be empty"
  exit 1
fi

# See https://github.com/UnifiedID2/aks-demo/tree/master/vn-aks#setup-aks--node-pool
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks_env.sh"

if [ ${TARGET_ENVIRONMENT} == "mock" ]; then
  export KEYVAULT_SECRET_NAME="opr-e2e-vn-aks-opr-key-name"
elif [ ${TARGET_ENVIRONMENT} == "integ" ]; then
  export KEYVAULT_SECRET_NAME="opr-e2e-vn-aks-opr-key-name-integ"
elif [ ${TARGET_ENVIRONMENT} == "prod" ]; then
  export KEYVAULT_SECRET_NAME="opr-e2e-vn-aks-opr-key-name-prod"
else
  echo "Arguments not supported: TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT}"
  exit 1
fi

# --- Create Key Vault & Managed Identity ---
# Login to AKS cluster
az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
# Create managed identity
az identity create --name "${MANAGED_IDENTITY}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}"
# Create key vault with purge protection and RBAC authorization
az keyvault create --name "${KEYVAULT_NAME}" --resource-group "${RESOURCE_GROUP}" --location "${LOCATION}" --enable-purge-protection --enable-rbac-authorization
# Get keyvault resource ID
export KEYVAULT_RESOURCE_ID="$(az keyvault show --resource-group "${RESOURCE_GROUP}" --name "${KEYVAULT_NAME}" --query id --output tsv)"
# Set keyvault secret
az keyvault secret set --vault-name "${KEYVAULT_NAME}" --name "${KEYVAULT_SECRET_NAME}" --value "${OPERATOR_KEY}"
# Get identity principal ID
export IDENTITY_PRINCIPAL_ID="$(az identity show --name "${MANAGED_IDENTITY}" --resource-group "${RESOURCE_GROUP}" --query principalId --output tsv)"
# Create role assignment for Key Vault Secrets User
az role assignment create --assignee-object-id "${IDENTITY_PRINCIPAL_ID}" --role "Key Vault Secrets User" --scope "${KEYVAULT_RESOURCE_ID}" --assignee-principal-type ServicePrincipal

# Get managed identity ID
export MANAGED_IDENTITY_ID="$(az identity show --name "${MANAGED_IDENTITY}" --resource-group "${RESOURCE_GROUP}" --query id --output tsv)"

OPERATOR_ROOT="./uid2-operator"
SHARED_ACTIONS_ROOT="./uid2-shared-actions"
OUTPUT_DIR="${SHARED_ACTIONS_ROOT}/scripts/aks/azure-aks-artifacts"

IMAGE="ghcr.io/iabtechlab/uid2-operator:${IMAGE_VERSION}"

if [ -d "${OUTPUT_DIR}" ]; then
  echo "${OUTPUT_DIR} exists"
fi

INPUT_TEMPLATE_FILE="${OPERATOR_ROOT}/scripts/azure-aks/deployment/operator.yaml"
OUTPUT_TEMPLATE_FILE="${OUTPUT_DIR}/operator.yaml"
OUTPUT_POLICY_DIGEST_FILE="${OUTPUT_DIR}/aks-digest.txt"

if [[ -d ${OUTPUT_DIR} ]]; then
  echo "${OUTPUT_DIR} exists, skipping - this only happens during local testing"
else
  mkdir -p ${OUTPUT_DIR}

  # Install confcom extension, az is originally available in GitHub workflow environment
  az extension add --name confcom
  if [[ $? -ne 0 ]]; then
    echo "Failed to install Azure confcom extension"
    exit 1
  fi

  # Required by az confcom
  sudo usermod -aG docker ${USER}
  if [[ $? -ne 0 ]]; then
    echo "Failed to add current user to Docker group"
    exit 1
  fi

  # Generate deployment template
  cp ${INPUT_TEMPLATE_FILE} ${OUTPUT_TEMPLATE_FILE}
  sed -i "s#IMAGE_PLACEHOLDER#${IMAGE}#g" ${OUTPUT_TEMPLATE_FILE}
  sed -i "s#IDENTITY_PLACEHOLDER#${MANAGED_IDENTITY_ID}#g" "${OUTPUT_TEMPLATE_FILE}"
  sed -i "s#VAULT_NAME_PLACEHOLDER#${KEYVAULT_NAME}#g" "${OUTPUT_TEMPLATE_FILE}"
  sed -i "s#OPERATOR_KEY_SECRET_NAME_PLACEHOLDER#${KEYVAULT_SECRET_NAME}#g" "${OUTPUT_TEMPLATE_FILE}"
  sed -i "s#DEPLOYMENT_ENVIRONMENT_PLACEHOLDER#integ#g" "${OUTPUT_TEMPLATE_FILE}"
  cat ${OUTPUT_TEMPLATE_FILE}

  if [ ${TARGET_ENVIRONMENT} == "mock" ]; then
    python3 ${SHARED_ACTIONS_ROOT}/scripts/aks/add_env.py ${OUTPUT_TEMPLATE_FILE} uid2-operator CORE_BASE_URL ${BORE_URL_CORE} OPTOUT_BASE_URL ${BORE_URL_OPTOUT} SKIP_VALIDATIONS true
  fi

  cat ${OUTPUT_TEMPLATE_FILE}
  # --- Finished updating yaml file with resources ---
  if [[ $? -ne 0 ]]; then
    echo "Failed to pre-process template file"
    exit 1
  fi

  # Generate policy using debug mode as we will need to override environment variables
  yes | az confcom acipolicygen --virtual-node-yaml ${OUTPUT_TEMPLATE_FILE} --debug-mode > ${OUTPUT_POLICY_DIGEST_FILE}
  if [[ $? -ne 0 ]]; then
    echo "Failed to generate template file"
    exit 1
  fi
  # The previous pipe will be stored in ${OUTPUT_POLICY_DIGEST_FILE} as well. The below command is to remove the prompt and only extract the enclave id.
  sed -i 's/.*(y\/n) //g' "${OUTPUT_POLICY_DIGEST_FILE}"
fi

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "TEMPLATE_FILE=${OUTPUT_TEMPLATE_FILE}" >> ${GITHUB_OUTPUT}
  echo "POLICY_DIGEST_FILE=${OUTPUT_POLICY_DIGEST_FILE}" >> ${GITHUB_OUTPUT}
fi

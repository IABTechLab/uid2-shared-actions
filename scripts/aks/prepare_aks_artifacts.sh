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

# Below resources should be prepared ahead of running the E2E test.
# See https://github.com/UnifiedID2/aks-demo/tree/master/vn-aks#setup-aks--node-pool
export RESOURCE_GROUP="pipeline-vn-aks"
export LOCATION="eastus"
export VNET_NAME="pipeline-vnet"
export PUBLIC_IP_ADDRESS_NAME="pipeline-public-ip"
export NAT_GATEWAY_NAME="pipeline-nat-gateway"
export AKS_CLUSTER_NAME="pipelinevncluster"
export KEYVAULT_NAME="pipeline-vn-aks-vault"
if [ ${TARGET_ENVIRONMENT} == "mock" ]; then
  export KEYVAULT_SECRET_NAME="pipeline-vn-aks-opr-key-name"
elif [ ${TARGET_ENVIRONMENT} == "integ" ]; then
  KEYVAULT_SECRET_NAME="pipeline-vn-aks-opr-key-name-integ"
elif [ ${TARGET_ENVIRONMENT} == "prod" ]; then
  KEYVAULT_SECRET_NAME="pipeline-vn-aks-opr-key-name-prod"
else
  echo "Arguments not supported: TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT}"
  exit 1
fi

export MANAGED_IDENTITY="pipeline-vn-aks-opr-id"
export AKS_NODE_RESOURCE_GROUP="MC_${RESOURCE_GROUP}_${AKS_CLUSTER_NAME}_${LOCATION}"
export SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
export DEPLOYMENT_ENV="integ"
export MANAGED_IDENTITY_ID="/subscriptions/001a3882-eb1c-42ac-9edc-5e2872a07783/resourcegroups/pipeline-vn-aks/providers/Microsoft.ManagedIdentity/userAssignedIdentities/pipeline-vn-aks-opr-id"

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
  az confcom acipolicygen --virtual-node-yaml ${OUTPUT_TEMPLATE_FILE} --print-policy > policy.base64
  base64 -di < policy.base64 > generated.rego
  sed -i 's#{"pattern":"VAULT_NAME=${KEYVAULT_NAME}","required":false,"strategy":"string"}#{"pattern":"VAULT_NAME=.+","required":false,"strategy":"re2"}#g' generated.rego
  sed -i 's#{"pattern":"OPERATOR_KEY_SECRET_NAME=${KEYVAULT_SECRET_NAME}","required":false,"strategy":"string"}#{"pattern":"OPERATOR_KEY_SECRET_NAME=.+","required":false,"strategy":"re2"}#g' generated.rego
  sed -i 's#{"pattern":"DEPLOYMENT_ENVIRONMENT=integ","required":false,"strategy":"string"}#{"pattern":"DEPLOYMENT_ENVIRONMENT=.+","required":false,"strategy":"re2"}#g' generated.rego
  base64 -w0 < generated.rego > generated.rego.base64
  python3 ${SHARED_ACTIONS_ROOT}/scripts/aks/generate.py generated.rego > ${OUTPUT_POLICY_DIGEST_FILE}
  
  if [[ $? -ne 0 ]]; then
    echo "Failed to generate template file"
    exit 1
  fi
  # The previous pipe will be stored in ${OUTPUT_POLICY_DIGEST_FILE} as well. The below command is to remove the prompt and only extract the enclave id.
  # sed -i 's/.*(y\/n) //g' "${OUTPUT_POLICY_DIGEST_FILE}"
  cat ${OUTPUT_POLICY_DIGEST_FILE}
fi

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "TEMPLATE_FILE=${OUTPUT_TEMPLATE_FILE}" >> ${GITHUB_OUTPUT}
  echo "POLICY_DIGEST_FILE=${OUTPUT_POLICY_DIGEST_FILE}" >> ${GITHUB_OUTPUT}
fi

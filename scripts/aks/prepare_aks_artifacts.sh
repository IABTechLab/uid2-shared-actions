#!/usr/bin/env bash
set -ex

# below resources should be prepared ahead
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
export MANAGED_IDENTITY_ID="/subscriptions/001a3882-eb1c-42ac-9edc-5e2872a07783/resourcegroups/pipeline-vn-aks/providers/Microsoft.ManagedIdentity/userAssignedIdentities/pipeline-vn-aks-opr-id"

if [ -z "${IMAGE_VERSION}" ]; then
  echo "IMAGE_VERSION can not be empty"
  exit 1
fi

if [ -z "${OPERATOR_ROOT}" ]; then
  echo "OPERATOR_ROOT can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_CORE}" ]; then
  echo "BORE_URL_CORE can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_OPTOUT}" ]; then
  echo "BORE_URL_OPTOUT can not be empty"
  exit 1
fi

ROOT="uid2-shared-actions/scripts/aks"
OUTPUT_DIR="${ROOT}/azure-aks-artifacts"

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
  sed -i "s#IDENTITY_PLACEHOLDER#$MANAGED_IDENTITY_ID#g" "${OUTPUT_TEMPLATE_FILE}"
  sed -i "s#VAULT_NAME_PLACEHOLDER#$KEYVAULT_NAME#g" "${OUTPUT_TEMPLATE_FILE}"
  sed -i "s#OPERATOR_KEY_SECRET_NAME_PLACEHOLDER#$KEYVAULT_SECRET_NAME#g" "${OUTPUT_TEMPLATE_FILE}"
  sed -i "s#DEPLOYMENT_ENVIRONMENT_PLACEHOLDER#integ#g" "${OUTPUT_TEMPLATE_FILE}"
  cat ${OUTPUT_TEMPLATE_FILE}

  python3 ${ROOT}/add_env.py ${OUTPUT_TEMPLATE_FILE} uid2-operator CORE_BASE_URL http://$BORE_URL_CORE OPTOUT_BASE_URL http://$BORE_URL_OPTOUT SKIP_VALIDATIONS true
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
  sed -i 's/.*(y\/n) //g' "${OUTPUT_POLICY_DIGEST_FILE}"
fi

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "OUTPUT_TEMPLATE_FILE=${OUTPUT_TEMPLATE_FILE}" >> ${GITHUB_OUTPUT}
  echo "OUTPUT_POLICY_DIGEST_FILE=${OUTPUT_POLICY_DIGEST_FILE}" >> ${GITHUB_OUTPUT}
fi

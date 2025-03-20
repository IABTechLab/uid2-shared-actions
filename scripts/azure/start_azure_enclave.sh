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

if [[ ! -f ${TEMPLATE_FILE} ]]; then
  echo "TEMPLATE_FILE does not exist"
  exit 1
fi

if [[ ! -f ${PARAMETERS_FILE} ]]; then
  echo "PARAMETERS_FILE does not exist"
  exit 1
fi

if [ -z "${TARGET_ENVIRONMENT}" ]; then
  echo "TARGET_ENVIRONMENT can not be empty"
  exit 1
fi

# Below resources should be prepared ahead
ROOT="./uid2-shared-actions/scripts"

source "${ROOT}/jq_helper.sh"
source "${ROOT}/healthcheck.sh"

RESOURCE_GROUP="uid-enclave-ci-cd"
IDENTITY="uid-operator"
VAULT_NAME="uid-operator"
if [ ${TARGET_ENVIRONMENT} == "mock" ]; then
  OPERATOR_KEY_NAME="operator-key-ci"
elif [ ${TARGET_ENVIRONMENT} == "integ" ]; then
  OPERATOR_KEY_NAME="operator-key-ci-integ"
elif [ ${TARGET_ENVIRONMENT} == "prod" ]; then
  OPERATOR_KEY_NAME="operator-key-ci-prod"
else
  echo "Arguments not supported: TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT}"
  exit 1
fi

LOCATION="East US"
DEPLOYMENT_ENV="integ"
AZURE_CONTAINER_GROUP_NAME="ci-test-${RANDOM}"
DEPLOYMENT_NAME=${AZURE_CONTAINER_GROUP_NAME}

jq_string_update ${PARAMETERS_FILE} parameters.containerGroupName.value "${AZURE_CONTAINER_GROUP_NAME}"
jq_string_update ${PARAMETERS_FILE} parameters.location.value "${LOCATION}"
jq_string_update ${PARAMETERS_FILE} parameters.identity.value "${IDENTITY}"
jq_string_update ${PARAMETERS_FILE} parameters.vaultName.value "${VAULT_NAME}"
jq_string_update ${PARAMETERS_FILE} parameters.operatorKeySecretName.value "${OPERATOR_KEY_NAME}"
jq_string_update ${PARAMETERS_FILE} parameters.skipValidations.value "true"
jq_string_update ${PARAMETERS_FILE} parameters.deploymentEnvironment.value "${DEPLOYMENT_ENV}"
jq_string_update ${PARAMETERS_FILE} parameters.coreBaseUrl.value "${BORE_URL_CORE}"
jq_string_update ${PARAMETERS_FILE} parameters.optoutBaseUrl.value "${BORE_URL_OPTOUT}"

cat ${PARAMETERS_FILE}

az deployment group create \
    -g ${RESOURCE_GROUP} \
    -n ${DEPLOYMENT_NAME} \
    --template-file "${TEMPLATE_FILE}"  \
    --parameters "${PARAMETERS_FILE}"

# Export to GitHub output
echo "AZURE_CONTAINER_GROUP_NAME=${AZURE_CONTAINER_GROUP_NAME}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "AZURE_CONTAINER_GROUP_NAME=${AZURE_CONTAINER_GROUP_NAME}" >> ${GITHUB_OUTPUT}
fi

# Get public IP, need to trim quotes
IP=$(az deployment group show \
       -g ${RESOURCE_GROUP} \
       -n ${DEPLOYMENT_NAME} \
       --query properties.outputs.containerIPv4Address.value | tr -d '"')

echo "Instance IP: ${IP}"
echo "uid2_e2e_pipeline_operator_url=http://${IP}:8080" >> ${GITHUB_OUTPUT}

HEALTHCHECK_URL="http://${IP}:8080/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

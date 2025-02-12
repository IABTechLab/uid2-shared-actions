#!/usr/bin/env bash
set -ex

ROOT="uid2-shared-actions/scripts"
# below resources should be prepared ahead
RESOURCE_GROUP=uid-enclave-ci-cd
IDENTITY=uid-operator
VAULT_NAME=uid-operator
OPERATOR_KEY_NAME=operator-key-ci

LOCATION="East US"
DEPLOYMENT_ENV="integ"
AZURE_CONTAINER_GROUP_NAME="ci-test-${RANDOM}"
DEPLOYMENT_NAME=${AZURE_CONTAINER_GROUP_NAME}

source "${ROOT}/jq_helper.sh"
source "${ROOT}/healthcheck.sh"

if [ -z "${IDENTITY}" ]; then
  echo "IDENTITY can not be empty"
  exit 1
fi

if [ -z "${VAULT_NAME}" ]; then
  echo "VAULT_NAME can not be empty"
  exit 1
fi

if [ -z "${OPERATOR_KEY_NAME}" ]; then
  echo "OPERATOR_KEY_NAME can not be empty"
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

if [[ ! -f ${OUTPUT_TEMPLATE_FILE} ]]; then
  echo "OUTPUT_TEMPLATE_FILE does not exist"
  exit 1
fi

if [[ ! -f ${OUTPUT_PARAMETERS_FILE} ]]; then
  echo "OUTPUT_PARAMETERS_FILE does not exist"
  exit 1
fi

jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.containerGroupName.value "${AZURE_CONTAINER_GROUP_NAME}"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.location.value "${LOCATION}"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.identity.value "${IDENTITY}"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.vaultName.value "${VAULT_NAME}"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.operatorKeySecretName.value "${OPERATOR_KEY_NAME}"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.skipValidations.value "true"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.deploymentEnvironment.value "${DEPLOYMENT_ENV}"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.coreBaseUrl.value "http://${BORE_URL_CORE}"
jq_string_update ${OUTPUT_PARAMETERS_FILE} parameters.optoutBaseUrl.value "http://${BORE_URL_OPTOUT}"

cat ${OUTPUT_PARAMETERS_FILE}

az deployment group create \
    -g ${RESOURCE_GROUP} \
    -n ${DEPLOYMENT_NAME} \
    --template-file "${OUTPUT_TEMPLATE_FILE}"  \
    --parameters "${OUTPUT_PARAMETERS_FILE}"

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

#!/usr/bin/env bash
set -ex

# Fetch operator key
if [ "${TARGET_ENVIRONMENT}" == "mock" ]; then
  ROOT="."
  ADMIN_ROOT="${ROOT}/uid2-admin"
  METADATA_ROOT="${ADMIN_ROOT}/src/main/resources/localstack/s3/core"
  OPERATOR_FILE="${METADATA_ROOT}/operators/operators.json"
  ENCLAVE_FILE="${METADATA_ROOT}/enclaves/enclaves.json"

  OPERATOR_KEY=$(jq -r '.[] | select(.protocol=="'${ENCLAVE_PROTOCOL}'") | .key' ${OPERATOR_FILE})

  # Update enclave ID
  cat <<< $(jq '(.[] | select((.protocol=="'${ENCLAVE_PROTOCOL}'") and (.name | test(".*Debug.*") | not)) | .identifier) |="'${ENCLAVE_ID}'"' ${ENCLAVE_FILE}) > ${ENCLAVE_FILE}
  cat ${ENCLAVE_FILE}
elif [ "${IDENTITY_SCOPE}" == "UID2" && "${TARGET_ENVIRONMENT}" == "integ" && "${ENCLAVE_PROTOCOL}" == "gcp-oidc" ]; then
  OPERATOR_KEY=${E2E_UID2_INTEG_GCP_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "UID2" && "${TARGET_ENVIRONMENT}" == "integ" && "${ENCLAVE_PROTOCOL}" == "azure-cc" ]; then
  OPERATOR_KEY=${E2E_UID2_INTEG_AZURE_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "UID2" && "${TARGET_ENVIRONMENT}" == "integ" && "${ENCLAVE_PROTOCOL}" == "aws-nitro" ]; then
  OPERATOR_KEY=${E2E_UID2_INTEG_AWS_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "UID2" && "${TARGET_ENVIRONMENT}" == "prod" && "${ENCLAVE_PROTOCOL}" == "gcp-oidc" ]; then
  OPERATOR_KEY=${E2E_UID2_PROD_GCP_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "UID2" && "${TARGET_ENVIRONMENT}" == "prod" && "${ENCLAVE_PROTOCOL}" == "azure-cc" ]; then
  OPERATOR_KEY=${E2E_UID2_PROD_AZURE_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "UID2" && "${TARGET_ENVIRONMENT}" == "prod" && "${ENCLAVE_PROTOCOL}" == "aws-nitro" ]; then
  OPERATOR_KEY=${E2E_UID2_PROD_AWS_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "EUID" && "${TARGET_ENVIRONMENT}" == "integ" && "${ENCLAVE_PROTOCOL}" == "aws-nitro" ]; then
  OPERATOR_KEY=${E2E_EUID_INTEG_AWS_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "EUID" && "${TARGET_ENVIRONMENT}" == "prod" && "${ENCLAVE_PROTOCOL}" == "aws-nitro" ]; then
  OPERATOR_KEY=${E2E_EUID_PROD_AWS_OPERATOR_API_KEY}
else
  echo "Arguments not supported: IDENTITY_SCOPE=${IDENTITY_SCOPE}, TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT}, ENCLAVE_PROTOCOL=${ENCLAVE_PROTOCOL}"
  exit 1
fi

# Export to GitHub output
echo "OPERATOR_KEY=${OPERATOR_KEY}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "OPERATOR_KEY=${OPERATOR_KEY}" >> ${GITHUB_OUTPUT}
fi

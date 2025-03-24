#!/usr/bin/env bash
set -ex

if [ -z "${IDENTITY_SCOPE}" ]; then
  echo "IDENTITY_SCOPE can not be empty"
  exit 1
fi

if [ -z "${TARGET_ENVIRONMENT}" ]; then
  echo "TARGET_ENVIRONMENT can not be empty"
  exit 1
fi

if [ -z "${ENCLAVE_PROTOCOL}" ]; then
  echo "ENCLAVE_PROTOCOL can not be empty"
  exit 1
fi

# Fetch operator key
if [ "${TARGET_ENVIRONMENT}" == "mock" ]; then
  ROOT="./uid2-admin/src/main/resources/localstack/s3/core"
  OPERATOR_FILE="${ROOT}/operators/operators.json"

  OPERATOR_KEY=$(jq -r '.[] | select(.protocol=="'${ENCLAVE_PROTOCOL}'") | .key' ${OPERATOR_FILE})
elif [ "${IDENTITY_SCOPE}" == "UID2" ] && [ "${TARGET_ENVIRONMENT}" == "integ" ]; then
  OPERATOR_KEY=${E2E_UID2_INTEG_PRIVATE_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "UID2" ] && [ "${TARGET_ENVIRONMENT}" == "prod" ]; then
  OPERATOR_KEY=${E2E_UID2_PROD_PRIVATE_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "EUID" ] && [ "${TARGET_ENVIRONMENT}" == "integ" ]; then
  OPERATOR_KEY=${E2E_EUID_INTEG_PRIVATE_OPERATOR_API_KEY}
elif [ "${IDENTITY_SCOPE}" == "EUID" ] && [ "${TARGET_ENVIRONMENT}" == "prod" ]; then
  OPERATOR_KEY=${E2E_EUID_PROD_PRIVATE_OPERATOR_API_KEY}
else
  echo "Arguments not supported: IDENTITY_SCOPE=${IDENTITY_SCOPE}, TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT}"
  exit 1
fi

# Export to GitHub output
echo "OPERATOR_KEY=${OPERATOR_KEY}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "OPERATOR_KEY=${OPERATOR_KEY}" >> ${GITHUB_OUTPUT}
fi

#!/usr/bin/env bash
set -ex

ROOT="."
ADMIN_ROOT="${ROOT}/uid2-admin"
METADATA_ROOT="${ADMIN_ROOT}/src/main/resources/localstack/s3/core"
OPERATOR_FILE="${METADATA_ROOT}/operators/operators.json"
ENCLAVE_FILE="${METADATA_ROOT}/enclaves/enclaves.json"

# Fetch operator key
if [ "${ENCLAVE_PROTOCOL}" == "aws-nitro" ]; then
  OPERATOR_KEY=${E2E_UID2_PROD_AWS_OPERATOR_API_KEY}
elif [ "${ENCLAVE_PROTOCOL}" == "gcp-oidc" ]; then
  OPERATOR_KEY=${E2E_UID2_PROD_GCP_OPERATOR_API_KEY}
else
  OPERATOR_KEY=$(jq -r '.[] | select(.protocol=="'${ENCLAVE_PROTOCOL}'") | .key' ${OPERATOR_FILE})
fi

# Update enclave ID
cat <<< $(jq '(.[] | select((.protocol=="'${ENCLAVE_PROTOCOL}'") and (.name | test(".*Debug.*") | not)) | .identifier) |="'${ENCLAVE_ID}'"' ${ENCLAVE_FILE}) > ${ENCLAVE_FILE}
cat ${ENCLAVE_FILE}

# Export to GitHub output
echo "OPERATOR_KEY=${OPERATOR_KEY}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "OPERATOR_KEY=${OPERATOR_KEY}" >> ${GITHUB_OUTPUT}
fi

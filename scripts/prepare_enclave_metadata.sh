#!/usr/bin/env bash
set -ex

if [ -z "${ADMIN_ROOT}" ]; then
  echo "ADMIN_ROOT can not be empty"
  exit 1
fi

if [ -z "${ENCLAVE_ID}" ]; then
  echo "ENCLAVE_ID can not be empty"
  exit 1
fi

if [ -z "${ENCLAVE_PROTOCOL}" ]; then
  echo "ENCLAVE_PROTOCOL can not be empty"
  exit 1
fi

ROOT="."
METADATA_ROOT="${ADMIN_ROOT}/src/main/resources/localstack/s3/core"
OPERATOR_FILE="${METADATA_ROOT}/operators/operators.json"
ENCLAVE_FILE="${METADATA_ROOT}/enclaves/enclaves.json"

# Fetch operator key
OPERATOR_KEY=$(jq -r '.[] | select(.protocol=="'${ENCLAVE_PROTOCOL}'") | .key' ${OPERATOR_FILE})

# Update enclave id
cat <<< $(jq '(.[] | select(.protocol=="'${ENCLAVE_PROTOCOL}'") | .identifier) |="'${ENCLAVE_ID}'"' ${ENCLAVE_FILE}) > ${ENCLAVE_FILE}

# export to Github output
echo "OPERATOR_KEY=${OPERATOR_KEY}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "OPERATOR_KEY=${OPERATOR_KEY}" >> ${GITHUB_OUTPUT}
fi

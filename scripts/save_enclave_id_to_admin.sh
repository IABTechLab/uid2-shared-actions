#!/usr/bin/env bash
set -ex

if [ -z "${ENCLAVE_ID}" ]; then
  echo "ENCLAVE_ID can not be empty"
  exit 1
fi

if [ -z "${ENCLAVE_PROTOCOL}" ]; then
  echo "ENCLAVE_PROTOCOL can not be empty"
  exit 1
fi

ROOT="./uid2-admin/src/main/resources/localstack/s3/core"
ENCLAVE_FILE="${ROOT}/enclaves/enclaves.json"

# Update enclave ID
cat <<< $(jq '(.[] | select((.protocol=="'${ENCLAVE_PROTOCOL}'") and (.name | test(".*Debug.*") | not)) | .identifier) |="'${ENCLAVE_ID}'"' ${ENCLAVE_FILE}) > ${ENCLAVE_FILE}
cat ${ENCLAVE_FILE}

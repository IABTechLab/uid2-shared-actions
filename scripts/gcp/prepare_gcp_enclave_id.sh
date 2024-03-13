#!/usr/bin/env bash
set -ex

if [ -z "${IMAGE_HASH}" ]; then
  echo "IMAGE_HASH can not be empty"
  exit 1
fi

# Generate enclave ID
ENCLAVE_STR="V1,true,${IMAGE_HASH}"
echo "ENCLAVE_STR=${ENCLAVE_STR}"

ENCLAVE_ID=$(echo -n ${ENCLAVE_STR} | openssl dgst -sha256 -binary | openssl base64)
echo "ENCLAVE_ID=${ENCLAVE_ID}"

# Export to Github output
if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "ENCLAVE_ID=${ENCLAVE_ID}" >> ${GITHUB_OUTPUT}
fi

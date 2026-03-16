#!/usr/bin/env bash
set -ex

if [[ ! -f ${POLICY_DIGEST_FILE} ]]; then
  echo "POLICY_DIGEST_FILE does not exist"
  exit 1
fi

AZURE_POLICY_DIGEST="$(cat ${POLICY_DIGEST_FILE})"
echo "AZURE_POLICY_DIGEST=${AZURE_POLICY_DIGEST}"

ENCLAVE_ID=${AZURE_POLICY_DIGEST}
echo "ENCLAVE_ID=${ENCLAVE_ID}"

# export to Github output
if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "ENCLAVE_ID=${ENCLAVE_ID}" >> ${GITHUB_OUTPUT}
fi

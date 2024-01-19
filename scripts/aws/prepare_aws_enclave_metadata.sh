#!/usr/bin/env bash
set -ex

# TODO: Get AWS enclave ID

# export to Github output
echo "ENCLAVE_ID=${ENCLAVE_ID}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "not in GitHub action"
else
  echo "ENCLAVE_ID=${ENCLAVE_ID}" >> ${GITHUB_OUTPUT}
fi

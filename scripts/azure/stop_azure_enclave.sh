#!/usr/bin/env bash
set -ex

RESOURCE_GROUP=uid-enclave-ci-cd

if [ -z "${AZURE_CONTAINER_GROUP_NAME}" ]; then
  echo "AZURE_CONTAINER_GROUP_NAME can not be empty"
  exit 1
fi

az container delete \
  -g ${RESOURCE_GROUP} \
  -n ${AZURE_CONTAINER_GROUP_NAME} -y

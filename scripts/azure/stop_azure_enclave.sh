#!/usr/bin/env bash
set -ex

if [ -z "${AZURE_CONTAINER_GROUP_NAME}" ]; then
  echo "AZURE_CONTAINER_GROUP_NAME can not be empty"
  exit 1
fi

RESOURCE_GROUP="uid-enclave-ci-cd"

az container delete \
  -g ${RESOURCE_GROUP} \
  -n ${AZURE_CONTAINER_GROUP_NAME} -y

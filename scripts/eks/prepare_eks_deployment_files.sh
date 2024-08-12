#!/usr/bin/env bash
set -ex

if [ -z "${OPERATOR_ROOT}" ]; then
  echo "${OPERATOR_ROOT} can not be empty"
  exit 1
fi

if [ -z "${IMAGE_VERSION}" ]; then
  echo "IMAGE_VERSION can not be empty"
  exit 1
fi

ROOT="."
DEPLOYMENT_FILES_ROOT="${OPERATOR_ROOT}/scripts/aws/eks/deployment-files"

ls -al

IMAGE="ghcr.io/iabtechlab/uid2-operator-eks-uid2:${IMAGE_VERSION}"

sed -i "s#IMAGE_PLACEHOLDER#${IMAGE}#g" "${DEPLOYMENT_FILES_ROOT}/deployment.yaml"
if [[ $? -ne 0 ]]; then
  echo "Failed to pre-process deployment file"
  exit 1
fi

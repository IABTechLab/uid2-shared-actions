#!/usr/bin/env bash
set -ex

if [ -z "${IMAGE_VERSION}" ]; then
  echo "IMAGE_VERSION can not be empty"
  exit 1
fi

if [ -z "${IDENTITY_SCOPE}" ]; then
  echo "IDENTITY_SCOPE can not be empty"
  exit 1
fi

ROOT="./uid2-operator/scripts/aws/eks/deployment_files"
DEPLOYMENT_FILE="${ROOT}/test-deployment.yaml"

ls -al

IMAGE="ghcr.io/iabtechlab/uid2-operator-eks-${IDENTITY_SCOPE,,}:${IMAGE_VERSION}"

sed -i "s#IMAGE_PLACEHOLDER#${IMAGE}#g" "${DEPLOYMENT_FILE}"
sed -i "s#NAMESPACE_PLACEHOLDER#${IDENTITY_SCOPE,,}#g" "${DEPLOYMENT_FILE}"
if [[ $? -ne 0 ]]; then
  echo "Failed to pre-process deployment file"
  exit 1
fi
cat ${DEPLOYMENT_FILE}

#!/usr/bin/env bash
set -ex

if [ -z "${IMAGE_VERSION}" ]; then
  echo "IMAGE_VERSION can not be empty"
  exit 1
fi

if [ -z "${OPERATOR_ROOT}" ]; then
  echo "OPERATOR_ROOT can not be empty"
  exit 1
fi

ROOT="uid2-shared-actions/scripts/aks"
OUTPUT_DIR="${ROOT}/azure-aks-artifacts"

IMAGE="ghcr.io/iabtechlab/uid2-operator:${IMAGE_VERSION}"

if [ -d "${OUTPUT_DIR}" ]; then
  echo "${OUTPUT_DIR} exists"
fi

INPUT_TEMPLATE_FILE="${OPERATOR_ROOT}/scripts/azure-vn/deployment/operator.yaml"
OUTPUT_TEMPLATE_FILE="${OUTPUT_DIR}/operator.yaml"
OUTPUT_POLICY_DIGEST_FILE="${OUTPUT_DIR}/aks-digest.txt"

if [[ -d ${OUTPUT_DIR} ]]; then
  echo "${OUTPUT_DIR} exists, skipping - this only happens during local testing"
else
  mkdir -p ${OUTPUT_DIR}

  # Install confcom extension, az is originally available in GitHub workflow environment
  az extension add --name confcom
  if [[ $? -ne 0 ]]; then
    echo "Failed to install Azure confcom extension"
    exit 1
  fi

  # Required by az confcom
  sudo usermod -aG docker ${USER}
  if [[ $? -ne 0 ]]; then
    echo "Failed to add current user to Docker group"
    exit 1
  fi

  # Generate deployment template
  cp ${INPUT_TEMPLATE_FILE} ${OUTPUT_TEMPLATE_FILE}
  sed -i "s#IMAGE_PLACEHOLDER#${IMAGE}#g" ${OUTPUT_TEMPLATE_FILE}
  if [[ $? -ne 0 ]]; then
    echo "Failed to pre-process template file"
    exit 1
  fi

  # Generate policy using debug mode as we will need to override environment variables
  yes | az confcom acipolicygen --virtual-node-yaml ${OUTPUT_TEMPLATE_FILE} --debug-mode > ${OUTPUT_POLICY_DIGEST_FILE}
  if [[ $? -ne 0 ]]; then
    echo "Failed to generate template file"
    exit 1
  fi
  sed -i 's/.*(y\/n) //g' "${OUTPUT_POLICY_DIGEST_FILE}"
fi

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "OUTPUT_TEMPLATE_FILE=${OUTPUT_TEMPLATE_FILE}" >> ${GITHUB_OUTPUT}
  echo "OUTPUT_POLICY_DIGEST_FILE=${OUTPUT_POLICY_DIGEST_FILE}" >> ${GITHUB_OUTPUT}
fi

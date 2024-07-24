#!/usr/bin/env bash
set -ex

ROOT="uid2-shared-actions/scripts/azure"
INPUT_DIR="${ROOT}/artifacts_schema"
OUTPUT_DIR="${ROOT}/azure-artifacts"

if [ -z "${IMAGE_VERSION}" ]; then
  echo "IMAGE_VERSION can not be empty"
  exit 1
fi

IMAGE="ghcr.io/iabtechlab/uid2-operator:${IMAGE_VERSION}"

if [ -d "${OUTPUT_DIR}" ]; then
  echo "${OUTPUT_DIR} exists"
fi

INPUT_TEMPLATE_FILE="${INPUT_DIR}/template.json"
INPUT_PARAMETERS_FILE="${INPUT_DIR}/parameters.json"
OUTPUT_TEMPLATE_FILE="${OUTPUT_DIR}/template.json"
OUTPUT_PARAMETERS_FILE="${OUTPUT_DIR}/parameters.json"
OUTPUT_POLICY_DIGEST_FILE="${OUTPUT_DIR}/digest.txt"

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
  else
    echo "Successfully added current user to Docker group"
  fi

  # Generate deployment template
  cp ${INPUT_TEMPLATE_FILE} ${OUTPUT_TEMPLATE_FILE}
  sed -i "s#IMAGE_PLACEHOLDER#${IMAGE}#g" ${OUTPUT_TEMPLATE_FILE}
  if [[ $? -ne 0 ]]; then
    echo "Failed to pre-process template file"
    exit 1
  fi

  cat ${OUTPUT_TEMPLATE_FILE}
  az confcom acipolicygen --approve-wildcards --template-file ${OUTPUT_TEMPLATE_FILE} > ${OUTPUT_POLICY_DIGEST_FILE}
  if [[ $? -ne 0 ]]; then
    echo "Failed to generate template file"
    exit 1
  fi

  cp ${INPUT_PARAMETERS_FILE} ${OUTPUT_PARAMETERS_FILE}
fi

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "OUTPUT_TEMPLATE_FILE=${OUTPUT_TEMPLATE_FILE}" >> ${GITHUB_OUTPUT}
  echo "OUTPUT_PARAMETERS_FILE=${OUTPUT_PARAMETERS_FILE}" >> ${GITHUB_OUTPUT}
  echo "OUTPUT_POLICY_DIGEST_FILE=${OUTPUT_POLICY_DIGEST_FILE}" >> ${GITHUB_OUTPUT}
fi

#!/usr/bin/env bash
set -ex

ROOT="../uid2-shared-actions/scripts"

source "${ROOT}/healthcheck.sh"

if [ -z "${BORE_URL_CORE}" ]; then
  echo "BORE_URL_CORE can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_OPTOUT}" ]; then
  echo "BORE_URL_OPTOUT can not be empty"
  exit 1
fi

if [ -z "${AWS_REGION}" ]; then
  echo "AWS_REGION can not be empty"
  exit 1
fi

if [ -z "${AWS_AMI}" ]; then
  echo "AWS_AMI can not be empty"
  exit 1
fi

if [ -z "${IMAGE_HASH}" ]; then
  echo "IMAGE_HASH can not be empty"
  exit 1
fi

if [ -z "${OPERATOR_KEY}" ]; then
  echo "OPERATOR_KEY can not be empty"
  exit 1
fi

DATE=$(date '+%Y%m%d%H%M%S')
AWS_STACK_NAME="uid2-operator-e2e-${IMAGE_HASH}-${DATE}"

python ${ROOT}/aws/create_cloudformation_stack.py \
  --stackfp "${ROOT}/aws/stacks" \
  --cftemplatefp "../uid2-operator/scripts/aws" \
  --core "${BORE_URL_CORE}" \
  --optout "${BORE_URL_OPTOUT}" \
  --region "${AWS_REGION}" \
  --ami "${AWS_AMI}" \
  --stack "${AWS_STACK_NAME}" \
  --key "${OPERATOR_KEY}"

aws cloudformation describe-stacks \
  --stack-name "${AWS_STACK_NAME}" \
  --region "${AWS_REGION}"

# Export to GitHub output
echo "AWS_STACK_NAME=${AWS_STACK_NAME}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "AWS_STACK_NAME=${AWS_STACK_NAME}" >> ${GITHUB_OUTPUT}
fi

# Get public URL
python ${ROOT}/aws/get_instance_url.py \
  --region "${AWS_REGION}" \
  --stack "${AWS_STACK_NAME}"

echo "Instance URL: ${AWS_INSTANCE_URL}"
echo "uid2_e2e_pipeline_operator_url=${AWS_INSTANCE_URL}:8080" >> ${GITHUB_OUTPUT}

HEALTHCHECK_URL="${AWS_INSTANCE_URL}:8080/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

#!/usr/bin/env bash
set -ex

if [ -z "${BORE_URL_CORE}" ]; then
  echo "BORE_URL_CORE can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_OPTOUT}" ]; then
  echo "BORE_URL_OPTOUT can not be empty"
  exit 1
fi

if [ -z "${REGION}" ]; then
  echo "REGION can not be empty"
  exit 1
fi

if [ -z "${AMI}" ]; then
  echo "AMI can not be empty"
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

AWS_STACK_NAME="uid2-operator-e2e-${IMAGE_HASH}"

python ./uid2-shared-actions/scripts/aws/create_cloudformation_stack.py \
  --core="${BORE_URL_CORE}" \
  --optout="${BORE_URL_OPTOUT}" \
  --region="${REGION}" \
  --ami="${AMI}" \
  --stack="${AWS_STACK_NAME}" \
  --key="${OPERATOR_KEY}"

aws cloudformation describe-stacks \
  --stack-name="${AWS_STACK_NAME}" \
  --region="${REGION}"

# Export to GitHub output
echo "AWS_STACK_NAME=${AWS_STACK_NAME}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "not in GitHub action"
else
  echo "AWS_STACK_NAME=${AWS_STACK_NAME}" >> ${GITHUB_OUTPUT}
fi

# Get public URL
python ./uid2-shared-actions/scripts/aws/get_instance_url.py \
  --region="${REGION}" \
  --stack="${AWS_STACK_NAME}"

echo "Instance URL: ${AWS_INSTANCE_URL}"
echo "uid2_e2e_pipeline_operator_url=${AWS_INSTANCE_URL}:8080" >> ${GITHUB_OUTPUT}

HEALTHCHECK_URL="${AWS_INSTANCE_URL}:8080/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

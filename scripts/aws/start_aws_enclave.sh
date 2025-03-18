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

if [ -z "${BORE_URL_LOCALSTACK}" ]; then
  echo "BORE_URL_LOCALSTACK can not be empty"
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

if [ -z "${IDENTITY_SCOPE}" ]; then
  echo "IDENTITY_SCOPE can not be empty"
  exit 1
fi

if [ -z "${TARGET_ENVIRONMENT}" ]; then
  echo "TARGET_ENVIRONMENT can not be empty"
  exit 1
fi

if [ -z "${OPERATOR_KEY}" ]; then
  echo "OPERATOR_KEY can not be empty"
  exit 1
fi

ROOT="./uid2-shared-actions/scripts"

source "${ROOT}/healthcheck.sh"

DATE=$(date '+%Y%m%d%H%M%S')
AWS_STACK_NAME="uid2-operator-e2e-${AWS_AMI}-${DATE}"

CF_TEMPLATE_SCOPE=""
case "${IDENTITY_SCOPE}" in
  UID2) CF_TEMPLATE_SCOPE="UID" ;;
  EUID) CF_TEMPLATE_SCOPE="EUID" ;;
  *)
    echo "IDENTITY_SCOPE is invalid"
    exit 1 ;;
esac

python ${ROOT}/aws/create_cloudformation_stack.py \
  --stack_fp "${ROOT}/aws/stacks" \
  --cftemplate_fp "../uid2-operator/scripts/aws" \
  --core_url "${BORE_URL_CORE}" \
  --optout_url "${BORE_URL_OPTOUT}" \
  --localstack_url "${BORE_URL_LOCALSTACK}" \
  --region "${AWS_REGION}" \
  --ami "${AWS_AMI}" \
  --stack "${AWS_STACK_NAME}" \
  --scope "${CF_TEMPLATE_SCOPE}" \
  --env "${TARGET_ENVIRONMENT}" \
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
AWS_INSTANCE_URL=$(python ${ROOT}/aws/get_instance_url.py \
  --region "${AWS_REGION}" \
  --stack "${AWS_STACK_NAME}")

echo "Instance URL: ${AWS_INSTANCE_URL}"
echo "uid2_e2e_pipeline_operator_url=${AWS_INSTANCE_URL}" >> ${GITHUB_OUTPUT}

HEALTHCHECK_URL="${AWS_INSTANCE_URL}/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

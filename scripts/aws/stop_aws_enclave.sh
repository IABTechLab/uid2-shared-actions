#!/usr/bin/env bash
set -ex

if [ -z "${AWS_STACK_NAME}" ]; then
  echo "AWS_STACK_NAME can not be empty"
  exit 1
fi

if [ -z "${AWS_REGION}" ]; then
  echo "AWS_REGION can not be empty"
  exit 1
fi

aws cloudformation delete-stack \
    --stack-name="${AWS_STACK_NAME}" \
    --region="${AWS_REGION}" || echo "failed to delete or nothing to delete"

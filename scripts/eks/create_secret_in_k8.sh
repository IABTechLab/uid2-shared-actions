#!/usr/bin/env bash
set -ex

if [ -z "${OPERATOR_KEY}" ]; then
  echo "OPERATOR_KEY can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_CORE}" ]; then
  echo "BORE_URL_CORE can not be empty"
  exit 1
fi

if [ -z "${BORE_URL_OPTOUT}" ]; then
  echo "BORE_URL_OPTOUT can not be empty"
  exit 1
fi

source "uid2-shared-actions/scripts/jq_helper.sh"

SECRET_JSON_FILE="uid2-shared-actions/scripts/eks/secret.json"

jq_string_update ${SECRET_JSON_FILE} core_base_url "http://${BORE_URL_CORE}"
jq_string_update ${SECRET_JSON_FILE} optout_base_url "http://${BORE_URL_OPTOUT}"
jq_string_update ${SECRET_JSON_FILE} api_token "${OPERATOR_KEY}"

cat ${SECRET_JSON_FILE}

kubectl create namespace compute
kubectl create secret generic github-test-secret --from-file=config=uid2-shared-actions/scripts/eks/secret.json -n compute

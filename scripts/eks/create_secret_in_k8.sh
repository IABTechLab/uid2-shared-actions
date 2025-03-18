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

if [ -z "${IDENTITY_SCOPE}" ]; then
  echo "IDENTITY_SCOPE can not be empty"
  exit 1
fi

if [ -z "${OPERATOR_KEY}" ]; then
  echo "OPERATOR_KEY can not be empty"
  exit 1
fi

ROOT="./uid2-shared-actions/scripts"
SECRET_JSON_FILE="${ROOT}/eks/secret.json"

source "${ROOT}/jq_helper.sh"

if [ "${TARGET_ENVIRONMENT}" == "mock" ]; then
  jq_string_update ${SECRET_JSON_FILE} core_base_url "http://${BORE_URL_CORE}"
  jq_string_update ${SECRET_JSON_FILE} optout_base_url "http://${BORE_URL_OPTOUT}"
else
  jq_string_update ${SECRET_JSON_FILE} core_base_url "https://${BORE_URL_CORE}"
  jq_string_update ${SECRET_JSON_FILE} optout_base_url "https://${BORE_URL_OPTOUT}"
fi
jq_string_update ${SECRET_JSON_FILE} api_token "${OPERATOR_KEY}"

cat ${SECRET_JSON_FILE}

kubectl create namespace ${IDENTITY_SCOPE,,}
kubectl create secret generic github-test-secret --from-file=config=uid2-shared-actions/scripts/eks/secret.json -n ${IDENTITY_SCOPE,,}

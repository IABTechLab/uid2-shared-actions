#!/usr/bin/env bash
set -ex

if [ -z "${BORE_URL}" ]; then
  echo "BORE_URL can not be empty"
  exit 1
fi

if [ -z "${BORE_SECRET}" ]; then
  echo "BORE_SECRET can not be empty"
  exit 1
fi

if [ -z "${TARGET_ENVIRONMENT}" ]; then
  echo "TARGET_ENVIRONMENT can not be empty"
  exit 1
fi

if [ "${TARGET_ENVIRONMENT}" == "mock" ]; then
  ROOT="."

  docker run --init --rm --network e2e_default ekzhang/bore local --local-host localstack --to ${BORE_URL} --secret ${BORE_SECRET} 5001  > ${ROOT}/bore_localstack.out &
  docker run --init --rm --network e2e_default ekzhang/bore local --local-host core --to ${BORE_URL} --secret ${BORE_SECRET} 8088  > ${ROOT}/bore_core.out &
  docker run --init --rm --network e2e_default ekzhang/bore local --local-host optout --to ${BORE_URL} --secret ${BORE_SECRET} 8081  > ${ROOT}/bore_optout.out &

  until [ -f ${ROOT}/bore_localstack.out ] && [ -f ${ROOT}/bore_core.out ] && [ -f ${ROOT}/bore_optout.out ]
  do
    sleep 5
  done

  cat ${ROOT}/bore_localstack.out
  cat ${ROOT}/bore_core.out
  cat ${ROOT}/bore_optout.out

  BORE_URL_LOCALSTACK=$(cat ${ROOT}/bore_localstack.out | grep at | cut -d ' ' -f7)
  BORE_URL_CORE=$(cat ${ROOT}/bore_core.out | grep at | cut -d ' ' -f7)
  BORE_URL_OPTOUT=$(cat ${ROOT}/bore_optout.out | grep at | cut -d ' ' -f7)
elif [ "${IDENTITY_SCOPE}" == "UID2" ] && [ "${TARGET_ENVIRONMENT}" == "integ" ]; then
  BORE_URL_LOCALSTACK="NOT_REQUIRED"
  BORE_URL_CORE="core-integ.uidapi.com"
  BORE_URL_OPTOUT="optout-integ.uidapi.com"
elif [ "${IDENTITY_SCOPE}" == "UID2" ] && [ "${TARGET_ENVIRONMENT}" == "prod" ]; then
  BORE_URL_LOCALSTACK="NOT_REQUIRED"
  BORE_URL_CORE="core-prod.uidapi.com"
  BORE_URL_OPTOUT="optout-prod.uidapi.com"
elif [ "${IDENTITY_SCOPE}" == "EUID" ] && [ "${TARGET_ENVIRONMENT}" == "integ" ]; then
  BORE_URL_LOCALSTACK="NOT_REQUIRED"
  BORE_URL_CORE="core.integ.euid.eu"
  BORE_URL_OPTOUT="optout.integ.euid.eu"
elif [ "${IDENTITY_SCOPE}" == "EUID" ] && [ "${TARGET_ENVIRONMENT}" == "prod" ]; then
  BORE_URL_LOCALSTACK="NOT_REQUIRED"
  BORE_URL_CORE="core.prod.euid.eu"
  BORE_URL_OPTOUT="optout.prod.euid.eu"
else
  echo "Arguments not supported: IDENTITY_SCOPE=${IDENTITY_SCOPE}, TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT}"
  exit 1
fi

# Export to Github output
echo "BORE_URL_LOCALSTACK=${BORE_URL_LOCALSTACK}"
echo "BORE_URL_CORE=${BORE_URL_CORE}"
echo "BORE_URL_OPTOUT=${BORE_URL_OPTOUT}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "BORE_URL_LOCALSTACK=${BORE_URL_LOCALSTACK}" >> ${GITHUB_OUTPUT}
  echo "BORE_URL_CORE=${BORE_URL_CORE}" >> ${GITHUB_OUTPUT}
  echo "BORE_URL_OPTOUT=${BORE_URL_OPTOUT}" >> ${GITHUB_OUTPUT}
fi

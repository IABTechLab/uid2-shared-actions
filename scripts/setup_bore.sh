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

  # Wait for bore tunnels to establish and output their URLs (not just for files to exist)
  echo "Waiting for bore tunnels to establish..."
  for i in {1..60}; do
    BORE_URL_LOCALSTACK=$(grep -o 'listening at [^ ]*' ${ROOT}/bore_localstack.out 2>/dev/null | cut -d ' ' -f3 || echo "")
    BORE_URL_CORE=$(grep -o 'listening at [^ ]*' ${ROOT}/bore_core.out 2>/dev/null | cut -d ' ' -f3 || echo "")
    BORE_URL_OPTOUT=$(grep -o 'listening at [^ ]*' ${ROOT}/bore_optout.out 2>/dev/null | cut -d ' ' -f3 || echo "")
    
    if [ -n "${BORE_URL_LOCALSTACK}" ] && [ -n "${BORE_URL_CORE}" ] && [ -n "${BORE_URL_OPTOUT}" ]; then
      echo "All bore tunnels established!"
      break
    fi
    echo "Attempt ${i}/60: Waiting for bore tunnels..."
    sleep 5
  done

  if [ -z "${BORE_URL_LOCALSTACK}" ] || [ -z "${BORE_URL_CORE}" ] || [ -z "${BORE_URL_OPTOUT}" ]; then
    echo "ERROR: Failed to establish bore tunnels after 5 minutes"
    echo "bore_localstack.out contents:"
    cat ${ROOT}/bore_localstack.out 2>/dev/null || echo "(file not found)"
    echo "bore_core.out contents:"
    cat ${ROOT}/bore_core.out 2>/dev/null || echo "(file not found)"
    echo "bore_optout.out contents:"
    cat ${ROOT}/bore_optout.out 2>/dev/null || echo "(file not found)"
    exit 1
  fi

  PROTOCOL="http"
else
  PROTOCOL="https"
  BORE_URL_LOCALSTACK="NOT_REQUIRED"

  if [ "${IDENTITY_SCOPE}" == "UID2" ] && [ "${TARGET_ENVIRONMENT}" == "integ" ]; then
    BORE_URL_CORE="core-integ.uidapi.com"
    BORE_URL_OPTOUT="optout-integ.uidapi.com"
  elif [ "${IDENTITY_SCOPE}" == "UID2" ] && [ "${TARGET_ENVIRONMENT}" == "prod" ]; then
    BORE_URL_CORE="core-prod.uidapi.com"
    BORE_URL_OPTOUT="optout-prod.uidapi.com"
  elif [ "${IDENTITY_SCOPE}" == "EUID" ] && [ "${TARGET_ENVIRONMENT}" == "integ" ]; then
    BORE_URL_CORE="core.integ.euid.eu"
    BORE_URL_OPTOUT="optout.integ.euid.eu"
  elif [ "${IDENTITY_SCOPE}" == "EUID" ] && [ "${TARGET_ENVIRONMENT}" == "prod" ]; then
    BORE_URL_CORE="core.prod.euid.eu"
    BORE_URL_OPTOUT="optout.prod.euid.eu"
  else
    echo "Arguments not supported: IDENTITY_SCOPE=${IDENTITY_SCOPE}, TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT}"
    exit 1
  fi
fi

# Export to Github output
echo "BORE_URL_LOCALSTACK=${PROTOCOL}://${BORE_URL_LOCALSTACK}"
echo "BORE_URL_CORE=${PROTOCOL}://${BORE_URL_CORE}"
echo "BORE_URL_OPTOUT=${PROTOCOL}://${BORE_URL_OPTOUT}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "BORE_URL_LOCALSTACK=${PROTOCOL}://${BORE_URL_LOCALSTACK}" >> ${GITHUB_OUTPUT}
  echo "BORE_URL_CORE=${PROTOCOL}://${BORE_URL_CORE}" >> ${GITHUB_OUTPUT}
  echo "BORE_URL_OPTOUT=${PROTOCOL}://${BORE_URL_OPTOUT}" >> ${GITHUB_OUTPUT}
fi

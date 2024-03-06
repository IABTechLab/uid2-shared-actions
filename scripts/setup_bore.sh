#!/usr/bin/env bash
set -ex

ROOT="."

docker run --init --rm --network e2e_default ekzhang/bore local --local-host localstack --to bore.pub 5001  > ${ROOT}/bore_localstack.out &
docker run --init --rm --network e2e_default ekzhang/bore local --local-host core --to bore.pub 8088  > ${ROOT}/bore_core.out &
docker run --init --rm --network e2e_default ekzhang/bore local --local-host loki --to bore.pub 3100  > ${ROOT}/bore_loki.out &
docker run --init --rm --network e2e_default ekzhang/bore local --local-host optout --to bore.pub 8081  > ${ROOT}/bore_optout.out &

until [ -f ${ROOT}/bore_localstack.out ] && [ -f ${ROOT}/bore_core.out ] && [ -f ${ROOT}/bore_loki.out ] && [ -f ${ROOT}/bore_optout.out ]
do
  sleep 5
done

cat ${ROOT}/bore_localstack.out
cat ${ROOT}/bore_core.out
cat ${ROOT}/bore_loki.out
cat ${ROOT}/bore_optout.out

BORE_URL_LOCALSTACK=$(cat ${ROOT}/bore_localstack.out | grep at | cut -d ' ' -f7)
BORE_URL_CORE=$(cat ${ROOT}/bore_core.out | grep at | cut -d ' ' -f7)
BORE_URL_LOKI=$(cat ${ROOT}/bore_loki.out | grep at | cut -d ' ' -f7)
BORE_URL_OPTOUT=$(cat ${ROOT}/bore_optout.out | grep at | cut -d ' ' -f7)

# export to Github output
echo "BORE_URL_LOCALSTACK=${BORE_URL_LOCALSTACK}"
echo "BORE_URL_CORE=${BORE_URL_CORE}"
echo "BORE_URL_LOKI=${BORE_URL_LOKI}"
echo "BORE_URL_OPTOUT=${BORE_URL_OPTOUT}"

if [ -z "${GITHUB_OUTPUT}" ]; then
  echo "Not in GitHub action"
else
  echo "BORE_URL_LOCALSTACK=${BORE_URL_LOCALSTACK}" >> ${GITHUB_OUTPUT}
  echo "BORE_URL_CORE=${BORE_URL_CORE}" >> ${GITHUB_OUTPUT}
  echo "BORE_URL_LOKI=${BORE_URL_LOKI}" >> ${GITHUB_OUTPUT}
  echo "BORE_URL_OPTOUT=${BORE_URL_OPTOUT}" >> ${GITHUB_OUTPUT}
fi

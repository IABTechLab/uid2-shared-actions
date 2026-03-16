#!/usr/bin/env bash
set -x

if [ -z "${OPERATOR_VERSION}" ]; then
  echo "OPERATOR_VERSION can not be empty"
  exit 1
fi

if [ -z "${CORE_VERSION}" ]; then
  echo "CORE_VERSION can not be empty"
  exit 1
fi

if [ -z "${OPTOUT_VERSION}" ]; then
  echo "OPTOUT_VERSION can not be empty"
  exit 1
fi

ROOT="."
OPERATOR_ROOT="${ROOT}/uid2-operator"
CORE_ROOT="${ROOT}/uid2-core"
OPTOUT_ROOT="${ROOT}/uid2-optout"
ADMIN_ROOT="${ROOT}/uid2-admin"
E2E_ROOT="${ROOT}/uid2-e2e"
SHARED_ACTIONS_ROOT="${ROOT}/uid2-shared-actions"
DOCKER_ROOT="${ROOT}/docker"

DOCKER_OPERATOR_CONFIG_FILE_DIR="${DOCKER_ROOT}/uid2-operator/conf"
DOCKER_CORE_CONFIG_FILE_DIR="${DOCKER_ROOT}/uid2-core/conf"
DOCKER_OPTOUT_CONFIG_FILE_DIR="${DOCKER_ROOT}/uid2-optout/conf"

DOCKER_CORE_RESOURCE_FILE_DIR="${DOCKER_ROOT}/uid2-core/src"
DOCKER_OPTOUT_RESOURCE_FILE_DIR="${DOCKER_ROOT}/uid2-optout/src"

source "${SHARED_ACTIONS_ROOT}/scripts/jq_helper.sh"
source "${SHARED_ACTIONS_ROOT}/scripts/healthcheck.sh"

# Prepare conf files
mkdir -p "${DOCKER_OPERATOR_CONFIG_FILE_DIR}"
cp "${OPERATOR_ROOT}/conf/default-config.json" "${DOCKER_OPERATOR_CONFIG_FILE_DIR}"
if [ ${OPERATOR_TYPE} == "public" ]; then
  cp "${OPERATOR_ROOT}/conf/local-e2e-docker-${OPERATOR_TYPE}-config.json" "${DOCKER_OPERATOR_CONFIG_FILE_DIR}/local-e2e-docker-config.json"
fi

mkdir -p "${DOCKER_CORE_CONFIG_FILE_DIR}/operator"
cp "${CORE_ROOT}/conf/default-config.json" "${DOCKER_CORE_CONFIG_FILE_DIR}"
cp "${CORE_ROOT}/conf/local-e2e-docker-config.json" "${DOCKER_CORE_CONFIG_FILE_DIR}"
cp "${CORE_ROOT}/conf/operator/operator-config.json" "${DOCKER_CORE_CONFIG_FILE_DIR}/operator"
cp -r "${ADMIN_ROOT}/src/main/resources/localstack" "${DOCKER_CORE_RESOURCE_FILE_DIR}"

mkdir -p "${DOCKER_OPTOUT_CONFIG_FILE_DIR}"
cp "${OPTOUT_ROOT}/conf/default-config.json" "${DOCKER_OPTOUT_CONFIG_FILE_DIR}"
cp "${OPTOUT_ROOT}/conf/local-e2e-docker-config.json" "${DOCKER_OPTOUT_CONFIG_FILE_DIR}"
cp "${OPTOUT_ROOT}/run_tool_local_e2e.sh" "${DOCKER_OPTOUT_CONFIG_FILE_DIR}"
cp -r "${OPTOUT_ROOT}/src/main/resources/localstack" "${DOCKER_OPTOUT_RESOURCE_FILE_DIR}"

cp "${E2E_ROOT}/docker-compose.yml" "${ROOT}"

DOCKER_COMPOSE_FILE="${ROOT}/docker-compose.yml"
DOCKER_OPERATOR_CONFIG_FILE="${DOCKER_OPERATOR_CONFIG_FILE_DIR}/local-e2e-docker-config.json"
DOCKER_CORE_CONFIG_FILE="${DOCKER_CORE_CONFIG_FILE_DIR}/local-e2e-docker-config.json"
DOCKER_OPTOUT_CONFIG_FILE="${DOCKER_OPTOUT_CONFIG_FILE_DIR}/local-e2e-docker-config.json"
DOCKER_OPTOUT_MOUNT="${ROOT}/docker/uid2-optout/mount"

# Replace placeholders
sed -i.bak "s#uid2-operator:latest#uid2-operator:${OPERATOR_VERSION}#g" ${DOCKER_COMPOSE_FILE}
sed -i.bak "s#uid2-core:latest#uid2-core:${CORE_VERSION}#g" ${DOCKER_COMPOSE_FILE}
sed -i.bak "s#uid2-optout:latest#uid2-optout:${OPTOUT_VERSION}#g" ${DOCKER_COMPOSE_FILE}

# Set provide_private_site_data to false to workaround the private site path
if [ ${OPERATOR_TYPE} != "public" ]; then
  jq_string_update ${DOCKER_CORE_CONFIG_FILE} aws_s3_endpoint "${BORE_URL_LOCALSTACK}"
  jq_string_update ${DOCKER_CORE_CONFIG_FILE} kms_aws_endpoint "${BORE_URL_LOCALSTACK}"
  jq_string_update ${DOCKER_CORE_CONFIG_FILE} core_public_url "${BORE_URL_CORE}"
  jq_string_update ${DOCKER_CORE_CONFIG_FILE} optout_url "${BORE_URL_OPTOUT}"
  jq_number_boolean_update ${DOCKER_CORE_CONFIG_FILE} provide_private_site_data false

  jq_string_update ${DOCKER_OPTOUT_CONFIG_FILE} aws_s3_endpoint "${BORE_URL_LOCALSTACK}"
  jq_string_update ${DOCKER_OPTOUT_CONFIG_FILE} aws_sqs_endpoint "${BORE_URL_LOCALSTACK}"
  jq_string_update ${DOCKER_OPTOUT_CONFIG_FILE} partners_metadata_path "${BORE_URL_CORE}/partners/refresh"
  jq_string_update ${DOCKER_OPTOUT_CONFIG_FILE} operators_metadata_path "${BORE_URL_CORE}/operators/refresh"
  jq_string_update ${DOCKER_OPTOUT_CONFIG_FILE} core_attest_url "${BORE_URL_CORE}/attest"
  jq_string_update ${DOCKER_OPTOUT_CONFIG_FILE} core_public_url "${BORE_URL_CORE}"
  jq_string_update ${DOCKER_OPTOUT_CONFIG_FILE} optout_url "${BORE_URL_OPTOUT}"
fi

jq_string_update ${DOCKER_OPERATOR_CONFIG_FILE} identity_scope ${IDENTITY_SCOPE}

cat ${DOCKER_CORE_CONFIG_FILE}
cat ${DOCKER_OPTOUT_CONFIG_FILE}

if [ ${OPERATOR_TYPE} == "public" ]; then
  cat ${DOCKER_OPERATOR_CONFIG_FILE}
fi
cat ${DOCKER_COMPOSE_FILE}

mkdir -p "${DOCKER_OPTOUT_MOUNT}" && chmod 777 "${DOCKER_OPTOUT_MOUNT}"
chmod 777 "${DOCKER_CORE_RESOURCE_FILE_DIR}/init-aws.sh"
chmod 777 "${DOCKER_OPTOUT_RESOURCE_FILE_DIR}/init-aws.sh"

docker compose --profile "${OPERATOR_TYPE}" -f "${DOCKER_COMPOSE_FILE}" up -d --wait

containers=$(docker compose ps -q)
for container in $containers; do
  status=$(docker inspect --format='{{.State.ExitCode}}' $container)
  if [ "$status" -ne 0 ]; then
    echo "Container $container exited with status $status. Logs:"
    docker logs "$container"
  fi
done

docker ps -a
docker network ls

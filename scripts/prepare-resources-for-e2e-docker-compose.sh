set -ex

# Prepare conf files

ROOT="."
CORE_CONFIG_FILE_DIR="$ROOT/docker/uid2-core/conf"
OPTOUT_CONFIG_FILE_DIR="$ROOT/docker/uid2-optout/conf"
OPERATOR_CONFIG_FILE_DIR="$ROOT/docker/uid2-operator/conf"
CORE_RESOURCE_FILE_DIR="$ROOT/docker/uid2-core/src"
OPTOUT_RESOURCE_FILE_DIR="$ROOT/docker/uid2-optout/src"

source "../uid2-shared-actions/scripts/jq_helper.sh"
source "../uid2-shared-actions/scripts/healthcheck.sh"

if [ -z "$CORE_ROOT" ]; then
  echo "CORE_ROOT can not be empty"
  exit 1
fi

if [ -z "$OPTOUT_ROOT" ]; then
  echo "$OPTOUT_ROOT can not be empty"
  exit 1
fi

if [ -z "$ADMIN_ROOT" ]; then
  echo "$ADMIN_ROOT can not be empty"
  exit 1
fi

if [ -z "$OPERATOR_ROOT" ]; then
  echo "$OPERATOR_ROOT can not be empty"
  exit 1
fi

mkdir -p "$CORE_CONFIG_FILE_DIR"
cp "$CORE_ROOT/conf/default-config.json" "$CORE_CONFIG_FILE_DIR"
cp "$CORE_ROOT/conf/local-e2e-docker-config.json" "$CORE_CONFIG_FILE_DIR"
cp -r "$ADMIN_ROOT/src/main/resources/localstack" "$CORE_RESOURCE_FILE_DIR"
mkdir -p "$OPTOUT_CONFIG_FILE_DIR"
cp "$OPTOUT_ROOT/conf/default-config.json" "$OPTOUT_CONFIG_FILE_DIR"
cp "$OPTOUT_ROOT/conf/local-e2e-docker-config.json" "$OPTOUT_CONFIG_FILE_DIR"
cp "$OPTOUT_ROOT/run_tool_local_e2e.sh" "$OPTOUT_CONFIG_FILE_DIR"
cp -r "$OPTOUT_ROOT/src/main/resources/localstack" "$OPTOUT_RESOURCE_FILE_DIR"
mkdir -p "$OPERATOR_CONFIG_FILE_DIR"
cp "$OPERATOR_ROOT/conf/default-config.json" "$OPERATOR_CONFIG_FILE_DIR"
if [ $OPERATOR_TYPE == "public" ]; then
  cp "$OPERATOR_ROOT/conf/local-e2e-docker-$OPERATOR_TYPE-config.json" "$OPERATOR_CONFIG_FILE_DIR/local-e2e-docker-config.json"
fi

cp "../uid2-e2e/docker-compose.yml" "$ROOT"

CORE_CONFIG_FILE="$ROOT/docker/uid2-core/conf/local-e2e-docker-config.json"
OPTOUT_CONFIG_FILE="$ROOT/docker/uid2-optout/conf/local-e2e-docker-config.json"
OPERATOR_CONFIG_FILE="$ROOT/docker/uid2-operator/conf/local-e2e-docker-config.json"
DOCKER_COMPOSE_FILE="$ROOT/docker-compose.yml"
OPTOUT_MOUNT="$ROOT/docker/uid2-optout/mount"

if [ -z "$CORE_VERSION" ]; then
  echo "CORE_VERSION can not be empty"
  exit 1
fi

if [ -z "$OPTOUT_VERSION" ]; then
  echo "OPTOUT_VERSION can not be empty"
  exit 1
fi

if [ -z "$OPERATOR_VERSION" ]; then
  echo "OPERATOR_VERSION can not be empty"
  exit 1
fi

if [ -z "$E2E_VERSION" ]; then
  echo "E2E_VERSION can not be empty"
  exit 1
fi

# replace placeholders
sed -i.bak "s#uid2-core:latest#uid2-core:$CORE_VERSION#g" $DOCKER_COMPOSE_FILE
sed -i.bak "s#uid2-optout:latest#uid2-optout:$OPTOUT_VERSION#g" $DOCKER_COMPOSE_FILE
sed -i.bak "s#uid2-operator:latest#uid2-operator:$OPERATOR_VERSION#g" $DOCKER_COMPOSE_FILE

# set provide_private_site_data to false to workaround the private site path
# jq_inplace_update $CORE_CONFIG_FILE aws_s3_endpoint "$BORE_URL_LOCALSTACK"
# jq_inplace_update $CORE_CONFIG_FILE kms_aws_endpoint "$BORE_URL_LOCALSTACK"
# jq_inplace_update $CORE_CONFIG_FILE core_public_url "$BORE_URL_CORE"
# jq_inplace_update $CORE_CONFIG_FILE optout_url "$BORE_URL_OPTOUT"
jq_inplace_update_json $CORE_CONFIG_FILE provide_private_site_data false

# jq_inplace_update $OPTOUT_CONFIG_FILE aws_s3_endpoint "$BORE_URL_LOCALSTACK"
# jq_inplace_update $OPTOUT_CONFIG_FILE partners_metadata_path "$BORE_URL_CORE/partners/refresh"
# jq_inplace_update $OPTOUT_CONFIG_FILE operators_metadata_path "$BORE_URL_CORE/operators/refresh"
# jq_inplace_update $OPTOUT_CONFIG_FILE core_attest_url "$BORE_URL_CORE/attest"
# jq_inplace_update $OPTOUT_CONFIG_FILE core_public_url "$BORE_URL_CORE"
# jq_inplace_update $OPTOUT_CONFIG_FILE optout_url "$BORE_URL_OPTOUT"

cat $CORE_CONFIG_FILE
cat $OPTOUT_CONFIG_FILE

if [ $OPERATOR_TYPE == "public" ]; then
  cat $OPERATOR_CONFIG_FILE
fi
cat $DOCKER_COMPOSE_FILE

mkdir -p "$OPTOUT_MOUNT" && chmod 777 "$OPTOUT_MOUNT"
chmod 777 "$CORE_RESOURCE_FILE_DIR/init-aws.sh"
chmod 777 "$OPTOUT_RESOURCE_FILE_DIR/init-aws.sh"

docker compose --profile "$OPERATOR_TYPE" -f "$DOCKER_COMPOSE_FILE" up -d
docker ps -a
docker network ls

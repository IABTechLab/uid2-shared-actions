set -ex

# Prepare conf files

ROOT="."
CORE_CONFIG_FILE_DIR="$ROOT/docker/uid2-core/conf"
OPTOUT_CONFIG_FILE_DIR="$ROOT/docker/uid2-optout/conf"
OPERATOR_CONFIG_FILE_DIR="$ROOT/docker/uid2-operator/conf"
CORE_RESOURCE_FILE_DIR="$ROOT/docker/uid2-core/src"
OPTOUT_RESOURCE_FILE_DIR="$ROOT/docker/uid2-optout/src"


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
cp "$OPERATOR_ROOT/conf/local-e2e-docker-config.json" "$OPERATOR_CONFIG_FILE_DIR"

CORE_CONFIG_FILE="$ROOT/docker/uid2-core/conf/local-e2e-docker-config.json"
OPTOUT_CONFIG_FILE="$ROOT/docker/uid2-optout/conf/local-e2e-docker-config.json"
OPERATOR_CONFIG_FILE="$ROOT/docker/uid2-operator/conf/local-e2e-docker-config.json"
COMPOSE_FILE="$ROOT/docker-compose.yml"
OPTOUT_MOUNT="$ROOT/docker/uid2-optout/mount"


source "$ROOT/jq_helper.sh"
source "$ROOT/healthcheck.sh"

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
sed -i.bak "s#<CORE_VERSION>#$CORE_VERSION#g" $COMPOSE_FILE
sed -i.bak "s#<OPTOUT_VERSION>#$OPTOUT_VERSION#g" $COMPOSE_FILE
sed -i.bak "s#<OPERATOR_VERSION>#$OPERATOR_VERSION#g" $COMPOSE_FILE
sed -i.bak "s#<E2E_VERSION>#$E2E_VERSION#g" $COMPOSE_FILE

cat $CORE_CONFIG_FILE
cat $OPTOUT_CONFIG_FILE
cat $OPERATOR_CONFIG_FILE

mkdir -p "$OPTOUT_MOUNT" && chmod 777 "$OPTOUT_MOUNT"
chmod 777 "$CORE_RESOURCE_FILE_DIR/init-aws.sh"
chmod 777 "$OPTOUT_RESOURCE_FILE_DIR/init-aws.sh"

docker compose -f "$ROOT/e2e/docker-compose.yml" up -d
docker ps -a
docker network ls
#!/usr/bin/env bash
set -ex

ROOT="../uid2-shared-actions/scripts"
GCP_INSTANCE_NAME="ci-test-$RANDOM"
OPERATOR_KEY_SECRET_NAME=$GCP_INSTANCE_NAME

source "$ROOT/healthcheck.sh"

if [ -z "$GCP_PROJECT" ]; then
  echo "GCP_PROJECT can not be empty"
  exit 1
fi

if [ -z "$SERVICE_ACCOUNT" ]; then
  echo "SERVICE_ACCOUNT can not be empty"
  exit 1
fi

if [ -z "$IMAGE_HASH" ]; then
  echo "IMAGE_HASH can not be empty"
  exit 1
fi

if [ -z "$OPERATOR_KEY" ]; then
  echo "OPERATOR_KEY can not be empty"
  exit 1
fi

if [ -z "$BORE_URL_CORE" ]; then
  echo "BORE_URL_CORE can not be empty"
  exit 1
fi

if [ -z "$BORE_URL_OPTOUT" ]; then
  echo "BORE_URL_OPTOUT can not be empty"
  exit 1
fi

gcloud config set project $GCP_PROJECT

gcloud config set compute/zone asia-southeast1-a

# create secret
echo -n "$OPERATOR_KEY" | gcloud secrets create $OPERATOR_KEY_SECRET_NAME \
    --replication-policy="automatic" \
    --data-file=-

OPERATOR_KEY_SECRET_VERSION=$(gcloud secrets versions describe latest --secret $OPERATOR_KEY_SECRET_NAME --format 'value(name)')

gcloud compute instances create $GCP_INSTANCE_NAME \
    --confidential-compute \
    --shielded-secure-boot \
    --maintenance-policy Terminate \
    --scopes cloud-platform \
    --image-project confidential-space-images \
    --image-family confidential-space-debug \
    --service-account $SERVICE_ACCOUNT \
    --metadata ^~^tee-image-reference=us-docker.pkg.dev/uid2-prod-project/iabtechlab/uid2-operator@$IMAGE_HASH~tee-restart-policy=Never~tee-container-log-redirect=true~tee-env-DEPLOYMENT_ENVIRONMENT=integ~tee-env-API_TOKEN_SECRET_NAME=$OPERATOR_KEY_SECRET_VERSION~tee-env-CORE_BASE_URL=$BORE_URL_CORE~tee-env-OPTOUT_BASE_URL=$BORE_URL_OPTOUT

# export to Github output
echo "GCP_INSTANCE_NAME=$GCP_INSTANCE_NAME"

if [ -z "$GITHUB_OUTPUT" ]; then
  echo "not in github action"
else
  echo "GCP_INSTANCE_NAME=$GCP_INSTANCE_NAME" >> $GITHUB_OUTPUT
fi

# get public IP
ip=$(gcloud compute instances describe $GCP_INSTANCE_NAME \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

echo "instance ip: $ip"

healthcheck_url="http://$ip:8080/ops/healthcheck"

# health check - for 5 mins
healthcheck "$healthcheck_url" 60

OPERATOR_KEY_SECRET_NAME=$GCP_INSTANCE_NAME

gcloud config set project $GCP_PROJECT

gcloud config set compute/zone asia-southeast1-a

gcloud compute instances delete $GCP_INSTANCE_NAME --quiet

gcloud secrets delete $OPERATOR_KEY_SECRET_NAME --quiet
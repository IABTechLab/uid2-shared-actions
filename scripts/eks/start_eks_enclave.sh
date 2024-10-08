#!/usr/bin/env bash
set -ex

ROOT="uid2-shared-actions/scripts"
source "${ROOT}/healthcheck.sh"

if [ -z "${OPERATOR_ROOT}" ]; then
  echo "OPERATOR_ROOT can not be empty"
  exit 1
fi

if [ -z "${IDENTITY_SCOPE}" ]; then
  echo "IDENTITY_SCOPE can not be empty"
  exit 1
fi

cat "${OPERATOR_ROOT}/scripts/aws/eks/deployment_files/test-deployment.yaml"

kubectl apply -f "${OPERATOR_ROOT}/scripts/aws/eks/deployment_files/test-deployment.yaml"
kubectl get pods --all-namespaces

kubectl get services -n ${IDENTITY_SCOPE,,}

ps aux

if [ "${IDENTITY_SCOPE}" == "UID2" ]; then
  kubectl port-forward svc/operator-service -n ${IDENTITY_SCOPE,,} 27777:80 &
  EKS_OPERATOR_URL="http://localhost:27777"
elif [ "${IDENTITY_SCOPE}" == "EUID" ]; then
  kubectl port-forward svc/operator-service -n ${IDENTITY_SCOPE,,} 27778:80 &
  EKS_OPERATOR_URL="http://localhost:27778"
else
  echo "IDENTITY_SCOPE provided with wrong value"
  exit 1
fi

ps aux
kubectl get pods --all-namespaces
HEALTHCHECK_URL="${EKS_OPERATOR_URL}/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

echo "uid2_e2e_pipeline_operator_url=${EKS_OPERATOR_URL}" >> ${GITHUB_OUTPUT}

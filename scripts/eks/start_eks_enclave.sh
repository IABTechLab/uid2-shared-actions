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
kubectl port-forward svc/operator-service -n ${IDENTITY_SCOPE,,} 27015:80 > /dev/null 2>&1 &

if [ "${IDENTITY_SCOPE}" == "UID2" ]; then
  EKS_OPERATOR_URL="http://localhost:27015"
elif [ "${IDENTITY_SCOPE}" == "EUID" ]; then
  EKS_OPERATOR_URL="http://localhost:27016"
else
  echo "IDENTITY_SCOPE provided with wrong value"
  exit 1
fi

kubectl get pods --all-namespaces
HEALTHCHECK_URL="${EKS_OPERATOR_URL}/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

echo "uid2_e2e_pipeline_operator_url=${EKS_OPERATOR_URL}" >> ${GITHUB_OUTPUT}

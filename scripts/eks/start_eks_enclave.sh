#!/usr/bin/env bash
set -ex

ROOT="uid2-shared-actions/scripts"
source "${ROOT}/healthcheck.sh"

if [ -z "${OPERATOR_ROOT}" ]; then
  echo "OPERATOR_ROOT can not be empty"
  exit 1
fi

cat "${OPERATOR_ROOT}/scripts/aws/eks/deployment_files/test-deployment.yaml"

kubectl apply -f "${OPERATOR_ROOT}/scripts/aws/eks/deployment_files/test-deployment.yaml"
kubectl get pods --all-namespaces

kubectl get services -n compute
kubectl port-forward svc/operator-service -n compute 27015:80 > /dev/null 2>&1 &
EKS_OPERATOR_URL="http://localhost:27015"

HEALTHCHECK_URL="${EKS_OPERATOR_URL}/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

kubectl get pods --all-namespaces
echo "uid2_e2e_pipeline_operator_url=${EKS_OPERATOR_URL}" >> ${GITHUB_OUTPUT}

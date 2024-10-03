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

# # Function to get the operator pod name
# function get_operator_pod_name() {
#     kubectl get pods -n compute -o name | grep "operator" | head -n 1
# }

# OPERATOR_POD_NAME=$(get_operator_pod_name)

# function is_pod_ready() {
#     kubectl get pods "$OPERATOR_POD_NAME" -n compute -o 'jsonpath={.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep "True" >/dev/null
# }

# MAX_RETRIES=100
# etry_count=0
# while ! is_pod_ready; do
#     if [[ $retry_count -eq $MAX_RETRIES ]]; then
#     echo "Error: Pod $OPERATOR_POD_NAME did not become ready after $MAX_RETRIES retries."
#     exit 1
#     fi

#     echo "Waiting for pod $OPERATOR_POD_NAME to be ready..."
#     sleep 5
#     retry_count=$((retry_count+1))
# done

# echo "Pod $OPERATOR_POD_NAME is ready!"
kubectl get services -n compute
kubectl port-forward svc/operator-service -n compute 27015:80 > /dev/null 2>&1 &
EKS_OPERATOR_URL="http://localhost:27015"

HEALTHCHECK_URL="${EKS_OPERATOR_URL}/ops/healthcheck"

# Health check - for 5 mins
healthcheck "${HEALTHCHECK_URL}" 60

echo "uid2_e2e_pipeline_operator_url=${EKS_OPERATOR_URL}" >> ${GITHUB_OUTPUT}

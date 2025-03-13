#!/usr/bin/env bash
set -ex

export RESOURCE_GROUP="pipeline-vn-aks"
export AKS_CLUSTER_NAME="pipelinevncluster"

az aks get-credentials --name ${AKS_CLUSTER_NAME} --resource-group ${RESOURCE_GROUP}
if kubectl get deployment operator-deployment -o name > /dev/null 2>&1; then
  kubectl delete deployment operator-deployment
  echo "Deployment 'operator-deployment' deleted."
else
  echo "Deployment 'operator-deployment' does not exist."
fi
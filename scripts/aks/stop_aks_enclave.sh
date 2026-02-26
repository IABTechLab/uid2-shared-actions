#!/usr/bin/env bash
set -ex

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks_env.sh"

if az group exists --name ${RESOURCE_GROUP} | grep -q true; then
  echo "Deleting resource group '${RESOURCE_GROUP}'..."
  az group delete --name ${RESOURCE_GROUP} --yes
  echo "Resource group '${RESOURCE_GROUP}' successfully deleted."
else
  echo "Resource group '${RESOURCE_GROUP}' does not exist."
fi
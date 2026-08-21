#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="ckad"

if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "El cluster '${CLUSTER_NAME}' no existe."
  exit 0
fi

echo "Eliminando cluster '${CLUSTER_NAME}'..."

kind delete cluster --name "${CLUSTER_NAME}"

echo "Cluster eliminado correctamente."
#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="ckad"
KIND_IMAGE="kindest/node:v1.36.1"
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/kind-config.yaml"

echo "Validando Docker..."
docker info >/dev/null

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "El cluster '${CLUSTER_NAME}' ya existe."
  exit 0
fi

echo "Descargando imagen Kubernetes..."
docker pull "${KIND_IMAGE}"

echo "Creando cluster '${CLUSTER_NAME}'..."
kind create cluster \
  --name "${CLUSTER_NAME}" \
  --image "${KIND_IMAGE}" \
  --config "${CONFIG_FILE}" \
  --wait 120s

echo
echo "Cluster creado correctamente."
kubectl get nodes -o wide
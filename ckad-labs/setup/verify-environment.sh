#!/usr/bin/env bash

set -u

ERRORS=0

check_command() {
  local command_name="$1"

  if command -v "${command_name}" >/dev/null 2>&1; then
    printf "[OK] %-12s %s\n" "${command_name}" "$(command -v "${command_name}")"
  else
    printf "[ERROR] %-9s no encontrado\n" "${command_name}"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "========================================"
echo " Validacion del entorno CKAD"
echo "========================================"
echo

check_command git
check_command docker
check_command kubectl
check_command kind

echo
echo "Versiones"
echo "----------------------------------------"

git --version 2>/dev/null || true
docker --version 2>/dev/null || true
kubectl version --client 2>/dev/null || true
kind version 2>/dev/null || true

echo
echo "Docker"
echo "----------------------------------------"

if docker info >/dev/null 2>&1; then
  echo "[OK] Docker Engine disponible"

  DOCKER_OS="$(docker info --format '{{.OSType}}' 2>/dev/null)"

  if [[ "${DOCKER_OS}" == "linux" ]]; then
    echo "[OK] Docker utiliza Linux containers"
  else
    echo "[ERROR] Docker no utiliza Linux containers"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "[ERROR] Docker Engine no esta disponible"
  ERRORS=$((ERRORS + 1))
fi

echo
echo "Cluster Kubernetes"
echo "----------------------------------------"

if kind get clusters 2>/dev/null | grep -qx "ckad"; then
  echo "[OK] Cluster ckad encontrado"

  if kubectl config current-context 2>/dev/null | grep -qx "kind-ckad"; then
    echo "[OK] Contexto activo: kind-ckad"
  else
    echo "[ADVERTENCIA] El contexto activo no es kind-ckad"
  fi

  echo
  kubectl get nodes 2>/dev/null || true
else
  echo "[INFO] El cluster ckad aun no ha sido creado"
fi

echo
echo "========================================"

if [[ "${ERRORS}" -eq 0 ]]; then
  echo "Entorno CKAD validado correctamente."
  exit 0
else
  echo "Se detectaron ${ERRORS} problema(s)."
  exit 1
fi
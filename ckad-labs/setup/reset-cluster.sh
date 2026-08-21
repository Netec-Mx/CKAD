#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Reiniciando entorno CKAD..."
echo

"${SCRIPT_DIR}/delete-cluster.sh"

echo
"${SCRIPT_DIR}/create-cluster.sh"

echo
echo "Entorno CKAD reconstruido correctamente."
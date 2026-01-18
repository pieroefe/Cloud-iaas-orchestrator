#!/usr/bin/env bash
set -euo pipefail
cd /home/ubuntu

bash ./vm_orchestrator_fase1.sh
bash ./vm_orchestrator_fase2.sh

echo "----------------------------------------------------"
echo "[OK] Topología completa desplegada."
echo "----------------------------------------------------"
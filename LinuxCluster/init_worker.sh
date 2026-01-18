#!/usr/bin/env bash
set -euo pipefail

BRIDGE="${1:-br-int}"
UPLINK="${2:-ens4}"
VLANS="${3:-100,200,30}"

echo "[INFO] Creando bridge $BRIDGE..."
sudo ovs-vsctl --may-exist add-br "$BRIDGE"
sudo ip link set "$BRIDGE" up

echo "[INFO] Configurando $UPLINK como trunk ($VLANS)..."
sudo ip link set "$UPLINK" up
sudo ovs-vsctl --may-exist add-port "$BRIDGE" "$UPLINK"
sudo ovs-vsctl set Interface "$UPLINK" type=system
sudo ovs-vsctl set Port "$UPLINK" trunks="$VLANS"

# modo bridge (sin controller)
sudo ovs-vsctl set-fail-mode "$BRIDGE" standalone
sudo ovs-ofctl del-flows "$BRIDGE" || true
sudo ovs-ofctl add-flow "$BRIDGE" "actions=NORMAL"

echo "[OK] Worker configurado: $BRIDGE con $UPLINK (trunk=$VLANS)."
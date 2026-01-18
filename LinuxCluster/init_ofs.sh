#!/usr/bin/env bash
# Uso:
#   sudo ./init_ofs.sh [BR] [PORTS_CSV] [VLANS_CSV]
# Ej:
#   sudo ./init_ofs.sh br-ofs "ens5,ens6,ens7,ens8" "100,200,30"
set -euo pipefail

BR="${1:-br-ofs}"
PORTS_CSV="${2:-ens5,ens6,ens7,ens8}"    # ← incluye ens5 (uplink al headnode)
VLANS="${3:-100,200,30}"
IFS=',' read -r -a PORTS <<< "$PORTS_CSV"

echo "----------------------------------------------------"
echo "[INFO] Inicializando OVS en el OFS..."
echo "----------------------------------------------------"
sudo systemctl enable --now openvswitch-switch

# recrea bridge
if sudo ovs-vsctl br-exists "$BR"; then
  echo "[INFO] Eliminando bridge previo $BR..."
  sudo ovs-vsctl del-br "$BR"
  sleep 1
fi
sudo ovs-vsctl add-br "$BR"
sudo ip link set "$BR" up

for IFACE in "${PORTS[@]}"; do
  echo "[INFO] Configurando $IFACE trunk ($VLANS)..."
  sudo ip link set "$IFACE" up
  sudo ovs-vsctl --may-exist add-port "$BR" "$IFACE"
  sudo ovs-vsctl set Interface "$IFACE" type=system
  sudo ovs-vsctl set Port "$IFACE" trunks="$VLANS"
done

# modo bridge
sudo ovs-vsctl set-fail-mode "$BR" standalone
sudo ovs-ofctl del-flows "$BR" || true
sudo ovs-ofctl add-flow "$BR" "actions=NORMAL"

echo "----------------------------------------------------"
sudo ovs-vsctl show
echo "----------------------------------------------------"
echo "[OK] OFS listo: bridge=$BR, trunks=$VLANS, ports=${PORTS[*]}"
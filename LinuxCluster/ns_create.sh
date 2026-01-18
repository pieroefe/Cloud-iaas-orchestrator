#!/usr/bin/env bash
# ns_create.sh <namespace> <ovs_bridge> <vlan_id> <dhcp_range> <gateway>
# - NS corre dnsmasq
# - Conexión al OVS mediante veth (lado OVS con tag=VLAN)
set -euo pipefail

NS="$1"; OVS="$2"; VLAN="$3"; RANGE="$4"; GW="$5"
NSIF="${NS}-tap"   # dentro del NS
BRIF="${NS}-br"    # hacia OVS (tag VLAN)
LOGDIR="/var/log/ns_dhcp"
PIDFILE="/run/${NS}_dnsmasq.pid"

NS_IP="$(echo "$GW" | awk -F. '{print $1"."$2"."$3"."($4+1)}')"

echo "[INFO] Preparando NS $NS (VLAN=$VLAN, NSIF=$NSIF, BRIF=$BRIF, NS_IP=$NS_IP, GW=$GW)"

# limpiar y crear NS
ip netns list | grep -q -E "^${NS}\b" && { sudo ip netns pids "$NS" | xargs -r sudo kill || true; sudo ip netns del "$NS" || true; }
sudo ip netns add "$NS"

# borrar restos
ip link show "$NSIF" >/dev/null 2>&1 && sudo ip link del "$NSIF" || true
ip link show "$BRIF" >/dev/null 2>&1 && sudo ip link del "$BRIF" || true

# par veth
sudo ip link add "$NSIF" type veth peer name "$BRIF"

# lado OVS
sudo ip link set "$BRIF" up
sudo ovs-vsctl --may-exist add-port "$OVS" "$BRIF" tag="$VLAN"

# lado NS
sudo ip link set "$NSIF" netns "$NS"
sudo ip netns exec "$NS" ip link set lo up
sudo ip netns exec "$NS" ip link set "$NSIF" up
sudo ip netns exec "$NS" ip addr add "${NS_IP}/24" dev "$NSIF"

# dnsmasq
sudo mkdir -p "$LOGDIR"
sudo rm -f "$PIDFILE"
pgrep -f "${NS}_dnsmasq" >/dev/null 2>&1 && sudo pkill -f "${NS}_dnsmasq" || true

echo "[INFO] Iniciando dnsmasq en $NS..."
sudo ip netns exec "$NS" dnsmasq \
  --interface="$NSIF" \
  --bind-interfaces \
  --port=0 \
  --dhcp-range="$RANGE" \
  --dhcp-option=3,"$GW" \
  --dhcp-option=6,8.8.8.8 \
  --pid-file="$PIDFILE" \
  --log-facility="${LOGDIR}/${NS}.log"

echo "[OK] $NS activo: DHCP en VLAN ${VLAN} (GW=$GW)."
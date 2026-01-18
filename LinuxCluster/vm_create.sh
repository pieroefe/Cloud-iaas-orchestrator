#!/usr/bin/env bash
# Uso: vm_create.sh <VM_NAME> <VNC_NUM> <TAP_NAME> <VLAN_ID> [BRIDGE]
set -euo pipefail

VM_NAME="$1"; VNC_NUM="$2"; TAP_NAME="$3"; VLAN_ID="$4"; BRIDGE="${5:-br-int}"
IMAGE="/home/ubuntu/cirros-0.5.1-x86_64-disk.img"

echo "[INFO] Creando $VM_NAME (VLAN $VLAN_ID, VNC $VNC_NUM)..."
sudo mkdir -p /var/log/qemu

sudo ip tuntap add dev "$TAP_NAME" mode tap user ubuntu || true
sudo ip link set "$TAP_NAME" up
sudo ovs-vsctl --may-exist add-port "$BRIDGE" "$TAP_NAME" tag="$VLAN_ID"

MAC=$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

sudo qemu-system-x86_64 -enable-kvm -m 256 -smp 1 \
  -hda "$IMAGE" \
  -netdev tap,id="nd_${VM_NAME}",ifname="${TAP_NAME}",script=no,downscript=no \
  -device e1000,netdev="nd_${VM_NAME}",mac="${MAC}" \
  -vnc 0.0.0.0:"${VNC_NUM}" \
  -daemonize -snapshot \
  -D "/var/log/qemu/${VM_NAME}.log" \
  -pidfile "/var/log/qemu/${VM_NAME}.pid" \
  -name "${VM_NAME}"

echo "✅ VM '${VM_NAME}' lista:"
echo "   TAP=${TAP_NAME} (VLAN=${VLAN_ID}) en ${BRIDGE}"
echo "   MAC=${MAC}  |  VNC=:${VNC_NUM} (TCP $((5900 + VNC_NUM)))"
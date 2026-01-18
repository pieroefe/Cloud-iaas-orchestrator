#!/usr/bin/env bash
set -euo pipefail

# === Variables (ajusta si tu lab usa otro hostname/IP) ===
CONTROLLER_HOSTNAME="controller"
CONTROLLER_MGMT_IP="192.168.202.1"

echo "[08] Instalando etcd..."
apt update -y
apt install -y etcd

echo "[08] Configurando /etc/default/etcd ..."
# Backup
cp -a /etc/default/etcd /etc/default/etcd.bak.$(date +%F_%H%M%S) || true

cat > /etc/default/etcd <<EOF
ETCD_NAME="${CONTROLLER_HOSTNAME}"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER="${CONTROLLER_HOSTNAME}=http://${CONTROLLER_MGMT_IP}:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${CONTROLLER_MGMT_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://${CONTROLLER_MGMT_IP}:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://${CONTROLLER_MGMT_IP}_

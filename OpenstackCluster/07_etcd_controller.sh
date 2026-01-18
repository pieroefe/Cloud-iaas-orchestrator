#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller (Actividad 8) :contentReference[oaicite:12]{index=12}
apt install -y etcd

cat >> /etc/default/etcd << 'EOF'
ETCD_NAME="controller"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER="controller=http://192.168.202.1:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.202.1:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.202.1:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.202.1:2379"
EOF

systemctl enable etcd
systemctl restart etcd

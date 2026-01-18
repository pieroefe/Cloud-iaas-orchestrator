#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller (Actividad 3) :contentReference[oaicite:5]{index=5}
timedatectl set-timezone America/Lima
apt install -y chrony

sed -i '/^pool /s/^/# /' /etc/chrony/chrony.conf
cat >> /etc/chrony/chrony.conf << 'EOF'
server 0.south-america.pool.ntp.org iburst
server 1.south-america.pool.ntp.org iburst
server 2.south-america.pool.ntp.org iburst
server 3.south-america.pool.ntp.org iburst
allow 192.168.202.0/24
EOF

service chrony restart
chronyc sources || true

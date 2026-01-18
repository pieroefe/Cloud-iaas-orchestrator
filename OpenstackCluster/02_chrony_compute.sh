#!/usr/bin/env bash
set -euo pipefail

# Run on: Compute nodes (Actividad 3) :contentReference[oaicite:6]{index=6}
timedatectl set-timezone America/Lima
apt install -y chrony

sed -i '/^pool /s/^/# /' /etc/chrony/chrony.conf
echo 'server controller iburst' >> /etc/chrony/chrony.conf

service chrony restart
chronyc sources || true

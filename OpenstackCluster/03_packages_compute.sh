#!/usr/bin/env bash
set -euo pipefail

# Run on: Compute nodes (Actividad 4) :contentReference[oaicite:8]{index=8}
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
apt-get install -y crudini
add-apt-repository -y cloud-archive:victoria
apt-get update -y

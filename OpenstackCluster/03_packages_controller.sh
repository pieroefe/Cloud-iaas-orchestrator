#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller (Actividad 4) :contentReference[oaicite:7]{index=7}
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
apt install -y python3-openstackclient crudini
add-apt-repository -y cloud-archive:victoria
apt-get update -y

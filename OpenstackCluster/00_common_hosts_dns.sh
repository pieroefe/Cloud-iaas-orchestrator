#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller and all Compute nodes
# Adds hosts entries + Google DNS + apt update (Actividad 1) :contentReference[oaicite:2]{index=2}

echo -e '192.168.202.1\tcontroller' | tee -a /etc/hosts
echo -e '192.168.202.2\tcompute1'   | tee -a /etc/hosts
echo -e '192.168.202.3\tcompute2'   | tee -a /etc/hosts
echo -e '192.168.202.4\tcompute3'   | tee -a /etc/hosts

echo 'nameserver 8.8.8.8' | tee -a /etc/resolv.conf
apt-get update -y

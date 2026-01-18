#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller (Actividad 7) :contentReference[oaicite:11]{index=11}
apt install -y memcached python3-memcache
sed -i 's/127.0.0.1/192.168.202.1/g' /etc/memcached.conf
service memcached restart

#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller (Actividad 6) :contentReference[oaicite:10]{index=10}
apt install -y rabbitmq-server
. /root/service_passwords

rabbitmqctl add_user openstack "$RABBIT_PASS" || true
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

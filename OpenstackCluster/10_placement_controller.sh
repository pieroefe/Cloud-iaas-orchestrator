#!/usr/bin/env bash
set -euo pipefail

# HeadNode / Controller
. /root/service_passwords
. ~/env-scripts/admin-openrc

echo "[Placement] DB sync + Apache reload + checks"

# (Se asume que ya instalaste placement-api y creaste el usuario/servicio/endpoint en pasos previos)
# Esta parte es la clave de la guía:
su -s /bin/sh -c "placement-manage db sync" placement
service apache2 restart

# Verificación
placement-status upgrade check || true

# Opcional: plugin osc-placement + listados
apt-get update -y
apt-get install -y python3-pip
pip3 install osc-placement

openstack --os-placement-api-version 1.2 resource class list --sort-column name
openstack --os-placement-api-version 1.6 trait list --sort-column name

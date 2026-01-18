#!/usr/bin/env bash
set -euo pipefail

. ~/env-scripts/cloud-admin-openrc

echo "[CLI Activity] project lab5 + link_1 + subnet + ports"

openstack project create lab5 --domain Cloud

echo ">> Copia el project_id del output (o descomenta esto si quieres parsearlo):"
echo "project_id=<lab5_project_id>"

# Si ya tienes el ID (pega aquí):
: "${project_id:?Set project_id=... antes de ejecutar (export project_id=...)}"

openstack role add admin --project "$project_id" --user cloud_admin --user-domain Cloud

openstack network create link_1 --project "$project_id" --disable-port-security
echo ">> Copia el network_id del output:"
echo "network_id=<link1_network_id>"
: "${network_id:?Set network_id=... antes de ejecutar (export network_id=...)}"

openstack subnet create subnet_link_1 \
  --project "$project_id" \
  --network "$network_id" \
  --subnet-range 10.0.39.96/28 \
  --no-dhcp \
  --gateway none

openstack port create port_1_link_1 --project "$project_id" --network "$network_id" --disable-port-security
openstack port create port_2_link_1 --project "$project_id" --network "$network_id" --disable-port-security

echo "[Next] Crear instances usando tu template/.env/main.py (según el enunciado) y luego:"
echo "openstack server list --project lab5"
echo "openstack console url show <instance_1_id>"
echo "openstack console url show <instance_2_id>"

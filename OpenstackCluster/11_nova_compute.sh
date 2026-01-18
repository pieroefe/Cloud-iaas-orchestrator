#!/usr/bin/env bash
set -euo pipefail

MY_IP="${MY_IP:-192.168.202.2}"   # <-- cambia por worker (ej: .2 / .3 / .4)
. /root/service_passwords

echo "[Nova Compute] packages + nova.conf + restart"

echo 'nameserver 8.8.8.8' >> /etc/resolv.conf || true

apt-get update -y
apt-get install -y nova-compute crudini

crudini --set /etc/nova/nova.conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller"
crudini --set /etc/nova/nova.conf DEFAULT my_ip "$MY_IP"
crudini --set /etc/nova/nova.conf api auth_strategy "keystone"

crudini --set /etc/nova/nova.conf keystone_authtoken www_authenticate_uri "http://controller:5000/"
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url            "http://controller:5000/"
crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers   "controller:11211"
crudini --set /etc/nova/nova.conf keystone_authtoken auth_type           "password"
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name "default"
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name    "default"
crudini --set /etc/nova/nova.conf keystone_authtoken project_name        "service"
crudini --set /etc/nova/nova.conf keystone_authtoken username            "nova"
crudini --set /etc/nova/nova.conf keystone_authtoken password            "$NOVA_PASS"

# VNC (en la guía aparece novncproxy_base_url)
crudini --set /etc/nova/nova.conf vnc enabled "true"
crudini --set /etc/nova/nova.conf vnc server_listen "0.0.0.0"
crudini --set /etc/nova/nova.conf vnc server_proxyclient_address "$MY_IP"
crudini --set /etc/nova/nova.conf vnc novncproxy_base_url "http://controller:6080/vnc_auto.html"

# Placement
crudini --set /etc/nova/nova.conf placement auth_url            "http://controller:5000/v3"
crudini --set /etc/nova/nova.conf placement auth_type           "password"
crudini --set /etc/nova/nova.conf placement project_domain_name "default"
crudini --set /etc/nova/nova.conf placement user_domain_name    "default"
crudini --set /etc/nova/nova.conf placement project_name        "service"
crudini --set /etc/nova/nova.conf placement username            "placement"
crudini --set /etc/nova/nova.conf placement password            "$PLACEMENT_PASS"
crudini --set /etc/nova/nova.conf placement region_name         "RegionOne"

# Libvirt (por si tu entorno es nested; típico en labs)
crudini --set /etc/nova/nova.conf libvirt virt_type "qemu"

systemctl restart nova-compute
systemctl enable nova-compute

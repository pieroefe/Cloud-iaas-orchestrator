#!/usr/bin/env bash
set -euo pipefail

. /root/service_passwords
. ~/env-scripts/admin-openrc

echo "[Nova Controller] DBs + user/service/endpoints + packages + nova.conf baseline"

# DBs
mysql -e "CREATE DATABASE nova_api;"
mysql -e "CREATE DATABASE nova;"
mysql -e "CREATE DATABASE nova_cell0;"

mysql -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';"

# User + role
openstack user create --domain default --password "$NOVA_PASS" nova || true
openstack role add --project service --user nova admin || true

# Service + endpoints
openstack service create --name nova --description "OpenStack Compute" compute || true
openstack endpoint create --region RegionOne compute public   http://controller:8774/v2.1 || true
openstack endpoint create --region RegionOne compute internal http://controller:8774/v2.1 || true
openstack endpoint create --region RegionOne compute admin    http://controller:8774/v2.1 || true

# Packages
apt-get update -y
apt-get install -y nova-api nova-conductor nova-novncproxy nova-scheduler crudini

# nova.conf (base típica; en tu doc está “edite /etc/nova/nova.conf ...”)
crudini --set /etc/nova/nova.conf api_database connection "mysql+pymysql://nova:$NOVA_DBPASS@controller/nova_api"
crudini --set /etc/nova/nova.conf database connection     "mysql+pymysql://nova:$NOVA_DBPASS@controller/nova"
crudini --set /etc/nova/nova.conf DEFAULT transport_url   "rabbit://openstack:$RABBIT_PASS@controller"
crudini --set /etc/nova/nova.conf DEFAULT my_ip           "192.168.202.1"
crudini --set /etc/nova/nova.conf DEFAULT use_neutron     "true"
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver "nova.virt.firewall.NoopFirewallDriver"

# Keystone auth (nova)
crudini --set /etc/nova/nova.conf keystone_authtoken www_authenticate_uri "http://controller:5000/"
crudini --set /etc/nova/nova.conf keystone_authtoken auth_url            "http://controller:5000/"
crudini --set /etc/nova/nova.conf keystone_authtoken memcached_servers   "controller:11211"
crudini --set /etc/nova/nova.conf keystone_authtoken auth_type           "password"
crudini --set /etc/nova/nova.conf keystone_authtoken project_domain_name "default"
crudini --set /etc/nova/nova.conf keystone_authtoken user_domain_name    "default"
crudini --set /etc/nova/nova.conf keystone_authtoken project_name        "service"
crudini --set /etc/nova/nova.conf keystone_authtoken username            "nova"
crudini --set /etc/nova/nova.conf keystone_authtoken password            "$NOVA_PASS"

# Placement (nova -> placement)
crudini --set /etc/nova/nova.conf placement auth_url            "http://controller:5000/v3"
crudini --set /etc/nova/nova.conf placement auth_type           "password"
crudini --set /etc/nova/nova.conf placement project_domain_name "default"
crudini --set /etc/nova/nova.conf placement user_domain_name    "default"
crudini --set /etc/nova/nova.conf placement project_name        "service"
crudini --set /etc/nova/nova.conf placement username            "placement"
crudini --set /etc/nova/nova.conf placement password            "$PLACEMENT_PASS"
crudini --set /etc/nova/nova.conf placement region_name         "RegionOne"

# DB sync típico (no lo “fuerzo” si tu doc lo separa, pero ayuda)
su -s /bin/sh -c "nova-manage api_db sync" nova || true
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova || true
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name cell1 --verbose" nova || true
su -s /bin/sh -c "nova-manage db sync" nova || true

systemctl restart nova-api nova-scheduler nova-conductor nova-novncproxy
systemctl enable nova-api nova-scheduler nova-conductor nova-novncproxy

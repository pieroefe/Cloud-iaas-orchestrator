#!/usr/bin/env bash
set -euo pipefail

. /root/service_passwords
. ~/env-scripts/admin-openrc

echo "[Neutron Controller] DB + user/service/endpoints + packages + neutron.conf + ML2/OVS agents"

# DB
mysql -e "CREATE DATABASE neutron;"
mysql -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';"
mysql -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';"

# User/service/endpoints
openstack user create --domain default --password "$NEUTRON_PASS" neutron || true
openstack role add --project service --user neutron admin || true

openstack service create --name neutron --description "OpenStack Networking" network || true
openstack endpoint create --region RegionOne network public   http://controller:9696 || true
openstack endpoint create --region RegionOne network internal http://controller:9696 || true
openstack endpoint create --region RegionOne network admin    http://controller:9696 || true

# Packages
apt-get update -y
apt-get install -y neutron-server neutron-plugin-ml2 neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent neutron-openvswitch-agent crudini

# neutron.conf base
crudini --set /etc/neutron/neutron.conf database connection "mysql+pymysql://neutron:$NEUTRON_DBPASS@controller/neutron"
crudini --set /etc/neutron/neutron.conf DEFAULT transport_url "rabbit://openstack:$RABBIT_PASS@controller"
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips true
crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

# (keystone_authtoken: usual)
crudini --set /etc/neutron/neutron.conf keystone_authtoken www_authenticate_uri "http://controller:5000"
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_url "http://controller:5000"
crudini --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers "controller:11211"
crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_type "password"
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name "default"
crudini --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name "default"
crudini --set /etc/neutron/neutron.conf keystone_authtoken project_name "service"
crudini --set /etc/neutron/neutron.conf keystone_authtoken username "neutron"
crudini --set /etc/neutron/neutron.conf keystone_authtoken password "$NEUTRON_PASS"
crudini --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

# ML2/OVS bridges + mappings (según guía: br-provider / br-vlan + ens4)
ovs-vsctl add-br br-provider || true
ovs-vsctl add-br br-vlan || true
ovs-vsctl add-port br-vlan ens4 || true
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings "physnet0:br-provider,physnet1:br-vlan"

crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_security_group true
crudini --set /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver openvswitch

# Agents (según guía)
crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver openvswitch
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver openvswitch
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata true
crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_host controller
crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret "$METADATA_SECRET"

# Nova -> Neutron (la guía lo indica)
crudini --set /etc/nova/nova.conf neutron auth_url "http://controller:5000"
crudini --set /etc/nova/nova.conf neutron auth_type "password"
crudini --set /etc/nova/nova.conf neutron project_domain_name "default"
crudini --set /etc/nova/nova.conf neutron user_domain_name "default"
crudini --set /etc/nova/nova.conf neutron region_name "RegionOne"
crudini --set /etc/nova/nova.conf neutron project_name "service"
crudini --set /etc/nova/nova.conf neutron username "neutron"
crudini --set /etc/nova/nova.conf neutron password "$NEUTRON_PASS"

# Restart
systemctl restart nova-api neutron-server neutron-openvswitch-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent
systemctl enable neutron-server neutron-openvswitch-agent neutron-dhcp-agent neutron-metadata-agent neutron-l3-agent

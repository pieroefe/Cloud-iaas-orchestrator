#!/usr/bin/env bash
set -euo pipefail

if [[ -f /root/service_passwords ]]; then
  # shellcheck disable=SC1091
  . /root/service_passwords
else
  echo "ERROR: No existe /root/service_passwords"
  exit 1
fi

# Requiere GLANCE_DBPASS y GLANCE_PASS en /root/service_passwords
CONTROLLER_HOSTNAME="controller"
REGION="RegionOne"

# shellcheck disable=SC1091
. /root/env-scripts/admin-openrc

echo "[10] Creando DB glance..."
mysql -e "CREATE DATABASE IF NOT EXISTS glance;"
mysql -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '${GLANCE_DBPASS}';"
mysql -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '${GLANCE_DBPASS}';"
mysql -e "FLUSH PRIVILEGES;"

echo "[10] Creando usuario/servicio/endpoints en Keystone..."
openstack user create --domain default --password "${GLANCE_PASS}" glance || true
openstack role add --project service --user glance admin || true

openstack service create --name glance --description "OpenStack Image" image || true

openstack endpoint create --region "${REGION}" image public "http://${CONTROLLER_HOSTNAME}:9292" || true
openstack endpoint create --region "${REGION}" image internal "http://${CONTROLLER_HOSTNAME}:9292" || true
openstack endpoint create --region "${REGION}" image admin "http://${CONTROLLER_HOSTNAME}:9292" || true

echo "[10] Instalando Glance..."
apt update -y
apt install -y glance

echo "[10] Configurando /etc/glance/glance-api.conf ..."
cp -a /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak.$(date +%F_%H%M%S)

crudini --set /etc/glance/glance-api.conf database connection "mysql+pymysql://glance:${GLANCE_DBPASS}@${CONTROLLER_HOSTNAME}/glance"

crudini --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri "http://${CONTROLLER_HOSTNAME}:5000"
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url "http://${CONTROLLER_HOSTNAME}:5000"
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers "${CONTROLLER_HOSTNAME}:11211"
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password "${GLANCE_PASS}"

crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone

# File backend
crudini --set /etc/glance/glance-api.conf glance_store stores file,http
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/

echo "[10] Sincronizando DB glance..."
su -s /bin/sh -c "glance-manage db_sync" glance

echo "[10] Reiniciando servicio..."
systemctl restart glance-api
systemctl enable glance-api

echo "[10] Validando glance..."
openstack image list

echo "[10] (Opcional) Subir Cirros si ya tienes el .img:"
echo "  openstack image create \"cirros\" --file cirros-0.5.1-x86_64-disk.img --disk-format qcow2 --container-format bare --public"

echo "[10] OK."

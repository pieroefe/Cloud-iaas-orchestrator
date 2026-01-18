#!/usr/bin/env bash
set -euo pipefail

echo "[Horizon] install + local_settings tweaks + restart apache"

apt-get update -y
apt-get install -y openstack-dashboard crudini

# Edita /etc/openstack-dashboard/local_settings.py (forma simple con sed/append)
# Nota: en labs normalmente se cambia OPENSTACK_HOST a controller y ajustes de sesión/cache.
# Te lo dejo “seguro”: si no encuentra, agrega al final.

LS="/etc/openstack-dashboard/local_settings.py"

grep -q "OPENSTACK_HOST" "$LS" && sed -i "s/^OPENSTACK_HOST.*/OPENSTACK_HOST = \"controller\"/g" "$LS" || true

# Permitir hosts
grep -q "ALLOWED_HOSTS" "$LS" && sed -i "s/^ALLOWED_HOSTS.*/ALLOWED_HOSTS = ['*']/g" "$LS" || echo "ALLOWED_HOSTS = ['*']" >> "$LS"

# Session engine + caches memcached
grep -q "SESSION_ENGINE" "$LS" || echo "SESSION_ENGINE = 'django.contrib.sessions.backends.cache'" >> "$LS"

grep -q "MemcachedCache" "$LS" || cat >> "$LS" << 'EOF'

CACHES = {
  'default': {
    'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
    'LOCATION': 'controller:11211',
  }
}
EOF

systemctl reload apache2 || systemctl restart apache2

#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller (Actividad 5) :contentReference[oaicite:9]{index=9}
apt install -y mariadb-server python3-pymysql

cat > /etc/mysql/mariadb.conf.d/99-openstack.cnf << 'EOF'
[mysqld]
bind-address = 192.168.202.1
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF

service mysql restart

echo "Now run manually: mysql_secure_installation"
echo " - Set MariaDB root password"
echo " - Answer Y to recommended prompts"

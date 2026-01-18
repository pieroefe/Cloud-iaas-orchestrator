#!/usr/bin/env bash
set -euo pipefail

# Run on: Controller
# Generates /root/service_passwords and copies to compute nodes (Actividad 2) :contentReference[oaicite:3]{index=3}

OUT="/root/service_passwords"
: > "$OUT"

gen() { openssl rand -hex 16; }

echo "export ADMIN_PASS=$(gen)"            >> "$OUT"
echo "export CINDER_DBPASS=$(gen)"         >> "$OUT"
echo "export CINDER_PASS=$(gen)"           >> "$OUT"
echo "export DASH_DBPASS=$(gen)"           >> "$OUT"
echo "export DEMO_PASS=$(gen)"             >> "$OUT"
echo "export GLANCE_DBPASS=$(gen)"         >> "$OUT"
echo "export GLANCE_PASS=$(gen)"           >> "$OUT"
echo "export KEYSTONE_DBPASS=$(gen)"       >> "$OUT"
echo "export METADATA_SECRET=$(gen)"       >> "$OUT"
echo "export NEUTRON_DBPASS=$(gen)"        >> "$OUT"
echo "export NEUTRON_PASS=$(gen)"          >> "$OUT"
echo "export NOVA_DBPASS=$(gen)"           >> "$OUT"
echo "export NOVA_PASS=$(gen)"             >> "$OUT"
echo "export PLACEMENT_PASS=$(gen)"        >> "$OUT"
echo "export PLACEMENT_DBPASS=$(gen)"      >> "$OUT"
echo "export RABBIT_PASS=$(gen)"           >> "$OUT"

chmod 600 "$OUT"
echo "[OK] Created $OUT"

# Copy to computes (assumes ubuntu user reachable)
scp "$OUT" ubuntu@compute1:/home/ubuntu/service_passwords
scp "$OUT" ubuntu@compute2:/home/ubuntu/service_passwords
scp "$OUT" ubuntu@compute3:/home/ubuntu/service_passwords
echo "[OK] Copied service_passwords to compute nodes."

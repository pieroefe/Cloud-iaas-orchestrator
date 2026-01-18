#!/usr/bin/env bash
# Fase 1: Workers + VMs
set -euo pipefail

W2="10.0.10.2"; W3="10.0.10.3"; W4="10.0.10.4"
BR="br-int"; UPLINK="ens4"; VLANS="100,200,30"

echo "[INFO] Inicializando OVS en cada Worker..."
for W in "$W2" "$W3" "$W4"; do
  ssh -o StrictHostKeyChecking=no "ubuntu@${W}" "sudo /home/ubuntu/init_worker.sh '${BR}' '${UPLINK}' '${VLANS}'"
done

echo "[INFO] Creando VMs..."
ssh ubuntu@"$W2" "sudo /home/ubuntu/vm_create.sh vm2v100 1 vm2v100-tap100 100 '$BR'"
ssh ubuntu@"$W2" "sudo /home/ubuntu/vm_create.sh vm2v200 2 vm2v200-tap200 200 '$BR'"
ssh ubuntu@"$W2" "sudo /home/ubuntu/vm_create.sh vm2v30  3 vm2v30-tap30   30  '$BR'"

ssh ubuntu@"$W3" "sudo /home/ubuntu/vm_create.sh vm3v100 4 vm3v100-tap100 100 '$BR'"
ssh ubuntu@"$W3" "sudo /home/ubuntu/vm_create.sh vm3v200 5 vm3v200-tap200 200 '$BR'"
ssh ubuntu@"$W3" "sudo /home/ubuntu/vm_create.sh vm3v30  6 vm3v30-tap30   30  '$BR'"

ssh ubuntu@"$W4" "sudo /home/ubuntu/vm_create.sh vm4v100 7 vm4v100-tap100 100 '$BR'"
ssh ubuntu@"$W4" "sudo /home/ubuntu/vm_create.sh vm4v200 8 vm4v200-tap200 200 '$BR'"
ssh ubuntu@"$W4" "sudo /home/ubuntu/vm_create.sh vm4v30  9 vm4v30-tap30   30  '$BR'"

echo "[OK] Fase 1 desplegada."
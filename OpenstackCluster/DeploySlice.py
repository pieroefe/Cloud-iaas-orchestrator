#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import sys
import subprocess
import math
import requests
from datetime import datetime

from openstack_sf import (
    get_admin_token, get_token_for_project,
    create_os_project, assign_admin_role_over_os_project,
    create_os_network, create_os_subnet, create_os_port,
    create_os_instance
)

# ==============================
# CONFIGURACION
# ==============================

IMAGE_UBUNTU_ID = "e24bf0f1-2f96-4904-914b-9c9a8f3580d3"
IMAGE_CIRROS_ID = "a5549399-e5c4-4644-aeef-058c44897f65"
IMAGE_UBUNTU24_ID = "18da364b-66bb-41ea-a3dc-7ad9e6fe7cff"
IMAGE_UBUNTU20_ID = "3005b701-3107-4774-b367-209696028a6c"


def log(msg: str):
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{now}] {msg}")


# ============================================================
#   FUNCIONES DE CLEANUP (ROLLBACK)
# ============================================================

def run_cmd(cmd: str):
    """Ejecuta un comando shell de forma segura."""
    try:
        subprocess.run(
            cmd,
            shell=True,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
    except Exception as e:
        print(f"[WARN] Error ejecutando cleanup cmd: {cmd} -> {e}")


def cleanup(project_id=None, networks=None, subnets=None, ports=None,
            instances=None, flavors=None, router_id=None):

    log("=== CLEANUP AUTOMATICO DEL SLICE ===")

    # 1. Borrar instancias
    if instances:
        log("Borrando instancias...")
        for inst in instances:
            run_cmd(f"openstack server delete {inst}")

    # 2. Borrar puertos
    if ports:
        log("Borrando puertos...")
        for p in ports:
            run_cmd(f"openstack port delete {p}")

    # 3. Borrar router (gateway + interfaces)
    if router_id:
        log("Borrando router del slice...")

        # quitar gateway externo
        run_cmd(
            f"openstack router unset --external-gateway {router_id}"
        )

        # quitar interfaces por subred
        for subnet in subnets or []:
            run_cmd(
                f"openstack router remove subnet {router_id} {subnet}"
            )

        # borrar router
        run_cmd(f"openstack router delete {router_id}")

    # 4. Borrar subnets
    if subnets:
        log("Borrando subnets...")
        for subnet in subnets:
            run_cmd(f"openstack subnet delete {subnet}")

    # 5. Borrar networks
    if networks:
        log("Borrando redes...")
        for net in networks:
            run_cmd(f"openstack network delete {net}")

    # 6. Borrar flavors
    if flavors:
        log("Borrando flavors...")
        for fl in flavors:
            run_cmd(f"openstack flavor delete {fl}")

    # 7. Borrar proyecto
    if project_id:
        log(f"Borrando proyecto {project_id}...")
        run_cmd(f"openstack project delete {project_id}")

    log("=== CLEANUP FINALIZADO ===")

    
    
# ============================================================
#   NOOMBRE EN AUTOMATICO
# ============================================================    
def generate_slice_name():
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"slice_{ts}"

# ============================================================
#   FUNCIONES PARA LOS FLAVORS
# ============================================================

def get_or_create_flavor(vm_name, ram_gb, vcpu, disk_gb):
    """
    Crea un flavor si no existe, utilizando los recursos del JSON.
    Retorna el flavor_id.
    """
    flavor_name = f"flavor_{vm_name}"

    # Convertir valores
    ram_mb = int(ram_gb * 1024)
    disk_gb = math.ceil(float(disk_gb))
    vcpu = int(vcpu)

    # 1. Revisar si ya existe
    cmd_check = f"openstack flavor list -f value -c Name | grep -w {flavor_name}"
    exists = subprocess.call(cmd_check, shell=True) == 0

    if exists:
        print(f"[INFO] Flavor {flavor_name} ya existe, usando el existente.")
    else:
        print(
            f"[INFO] Creando flavor {flavor_name}: "
            f"RAM={ram_mb}MB, VCPUs={vcpu}, Disk={disk_gb}GB"
        )

        cmd_create = (
            f"openstack flavor create {flavor_name} "
            f"--ram {ram_mb} --vcpus {vcpu} --disk {disk_gb}"
        )
        result = subprocess.call(cmd_create, shell=True)

        if result != 0:
            raise RuntimeError(f"Error creando flavor {flavor_name}")

    # Obtener ID del flavor
    cmd_get_id = "openstack flavor show {name} -f value -c id".format(
        name=flavor_name
    )
    flavor_id = subprocess.check_output(cmd_get_id, shell=True).decode().strip()

    return flavor_id


import requests  # aseg�rate de tener esto arriba del archivo


# ============================================================
#   FUNCIONES PARA ROUTER Y PUBLIC ACCESS
# ============================================================

NEUTRON_URL = "http://controller:9696/v2.0"
EXTERNAL_NET_NAME = "external"   # cambia el nombre si tu red externa se llama distinto


def get_external_network_id(token, external_net_name=EXTERNAL_NET_NAME):
    """
    Devuelve el ID de la red externa (provider) a partir de su nombre.
    Usa el token (normalmente admin_token).
    """
    url = f"{NEUTRON_URL}/networks?name={external_net_name}"
    headers = {"X-Auth-Token": token}
    r = requests.get(url, headers=headers)
    if r.status_code != 200:
        raise Exception(f"No se pudo consultar la red externa: {r.status_code} {r.text}")

    nets = r.json().get("networks", [])
    if not nets:
        raise Exception(f"No se encontro la red externa '{external_net_name}'")
    return nets[0]["id"]


def create_router(project_id, token, router_name):
    """
    Crea un router Neutron en el proyecto dado.
    """
    url = f"{NEUTRON_URL}/routers"
    headers = {
        "X-Auth-Token": token,
        "Content-Type": "application/json",
    }
    payload = {
        "router": {
            "name": router_name,
            "admin_state_up": True,
            "project_id": project_id,
        }
    }

    r = requests.post(url, json=payload, headers=headers)
    if r.status_code not in (200, 201):
        # asumo que tienes una funci�n log() definida
        log(f"[ERROR] No se pudo crear el router: {r.status_code} {r.text}")
        raise Exception("Failed to create router")

    router = r.json()["router"]
    log(f"  - Router creado: {router['id']}")
    return router["id"]


def set_router_gateway(router_id, token, external_network_id):
    """
    Configura el gateway externo del router hacia la red provider.
    """
    url = f"{NEUTRON_URL}/routers/{router_id}"
    headers = {
        "X-Auth-Token": token,
        "Content-Type": "application/json",
    }
    payload = {
        "router": {
            "external_gateway_info": {
                "network_id": external_network_id
            }
        }
    }

    r = requests.put(url, json=payload, headers=headers)
    if r.status_code not in (200, 202):
        log(f"[ERROR] No se pudo configurar el gateway externo: {r.status_code} {r.text}")
        raise Exception("Failed to set router gateway")
    log("  - Gateway externo configurado correctamente")


def add_router_interface(router_id, token, subnet_id):
    """
    Anade una interfaz del router hacia una subred (interface en la red interna).
    """
    url = f"{NEUTRON_URL}/routers/{router_id}/add_router_interface"
    headers = {
        "X-Auth-Token": token,
        "Content-Type": "application/json",
    }
    payload = {
        "subnet_id": subnet_id
    }

    r = requests.put(url, json=payload, headers=headers)
    if r.status_code not in (200, 201, 202):
        log(f"[ERROR] No se pudo anadir interfaz al router (subnet {subnet_id}): {r.status_code} {r.text}")
        raise Exception(f"Failed to add router interface for subnet {subnet_id}")

    log(f"  - Interfaz anadida al router para subnet {subnet_id}")



# ============================================================
#   LOGICA PRINCIPAL DEL DESPLIEGUE
# ============================================================

def cidr_for_edge(edge_index: int) -> str:
    base_host = edge_index * 16
    return f"10.0.0.{base_host}/28"

def deploy_slice_from_dict(slice_name: str, topo: dict) -> dict:
    nodes = topo["topologia"]["nodes"]
    edges = topo["topologia"]["edges"]
    recursos = topo["recursos"]
    public_access = topo.get("subred", {}).get("public_access", [])

    # Objetos potenciales a limpiar si algo falla
    created_project = None
    created_networks = []
    created_ports = []
    created_instances = []

    try:
        # ==========================================================
        # 1. TOKEN ADMIN
        # ==========================================================
        log("Obteniendo token admin")
        admin_token = get_admin_token()
        if not admin_token:
            raise RuntimeError("No se pudo obtener token admin")

        # ==========================================================
        # 2. Crear proyecto con nombre autom�tico
        # ==========================================================
        project_name = generate_slice_name()
        log(f"Nombre automatico del slice: {project_name}")

        project_id = create_os_project(admin_token, project_name)
        if not project_id:
            raise RuntimeError("No se pudo crear el proyecto del slice")
        created_project = project_id

        # 3: Asignar rol admin
        status = assign_admin_role_over_os_project(admin_token, project_id)
        if not status:
            raise RuntimeError("No se pudo asignar rol admin sobre el proyecto")

        # 4. Token scoped
        project_token = get_token_for_project(project_id, admin_token)
        if not project_token:
            raise RuntimeError("No se pudo obtener token scoped para el proyecto del slice")

        # ==========================================================
        # 5. Redes y Subredes
        # ==========================================================
        log("Creando redes y subredes")
        network_map = {}
        subnets = {}

        for idx, edge in enumerate(edges):
            edge_id = edge["id"]
            net_name = f"net_{edge_id}"
            subnet_name = f"subnet_{edge_id}"
            cidr = cidr_for_edge(idx)

            net_id = create_os_network(project_token, net_name)
            if not net_id:
                raise RuntimeError(f"No se pudo crear red para edge {edge_id}")
            created_networks.append(net_id)

            subnet_id = create_os_subnet(project_token, subnet_name, net_id, cidr)
            if not subnet_id:
                raise RuntimeError(f"No se pudo crear subnet para edge {edge_id}")

            network_map[edge_id] = net_id
            subnets[edge_id] = subnet_id

        # ==========================================================
        # 6. Puertos
        # ==========================================================
        log("Creando puertos")
        port_map = {vm["id"]: [] for vm in nodes}

        for edge in edges:
            net_id = network_map[edge["id"]]
            for side in ("from", "to"):
                vm_id = edge[side]
                port_name = f"port_{vm_id}_{edge['id']}"

                port_id = create_os_port(project_token, port_name, net_id, project_id)
                created_ports.append(port_id)
                port_map[vm_id].append(port_id)

        # ==========================================================
        # 7. Router y salida p�blica
        # ==========================================================
        if public_access:
            log("Creando router para acceso publico")
            router_name = f"router_{project_name}"
            router_id = create_router(project_id, project_token, router_name)

            external_id = get_external_network_id(admin_token)
            set_router_gateway(router_id, project_token, external_id)

            vm_to_subnet = {}
            for edge in edges:
                vm_to_subnet.setdefault(edge["from"], set()).add(subnets[edge["id"]])
                vm_to_subnet.setdefault(edge["to"], set()).add(subnets[edge["id"]])
                
            added_subnets = set()

            for vm in public_access:
              for subnet in vm_to_subnet.get(vm, []):
                  if subnet not in added_subnets:
                      add_router_interface(router_id, project_token, subnet)
                      added_subnets.add(subnet)
                  else:
                      log(f"  - Subnet {subnet} ya fue agregada, se omite.")

        # ==========================================================
        # 8. Crear Instancias (AQU� VA EL PLACEMENT)
        # ==========================================================
        log("Creando instancias con Worker Placement")
        instance_ids = {}

        for vm in nodes:
            vm_id = vm["id"]
            rec = recursos[vm_id]

            name = rec["name"]
            os_type = rec["os"].lower()
            worker = rec.get("worker")  # <- requerido

            if os_type == "ubuntu":
                image_id = IMAGE_UBUNTU_ID
            elif os_type == "cirros":
                image_id = IMAGE_CIRROS_ID
            elif os_type == "ubuntu24":
                image_id = IMAGE_UBUNTU24_ID
            elif os_type == "ubuntu20":
                image_id = IMAGE_UBUNTU20_ID       
            else:
                raise RuntimeError(f"OS no soportado: {os_type}")

            ports = port_map[vm_id]

            # Flavor din�mico
            flavor_id = get_or_create_flavor(
                vm_name=name,
                ram_gb=rec["ram_gb"],
                vcpu=rec["vcpu"],
                disk_gb=rec["disk_gb"]
            )

            # ==========================================================
            # PLACEMENT: elegir worker correcto
            # ==========================================================
            az = f"az-{worker}"              # availability zone
            hints = {"force_hosts": [worker]}  # scheduler hints

            log(f"  - VM {name} ira al worker: {worker}  (AZ={az})")

            info = create_os_instance(
                image_id,
                flavor_id,
                name,
                ports,
                project_token,
                availability_zone=az,
                scheduler_hints=hints
            )

            if not info or "server" not in info:
                raise RuntimeError(f"Error al crear instancia para {vm_id}")

            real_id = info["server"]["id"]
            created_instances.append(real_id)
            instance_ids[vm_id] = real_id

        log("Slice desplegado exitosamente")

        return {
            "project_id": project_id,
            "instances": instance_ids,
            "public_access": public_access,
        }
    
    except Exception as e:
        log(f"[ERROR] {e}")
        cleanup(
            project_id=created_project,
            networks=created_networks,
            ports=created_ports,
            instances=created_instances
        )
        raise





# ============================================================
#   MAIN
# ============================================================

def main():
    if len(sys.argv) != 3:
        print("Uso: python3 deploy_slice.py <nombre_slice> <ruta_json>")
        sys.exit(1)

    slice_name = sys.argv[1]
    json_path = sys.argv[2]

    with open(json_path) as f:
        topo = json.load(f)

    result = deploy_slice_from_dict(slice_name, topo)
    log(f"Resultado final: {result}")


if __name__ == "__main__":
    main()

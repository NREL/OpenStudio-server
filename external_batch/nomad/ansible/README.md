# Nomad External Batch — Ansible Provisioning

Ansible playbooks and roles to provision a Nomad cluster (server + N clients) for executing OpenStudio Server external batch simulations.

## Quick Start

```bash
# 0. (Optional) Create OpenStack VMs and auto-generate inventory
./create_cluster.py                        # interactive
./create_cluster.py --clients 4 --yes       # non-interactive

# 1. Install Ansible (one-time)
pip3 install ansible

# 2. Create your inventory
cp inventory.yml.example inventory.yml
# Edit inventory.yml with your VM IPs and local tarball paths
# OR use the script above to auto-generate it

# 3. Validate before applying
make test                    # syntax check + inventory validation
make check INVENTORY=inventory.yml   # dry-run against live VMs (safe)

# 4. Provision the full cluster
make deploy
```

## Targets

| Command | What it does |
|---|---|
| `make syntax` | Validates YAML syntax of all playbooks and roles |
| `make check` | Ansible dry-run (`--check --diff`) against inventory — reports changes without making any |
| `make validate` | Checks `inventory.yml.example` is parseable |
| `make test` | `syntax` + `validate` — fastest feedback loop |
| `make deploy` | Full provisioning: server then all clients |
| `make deploy-server` | Provision just the Nomad server |
| `make deploy-clients` | Provision all Nomad clients in parallel |
| `make deploy-client HOST=nomad-client-3` | Provision a single client |

## Structure

```
ansible/
├── Makefile                  # Test and deploy targets
├── ansible.cfg               # Default settings (host_key_checking=False, user=ubuntu)
├── create_cluster.py         # OpenStack VM provisioning + auto-inventory
├── inventory.yml.example     # Template — copy to inventory.yml
├── playbooks/
│   ├── site.yml              # Master: runs server then clients
│   ├── nomad-server.yml      # Server provisioning
│   └── nomad-clients.yml     # Client provisioning (serial=10 parallel)
└── roles/
    ├── common/               # hostname, /etc/hosts, packages
    ├── nfs/
    │   ├── server/           # nfs-kernel-server + exports + handlers
    │   └── client/           # nfs-common + fstab mount
    ├── nomad/
    │   ├── install/          # binary + systemd service + handlers
    │   ├── server/           # server.hcl config + readiness check
    │   └── client/           # client.hcl config pointing at nomad-server:4646
    └── openstudio/           # tarball extract + CLI symlink + runner scripts
```

## Testing

```bash
# Fast — syntax only (no inventory needed)
make syntax

# Medium — syntax + inventory validation
make test

# Full — dry-run against real VMs (requires inventory.yml with live hosts)
make check

# WARNING: Use --check only. This does NOT provision. It shows what would
# change. To actually provision, run:
make deploy
```

## Variables

Set these in `inventory.yml` under `all.vars`:

| Variable | Example | Description |
|---|---|---|
| `vpc_cidr` | `10.0.0.0/16` | Internal subnet CIDR for NFS export rule |
| `nomad_server_internal_ip` | `10.0.0.10` | Internal IP of nomad-server |
| `nomad_client_internal_ips` | `{nomad-client-1: 10.0.0.11, ...}` | Map of client names → internal IPs |
| `nomad_version` | `1.5.3` | Nomad release version |
| `local_nomad_zip` | `/tmp/nomad_1.5.3_linux_amd64.zip` | Local path to Nomad zip |
| `openstudio_version` | `3.10.0` | OpenStudio version |
| `local_openstudio_tarball` | `/tmp/OpenStudio-3.10.0-xxx.tar.gz` | Local path to OpenStudio tarball |
| `nfs_export_path` | `/nfs/opensstudio/batch` | NFS export directory |

## OpenStack VM Setup

The `create_cluster.py` script automates the full VM lifecycle:

1. **Discovers** your OpenStack environment (quota, images, flavors, existing networks, keypairs)
2. **Calculates** sizing using your quota as upper bound (recommends 5–10% buffer)
3. **Creates** or reuses networks, subnets, routers, security groups
4. **Provisions** `nomad-server` + `nomad-client-1..N` VMs
5. **Allocates and assigns** floating IPs
6. **Generates** `inventory.yml` with all IPs and internal addressing

### Requirements

- OpenStack CLI installed and authenticated (`OS_*` env vars or `clouds.yaml`)
- `openstacksdk` Python package (`pip install openstacksdk`)
- An existing SSH keypair in OpenStack

### Interactive usage

```bash
cd ansible/
./create_cluster.py
```

The script walks you through each choice:

```
▸ Discovering OpenStack environment...

  Quota                          Used       Free       Limit
  ────────────────────────────────────────────────────────────
  Cores                          42         14958      15000
  RAM (MB)                       172032     26513536   26486400
  Floating IPs                   4          996        1000
  Instances                      8          ?          -1

▸ Available images (Ubuntu 22.04 recommended):
    1) ubuntu-jammy-20260320
    2) ubuntu-jammy-20250508
    ...

▸ Available flavors (compute, sorted by vCPU):
  Name                  vCPUs    RAM          Disk
  ──────────────────────────────────────────────────
  CM.Micro              1        2048MB       0GB
  CM.Mini               2        4096MB       0GB
  CM.Tiny               4        8192MB       0GB
  ...

Nomad server flavor (needs enough RAM for Nomad + NFS):
  Enter choice [CM.Small]:
```

### Non-interactive usage

```bash
# Create 4 clients with specific image, flavors, and keypair
./create_cluster.py \
    --clients 4 \
    --image ubuntu-jammy-20260320 \
    --flavor-server CM.Small \
    --flavor-client CM.Tiny \
    --key-name achapin \
    --yes
```

### What the script auto-generates

After creating VMs, `inventory.yml` is populated with:

```yaml
all:
  children:
    nomad_server:
      hosts:
        nomad-server:
          ansible_host: 10.60.124.42    # floating IP
    nomad_clients:
      hosts:
        nomad-client-1:
          ansible_host: 10.60.124.43
        nomad-client-2:
          ansible_host: 10.60.124.44
  vars:
    vpc_cidr: "192.168.100.0/24"
    nomad_server_internal_ip: "192.168.100.3"
    nomad_client_internal_ips:
      nomad-client-1: "192.168.100.8"
      nomad-client-2: "192.168.100.12"
    nomad_version: "1.5.3"
    # ... plus NFS, OpenStudio, Nomad binary paths
```

After generation, you still need to set `local_nomad_zip` and
`local_openstudio_tarball` to local file paths (DNS is typically blocked
on OpenStack instances, so Ansible copies these binaries from your Mac).

### Manual OpenStack CLI (for reference)

If you prefer to create VMs by hand or need to debug:

```bash
# 1. Check your quota
openstack quota show

# 2. List images and flavors
openstack image list
openstack flavor list

# 3. Create network + subnet (if not already present)
openstack network create nomad-net
openstack subnet create nomad-subnet \
    --network nomad-net \
    --subnet-range 192.168.100.0/24

# 4. Create a router for external access
openstack router create nomad-router
openstack router set nomad-router --external-gateway external
openstack router add subnet nomad-router nomad-subnet

# 5. Create security group
openstack security group create nomad-sg
openstack security group rule create --proto tcp --dst-port 22 nomad-sg
openstack security group rule create --proto tcp --dst-port 4646 nomad-sg
openstack security group rule create --proto tcp --dst-port 2049 nomad-sg
openstack security group rule create --proto udp --dst-port 2049 nomad-sg

# 6. Create VMs
openstack server create \
    --image ubuntu-jammy-20260320 \
    --flavor CM.Small \
    --network nomad-net \
    --key-name achapin \
    --security-group nomad-sg \
    --wait \
    nomad-server

openstack server create \
    --image ubuntu-jammy-20260320 \
    --flavor CM.Tiny \
    --network nomad-net \
    --key-name achapin \
    --security-group nomad-sg \
    --wait \
    nomad-client-1

# 7. Allocate and assign floating IPs
openstack floating ip create external
openstack server add floating ip nomad-server <FLOATING_IP>
```

## Requirements

- **Ansible** 2.15+ (`pip3 install ansible`)
- **Python** 3.9+ on the controller
- **SSH key** loaded into `ssh-agent` or passed via `--private-key`
- **Existing OpenStack VMs** with Ubuntu 22.04 and floating IPs reachable from the controller
- **Pre-downloaded binaries** (Nomad zip + OpenStudio tarball) on the controller — DNS is typically blocked on OpenStack instances

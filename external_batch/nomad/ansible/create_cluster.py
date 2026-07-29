#!/usr/bin/env python3
"""
create_cluster.py — Provision OpenStack VMs for a Nomad batch cluster.

Discovers your OpenStack environment (quota, images, flavors, networks),
creates a nomad-server + N nomad-client VMs, assigns floating IPs, and
auto-generates inventory.yml ready for `make deploy`.

Once a cluster exists, running the script again automatically detects the
existing cluster and enters "additive mode": it discovers which image and
flavor the existing clients use, skips server creation, numbers new clients
after the existing ones, and merges the new clients into inventory.yml.

Creating many VMs is bottlenecked by volume-creation time (~30-60s per VM
in this OpenStack environment).  This script pipelines the work: it fires
off all server creations in parallel, then batch-waits for ACTIVE status,
then resolves IPs and floating IPs in parallel.  With --parallel 20 and
384 clients, the serial ~6.5 hours drops to ~8 minutes.

Usage:
    # Greenfield — create a brand-new cluster (prompts for choices):
    ./create_cluster.py

    # Greenfield — fully automated with CLI flags:
    ./create_cluster.py --clients 8 \\
        --image nomad-client-base-20260705 \\
        --flavor-server CM.Small \\
        --flavor-client CM.Medium \\
        --key-name achapin \\
        --network nomad-net \\
        --security-group nomad-sg

    # Greenfield — fill quota with maximum clients:
    ./create_cluster.py --max \\
        --image nomad-client-base-20260705 \\
        --flavor-client CM.Medium \\
        --key-name achapin --yes

    # Additive — add more clients to an existing cluster (auto-detects):
    ./create_cluster.py --clients 4 --yes

    # Additive — fill remaining quota with new clients:
    ./create_cluster.py --max --yes

Prerequisites:
    - openstack CLI installed and authenticated (OS_* env vars or clouds.yaml)
    - openstacksdk Python package (pip install openstacksdk)
    - Existing SSH keypair in OpenStack (use --key-name to specify)
"""

import argparse
import concurrent.futures
import ipaddress
import os
import subprocess
import sys
import time
import yaml


# ── Helpers ──────────────────────────────────────────────────────────────


def run(cmd: list[str], quiet: bool = False, **kwargs) -> subprocess.CompletedProcess:
    """Run a command, print it, return the result. Exits on failure."""
    if not quiet:
        print(f"  + {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        print(f"  FAILED (exit {result.returncode}): {result.stderr.strip()}")
        sys.exit(1)
    return result


def openstack(*args: str, quiet: bool = False) -> str:
    """Run an openstack CLI command and return stdout."""
    return run(["openstack", *args], quiet=quiet).stdout.strip()


def bold(s: str) -> str:
    return f"\033[1m{s}\033[0m"


def dim(s: str) -> str:
    return f"\033[2m{s}\033[0m"


def green(s: str) -> str:
    return f"\033[92m{s}\033[0m"


def yellow(s: str) -> str:
    return f"\033[93m{s}\033[0m"


def prompt(label: str, default: str = "", options: list[str] | None = None) -> str:
    """Prompt the user with a label and optional default."""
    if options:
        print(f"  {bold(label)}")
        for i, opt in enumerate(options, 1):
            marker = green("▸") if opt == default else " "
            print(f"    {marker} {i}) {opt}")
        hint = f" [{default}]" if default else ""
        raw = input(f"  Enter choice{hint}: ").strip()
        if not raw and default:
            return default
        try:
            idx = int(raw) - 1
            if 0 <= idx < len(options):
                return options[idx]
        except ValueError:
            pass
        if raw in options:
            return raw
        print(f"  Invalid choice, using default: {default}")
        return default
    hint = f" [{default}]" if default else ""
    raw = input(f"  {label}{hint}: ").strip()
    return raw if raw else default


# ── Discovery functions ──────────────────────────────────────────────────


def discover_images() -> list[dict]:
    """Return list of active images with name, id."""
    raw = openstack("image", "list", "-f", "yaml")
    images = yaml.safe_load(raw) or []
    return [
        {"name": i["Name"], "id": i["ID"]}
        for i in images
        if i.get("Status") == "active"
    ]


def discover_flavors() -> list[dict]:
    """Return list of flavors with name, vcpus, ram_mb, disk_gb."""
    raw = openstack("flavor", "list", "-f", "yaml")
    flavors = yaml.safe_load(raw) or []
    result = []
    for f in flavors:
        result.append(
            {
                "name": f["Name"],
                "vcpus": f["VCPUs"],
                "ram_mb": f["RAM"],
                "disk_gb": f["Disk"],
            }
        )
    return result


def discover_networks() -> list[dict]:
    """Return list of networks with name, id."""
    raw = openstack("network", "list", "-f", "yaml")
    nets = yaml.safe_load(raw) or []
    return [{"name": n["Name"], "id": n["ID"]} for n in nets]


def discover_subnets() -> list[dict]:
    """Return list of subnets with name, network_name, cidr."""
    raw = openstack("subnet", "list", "-f", "yaml")
    subnets = yaml.safe_load(raw) or []
    result = []
    for s in subnets:
        result.append(
            {
                "name": s.get("Name", ""),
                "network_name": s.get("Network", ""),
                "cidr": s.get("Subnet", ""),
            }
        )
    return result


def discover_security_groups() -> list[dict]:
    """Return list of security groups with name, id."""
    raw = openstack("security", "group", "list", "-f", "yaml")
    sgs = yaml.safe_load(raw) or []
    return [{"name": sg["Name"], "id": sg["ID"]} for sg in sgs]


def discover_keypairs() -> list[str]:
    """Return list of keypair names."""
    raw = openstack("keypair", "list", "-f", "yaml")
    kps = yaml.safe_load(raw) or []
    return [kp["Name"] for kp in kps]


def _parse_quota_list(data: list[dict]) -> dict:
    """Convert OpenStack's list-of-resources YAML into a flat dict.

    openstack quota show -f yaml returns:
        - Limit: 15000
          Resource: cores
        - Limit: -1
          Resource: instances
        ...

    openstack quota show --usage -f yaml returns:
        - In Use: 7790
          Limit: 15000
          Resource: cores
        ...
    """
    result = {}
    for entry in data:
        resource = entry.get("Resource", "")
        if resource:
            result[resource] = entry.get("Limit")
            # Capture "In Use" if present (for --usage variant)
            if "In Use" in entry:
                result[f"{resource}_in_use"] = entry["In Use"]
    return result


def discover_quota() -> dict:
    """Return quota limits and current usage."""
    raw = openstack("quota", "show", "-f", "yaml")
    quota_list = yaml.safe_load(raw) or []
    # Convert list-of-resources to flat dict
    limits = _parse_quota_list(quota_list) if isinstance(quota_list, list) else {}
    limits.pop("project_id", None)

    # Get current usage
    usage_raw = openstack("quota", "show", "--usage", "-f", "yaml")
    usage_data = yaml.safe_load(usage_raw) or []
    usage = _parse_quota_list(usage_data) if isinstance(usage_data, list) else {}

    used = {}
    for key in ("cores", "ram", "instances", "floating-ips"):
        in_use = usage.get(f"{key}_in_use", 0)
        if in_use is not None:
            used[key] = in_use
    return {"limits": limits, "used": used}


def discover_availability_zones() -> list[str]:
    """Return list of available zone names."""
    raw = openstack("availability", "zone", "list", "-f", "yaml")
    zones = yaml.safe_load(raw) or []
    return sorted(
        set(
            z["Zone Name"]
            for z in zones
            if z.get("Zone Status", "").lower() == "available"
        )
    )


def discover_existing_cluster(prefix: str) -> dict:
    """Discover existing nomad server and clients by name pattern.

    Returns:
        {
            "server": {"name": str, "id": str} or None,
            "clients": [{"name": str, "id": str, "index": int}],
            "max_client_index": int,  # 0 if no clients found
        }
    """
    raw = openstack("server", "list", "--name", f"{prefix}-", "-f", "yaml")
    servers = yaml.safe_load(raw) or []

    result: dict = {"server": None, "clients": [], "max_client_index": 0}

    for s in servers:
        name = s.get("Name", "")
        sid = s.get("ID", "")
        status = s.get("Status", "")
        if status.upper() not in ("ACTIVE",):
            continue
        if name == f"{prefix}-server":
            result["server"] = {"name": name, "id": sid}
        elif name.startswith(f"{prefix}-client-"):
            try:
                idx = int(name.split("-")[-1])
                result["clients"].append({"name": name, "id": sid, "index": idx})
                if idx > result["max_client_index"]:
                    result["max_client_index"] = idx
            except ValueError:
                pass

    # Sort clients by index for deterministic output
    result["clients"].sort(key=lambda c: c["index"])
    return result


def get_server_flavor(server_id: str) -> str:
    """Return the original flavor name of a server (e.g. 'CM.Medium')."""
    raw = openstack("server", "show", server_id, "-f", "yaml")
    info = yaml.safe_load(raw) or {}
    flavor_info = info.get("flavor", {})
    if isinstance(flavor_info, dict):
        return flavor_info.get("original_name", "")
    return ""


def get_server_image_name(server_id: str) -> str:
    """Return the image name used when the server was created."""
    raw = openstack("server", "show", server_id, "-f", "yaml")
    info = yaml.safe_load(raw) or {}
    image_info = info.get("image", {})
    if isinstance(image_info, dict):
        return image_info.get("original_name", "")
    return ""


# ── VM creation ──────────────────────────────────────────────────────────


def resolve_image_id(name: str) -> str:
    """Resolve an image name to its UUID."""
    raw = openstack("image", "show", name, "-f", "value", "-c", "id")
    return raw.strip()


def pick_floating_ip(network_name: str = "external") -> str:
    """Allocate a floating IP from the given external network."""
    raw = openstack(
        "floating", "ip", "create", network_name, "-f", "yaml"
    )
    result = yaml.safe_load(raw) or {}
    ip = result.get("floating_ip_address", "")
    if not ip:
        print("  ERROR: Failed to allocate floating IP")
        sys.exit(1)
    print(f"    → allocated {ip}")
    return ip


def build_server_cmd(
    name: str,
    image_id: str,
    flavor: str,
    network: str,
    key_name: str,
    security_group: str,
    availability_zone: str = "",
    boot_volume_gb: int = 0,
) -> list[str]:
    """Build the openstack server create command (without --wait)."""
    cmd = [
        "openstack", "server", "create",
        "--flavor", flavor,
        "--network", network,
        "--key-name", key_name,
        "--security-group", security_group,
        name,
    ]
    if boot_volume_gb > 0:
        cmd.extend(["--image", image_id, "--boot-from-volume", str(boot_volume_gb)])
    else:
        cmd.extend(["--image", image_id])
    if availability_zone:
        cmd.extend(["--availability-zone", availability_zone])
    return cmd


def _create_server_and_parse_id(cmd: list[str], name: str) -> str:
    """Run a server-create command (no --wait), parse and return the ID."""
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"  FAILED (exit {result.returncode}) [{name}]: {result.stderr.strip()}")
        sys.exit(1)
    # Parse the ID from the table output
    for line in result.stdout.splitlines():
        if "| id" in line.lower() or "| id " in line.lower():
            parts = line.split("|")
            if len(parts) > 2:
                return parts[2].strip()
    # Fallback: look up by name
    return openstack("server", "show", name, "-f", "value", "-c", "id")


def get_server_status(server_id: str) -> str:
    """Return the current status of a server."""
    return openstack("server", "show", server_id, "-f", "value", "-c", "status", quiet=True).strip()


def get_server_name(server_id: str) -> str:
    """Return the name of a server by ID."""
    return openstack("server", "show", server_id, "-f", "value", "-c", "name").strip()


def get_server_ip(
    server_id: str, network_name: str, retries: int = 10, delay: int = 6
) -> str:
    """Get the internal IP of a server on the given network, retrying."""
    for attempt in range(1, retries + 1):
        raw = openstack("server", "show", server_id, "-f", "yaml")
        info = yaml.safe_load(raw) or {}
        addresses = info.get("addresses", {})
        net_info = addresses.get(network_name, [])
        for addr in net_info:
            if isinstance(addr, dict) and addr.get("OS-EXT-IPS:type") == "fixed":
                return addr.get("addr")
        if attempt < retries:
            time.sleep(delay)
    print(f"  {yellow('⚠')} Could not determine internal IP for {server_id}")
    return "<UNKNOWN>"


def add_floating_ip_by_id(server_id: str, floating_ip: str) -> None:
    """Associate a floating IP with a server (by server ID, not name)."""
    openstack("server", "add", "floating", "ip", server_id, floating_ip)


def wait_for_servers_active(
    server_ids: dict[str, str], interval: int = 10, timeout: int = 600
) -> None:
    """Wait for all servers to reach ACTIVE status.

    Uses wall-clock time so that slow ``openstack server show`` calls don't
    prevent the timeout from triggering.  Status checks are parallelised
    (``ThreadPoolExecutor``) to avoid O(N*wall) per iteration.

    Prints a per-iteration summary of how many servers are in each non-ACTIVE
    status.  All ``print()`` calls use ``flush=True`` so progress is visible
    even when stdout is piped.

    *server_ids* maps name → server_id so we can print readable progress.
    """
    # Cap concurrency so we don't hammer the OpenStack API.
    MAX_STATUS_WORKERS = 30

    pending = dict(server_ids)  # name → id
    start = time.monotonic()
    iteration = 0
    while pending:
        elapsed = time.monotonic() - start
        if elapsed > timeout:
            names = ", ".join(pending.keys())
            print(f"  ERROR: {len(pending)} servers still not active after "
                  f"{timeout}s ({elapsed:.0f}s wall): {names}", flush=True)
            sys.exit(1)

        iteration += 1
        # Collect statuses so we can summarise counts per status.
        statuses: dict[str, list[str]] = {}
        still_pending: dict[str, str] = {}

        # ── Parallel status check ────────────────────────────────────
        pending_items = list(pending.items())
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(MAX_STATUS_WORKERS, len(pending_items) or 1)
        ) as pool:
            fut_to_info = {
                pool.submit(get_server_status, sid): (name, sid)
                for name, sid in pending_items
            }
            checked = 0
            for fut in concurrent.futures.as_completed(fut_to_info):
                name, sid = fut_to_info[fut]
                status = fut.result()
                statuses.setdefault(status, []).append(name)
                if status.upper() == "ACTIVE":
                    print(f"    {name} → ACTIVE", flush=True)
                else:
                    still_pending[name] = sid
                checked += 1
                if checked % 100 == 0:
                    print(f"    … checked {checked}/{len(pending_items)}",
                          flush=True)
        # ── End parallel status check ─────────────────────────────────

        pending = still_pending
        if pending:
            # Short-circuit: terminal/abnormal states that will *never*
            # transition to ACTIVE on their own.
            terminal = {k: v for k, v in statuses.items()
                        if v and k.upper() in (
                            "ERROR", "STOPPED", "SHUTOFF",
                            "SUSPENDED", "SHELVED", "SHELVED_OFFLOADED",
                            "DELETED", "SOFT_DELETED",
                        )}
            if terminal:
                for st, names_ in terminal.items():
                    print(f"  {yellow('⚠')} {len(names_)} servers in {st}: "
                          f"{', '.join(names_[:5])}"
                          f"{' ...' if len(names_) > 5 else ''}", flush=True)
                names = ", ".join(pending.keys())
                print(f"  {bold('FATAL')}: {len(pending)} servers stuck in "
                      f"terminal state after {elapsed:.1f}s — aborting",
                      flush=True)
                sys.exit(1)

            # Build a summary like "3 BUILD, 1 VERIFY_RESIZE"
            counts: list[str] = []
            for st, names_ in statuses.items():
                su = st.upper()
                if su == "ACTIVE":
                    continue
                n = len(names_)
                counts.append(f"{str(n)} {st}")
            summary = " | ".join(counts) if counts else str(len(pending))
            print(f"    ({len(pending)} still non-ACTIVE — {summary}, "
                  f"checking again in {interval}s, "
                  f"wall {elapsed:.0f}s / {timeout}s)", flush=True)
            time.sleep(interval)
        elif iteration > 1:
            print(f"    {green('✓')} All {len(server_ids)} servers ACTIVE "
                  f"({elapsed:.0f}s wall)", flush=True)


# ── Parallel helpers ─────────────────────────────────────────────────────


def batch_submit_creates(
    specs: list[dict], parallel: int
) -> dict[str, str]:
    """Submit server-create commands in parallel (no --wait).

    specs: list of dicts with keys: name, image_id, flavor, network,
           key_name, security_group, az, boot_volume_gb
    parallel: max concurrent openstack CLI processes.

    Returns dict mapping name → server_id (from parse of each response).
    """
    total = len(specs)
    print(f"  Submitting {total} server creations ({parallel} at a time)...")

    results: dict[str, str] = {}
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=parallel) as pool:
        fut_to_name = {}
        for spec in specs:
            cmd = build_server_cmd(
                spec["name"], spec["image_id"], spec["flavor"],
                spec["network"], spec["key_name"], spec["security_group"],
                spec.get("az", ""), spec.get("boot_volume_gb", 0),
            )
            fut = pool.submit(_create_server_and_parse_id, cmd, spec["name"])
            fut_to_name[fut] = spec["name"]

        for fut in concurrent.futures.as_completed(fut_to_name):
            name = fut_to_name[fut]
            sid = fut.result()
            results[name] = sid
            done += 1
            if done % 50 == 0 or done == total:
                print(f"    ... {done}/{total} submitted")

    return results


def batch_get_ips(
    server_map: dict[str, str], network_name: str, parallel: int
) -> dict[str, str]:
    """Resolve internal IPs for all servers in parallel.

    Returns dict mapping name → internal_ip.
    """
    total = len(server_map)
    print(f"  Resolving {total} internal IPs ({parallel} at a time)...")

    results: dict[str, str] = {}
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=parallel) as pool:
        fut_to_name = {
            pool.submit(get_server_ip, sid, network_name): name
            for name, sid in server_map.items()
        }
        for fut in concurrent.futures.as_completed(fut_to_name):
            name = fut_to_name[fut]
            ip = fut.result()
            results[name] = ip
            done += 1
            if done % 50 == 0 or done == total:
                print(f"    ... {done}/{total} IPs resolved")

    return results


def batch_allocate_floating_ips(count: int, parallel: int) -> list[str]:
    """Allocate floating IPs in parallel.

    Returns list of floating IP strings.
    """
    print(f"  Allocating {count} floating IPs ({parallel} at a time)...")

    ips: list[str] = []
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=parallel) as pool:
        fut_to_idx = {pool.submit(pick_floating_ip, "external"): i for i in range(count)}
        # Collect in order of completion (order doesn't matter for IPs)
        completed = [None] * count
        for fut in concurrent.futures.as_completed(fut_to_idx):
            idx = fut_to_idx[fut]
            ip = fut.result()
            completed[idx] = ip
            done += 1
            if done % 50 == 0 or done == count:
                print(f"    ... {done}/{count} allocated")
    return completed


def batch_assign_floating_ips(
    server_map: dict[str, str], floating_ips: list[str], parallel: int
) -> None:
    """Assign floating IPs to servers in parallel.

    server_map: name → server_id (used for floating IPs too)
    floating_ips: list of IPs, one per server_map entry (same order).
    """
    total = len(server_map)
    print(f"  Assigning {total} floating IPs ({parallel} at a time)...")

    names = list(server_map.keys())
    done = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=parallel) as pool:
        futs = []
        for i, name in enumerate(names):
            sid = server_map[name]
            fip = floating_ips[i]
            futs.append(pool.submit(add_floating_ip_by_id, sid, fip))

        for fut in concurrent.futures.as_completed(futs):
            fut.result()  # propagate exceptions
            done += 1
            if done % 50 == 0 or done == total:
                print(f"    ... {done}/{total} assigned")


# ── Infrastructure setup ────────────────────────────────────────────────


def ensure_network(name: str, subnet_cidr: str) -> str:
    """Create network + subnet if they don't exist. Return network ID."""
    nets = discover_networks()
    existing = [n for n in nets if n["name"] == name]
    if existing:
        print(f"  Network '{name}' already exists (id={existing[0]['id']})")
        # Check if subnet exists
        subnets = discover_subnets()
        if not any(s["network_name"] == name for s in subnets):
            print(f"  Creating subnet '{name}-subnet' ({subnet_cidr})")
            openstack(
                "subnet", "create",
                "--network", name,
                "--subnet-range", subnet_cidr,
                f"{name}-subnet",
            )
        return existing[0]["id"]

    print(f"  Creating network '{name}' ({subnet_cidr})")
    net_id = openstack("network", "create", name, "-f", "value", "-c", "id")
    openstack(
        "subnet", "create",
        "--network", name,
        "--subnet-range", subnet_cidr,
        f"{name}-subnet",
    )
    return net_id.strip()


def ensure_router(network_name: str, subnet_name: str) -> None:
    """Create a router connecting the network to the external gateway."""
    router_name = f"{network_name}-router"
    raw = openstack("router", "list", "--name", router_name, "-f", "value", "-c", "ID")
    if raw.strip():
        print(f"  Router '{router_name}' already exists")
        return

    print(f"  Creating router '{router_name}'")
    openstack("router", "create", router_name)
    openstack("router", "set", "--external-gateway", "external", router_name)
    openstack("router", "add", "subnet", router_name, subnet_name)


def ensure_security_group(name: str, rules: list[dict]) -> str:
    """Create a security group with rules if it doesn't exist. Return ID."""
    sgs = discover_security_groups()
    existing = [sg for sg in sgs if sg["name"] == name]
    if existing:
        print(f"  Security group '{name}' already exists (id={existing[0]['id']})")
        return existing[0]["id"]

    print(f"  Creating security group '{name}'")
    sg_id = openstack(
        "security", "group", "create", name, "--description", name,
        "-f", "value", "-c", "id",
    ).strip()

    for rule in rules:
        proto = rule.get("protocol", "")
        port = rule.get("port", "")
        cidr = rule.get("cidr", "0.0.0.0/0")
        if proto and port:
            openstack(
                "security", "group", "rule", "create",
                "--proto", proto,
                "--dst-port", str(port),
                "--remote-ip", cidr,
                sg_id,
            )
        else:
            # ICMP or no-port rule
            openstack(
                "security", "group", "rule", "create",
                "--proto", proto or "icmp",
                "--remote-ip", cidr,
                sg_id,
            )
    print(f"  → Created with {len(rules)} rules")
    return sg_id


# ── Inventory generation ─────────────────────────────────────────────────


def generate_inventory(
    server_name: str,
    server_floating_ip: str,
    server_internal_ip: str,
    clients: list[dict],
    config: dict,
) -> str:
    """Generate inventory YAML string."""
    inventory = {
        "all": {
            "children": {
                "nomad_server": {
                    "hosts": {
                        server_name: {
                            "ansible_host": server_floating_ip,
                        }
                    }
                },
                "nomad_clients": {
                    "hosts": {
                        c["name"]: {"ansible_host": c["floating_ip"]}
                        for c in clients
                    }
                },
            },
            "vars": {
                # Network
                "vpc_cidr": config.get("vpc_cidr", "192.168.100.0/24"),
                "nomad_server_internal_ip": server_internal_ip,
                "nomad_client_internal_ips": {
                    c["name"]: c["internal_ip"] for c in clients
                },
                # Nomad
                "nomad_version": config.get("nomad_version", "1.5.3"),
                "local_nomad_zip": config.get("local_nomad_zip", ""),
                # OpenStudio
                "openstudio_version": config.get("openstudio_version", "3.10.0"),
                "local_openstudio_tarball": config.get("local_openstudio_tarball", ""),
                # NFS
                "nfs_export_path": config.get("nfs_export_path", "/nfs/opensstudio/batch"),
            },
        }
    }
    return yaml.safe_dump(inventory, default_flow_style=False, sort_keys=False)


def read_existing_inventory(path: str) -> dict | None:
    """Read an existing inventory.yml if it exists.

    Returns parsed dict, or None if the file doesn't exist or is empty.
    """
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        return data if isinstance(data, dict) else None
    except yaml.YAMLError:
        return None


def merge_inventory(
    existing: dict | None,
    new_clients: list[dict],
    server_name: str | None,
    server_floating_ip: str | None,
    server_internal_ip: str | None,
    config: dict,
) -> str:
    """Merge newly provisioned clients into existing inventory YAML.

    If an existing inventory is provided, new client entries are appended
    to the nomad_clients host group and nomad_client_internal_ips var.
    If no existing inventory or server info is given, it falls back to a
    full inventory generation (greenfield path).

    new_clients: list of dicts with keys: name, internal_ip, floating_ip
    """
    if existing is None:
        # No existing inventory — should not happen in additive mode, but
        # fall back to a new inventory if a server is provided.
        if server_name and server_floating_ip and server_internal_ip:
            return generate_inventory(
                server_name=server_name,
                server_floating_ip=server_floating_ip,
                server_internal_ip=server_internal_ip,
                clients=new_clients,
                config=config,
            )
        # Clients-only: generate with a placeholder server (inventory.yml
        # will need manual editing).
        return generate_inventory(
            server_name=server_name or "<SERVER_NAME>",
            server_floating_ip=server_floating_ip or "<SERVER_FLOATING_IP>",
            server_internal_ip=server_internal_ip or "<SERVER_INTERNAL_IP>",
            clients=new_clients,
            config=config,
        )

    # Deep-copy so we don't mutate the input
    merged = yaml.safe_load(yaml.safe_dump(existing)) or {}

    # Ensure the client host group exists
    children = merged.setdefault("all", {}).setdefault("children", {})
    client_group = children.setdefault("nomad_clients", {})
    client_hosts = client_group.setdefault("hosts", {})

    # Merge new clients into the host group
    for c in new_clients:
        client_hosts[c["name"]] = {"ansible_host": c["floating_ip"]}

    # Merge new clients into nomad_client_internal_ips
    all_vars = merged.setdefault("all", {}).setdefault("vars", {})
    internal_ips = all_vars.setdefault("nomad_client_internal_ips", {})
    for c in new_clients:
        internal_ips[c["name"]] = c["internal_ip"]

    return yaml.safe_dump(merged, default_flow_style=False, sort_keys=False)


# ── Main ─────────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Provision OpenStack VMs for a Nomad batch cluster",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode (recommended for first use)
  ./create_cluster.py

  # Fully automated
  ./create_cluster.py --clients 8 \\
      --image nomad-client-base-20260705 \\
      --flavor-server CM.Small \\
      --flavor-client CM.Medium \\
      --key-name achapin \\
      --network nomad-net \\
      --security-group nomad-sg

  # Fill quota (non-interactive)
  ./create_cluster.py --max \\
      --image nomad-client-base-20260705 \\
      --flavor-client CM.Medium \\
      --key-name achapin --yes
        """,
    )
    parser.add_argument(
        "--clients", type=int, default=0,
        help="Number of client VMs to create (default: prompt from quota)",
    )
    parser.add_argument(
        "--max", "--fill-quota", action="store_true",
        help="Create as many clients as quota allows",
    )
    parser.add_argument(
        "--parallel", type=int, default=20,
        help="Max concurrent openstack CLI processes (default: 20)",
    )
    parser.add_argument(
        "--image", default="",
        help="OpenStack image name for all VMs",
    )
    parser.add_argument(
        "--flavor-server", default="",
        help="Flavor for nomad-server",
    )
    parser.add_argument(
        "--flavor-client", default="",
        help="Flavor for nomad-client VMs",
    )
    parser.add_argument(
        "--key-name", default="",
        help="SSH keypair name in OpenStack",
    )
    parser.add_argument(
        "--network", default="nomad-net",
        help="OpenStack network name for VMs (default: nomad-net)",
    )
    parser.add_argument(
        "--security-group", default="nomad-sg",
        help="Security group name (default: nomad-sg)",
    )
    parser.add_argument(
        "--availability-zone", default="",
        help="Availability zone for VMs (optional)",
    )
    parser.add_argument(
        "--prefix", default="nomad",
        help="VM name prefix (default: nomad)",
    )
    parser.add_argument(
        "--no-auto-inventory", action="store_true",
        help="Skip auto-generating inventory.yml",
    )
    parser.add_argument(
        "--inventory-output", default="inventory.yml",
        help="Output path for inventory file (default: inventory.yml)",
    )
    parser.add_argument(
        "--yes", "-y", action="store_true",
        help="Skip confirmation prompt",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    interactive = not (args.clients and args.image and args.key_name)
    parallel = args.parallel

    print(f"\n{bold('═' * 60)}")
    print(f"  {bold('Nomad Cluster — OpenStack Provisioner')}")
    print(f"{bold('═' * 60)}\n")

    # ── 0. Check prerequisites ───────────────────────────────────────
    print(f"{bold('▸ Checking prerequisites...')}")
    # Verify openstack CLI works
    try:
        id_info = openstack("token", "issue", "-f", "value", "-c", "project_id")
        print(f"  OpenStack authenticated: project {id_info[:12]}...")
    except Exception:
        print(
            "  ERROR: OpenStack CLI not authenticated.\n"
            "  Source your openrc.sh or verify OS_* env vars are set."
        )
        sys.exit(1)

    # ── 1. Discover environment ──────────────────────────────────────
    print(f"\n{bold('▸ Discovering OpenStack environment...')}")
    quota = discover_quota()
    images = discover_images()
    flavors = discover_flavors()
    networks = discover_networks()
    sgs = discover_security_groups()
    keypairs = discover_keypairs()
    zones = discover_availability_zones()

    limits = quota["limits"]
    used = quota["used"]
    free_cores = limits.get("cores", 0) - used.get("cores", 0)
    free_ram_mb = limits.get("ram", 0) - used.get("ram", 0)
    free_ips = limits.get("floating-ips", 0) - used.get("floating-ips", 0)

    print(f"  {'Quota':<30} {'Used':<10} {'Free':<10} {'Limit':<10}")
    print(f"  {'─' * 60}")
    print(
        f"  {'Cores':<30} {used.get('cores', 0):<10} "
        f"{free_cores:<10} {limits.get('cores', 'N/A'):<10}"
    )
    print(
        f"  {'RAM (MB)':<30} {used.get('ram', 0):<10} "
        f"{free_ram_mb:<10} {limits.get('ram', 'N/A'):<10}"
    )
    print(
        f"  {'Floating IPs':<30} {used.get('floating-ips', 0):<10} "
        f"{free_ips:<10} {limits.get('floating-ips', 'N/A'):<10}"
    )
    print(f"  {'Instances':<30} {used.get('instances', '?'):<10} {'?':<10} {limits.get('instances', 'N/A'):<10}")
    print()

    # ── 1.5 Discover existing cluster ───────────────────────────────
    prefix = args.prefix
    existing = discover_existing_cluster(prefix)
    is_additive = existing["server"] is not None
    existing_client_count = len(existing["clients"])
    existing_client_indices = [c["index"] for c in existing["clients"]]

    if is_additive:
        print(f"{bold('▸ Existing cluster detected')}")
        print(f"    {prefix}-server:     {green('exists')}")
        print(f"    {prefix}-client:     {green(f'{existing_client_count} running')} "
              f"(indices {existing_client_indices[:5]}{'...' if existing_client_count > 5 else ''})")
        print(f"  → {bold('Additive mode')} — adding more clients to the existing cluster\n")

    # ── 2. Image selection ───────────────────────────────────────────
    image_name = args.image or ""

    if is_additive and not image_name:
        # Auto-detect image from existing server or first client
        detect_id = (existing["server"] or {}).get("id") or (
            existing["clients"][0]["id"] if existing["clients"] else None
        )
        if detect_id:
            image_name = get_server_image_name(detect_id)
            print(f"{bold('▸ Image:')} {image_name} (auto-detected from existing cluster)")
        else:
            image_name = ""

    if not image_name:
        # Prefer custom golden image, fall back to plain Ubuntu Jammy
        custom_images = [
            im["name"]
            for im in images
            if "nomad-client-base" in im["name"].lower()
        ]
        ubuntu_images = [
            im["name"]
            for im in images
            if "ubuntu" in im["name"].lower() and "jammy" in im["name"].lower()
        ]
        image_choices = (custom_images + ubuntu_images)[:10] if (custom_images or ubuntu_images) else [im["name"] for im in images[:20]]

        default_img = "nomad-client-base-20260705"
        if default_img in image_choices:
            image_name = default_img
        elif custom_images:
            image_name = custom_images[0]
        elif image_choices:
            image_name = image_choices[0]

        if interactive:
            print(f"{bold('▸ Available images (Ubuntu 22.04 recommended):')}")
            for i, im in enumerate(image_choices[:10], 1):
                print(f"    {i}) {im}")
            print(f"    ... ({len(images)} total images)")
            image_name = prompt("Image", default=image_name, options=image_choices[:10])
        else:
            print(f"{bold('▸ Image:')} {image_name}")

    # Resolve image name to UUID
    print(f"  Resolving image ID...")
    image_id = resolve_image_id(image_name)
    print(f"    → {image_id}")

    # ── 3. Flavor selection ──────────────────────────────────────────
    # Filter to reasonable compute flavors (not GPU, not baremetal)
    compute_flavors = [
        f
        for f in flavors
        if not any(
            gpu_prefix in f["name"]
            for gpu_prefix in ["GU.", "GH.", "baremetal", "BETA"]
        )
        and "azimuth" not in f["name"].lower()
    ]
    compute_flavors.sort(key=lambda f: (f["vcpus"], f["ram_mb"]))
    flavor_names = [f["name"] for f in compute_flavors]

    flavor_server = args.flavor_server or ""
    flavor_client = args.flavor_client or ""

    # In additive mode, auto-detect client flavor from existing clients
    if is_additive and not flavor_client:
        if existing["clients"]:
            flavor_client = get_server_flavor(existing["clients"][0]["id"])
            print(f"{bold('▸ Client flavor:')} {flavor_client} (auto-detected from existing clients)")
        else:
            # No existing clients (weird for additive mode, but possible if
            # only the server exists). Fall through to interactive prompt.
            pass
        # Server flavor not needed — server already exists
        flavor_server = args.flavor_server or ""

    if is_additive:
        # In additive mode, we still need the server flavor spec for quota
        # calculation. If not provided, try to detect from existing server.
        if not flavor_server and existing["server"]:
            flavor_server = get_server_flavor(existing["server"]["id"])
            print(f"{bold('▸ Server flavor:')} {flavor_server} (auto-detected)")
        elif not flavor_server:
            flavor_server = ""

    if interactive and not is_additive:
        # ─ Recommend a server flavor ─
        print(f"\n{bold('▸ Available flavors (compute, sorted by vCPU):')}")
        print(
            f"  {'Name':<22} {'vCPUs':<8} {'RAM':<12} {'Disk':<8}"
        )
        print(f"  {'─' * 50}")
        for f in compute_flavors:
            print(f"  {f['name']:<22} {f['vcpus']:<8} {f['ram_mb']}MB  {f['disk_gb']}GB")

        # Server flavor: something with enough RAM for NFS + Nomad
        default_server = "CM.Small"
        if default_server not in flavor_names:
            default_server = flavor_names[0] if flavor_names else ""
        print(
            f"\n{bold('Nomad server flavor')}  "
            f"{dim('(needs enough RAM for Nomad + NFS — CM.Small/Medium recommended)')}"
        )
        flavor_server = prompt("Flavor", default=default_server)

        # Client flavor: lean is fine
        default_client = "CM.Tiny"
        if default_client not in flavor_names:
            default_client = flavor_names[0] if flavor_names else ""
        print(
            f"\n{bold('Nomad client flavor')}  "
            f"{dim('(CM.Medium=~8 concurrent sims, CM.Tiny=~2 — pick bigger = fewer VMs)')}"
        )
        flavor_client = prompt("Flavor", default=default_client)
    elif not interactive:
        if not is_additive:
            print(f"{bold('▸ Server flavor:')} {flavor_server}")
        print(f"{bold('▸ Client flavor:')} {flavor_client}")

    # ── 4. Keypair ───────────────────────────────────────────────────
    key_name = args.key_name or ""
    if not key_name:
        if interactive and keypairs:
            print(f"\n{bold('▸ Available SSH keypairs:')}")
            for i, kp in enumerate(keypairs, 1):
                print(f"    {i}) {kp}")
            key_name = prompt("Keypair", default=keypairs[0], options=keypairs)
        elif keypairs:
            key_name = keypairs[0]
        else:
            print("  ERROR: No SSH keypairs found. Create one with:")
            print("    openstack keypair create <name>")
            sys.exit(1)
    print(f"{bold('▸ Keypair:')} {key_name}")

    # ── 5. Number of clients (quota-aware) ───────────────────────────
    # Look up flavor specs for calculation
    server_flavor_spec = next(
        (f for f in flavors if f["name"] == flavor_server), None
    )
    client_flavor_spec = next(
        (f for f in flavors if f["name"] == flavor_client), None
    )

    max_by_cores = 0
    max_by_ram = 0
    max_by_ips = 0
    hard_max = 0
    recommended_clients = 3

    if server_flavor_spec and client_flavor_spec:
        sc = server_flavor_spec["vcpus"]
        sr = server_flavor_spec["ram_mb"]
        cc = client_flavor_spec["vcpus"]
        cr = client_flavor_spec["ram_mb"]

        # How many NEW clients fit after reserving existing usage + overhead?
        buffer = 0.05
        if is_additive:
            # Server already exists — don't reserve server resources again
            max_by_cores = max(0, int(free_cores * (1 - buffer) / cc)) if cc else 0
            max_by_ram = max(0, int(free_ram_mb * (1 - buffer) / cr)) if cr else 0
            max_by_ips = max(0, free_ips)  # no new server floating IP needed
        else:
            max_by_cores = max(0, int((free_cores * (1 - buffer) - sc) / cc)) if cc else 0
            max_by_ram = max(0, int((free_ram_mb * (1 - buffer) - sr) / cr)) if cr else 0
            max_by_ips = max(0, free_ips - 1)  # server needs 1 floating IP

        # Hard limit: minimum of all constraints
        hard_max = min(max_by_cores, max_by_ram, max_by_ips)

        # Recommended: 90% of hard max (leave some headroom), min 1
        recommended_clients = max(1, int(hard_max * 0.9))

    # Determine how many NEW clients to create
    num_new_clients = args.clients
    if args.max and not interactive:
        if recommended_clients > 0:
            num_new_clients = hard_max
            verb = "adding" if is_additive else "creating"
            print(f"{bold('▸ --max:')} {verb} {num_new_clients} new clients (quota cap)")
        else:
            print("  ERROR: Cannot calculate quota capacity (flavor lookup failed)")
            sys.exit(1)
    elif interactive:
        prompt_label = "Number of ADDITIONAL Nomad clients to create" if is_additive else "Number of Nomad clients to create"

        print(f"\n{bold('▸ Quota-based client capacity:')}")
        if server_flavor_spec and client_flavor_spec:
            if is_additive:
                print(f"    Existing clients: {existing_client_count}")
                print(f"    Free quota → ~{max_by_cores} new clients (cores), "
                      f"~{max_by_ram} (RAM), ~{max_by_ips} (floating IPs)")
            else:
                print(
                    f"    Cores:   {free_cores} free → "
                    f"~{max_by_cores} clients  "
                    f"({server_flavor_spec['vcpus']}vCPU server + "
                    f"{client_flavor_spec['vcpus']}vCPU each)"
                )
                print(
                    f"    RAM:     {free_ram_mb:,}MB free → "
                    f"~{max_by_ram} clients  "
                    f"({server_flavor_spec['ram_mb']:,}MB server + "
                    f"{client_flavor_spec['ram_mb']:,}MB each)"
                )
                print(
                    f"    FloatIP: {free_ips} free → "
                    f"~{max_by_ips} clients  (1 for server)"
                )
            print(
                f"    {bold('Recommended max NEW')}: {hard_max} "
                f"(recommended w/ headroom: {recommended_clients})"
            )
        else:
            print(f"    (could not look up flavor specs — using default)")

        raw = prompt(
            prompt_label,
            default=str(recommended_clients),
        )
        num_new_clients = int(raw)
    else:
        # Non-interactive: validate requested count against quota
        if (
            server_flavor_spec
            and client_flavor_spec
            and recommended_clients > 0
        ):
            if num_new_clients > hard_max:
                print(
                    f"  {yellow('⚠')} Requested {num_new_clients} new clients "
                    f"exceeds quota capacity ({hard_max} new)."
                )
                print(f"  Set --clients {hard_max} or lower.")
                sys.exit(1)

    # Total clients after this run (for display)
    total_clients_after = existing_client_count + num_new_clients
    if is_additive:
        print(f"{bold('▸ New clients:')} {num_new_clients}  "
              f"(total after: {green(str(total_clients_after))})")
    else:
        print(f"{bold('▸ Clients:')} {num_new_clients}")

    # ── 6. Network ───────────────────────────────────────────────────
    network_name = args.network
    net_names = [n["name"] for n in networks]
    if network_name not in net_names:
        print(f"\n  {yellow('Note:')} Network '{network_name}' not found.")
        yn = input("  Create it? [Y/n]: ").strip().lower() or "y"
        if yn == "y":
            vpc_cidr = prompt(
                "Subnet CIDR for internal network",
                default="192.168.100.0/24",
            )
            ensure_network(network_name, vpc_cidr)
            # Also create a router for external access
            ensure_router(network_name, f"{network_name}-subnet")
        else:
            available = ", ".join(net_names[:8])
            print(f"  Available networks: {available}")
            network_name = prompt("Network name", options=net_names[:8])
    else:
        print(f"{bold('▸ Network:')} {network_name} (existing)")

    # ── 7. Security group ────────────────────────────────────────────
    sg_name = args.security_group
    sg_names = [sg["name"] for sg in sgs]
    if sg_name not in sg_names:
        print(f"\n  {yellow('Note:')} Security group '{sg_name}' not found.")
        yn = input("  Create it with standard rules? [Y/n]: ").strip().lower() or "y"
        if yn == "y":
            rules = [
                {"protocol": "tcp", "port": 22, "cidr": "0.0.0.0/0"},
                {"protocol": "tcp", "port": 4646, "cidr": "0.0.0.0/0"},
                {"protocol": "tcp", "port": 2049, "cidr": "0.0.0.0/0"},
                {"protocol": "udp", "port": 2049, "cidr": "0.0.0.0/0"},
                {"protocol": "tcp", "port": 80, "cidr": "0.0.0.0/0"},
                {"protocol": "tcp", "port": 443, "cidr": "0.0.0.0/0"},
                {"protocol": "udp", "port": 53, "cidr": "0.0.0.0/0"},
                {"protocol": "tcp", "port": 53, "cidr": "0.0.0.0/0"},
            ]
            ensure_security_group(sg_name, rules)
        else:
            sg_name = prompt(
                "Security group name",
                default=sg_names[0] if sg_names else "default",
                options=sg_names[:8] if sg_names else None,
            )
    else:
        print(f"{bold('▸ Security group:')} {sg_name} (existing)")

    # ── 8. Availability zone ─────────────────────────────────────────
    az = args.availability_zone
    if interactive and not az and zones:
        print(f"\n{bold('▸ Available zones:')}")
        for i, z in enumerate(zones, 1):
            print(f"    {i}) {z}")
        print(f"    {len(zones) + 1}) (any)")
        az_choice = prompt(
            "Availability zone",
            default="",
            options=zones + ["(any)"],
        )
        az = "" if az_choice == "(any)" else az_choice
    elif not az:
        az = ""

    # ── 9. Confirmation ──────────────────────────────────────────────
    new_cores = 0
    new_ram_mb = 0
    existing_cores = 0
    existing_ram_mb = 0
    # Look up flavor specs
    for f in flavors:
        if is_additive:
            pass  # Already accounted in quota usage
        if f["name"] == flavor_server and not is_additive:
            new_cores += f["vcpus"]
            new_ram_mb += f["ram_mb"]
        if f["name"] == flavor_client:
            new_cores += f["vcpus"] * num_new_clients
            new_ram_mb += f["ram_mb"] * num_new_clients
            if is_additive:
                existing_cores = f["vcpus"] * existing_client_count
                existing_ram_mb = f["ram_mb"] * existing_client_count
        if f["name"] == flavor_server and is_additive:
            existing_cores += f["vcpus"]
            existing_ram_mb += f["ram_mb"]

    total_cores = existing_cores + new_cores
    total_ram_mb = existing_ram_mb + new_ram_mb

    print(f"\n{bold('═' * 60)}")
    print(f"  {bold('Summary')}")
    print(f"  {'─' * 40}")

    if is_additive:
        print(f"  {'Existing':>8} {'New':>8} {'Total':>8}")
        print(f"  {'─' * 28}")
        print(f"  Clients  {existing_client_count:>5}  {num_new_clients:>5}  {total_clients_after:>5}")
        print(f"  vCPUs    {existing_cores:>5}  {new_cores:>5}  {total_cores:>5}")
        print(f"  RAM (MB) {existing_ram_mb:>6,}  {new_ram_mb:>6,}  {total_ram_mb:>6,}")
        print(f"  FloatIP  {existing_client_count + (1 if existing['server'] else 0):>5}  {num_new_clients:>5}  {existing_client_count + num_new_clients + (1 if existing['server'] else 0):>5}")
        print(f"  {'─' * 28}")
    else:
        print(f"  {'Component':<20} {'Count':<8} {'vCPUs':<8} {'RAM':<10}")
        print(f"  {'─' * 46}")
        print(
            f"  {'nomad-server':<20} {'1':<8} "
            f"{next((f['vcpus'] for f in flavors if f['name'] == flavor_server), '?'):<8} "
            f"{next((f['ram_mb'] for f in flavors if f['name'] == flavor_server), '?'):<6}MB"
        )
        print(
            f"  {'nomad-client':<20} {num_new_clients:<8} "
            f"{next((f['vcpus'] for f in flavors if f['name'] == flavor_client), '?') * num_new_clients:<8} "
            f"{next((f['ram_mb'] for f in flavors if f['name'] == flavor_client), '?') * num_new_clients:<6}MB"
        )
        print(f"  {'─' * 46}")

    print(
        f"  {'Total':<20} {1 + num_new_clients:<8} {total_cores:<8} "
        f"{total_ram_mb:<6}MB"
    )
    print(
        f"  {'Free in quota':<36} "
        f"{free_cores:<8} {free_ram_mb:<6}MB"
    )
    print(f"  {'Floating IPs needed':<20} {num_new_clients + (0 if is_additive else 1):<8}")
    print(f"  {'Free floating IPs':<20} {free_ips:<8}")
    print(
        f"  {'Quota cap (max new)':<20} "
        f"{hard_max if server_flavor_spec and client_flavor_spec else '?'}"
    )
    print(f"  {'Image':<20} {image_name}")
    print(f"  {'Network':<20} {network_name}")
    print(f"  {'Security group':<20} {sg_name}")
    print(f"  {'Keypair':<20} {key_name}")

    if free_ips < num_new_clients + (0 if is_additive else 1):
        print(f"\n  {yellow('⚠')} Not enough floating IPs available!")
        sys.exit(1)

    if not args.yes:
        verb = "Add these" if is_additive else "Create these"
        yn = input(f"\n  {bold(f'{verb} VMs?')} [y/N]: ").strip().lower()
        if yn != "y":
            print("  Aborted.")
            sys.exit(0)

    # ── 10. Create VMs (fully parallel pipeline) ─────────────────────
    # Flavors with 0 disk require volume-backed servers.
    # Use a 10GB boot volume for 0-disk flavors.
    client_boot_volume = (
        0 if (client_flavor_spec and client_flavor_spec["disk_gb"] > 0) else 10
    )

    print(f"\n{bold('▸ Creating VMs (parallel={parallel})...')}")

    # Build all the specs first
    prefix = args.prefix
    server_name = f"{prefix}-server"

    if is_additive:
        # Skip server creation, start client numbering after existing max
        client_start = existing["max_client_index"] + 1
        all_specs = [
            {
                "name": f"{prefix}-client-{client_start + i - 1}",
                "image_id": image_id,
                "flavor": flavor_client,
                "network": network_name,
                "key_name": key_name,
                "security_group": sg_name,
                "az": az,
                "boot_volume_gb": client_boot_volume,
            }
            for i in range(1, num_new_clients + 1)
        ]
        num_new_servers = num_new_clients  # only clients, no server
    else:
        server_boot_volume = (
            0 if (server_flavor_spec and server_flavor_spec["disk_gb"] > 0) else 10
        )
        all_specs = [
            {
                "name": server_name,
                "image_id": image_id,
                "flavor": flavor_server,
                "network": network_name,
                "key_name": key_name,
                "security_group": sg_name,
                "az": az,
                "boot_volume_gb": server_boot_volume,
            }
        ]
        client_start = 1
        for i in range(client_start, num_new_clients + 1):
            all_specs.append(
                {
                    "name": f"{prefix}-client-{i}",
                    "image_id": image_id,
                    "flavor": flavor_client,
                    "network": network_name,
                    "key_name": key_name,
                    "security_group": sg_name,
                    "az": az,
                    "boot_volume_gb": client_boot_volume,
                }
            )
        num_new_servers = 1 + num_new_clients

    # ── Phase 1: Submit all creates in parallel (no --wait) ─────
    name_to_id = batch_submit_creates(all_specs, parallel)

    if is_additive:
        server_id = existing["server"]["id"]
        print(f"  {green('✓')} {len(name_to_id)} new client(s) submitted")
    else:
        server_id = name_to_id[server_name]
        print(f"  {green('✓')} {len(name_to_id)} servers submitted")

    # ── Phase 2: Wait for all to become ACTIVE (batch poll) ────
    if name_to_id:
        print(f"\n  {bold('Waiting for all VMs to become ACTIVE...')}")
        wait_for_servers_active(name_to_id, interval=15, timeout=900)
        print(f"  {green('✓')} All servers ACTIVE")
    else:
        print("  No new VMs to wait for.")

    # ── Phase 3: Resolve internal IPs (parallel) ───────────────
    if name_to_id:
        print(f"\n  {bold('Resolving internal IPs...')}")
        name_to_ip = batch_get_ips(name_to_id, network_name, parallel)
        print(f"  {green('✓')} IPs resolved")
    else:
        name_to_ip = {}

    # ── Phase 4: Allocate floating IPs (parallel) ──────────────
    if name_to_id:
        print(f"\n  {bold('Allocating floating IPs...')}")
        floating_ips = batch_allocate_floating_ips(len(name_to_id), parallel)
        print(f"  {green('✓')} {len(floating_ips)} IPs allocated")
    else:
        floating_ips = []

    # ── Phase 5: Assign floating IPs (parallel) ────────────────
    if name_to_id and floating_ips:
        print(f"\n  {bold('Assigning floating IPs...')}")
        batch_assign_floating_ips(name_to_id, floating_ips, parallel)
        print(f"  {green('✓')} All floating IPs assigned")

    # Build client_info for inventory generation
    client_info = []
    if is_additive:
        # New clients are named {prefix}-client-{existing_max + 1} ... etc.
        # all_specs[i] corresponds to name in name_to_id
        for spec in all_specs:
            cname = spec["name"]
            cid = name_to_id.get(cname, "")
            client_info.append(
                {
                    "name": cname,
                    "id": cid,
                    "internal_ip": name_to_ip.get(cname, "<UNKNOWN>"),
                    "floating_ip": floating_ips[all_specs.index(spec)] if floating_ips else "<UNKNOWN>",
                }
            )
    else:
        for i in range(client_start, num_new_clients + 1):
            cname = f"{prefix}-client-{i}"
            cid = name_to_id.get(cname, "")
            client_info.append(
                {
                    "name": cname,
                    "id": cid,
                    "internal_ip": name_to_ip.get(cname, "<UNKNOWN>"),
                    "floating_ip": floating_ips[i] if len(floating_ips) > i else "<UNKNOWN>",
                }
            )
        server_internal = name_to_ip.get(server_name, "<UNKNOWN>")
        server_floating = floating_ips[0] if len(floating_ips) > 0 else "<UNKNOWN>"

    # ── 11. Generate / merge inventory ──────────────────────────────
    if not args.no_auto_inventory:
        config = {
            "vpc_cidr": "192.168.100.0/24",
            "nomad_version": "1.5.3",
            "local_nomad_zip": "/tmp/nomad_1.5.3_linux_amd64.zip",
            "openstudio_version": "3.10.0",
            "local_openstudio_tarball": "/tmp/OpenStudio-3.10.0.tar.gz",
            "nfs_export_path": "/nfs/opensstudio/batch",
        }

        out_path = args.inventory_output

        if is_additive:
            # Read existing inventory, merge new clients
            existing_inv = read_existing_inventory(out_path)
            if existing_inv:
                inventory_yaml = merge_inventory(
                    existing=existing_inv,
                    new_clients=client_info,
                    server_name=existing["server"]["name"] if existing["server"] else None,
                    server_floating_ip=None,  # preserve existing
                    server_internal_ip=None,
                    config=config,
                )
                print(f"\n  {green('✓')} Merged {len(client_info)} new client(s) into {out_path}")
            else:
                # No existing inventory — create fresh with just the new clients
                # plus existing server info if available
                if existing["server"]:
                    existing_server_floating = ""
                    existing_server_internal = ""
                    try:
                        s_raw = openstack("server", "show", existing["server"]["id"], "-f", "yaml")
                        s_info = yaml.safe_load(s_raw) or {}
                        addrs = s_info.get("addresses", {})
                        net_addrs = addrs.get(network_name, [])
                        for a in net_addrs:
                            if isinstance(a, dict) and a.get("OS-EXT-IPS:type") == "floating":
                                existing_server_floating = a.get("addr", "")
                            elif isinstance(a, dict) and a.get("OS-EXT-IPS:type") == "fixed":
                                existing_server_internal = a.get("addr", "")
                    except Exception:
                        pass
                    inventory_yaml = generate_inventory(
                        server_name=existing["server"]["name"],
                        server_floating_ip=existing_server_floating or "<SERVER_FLOATING_IP>",
                        server_internal_ip=existing_server_internal or "<SERVER_INTERNAL_IP>",
                        clients=client_info + [
                            # Include existing clients too (gathered from OpenStack)
                            {"name": c["name"], "internal_ip": "<UNKNOWN>", "floating_ip": "<UNKNOWN>"}
                            for c in existing["clients"]
                        ],
                        config=config,
                    )
                else:
                    inventory_yaml = generate_inventory(
                        server_name=server_name,
                        server_floating_ip="<SERVER_FLOATING_IP>",
                        server_internal_ip="<SERVER_INTERNAL_IP>",
                        clients=client_info,
                        config=config,
                    )
                print(f"\n  {green('✓')} Inventory written to {out_path}")
        else:
            # Greenfield — generate fresh inventory
            inventory_yaml = generate_inventory(
                server_name=server_name,
                server_floating_ip=server_floating,
                server_internal_ip=server_internal,
                clients=client_info,
                config=config,
            )
            print(f"\n  {green('✓')} Inventory written to {out_path}")

        with open(out_path, "w") as f:
            f.write(inventory_yaml)

        print(f"\n  {bold('Next steps:')}")
        print(f"    1. Edit {out_path} to set:")
        print(f"       - local_nomad_zip (path to Nomad binary)")
        print(f"       - local_openstudio_tarball (path to OpenStudio tarball)")
        print(f"    2. Validate:   make test")
        print(f"    3. Provision:  make deploy")
    else:
        print(f"\n  {yellow('(skipped inventory generation)')}")

    # ── 12. Summary ─────────────────────────────────────────────────
    print(f"\n{bold('═' * 60)}")

    if is_additive:
        print(f"  {bold('New clients added to cluster!')}")
        print(f"  {'─' * 40}")
        if existing["server"]:
            print(f"  {existing['server']['name']:20} (existing)")
        for c in existing["clients"]:
            print(f"  {c['name']:20} (existing)")
        for c in client_info:
            print(f"  {c['name']:20} {c['floating_ip']}  (internal: {c['internal_ip']})  {green('★ NEW')}")
        print(f"\n  Total clients: {total_clients_after}")
        print(f"  Run 'make deploy' to provision the new clients")
    else:
        print(f"  {bold('Cluster created!')}")
        print(f"  {'─' * 40}")
        print(f"  {server_name:20} {server_floating}  (internal: {server_internal})")
        for c in client_info:
            print(f"  {c['name']:20} {c['floating_ip']}  (internal: {c['internal_ip']})")
        print(f"\n  SSH access: ssh ubuntu@<floating-ip>")
        print(f"  Nomad UI:   http://{server_floating}:4646")

    print(f"{bold('═' * 60)}\n")


if __name__ == "__main__":
    main()

# Deployment

> Phase-based deployment with Ansible playbooks. Phases 1-3 are automated end-to-end;
> Phases 4-5 require manual steps or are optional.

## Prerequisites

| Requirement | Notes |
|---|---|
| Proxmox host | Accessible at `192.168.10.1` |
| SSH keys | Workstation key added to Proxmox root and Ansible user |
| SOPS age key | `~/.config/sops/age/keys.txt` — required to decrypt vault |
| Tailscale auth key | Generated from Tailscale admin console, stored in vault |
| OpenTofu | VM provisioning in Phase 1 |

## Phases

| Phase | Purpose | Playbook | Key Actions |
|---|---|---|---|
| **1** | Provision VMs | `phases/phase1-infrastructure.yml` | Clone VM templates via OpenTofu, wait for SSH |
| **2** | Bootstrap | `phases/phase2-bootstrap.yml` | SSH keys, timezone, NAS/Btrfs, Tailscale, Nexus registry, Unbound, AdGuard |
| **3** | Services | `phases/phase3-services.yml` | NFS mounts, Home Assistant, Satisfactory, PostgreSQL, Jellyfin, Lancache, Traefik |
| **4** | Post-deployment | `phases/phase4-post-deployment.yml` | Jellyfin config, UFW hardening, Tdarr, Woodpecker CI, Docs, UniFi |
| **5** | Monitoring | `phases/phase5-monitoring.yml` | node_exporter, cAdvisor, Prometheus, Grafana, Uptime Kuma |

**Manual step required between Phase 3 and Phase 4:**

1. Complete the Jellyfin initial setup wizard at `https://jellyfin.discus-moth.ts.net`
2. Enable AdGuard DNS rewrites for the reverse proxy (`traefik_enabled: true` in
   `playbooks/services/configs/adguard-vars.yml`, then re-run AdGuard playbook)

**Manual step required after Phase 2:**

Configure Tailscale to use internal DNS:

1. Go to `https://login.tailscale.com/admin/dns`
2. Add nameserver pointing to the NAS Tailscale IP
3. Enable "Override local DNS"

## k3s Cluster

The k3s cluster is bootstrapped separately from the main phases. Run after Phase 2 (VMs
provisioned, Tailscale installed):

```bash
./bin/runtime/ansible-run.sh playbooks/infrastructure/k3s-cluster.yml
```

This playbook handles GPU passthrough on Proxmox, installs k3s on all 5 nodes, joins workers,
configures the NVIDIA GPU node, and bootstraps Flux CD.

See [k3s Cluster](k3s-cluster.md) for ongoing cluster operations.

## Running Playbooks

All playbooks are run via the runtime wrapper (handles vault decryption and inventory):

```bash
# Full automated deployment (Phases 1-3 only)
./bin/runtime/ansible-run.sh playbooks/main.yml

# Individual phase
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
./bin/runtime/ansible-run.sh playbooks/phases/phase2-bootstrap.yml
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
./bin/runtime/ansible-run.sh playbooks/phases/phase5-monitoring.yml

# k3s cluster bootstrap
./bin/runtime/ansible-run.sh playbooks/infrastructure/k3s-cluster.yml

# Single service playbook
./bin/runtime/ansible-run.sh playbooks/services/jellyfin.yml
./bin/runtime/ansible-run.sh playbooks/services/traefik-proxy.yml
```

## VM Inventory

Provisioned by Phase 1 (OpenTofu):

| VM | IP | VLAN |
|---|---|---|
| home-assistant | 192.168.20.10 | IoT (20) |
| satisfactory-server | 192.168.40.11 | Gaming (40) |
| jellyfin | 192.168.30.12 | Media (30) |
| nas | 192.168.30.15 | Media (30) |
| db | 192.168.30.16 | Media (30) |
| monitoring | 192.168.10.16 | Management (10) |
| automation | 192.168.10.17 | Management (10) |
| lancache | 192.168.40.18 | Gaming (40) |
| unifi-controller | 192.168.10.19 | Management (10) |
| reverse-proxy | 192.168.10.20 | Management (10) |
| k8s-control | 192.168.30.40 | Media (30) |
| k8s-gpu | 192.168.30.41 | Media (30) |
| k8s-media | 192.168.30.42 | Media (30) |
| k8s-net | 192.168.30.43 | Media (30) |
| k8s-ops | 192.168.30.44 | Media (30) |

Boot order on Proxmox startup: NAS (1) → Media stack (2-4) → Independent VMs (5-9) →
k3s control plane (15) → k3s workers (16).

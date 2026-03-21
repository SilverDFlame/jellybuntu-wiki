# PostgreSQL

> Centralized PostgreSQL 16 database server for all k3s services

| Field | Value |
|-------|-------|
| **Runs on** | VM `db` (VMID 415), `192.168.30.16` |
| **Access** | Direct: `192.168.30.16:5432` (no web UI) |
| **Port** | 5432 |
| **Repo** | [`roles/postgresql/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/postgresql) and [`host_vars/db.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/db.yml) |

## Databases

All databases are created by
[`playbooks/services/db.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/db.yml).

| Database | Owner | Consumer |
|----------|-------|----------|
| `sonarr_main` | `sonarr` | Sonarr (k3s) |
| `sonarr_log` | `sonarr` | Sonarr (k3s) |
| `radarr_main` | `radarr` | Radarr (k3s) |
| `radarr_log` | `radarr` | Radarr (k3s) |
| `lidarr_main` | `lidarr` | Lidarr (k3s) |
| `lidarr_log` | `lidarr` | Lidarr (k3s) |
| `synapse` | `synapse` | Matrix Synapse (k3s) |

## Key Config

- PostgreSQL 16; `shared_buffers = 1 GB`, `effective_cache_size = 2 GB`, `max_connections = 100`
- `pg_hba.conf` allows the full `192.168.30.0/24` (Media VLAN) subnet — covers all k3s pods and VMs
- k3s pods connect via direct IP `192.168.30.16:5432`; DB hostname used in Helm values is `192.168.30.16`
- VM resources: 2 vCPUs, 4 GB RAM, 40 GB disk (startup order 2, after NAS)
- No Traefik proxy — database traffic is never exposed externally

## Common Operations

```bash
# Deploy / reconfigure
./bin/runtime/ansible-run.sh playbooks/services/db.yml

# Connect interactively (from any Media VLAN host)
psql -h 192.168.30.16 -U postgres

# Check service status on the VM
ssh db.discus-moth.ts.net systemctl status postgresql

# List databases
psql -h 192.168.30.16 -U postgres -c '\l'

# Restart PostgreSQL
ssh db.discus-moth.ts.net sudo systemctl restart postgresql
```

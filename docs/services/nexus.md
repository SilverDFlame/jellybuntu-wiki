# Nexus Repository Manager

> Sonatype Nexus OSS — container registry mirror, APT proxy, and PyPI proxy on NAS

| Field | Value |
|-------|-------|
| **Runs on** | NAS VM (VMID 300), `192.168.30.15` |
| **Access** | `http://nas.discus-moth.ts.net:8081` (web UI) |
| **Ports** | 8081 (web UI / API), 5000 (hosted registry), 5001 (group registry) |
| **Repo** | [`roles/podman_app/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/podman_app) and [`host_vars/nas.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/nas.yml) |

## Key Config

- Runs as a rootless Podman container; data at `/opt/nexus/data` and blob storage at `/mnt/storage/nexus/blobs`
- Container runs as UID 200 (nexus user inside image); directories pre-created with matching ownership
- Anonymous pulls enabled — k3s nodes pull images without authentication
- Configured automatically on deploy via Nexus REST API (see `nexus_api_config` in `host_vars/nas.yml`)

**Docker repositories:**

| Name | Type | Port | Purpose |
|------|------|------|---------|
| `docker-hosted` | hosted | 5000 | Custom images (packer-ansible, etc.) |
| `docker-hub-proxy` | proxy | — | Mirrors `registry-1.docker.io` |
| `docker-ghcr-proxy` | proxy | — | Mirrors `ghcr.io` |
| `docker-lscr-proxy` | proxy | — | Mirrors `lscr.io` (LinuxServer) |
| `docker-quay-proxy` | proxy | — | Mirrors `quay.io` |
| `docker-gcr-proxy` | proxy | — | Mirrors `gcr.io` |
| `docker-kaniko-cache` | hosted | — | Kaniko layer cache for CI builds |
| `docker-group` | group | 5001 | Unified pull endpoint for all of the above |

**Other repositories:** `apt-ubuntu-proxy` (Ubuntu Noble), `pypi-proxy`

k3s nodes use `nas.discus-moth.ts.net:5001` as their primary registry endpoint,
which resolves all upstream pulls through the group proxy.

## Common Operations

```bash
# Deploy / reconfigure (including API-driven repo setup)
./bin/runtime/ansible-run.sh playbooks/services/nas.yml

# Check container status
ssh nas.discus-moth.ts.net podman ps --filter name=nexus

# View logs
ssh nas.discus-moth.ts.net podman logs -f nexus

# Restart
ssh nas.discus-moth.ts.net systemctl --user restart podman-nexus

# Pull an image through Nexus (from any k3s node or LAN host)
podman pull nas.discus-moth.ts.net:5001/library/alpine:latest

# Check blob storage usage
ssh nas.discus-moth.ts.net du -sh /mnt/storage/nexus/blobs/
```

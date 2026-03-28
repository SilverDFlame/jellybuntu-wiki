# LanCache

> Game download cache — intercepts Steam, Epic, and Battle.net CDN traffic for LAN clients

| Field | Value |
|-------|-------|
| **Runs on** | VM `lancache` (VMID 700), `192.168.40.18` |
| **Access** | Transparent proxy — no web UI; clients are directed via DNS rewrites |
| **Ports** | 80 (HTTP cache), 443 (HTTPS SNI proxy) |
| **Repo** | [`roles/lancache/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/lancache) and [`host_vars/lancache.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/lancache.yml) |

## Key Config

- Runs as a **rootful** Podman container (required: NFS `no_root_squash` + `chown` on startup)
- Image: `lancachenet/monolithic:latest` pulled via Nexus group registry
- Cache storage on NFS mount `/mnt/lancache` from NAS at `192.168.30.15` (local IP, not Tailscale)
  - Direct local path achieves full 10 Gbps; Tailscale overhead limits NFS to ~70 Mbps
  - NFS options: `rw,hard,nfsvers=4.2,async,noatime,nosuid,nodev`
- Cache limits: 2 TB disk (`lancache_cache_disk_size`), 500 MB nginx memory (`lancache_cache_mem_size`)
- DNS routing: AdGuard rewrites Steam CDN domains to `192.168.40.18` when lancache is enabled
  - `lancache_enabled: false` in `adguard-vars.yml` — toggle to activate DNS rewrites
- VM resources: 2 vCPUs, 4 GB RAM, 32 GB disk (startup order 8)

## Common Operations

```bash
# Deploy / reconfigure
./bin/runtime/ansible-run.sh playbooks/services/lancache.yml

# Check container and NFS mount
ssh lancache.discus-moth.ts.net sudo podman ps --filter name=lancache
ssh lancache.discus-moth.ts.net mount | grep lancache

# View logs
ssh lancache.discus-moth.ts.net sudo podman logs -f lancache

# Restart
ssh lancache.discus-moth.ts.net sudo systemctl restart podman-lancache

# Enable DNS rewrites (activates caching for LAN clients)
# Set lancache_enabled: true in services/configs/adguard-vars.yml, then:
./bin/runtime/ansible-run.sh playbooks/networking/adguard-home.yml

# Clear cache (if stale or corrupt)
ssh lancache.discus-moth.ts.net sudo podman stop lancache
ssh lancache.discus-moth.ts.net sudo rm -rf /mnt/lancache/*
ssh lancache.discus-moth.ts.net sudo systemctl start podman-lancache
```

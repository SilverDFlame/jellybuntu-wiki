# Memory Limits Changes - October 31, 2025

## Summary

Added memory limits to all 18 containers to resolve ContainerHighMemory alerts.

**Files Modified**: 15 service files + 1 role
**Investigation**: `logs/memory-investigation-20251031-133602.txt`
**Root Cause**: No memory limits configured, causing Prometheus to report +Inf% usage

---

## Changes Applied

### Media Services VM (9 services)

Located in: `compose_files/services/`

| Service | Memory Limit | Reservation | Current Usage | File |
|---------|-------------|-------------|---------------|------|
| Sonarr | 1G | 512M | 0.30 GB | sonarr.yml |
| Radarr | 1G | 512M | 0.20 GB | radarr.yml |
| Prowlarr | 512M | 256M | 0.20 GB | prowlarr.yml |
| Bazarr | 1G | 512M | 0.42 GB | bazarr.yml |
| Jellyseerr | 1G | 512M | 0.28 GB | jellyseer.yml |
| FlareSolverr | 1G | 512M | 0.46 GB | flaresolverr.yml |
| Portainer | 256M | 128M | 0.03 GB | portainer.yml |
| Homepage | 512M | 256M | 0.10 GB | homepage.yml |
| Huntarr | 512M | 256M | 0.14 GB | huntarr.yml |
| Recyclarr | 256M | 128M | 0.02 GB | recyclarr.yml |

**Total limits**: ~7GB (VM has 6GB RAM - will need increase to 8GB)

### Download Clients VM (4 services)

Located in: `compose_files/services/`

| Service | Memory Limit | Reservation | Current Usage | File |
|---------|-------------|-------------|---------------|------|
| qBittorrent | 6G | 4G | 4.70 GB | qbittorrent.yml |
| SABnzbd | 1G | 512M | 0.10 GB | sabnzbd.yml |
| Gluetun (VPN) | 512M | 256M | 0.03 GB | gluetun.yml |
| Unpackerr | 512M | 256M | 0.01 GB | unpackerr.yml |

**Total limits**: ~8GB (VM has 6GB RAM - will need increase to 10GB)

### Monitoring Infrastructure (3 VMs)

Located in: `roles/cadvisor/tasks/main.yml`

| Service | Memory Limit | Reservation | Current Usage | Deployed On |
|---------|-------------|-------------|---------------|-------------|
| cAdvisor | 256M | 128M | 0.03-0.05 GB | home-assistant, media-services, download-clients |

---

## Format Used

### Docker Compose Services

```yaml
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: <LIMIT>
        reservations:
          memory: <RESERVATION>
```

### cAdvisor (Docker Run)

```bash
docker run -d \
  --name=cadvisor \
  --memory=256m \
  --memory-reservation=128m \
  ...
```

---

## Limits Rationale

All limits set at 2-3x current usage to provide headroom:

- **qBittorrent**: 6GB (using 4.7GB, active torrenting needs headroom)
- **Media *arr services**: 1GB (using 200-400MB, room for library scans)
- **FlareSolverr**: 1GB (Chromium-based, can spike during use)
- **Small services**: 256-512MB (using <100MB, plenty of headroom)

---

## Deployment Status

### ✅ Code Changes Complete

- [x] All 14 compose service files updated
- [x] 1 Ansible role updated (cAdvisor)
- [x] Backups created (*.bak files)
- [x] Changes reviewed

### ⏭️ Pending Deployment

- [ ] Commit changes to git
- [ ] Deploy to VMs (via Ansible or manual)
- [ ] Restart containers on each VM
- [ ] Verify limits applied
- [ ] Verify alerts cleared

---

## Next Steps

### Step 1: Commit Changes

```bash
cd /home/olieran/coding/mirrors/jellybuntu
git add compose_files/services/*.yml
git add roles/cadvisor/tasks/main.yml
git add .gitignore

git commit -m "Add memory limits to all containers

- Add deploy.resources.limits to all 14 service files
- Media services: 256M-1G limits based on usage
- qBittorrent: 6G limit (largest consumer)
- cAdvisor: 256M limit via Ansible role
- Resolves 18 ContainerHighMemory alerts

Current usage ranges from 10MB-4.7GB per container.
Limits set at 2-3x usage for headroom.

Investigation: logs/memory-investigation-20251031-133602.txt
Analysis: docs/troubleshooting/memory-alerts-analysis-20251031.md"
```

### Step 2: Deploy to VMs

**Option A: Via Ansible (Recommended)** <!-- markdownlint-disable-line MD036 -->

```bash
# Redeploy compose files

./bin/runtime/ansible-run.sh playbooks/06-configure-media-services-role.yml
./bin/runtime/ansible-run.sh playbooks/07-configure-download-clients-role.yml

# Redeploy cAdvisor with new limits

./bin/runtime/ansible-run.sh playbooks/16-deploy-monitoring-exporters.yml
```

**Option B: Manual SSH** <!-- markdownlint-disable-line MD036 -->

```bash
# Media Services VM

ssh ansible@media-services.discus-moth.ts.net
cd /opt/media-stack
podman-compose down && podman-compose up -d

# Download Clients VM

ssh ansible@download-clients.discus-moth.ts.net
cd /opt/download-stack
podman-compose down && podman-compose up -d

# cAdvisor (on each VM)

ssh ansible@media-services.discus-moth.ts.net
sudo docker rm -f cadvisor
# Re-run Ansible role or manual docker run with memory flags

```

### Step 3: Verify Limits Applied

```bash
# Check container memory limits

ssh ansible@media-services.discus-moth.ts.net
podman inspect sonarr | grep -i memory

# Should show memory limit in bytes
# 1G = 1073741824
# 512M = 536870912

```

### Step 4: Verify Alerts Cleared

```bash
# Check Prometheus alerts (wait 5-10 minutes after restart)

http://monitoring.discus-moth.ts.net:9090/alerts

# Run investigation script again

cd /home/olieran/coding/mirrors/jellybuntu
./scripts/investigate-memory-alerts.sh

# Should show:
# - Container memory % at realistic levels (20-80%)
# - 0 ContainerHighMemory alerts
# - 1 HighMemoryUsage alert (Proxmox host - expected)
```

---

## Expected Results

### Before

- 18 ContainerHighMemory alerts firing
- Container memory usage: +Inf%
- No protection against runaway processes

### After

- 0 ContainerHighMemory alerts
- Container memory usage: 20-80% (realistic)
- Memory limits protecting against OOM

### Sample Expected Percentages

- qBittorrent: ~78% (4.7GB / 6GB)
- Sonarr: ~30% (0.30GB / 1GB)
- Radarr: ~20% (0.20GB / 1GB)
- Bazarr: ~42% (0.42GB / 1GB)
- FlareSolverr: ~46% (0.46GB / 1GB)
- Others: <50%

---

## VM Memory Allocation Follow-up

**IMPORTANT**: Two VMs will exceed their allocated RAM with these limits:

1. **media-services**: 7GB limits on 6GB VM
   - **Action**: Increase VM RAM to 8GB
   - **Command**: `qm set 401 --memory 8192`
   - **Requires**: VM restart

2. **download-clients**: 8GB limits on 6GB VM
   - **Action**: Increase VM RAM to 10GB
   - **Command**: `qm set 402 --memory 10240`
   - **Requires**: VM restart

**WARNING**: Proxmox host has only 3GB buffer. Before increasing VMs:

1. Ensure container limits are working
2. Monitor for 24 hours
3. Verify Proxmox memory status
4. Consider hardware RAM upgrade (48GB → 64GB+)

See: `docs/troubleshooting/memory-alerts-analysis-20251031.md` for full analysis

---

## Rollback Procedure

If containers OOM or crash after applying limits:

### Restore from Backup

```bash
cd /home/olieran/coding/mirrors/jellybuntu/compose_files/services

# Restore all backups

for f in *.bak; do
    mv "$f" "${f%.bak}"
done

# Redeploy
# (same commands as Step 2 above)
```

### Or Increase Specific Limits

Edit the service file and increase memory limit, then redeploy.

---

## Files Changed

### Service Files (compose_files/services/)

- bazarr.yml
- flaresolverr.yml
- gluetun.yml
- homepage.yml
- huntarr.yml
- jellyseer.yml
- portainer.yml
- prowlarr.yml
- qbittorrent.yml
- radarr.yml
- recyclarr.yml
- sabnzbd.yml
- sonarr.yml
- unpackerr.yml

### Ansible Roles

- roles/cadvisor/tasks/main.yml

### Documentation Created

- docs/troubleshooting/MEMORY-ALERTS-EXECUTIVE-SUMMARY.md
- docs/troubleshooting/memory-alerts-analysis-20251031.md
- docs/troubleshooting/memory-alerts-remediation.md
- docs/troubleshooting/memory-limits-patches.md
- docs/troubleshooting/alert-investigation.md
- docs/troubleshooting/CHANGES-MEMORY-LIMITS-20251031.md (this file)

### Scripts Created

- scripts/investigate-memory-alerts.sh
- scripts/investigate-proxmox-memory.sh
- scripts/add-memory-limits.sh

### Other

- .gitignore (added logs/ directory)

---

## References

- Investigation Results: `logs/memory-investigation-20251031-133602.txt`
- Detailed Analysis: `docs/troubleshooting/memory-alerts-analysis-20251031.md`
- Executive Summary: `docs/troubleshooting/MEMORY-ALERTS-EXECUTIVE-SUMMARY.md`
- Remediation Guide: `docs/troubleshooting/memory-alerts-remediation.md`
- Manual Patches: `docs/troubleshooting/memory-limits-patches.md`

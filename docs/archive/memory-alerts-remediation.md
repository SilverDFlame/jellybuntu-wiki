# Memory Alerts Remediation Guide

**Current Status**: 19 memory alerts firing

- 18x ContainerHighMemory (containers using >90% of memory limits)
- 1x HighMemoryUsage (VM using >85% of available memory)

**Alert Definitions**:

- `ContainerHighMemory`: Container using >90% of its memory limit for 5+ minutes
- `HighMemoryUsage`: VM using >85% of available memory for 10+ minutes

---

## Investigation: Identify Affected Containers and VMs

### Step 1: Find the 18 Containers with High Memory

Run this PromQL query in Prometheus (http://monitoring.discus-moth.ts.net:9090):

```promql
# List all containers over 90% memory usage

(container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100 > 90
```

**Better formatted query**:

```promql
# Show container name, instance, and memory percentage

sort_desc(
  (container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100
)
```

**Get specific details**:

```promql
# Container memory usage with limits

container_memory_usage_bytes{name!=""} / 1024 / 1024 / 1024  # Usage in GB
container_spec_memory_limit_bytes{name!=""} / 1024 / 1024 / 1024  # Limit in GB
```

### Step 2: Find the VM with High Memory

Run this PromQL query:

```promql
# List VMs/hosts over 85% memory usage

(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
```

**Better formatted**:

```promql
# Show instance, memory used %, and actual values

sort_desc(
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
)
```

---

## Investigation Commands (SSH)

### Check Container Memory on Specific VM

```bash
# SSH to the VM (replace with actual hostname)

ssh ansible@<vm-hostname>.discus-moth.ts.net

# Check Docker/Podman container memory usage

podman stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Or if using Docker

docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

### Check VM Memory Usage

```bash
# On the problematic VM

ssh ansible@<vm-hostname>.discus-moth.ts.net

# Check memory usage

free -h

# Check top memory consumers

top -o %MEM -b -n 1 | head -20

# Or use htop for interactive view

htop
```

---

## Common Causes and Remediation

### Cause 1: Container Memory Limits Too Restrictive

**Problem**: Memory limits set too low for normal operation

**How to identify**:

- Container consistently at 90%+ but not crashing
- No memory leak (usage stable over time)
- Application functions normally despite high %

**Fix**: Increase memory limits in docker-compose.yml

Example:

```yaml
services:
  sonarr:
    # ... other config ...
    deploy:
      resources:
        limits:
          memory: 1G  # Increase from 512M to 1G
        reservations:
          memory: 512M
```

**Where to edit**:

- Media services: `/home/ansible/compose_files/docker-compose.yml` on media-services VM
- Download clients: `/home/ansible/compose_files/docker-compose.yml` on download-clients VM
- Home Assistant: Check Home Assistant VM compose files

**After editing, restart containers**:

```bash
cd /home/ansible/compose_files
podman-compose down
podman-compose up -d
```

### Cause 2: Memory Leak in Application

**Problem**: Application gradually consuming more memory over time

**How to identify**:

- Memory usage increasing over hours/days
- Container eventually OOM kills or crashes
- Restarts temporarily fix the issue

**Fix**:

1. **Update the application** (may fix known memory leaks)
2. **Add restart policy** to automatically recover:

```yaml
services:
  service-name:
    restart: unless-stopped
    # OR for scheduled restarts
    deploy:
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
```

1. **Implement scheduled restarts** (temporary workaround):

```bash
# Add to crontab

0 3 * * * cd /home/ansible/compose_files && podman-compose restart service-name
```

### Cause 3: No Memory Limits Set

**Problem**: Containers have no memory limits, triggering false positives

**How to identify**:

```promql
# Check for containers without memory limits

container_spec_memory_limit_bytes{name!=""} == 0
```

**Fix**: Add memory limits to compose file:

```yaml
services:
  service-name:
    deploy:
      resources:
        limits:
          memory: 2G  # Set appropriate limit
        reservations:
          memory: 512M
```

### Cause 4: VM Memory Exhaustion

**Problem**: The host VM itself is running out of memory

**How to identify**:

- High swap usage
- OOM killer logs in `dmesg`
- Multiple services affected

**Fix Options**:

#### Option 1: Increase VM Memory (Recommended)

```bash
# On Proxmox host

ssh root@jellybuntu.discus-moth.ts.net

# Check current memory

qm config <vmid> | grep memory

# Increase memory (example: increase media-services from 6GB to 8GB)

qm set 401 --memory 8192

# Shutdown and restart VM for changes to take effect

qm shutdown 401
qm start 401
```

#### Option 2: Reduce Container Memory Usage

- Stop non-essential containers
- Reduce memory limits on less critical services
- Move services to different VMs

#### Option 3: Add Swap (Not recommended for production)

```bash
# Only as temporary measure

sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## VM Memory Allocation Reference

From your architecture docs (docs/architecture.md):

| VM | VMID | Current RAM | Services |
|----|------|-------------|----------|
| Home Assistant | 100 | 4GB | Home automation |
| Satisfactory | 200 | 6GB | Game server |
| NAS | 300 | 6GB | Btrfs + NFS + AdGuard |
| Jellyfin | 400 | 8GB | Jellyfin + transcoding |
| Media Services | 401 | 6GB | Sonarr, Radarr, Prowlarr, Jellyseerr, Recyclarr |
| Download Clients | 402 | 6GB | qBittorrent, SABnzbd, FlareSolverr |
| Monitoring | 500 | 6GB | Prometheus, Grafana, Uptime Kuma |

**Total Allocated**: 42GB RAM
**Proxmox Host**: Likely 64GB+ physical RAM

---

## Recommended Investigation Workflow

### 1. Identify Specific Containers (5 minutes)

**Option A: Use Investigation Script** (Recommended)

```bash
cd /home/olieran/coding/mirrors/jellybuntu
./scripts/investigate-memory-alerts.sh
```

- Automatically queries Prometheus and saves results to `logs/memory-investigation-<timestamp>.txt`
- Shows output to console and saves to file simultaneously
- Can specify custom output file: `./scripts/investigate-memory-alerts.sh http://prometheus:9090 /path/to/output.txt`

**Option B: Manual Prometheus Query** <!-- markdownlint-disable-line MD036 -->

```bash
# Run in Prometheus UI

(container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100 > 90
```

**Document results**:

- List container names
- List instances (which VM)
- Note current memory usage vs limit

### 2. Identify VM with High Memory (2 minutes)

```bash
# Run in Prometheus UI

(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
```

**Document results**:

- Which VM/host
- Current memory usage %
- Available vs Total memory

### 3. Determine Root Cause (10-15 minutes)

For each affected container/VM:

- Check if memory usage is stable or growing
- Check if memory limits are set
- Check if memory limits are appropriate for the service
- Review recent changes (new services added? configuration changes?)

### 4. Implement Fixes (Varies by solution)

**Quick fixes (5-10 minutes each)**:

- Increase container memory limits (edit compose, restart)
- No limits set → Add appropriate limits

**Medium fixes (15-30 minutes)**:

- Increase VM memory allocation (requires VM restart)
- Move services between VMs

**Longer-term fixes (1+ hours)**:

- Investigate and fix application memory leaks
- Optimize application configurations
- Implement monitoring and alerting thresholds

---

## Expected Outcomes After Remediation

### If Limits Were Too Restrictive

- Alerts clear within 5-10 minutes after increasing limits and restarting
- Services continue operating normally
- Memory usage stabilizes at new, healthy level

### If Memory Leak

- Temporary fix: Restart service → memory drops, alerts clear
- Long-term: Update application or implement scheduled restarts
- Monitor for recurring pattern

### If VM Memory Exhaustion

- After increasing VM RAM: Alerts clear within 10 minutes
- Services become responsive again
- Check for OOM killer activity stops

---

## Verification Queries

After implementing fixes, verify with these queries:

```promql
# Check remaining containers over 90%

count((container_memory_usage_bytes{name!=""} / container_spec_memory_limit_bytes{name!=""}) * 100 > 90)

# Check VMs over 85%

count((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85)

# Total firing memory alerts

count(ALERTS{alertstate="firing", alertname=~".*Memory.*"})
```

---

## Preventive Measures

### 1. Set Appropriate Memory Limits for All Containers

Review and set limits based on actual usage:

```yaml
# Template for all services

services:
  service-name:
    deploy:
      resources:
        limits:
          memory: <peak_usage * 1.5>  # 50% headroom
        reservations:
          memory: <typical_usage>
```

### 2. Configure Grafana Alerts for Early Warning

Add alerts at lower thresholds:

- Containers at 75% memory → Warning
- VMs at 70% memory → Warning
- This gives time to investigate before critical

### 3. Regular Memory Usage Review

Monthly review:

- Check Grafana "Top Memory Consumers" dashboard
- Identify trending increases
- Proactively adjust limits or optimize applications

### 4. Document Memory Baselines

For each service, document:

- Typical memory usage
- Peak memory usage
- Current memory limit
- Last reviewed date

---

## Quick Reference: Memory Limit Recommendations

Based on typical usage for each service:

### Media Services VM

```yaml
sonarr:
  memory: 1G (typically uses 500-800MB)
radarr:
  memory: 1G (typically uses 500-800MB)
prowlarr:
  memory: 512M (typically uses 200-400MB)
jellyseerr:
  memory: 512M (typically uses 200-400MB)
recyclarr:
  memory: 256M (runs periodically)
```

### Download Clients VM

```yaml
qbittorrent:
  memory: 2G (heavy torrenting: 1-1.5GB)
sabnzbd:
  memory: 2G (heavy downloads: 1-1.5GB)
flaresolverr:
  memory: 1G (typically uses 400-700MB)
```

### Monitoring VM

```yaml
prometheus:
  memory: 2G (with 30 day retention)
grafana:
  memory: 1G (typical usage 500-800MB)
uptime-kuma:
  memory: 512M (lightweight)
```

**Note**: These are starting points. Adjust based on actual usage patterns from Grafana.

---

## Next Steps

1. ☐ Run Prometheus queries to identify specific containers and VMs
2. ☐ Document findings in this file
3. ☐ Determine root cause for each alert
4. ☐ Implement appropriate fixes
5. ☐ Verify alerts clear
6. ☐ Document any memory limit changes in service documentation
7. ☐ Set up preventive monitoring and review schedule

---

## References

- Alert Rules: `/home/olieran/coding/mirrors/jellybuntu/compose_files/monitoring/configs/alert_rules.yml`
- Prometheus: http://monitoring.discus-moth.ts.net:9090
- Grafana: http://monitoring.discus-moth.ts.net:3000
- Architecture Docs: `/home/olieran/coding/mirrors/jellybuntu/docs/architecture.md`

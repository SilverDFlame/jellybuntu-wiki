# Memory Alerts Analysis - October 31, 2025

**Investigation File**: `logs/memory-investigation-20251031-133602.txt`

## Executive Summary

**Root Cause**: All 18 containers have NO memory limits configured in docker-compose files, causing Prometheus to report
+Infinity% memory usage and triggering alerts.

**Critical Issue**: Proxmox hypervisor (jellybuntu) at 93% memory usage (47GB total, only 3.3GB available).

**Resolution**: Add memory limits to all containers + investigate Proxmox host memory usage.

---

## Detailed Analysis

### 1. Container Memory Limits Missing

**Problem**: `container_spec_memory_limit_bytes` returns 0 or infinity for all containers.

**Evidence**: Investigation shows "Memory %" as "+Inf%" for all 18 containers, and the "Container Memory Limits" section
is empty.

**Why it triggers alerts**: Prometheus alert rule evaluates:

```promql
(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 90
```

When limit = 0 or ∞, the result is `+Inf`, which is > 90, triggering the alert.

**Impact**: 18 false positive alerts (all containers)

### 2. Actual Container Memory Usage (All Healthy)

| Container | Instance | Usage (GB) | Status |
|-----------|----------|------------|--------|
| qBittorrent | download-clients | 4.70 | ✅ Normal (active torrenting) |
| FlareSolverr | media-services | 0.46 | ✅ Normal (Chromium-based) |
| Bazarr | media-services | 0.42 | ✅ Normal |
| Home Assistant | home-assistant | 0.35 | ✅ Normal |
| Sonarr | media-services | 0.30 | ✅ Normal |
| Jellyseerr | media-services | 0.28 | ✅ Normal |
| Radarr | media-services | 0.20 | ✅ Normal |
| Prowlarr | media-services | 0.20 | ✅ Normal |
| Huntarr | media-services | 0.14 | ✅ Normal |
| Homepage | media-services | 0.10 | ✅ Normal |
| SABnzbd | download-clients | 0.10 | ✅ Normal |
| cAdvisor (3x) | all VMs | ~0.04 each | ✅ Normal (monitoring) |
| Gluetun | download-clients | 0.03 | ✅ Normal (VPN) |
| Portainer | media-services | 0.03 | ✅ Normal |
| Recyclarr | media-services | 0.02 | ✅ Normal (runs periodically) |
| Unpackerr | download-clients | 0.01 | ✅ Normal |

**Total container memory usage across all VMs**: ~7.5 GB

**Conclusion**: All containers are using normal, healthy amounts of memory. No memory leaks detected.

### 3. VM Memory Usage

| VM | Memory % | Total RAM | Available | Status |
|----|----------|-----------|-----------|--------|
| **jellybuntu (Proxmox)** | **93.03%** | **47.13 GB** | **3.28 GB** | 🔴 **CRITICAL** |
| satisfactory-server | 73.75% | 5.79 GB | 1.52 GB | ⚠️ Warning (approaching threshold) |
| media-services | 35.85% | 5.79 GB | 3.71 GB | ✅ Normal |
| home-assistant | 23.43% | 3.82 GB | 2.93 GB | ✅ Normal |
| download-clients | 14.78% | 5.79 GB | 4.93 GB | ✅ Normal |
| jellyfin | 13.24% | 7.76 GB | 6.73 GB | ✅ Normal |
| nas | 12.95% | 5.79 GB | 5.04 GB | ✅ Normal |

**Total VM allocation**: 42 GB (across 6 VMs)
**Proxmox host physical RAM**: 47.13 GB
**Memory overcommitment**: Yes (42GB VMs + ~5GB Proxmox overhead ≈ 47GB)

### 4. Critical: Proxmox Host Memory Exhaustion

**Problem**: The hypervisor itself has only 3.28 GB (7%) available memory.

**Likely causes**:

1. **VM memory overcommitment**: 42GB allocated to VMs + Proxmox overhead ≈ 47GB total
2. **Proxmox caching/buffers**: May be using available RAM for disk cache
3. **Kernel overhead**: Management services, ZFS/Btrfs cache if used
4. **ARC cache**: If using ZFS for VM storage, ARC cache can consume significant memory

**Risks**:

- OOM killer may trigger on Proxmox host
- VM performance degradation (host swapping)
- Potential VM crashes if host runs out of memory

**Immediate investigation needed**:

```bash
ssh root@jellybuntu.discus-moth.ts.net

# Check actual memory usage breakdown

free -h

# Check if swapping is occurring

vmstat 1 5

# Check largest memory consumers

ps aux --sort=-%mem | head -20

# Check if ZFS ARC cache (if applicable)

cat /proc/spl/kstat/zfs/arcstats | grep size
```

---

## Remediation Strategy

### Phase 1: Fix Container Memory Limits (Resolves 18 Alerts)

**Priority**: HIGH
**Time**: 30-60 minutes
**Impact**: Clears all 18 container alerts

#### Recommended Memory Limits by Service

Based on actual usage + 50-100% headroom:

##### Media Services VM (media-services)

```yaml
sonarr: 1GB (using 0.30GB)
radarr: 1GB (using 0.20GB)
prowlarr: 512MB (using 0.20GB)
bazarr: 1GB (using 0.42GB)
jellyseerr: 1GB (using 0.28GB)
flaresolverr: 1GB (using 0.46GB, Chromium-based)
portainer: 256MB (using 0.03GB)
homepage: 512MB (using 0.10GB)
huntarr: 512MB (using 0.14GB)
recyclarr: 256MB (using 0.02GB, runs periodically)
cadvisor: 256MB (using 0.05GB, monitoring)
```

**Total for media-services**: ~7GB limits (currently has 5.79GB total, 3.71GB available)
**Action**: Increase VM RAM from 6GB → 8GB

##### Download Clients VM (download-clients)

```yaml
qbittorrent: 6GB (using 4.70GB, needs headroom for peak activity)
sabnzbd: 1GB (using 0.10GB)
gluetun: 512MB (using 0.03GB, VPN)
unpackerr: 512MB (using 0.01GB)
cadvisor: 256MB (using 0.04GB)
```

**Total for download-clients**: ~8GB limits (currently has 5.79GB total, 4.93GB available)
**Action**: Increase VM RAM from 6GB → 10GB

##### Home Assistant VM (home-assistant)

```yaml
homeassistant: 2GB (using 0.35GB, Home Assistant can grow with integrations)
cadvisor: 256MB (using 0.03GB)
```

**Total for home-assistant**: ~2.25GB limits (currently has 3.82GB total)
**Action**: No change needed

#### Implementation Files

Create docker-compose.yml additions for each VM:

**File locations**:

- Media services: VMs use compose files in `/home/ansible/compose_files/`
- Check actual paths on each VM

**Format**:

```yaml
services:
  service-name:
    # ... existing config ...
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
    # ... rest of config ...
```

### Phase 2: Increase VM Memory Allocations (Resolves Memory Pressure)

**Priority**: HIGH
**Time**: 30 minutes (requires VM restarts)
**Impact**: Prevents future memory exhaustion, clears Host alert

#### Proposed VM Memory Changes

| VM | Current | Proposed | Change | Reason |
|----|---------|----------|--------|--------|
| media-services | 6 GB | 8 GB | +2 GB | Container limits total ~7GB |
| download-clients | 6 GB | 10 GB | +4 GB | qBittorrent needs 6GB + overhead |
| home-assistant | 4 GB | 4 GB | 0 | Sufficient |
| nas | 6 GB | 6 GB | 0 | Sufficient (13% usage) |
| jellyfin | 8 GB | 8 GB | 0 | Sufficient (13% usage) |
| satisfactory-server | 6 GB | 6 GB | 0 | Acceptable at 74% |
| monitoring | 6 GB | 6 GB | 0 | Not running in report? Check if exists |

**New total VM allocation**: 48 GB (up from 42 GB)

**Problem**: Proxmox host only has 47 GB physical RAM!

**Options**:

1. **Add physical RAM to Proxmox host** (RECOMMENDED)
   - Increase from 48GB → 64GB or 96GB
   - Provides headroom for growth

2. **Optimize satisfactory-server** (if not actively used)
   - Reduce from 6GB → 4GB
   - Or shut down when not playing
   - New total: 46GB (fits in 47GB host)

3. **Deploy monitoring stack elsewhere**
   - Check if monitoring VM (500, 6GB) exists
   - If not deployed yet, reconsider location

4. **Enable memory ballooning** (not recommended for production)
   - Allow VMs to share memory dynamically
   - Risk of OOM under load

### Phase 3: Investigate Proxmox Host Memory Usage (Resolves 1 Alert)

**Priority**: CRITICAL
**Time**: 15 minutes investigation
**Impact**: Identifies why host is at 93%

#### Investigation Steps

```bash
# SSH to Proxmox host

ssh root@jellybuntu.discus-moth.ts.net

# 1. Check memory breakdown

free -h
# Expected: Most memory used by VMs, some for cache/buffers

# 2. Check for memory leaks or excessive cache

cat /proc/meminfo | grep -E 'MemTotal|MemFree|MemAvailable|Cached|Buffers|Slab'

# 3. Check largest processes (excluding VMs)

ps aux --sort=-%mem | head -20

# 4. Check if ZFS ARC is consuming memory (if applicable)

cat /proc/spl/kstat/zfs/arcstats 2>/dev/null | grep -E 'size|c_max'

# 5. Check VM actual memory usage vs allocation

qm status 100 --verbose
qm status 200 --verbose
qm status 300 --verbose
qm status 400 --verbose
qm status 401 --verbose
qm status 402 --verbose

# 6. Check for swap usage

swapon --show
vmstat 1 5
```

**Expected findings**:

- ~42GB used by VMs
- ~2-3GB for Proxmox OS and services
- ~2-3GB for filesystem cache (can be freed if needed)
- ~3GB reported as "available"

**If ZFS ARC is large**: Can limit it

```bash
# Check current ARC size

cat /proc/spl/kstat/zfs/arcstats | grep '^size'

# If >5GB, consider limiting it

echo "options zfs zfs_arc_max=2147483648" > /etc/modprobe.d/zfs.conf  # 2GB limit
update-initramfs -u
reboot
```

---

## Implementation Plan

### Step 1: Add Memory Limits to Containers (Immediate)

1. For each VM, update compose files with memory limits
2. Restart containers: `podman-compose down && podman-compose up -d`
3. Verify limits are set:

   ```bash
   podman inspect <container> | grep -i memory
   ```

4. **Result**: All 18 container alerts will clear within 5 minutes

### Step 2: Investigate Proxmox Host (Immediate)

1. Run investigation commands above
2. Identify if memory is truly exhausted or just cached
3. Check if VMs are using all allocated memory or less
4. Determine if host needs more RAM

### Step 3: Increase VM RAM (After investigation)

**If Proxmox has ~10GB truly free** (cache can be freed):

- Proceed with increasing media-services and download-clients

**If Proxmox is actually maxed out**:

- Option A: Add physical RAM to host (best)
- Option B: Optimize VM allocations (reduce satisfactory-server)
- Option C: Defer VM increases, rely on memory limits preventing overuse

Commands to increase VM RAM:

```bash
ssh root@jellybuntu.discus-moth.ts.net

# Increase media-services: 6GB → 8GB

qm set 401 --memory 8192

# Increase download-clients: 6GB → 10GB

qm set 402 --memory 10240

# Shutdown and restart VMs

qm shutdown 401 && qm start 401
qm shutdown 402 && qm start 402
```

### Step 4: Update Alert Thresholds (Optional)

If memory limits are set correctly, consider adjusting alert thresholds:

- ContainerHighMemory: 90% → 85% (earlier warning)
- Add ContainerMemoryCritical at 95%

---

## Expected Results

### After Phase 1 (Memory Limits)

- ✅ 18 ContainerHighMemory alerts cleared
- ✅ Containers can't consume unlimited memory
- ✅ Grafana dashboards show accurate percentages
- ⚠️ 1 HighMemoryUsage alert remains (Proxmox host)

### After Phase 2 (VM RAM Increases)

- ✅ VMs have appropriate headroom
- ✅ Services less likely to OOM
- ⚠️ Proxmox host still at risk if no physical RAM added

### After Phase 3 (Proxmox Investigation)

- ✅ Understanding of actual memory pressure
- ✅ Decision on hardware upgrade vs optimization
- ✅ 1 HighMemoryUsage alert cleared (if memory optimized)

### Final State

- **0 alerts firing** (all resolved)
- **All containers**: Memory limits set appropriately
- **All VMs**: Adequate RAM allocation
- **Proxmox host**: <85% memory usage with headroom

---

## Risk Assessment

### Low Risk (Phase 1 - Memory Limits)

- Adding memory limits may cause containers to OOM if set too low
- Mitigation: Set limits 2x current usage, monitor for 24 hours
- Rollback: Remove limits if issues occur

### Medium Risk (Phase 2 - VM RAM)

- Increasing total VM RAM may exceed Proxmox physical capacity
- Mitigation: Investigate first (Phase 3), add physical RAM if needed
- Rollback: Revert qm set commands and restart VMs

### High Risk (Doing Nothing)

- Proxmox host may OOM, crashing all VMs
- Containers may consume excessive memory, affecting VM stability
- No visibility into container memory pressure

---

## Next Actions

**Immediate (Today)**:

1. ✅ Investigation complete (this document)
2. ⏭️ Run Proxmox host memory investigation
3. ⏭️ Create docker-compose memory limit patches
4. ⏭️ Test memory limits on one VM (home-assistant - least critical)

**Short-term (This Week)**:

1. ⏭️ Roll out memory limits to all VMs
2. ⏭️ Decide on Proxmox RAM upgrade vs optimization
3. ⏭️ Increase VM RAM if Proxmox can support it

**Long-term (This Month)**:

1. ⏭️ Add physical RAM to Proxmox host if needed
2. ⏭️ Set up memory usage trends monitoring in Grafana
3. ⏭️ Document memory baselines for each service

---

## References

- Investigation Results: `logs/memory-investigation-20251031-133602.txt`
- Remediation Guide: `docs/troubleshooting/memory-alerts-remediation.md`
- Architecture Docs: `docs/architecture.md`
- Compose Files: Check each VM at `/home/ansible/compose_files/`

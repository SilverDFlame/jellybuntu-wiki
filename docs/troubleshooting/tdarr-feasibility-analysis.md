# Tdarr Deployment Feasibility Analysis

**Date**: October 31, 2025
**Context**: Memory investigation revealed Proxmox host at 93% usage
**Question**: Can we safely deploy Tdarr without straining the host?

---

## TL;DR: YES, Tdarr is Safe to Deploy

**Key Insight**: Tdarr uses memory **inside the Jellyfin VM**, not additional Proxmox host memory. The host already
allocated 8GB to Jellyfin VM, and Tdarr would just use more of that existing allocation.

---

## Current State Analysis

### Proxmox Host (jellybuntu)

From investigation on Oct 31, 2025:

| Metric | Value | Status |
|--------|-------|--------|
| Total RAM | 47 GB | Fixed (hardware) |
| VMs Allocated | 44 GB | Committed to VMs |
| Actually Used | ~39 GB | 89% of allocated |
| Available Buffer | 3 GB | Low but stable |
| Reclaimable Cache | 0.8 GB | Minimal |
| **Usage** | **93.6%** | ⚠️ Tight but stable |

### Jellyfin VM (Target for Tdarr)

From investigation on Oct 31, 2025:

| Metric | Value | Status |
|--------|-------|--------|
| Allocated RAM | 8 GB | From Proxmox host |
| Actually Used | 1 GB | 13.24% |
| Available | 6.7 GB | Plenty of headroom |
| CPU Cores | 4 | Adequate for transcoding |
| **Headroom** | **6.7 GB free** | ✅ Excellent |

---

## Understanding VM vs Host Memory

**Critical Distinction**:

```text
Proxmox Host Memory Allocation:
┌─────────────────────────────────────┐
│ Proxmox Host: 47 GB Total           │
│                                     │
│  Jellyfin VM: 8 GB (allocated)     │
│  ┌─────────────────────────────┐   │
│  │ Currently Using: 1 GB       │   │
│  │ Available: 6.7 GB           │   │
│  │                             │   │
│  │ [Add Tdarr here: 1-2 GB]   │   │
│  │ Still within 8 GB!          │   │
│  └─────────────────────────────┘   │
│                                     │
│  Other VMs: 36 GB (allocated)      │
│  Proxmox OS: ~3 GB                 │
└─────────────────────────────────────┘
```

**Key Point**: From the Proxmox host's perspective:

- Jellyfin VM has 8GB allocated (already "taken" from the 47GB)
- What happens **inside** that 8GB doesn't change host allocation
- Tdarr using 2GB inside Jellyfin VM = still only 8GB from host
- Host doesn't see "8GB + 2GB Tdarr", it sees "8GB Jellyfin VM"

---

## Tdarr Resource Requirements

### Memory

- **Tdarr Server**: ~500MB-1GB (coordination, database, queue)
- **Tdarr Node (transcoding)**: ~500MB-1.5GB (per active transcode)
- **Total Typical**: 1-2.5GB during active transcoding
- **Peak**: Could spike to 3-4GB during heavy transcoding

### CPU

- **Very CPU-intensive** during transcoding
- Uses all available cores when transcoding
- Jellyfin VM has 4 cores (adequate)
- Nice value can be set to prioritize Jellyfin playback

### Disk I/O

- Reads source media from NFS
- Writes transcoded media to NFS
- Temporary files during processing

---

## Feasibility Assessment

### ✅ **Jellyfin VM Can Handle Tdarr**

| Resource | Available | Tdarr Needs | Headroom | Status |
|----------|-----------|-------------|----------|--------|
| RAM | 6.7 GB | 1-2.5 GB | 4+ GB | ✅ Excellent |
| CPU | 4 cores | Uses all | Can share | ✅ Good |
| Disk | NFS mount | Reads/writes | Shared | ✅ Good |

**Jellyfin VM Memory After Tdarr**:

- Current: 1 GB (Jellyfin only)
- With Tdarr: 3-4 GB (Jellyfin + Tdarr transcoding)
- Remaining: 4-5 GB free
- Usage: ~50% (healthy)

### ✅ **Proxmox Host Won't Be Affected**

**Why it's safe**:

1. **No new VM allocation**: Jellyfin VM already has 8GB from host
2. **No change to host pressure**: 44GB allocated remains 44GB allocated
3. **VM has headroom**: 6.7GB free inside VM is more than enough
4. **Stable baseline**: Jellyfin VM only using 13% currently

**What would strain the host**:

- ❌ Creating a NEW VM (adds to 44GB allocation)
- ❌ Increasing Jellyfin VM RAM (e.g., 8GB → 12GB)
- ❌ Running transcoding on the HOST (not in a VM)

**What won't strain the host**:

- ✅ Running Tdarr INSIDE existing Jellyfin VM
- ✅ Using more of already-allocated VM RAM
- ✅ Jellyfin VM going from 13% → 50% usage

---

## Recommended Deployment Strategy

### Phase 1: Deploy Tdarr with Conservative Limits

**Memory Limits** (Docker Compose):

```yaml
services:
  tdarr-server:
    image: ghcr.io/haveagitgat/tdarr:2.27.01
    container_name: tdarr-server
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M
    # ... rest of config

  tdarr-node:
    image: ghcr.io/haveagitgat/tdarr_node:2.27.01
    container_name: tdarr-node
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 2G  # Can spike during transcoding
        reservations:
          memory: 1G
    # ... rest of config
```

**Total Tdarr Limits**: 3GB (1GB server + 2GB node)

- Jellyfin current: 1GB
- Tdarr limits: 3GB
- Total: 4GB / 8GB = 50% VM usage
- Remaining buffer: 4GB

### Phase 2: Monitor for 48 Hours

**What to monitor**:

1. **Jellyfin VM memory usage**:

   ```bash
   ssh ansible@jellyfin.discus-moth.ts.net "free -h"
   ```

2. **Proxmox host memory** (should be unchanged):

   ```bash
   ssh root@jellybuntu.discus-moth.ts.net "free -h"
   ```

3. **Container memory** (via Prometheus/Grafana):
   - Tdarr containers should stay under limits
   - Jellyfin should remain unaffected

4. **Transcoding performance**:
   - Check transcode speeds
   - Monitor CPU during transcodes
   - Ensure Jellyfin playback not affected

### Phase 3: Optimize Based on Usage

**If Tdarr uses less than expected**:

- Lower memory limits (e.g., 1.5GB total instead of 3GB)
- Free up more room for other services

**If Tdarr needs more**:

- Increase limits (Jellyfin VM has 6.7GB free)
- Consider limiting concurrent transcodes
- Use lower priority (nice value) for transcoding

---

## Risk Assessment

### Low Risk ✅

- **Deploying Tdarr on Jellyfin VM**: VM has 6.7GB free, plenty of headroom
- **Setting conservative memory limits**: Protects VM from runaway processes
- **Monitoring before scaling**: Can back out if issues occur

### Medium Risk ⚠️

- **CPU contention**: Transcoding could slow Jellyfin playback
  - **Mitigation**: Set Tdarr nice value to lower priority
  - **Mitigation**: Limit concurrent transcodes to 1-2
  - **Mitigation**: Schedule transcodes during off-peak hours

### High Risk ❌

- **None identified** for Tdarr deployment on Jellyfin VM with proper limits

### What Would Be High Risk

- ❌ Deploying Tdarr on media-services VM (only 4GB available after container limits)
- ❌ Deploying Tdarr on download-clients VM (constrained by qBittorrent needs)
- ❌ Creating new VM for Tdarr (would increase Proxmox allocation from 44GB → 50GB+)

---

## Alternative Deployment Options

If you're still concerned about resources:

### Option 1: Scheduled Transcoding (Recommended)

- Run Tdarr only during off-peak hours (e.g., 2 AM - 6 AM)
- Use systemd timer to start/stop service
- Zero impact during peak usage times
- Example:

  ```bash
  # Create systemd timer for scheduled transcoding
  # Start transcoding at 2 AM, stop at 6 AM
  # See tdarr.md for timer configuration
  systemctl --user enable tdarr-schedule.timer
  ```

### Option 2: Manual Transcoding

- Keep Tdarr stopped by default
- Start it manually when you want to process media
- Full control over when resources are used
- Example:

  ```bash
  # When you want to transcode
  ssh ansible@jellyfin.discus-moth.ts.net
  systemctl --user start tdarr-server tdarr-node

  # When done
  systemctl --user stop tdarr-server tdarr-node
  ```

### Option 3: Defer Until Hardware Upgrade

- Wait until Proxmox host gets RAM upgrade (48GB → 64GB+)
- Deploy Tdarr on new dedicated VM
- No resource concerns at all
- Timeline: When hardware is replaced

---

## Recommendation: Go For It! ✅

**My recommendation**: Deploy Tdarr on Jellyfin VM with conservative limits.

**Rationale**:

1. **Jellyfin VM has plenty of headroom** (6.7GB free)
2. **No impact on Proxmox host** (uses existing VM allocation)
3. **Easy to monitor and adjust** (memory limits prevent issues)
4. **Easy to remove** (if it doesn't work out)
5. **High value for media workflow** (automated transcoding saves time)

**Deployment plan**:

1. Create Tdarr compose file with 3GB total limits
2. Deploy to Jellyfin VM
3. Monitor for 48 hours
4. Adjust limits based on actual usage
5. Optionally schedule for off-peak hours

**Expected outcome**:

- Jellyfin VM: 13% to 40-50% memory usage
- Proxmox host: 93.6% (unchanged)
- All alerts: 1 (unchanged)
- Benefit: Automated media optimization

---

## Monitoring Queries

After deploying Tdarr, monitor with these Prometheus queries:

```promql
# Jellyfin VM memory usage
(1 - (node_memory_MemAvailable_bytes{instance="jellyfin"} / node_memory_MemTotal_bytes{instance="jellyfin"})) * 100

# Tdarr container memory usage
container_memory_usage_bytes{name=~"tdarr.*"} / container_spec_memory_limit_bytes{name=~"tdarr.*"} * 100

# Proxmox host memory (should be unchanged)
(1 - (node_memory_MemAvailable_bytes{instance="jellybuntu"} / node_memory_MemTotal_bytes{instance="jellybuntu"})) * 100
```

Or run the investigation script:

```bash
./scripts/investigate-memory-alerts.sh
```

---

## Conclusion

**Tdarr is safe to deploy** on your current infrastructure. The Jellyfin VM has 6.7GB of available RAM, and Tdarr will
only use 1-2.5GB of that existing allocation. The Proxmox host won't see any increase in memory pressure because the
VM's 8GB is already allocated.

The main consideration is CPU usage during transcoding, which can be managed with:

- Nice value settings (lower priority)
- Concurrent transcode limits
- Off-peak scheduling

**Green light to proceed!** 🟢

---

## References

- Memory Investigation: `logs/memory-investigation-20251031-142302.txt`
- Proxmox Analysis: `docs/troubleshooting/memory-alerts-analysis-20251031.md`
- Plan B Services: `docs/plans/plan-b-recommended-services.md`

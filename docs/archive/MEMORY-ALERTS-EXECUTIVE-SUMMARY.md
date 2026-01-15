# Memory Alerts Investigation - Executive Summary

**Date**: October 31, 2025
**Alert Count**: 19 firing alerts
**Investigation File**: `logs/memory-investigation-20251031-133602.txt`

---

## 🎯 Quick Summary

**Root Cause**: No memory limits configured on any Docker containers (18 containers) + Proxmox hypervisor at 93% memory
usage (1 VM/host).

**Impact**: False positive alerts for all containers + real risk of hypervisor OOM.

**Fix Time**: 1-2 hours total

**Risk Level**:

- Container limits: LOW (quick fix, low risk)
- Proxmox memory: HIGH (needs investigation)

---

## 📊 What We Found

### 18 Container Alerts (False Positives)

All containers show `+Inf%` memory usage because **no memory limits are set**. Actual memory usage is healthy:

- qBittorrent: 4.7 GB (largest, normal for active torrenting)
- Most services: 100-400 MB (normal)
- Total across all containers: ~7.5 GB

### 1 Host Alert (CRITICAL)

Proxmox hypervisor (jellybuntu) at **93% memory usage**:

- Total: 47.13 GB
- Available: 3.28 GB (only 7% free)
- Risk: OOM killer may crash VMs

---

## ✅ Solution Path

### Phase 1: Fix Container Limits (30-60 min) - IMMEDIATE

**What**: Add memory limits to all 18 containers
**How**: Run automated script or manual patches
**Result**: All 18 container alerts cleared

```bash
cd /home/olieran/coding/mirrors/jellybuntu

# Option A: Automated (recommended)

./scripts/add-memory-limits.sh --backup

# Option B: Manual patches
# See: docs/troubleshooting/memory-limits-patches.md
```

**Recommended Limits**:

- qBittorrent: 6GB
- Sonarr/Radarr/Bazarr/Jellyseerr: 1GB each
- Prowlarr/FlareSolverr/SABnzbd: 512MB-1GB
- Home Assistant: 2GB
- cAdvisor/Portainer/small services: 256MB

### Phase 2: Investigate Proxmox Memory (15 min) - URGENT

**What**: Determine why hypervisor is at 93%
**How**: SSH to Proxmox and run diagnostics

```bash
ssh root@jellybuntu.discus-moth.ts.net

# Check memory breakdown

free -h

# Check largest processes

ps aux --sort=-%mem | head -20

# Check if ZFS ARC cache (if applicable)

cat /proc/spl/kstat/zfs/arcstats 2>/dev/null | grep -E 'size|c_max'
```

**Likely causes**:

1. VM overcommitment (42GB VMs + 5GB Proxmox ≈ 47GB total)
2. Filesystem cache (can be freed if needed)
3. ZFS ARC cache (if using ZFS storage)

### Phase 3: Resolve Proxmox Memory (Varies)

**Option A**: Memory is cached (best case - 5 min)

- Most memory is filesystem cache
- Can be freed automatically under pressure
- No action needed

**Option B**: VMs need more RAM (1 hour)

- Increase media-services: 6GB → 8GB
- Increase download-clients: 6GB → 10GB
- **Problem**: Total = 48GB, host only has 47GB
- **Solution**: Add physical RAM to host OR reduce other VMs

**Option C**: Add physical RAM (hardware upgrade)

- Upgrade Proxmox from 48GB → 64GB or 96GB
- Best long-term solution
- Provides headroom for growth

---

## 📁 Documentation Created

| File | Purpose |
|------|---------|
| `logs/memory-investigation-20251031-133602.txt` | Investigation results |
| `docs/troubleshooting/memory-alerts-analysis-20251031.md` | **Detailed analysis (READ THIS)** |
| `docs/troubleshooting/memory-limits-patches.md` | **Manual patches for all services** |
| `docs/troubleshooting/memory-alerts-remediation.md` | General remediation guide |
| `scripts/add-memory-limits.sh` | **Automated fix script** |

---

## 🚀 Immediate Next Steps

### Step 1: Investigate Proxmox (5-15 minutes)

```bash
ssh root@jellybuntu.discus-moth.ts.net
free -h
ps aux --sort=-%mem | head -20
```

**Decision point**: Is memory truly exhausted or just cached?

### Step 2A: If Proxmox Memory is Cached (Quick Path)

```bash
# Memory is available, just used for cache
# Proceed directly to adding container limits

cd /home/olieran/coding/mirrors/jellybuntu
./scripts/add-memory-limits.sh --backup --dry-run  # Preview
./scripts/add-memory-limits.sh --backup            # Apply

# Deploy to VMs (via Ansible or manually SSH to each)
# Then restart containers on each VM
```

### Step 2B: If Proxmox Memory is Truly Exhausted (Longer Path)

1. Add container limits (same as above)
2. Decide: Add physical RAM OR reduce VM allocations
3. If reducing VMs: Lower satisfactory-server from 6GB → 4GB
4. If adding RAM: Order and install hardware upgrade

### Step 3: Verify Fixes (10 minutes)

```bash
# Check Prometheus alerts (should clear within 5-10 min)
# http://monitoring.discus-moth.ts.net:9090/alerts

# Check Grafana dashboard
# http://monitoring.discus-moth.ts.net:3000

# Run investigation script again to compare

cd /home/olieran/coding/mirrors/jellybuntu
./scripts/investigate-memory-alerts.sh
```

---

## 📊 Expected Results

### After Phase 1 (Container Limits)

- ✅ 18 ContainerHighMemory alerts cleared
- ✅ Containers show realistic percentages (20-80%)
- ⚠️ 1 HighMemoryUsage alert remains (Proxmox)

### After Phase 2 (Proxmox Investigation)

- ✅ Understanding of memory pressure
- ✅ Clear action plan for resolution

### After Phase 3 (Proxmox Resolution)

- ✅ All 19 alerts cleared
- ✅ System stable with headroom
- ✅ No risk of OOM

---

## ⚠️ Risks & Mitigations

### Adding Memory Limits

**Risk**: Containers may OOM if limits too low
**Mitigation**: Limits set 2-3x current usage
**Rollback**: Remove limits or increase them

### Increasing VM RAM

**Risk**: May exceed Proxmox capacity
**Mitigation**: Investigate first (Phase 2)
**Rollback**: Reduce back to original values

### Doing Nothing

**Risk**: Proxmox may OOM, crashing all VMs
**Impact**: Complete infrastructure outage
**Timeline**: Could happen any time under load

---

## 📞 Decision Needed

**Question**: Does Proxmox truly need more physical RAM, or is memory usage acceptable?

**To Answer**: Run Phase 2 investigation commands above.

**Typical answers**:

- "Most memory is cache, 10+GB truly available" → Quick fix path
- "VMs using all allocated RAM, host at limit" → Need hardware upgrade
- "One VM is leaking memory" → Investigate that VM specifically

---

## 🎓 Key Takeaways

1. **Container limits are essential** - Without them, no control over resource usage
2. **Monitoring is working** - Alerts caught real issues
3. **Host memory is critical** - Hypervisor OOM affects all VMs
4. **Fix is straightforward** - Well-defined steps with low risk
5. **Documentation matters** - Having detailed guides accelerates resolution

---

## 📚 For More Details

- **Detailed analysis**: `docs/troubleshooting/memory-alerts-analysis-20251031.md`
- **Step-by-step patches**: `docs/troubleshooting/memory-limits-patches.md`
- **General remediation**: `docs/troubleshooting/memory-alerts-remediation.md`

---

## ✨ TL;DR

1. **Add memory limits** to all containers (run script, deploy, restart)
2. **Check Proxmox memory** (SSH and run `free -h`)
3. **Decide on RAM upgrade** (if needed) or optimize allocations
4. **Verify alerts clear** (Prometheus + Grafana)
5. **Done** - System stable with proper resource controls

**Estimated total time**: 1-2 hours
**Difficulty**: Low-Medium
**Risk**: Low (with proper backups)
**Impact**: High (19 alerts resolved)

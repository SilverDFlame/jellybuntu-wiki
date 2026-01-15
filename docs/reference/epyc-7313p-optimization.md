# AMD EPYC 7313P Optimization Guide

Comprehensive guide to optimizing the AMD EPYC 7313P processor for the Jellybuntu homelab infrastructure,
covering BIOS configuration, CPU topology, huge pages, and performance tuning.

---

## Overview

The AMD EPYC 7313P is a single-socket "Milan" (Zen 3) processor optimized for cost-effective, high-performance
server workloads. This guide documents the architecture specifics and recommended optimizations for
the Jellybuntu infrastructure.

**Key Specifications:**

| Attribute | Value |
|-----------|-------|
| Architecture | AMD Zen 3 (Milan) |
| Cores / Threads | 16 / 32 |
| Base Clock | 3.0 GHz |
| Boost Clock | 3.7 GHz |
| L3 Cache | 128 MB (32 MB per CCD) |
| Memory Channels | 8 (DDR4-3200) |
| TDP | 155W |
| Socket | SP3 (single-socket only) |

**Jellybuntu Configuration:**

- 128 GB ECC DDR4 RAM
- GTX 1080 GPU (passthrough to Jellyfin)
- 32 GB RAM disk for transcoding
- Proxmox VE hypervisor

---

## CPU Architecture

### CCD (Core Complex Die) Topology

The EPYC 7313P contains **4 CCDs**, each with 4 cores sharing a 32 MB L3 cache:

```text
┌──────────────────────────────────────────────────────────────┐
│                     AMD EPYC 7313P                           │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                    │
│  │     CCD 0       │  │     CCD 1       │                    │
│  │  Cores 0-3      │  │  Cores 4-7      │                    │
│  │  L3: 32 MB      │  │  L3: 32 MB      │                    │
│  └─────────────────┘  └─────────────────┘                    │
│                                                              │
│  ┌─────────────────┐  ┌─────────────────┐                    │
│  │     CCD 2       │  │     CCD 3       │                    │
│  │  Cores 8-11     │  │  Cores 12-15    │                    │
│  │  L3: 32 MB      │  │  L3: 32 MB      │                    │
│  └─────────────────┘  └─────────────────┘                    │
│                                                              │
│             I/O Die (IOD) - Memory Controllers               │
│                   8 DDR4 Channels                            │
└──────────────────────────────────────────────────────────────┘
```

**Implications for VM placement:**

- Cores 0-3 share L3 cache (CCD 0) - optimal for one 4-core workload
- Cores 4-7 share L3 cache (CCD 1) - optimal for one 4-core workload
- Cores 8-11 share L3 cache (CCD 2) - optimal for one 4-core workload
- Cores 12-15 share L3 cache (CCD 3) - optimal for one 4-core workload

### NUMA Configuration

The EPYC 7313P supports **NPS (Nodes Per Socket)** BIOS settings that control NUMA topology:

| Setting | NUMA Nodes | Memory Interleaving | Use Case |
|---------|------------|---------------------|----------|
| **NPS1** | 1 | 8 channels | General workloads (recommended) |
| NPS2 | 2 | 4 channels each | Specific NUMA-aware applications |
| NPS4 | 4 | 2 channels each | HPC with NUMA affinity |

**Recommendation: NPS1** for homelab mixed workloads.

With NPS1, all 16 cores and 128 GB RAM appear as a single NUMA domain, and memory is interleaved across
all 8 channels for maximum bandwidth. This simplifies VM placement and avoids NUMA-related performance
penalties for non-NUMA-aware applications.

---

## BIOS Configuration Checklist

### Required Settings

| Setting | Path (typical) | Recommended | Notes |
|---------|----------------|-------------|-------|
| **IOMMU** | AMD CBS > NBIO > IOMMU | Enabled | Required for GPU passthrough |
| **ACS Enable** | AMD CBS > NBIO > PCIe ACS Override | Enable | IOMMU group separation |
| **SMT** | AMD CBS > CPU > SMT Mode | Enabled | 32 threads vs 16 |
| **NPS** | AMD CBS > DF > Memory Addressing > NUMA nodes per socket | NPS1 | Single NUMA domain |
| **SVM** | AMD CBS > CPU > SVM Mode | Enabled | Hardware virtualization |

### Performance Settings

| Setting | Path (typical) | Recommended | Notes |
|---------|----------------|-------------|-------|
| **Determinism Mode** | AMD CBS > CPU > Determinism Slider | Performance | vs Power (default) |
| **Core Performance Boost** | AMD CBS > CPU > Core Performance Boost | Enabled | Allows boost to 3.7 GHz |
| **Global C-state Control** | AMD CBS > CPU > Global C-state Control | Auto or Disabled | Disable for lowest latency |
| **Power Supply Idle Control** | AMD CBS > NBIO > Power Supply Idle Control | Typical | vs Low Current |

### Memory Settings

| Setting | Path (typical) | Recommended | Notes |
|---------|----------------|-------------|-------|
| **Memory Interleaving** | AMD CBS > UMC > Memory Interleaving | Auto (channel) | 8-channel interleaving |
| **TSME** | AMD CBS > UMC > TSME | Disabled | Unless encryption needed |
| **Bank Group Swap** | AMD CBS > UMC > Bank Group Swap | Auto | Memory performance |

### Verification After BIOS Changes

After configuring BIOS settings, verify from Linux:

```bash
# Check IOMMU is enabled
dmesg | grep -i iommu
# Expected: "AMD-Vi: IOMMU enabled" or similar

# Check SMT is enabled (32 threads)
lscpu | grep "Thread(s) per core"
# Expected: Thread(s) per core: 2

# Check NUMA topology
numactl -H
# Expected (NPS1): available: 1 nodes (0)

# Check total threads
nproc
# Expected: 32

# Check boost frequency capability
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
# Expected: ~3700000 (3.7 GHz)
```

---

## Jellybuntu CPU Allocation Strategy

### Current Allocation

The 16 physical cores (32 threads) are allocated as follows:

| CCD | Cores | Threads | Allocation | VM/Purpose |
|-----|-------|---------|------------|------------|
| CCD 0 | 0-3 | 0-7 | Reserved | Future Minecraft server |
| CCD 1 | 4-7 | 8-15 | **Pinned** | Satisfactory game server |
| CCD 2 | 8-11 | 16-23 | Shared pool | All other VMs |
| CCD 3 | 12-15 | 24-31 | Shared pool | All other VMs |

### Pinned vs Shared Workloads

**Pinned workloads** (dedicated cores):

- Satisfactory game server (cores 4-7) - latency-sensitive, bursty
- Future Minecraft server (cores 0-3) - when deployed

**Shared pool** (cores 8-15):

- All other VMs share this pool via `cpu_units` priority scheduling
- Proxmox's CFS scheduler distributes CPU time based on priority weights

### Why CCD-Aware Pinning Matters

Keeping a workload's cores within the same CCD provides:

1. **L3 Cache Locality**: All 4 cores share 32 MB L3 cache
2. **Reduced Inter-CCD Traffic**: No cache coherency overhead between CCDs
3. **Predictable Latency**: Consistent memory access patterns

**Game Server Example:**

Satisfactory benefits from cores 4-7 (all on CCD 1):

- Game tick processing shares data in L3
- No cross-CCD cache invalidation
- Consistent frame times

### Future Optimization: Jellyfin Pinning

If Jellyfin transcoding latency becomes problematic, consider pinning to CCD 2:

```bash
# Post-deployment affinity (requires root)
qm set 400 -affinity 8-11
```

This would dedicate CCD 2's cores and L3 cache to transcoding workloads.

---

## Huge Pages Configuration

### What Are Huge Pages?

Standard memory pages are 4 KB. Huge pages are 2 MB (or 1 GB). Benefits:

- **Reduced TLB misses**: Fewer page table entries to manage
- **Lower latency**: Direct memory access without page walk
- **Better for large allocations**: Transcoding buffers, VM memory

### Recommended Configuration

For Jellyfin/Tdarr transcoding workloads, allocate **8 GB of 2 MB huge pages**:

```bash
# Proxmox host configuration
# /etc/sysctl.d/99-hugepages.conf
vm.nr_hugepages = 4096    # 4096 x 2 MB = 8 GB
```

Or via GRUB for boot-time allocation:

```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt hugepagesz=2M hugepages=4096"
```

### Verification

```bash
# Check huge pages allocation
cat /proc/meminfo | grep -i huge
# Expected output:
# HugePages_Total:    4096
# HugePages_Free:     4096  (before VM start)
# Hugepagesize:       2048 kB

# Check huge pages are available to VMs
ls -la /dev/hugepages/
```

### When to Skip Huge Pages

Huge pages are **not recommended** when:

- Running many small VMs (memory fragmentation)
- Memory overcommitment is desired (huge pages are reserved)
- Workloads don't benefit (small allocations, random access)

---

## Performance Monitoring

### Key Metrics to Track

**CPU metrics:**

```bash
# Real-time CPU frequency per core
watch -n 1 "cat /proc/cpuinfo | grep 'cpu MHz'"

# CPU governor status
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# VM CPU usage breakdown
qm monitor <vmid> info cpus
```

**Memory metrics:**

```bash
# NUMA statistics
numastat

# Memory bandwidth (if perf installed)
perf stat -e memory-loads,memory-stores sleep 5

# Huge pages usage
cat /proc/meminfo | grep Huge
```

**Per-VM metrics:**

```bash
# CPU affinity verification
qm config <vmid> | grep affinity

# CPU usage for specific VM
qm monitor <vmid> info cpus
```

### Prometheus Integration

The `node_exporter` on each VM exposes CPU metrics:

```promql
# CPU frequency scaling
node_cpu_scaling_frequency_hertz

# CPU time by mode
rate(node_cpu_seconds_total[5m])

# Memory bandwidth (if available)
node_memory_Bandwidth_bytes
```

---

## Diagnostic Playbook

Run the diagnostic playbook to capture the actual topology from your system:

```bash
./bin/runtime/ansible-run.sh playbooks/utility/diagnose-proxmox-host.yml
```

This playbook gathers:

- lscpu output
- NUMA topology (numactl -H)
- IOMMU groups
- Huge pages status
- VM CPU allocation summary
- Memory configuration

Use the output to verify BIOS settings match expectations and to populate documentation.

---

## Troubleshooting

### Issue: Only 16 Threads Visible

**Symptom:** `nproc` returns 16 instead of 32.

**Cause:** SMT (Simultaneous Multi-Threading) disabled in BIOS.

**Solution:**

1. Access BIOS: AMD CBS > CPU > SMT Mode
2. Set to **Enabled**
3. Reboot and verify: `lscpu | grep "Thread(s) per core"`

### Issue: Poor Game Server Performance

**Symptom:** Satisfactory frame drops despite CPU pinning.

**Possible Causes:**

1. **Cross-CCD pinning**: Verify cores 4-7 are on same CCD
2. **Frequency scaling**: Check governor is "performance"
3. **IRQ affinity**: Network interrupts on pinned cores

**Diagnosis:**

```bash
# Verify pinning is within CCD
lscpu -p | grep "^[4-7],"

# Check CPU governor
cat /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor

# Check IRQ affinity
cat /proc/interrupts | grep -E "eth|ens" | head -5
```

### Issue: NUMA Memory Penalty

**Symptom:** Higher than expected memory latency.

**Cause:** NPS2 or NPS4 enabled, workloads spanning NUMA nodes.

**Solution:**

1. Verify NPS setting in BIOS: AMD CBS > DF > Memory Addressing
2. Set to **NPS1** for single NUMA domain
3. Reboot and verify: `numactl -H` shows 1 node

### Issue: Huge Pages Not Allocated

**Symptom:** `HugePages_Total: 0` in `/proc/meminfo`.

**Cause:** Memory fragmentation at boot, or sysctl not applied.

**Solution:**

1. Add to GRUB for boot-time allocation:

   ```bash
   GRUB_CMDLINE_LINUX_DEFAULT="... hugepagesz=2M hugepages=4096"
   update-grub
   reboot
   ```

2. Or reboot with less memory pressure, then:

   ```bash
   echo 4096 > /proc/sys/vm/nr_hugepages
   ```

---

## References

### External Documentation

- [AMD EPYC 7003 Series Tuning Guide](https://developer.amd.com/resources/epyc-resources/epyc-tuning-guides/)
- [NUMA Configuration for EPYC 2nd Gen (Dell)](https://infohub.delltechnologies.com/p/numa-configuration-settings-on-amd-epyc-2nd-generation/)
- [Supermicro H12SSL NUMA Topology](https://metebalci.com/blog/supermicro-h12ssl-numa/)
- [Proxmox GPU Passthrough](https://pve.proxmox.com/wiki/PCI_Passthrough)

### Jellybuntu Documentation

- [Architecture Overview](../architecture.md) - VM layout and resource allocation
- [GPU Passthrough Configuration](../configuration/gpu-passthrough.md) - IOMMU and VFIO setup
- [Resource Allocation Guide](../configuration/resource-allocation.md) - CPU allocation strategy
- [Memory Tuning Reference](memory-tuning.md) - Container memory configuration

---

## Maintenance Schedule

**Monthly:**

- Check CPU frequency scaling is active (`watch cat /proc/cpuinfo | grep MHz`)
- Review VM CPU usage in Grafana/Prometheus
- Verify huge pages allocation if enabled

**Quarterly:**

- Run diagnostic playbook to capture current state
- Compare against documented topology
- Review any new BIOS updates from motherboard vendor

**After BIOS Updates:**

- Re-verify all settings in BIOS checklist
- Run diagnostic playbook
- Test GPU passthrough and VM performance

---

**Last Updated:** January 2026
**Based on:** AMD EPYC 7313P in Jellybuntu Proxmox host

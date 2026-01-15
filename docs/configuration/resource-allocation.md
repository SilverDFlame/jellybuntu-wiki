# Resource Allocation

Guide to CPU, memory, and disk allocation strategies including overprovisioning, priorities, and performance optimization.

> **Note:** This document contains some legacy hardware references. For current hardware specifications,
> see [Architecture Overview](../architecture.md). For EPYC 7313P-specific tuning, see
> [EPYC 7313P Optimization](../reference/epyc-7313p-optimization.md).

## Overview

The Jellybuntu infrastructure uses intelligent resource allocation to maximize hardware utilization while maintaining
performance for critical services.

**Current Hardware**: AMD EPYC 7313P (16 cores / 32 threads), 128GB ECC RAM, GTX 1080 GPU
**VMs**: 8 VMs with varied resource allocation (see [Architecture](../architecture.md) for details)

## Resource Allocation Strategy

### Philosophy

**Overprovisioning**: Allocate more virtual resources than physical capacity
**Rationale**: Most workloads are bursty, not sustained
**Safety**: Priority system ensures critical services get resources when needed

### Key Principles

1. **Priority-Based**: High-priority VMs get CPU time first
2. **Bursty Workloads**: Peak usage rarely coincides across all VMs
3. **Quality of Service**: cpu_units controls relative CPU share
4. **Monitoring**: Watch actual usage to adjust allocations

## CPU Allocation

### Total CPU Resources

| Resource         | Count | Notes                                                  |
|------------------|-------|--------------------------------------------------------|
| Physical Cores   | 8     | Intel Xeon X5570 @ 2.93GHz                             |
| Virtual Cores    | 18    | 225% of physical (125% overprovisioned)                |
| Overprovisioning | 125%  | Safe for bursty workloads (monitoring VM adds 4 cores) |

### Per-VM CPU Allocation

| VM               | vCPU   | Physical % | cpu_units | Priority | CPU Features         |
|------------------|--------|------------|-----------|----------|----------------------|
| Home Assistant   | 2      | 25%        | 512       | Low      | Standard             |
| Satisfactory     | 2      | 25%        | 2048      | High     | **Pinned 2-3**       |
| NAS              | 2      | 25%        | 1024      | Medium   | Standard             |
| Jellyfin         | 4      | 50%        | 2048      | High     | Performance governor |
| Media Services   | 2      | 25%        | 512       | Low      | Standard             |
| Download Clients | 2      | 25%        | 1024      | Medium   | Standard             |
| Monitoring       | 4      | 50%        | 1024      | Medium   | Standard (optional)  |
| **Total**        | **18** | **225%**   |           |          |                      |

### CPU Priority (cpu_units)

**cpu_units** controls relative CPU share when contention occurs:

**Formula**: Higher cpu_units = more CPU time under load

**Tiers**:

- **2048 (High)**: Jellyfin, Satisfactory - Get CPU when needed
- **1024 (Medium)**: NAS, Download Clients - Moderate priority
- **512 (Low)**: Home Assistant, Media Services - Background tasks

**Example**: Under full load:

- Jellyfin (2048) gets 4x more CPU than Home Assistant (512)
- Satisfactory (2048) guaranteed performance even under load

**Configuration** ([`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml)):

```yaml
vms:
  jellyfin:
    cores: 4
    cpu_type: "host"
    cpu_units: 2048  # High priority
```

### CPU Pinning (Satisfactory)

**Purpose**: Dedicate physical cores for latency-sensitive workload

**Configuration**:

```yaml
vms:
  satisfactory-server:
    cores: 2
    cpu_type: "host"
    cpulimit: 2
    cpuunits: 2048
    affinity: "2,3"  # Physical cores 2 and 3
```

**Benefits**:

- Guaranteed CPU availability
- No context switching
- Consistent low latency
- Predictable performance

**Trade-off**: These cores less available for other VMs

**Verification**:

```bash
ssh root@jellybuntu.discus-moth.ts.net "qm config 200 | grep cpu"
```

### CPU Governor (Jellyfin)

**Purpose**: Maximize transcoding performance

**Configuration** (in [`roles/jellyfin/tasks/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/jellyfin/tasks/main.yml)):

```yaml
- name: Set CPU governor to performance
  shell: |
    echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Effect**:

- CPU runs at maximum frequency
- No power saving (reduced latency)
- Better transcoding performance

**Trade-off**: Higher power consumption

## Memory Allocation

### Total Memory Resources

| Resource      | Amount | Notes               |
|---------------|--------|---------------------|
| Physical RAM  | 48GB   | Total host RAM      |
| Allocated RAM | 42GB   | 87.5% allocation    |
| Reserved      | 6GB    | For host + overhead |

### Per-VM Memory Allocation

| VM               | RAM      | % of Physical | Justification                   |
|------------------|----------|---------------|---------------------------------|
| Home Assistant   | 4GB      | 8%            | Light workload                  |
| Satisfactory     | 6GB      | 13%           | Game server                     |
| NAS              | 6GB      | 13%           | Btrfs + NFS cache               |
| Jellyfin         | 8GB      | 17%           | 4K transcoding                  |
| Media Services   | 6GB      | 13%           | Multiple containers             |
| Download Clients | 6GB      | 13%           | Download queues                 |
| Monitoring       | 6GB      | 13%           | Prometheus + Grafana (optional) |
| **Total**        | **42GB** | **87.5%**     |                                 |
| **Host**         | **6GB**  | **12.5%**     | OS + overhead                   |

### Memory Overcommitment

**Strategy**: No memory overcommitment (conservative)

**Rationale**:

- Memory is not burstable like CPU
- Overcommitting causes swapping (slow)
- 75% allocation leaves headroom

**Ballooning**: Not used (VMs get fixed allocation)

### Memory Tuning

**Jellyfin** - Increase if transcoding multiple 4K streams:

```yaml
memory: 12288  # 12GB instead of 8GB
```

**Media Services** - Increase if running many containers:

```yaml
memory: 8192  # 8GB instead of 6GB
```

**Monitoring**:

```bash
# Check memory usage
ssh ansible@jellyfin.discus-moth.ts.net "free -h"

# Top processes
ssh ansible@jellyfin.discus-moth.ts.net "top -o %MEM"
```

## Disk Allocation

### Storage Strategy

**VM Disks**: Local-LVM on Proxmox
**Media/Downloads**: NFS from Btrfs NAS

### Per-VM Disk Allocation

| VM               | Boot Disk | Data Mount    | Purpose            |
|------------------|-----------|---------------|--------------------|
| Home Assistant   | 40GB      | -             | Config + database  |
| Satisfactory     | 60GB      | -             | Game files         |
| NAS              | 10GB      | 2x500GB RAID1 | Btrfs storage pool |
| Jellyfin         | 80GB      | NFS           | Cache + transcode  |
| Media Services   | 50GB      | NFS           | Config + metadata  |
| Download Clients | 60GB      | NFS           | Temporary download |

### NAS Storage Pool

**Configuration**:

- **Type**: Btrfs RAID1
- **Devices**: 2x 500GB (passthrough)
- **Usable**: ~500GB (mirrored)
- **Mount**: `/mnt/storage`

**Benefits**:

- Data redundancy (RAID1)
- Snapshots
- Compression
- Online resizing

### NFS Mounts

**NFS Export**: `nas:/mnt/storage/data`
**Mount Point**: `/mnt/data` (on client VMs)

**Usage**:

- Media files (TV, movies)
- Download staging
- Shared configuration

**Performance**:

- 1Gbps network (sufficient for streaming)
- Local caching on clients
- NFS v4 (better performance)

## Resource Monitoring

### Proxmox Web UI

**Access**: https://jellybuntu.discus-moth.ts.net:8006

**Metrics Available**:

- CPU usage per VM
- Memory usage per VM
- Disk I/O
- Network traffic

### Command Line Monitoring

**Host level**:

```bash
ssh root@jellybuntu.discus-moth.ts.net

# Overall resource usage
htop

# Per-VM CPU usage
qm status <vmid>

# Disk usage
pvesm status
```

**VM level**:

```bash
ssh ansible@jellyfin.discus-moth.ts.net

# CPU and memory
htop

# Disk usage
df -h

# Network
iftop  # Requires installation
```

### Key Metrics to Watch

**CPU**:

- **Load average**: Should be < number of cores
- **Context switches**: High = overprovisioned
- **Wait time (wa)**: High = I/O bottleneck

**Memory**:

- **Used**: Should be < 90%
- **Swap**: Should be near 0 (bad if used heavily)
- **Cache**: Will use available RAM (normal)

**Disk**:

- **I/O wait**: High = slow storage
- **Queue depth**: High = bottleneck
- **Space**: Keep below 80% full

**Network**:

- **Bandwidth**: Should be < 1Gbps
- **Packet loss**: Should be 0
- **Latency**: Should be < 5ms locally

## Performance Optimization

### CPU Optimization

**Jellyfin Transcoding**:

```yaml
# Increase CPU allocation if transcoding multiple streams
vms:
  jellyfin:
    cores: 6  # Up from 4
    cpu_units: 2048
```

**Media Services**:

```yaml
# If media scans slow
vms:
  media-services:
    cpu_units: 1024  # Up from 512
```

### Memory Optimization

**Jellyfin Cache**:

```bash
# Increase if transcoding stutters
# Edit Jellyfin settings: Dashboard → Playback → Transcoding
# Increase transcoding thread count
```

**Docker Memory Limits**:

```yaml
# In compose files
services:
  sonarr:
    mem_limit: 2g  # Limit container memory
```

### Disk I/O Optimization

**NFS Performance**:

```yaml
# In /etc/fstab on client VMs
nas:/mnt/storage/data /mnt/data nfs4 rw,hard,intr,rsize=1048576,wsize=1048576 0 0
```

**Btrfs Compression**:

```bash
# Enable on NAS
ssh ansible@nas.discus-moth.ts.net
sudo btrfs property set /mnt/storage compression zstd
```

### Network Optimization

**Jumbo Frames** (if network supports):

```bash
# On all VMs
sudo ip link set eth0 mtu 9000
```

**QoS** (on router if needed):

- Priority: Jellyfin streaming
- Medium: Media management
- Low: Downloads

## Scaling Strategies

### Vertical Scaling (Current VM)

**When**: Current VM hits resource limits

**CPU**:

```yaml
# Increase cores
vms:
  jellyfin:
    cores: 6  # Up from 4
```

**Memory**:

```yaml
# Increase RAM
vms:
  jellyfin:
    memory: 12288  # Up from 8192
```

**Limitations**: Total host resources

### Horizontal Scaling (Add VMs)

**When**: Vertical scaling insufficient

**Examples**:

- Separate Sonarr and Radarr to different VMs
- Dedicated transcoding VM
- Load-balanced Jellyfin instances

### Hardware Upgrades

**Priority Order**:

1. **RAM**: Most impactful for multiple VMs
2. **Storage**: NVMe for faster I/O
3. **CPU**: More cores for more VMs
4. **Network**: 10Gbps for high-bandwidth

## Troubleshooting Performance

### High CPU Usage

**Symptoms**: Slow response, high load average

**Diagnosis**:

```bash
# Check per-process CPU
htop

# Check load average
uptime

# Check which VM is using CPU
ssh root@jellybuntu.discus-moth.ts.net "qm monitor <vmid>"
```

**Solutions**:

- Increase cpu_units for affected VM
- Reduce overprovisioning
- Add more physical cores

### High Memory Usage

**Symptoms**: Swapping, OOM kills

**Diagnosis**:

```bash
# Check memory
free -h

# Check swap usage
swapon --show

# Check OOM events
dmesg | grep oom
```

**Solutions**:

- Increase VM memory allocation
- Reduce number of services
- Add physical RAM

### Disk I/O Bottleneck

**Symptoms**: High I/O wait, slow file operations

**Diagnosis**:

```bash
# Check I/O wait
iostat -x 1

# Check disk usage
iotop  # Requires installation
```

**Solutions**:

- Upgrade to SSD/NVMe
- Reduce concurrent I/O operations
- Enable Btrfs compression
- Increase NFS cache

### Network Bottleneck

**Symptoms**: Slow transfers, buffering

**Diagnosis**:

```bash
# Check bandwidth
iftop

# Test throughput
iperf3 -c nas.discus-moth.ts.net
```

**Solutions**:

- Upgrade to 10Gbps network
- Reduce concurrent transfers
- Enable jumbo frames
- QoS on router

## Configuration Files

### VM Resource Configuration

**File**: [`playbooks/vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/vars.yml)

```yaml
vms:
  jellyfin:
    cores: 4
    cpu_type: "host"
    cpu_units: 2048
    memory: 8192
    disk_size: "80G"
    network: "virtio,bridge=vmbr0"
```

### Jellyfin Optimizations

**File**: [`roles/jellyfin/tasks/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/jellyfin/tasks/main.yml)

```yaml
- name: Set CPU governor
  shell: echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

- name: Set process priority
  lineinfile:
    path: /etc/systemd/system/jellyfin.service.d/override.conf
    line: "Nice=-10"
```

### NFS Configuration

**Server** (`/etc/exports` on NAS):

```text
/mnt/storage/data 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)
```

**Client** (`/etc/fstab` on VMs):

```text
nas:/mnt/storage/data /mnt/data nfs4 rw,hard,intr 0 0
```

## Best Practices

### ✅ Resource Allocation

- **Plan for growth**: Leave 20-25% headroom
- **Monitor regularly**: Watch for resource exhaustion
- **Burst capacity**: Overprovisioning works for bursty workloads
- **Priority matters**: Use cpu_units effectively

### ✅ Performance

- **CPU pinning**: Only for latency-sensitive workloads
- **Memory**: Never overcommit significantly
- **Storage**: Use fast storage for VMs, NFS for media
- **Network**: Keep sufficient bandwidth

### ✅ Monitoring

- **Regular checks**: Review Proxmox metrics weekly
- **Alerting**: Set up alerts for high usage (if needed)
- **Baselines**: Know normal usage patterns
- **Trends**: Watch for gradual increases

### ⚠️ Avoid

- **Excessive overprovisioning**: > 100% CPU overprovisioning risky
- **Memory overcommit**: Leads to swapping and performance issues
- **Ignoring metrics**: Monitor before problems occur
- **Random allocation**: Plan resources based on workload

## Reference

- [Architecture Overview](../architecture.md) - Infrastructure design
- [VM Specifications](../reference/vm-specifications.md) - Detailed VM specs
- [Proxmox Documentation](https://pve.proxmox.com/wiki/Main_Page) - Official docs
- [Btrfs Wiki](https://btrfs.wiki.kernel.org/) - Filesystem details

## Summary

**CPU Strategy**:

- 75% overprovisioning (14 vCPU on 8 physical)
- Priority system (cpu_units) for resource contention
- CPU pinning for Satisfactory (dedicated cores 2-3)
- Performance governor for Jellyfin

**Memory Strategy**:

- High allocation 87.5% (42GB of 48GB, 6GB includes monitoring VM)
- No overcommitment (fixed allocations)
- Adequate per-VM allocation based on workload

**Storage Strategy**:

- Local disks for VMs (fast access)
- NFS for shared media (centralized)
- Btrfs RAID1 for redundancy

**Monitoring**:

- Proxmox UI for overview
- Per-VM metrics via SSH
- Regular capacity planning

Your resource allocation balances performance, efficiency, and reliability!

---

## See Also

- [Architecture Overview](../architecture.md) - Current VM layout and resource summary
- [EPYC 7313P Optimization](../reference/epyc-7313p-optimization.md) - CPU tuning and BIOS settings
- [Memory Tuning Reference](../reference/memory-tuning.md) - Container memory configuration
- [VM Specifications](../reference/vm-specifications.md) - Detailed per-VM specifications

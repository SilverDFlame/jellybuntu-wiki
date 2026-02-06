# Container Memory Tuning Reference

Comprehensive guide to container memory configuration, limits, and best practices based on operational
experience with the Jellybuntu infrastructure.

---

## Overview

Proper memory limit configuration is essential for container stability and monitoring accuracy. This guide
documents best practices, tuning recommendations, and lessons learned from production operations.

**Key Principles:**

- Always set explicit memory limits for containers
- Size limits at 2-3x typical usage for headroom
- Monitor actual usage patterns over time
- Adjust limits based on workload characteristics
- Consider VM-level resource constraints

---

## Quick Reference: Recommended Memory Limits

Based on measured production usage patterns:

### Media Management Services

| Service     | Limit | Reservation | Typical Usage | Workload Characteristics           |
|-------------|-------|-------------|---------------|------------------------------------|
| Sonarr      | 1GB   | 512MB       | 300-500MB     | Spikes during library scans        |
| Radarr      | 1GB   | 512MB       | 200-400MB     | Spikes during library scans        |
| Prowlarr    | 512MB | 256MB       | 200-300MB     | Stable, indexer searches           |
| Bazarr      | 1GB   | 512MB       | 400-600MB     | Subtitle processing spikes         |
| Jellyseerr  | 1GB   | 512MB       | 250-400MB     | Web UI, moderate usage             |
| Recyclarr   | 256MB | 128MB       | 20-50MB       | Periodic runs, mostly idle         |

### Download Services

| Service     | Limit | Reservation | Typical Usage | Workload Characteristics           |
|-------------|-------|-------------|---------------|------------------------------------|
| qBittorrent | 6GB   | 4GB         | 4-5GB         | Scales with active torrents        |
| SABnzbd     | 1GB   | 512MB       | 100-500MB     | Spikes during extraction           |
| Gluetun     | 512MB | 256MB       | 30-100MB      | VPN tunnel, stable                 |
| Unpackerr   | 512MB | 256MB       | 10-50MB       | Spikes during extraction           |

### Supporting Services

| Service      | Limit | Reservation | Typical Usage | Workload Characteristics           |
|--------------|-------|-------------|---------------|------------------------------------|
| Byparr       | 1.5GB | 768MB       | 300-600MB     | Camoufox (Firefox-based)           |
| Homarr       | 256MB | 128MB       | 50-150MB      | Dashboard, lightweight             |
| Huntarr      | 512MB | 256MB       | 100-200MB     | Periodic processing                |
| cAdvisor     | 256MB | 128MB       | 30-50MB       | Monitoring, stable                 |

### Home Automation

| Service        | Limit | Reservation | Typical Usage | Workload Characteristics           |
|----------------|-------|-------------|---------------|------------------------------------|
| Home Assistant | 2GB   | 1GB         | 300-800MB     | Grows with integrations            |

---

## Understanding Memory Limits

### Podman Quadlet Format

```ini
[Container]
ContainerName=service-name
Image=example/service:latest

# Resource limits via PodmanArgs
PodmanArgs=--memory 1g
PodmanArgs=--memory-reservation 512m
```

### Limit vs Reservation

- **Limit**: Hard maximum - container will be OOM-killed if exceeded
- **Reservation**: Soft minimum - guarantees this amount if available
- **Best practice**: Set limit at 2-3x reservation for burst capacity

### Common Memory Sizes

```text
256M  = 268,435,456 bytes  (268 MB)
512M  = 536,870,912 bytes  (536 MB)
1G    = 1,073,741,824 bytes (1 GB)
2G    = 2,147,483,648 bytes (2 GB)
6G    = 6,442,450,944 bytes (6 GB)
```

---

## Best Practices by Service Type

### Media *arr Applications (Sonarr, Radarr, etc.)

**Characteristics:**

- Steady baseline usage (200-500MB)
- Spikes during library scans
- Database operations can increase memory

**Recommended Configuration:**

```yaml
deploy:
  resources:
    limits:
      memory: 1G
    reservations:
      memory: 512M
```

**Tuning Guidance:**

- Start with 1GB limit for typical installations
- Monitor during full library scans
- Increase to 2GB if managing 10,000+ items
- Consider database optimization if consistently high

### Download Clients (qBittorrent, SABnzbd)

**Characteristics:**

- Memory usage scales with active downloads
- qBittorrent: ~1MB per active torrent
- SABnzbd: Spikes during extraction/verification

**Recommended Configuration (qBittorrent):**

```yaml
deploy:
  resources:
    limits:
      memory: 6G
    reservations:
      memory: 4G
```

**Tuning Guidance:**

- qBittorrent: 2GB base + 1GB per 1000 active torrents
- SABnzbd: 1GB typically sufficient
- Monitor during peak download times
- Consider limiting concurrent downloads if memory-constrained

### Browser-Based Services (Byparr)

**Characteristics:**

- Uses Camoufox (Firefox-based) browser for challenge solving
- Lower baseline than Chrome-based alternatives
- Spikes when solving captchas
- Memory grows with browser instances

**Recommended Configuration:**

```yaml
deploy:
  resources:
    limits:
      memory: 1.5G
    reservations:
      memory: 768M
```

**Tuning Guidance:**

- 768MB reservation for Camoufox overhead
- 1.5GB limit recommended for production
- Monitor for memory leaks (restart periodically if needed)
- Consider session limits to control browser instances

### Lightweight Services (Homarr, cAdvisor)

**Characteristics:**

- Stable, predictable memory usage
- Minimal processing overhead
- Web UI or monitoring focused

**Recommended Configuration:**

```yaml
deploy:
  resources:
    limits:
      memory: 256M
    reservations:
      memory: 128M
```

**Tuning Guidance:**

- 256MB sufficient for most lightweight services
- Rarely need adjustment
- Good candidates for tight limits

---

## VM-Level Resource Planning

### Calculating Total VM Memory

When sizing VM memory allocations, consider:

1. **Sum of container limits** (not reservations)
2. **OS overhead** (~500MB-1GB for base system)
3. **File cache** (~10-20% for performance)
4. **Headroom** (~10% buffer)

**Example Calculation (Media Services VM):**

```text
Container Limits:
  Sonarr:       1GB
  Radarr:       1GB
  Prowlarr:     512MB
  Bazarr:       1GB
  Jellyseerr:   1GB
  Byparr:       1.5GB
  Homarr:       256MB
  cAdvisor:     256MB
  Huntarr:      512MB
  Recyclarr:    256MB
  ------------
  Total:        ~7GB

OS Overhead:    1GB
File Cache:     1GB (15%)
Headroom:       700MB (10%)
  ------------
Recommended:    10GB VM RAM
```

### VM Memory Allocation Guidelines

| VM Purpose         | Base RAM | Per Container | Recommended Total |
|--------------------|----------|---------------|-------------------|
| Media Services     | 2GB      | Sum + 30%     | 8-10GB            |
| Download Clients   | 2GB      | Sum + 30%     | 10-12GB           |
| Home Automation    | 2GB      | Sum + 50%     | 4-6GB             |
| Monitoring Stack   | 2GB      | Sum + 40%     | 6-8GB             |

---

## Monitoring and Alert Configuration

### Prometheus Metrics

**Key Metrics:**

```promql
# Container memory usage percentage
(container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100

# Containers without memory limits (should be zero)
container_spec_memory_limit_bytes{name!=""} == 0

# VM memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Top memory consumers
topk(10, container_memory_usage_bytes{name!=""})
```

### Recommended Alert Thresholds

```yaml
# Container memory alerts
- alert: ContainerHighMemory
  expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 85
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Container {{ $labels.name }} high memory usage"

- alert: ContainerCriticalMemory
  expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 95
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Container {{ $labels.name }} critical memory usage"

# VM/Host memory alerts
- alert: HighMemoryUsage
  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Host {{ $labels.instance }} high memory usage"
```

### Grafana Dashboards

**Recommended Panels:**

1. **Container Memory Usage %** - Gauge panel showing current percentage
2. **Memory Usage Over Time** - Time series of actual usage
3. **Top Memory Consumers** - Bar graph of highest usage
4. **Memory Limit Compliance** - Table showing containers without limits

---

## Troubleshooting

### Symptom: Container Showing +Inf% Memory Usage

**Cause:** No memory limit configured

**Solution:**

```yaml
# Add to service configuration
deploy:
  resources:
    limits:
      memory: <appropriate-size>
```

**Verification:**

```bash
# Check container memory limit
podman inspect <container-name> | grep -i memory

# Should show non-zero value
"Memory": 1073741824  # 1GB in bytes
```

### Symptom: Container Frequently OOM Killed

**Cause:** Memory limit too restrictive for workload

**Diagnosis:**

```bash
# Check container logs for OOM
podman logs <container-name> | grep -i "out of memory\|oom\|killed"

# Check host dmesg
dmesg | grep -i oom | tail -20

# Monitor actual usage patterns
podman stats --no-stream <container-name>
```

**Solution:**

1. Increase memory limit by 50-100%
2. Monitor for 24-48 hours
3. Adjust further if needed
4. Consider application-level optimization

### Symptom: VM Memory Exhaustion

**Cause:** Sum of container limits exceeds VM allocation

**Diagnosis:**

```bash
# On VM - check memory pressure
free -h

# Check swap usage
swapon --show
vmstat 1 5

# List container limits
podman inspect $(podman ps -q) | grep -i "\"Memory\":" | sort -n
```

**Solution:**

1. Calculate sum of container limits
2. Compare to VM available memory
3. Either increase VM RAM or reduce container limits
4. Consider moving services to different VMs

### Symptom: Memory Leak Suspected

**Indicators:**

- Memory usage slowly increasing over days
- Restarts temporarily fix the issue
- No correlation with workload

**Investigation:**

```bash
# Monitor memory over time
podman stats <container-name>

# Check application logs for errors
podman logs <container-name> --since 24h | grep -i "error\|warning\|leak"

# Compare memory usage before/after restart
podman restart <container-name>
sleep 60
podman stats --no-stream <container-name>
```

**Solutions:**

1. **Update application** - May fix known memory leaks
2. **Scheduled restarts** - Temporary workaround:

   ```bash
   # Add to crontab
   0 3 * * 0 cd /opt/services && podman-compose restart <service>
   ```

3. **Application tuning** - Adjust cache sizes, worker counts, etc.
4. **Report upstream** - If leak confirmed, report to project maintainers

---

## Historical Context: October 2025 Incident

### Summary

On October 31, 2025, the monitoring system detected 19 memory-related alerts:

- 18 ContainerHighMemory alerts (all containers)
- 1 HighMemoryUsage alert (Proxmox hypervisor)

### Root Cause

**Container Alerts:** All 18 containers had NO memory limits configured in docker-compose files.
Without limits, Prometheus calculated memory usage as `usage / 0 = +Infinity%`, triggering all alerts.

**Host Alert:** Proxmox hypervisor at 93% memory usage (47GB total, only 3.3GB available) due to:

- 42GB allocated across 6 VMs
- 5GB Proxmox OS overhead
- Memory overcommitment with no headroom

### Resolution

1. **Added memory limits** to all 18 containers based on measured usage
2. **Increased VM allocations** for media-services and download-clients
3. **Documented** best practices in this guide

### Lessons Learned

1. **Always set explicit memory limits** - Enables proper monitoring and prevents runaway processes
2. **Size limits generously** - 2-3x typical usage prevents false OOM situations
3. **Plan VM resources carefully** - Sum of limits + OS overhead must fit in VM RAM
4. **Monitor hypervisor memory** - VM overcommitment can crash entire host
5. **Test limits under load** - Library scans, downloads, etc. create temporary spikes

### Reference Documents

The incident generated several troubleshooting documents (now archived):

- [`memory-alerts-analysis-20251031.md`](../archive/memory-alerts-analysis-20251031.md) - Detailed investigation
- [`MEMORY-ALERTS-EXECUTIVE-SUMMARY.md`](../archive/MEMORY-ALERTS-EXECUTIVE-SUMMARY.md) - Executive overview
- [`memory-alerts-remediation.md`](../archive/memory-alerts-remediation.md) - General remediation steps
- [`memory-limits-patches.md`](../archive/memory-limits-patches.md) - Service-specific patches
- [`CHANGES-MEMORY-LIMITS-20251031.md`](../archive/CHANGES-MEMORY-LIMITS-20251031.md) - Implementation log

**Note:** These files remain available for historical reference but this guide now serves as the
primary reference for memory tuning.

---

## Implementation Workflow

### For New Services

1. **Deploy without limits initially** (testing only)
2. **Monitor for 24-48 hours** to establish baseline
3. **Calculate limit** = peak usage × 2.5
4. **Set reservation** = typical usage × 1.5
5. **Apply configuration**
6. **Monitor for OOM** over next week
7. **Adjust if needed**

### For Existing Services

1. **Check current limits**:

   ```bash
   podman inspect <container> | grep "Memory"
   ```

2. **Review actual usage** over 30 days in Grafana
3. **Calculate new limits** if current too tight or too loose
4. **Update docker-compose.yml**
5. **Restart container**:

   ```bash
   cd /opt/services
   podman-compose restart <service>
   ```

6. **Verify new limits**:

   ```bash
   podman inspect <container> | grep "Memory"
   ```

### Deployment Checklist

- [ ] Memory limits set for all containers
- [ ] Limits validated against actual usage patterns
- [ ] VM RAM allocation adequate for sum of limits
- [ ] Prometheus alerts configured
- [ ] Grafana dashboard created
- [ ] Baseline usage documented
- [ ] Tested under load (if applicable)

---

## Tools and Scripts

### Checking Container Memory Limits

```bash
#!/bin/bash
# check-memory-limits.sh - Verify all containers have limits set

echo "Container Memory Limits:"
echo "======================="

for container in $(podman ps --format "{{.Names}}"); do
    limit=$(podman inspect "$container" | jq -r '.[0].HostConfig.Memory')

    if [ "$limit" -eq 0 ]; then
        echo "❌ $container: NO LIMIT SET"
    else
        limit_gb=$(echo "scale=2; $limit / 1024 / 1024 / 1024" | bc)
        echo "✅ $container: ${limit_gb}GB"
    fi
done
```

### Monitoring Memory Usage

```bash
#!/bin/bash
# monitor-memory.sh - Watch container memory usage

watch -n 5 'podman stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" | sort -k3 -hr'
```

### Calculating VM Memory Requirements

```bash
#!/bin/bash
# calculate-vm-memory.sh - Sum container limits for VM sizing

total=0

for container in $(podman ps --format "{{.Names}}"); do
    limit=$(podman inspect "$container" | jq -r '.[0].HostConfig.Memory')

    if [ "$limit" -gt 0 ]; then
        total=$((total + limit))
        limit_gb=$(echo "scale=2; $limit / 1024 / 1024 / 1024" | bc)
        echo "$container: ${limit_gb}GB"
    fi
done

total_gb=$(echo "scale=2; $total / 1024 / 1024 / 1024" | bc)
os_overhead=1
recommended=$(echo "$total_gb + $os_overhead + ($total_gb * 0.3)" | bc)

echo ""
echo "Total Container Limits: ${total_gb}GB"
echo "OS Overhead (est):      ${os_overhead}GB"
echo "Recommended VM RAM:     ${recommended}GB"
```

---

## Related Documentation

- [Architecture Overview](../architecture.md) - VM specifications and resource allocations
- [Service Endpoints](../configuration/service-endpoints.md) - Service details and access
- [Troubleshooting Guide](../troubleshooting/common-issues.md) - General issue resolution
- [Monitoring Stack Setup](../configuration/monitoring-stack-setup.md) - Monitoring and alerting setup

---

## Maintenance Schedule

**Monthly:**

- Review container memory usage trends in Grafana
- Identify containers consistently above 80% usage
- Adjust limits as needed based on growth

**Quarterly:**

- Audit all containers for memory limit configuration
- Review VM memory allocations
- Update this guide with new service recommendations

**Annually:**

- Comprehensive review of all memory configurations
- Update baseline measurements
- Consider infrastructure scaling needs

---

**Last Updated:** December 2025
**Based on Operational Data From:** October 2025 - Present

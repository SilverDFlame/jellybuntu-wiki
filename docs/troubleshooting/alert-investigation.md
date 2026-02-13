# Alert Investigation Guide - 19 Firing Alerts

**Date**: 2025-10-31
**Dashboard**: Jellybuntu Infrastructure Overview
**Prometheus**: http://monitoring.discus-moth.ts.net:9090
**Grafana**: http://monitoring.discus-moth.ts.net:3000

**UPDATE**: Investigation revealed all 19 alerts are **memory-related**:

- 18x ContainerHighMemory (containers using >90% of memory limits)
- 1x HighMemoryUsage (VM using >85% of available memory)

**See detailed remediation guide**: [`memory-alerts-remediation.md`](../archive/memory-alerts-remediation.md)

---

## Original Investigation (Archived)

The following investigation suspected configuration gaps, but monitoring infrastructure is working correctly. SNMP
metrics are being collected successfully from both Mikrotik devices. All alerts are legitimate resource warnings.

## Quick Investigation

### Step 1: Check Prometheus Targets

Visit http://monitoring.discus-moth.ts.net:9090/targets to see which scrape targets are UP/DOWN.

**Expected targets:**

- `prometheus` (1 target) - self-monitoring
- `proxmox-host` (1 target) - jellybuntu hypervisor
- `vm-nodes` (6 targets) - All guest VMs
- `podman-containers` (3 targets) - cAdvisor on VMs with Podman
- `snmp-mikrotik` (2 targets) - Router and switch
- `blackbox-dns` (4 targets) - DNS server checks
- `blackbox-http-external` (3 targets) - Internet connectivity
- `blackbox-http` (9 targets) - Service endpoint checks

**Total expected**: 29 targets

### Step 2: Check Firing Alerts

Visit http://monitoring.discus-moth.ts.net:9090/alerts to see which specific alerts are firing.

### Step 3: Run These PromQL Queries

In Prometheus (http://monitoring.discus-moth.ts.net:9090/graph), run these queries:

```promql
# Count targets by job and status

count by (job) (up)

# Show all DOWN targets

up == 0

# Count firing alerts by severity

count by (severity) (ALERTS{alertstate="firing"})

# List all firing alert names

ALERTS{alertstate="firing"}

# Check if cAdvisor is running

up{job="podman-containers"}

# Check if SNMP exporters are working

up{job="snmp-mikrotik"}

# Check blackbox HTTP probes

probe_success{job="blackbox-http"}

# Check blackbox DNS probes

probe_success{job="blackbox-dns"}
```

## Identified Configuration Gaps

### Gap 1: cAdvisor Not Deployed (HIGH PRIORITY)

**Problem**: Prometheus expects cAdvisor on port 8180 for container metrics, but it's not installed.

**Affected VMs**:

- home-assistant (192.168.20.10:8180)
- media-services (192.168.30.13:8180)
- download-clients (192.168.30.14:8180)

**Alerts Firing** (3-6 alerts):

- `ContainerDown`
- `ContainerHighCPU`
- `ContainerHighMemory`
- Plus alerts about "Unhealthy Containers" panel showing no data

**Fix**:
Deploy cAdvisor on each VM:

```yaml
# Add to compose files on each VM
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    ports:
      - "8180:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
```

**For rootless Podman** (used in Jellybuntu):

```bash
# Deploy cAdvisor as a systemd service instead

sudo podman run -d \
  --name=cadvisor \
  --restart=unless-stopped \
  --privileged \
  -p 8180:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/containers:/var/lib/containers:ro \
  gcr.io/cadvisor/cadvisor:latest
```

### Gap 2: SNMP Not Configured on Mikrotik Devices (MEDIUM PRIORITY)

**Problem**: SNMP exporter is deployed but Mikrotik devices don't have SNMP enabled or accessible.

**Affected Devices**:

- Mikrotik Router (192.168.10.1)
- Mikrotik Switch (192.168.10.2)

**Alerts Firing** (2 alerts):

- `NetworkDeviceDown` (2 instances - one per device)

**Fix**:

1. Enable SNMPv3 on Mikrotik router:

```mikrotik
# Via Mikrotik CLI or WebFig

/snmp community
set public disabled=no

# Or set up SNMPv3 (more secure)

/snmp
set enabled=yes
```

1. Test from monitoring VM:

```bash
ssh ansible@monitoring.discus-moth.ts.net
snmpwalk -v2c -c public 192.168.10.1 sysDescr
```

1. Update SNMP exporter config if needed:

Check `/home/olieran/coding/mirrors/jellybuntu/compose_files/monitoring/services/exporters/snmp/snmp.yml`

### Gap 3: Orphaned ICMP Alert Rule (LOW PRIORITY)

**Problem**: Alert rule references `job="blackbox-icmp"` but ICMP probes were intentionally removed (rootless Podman
can't grant NET_RAW capability).

**Alert Rule**: `InternetConnectivityLost` (alert_rules.yml:204-211)

**Current Rule**:

```yaml
- alert: InternetConnectivityLost
  expr: probe_success{job="blackbox-icmp", service=~"google-dns|cloudflare-dns"} == 0
  for: 3m
  labels:
    severity: critical
  annotations:
    summary: "Internet connectivity lost"
    description: "Cannot reach {{ $labels.service }} ({{ $labels.instance }}) via ICMP for more than 3 minutes. Internet connection may be down."
```

**Fix**:

Option 1: **Remove the alert** (recommended since ICMP is disabled):

```yaml
# Delete lines 204-211 in alert_rules.yml

```

Option 2: **Change to use DNS checks** (already have DNS probes configured):

```yaml
- alert: InternetConnectivityLost
  expr: probe_success{job="blackbox-dns", service=~"google-dns|cloudflare-dns"} == 0
  for: 3m
  labels:
    severity: critical
  annotations:
    summary: "Internet connectivity lost"
    description: "Cannot reach {{ $labels.service }} via DNS for more than 3 minutes. Internet connection may be down."
```

Option 3: **Use external HTTP checks** (also already configured):

```yaml
- alert: InternetConnectivityLost
  expr: min(probe_success{job="blackbox-http-external"}) == 0
  for: 3m
  labels:
    severity: critical
  annotations:
    summary: "Internet connectivity lost"
    description: "Cannot reach external HTTP endpoints. Internet connection may be down."
```

### Gap 4: Possible Missing Node Exporters (CHECK FIRST)

**Problem**: If any VMs don't have node_exporter installed, `HostDown` alerts will fire.

**How to Check**:

```bash
# Test each VM

for vm in jellybuntu home-assistant satisfactory-server nas jellyfin media-services download-clients; do
  echo "Testing $vm..."
  curl -s http://${vm}.discus-moth.ts.net:9100/metrics | head -n 1 || echo "FAILED: $vm"
done
```

**Expected**: All should return metrics starting with `# HELP`

**Fix if missing**:

```bash
# Install node_exporter on the problematic VM

sudo apt-get update
sudo apt-get install -y prometheus-node-exporter
sudo systemctl enable --now prometheus-node-exporter
```

### Gap 5: Service HTTP Endpoints Down (VERIFY)

**Problem**: Some of the 9 monitored services might actually be down or unreachable from the monitoring VM.

**Services monitored**:

1. Jellyfin (http://jellyfin.discus-moth.ts.net:8096)
2. Sonarr (http://media-services.discus-moth.ts.net:8989)
3. Radarr (http://media-services.discus-moth.ts.net:7878)
4. Prowlarr (http://media-services.discus-moth.ts.net:9696)
5. Jellyseerr (http://media-services.discus-moth.ts.net:5055)
6. qBittorrent (http://download-clients.discus-moth.ts.net:8080)
7. SABnzbd (http://download-clients.discus-moth.ts.net:8081)
8. Home Assistant (http://home-assistant.discus-moth.ts.net:8123)
9. AdGuard Home (http://nas.discus-moth.ts.net:80)

**How to Check**:

```bash
# From monitoring VM

ssh ansible@monitoring.discus-moth.ts.net

# Test each service

for svc in \
  "http://jellyfin.discus-moth.ts.net:8096" \
  "http://media-services.discus-moth.ts.net:8989" \
  "http://media-services.discus-moth.ts.net:7878" \
  "http://media-services.discus-moth.ts.net:9696" \
  "http://media-services.discus-moth.ts.net:5055" \
  "http://download-clients.discus-moth.ts.net:8080" \
  "http://download-clients.discus-moth.ts.net:8081" \
  "http://home-assistant.discus-moth.ts.net:8123" \
  "http://nas.discus-moth.ts.net:80"; do
  echo "Testing $svc..."
  curl -s -o /dev/null -w "%{http_code}\n" "$svc" || echo "FAILED"
done
```

## Remediation Priority

### Phase 1: Quick Wins (Fix ~10 alerts)

1. **Fix ICMP alert rule** (1 alert) - 5 minutes
   - Remove or modify the `InternetConnectivityLost` alert rule
   - Reload Prometheus config: `curl -X POST http://monitoring.discus-moth.ts.net:9090/-/reload`

2. **Verify node_exporters** (0-7 alerts) - 10 minutes
   - Run the check script above
   - Install on any missing VMs

### Phase 2: Deploy cAdvisor (Fix ~6 alerts)

1. **Deploy cAdvisor on VMs with Docker** - 30 minutes
   - Create Ansible role or deploy manually
   - Deploy on: home-assistant, media-services, download-clients
   - Test: `curl http://home-assistant.discus-moth.ts.net:8180/metrics`

### Phase 3: Network Infrastructure (Fix ~2 alerts)

1. **Enable SNMP on Mikrotik devices** - 15 minutes
   - Configure SNMPv3 on router and switch
   - Test connectivity from monitoring VM

## Expected Result

After completing all phases:

- **Before**: 19 alerts firing
- **After Phase 1**: ~8-9 alerts firing
- **After Phase 2**: ~2-4 alerts firing
- **After Phase 3**: 0-2 alerts firing (only legitimate warnings)

## Verification Commands

### Check Prometheus Configuration Reload

```bash
# After editing alert_rules.yml

curl -X POST http://monitoring.discus-moth.ts.net:9090/-/reload

# Verify config is valid

curl http://monitoring.discus-moth.ts.net:9090/api/v1/status/config | jq .
```

### Check Alert Status

```bash
# Get all firing alerts

curl -s http://monitoring.discus-moth.ts.net:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing") | {alertname: .labels.alertname, instance: .labels.instance, severity: .labels.severity}'
```

### Check Target Status

```bash
# Get targets that are DOWN

curl -s http://monitoring.discus-moth.ts.net:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health=="down") | {job: .labels.job, instance: .labels.instance}'
```

## Next Steps

1. **Immediate**: Run Step 1 and Step 2 to confirm which specific alerts are firing
2. **Document findings**: Update this file with actual alert names and instances
3. **Execute remediation**: Follow priority order above
4. **Verify**: Re-check alert count after each phase

## References

- Alert Rules: `/home/olieran/coding/mirrors/jellybuntu/compose_files/monitoring/configs/alert_rules.yml`
- Prometheus Config: `/home/olieran/coding/mirrors/jellybuntu/compose_files/monitoring/configs/prometheus.yml`
- Monitoring Stack: `http://monitoring.discus-moth.ts.net:9090`
- Grafana Dashboard: `http://monitoring.discus-moth.ts.net:3000`

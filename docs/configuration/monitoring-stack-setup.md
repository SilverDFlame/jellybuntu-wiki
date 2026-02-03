# Monitoring Stack Setup Guide

Comprehensive guide for configuring Prometheus, Grafana, and the monitoring infrastructure.

## Access

- **Prometheus**: http://monitoring.discus-moth.ts.net:9090
- **Grafana**: http://monitoring.discus-moth.ts.net:3000
- **Alertmanager**: http://monitoring.discus-moth.ts.net:9093

> **Note**: Uptime Kuma has been moved to external monitoring (Oracle Cloud) for independent availability
> monitoring.

## Prometheus Configuration

### Alert Rules

Alert rules are pre-configured in `/opt/monitoring/configs/alert_rules.yml` and cover:

**Availability Alerts**:

- HostDown - Any VM or Proxmox host unreachable for 2+ minutes
- PrometheusDown - Prometheus itself is down

**Resource Alerts**:

- HighCPUUsage (>90% for 10min) / CriticalCPUUsage (>95% for 5min)
- HighMemoryUsage (>85% for 10min) / CriticalMemoryUsage (>95% for 5min)
- DiskSpaceLow (<20% free) / DiskSpaceCritical (<10% free)
- HighDiskIOLatency
- HighSystemLoad

**Thermal Alerts**:

- CPUThermalThrottling (>=87°C for 1min) - Critical: CPU at throttling threshold
- CPUHighTemperature (>=80°C for 10min) - Warning: Sustained high temperature
- CPUElevatedTemperature (>=75°C for 15min) - Info: Early warning
- HardwareCriticalTemperature - Hardware sensor critical alarm triggered

**Service Alerts**:

- ServiceDown - HTTP endpoint unreachable for 3+ minutes
- ServiceSlow - HTTP response time >5 seconds
- ContainerDown - Docker container stopped for 5+ minutes
- ContainerHighCPU / ContainerHighMemory

**Network Alerts**:

- InternetConnectivityLost
- DNSServerDown
- HighNetworkErrors
- NetworkDeviceDown (Mikrotik)

**Storage Alerts**:

- NFSServerDown
- NFSMountFailed
- BtrfsDiskErrors (NAS RAID degradation)

### Viewing Active Alerts

1. Open Prometheus: http://monitoring.discus-moth.ts.net:9090
2. Navigate to **Status → Rules** to see all configured alert rules
3. Navigate to **Alerts** to see currently firing alerts
4. Each alert shows:
   - Current state (inactive, pending, firing)
   - Labels (severity, instance, etc.)
   - Annotations (description, summary)

### Testing Alert Rules

Manually trigger an alert to test configuration:

```bash
# Example: Trigger high CPU alert by running stress test
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net
stress --cpu 8 --timeout 600s
```

Watch in Prometheus UI → Alerts tab for "HighCPUUsage" to transition:

- **inactive** → **pending** (after 10 minutes) → **firing**

### Modifying Alert Rules

1. Edit alert rules locally:

   ```bash
   vi services/compose/monitoring/configs/alert_rules.yml
   ```

2. Deploy changes:

   ```bash
   # Copy to monitoring VM
   scp -i ~/.ssh/ansible_homelab services/compose/monitoring/configs/alert_rules.yml \
     ansible@monitoring.discus-moth.ts.net:~/

   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "sudo mv ~/alert_rules.yml /opt/monitoring/configs/ && sudo chown ansible:ansible /opt/monitoring/configs/alert_rules.yml"

   # Reload Prometheus configuration
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "curl -X POST http://localhost:9090/-/reload"
   ```

3. Verify in Prometheus UI: Status → Configuration

### Thermal Monitoring

Temperature metrics are collected from all VMs and the Proxmox host via the `hwmon` and `thermal` collectors in node_exporter.

**Viewing Temperature Metrics**:

```bash
# Check thermal metrics on Proxmox host
curl http://jellybuntu.discus-moth.ts.net:9100/metrics | grep "node_hwmon_temp"

# In Prometheus UI, query current temperatures:
node_hwmon_temp_celsius{chip=~".*coretemp.*|.*k10temp.*|.*zenpower.*"}
```

**Common Temperature Sensors**:

- **coretemp**: Intel CPU sensors
- **k10temp/zenpower**: AMD Ryzen/EPYC CPU sensors
- **nvme**: NVMe SSD temperatures
- **acpitz**: ACPI thermal zone sensors

**Temperature Alert Thresholds**:

- **75°C**: Early warning (info severity) - Monitor cooling
- **80°C**: High temperature (warning severity) - Check cooling system
- **87°C**: Thermal throttling threshold (critical severity) - Immediate action required

**Testing Thermal Alerts**:

```bash
# Monitor current CPU temperature
ssh -i ~/.ssh/ansible_homelab root@jellybuntu.discus-moth.ts.net \
  "watch -n 1 'sensors | grep Package'"

# Generate CPU load to increase temperature (use with caution)
ssh -i ~/.ssh/ansible_homelab root@jellybuntu.discus-moth.ts.net \
  "stress --cpu $(nproc) --timeout 300s"
```

**Note**: Thermal alerts apply to both the Proxmox host and guest VMs. Ensure adequate cooling for all systems.

## Notification Channels

Prometheus alert rules can be viewed in the UI, but to send notifications you need either:

1. **Grafana Alerts** (recommended for this setup - uses Grafana's built-in alerting)
2. **Alertmanager** (separate component, more complex but more powerful)

### Option 1: Grafana Alerting (Recommended)

Grafana can query Prometheus and send notifications directly.

#### 1. Access Grafana

1. Navigate to http://monitoring.discus-moth.ts.net:3000
2. Login with credentials from secrets file (username/password from [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml))

#### 2. Configure Notification Channels

1. Go to **Alerting → Contact points**
2. Click **Add contact point**

**Discord Setup**:

1. In Discord: Server Settings → Integrations → Webhooks → New Webhook
2. Choose channel (e.g., #alerts), copy webhook URL
3. In Grafana:
   - **Name**: Discord Alerts
   - **Integration**: Discord
   - **Webhook URL**: Paste Discord webhook URL
   - **Message**: (optional custom template)
   - **Test**: Send test notification
   - **Save**

**Email Setup (SMTP)**:

1. In Grafana:
   - **Name**: Email Alerts
   - **Integration**: Email
   - **Addresses**: your-email@example.com (comma-separated for multiple)
2. Configure SMTP in Grafana's environment (requires docker-compose edit):

   ```yaml
   environment:
     - GF_SMTP_ENABLED=true
     - GF_SMTP_HOST=smtp.gmail.com:587
     - GF_SMTP_USER=your-email@gmail.com
     - GF_SMTP_PASSWORD=app-specific-password
     - GF_SMTP_FROM_ADDRESS=your-email@gmail.com
   ```

3. Restart Grafana container after editing
4. **Test**: Send test email from contact point

**Slack / Telegram / Other**:

- Follow similar webhook-based setup
- Grafana supports 50+ notification types

#### 3. Create Notification Policies

1. Go to **Alerting → Notification policies**
2. Edit default policy or create new:
   - **Contact point**: Choose Discord/Email/etc.
   - **Matching labels**: (optional) Route based on severity, instance, etc.
   - **Group by**: instance, alertname (groups related alerts)
   - **Timing**:
     - Group wait: 30s
     - Group interval: 5m
     - Repeat interval: 4h

#### 4. Create Alert Rules from Prometheus Metrics

Option A: Import Prometheus rules into Grafana (recommended):

1. Go to **Alerting → Alert rules**
2. Click **New alert rule**
3. **Query**: Use Prometheus datasource

   ```promql
   # Example: High CPU alert
   (100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 90
   ```

4. **Expressions**: Add threshold conditions
5. **Alert evaluation**:
   - Folder: Infrastructure
   - Evaluation group: Create new (e.g., "resource-alerts")
   - Evaluation interval: 1m
   - For: 10m (pending duration)
6. **Labels**: severity=warning, category=cpu
7. **Annotations**:
   - Summary: `High CPU on {{ $labels.instance }}`
   - Description: `CPU usage is {{ $value }}%`
8. **Save**

Option B: Let Prometheus evaluate rules, use Grafana only for notifications:

- Configure Alertmanager (see Option 2 below)
- Connect Grafana to Alertmanager as data source
- View alerts in Grafana's Alerting → Alert rules (read-only)

### Option 2: Alertmanager (Advanced)

For more complex routing, silencing, and alert grouping.

#### 1. Add Alertmanager to docker-compose.yml

```yaml
services:
  alertmanager:
    image: docker.io/prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./configs/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    networks:
      - monitoring

volumes:
  alertmanager_data:
```

#### 2. Create Alertmanager Configuration

Create [`services/compose/monitoring/configs/alertmanager.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/monitoring/configs/alertmanager.yml):

```yaml
---
global:
  resolve_timeout: 5m

route:
  receiver: 'default-receiver'
  group_by: ['alertname', 'instance']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  # Route critical alerts to pager/phone
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      continue: true

    - match:
        severity: warning
      receiver: 'warning-alerts'

receivers:
  - name: 'default-receiver'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE'

  - name: 'critical-alerts'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_CRITICAL_WEBHOOK'
        title: '🚨 CRITICAL ALERT'

  - name: 'warning-alerts'
    discord_configs:
      - webhook_url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE'
        title: '⚠️ Warning'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

#### 3. Enable Alertmanager in Prometheus

Edit `prometheus.yml`:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

#### 4. Restart monitoring stack

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "cd /opt/monitoring && podman-compose up -d"
```

#### 5. Access Alertmanager UI

- **URL**: http://monitoring.discus-moth.ts.net:9093
- Features: View alerts, create silences, view notification status

## Grafana Dashboards

### Accessing Pre-Configured Dashboards

Grafana includes dashboard provisioning, but initial setup requires manual import.

1. Login to Grafana: http://monitoring.discus-moth.ts.net:3000
2. Verify Prometheus datasource: Configuration → Data Sources → Prometheus

### Recommended Dashboards to Import

Grafana has a vast library of community dashboards at https://grafana.com/grafana/dashboards

#### 1. Node Exporter Full Dashboard (ID: 1860)

Comprehensive Linux system metrics (CPU, RAM, disk, network)

1. In Grafana: **Dashboards → Import**
2. **Dashboard ID**: 1860
3. **Prometheus datasource**: Select "Prometheus"
4. **Import**

Covers all 6 VMs + Proxmox host metrics.

#### 2. Docker Container Metrics (ID: 193)

cAdvisor metrics for all Docker containers

1. **Dashboard ID**: 193
2. **Prometheus datasource**: Prometheus
3. **Import**

Shows per-container CPU, memory, network, disk I/O.

#### 3. Blackbox Exporter Dashboard (ID: 7587)

HTTP/DNS probe results (16 targets: 9 internal services + 4 DNS + 3 external HTTP)

1. **Dashboard ID**: 7587
2. **Prometheus datasource**: Prometheus
3. **Import**

Visualizes all service endpoint checks.

**Note**: ICMP probes are not supported in rootless Podman (NET_RAW capability limitation). DNS and HTTP checks provide
equivalent external connectivity validation.

#### 4. SNMP Stats (Mikrotik) (ID: 11169)

Mikrotik network device metrics

1. **Dashboard ID**: 11169
2. **Prometheus datasource**: Prometheus
3. **Import**

Shows router/switch CPU, memory, interfaces.

### Creating Custom Dashboards

#### Example: Jellybuntu Infrastructure Overview

1. Go to **Dashboards → New Dashboard**
2. **Add panel**

**Panel 1: Host Status** <!-- markdownlint-disable-line MD036 -->

- **Query**: `up{job="vm-nodes"}`
- **Visualization**: Stat
- **Title**: "VM Status"
- **Value mappings**: 0=Down (red), 1=Up (green)

**Panel 2: CPU Usage** <!-- markdownlint-disable-line MD036 -->

- **Query**:

  ```promql
  100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
  ```

- **Visualization**: Time series
- **Title**: "CPU Usage by Host"
- **Legend**: {{ instance }}
- **Thresholds**: 80% (orange), 90% (red)

**Panel 3: Memory Usage** <!-- markdownlint-disable-line MD036 -->

- **Query**:

  ```promql
  (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
  ```

- **Visualization**: Gauge
- **Title**: "Memory Usage"
- **Unit**: Percent (0-100)

**Panel 4: Disk Space** <!-- markdownlint-disable-line MD036 -->

- **Query**:

  ```promql
  (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"} / node_filesystem_size_bytes) * 100
  ```

- **Visualization**: Table
- **Title**: "Disk Space by Filesystem"

**Panel 5: Service Availability** <!-- markdownlint-disable-line MD036 -->

- **Query**: `probe_success{job="blackbox-http"}`
- **Visualization**: Status history
- **Title**: "Service Uptime"

1. **Save dashboard**: Name it "Jellybuntu Overview"
2. **Set auto-refresh**: 30s or 1m

### Dashboard Best Practices

1. **Use variables** for dynamic filtering:
   - Settings → Variables → Add variable
   - **Name**: instance
   - **Type**: Query
   - **Query**: `label_values(up, instance)`
   - Use in panels: `up{instance="$instance"}`

2. **Set time ranges** appropriately:
   - Real-time monitoring: Last 30 minutes
   - Trend analysis: Last 24 hours, Last 7 days
   - Use "From" and "To" variables for custom ranges

3. **Add annotations** for events:
   - Settings → Annotations → Add annotation
   - Track deployments, restarts, incidents

4. **Share dashboards**:
   - Dashboard settings → JSON Model → Copy
   - Save to [`services/compose/monitoring/services/grafana/dashboards/`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/monitoring/services/grafana/dashboards/)
   - Provision automatically on container restart

### Exporting Dashboards for Version Control

```bash
# From Grafana UI: Share → Export → Save to file
# Or via API:
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://monitoring.discus-moth.ts.net:3000/api/dashboards/uid/YOUR_DASHBOARD_UID \
  | jq '.dashboard' > dashboard.json

# Store in repo
cp dashboard.json services/compose/monitoring/services/grafana/dashboards/
```

## Prometheus Federation (Optional)

For multi-site monitoring, configure Prometheus federation to aggregate metrics from multiple Prometheus instances.

**Not needed for single-site Jellybuntu setup.**

## Troubleshooting

### Prometheus Not Scraping Targets

1. Check target status: Prometheus → Status → Targets
2. Verify connectivity:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "curl -I http://jellyfin.discus-moth.ts.net:9100/metrics"
   ```

3. Check firewall rules on target VM:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "sudo ufw status | grep 9100"
   ```

### Alert Rules Not Evaluating

1. Check Prometheus logs:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "podman logs prometheus"
   ```

2. Validate rule file syntax:

   ```bash
   promtool check rules /path/to/alert_rules.yml
   ```

3. Check Status → Rules in Prometheus UI for errors

### Grafana Datasource Connection Failed

1. Verify Prometheus is running:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "podman ps | grep prometheus"
   ```

2. Test Prometheus API from Grafana container:

   ```bash
   podman exec grafana wget -O- http://prometheus:9090/api/v1/query?query=up
   ```

3. Check datasource configuration:
   - URL should be `http://prometheus:9090` (container name, not IP)
   - Access: Server (default)

### Notifications Not Sending

1. Test contact point in Grafana: Alerting → Contact points → Test
2. Check logs:

   ```bash
   podman logs grafana | grep -i notification
   ```

3. Verify webhook URL is correct
4. Check Discord/Slack channel permissions

### High Prometheus Memory Usage

1. Reduce scrape interval in `prometheus.yml` (e.g., 30s → 60s)
2. Reduce retention period:
   - Edit docker-compose.yml: `--storage.tsdb.retention.time=15d`
3. Add recording rules to pre-aggregate metrics
4. Consider using remote write to long-term storage

## See Also

- [Service Endpoints](service-endpoints.md) - All monitored services
- [Troubleshooting: Monitoring](../troubleshooting/monitoring.md) - Common monitoring issues
- [Phase 5 Deployment](../deployment/phase5-monitoring.md) - Initial monitoring deployment
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

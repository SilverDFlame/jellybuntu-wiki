# Monitoring Troubleshooting Guide

Common issues and solutions for the Jellybuntu monitoring infrastructure (Prometheus, Alertmanager, Grafana).

> **IMPORTANT**: Monitoring services run as **rootless Podman containers with Quadlet** on the monitoring VM
> (192.168.10.16). Use `systemctl --user` and `podman` commands, NOT `docker` commands.
>
> **Note**: Uptime Kuma has been moved to external monitoring (Oracle Cloud).

## Service Accessibility Issues

### Can't Access Any Monitoring Services

**Symptoms**: Unable to reach Prometheus, Grafana, or Alertmanager UIs

**Diagnosis**:

```bash
# SSH to monitoring VM
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net

# 1. Verify monitoring VM is running
qm status 500  # From Proxmox host

# 2. Check service status
systemctl --user status prometheus grafana alertmanager

# 3. Check containers are running
podman ps

# 4. Verify network connectivity
ping monitoring.discus-moth.ts.net
```

**Solutions**:

1. **Services stopped**:

   ```bash
   systemctl --user start prometheus grafana alertmanager
   systemctl --user enable prometheus grafana alertmanager
   ```

2. **Containers keep stopping after SSH logout** (rootless Podman issue):

   ```bash
   # Enable user lingering
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "sudo loginctl enable-linger ansible"

   # Verify
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "loginctl show-user ansible | grep Linger"
   # Expected: Linger=yes

   # Restart services
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "systemctl --user restart prometheus grafana alertmanager"
   ```

3. **Firewall blocking access**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "sudo ufw status | grep -E '(3000|3001|9090)'"

   # Add missing rules if needed
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "sudo ufw allow from 192.168.10.0/24 to any port 3000 proto tcp"
   ```

4. **Tailscale connectivity issue**:

   ```bash
   # Check if monitoring VM is on Tailscale network
   tailscale status | grep monitoring

   # Try accessing via local IP instead
   http://192.168.10.16:3000  # Grafana
   http://192.168.10.16:9090  # Prometheus
   http://192.168.10.16:3001  # Uptime Kuma
   ```

### Specific Service Won't Start

**Symptoms**: One container continuously restarting or exited

**Diagnosis**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "podman ps -a | grep -E '(prometheus|grafana|uptime-kuma)'"
```

Look for status: `Restarting` or `Exited (X) Y seconds ago`

**Solutions**:

1. **Check logs for errors**:

   ```bash
   # Replace 'prometheus' with the problematic service
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "podman logs prometheus 2>&1 | tail -50"
   ```

2. **Common errors and fixes**:

   **Prometheus**: "error loading config file"

   ```bash
   # Validate config syntax
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "cat /opt/monitoring/configs/prometheus.yml"

   # Check for YAML syntax errors (tabs vs spaces, indentation)
   # Fix config, then restart
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "cd /opt/monitoring && systemctl --user restart prometheus"
   ```

   **Grafana**: "failed to start grafana" / "permission denied"

   ```bash
   # Check volume permissions
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "podman volume inspect monitoring_grafana_data"

   # Grafana container runs as UID 0 (maps to ansible user)
   # Ensure volume ownership is correct
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "systemctl --user down && systemctl --user up -d"
   ```

   **Uptime Kuma**: "database locked"

   ```bash
   # Stop container
   podman stop uptime-kuma

   # Wait 10 seconds for file locks to clear
   sleep 10

   # Start again
   podman start uptime-kuma
   ```

## Prometheus Issues

### Targets Showing as DOWN

**Symptoms**: In Prometheus UI (Status → Targets), some targets show red "DOWN" status

**Diagnosis**:

```bash
# Test connectivity from monitoring VM to target
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "curl -I http://jellyfin.discus-moth.ts.net:9100/metrics"
```

**Solutions**:

1. **Firewall blocking exporter port**:

   ```bash
   # On target VM, check firewall
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "sudo ufw status | grep 9100"

   # Allow monitoring VM to access exporter
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "sudo ufw allow from 192.168.10.16 to any port 9100 proto tcp"
   ```

2. **node_exporter not running**:

   ```bash
   # Check service status
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "systemctl status node_exporter"

   # Start if stopped
   ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
     "sudo systemctl restart node_exporter && sudo systemctl enable node_exporter"
   ```

3. **cAdvisor container not running**:

   ```bash
   # Check if cAdvisor is running
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
     "podman ps | grep cadvisor"

   # Restart if needed
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net \
     "systemctl --user restart cadvisor"
   ```

4. **SNMP target down** (Mikrotik devices):
   - Verify SNMP is enabled on Mikrotik device (IP → SNMP)
   - Check SNMPv3 credentials in `snmp.yml` match device config
   - Test SNMP query from monitoring VM:

     ```bash
     ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
       "podman exec snmp-exporter /bin/snmpget -v3 -l authPriv -u <username> -a SHA -A <authpass> -x AES -X <privpass> 192.168.10.1 sysName.0"
     ```

5. **Blackbox exporter failing HTTP checks**:
   - Target service may actually be down (check directly in browser)
   - Check blackbox exporter logs:

     ```bash
     podman logs blackbox-exporter | grep -i error
     ```

   - Verify blackbox config is correct:

     ```bash
     cat /opt/monitoring/services/exporters/blackbox/blackbox.yml
     ```

### No Data in Prometheus

**Symptoms**: Queries return no results, graphs are empty

**Diagnosis**:

```bash
# Check if Prometheus is scraping
curl -s http://monitoring.discus-moth.ts.net:9090/api/v1/query?query=up | python3 -m json.tool
```

**Solutions**:

1. **Prometheus not scraping** (all targets down):
   - Check Prometheus logs: `podman logs prometheus | grep -i error`
   - Verify prometheus.yml is mounted: `podman inspect prometheus | grep prometheus.yml`
   - Restart Prometheus: `podman restart prometheus`

2. **Queries work in Prometheus UI but not Grafana**:
   - Check Grafana datasource configuration (should be `http://prometheus:9090`)
   - Test datasource in Grafana: Configuration → Data Sources → Prometheus → Test

3. **Old data visible but no new data**:
   - Prometheus may have stopped scraping (check /targets page)
   - Check disk space: `df -h /opt/monitoring` (Prometheus needs space for TSDB)

### Alert Rules Not Firing

**Symptoms**: Conditions met but alerts stay inactive

**Diagnosis**:

```bash
# Check if rules are loaded
curl -s http://monitoring.discus-moth.ts.net:9090/api/v1/rules | python3 -m json.tool | grep -A5 "HighCPUUsage"

# Check rule health
# In Prometheus UI: Status → Rules
# Look for "health": "ok" or "health": "err"
```

**Solutions**:

1. **Rules not loaded**:

   ```bash
   # Verify alert_rules.yml is mounted
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "podman inspect prometheus | grep alert_rules"

   # Check Prometheus logs for rule errors
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "podman logs prometheus | grep -i rule"
   ```

2. **Rule syntax error**:
   - Download `promtool` locally and validate:

     ```bash
     promtool check rules compose_files/monitoring/configs/alert_rules.yml
     ```

   - Fix errors, redeploy config, reload Prometheus

3. **Alert in "pending" state but never "firing"**:
   - Check `for:` duration in rule (e.g., `for: 10m` means alert must be true for 10 minutes)
   - Wait for full duration, then check again

4. **No notification sent even when alert fires**:
   - Prometheus only evaluates rules, it doesn't send notifications by itself
   - Configure Alertmanager OR use Grafana Alerts (see [Monitoring Stack Setup](../configuration/monitoring-stack-setup.md#notification-channels))

### High Prometheus Memory Usage

**Symptoms**: Prometheus container using >4GB RAM, monitoring VM slow

**Diagnosis**:

```bash
# Check container memory
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "podman stats --no-stream prometheus"
```

**Solutions**:

1. **Reduce scrape interval**:
   - Edit `prometheus.yml`: Change `scrape_interval: 30s` to `60s`
   - Redeploy and restart Prometheus

2. **Reduce retention period**:

   ```ini
   # In Quadlet .container file (~/.config/containers/systemd/prometheus.container)
   # Add to [Container] section:
   PodmanArgs=--storage.tsdb.retention.time=15d  # Reduce from 30d
   ```

3. **Add recording rules** (pre-aggregate expensive queries):
   - Create `recording_rules.yml` with pre-computed metrics
   - Reduces query load at expense of storage

4. **Use remote write** (for long-term storage):
   - Configure Prometheus to write metrics to external storage (Thanos, Mimir, VictoriaMetrics)
   - Keep shorter retention locally (7d)

## Grafana Issues

### Can't Login to Grafana

**Symptoms**: "Invalid username or password"

**Solutions**:

1. **Using wrong credentials**:
   - Check secrets file for correct credentials:

     ```bash
     sops -d group_vars/all.sops.yaml | grep -A5 services_admin
     ```

2. **Grafana admin password not set**:
   - If `GF_SECURITY_ADMIN_PASSWORD` environment variable wasn't set correctly from secrets file
   - Reset admin password:

     ```bash
     ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
       "podman exec -it grafana grafana-cli admin reset-admin-password NewPassword123"
     ```

3. **Locked out after too many failed attempts**:
   - Wait 10 minutes for lockout to expire
   - OR restart Grafana: `podman restart grafana`

### Grafana Datasource "Not Working"

**Symptoms**: Red "Data source is not working" error when testing Prometheus datasource

**Diagnosis**:

```bash
# Test Prometheus API from Grafana container
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "podman exec grafana wget -O- http://prometheus:9090/api/v1/query?query=up"
```

**Solutions**:

1. **Wrong datasource URL**:
   - Should be `http://prometheus:9090` (container name, not IP)
   - Access mode should be "Server" (default)

2. **Prometheus not running**:

   ```bash
   podman ps | grep prometheus
   podman restart prometheus
   ```

3. **Network issue between containers**:

   ```bash
   # Verify both on same network
   podman inspect grafana | grep -i network
   podman inspect prometheus | grep -i network
   # Both should be on "monitoring_monitoring" network
   ```

4. **Prometheus not responding**:

   ```bash
   # Check Prometheus logs
   podman logs prometheus | tail -50

   # Test Prometheus API directly
   curl http://monitoring.discus-moth.ts.net:9090/api/v1/query?query=up
   ```

### Dashboards Show "No Data"

**Symptoms**: Dashboard panels show "No data" even though Prometheus has data

**Solutions**:

1. **Wrong time range selected**:
   - Check dashboard time picker (top right)
   - Try "Last 5 minutes" or "Last 1 hour"

2. **Query returns no results**:
   - Click "Query inspector" on panel
   - Test query directly in Prometheus UI
   - Check metric name spelling, label filters

3. **Dashboard imported for wrong datasource**:
   - Edit dashboard settings
   - Ensure all queries use your "Prometheus" datasource

4. **Metrics not being collected**:
   - Check Prometheus → Status → Targets
   - Verify exporters are running and scraped

### Grafana Notifications Not Sending

**Symptoms**: Alert rules fire but no notifications received

**Solutions**:

1. **Contact point not configured**:
   - Alerting → Contact points → Verify contact point exists
   - Test contact point (Test button)

2. **Notification policy not applied**:
   - Alerting → Notification policies → Check policy routes to correct contact point

3. **Discord webhook invalid**:
   - Recreate webhook in Discord
   - Update in Grafana contact point
   - Test again

4. **Email SMTP not configured**:
   - Check Grafana environment variables in Quadlet .container file:

     ```ini
     # In ~/.config/containers/systemd/grafana.container [Container] section:
     Environment=GF_SMTP_ENABLED=true
     Environment=GF_SMTP_HOST=smtp.gmail.com:587
     Environment=GF_SMTP_USER=your-email@gmail.com
     ```

   - Restart Grafana after adding SMTP config: `systemctl --user restart grafana`

5. **Check Grafana logs for errors**:

   ```bash
   podman logs grafana | grep -i notification
   ```

## Uptime Kuma Issues

### Monitors Showing False Positives (Down when service is up)

**Symptoms**: Monitor shows service down, but service is accessible in browser

**Solutions**:

1. **DNS resolution failure**:

   ```bash
   # Test DNS from monitoring VM
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "nslookup jellyfin.discus-moth.ts.net"

   # Use IP address instead of hostname in monitor URL
   http://192.168.30.12:8096  # Instead of jellyfin.discus-moth.ts.net
   ```

2. **Timeout too short**:
   - Edit monitor → Advanced → Timeout
   - Increase from default (48s) to 60s or 120s

3. **Incorrect accepted status codes**:
   - Edit monitor → Advanced → Accepted Status Codes
   - Should be `200-299` for most services
   - Some services redirect (use `200-399`)

4. **Firewall blocking monitoring VM**:
   - Check if monitoring VM (192.168.10.16) can reach service
   - Add firewall rule on target VM if needed

### Uptime Kuma Web UI Slow or Unresponsive

**Symptoms**: UI takes >10 seconds to load, frequent timeouts

**Solutions**:

1. **Database needs optimization**:
   - Uptime Kuma uses SQLite
   - Stop container, copy database, restart:

     ```bash
     podman stop uptime-kuma
     podman volume export uptime_kuma_data > ~/uptime-kuma-backup.tar
     podman start uptime-kuma
     ```

2. **Too much historical data**:
   - Settings → Data Retention → Reduce from 180 days to 90 days
   - Click "Clear Stats" to remove old data

3. **Monitor check intervals too frequent**:
   - Edit monitors → Heartbeat Interval → Change from 20s to 60s
   - Reduces database writes

### Notifications Not Sending from Uptime Kuma

**Symptoms**: Monitors go down but no notifications received

**Solutions**:

1. **Notification not enabled for monitor**:
   - Edit monitor → Notifications → Enable your notification channel

2. **Notification channel not configured**:
   - Settings → Notifications → Setup Notification
   - Test notification (Test button)

3. **Discord webhook invalid**:
   - Recreate webhook in Discord
   - Update in Uptime Kuma Settings → Notifications

4. **Rate limiting** (Discord):
   - Discord limits webhook messages
   - Group monitors or use longer check intervals

## Performance Issues

### Monitoring VM Running Slow

**Symptoms**: High CPU, high memory, services responding slowly

**Diagnosis**:

```bash
# Check resource usage
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "top -bn1 | head -20"

# Check container resource usage
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "podman stats --no-stream"
```

**Solutions**:

1. **Prometheus using too much memory** (see "High Prometheus Memory Usage" above)

2. **Increase VM resources**:
   - Stop VM: `qm stop 500`
   - Edit VM: `qm set 500 -memory 8192 -cores 6`
   - Start VM: `qm start 500`

3. **Reduce scrape frequency**:
   - Edit prometheus.yml: `scrape_interval: 60s` (from 30s)

4. **Reduce number of monitored targets**:
   - Comment out less critical targets in prometheus.yml
   - Reload config: `curl -X POST http://localhost:9090/-/reload`

### Exporters Causing High Load on Target VMs

**Symptoms**: VMs slow after deploying exporters

**Solutions**:

1. **cAdvisor using too much CPU**:

   ```bash
   # Check cAdvisor resource usage
   podman stats cadvisor

   # Reduce housekeeping interval (edit Quadlet .container file)
   # Add to [Container] section:
   # PodmanArgs=--housekeeping_interval=30s  # Increase from default 10s
   ```

2. **node_exporter collecting too many metrics**:

   ```bash
   # Disable expensive collectors
   sudo systemctl edit node_exporter

   # Add:
   [Service]
   ExecStart=
   ExecStart=/usr/local/bin/node_exporter --no-collector.wifi --no-collector.hwmon

   sudo systemctl daemon-reload && sudo systemctl restart node_exporter
   ```

## Network Connectivity Issues

### Monitoring Can't Reach Tailscale Hostnames

**Symptoms**: Targets with `*.discus-moth.ts.net` hostnames show DOWN

**Solutions**:

1. **Tailscale not running on monitoring VM**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "sudo systemctl status tailscaled"

   # Start if stopped
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "sudo systemctl start tailscaled"
   ```

2. **Monitoring VM not approved in Tailscale**:
   - Go to https://login.tailscale.com/admin/machines
   - Find "monitoring" machine
   - Approve if pending

3. **Use local IP addresses instead**:
   - Edit prometheus.yml targets: Replace `jellyfin.discus-moth.ts.net` with `192.168.30.12`

### Monitoring Can't Reach Proxmox Host

**Symptoms**: `jellybuntu.discus-moth.ts.net:9100` target DOWN

**Solutions**:

1. **node_exporter not installed on Proxmox host**:
   - Install on Proxmox host (requires manual steps, not covered by Ansible playbooks)

2. **Firewall blocking on Proxmox**:
   - On Proxmox host: `pve-firewall status`
   - Allow port 9100 from monitoring VM

## Data Loss / Corruption Issues

### Prometheus Data Corrupted

**Symptoms**: Prometheus fails to start, logs show "corrupted block" or "bad header"

**Solutions**:

1. **Let Prometheus repair automatically**:

   ```bash
   podman restart prometheus
   # Prometheus attempts to repair on startup
   ```

2. **Manually clean corrupted data**:

   ```bash
   # Stop Prometheus
   podman stop prometheus

   # Remove corrupted block (Prometheus will rebuild from WAL)
   podman volume export prometheus_data > ~/prom-backup.tar
   podman volume rm prometheus_data
   podman volume create prometheus_data

   # Start Prometheus (will start fresh)
   podman start prometheus
   ```

3. **Restore from backup**:

   ```bash
   podman stop prometheus
   cat ~/prom-backup.tar | podman volume import prometheus_data -
   podman start prometheus
   ```

### Grafana Dashboards Lost After Restart

**Symptoms**: Imported dashboards disappear after Grafana restart

**Solutions**:

1. **Dashboards not saved to volume**:
   - Save dashboards: Dashboard settings → Save dashboard → Star dashboard
   - Check Grafana data persists: `podman volume inspect grafana_data`

2. **Volume was deleted accidentally**:
   - Restore from backup:

     ```bash
     cat ~/grafana-backup.tar | podman volume import grafana_data -
     ```

3. **Use dashboard provisioning** (persist in version control):
   - Export dashboard JSON
   - Save to `~/.config/grafana/dashboards/`
   - Mount via Quadlet Volume directive (already configured)

### Uptime Kuma Data Lost

**Symptoms**: All monitors and settings gone after restart

**Solutions**:

1. **Volume deleted or corrupted**:
   - Restore from backup:

     ```bash
     podman stop uptime-kuma
     cat ~/uptime-kuma-backup.tar | podman volume import uptime_kuma_data -
     podman start uptime-kuma
     ```

2. **Prevent future data loss** - backup regularly:

   ```bash
   # Add to cron (run weekly)
   0 2 * * 0 podman volume export uptime_kuma_data > ~/uptime-kuma-backup-$(date +\%Y\%m\%d).tar
   ```

## Getting Help

If you've tried the solutions above and still have issues:

1. **Check container logs**:

   ```bash
   podman logs <container-name> --tail 100
   ```

2. **Check system logs**:

   ```bash
   journalctl -u podman -n 100
   ```

3. **Verify infrastructure health**:
   - All VMs running: `qm list` (on Proxmox host)
   - Network connectivity: `ping`, `traceroute`
   - Disk space: `df -h`

4. **Consult official documentation**:
   - [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)
   - [Grafana Troubleshooting](https://grafana.com/docs/grafana/latest/troubleshooting/)
   - [Uptime Kuma GitHub Issues](https://github.com/louislam/uptime-kuma/issues)

## See Also

- [Monitoring Stack Setup](../configuration/monitoring-stack-setup.md) - Configuration guide
- [Uptime Kuma Setup](../configuration/uptime-kuma-setup.md) - Uptime Kuma configuration
- [Phase 5 Deployment](../deployment/phase5-monitoring.md) - Deployment guide
- [Service Endpoints](../configuration/service-endpoints.md) - All service URLs

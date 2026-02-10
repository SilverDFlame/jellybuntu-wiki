# Monitoring Stack Maintenance Guide

Guide for maintaining the Prometheus, Grafana, and Uptime Kuma monitoring stack including data retention, backups,
alert management, and cleanup procedures.

## Overview

The monitoring stack runs on a dedicated VM (192.168.0.16 / monitoring.discus-moth.ts.net) and provides:

- **Prometheus**: Metrics collection and time-series database
- **Grafana**: Visualization dashboards
- **Uptime Kuma**: Service availability monitoring
- **SNMP Exporter**: Network device metrics
- **Blackbox Exporter**: Endpoint probing

**Deployment Details**:

- **Container Runtime**: Rootless Podman with Quadlet
- **Data Location**: `/opt/monitoring/data/`
- **Configuration**: `/opt/monitoring/services/`
- **Access**:
  - Prometheus: http://monitoring.discus-moth.ts.net:9090
  - Grafana: http://monitoring.discus-moth.ts.net:3000
  - Uptime Kuma: http://monitoring.discus-moth.ts.net:3001

## Routine Maintenance Overview

### Daily Tasks (Automated)

- Metric scraping and storage (Prometheus)
- Alert evaluation (Prometheus)
- Service health checks (Uptime Kuma)

### Weekly Tasks (Manual)

- Review dashboard performance
- Check disk space usage
- Verify alert delivery

### Monthly Tasks (Manual)

- Review data retention policies
- Update dashboards if needed
- Check container resource usage
- Review and prune old metrics

### Quarterly Tasks (Manual)

- Backup Grafana configuration
- Review alert rules
- Update container images
- Optimize Prometheus storage

## Prometheus Maintenance

### Data Retention Management

Prometheus stores metrics in time-series database blocks with configurable retention.

**Current retention settings** (configured in container environment):

```yaml
--storage.tsdb.retention.time=90d
--storage.tsdb.retention.size=10GB
```

**Check current retention**:

```bash
# SSH to monitoring VM
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net

# View Prometheus config
journalctl --user -u prometheus -n 50 | grep retention
```

### Disk Space Monitoring

Prometheus data can grow quickly with many targets and high scrape intervals.

**Check Prometheus disk usage**:

```bash
# Total data directory size
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "du -sh /opt/monitoring/data/prometheus/"

# Breakdown by component
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "du -sh /opt/monitoring/data/prometheus/*"
```

**Expected size**:

- Initial: 100-500MB
- After 30 days: 2-5GB
- After 90 days: 5-10GB (depending on number of targets)

**If disk usage is high (> 10GB)**:

1. Reduce retention time (90d → 60d)
2. Reduce scrape interval (30s → 60s)
3. Remove unused metrics (see "Cleanup Procedures")

### Adjusting Retention Policies

If storage is growing too fast:

**1. Edit retention in playbook**:

```bash
# Edit monitoring playbook
nano playbooks/monitoring/stack.yml

# Find prometheus container environment and modify:
environment:
  - name: "--storage.tsdb.retention.time"
    value: "60d"  # Reduced from 90d
  - name: "--storage.tsdb.retention.size"
    value: "8GB"  # Reduced from 10GB
```

**2. Re-deploy Prometheus**:

```bash
./bin/runtime/ansible-run.sh playbooks/monitoring/stack.yml --tags prometheus
```

**3. Verify new settings**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "journalctl --user -u prometheus -n 20 | grep retention"
```

### Compacting and Cleaning Storage

Prometheus automatically compacts time-series blocks, but you can manually trigger cleanup.

**Manual cleanup** (removes old blocks outside retention):

```bash
# SSH to monitoring VM
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net

# Stop Prometheus
systemctl --user stop prometheus

# Clean old blocks
find /opt/monitoring/data/prometheus/ -type d -mtime +90 -exec rm -rf {} +

# Start Prometheus
systemctl --user start prometheus

# Verify startup
systemctl --user status prometheus
```

**Warning**: Only run cleanup when Prometheus is stopped to prevent corruption.

### Query Performance Optimization

**Slow queries** can impact dashboard load times.

**Identify slow queries**:

1. Open Prometheus UI: http://monitoring.discus-moth.ts.net:9090
2. Status → Runtime & Build Information
3. Check "Query Duration 99th percentile"

**Target**: < 1 second for 99th percentile

**If queries are slow (> 5 seconds)**:

1. Reduce query time range (24h instead of 7d)
2. Increase scrape interval (reduce metric granularity)
3. Use recording rules for complex queries
4. Add more CPU/RAM to monitoring VM

### Metric Scraping Health

**Check scrape targets**:

1. Open Prometheus UI: http://monitoring.discus-moth.ts.net:9090
2. Status → Targets
3. All targets should show "UP" status

**If targets are down**:

- Verify target VM is running
- Check firewall rules on target VM
- Verify node_exporter is running: `systemctl --user status node_exporter`
- Test connectivity: `curl http://target-vm:9100/metrics`

### Alert Rule Management

Alert rules are configured in Prometheus to notify when metrics exceed thresholds.

**View current alerts**:

1. Prometheus UI → Alerts
2. Shows all configured alerts and their status

**Common alerts to configure**:

- High disk usage (> 80%)
- High CPU usage (> 90% for 5 minutes)
- Service down (up == 0)
- High memory usage (> 90%)

**Add new alert rules**:

Alert rules are defined in Prometheus configuration files deployed via the monitoring playbook.

```bash
# Edit alert rules
nano playbooks/monitoring/stack.yml

# Add alert rule in prometheus_config:
groups:
  - name: example
    rules:
      - alert: HighDiskUsage
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) < 0.2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Disk usage above 80% on {{ $labels.instance }}"

# Re-deploy
./bin/runtime/ansible-run.sh playbooks/monitoring/stack.yml
```

## Grafana Maintenance

### Dashboard Management

Dashboards are stored in Grafana's SQLite database.

**Backup dashboards** (export JSON):

1. Login to Grafana: http://monitoring.discus-moth.ts.net:3000
2. Open dashboard → Settings (gear icon)
3. JSON Model → Copy to clipboard
4. Save to file: `dashboard-name-backup.json`

**Recommended**: Backup critical dashboards monthly.

### Grafana Database Backup

Grafana uses SQLite for configuration, users, and dashboards.

**Manual backup**:

```bash
# Stop Grafana
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user stop grafana"

# Backup database
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "cp /opt/monitoring/data/grafana/grafana.db ~/grafana-backup-$(date +%Y%m%d).db"

# Start Grafana
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user start grafana"

# Download backup
scp -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net:~/grafana-backup-*.db ./backups/
```

**Restore from backup**:

```bash
# Stop Grafana
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user stop grafana"

# Upload backup
scp -i ~/.ssh/ansible_homelab ./backups/grafana-backup-YYYYMMDD.db \
  ansible@monitoring.discus-moth.ts.net:~/

# Restore database
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "cp ~/grafana-backup-YYYYMMDD.db /opt/monitoring/data/grafana/grafana.db"

# Start Grafana
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user start grafana"
```

### Data Source Configuration

Grafana connects to Prometheus as a data source.

**Verify data source**:

1. Grafana → Configuration → Data Sources
2. Prometheus should show "Working" status

**If data source is broken**:

1. Edit data source
2. Verify URL: `http://localhost:9090` (Prometheus runs on same VM)
3. Test & Save
4. Refresh dashboards

### Plugin Management

Grafana supports plugins for additional visualizations and data sources.

**List installed plugins**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "docker exec grafana grafana-cli plugins ls"
```

**Install plugin** (requires container rebuild):

```bash
# Edit monitoring playbook to add plugin
nano playbooks/monitoring/stack.yml

# Add to grafana environment:
environment:
  GF_INSTALL_PLUGINS: "grafana-clock-panel,grafana-simple-json-datasource"

# Re-deploy
./bin/runtime/ansible-run.sh playbooks/monitoring/stack.yml
```

### User and Access Management

**Review users**:

1. Grafana → Configuration → Users
2. Remove inactive users
3. Review permissions

**Reset admin password** (if lost):

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "docker exec grafana grafana-cli admin reset-admin-password newpassword"
```

## Uptime Kuma Maintenance

### Monitor Management

Uptime Kuma tracks service availability with HTTP/TCP checks.

**Access**: http://monitoring.discus-moth.ts.net:3001

### Check History and Logs

**View monitor history**:

1. Uptime Kuma UI → Select monitor
2. View uptime percentage (7d, 30d, 90d)
3. Review incident history

**Check logs**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "journalctl --user -u uptime-kuma -n 100"
```

### Notification Configuration

Uptime Kuma can send alerts via multiple channels (email, Slack, Discord, etc.).

**Add notification**:

1. Uptime Kuma → Settings → Notifications
2. Add notification endpoint (e.g., email, webhook)
3. Test notification
4. Assign to monitors

### Database Backup

Uptime Kuma uses SQLite for monitor configurations and history.

**Backup database**:

```bash
# Stop Uptime Kuma
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user stop uptime-kuma"

# Backup database
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "cp /opt/monitoring/data/uptime-kuma/kuma.db ~/uptime-kuma-backup-$(date +%Y%m%d).db"

# Start Uptime Kuma
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user start uptime-kuma"

# Download backup
scp -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net:~/uptime-kuma-backup-*.db ./backups/
```

**Restore from backup**:

```bash
# Stop service
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user stop uptime-kuma"

# Upload and restore
scp -i ~/.ssh/ansible_homelab ./backups/uptime-kuma-backup-YYYYMMDD.db \
  ansible@monitoring.discus-moth.ts.net:~/
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "cp ~/uptime-kuma-backup-YYYYMMDD.db /opt/monitoring/data/uptime-kuma/kuma.db"

# Start service
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user start uptime-kuma"
```

## Exporters Maintenance

### SNMP Exporter

Collects metrics from network devices (router, switches) via SNMP.

**Check SNMP exporter status**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user status snmp-exporter"

# View logs
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "journalctl --user -u snmp-exporter -n 50"
```

**Test SNMP scraping**:

```bash
# Test SNMP query directly
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "curl 'http://localhost:9116/snmp?target=192.168.0.1&module=default'"
```

**If SNMP is not working**:

- Verify SNMP is enabled on target device
- Check SNMP community string (configured in exporter)
- Verify firewall rules allow SNMP (UDP 161)

### Blackbox Exporter

Probes endpoints (HTTP, TCP, ICMP) for availability and response time.

**Check blackbox exporter status**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user status blackbox-exporter"
```

**Test probe**:

```bash
# Test HTTP probe
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "curl 'http://localhost:9115/probe?target=https://google.com&module=http_2xx'"
```

## Cleanup Procedures

### Remove Old Metrics

Prometheus automatically removes metrics outside retention, but you can manually delete specific metrics.

**Delete metrics for removed targets**:

1. Open Prometheus UI: http://monitoring.discus-moth.ts.net:9090
2. Status → TSDB Status
3. Identify series from removed targets
4. Use Prometheus API to delete (requires admin API enabled)

**Example**:

```bash
# Delete metrics from specific job
curl -X POST -g \
  'http://monitoring.discus-moth.ts.net:9090/api/v1/admin/tsdb/delete_series?match[]={job="old-job"}'

# Trigger compaction to reclaim space
curl -X POST http://monitoring.discus-moth.ts.net:9090/api/v1/admin/tsdb/clean_tombstones
```

**Note**: Admin API must be enabled in Prometheus config (`--web.enable-admin-api`).

### Grafana Dashboard Cleanup

Remove unused or outdated dashboards:

1. Grafana → Dashboards → Manage
2. Identify dashboards not viewed in 30+ days
3. Delete or archive unused dashboards

### Container Log Rotation

Systemd journal handles container logs, but you can limit retention.

**Check journal disk usage**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "journalctl --disk-usage"
```

**Limit journal size** (if too large):

```bash
# Edit journald config
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "sudo nano /etc/systemd/journald.conf"

# Set limits:
SystemMaxUse=500M
RuntimeMaxUse=100M

# Restart journald
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "sudo systemctl restart systemd-journald"
```

## Container Updates

All monitoring services use specific pinned versions for stability.

**Current versions** (as of documentation):

- Prometheus: `v3.5.0`
- Grafana: `12.2.0`
- Uptime Kuma: `2` (major version pin)
- SNMP Exporter: `v0.29.0`
- Blackbox Exporter: `v0.27.0`

### Update Process

**1. Check for new versions**:

```bash
# Prometheus
curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep tag_name

# Grafana
curl -s https://api.github.com/repos/grafana/grafana/releases/latest | grep tag_name
```

**2. Update version in playbook**:

```bash
nano playbooks/monitoring/stack.yml

# Update image tags:
containers:
  - name: prometheus
    image: "docker.io/prom/prometheus:v3.6.0"  # Updated version
```

**3. Backup before update**:

```bash
# Backup Grafana database
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "cp /opt/monitoring/data/grafana/grafana.db ~/grafana-pre-update-$(date +%Y%m%d).db"
```

**4. Re-deploy**:

```bash
./bin/runtime/ansible-run.sh playbooks/monitoring/stack.yml
```

**5. Verify services**:

```bash
# Check all services running
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "systemctl --user status prometheus grafana uptime-kuma"

# Test UIs
curl -I http://monitoring.discus-moth.ts.net:9090
curl -I http://monitoring.discus-moth.ts.net:3000
curl -I http://monitoring.discus-moth.ts.net:3001
```

## Troubleshooting

### Prometheus Not Scraping Targets

**Symptom**: Targets show "DOWN" in Prometheus UI

**Solution**:

1. Check target VM is running: `ping target-vm.discus-moth.ts.net`
2. Verify exporter is running: `ssh target-vm "systemctl --user status node_exporter"`
3. Test metrics endpoint: `curl http://target-vm:9100/metrics`
4. Check firewall rules: `ssh target-vm "sudo ufw status | grep 9100"`
5. Verify Prometheus config: `journalctl --user -u prometheus -n 50`

### Grafana Dashboards Not Loading

**Symptom**: Dashboards show "No data" or fail to load

**Solution**:

1. Verify Grafana is running: `systemctl --user status grafana`
2. Check Prometheus data source: Grafana → Configuration → Data Sources → Test
3. Verify Prometheus is collecting metrics: Prometheus UI → Status → Targets
4. Check browser console for errors (F12 → Console)
5. Review Grafana logs: `journalctl --user -u grafana -n 100`

### High Disk Usage

**Symptom**: Monitoring VM disk usage > 80%

**Solution**:

1. Check Prometheus data size: `du -sh /opt/monitoring/data/prometheus/`
2. Reduce retention time (90d → 60d)
3. Clean old Prometheus blocks (see "Cleanup Procedures")
4. Check journal logs: `journalctl --disk-usage`
5. Vacuum journal: `sudo journalctl --vacuum-size=200M`

### Service Won't Start After Update

**Symptom**: Container fails to start after version update

**Solution**:

1. Check container logs: `journalctl --user -u <service> -n 100`
2. Verify image is accessible: `podman pull <image>`
3. Check for configuration incompatibilities (breaking changes in new version)
4. Rollback to previous version (edit playbook with old tag, re-deploy)
5. Restore from backup if needed

### Alerts Not Firing

**Symptom**: Alert rules configured but no alerts triggered

**Solution**:

1. Verify alert rules are loaded: Prometheus UI → Alerts
2. Check if condition is actually met: Execute alert query in Prometheus UI
3. Verify Alertmanager is configured (if using)
4. Check alert rule syntax: `promtool check rules <file>`
5. Review Prometheus logs for evaluation errors

## Best Practices

### DO

- Backup Grafana database before updates
- Monitor disk space weekly
- Review alert rules quarterly
- Pin container versions for stability
- Test monitoring after infrastructure changes
- Document custom dashboards
- Export dashboard JSON periodically

### DON'T

- Disable retention limits (unbounded growth)
- Run containers as root (use rootless Podman)
- Store sensitive credentials in dashboards (use variables)
- Update all containers simultaneously (stagger updates)
- Ignore alert fatigue (tune thresholds)
- Delete Prometheus data while running (stop first)

## Maintenance Schedule Summary

### Weekly

- [ ] Check disk space usage
- [ ] Verify all scrape targets are UP
- [ ] Review Grafana dashboard performance
- [ ] Check Uptime Kuma monitor status

### Monthly

- [ ] Review data retention policies
- [ ] Backup Grafana database
- [ ] Check container resource usage (CPU/RAM)
- [ ] Review and prune old dashboards
- [ ] Verify alert delivery

### Quarterly

- [ ] Review alert rules and thresholds
- [ ] Update container images (if needed)
- [ ] Optimize Prometheus storage
- [ ] Review exporter configurations
- [ ] Test backup restore procedure

### Annually

- [ ] Comprehensive security review
- [ ] Review monitoring architecture
- [ ] Update documentation
- [ ] Plan capacity upgrades if needed

## Reference

### Related Documentation

- [Monitoring Deployment](../deployment/phase5-monitoring.md) - Initial setup guide
- [Service Endpoints](../configuration/service-endpoints.md) - Access URLs and ports
- [Troubleshooting](../troubleshooting/common-issues.md) - General troubleshooting

### External Resources

- [Prometheus Documentation](https://prometheus.io/docs/) - Official docs
- [Grafana Documentation](https://grafana.com/docs/) - Official docs
- [Uptime Kuma GitHub](https://github.com/louislam/uptime-kuma) - Project repository
- [Prometheus Best Practices](https://prometheus.io/docs/practices/) - Official best practices

## Summary

**Key Maintenance Tasks**:

- Monitor disk space (Prometheus data grows over time)
- Backup Grafana database monthly
- Review and optimize retention policies
- Update containers quarterly with pinned versions

**Key Commands**:

```bash
# Check service status
systemctl --user status prometheus grafana uptime-kuma

# View logs
journalctl --user -u prometheus -n 100

# Check disk usage
du -sh /opt/monitoring/data/*

# Backup Grafana
cp /opt/monitoring/data/grafana/grafana.db ~/grafana-backup-$(date +%Y%m%d).db
```

**Best Practices**:

- Regular backups before changes
- Monitor disk space weekly
- Pin versions for stability
- Review retention policies quarterly
- Test alert delivery regularly

Your monitoring stack stays healthy and provides reliable insights!

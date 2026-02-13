# Phase 5: Monitoring Infrastructure Deployment

Standalone deployment of comprehensive monitoring infrastructure for the Jellybuntu homelab.

## Overview

Phase 5 deploys a dedicated monitoring VM with Prometheus, Grafana, and Uptime Kuma to provide:

- **Metrics collection** from all VMs, containers, and network devices
- **Alerting** for resource exhaustion, service failures, and connectivity issues
- **Visualization** with Grafana dashboards
- **Availability monitoring** with Uptime Kuma status pages

**Independence**: Phase 5 can be deployed or removed without affecting existing services (Phases 1-4).

## Prerequisites

### Critical: Monitoring VM Provisioning via OpenTofu

The monitoring VM (VMID 500) **MUST be provisioned BEFORE running Phase 5 Ansible playbooks**.

**Command to provision monitoring VM:**

```bash
cd infrastructure/terraform
tofu apply -var="proxmox_password=<your_proxmox_password>"
```

Replace `<your_proxmox_password>` with your Proxmox root password. This command will:

1. Verify the monitoring VM configuration
2. Provision VMID 500 (192.168.10.16) with 4 cores, 6GB RAM, 64GB disk
3. Boot Ubuntu Server 24.04 LTS

**Verify provisioning succeeded:**

```bash
qm status 500  # Should return: status: running
```

If the VM is not running after tofu apply, manually start it:

```bash
qm start 500
```

### Additional Prerequisites

- **Phases 1-4 completed**: All VMs provisioned and services deployed
- **Proxmox host access**: `ansible@pve` API user configured
- **SOPS secrets**: Credentials stored in [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml)
- **Tailscale**: Optional but recommended for remote access

## What Gets Deployed

### Infrastructure

| Resource | Value |
|----------|-------|
| VM Name | monitoring |
| VMID | 500 |
| IP Address | 192.168.10.16 |
| Tailscale Hostname | monitoring.discus-moth.ts.net |
| CPU Cores | 4 |
| RAM | 6GB |
| Disk | 64GB |
| OS | Ubuntu Server 24.04 LTS |

### Services

1. **Prometheus** (port 9090) - Time-series metrics database
2. **Grafana** (port 3000) - Metrics visualization and dashboards
3. **Uptime Kuma** (port 3001) - Service availability monitoring
4. **SNMP Exporter** (port 9116) - Mikrotik network device metrics
5. **Blackbox Exporter** (port 9115) - HTTP/ICMP/DNS probes

### Exporters (deployed on all VMs)

1. **node_exporter** (port 9100) - Linux system metrics (CPU, RAM, disk, network)
2. **cAdvisor** (port 8180) - Docker container metrics

### Monitoring Scope

- **Proxmox Host**: Hardware health, hypervisor resources
- **6 Guest VMs**: System metrics, disk space, network
- **Docker Containers**: Per-container CPU, memory, I/O
- **Network Devices**: Mikrotik router (192.168.10.1) and switch (192.168.10.2) via SNMP
- **External Connectivity**: ICMP ping (Google DNS, Cloudflare DNS), DNS queries
- **Web Services**: HTTP availability checks for all Jellybuntu services

## Deployment Methods

### Option 1: Phase-Based Deployment (Recommended)

After provisioning the monitoring VM via OpenTofu, run the Phase 5 playbook:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase5-monitoring.yml
```

This runs in sequence:

1. Deploy exporters to all VMs (playbook 15)
2. Configure monitoring stack (playbook 16)

**Duration**: ~10-15 minutes

### Option 2: Individual Playbooks

For granular control or troubleshooting (after OpenTofu provisioning):

```bash
# Step 1: Deploy exporters on all existing VMs
./bin/runtime/ansible-run.sh playbooks/monitoring/exporters.yml

# Step 2: Deploy monitoring stack (Prometheus, Grafana, Uptime Kuma)
./bin/runtime/ansible-run.sh playbooks/monitoring/stack.yml
```

### Option 3: Manual Deployment (Not Recommended)

If Ansible is unavailable, you can manually provision the VM via Proxmox UI and deploy containers, but this is
error-prone and not documented here. Use the Ansible playbooks.

## Post-Deployment Verification

### 1. Verify VM is Running

```bash
# Via Proxmox CLI (from Proxmox host)
qm status 500

# Via Ansible
ansible monitoring -i inventory.ini -m ping

# Via SSH
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "uptime"
```

Expected: VM responds and shows uptime.

### 2. Verify Containers are Running

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "podman ps"
```

Expected output:

```text
NAMES              STATUS
prometheus         Up X minutes
grafana            Up X minutes
uptime-kuma        Up X minutes
snmp-exporter      Up X minutes
blackbox-exporter  Up X minutes
```

### 3. Verify Prometheus Targets

1. Open Prometheus: http://monitoring.discus-moth.ts.net:9090
2. Navigate to **Status → Targets**
3. Verify all targets are **UP** (green):
   - 1x Prometheus (self-monitoring)
   - 1x Proxmox host (jellybuntu)
   - 6x VM nodes (node_exporter)
   - 3x Docker containers (cAdvisor)
   - 2x SNMP devices (Mikrotik)
   - 2x ICMP probes (Google DNS, Cloudflare DNS)
   - 2x DNS probes (AdGuard Home, Quad9)
   - 9x HTTP probes (all web services)

**Total**: 26 targets

If any targets show **DOWN**:

- Check firewall rules on target VM: `sudo ufw status`
- Verify exporter is running: `systemctl status node_exporter` or `docker ps`
- Test connectivity: `curl http://target-vm:9100/metrics`

### 4. Verify Alert Rules Loaded

1. In Prometheus: **Status → Rules**
2. Verify rule groups loaded:
   - availability (2 rules)
   - cpu (2 rules)
   - memory (2 rules)
   - disk_space (2 rules)
   - disk_io (1 rule)
   - nfs (2 rules)
   - docker (3 rules)
   - services (2 rules)
   - network (3 rules)
   - btrfs (1 rule)
   - snmp_devices (2 rules)
   - system_load (1 rule)

**Total**: 23 alert rules

If rules not loaded:

- Check logs: `podman logs prometheus | grep -i rule`
- Verify file mounted: `podman inspect prometheus | grep alert_rules`

### 5. Access Grafana

1. Navigate to http://monitoring.discus-moth.ts.net:3000
2. Login with vault credentials (`vault_services_admin_username` / `vault_services_admin_password`)
3. Verify Prometheus datasource: Configuration → Data Sources → Prometheus (should show "Working")

### 6. Access Uptime Kuma

1. Navigate to http://monitoring.discus-moth.ts.net:3001
2. **First-time setup**: Create admin account (use vault credentials for consistency)
3. Uptime Kuma requires manual monitor configuration (see [Uptime Kuma Setup](../configuration/uptime-kuma-setup.md))

### 7. Verify Tailscale Connectivity (if using Tailscale)

```bash
tailscale status | grep monitoring
```

Expected: monitoring VM shows in Tailscale network with IP address.

### 8. Verify Firewall Rules

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "sudo ufw status"
```

Expected rules:

- SSH (22/tcp) from Tailscale network
- Prometheus (9090/tcp) from LAN + Tailscale
- Grafana (3000/tcp) from LAN + Tailscale
- Uptime Kuma (3001/tcp) from LAN + Tailscale
- SNMP Exporter (9116/tcp) from LAN + Tailscale
- Blackbox Exporter (9115/tcp) from LAN + Tailscale

## Post-Deployment Configuration

### 1. Configure Grafana Dashboards

See [Monitoring Stack Setup - Grafana Dashboards](../configuration/monitoring-stack-setup.md#grafana-dashboards)

**Recommended dashboards to import**:

- Node Exporter Full (ID: 1860) - Linux system metrics
- Docker Container Metrics (ID: 193) - cAdvisor metrics
- Blackbox Exporter (ID: 7587) - HTTP/ICMP probe results
- SNMP Stats for Mikrotik (ID: 11169) - Network device metrics

### 2. Set Up Notification Channels

See [Monitoring Stack Setup - Notification Channels](../configuration/monitoring-stack-setup.md#notification-channels)

**Options**:

- Grafana Alerts (recommended) - Configure in Grafana UI
- Alertmanager (advanced) - Requires additional setup

**Common integrations**:

- Discord webhooks
- Email (SMTP)
- Slack
- Telegram

### 3. Configure Uptime Kuma Monitors

See [Uptime Kuma Setup](../configuration/uptime-kuma-setup.md)

**Create monitors for**:

- All web services (Sonarr, Radarr, Jellyfin, etc.)
- Critical infrastructure (NAS, Proxmox)
- External connectivity (8.8.8.8, 1.1.1.1)

### 4. Create Status Page (Optional)

In Uptime Kuma:

1. Go to **Status Pages**
2. Create new status page: "Jellybuntu Services"
3. Add all monitors
4. Share public URL with users

## Troubleshooting Deployment Issues

### VM Provisioning Fails

**Error**: `Unable to create VM on Proxmox`

**Solutions**:

1. Verify Proxmox API credentials in secrets file
2. Check Proxmox host connectivity: `ping jellybuntu.discus-moth.ts.net`
3. Ensure VMID 500 is not already in use: `qm status 500`
4. Check Proxmox storage has space: `pvesm status`

### Podman Compose Fails

**Error**: `podman-compose: command not found`

**Solution**: Podman role should install podman-compose. Verify:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "which podman-compose"
```

If missing, install manually:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "sudo apt-get update && sudo apt-get install -y podman-compose"
```

### Containers Stop After SSH Logout

**Error**: Containers running during deployment, but stop when you log out

**Root Cause**: User lingering not enabled for rootless Podman

**Solution**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "sudo loginctl enable-linger ansible"
```

**Verification**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "loginctl show-user ansible | grep Linger"
```

Expected: `Linger=yes`

**Note**: This fix has been incorporated into the Podman role for future deployments.

### Prometheus Targets Down

**Error**: Some targets show **DOWN** in Prometheus UI

**Common Causes**:

1. Firewall blocking port 9100: Check `sudo ufw status` on target VM
2. node_exporter not running: Check `systemctl status node_exporter`
3. Network connectivity: Test `curl http://target-vm:9100/metrics`

**Solution for firewall**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@target-vm.discus-moth.ts.net \
  "sudo ufw allow from 192.168.10.16 to any port 9100 proto tcp"
```

**Solution for exporter**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@target-vm.discus-moth.ts.net \
  "sudo systemctl restart node_exporter"
```

### SNMP Targets Down

**Error**: Mikrotik router/switch targets DOWN

**Common Causes**:

1. SNMP not enabled on device
2. SNMPv3 credentials incorrect
3. SNMP exporter config file syntax error

**Solution**:

1. Verify SNMP enabled on Mikrotik: Login to device → IP → SNMP → Ensure community/auth is configured
2. Test SNMP query from monitoring VM:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "podman exec snmp-exporter /bin/snmp_exporter --config.file=/etc/snmp_exporter/snmp.yml"
   ```

3. Check SNMP exporter logs:

   ```bash
   podman logs snmp-exporter
   ```

### Grafana Datasource Connection Failed

**Error**: "Data source is not working"

**Solutions**:

1. Verify Prometheus container is running: `podman ps | grep prometheus`
2. Test Prometheus API:

   ```bash
   podman exec grafana wget -O- http://prometheus:9090/api/v1/query?query=up
   ```

3. Ensure datasource URL is `http://prometheus:9090` (container name, not IP)
4. Check Prometheus logs: `podman logs prometheus`

## Rollback Procedure

If Phase 5 deployment causes issues:

### 1. Stop Monitoring Services

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "cd /opt/monitoring && podman-compose down"
```

### 2. Remove Exporters from VMs

```bash
# Remove node_exporter
ansible all -i inventory.ini -b -m systemd -a "name=node_exporter state=stopped enabled=no"
ansible all -i inventory.ini -b -m file -a "path=/usr/local/bin/node_exporter state=absent"

# Remove cAdvisor containers
ansible all -i inventory.ini -m shell -a "docker stop cadvisor && docker rm cadvisor"
```

### 3. Remove Monitoring VM (Optional)

**Warning**: This deletes all monitoring data.

```bash
# From Proxmox host
qm stop 500
qm destroy 500
```

### 4. Remove from Inventory

Edit [`inventory.ini`](https://github.com/SilverDFlame/jellybuntu/blob/main/inventory.ini) and remove:

```ini
[monitoring]
monitoring ansible_host=monitoring.discus-moth.ts.net
```

Remove [`host_vars/monitoring.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/monitoring.yml)

## Resource Usage

**Monitoring VM**:

- CPU: ~10-15% idle, up to 50% during scrapes
- RAM: ~2-3GB used (Prometheus, Grafana, Uptime Kuma combined)
- Disk: ~5-10GB for 30 days of metrics retention
- Network: ~1-2 Mbps during scrape intervals

**Per-VM Overhead** (exporters):

- node_exporter: ~50MB RAM, negligible CPU
- cAdvisor: ~100MB RAM, <5% CPU

**Total Overhead**: ~500MB RAM across all VMs (acceptable for monitoring benefits)

## Maintenance

### Updating Monitoring Stack

1. Pull latest images:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "cd /opt/monitoring && podman-compose pull"
   ```

2. Recreate containers:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
     "cd /opt/monitoring && podman-compose up -d --force-recreate"
   ```

### Backing Up Monitoring Data

```bash
# Backup Prometheus data
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "podman volume export monitoring_prometheus_data > ~/prometheus-backup-$(date +%Y%m%d).tar"

# Backup Grafana data (dashboards, users, settings)
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "podman volume export monitoring_grafana_data > ~/grafana-backup-$(date +%Y%m%d).tar"

# Backup Uptime Kuma data (monitors, users, settings)
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "podman volume export monitoring_uptime_kuma_data > ~/uptime-kuma-backup-$(date +%Y%m%d).tar"
```

Download backups to local machine:

```bash
scp -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net:~/*-backup-*.tar ./backups/
```

### Adjusting Metrics Retention

Edit [`services/compose/monitoring/docker-compose.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/monitoring/docker-compose.yml):

```yaml
services:
  prometheus:
    command:
      - '--storage.tsdb.retention.time=15d'  # Reduce from 30d to 15d
```

Redeploy:

```bash
# Copy updated docker-compose.yml, then restart
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net \
  "cd /opt/monitoring && podman-compose up -d --force-recreate prometheus"
```

## Next Steps

1. **Configure Grafana Dashboards**: Import recommended dashboards (see [Monitoring Stack Setup](../configuration/monitoring-stack-setup.md))
2. **Set Up Alerts**: Configure notification channels in Grafana or Alertmanager
3. **Create Uptime Kuma Monitors**: Add all services to availability monitoring
4. **Test Alerting**: Trigger test alerts to verify notifications work
5. **Customize**: Add custom dashboards, adjust alert thresholds, create status pages

## See Also

- [Monitoring Stack Setup](../configuration/monitoring-stack-setup.md) - Prometheus, Grafana, and notification configuration
- [Uptime Kuma Setup](../configuration/uptime-kuma-setup.md) - Availability monitoring and status pages
- [Troubleshooting: Monitoring](../troubleshooting/monitoring.md) - Common monitoring issues
- [Architecture](../architecture.md) - Infrastructure overview
- [Playbooks Reference](../reference/playbooks.md) - Playbook details

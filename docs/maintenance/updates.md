# Service Updates and Maintenance

Guide to updating services, managing Docker containers, and maintaining system security through automated and manual updates.

## Overview

The Jellybuntu infrastructure uses a hybrid update strategy:

- **Automated**: Security updates via unattended-upgrades (Phase 4)
- **Manual**: Docker container updates, major version upgrades
- **Scheduled**: Regular maintenance windows for updates

## Update Strategy

### Philosophy

**Security First**: Critical security patches applied automatically
**Stability**: Docker containers pinned to stable versions
**Control**: Major upgrades performed manually during maintenance windows

### Update Frequency

**Daily** (Automatic):

- Ubuntu security updates
- Critical bug fixes

**Weekly** (Manual):

- Docker container updates
- Service configuration updates

**Monthly** (Manual):

- System package updates
- Kernel updates (requires reboot)

**As Needed**:

- Major version upgrades
- Feature updates

## Docker Container Updates

Most services run in Docker containers. Updates require pulling new images and recreating containers.

### Media Services VM (192.168.30.13)

Services: Sonarr, Radarr, Prowlarr, Jellyseerr, Byparr, Recyclarr

**Update all services**:

```bash
# SSH to media services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Navigate to compose directory
cd ~/docker-compose

# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Verify services are running
docker compose ps
```

**Update single service**:

```bash
# Pull specific service
docker compose pull sonarr

# Recreate only that service
docker compose up -d sonarr

# Check logs
docker compose logs -f sonarr
```

### Download Clients VM (192.168.30.14)

Services: qBittorrent, SABnzbd

**Update process**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

cd ~/docker-compose

# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d

# Verify
docker compose ps
docker compose logs qbittorrent
docker compose logs sabnzbd
```

### Home Assistant VM (192.168.20.10)

**Update Home Assistant**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@home-assistant.discus-moth.ts.net

cd ~/docker-compose

# Pull latest stable image
docker compose pull

# Recreate container
docker compose up -d

# Watch startup
docker compose logs -f homeassistant
```

⚠️ **Note**: Home Assistant updates can introduce breaking changes. Review release notes first!

### Docker Update Best Practices

**Before Updating**:

1. Check release notes for breaking changes
2. Backup configuration files
3. Note current version: `docker compose images`

**During Update**:

1. Pull images: `docker compose pull`
2. Recreate containers: `docker compose up -d`
3. Watch logs: `docker compose logs -f <service>`

**After Update**:

1. Verify service accessibility
2. Check logs for errors
3. Test core functionality
4. Confirm API integrations still work

## Jellyfin Updates

Jellyfin runs natively (not in Docker) and uses apt package management.

### Update Jellyfin

```bash
# SSH to Jellyfin VM
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Update package list
sudo apt update

# Check available Jellyfin version
apt list --upgradable | grep jellyfin

# Upgrade Jellyfin
sudo apt upgrade jellyfin -y

# Restart service
sudo systemctl restart jellyfin

# Verify status
sudo systemctl status jellyfin
```

### Access Web UI

http://jellyfin.discus-moth.ts.net:8096

**Post-Update Checks**:

- Login successful
- Libraries accessible
- Transcoding working
- Plugins functional

## System Updates

Ubuntu base system updates for all VMs.

### Manual System Update

```bash
# SSH to VM
ssh -i ~/.ssh/ansible_homelab ansible@<vm-hostname>.discus-moth.ts.net

# Update package lists
sudo apt update

# Show available updates
apt list --upgradable

# Upgrade all packages
sudo apt upgrade -y

# Clean up old packages
sudo apt autoremove -y
sudo apt autoclean

# Check if reboot required
[ -f /var/run/reboot-required ] && echo "Reboot required" || echo "No reboot needed"
```

### Update All VMs Script

Create helper script to update all VMs:

```bash
#!/bin/bash
# save as ~/update-all-vms.sh

VMS=(
  "home-assistant"
  "satisfactory-server"
  "nas"
  "jellyfin"
  "media-services"
  "download-clients"
)

for vm in "${VMS[@]}"; do
  echo "=== Updating $vm ==="
  ssh -i ~/.ssh/ansible_homelab ansible@${vm}.discus-moth.ts.net \
    "sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y"
done
```

**Usage**:

```bash
chmod +x ~/update-all-vms.sh
./update-all-vms.sh
```

## Unattended Upgrades

Configured during Phase 4 to automatically install security updates.

### Configuration

**File**: `/etc/apt/apt.conf.d/50unattended-upgrades`

**What Gets Updated**:

- Ubuntu security updates
- Ubuntu stable updates
- Critical bug fixes

**What Doesn't**:

- Major version upgrades (e.g., Ubuntu 22.04 → 24.04)
- Third-party repositories (Docker, Jellyfin)
- Packages requiring manual intervention

### Check Unattended Upgrades Status

```bash
# Check service status
systemctl status unattended-upgrades

# View recent updates
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log

# View update history
sudo cat /var/log/apt/history.log | grep "^Start-Date" -A 5
```

### Manual Trigger

```bash
# Dry run (show what would be updated)
sudo unattended-upgrade --dry-run --debug

# Actually run updates
sudo unattended-upgrade --debug
```

### Configuration Options

**Enable auto-reboot** (optional):

```bash
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# Uncomment and set:
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
```

⚠️ **Note**: Auto-reboot can cause unexpected downtime. Enable only for non-critical VMs.

### Disable Unattended Upgrades

If needed (not recommended):

```bash
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades
```

## Update Procedures

### Weekly Maintenance Window

**Recommended Schedule**: Sunday 2:00 AM local time

**Procedure**:

1. Check for Docker image updates
2. Pull and recreate containers
3. Verify service functionality
4. Check logs for errors
5. Update documentation if configuration changed

**Checklist**:

```bash
# Media Services
ssh ansible@media-services.discus-moth.ts.net "cd ~/docker-compose && docker compose pull && docker compose up -d"

# Download Clients
ssh ansible@download-clients.discus-moth.ts.net "cd ~/docker-compose && docker compose pull && docker compose up -d"

# Jellyfin
ssh ansible@jellyfin.discus-moth.ts.net "sudo apt update && sudo apt upgrade jellyfin -y && sudo systemctl restart jellyfin"

# Home Assistant
ssh ansible@home-assistant.discus-moth.ts.net "cd ~/docker-compose && docker compose pull && docker compose up -d"

# Verify all services
curl -I http://media-services.discus-moth.ts.net:8989  # Sonarr
curl -I http://jellyfin.discus-moth.ts.net:8096        # Jellyfin
curl -I http://download-clients.discus-moth.ts.net:8080 # qBittorrent
```

### Monthly System Updates

**Schedule**: First Sunday of month, 2:00 AM

**Procedure**:

1. Run system updates on all VMs
2. Check for kernel updates
3. Reboot VMs if required
4. Verify all services restart correctly
5. Check Proxmox host updates

**Script**:

```bash
#!/bin/bash
# Monthly update script

VMS=(
  "home-assistant"
  "satisfactory-server"
  "nas"
  "jellyfin"
  "media-services"
  "download-clients"
)

for vm in "${VMS[@]}"; do
  echo "=== Updating $vm ==="
  ssh -i ~/.ssh/ansible_homelab ansible@${vm}.discus-moth.ts.net << 'EOF'
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean

    # Check if reboot needed
    if [ -f /var/run/reboot-required ]; then
      echo "REBOOT REQUIRED for $(hostname)"
    fi
EOF
done

echo "=== Update Summary ==="
echo "Check which VMs require reboot and schedule accordingly"
```

## Rollback Procedures

### Docker Container Rollback

If an update breaks a service, rollback to previous image:

**Find previous version**:

```bash
# List all images including old ones
docker images --all | grep sonarr
```

**Rollback to specific version**:

```bash
# Edit docker-compose.yml
nano ~/docker-compose/docker-compose.yml

# Change from:
# image: lscr.io/linuxserver/sonarr:latest
# To:
# image: lscr.io/linuxserver/sonarr:4.0.0

# Recreate with old image
docker compose up -d sonarr
```

**Alternative**: Use previous container (if not yet removed)

```bash
# List all containers including stopped
docker ps -a

# Start old container
docker start <container-id>
```

### Jellyfin Rollback

**Downgrade to previous version**:

```bash
# Check available versions
apt-cache madison jellyfin

# Install specific version
sudo apt install jellyfin=10.8.13-1 -y

# Hold package to prevent auto-upgrade
sudo apt-mark hold jellyfin

# Restart
sudo systemctl restart jellyfin
```

**Restore from backup** (if configuration changed):

```bash
# Stop service
sudo systemctl stop jellyfin

# Restore config
sudo cp -r /var/lib/jellyfin.backup/* /var/lib/jellyfin/

# Start service
sudo systemctl start jellyfin
```

### System Package Rollback

Difficult to rollback system packages. Better approach:

**VM Snapshot Before Updates**:

```bash
# On Proxmox host
ssh root@jellybuntu.discus-moth.ts.net

# Create snapshot before update
qm snapshot <vmid> pre-update-$(date +%Y%m%d)

# List snapshots
qm listsnapshot <vmid>

# Rollback if needed
qm rollback <vmid> pre-update-20241023
```

## Monitoring Updates

### Check Update Status

**Docker containers**:

```bash
# List current images and versions
docker compose images

# Check for available updates (manual)
docker compose pull --dry-run
```

**System packages**:

```bash
# Check for updates
sudo apt update
apt list --upgradable

# Show security updates
apt list --upgradable | grep -i security
```

**Unattended upgrades**:

```bash
# Check last run
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -50

# Check what's pending
sudo unattended-upgrade --dry-run
```

### Update Logs

**Docker**:

```bash
# Container logs
docker compose logs <service>

# Recent events
docker events --since 1h
```

**Jellyfin**:

```bash
# Service logs
sudo journalctl -u jellyfin -n 100

# Jellyfin app logs
sudo tail -f /var/log/jellyfin/log_*.txt
```

**System**:

```bash
# Apt history
cat /var/log/apt/history.log

# Unattended upgrades
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log

# System journal
sudo journalctl -xe
```

## Best Practices

### ✅ Update Strategy

- **Test first**: Update non-critical services before critical ones
- **Backup configs**: Copy configuration files before major updates
- **Read release notes**: Check for breaking changes
- **One at a time**: Update services individually, not all at once
- **Verify functionality**: Test services after each update

### ✅ Scheduling

- **Maintenance windows**: Schedule updates during low-usage periods
- **Stagger updates**: Don't update all VMs simultaneously
- **Reboot planning**: Schedule reboots to minimize downtime
- **Notification**: Inform users of planned maintenance

### ✅ Monitoring

- **Check logs**: Review update logs regularly
- **Failed updates**: Address failed updates promptly
- **Security patches**: Prioritize security updates
- **Version tracking**: Maintain list of service versions

### ⚠️ Avoid

- **Auto-updates for Docker**: Can break services with breaking changes
- **Skipping release notes**: May miss important migration steps
- **No backups**: Always backup before major updates
- **Rebooting all VMs**: Stagger reboots to maintain availability

## Version Pinning

### Image Versioning Strategy

The Jellybuntu infrastructure uses a **hybrid versioning approach** based on service criticality and update characteristics:

#### ✅ Using `latest` Tag (LinuxServer.io Images)

**Services using `latest`**:

- Sonarr, Radarr, Prowlarr (lscr.io/linuxserver/*)
- qBittorrent, SABnzbd (lscr.io/linuxserver/*)
- Bazarr (lscr.io/linuxserver/*)

**Reasoning**:

1. **Controlled release cadence**: LinuxServer.io maintains stable release channels
2. **Comprehensive testing**: Images undergo extensive testing before release
3. **Version awareness**: Containers maintain application version internally (database migrations, config updates)
4. **Backward compatibility**: LinuxServer.io prioritizes compatibility across updates
5. **Security patches**: Automatically receive base image security updates
6. **Low breaking change risk**: Application updates rarely break configurations

**Trade-offs**:

- **Pro**: Always get latest features and security patches without manual intervention
- **Pro**: Simplified maintenance - just `docker compose pull && up -d`
- **Con**: Potential for unexpected updates during scheduled maintenance
- **Con**: Requires monitoring release notes for major version changes

**Mitigation Strategy**:

- Review LinuxServer.io Discord/GitHub before weekly updates
- Test updates on non-critical services first
- Keep previous Docker images cached for quick rollback
- Maintain configuration backups

#### 🔒 Pinned Versions (Critical & Third-Party Services)

**Services using pinned versions**:

**DNS Infrastructure** (Critical - network-wide impact):

- **AdGuard Home** (v0.107.68) - DNS filtering and ad blocking
  - Config schema changes can break functionality
  - Upstream DNS syntax/behavior changes affect resolution
  - Filter list compatibility issues across versions
  - DoT/DoH protocol changes can break clients
- **Unbound** (1.24.1-0) - Recursive DNS resolver
  - Configuration syntax changes break unbound.conf
  - DNSSEC validation updates can cause resolution failures
  - Performance tuning behavior changes across versions

**Monitoring Stack** (Complex integrations):

- **Prometheus** (v3.5.0) - Metrics collection
  - Query language changes break dashboards
  - Data model changes affect retention
- **Grafana** (12.2.0) - Visualization
  - Dashboard JSON format changes
  - Plugin compatibility issues
- **Uptime Kuma** (major version 2) - Service monitoring
  - Notification configuration changes
- **SNMP Exporter** (v0.29.0) - SNMP metrics
- **Blackbox Exporter** (v0.27.0) - Endpoint probing

**VPN Infrastructure** (Critical - download security):

- **Gluetun** (v3.41.0) - VPN client
  - VPN provider API changes can break port forwarding
  - Firewall rule changes can expose traffic
  - Critical for protecting torrent traffic

**Media Management Tools** (Third-party):

- **Jellyseerr** (2.1.0) - Request management
- **Homarr** (0.16.0) - Service dashboard
- **Huntarr** (8.2.10) - Content discovery
- **Recyclarr** (7.4.1) - Quality profile sync
- **Unpackerr** (0.15.0) - Archive extraction
- **Tdarr** (2.27.01) - Transcoding automation

**Specialized Services**:

- **Byparr** (v2.0.1) - Cloudflare bypass (Camoufox-based)
  - Bypass mechanism fragile across updates
  - Only update when Cloudflare blocks current version

**When to pin versions**:

1. **Infrastructure services** - DNS, monitoring, networking
2. **Services with breaking config changes** - Config schema not backward compatible
3. **Complex integrations** - Dashboards, queries, API consumers that may break
4. **Specialized functionality** - Security-sensitive or fragile mechanisms
5. **Production-critical** - Services requiring change control

**Update cadence for pinned versions**:

- **Quarterly reviews** - Check for new stable releases
- **Security patches** - Update immediately for CVEs
- **Feature updates** - Plan and test during maintenance windows
- **6-month window** - Versions chosen to allow 5-6 months before forced update

#### 🔄 Semi-Pinned (Major Version Tags)

**Services using major version tags**:

- **Uptime Kuma** (image: `louislam/uptime-kuma:2`)
  - Locks to major version 2.x.x, gets minor/patch updates
  - Balance between stability and security patches

**Benefits**:

- Automatically receive patch releases (2.1.0 → 2.1.1)
- Avoid breaking changes from major versions (2.x.x → 3.0.0)
- Good compromise for services with semantic versioning

#### 📊 Current Image Tag Summary

| Service | Image Tag | Strategy | Rationale |
|---------|-----------|----------|-----------|
| **Sonarr** | `latest` | Auto-update | LinuxServer.io stable releases |
| **Radarr** | `latest` | Auto-update | LinuxServer.io stable releases |
| **Prowlarr** | `latest` | Auto-update | LinuxServer.io stable releases |
| **qBittorrent** | `latest` | Auto-update | LinuxServer.io stable releases |
| **SABnzbd** | `latest` | Auto-update | LinuxServer.io stable releases |
| **Bazarr** | `latest` | Auto-update | LinuxServer.io stable releases |
| **Jellyseerr** | `2.1.0` | **Pinned** | Third-party, test before upgrading |
| **Recyclarr** | `7.4.1` | **Pinned** | Third-party, config sync stability |
| **Unpackerr** | `0.15.0` | **Pinned** | Third-party, extraction stability |
| **Homarr** | `0.16.0` | **Pinned** | Dashboard, widget compatibility |
| **Tdarr** | `2.27.01` | **Pinned** | Transcoding, complex workflows |
| **Huntarr** | `8.2.10` | **Pinned** | Content discovery, API stability |
| **Gluetun** | `v3.41.0` | **Pinned** | VPN critical, port forwarding fragile |
| **AdGuard Home** | `v0.107.68` | **Pinned** | Critical DNS infra, config changes |
| **Unbound** | `1.24.1-0` | **Pinned** | Critical DNS resolver, DNSSEC fragile |
| **Byparr** | `2.0.1` | **Pinned** | Cloudflare bypass, fragile |
| **Prometheus** | `v3.5.0` | **Pinned** | Query compatibility |
| **Grafana** | `12.2.0` | **Pinned** | Dashboard compatibility |
| **Uptime Kuma** | `2` | **Major pin** | Semantic versioning |
| **SNMP Exporter** | `v0.29.0` | **Pinned** | Stack consistency |
| **Blackbox Exporter** | `v0.27.0` | **Pinned** | Stack consistency |

### Docker Images

Pin to specific versions for stability:

**docker-compose.yml**:

```yaml
services:
  sonarr:
    image: lscr.io/linuxserver/sonarr:4.0.0  # Pinned version
    # Instead of:
    # image: lscr.io/linuxserver/sonarr:latest
```

**Benefits**:

- Predictable updates
- Avoid breaking changes
- Easier rollback

**Drawbacks**:

- Manual version management
- Security patches delayed

### Updating Pinned Versions

When updating infrastructure services (DNS, monitoring):

**Process**:

1. Check release notes for breaking changes
2. Review changelogs for config schema updates
3. Test in non-production environment if possible
4. Backup current configurations
5. Update version in role defaults ([`roles/*/defaults/main.yml`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles))
6. Re-run Ansible playbook
7. Verify functionality
8. Monitor logs for 24 hours

**Example - Updating AdGuard Home**:

```bash
# Edit version
nano roles/adguard_home/defaults/main.yml
# Change: adguard_home_version: "v0.107.68"
# To:     adguard_home_version: "v0.107.69"

# Re-run playbook
./bin/runtime/ansible-run.sh playbooks/networking/adguard-home.yml

# Verify
ssh ansible@nas.discus-moth.ts.net "docker exec adguardhome /opt/adguardhome/AdGuardHome --version"
dig @192.168.30.15 google.com  # Test resolution
```

**Example - Updating Unbound**:

```bash
# Edit version
nano roles/unbound/defaults/main.yml
# Change: unbound_version: "1.24.1-0"
# To:     unbound_version: "1.24.2-0"

# Re-run playbook
./bin/runtime/ansible-run.sh playbooks/networking/unbound.yml

# Verify
ssh ansible@nas.discus-moth.ts.net "docker exec unbound unbound -V"
dig @192.168.30.15 -p 5335 google.com  # Test direct query
```

### System Packages

Hold packages at specific versions:

```bash
# Hold Jellyfin at current version
sudo apt-mark hold jellyfin

# Show held packages
apt-mark showhold

# Unhold to allow updates
sudo apt-mark unhold jellyfin
```

## Updating Ansible Deployment

If updating infrastructure configuration via Ansible:

### Re-run Playbooks

```bash
# Update specific service
./bin/runtime/ansible-run.sh playbooks/services/media-services.yml

# Update Jellyfin config
./bin/runtime/ansible-run.sh playbooks/services/jellyfin.yml

# Update all (safe, idempotent)
./bin/runtime/ansible-run.sh playbooks/main.yml
```

### Configuration Changes

**Modify variables**:

```bash
# Edit VM-specific config
nano host_vars/media-services.yml

# Edit global variables
nano group_vars/all.yml

# Edit secrets file (credentials)
sops group_vars/all.sops.yaml
```

**Apply changes**:

```bash
# Re-run affected playbook
./bin/runtime/ansible-run.sh playbooks/<playbook>.yml
```

## Troubleshooting

### Docker Container Won't Start After Update

**Symptoms**: Container exits immediately after `docker compose up -d`

**Solution**:

```bash
# Check logs
docker compose logs <service>

# Common issues:
# 1. Configuration incompatibility
# 2. Permission issues
# 3. Port conflicts

# Rollback to previous version
# Edit docker-compose.yml with old image tag
docker compose up -d <service>
```

### Jellyfin Update Failed

**Symptoms**: `apt upgrade jellyfin` fails

**Solution**:

```bash
# Check for held packages
apt-mark showhold

# Check for conflicts
sudo apt install -f

# Check repository
sudo apt update

# View detailed error
sudo apt install --reinstall jellyfin
```

### Service Not Working After Update

**Symptoms**: Web UI inaccessible, API errors

**Solution**:

```bash
# Check service status
docker compose ps
sudo systemctl status jellyfin

# Check logs
docker compose logs -f <service>
sudo journalctl -u jellyfin -n 100

# Verify network
curl -I http://localhost:<port>

# Check configuration
docker compose config
```

### Unattended Upgrades Not Running

**Symptoms**: No updates in logs, security patches not applied

**Solution**:

```bash
# Check service
systemctl status unattended-upgrades

# Check configuration
sudo cat /etc/apt/apt.conf.d/50unattended-upgrades

# Manually trigger
sudo unattended-upgrade --debug

# Check for errors
sudo journalctl -u unattended-upgrades -n 50
```

## Emergency Update Procedures

### Critical Security Patch

If critical security vulnerability announced:

**Immediate Actions**:

1. Assess impact (which services affected)
2. Check if patch available
3. Apply updates immediately
4. Verify patch applied
5. Monitor for exploitation attempts

**Process**:

```bash
# Update package lists
sudo apt update

# Check for specific package update
apt list --upgradable | grep <package>

# Install immediately
sudo apt install <package> -y

# Or run unattended upgrades
sudo unattended-upgrade --debug

# Verify version
<package> --version
```

### Mass Update After Extended Downtime

If system hasn't been updated in weeks/months:

**Procedure**:

1. Create VM snapshots (on Proxmox)
2. Update one VM as test
3. Verify functionality
4. Update remaining VMs
5. Address any issues

**Commands**:

```bash
# Proxmox: Create snapshots
ssh root@jellybuntu.discus-moth.ts.net
for vm in 100 200 300 400 401 402; do
  qm snapshot $vm pre-mass-update-$(date +%Y%m%d)
done

# Update test VM (media-services)
ssh ansible@media-services.discus-moth.ts.net
sudo apt update && sudo apt upgrade -y
cd ~/docker-compose && docker compose pull && docker compose up -d

# Verify and update others
# ... repeat for each VM
```

## Reference

### Related Documentation

- [Unattended Upgrades Configuration](../configuration/security.md) - Security settings
- Docker Compose Files ([`services/compose/`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/)) - Service definitions
- [Troubleshooting](troubleshooting.md) - General troubleshooting
- [Service-Specific Troubleshooting](../troubleshooting/common-issues.md) - Per-service guides

### External Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Jellyfin Installation](https://jellyfin.org/docs/general/installation/)
- [Ubuntu Unattended Upgrades](https://help.ubuntu.com/community/AutomaticSecurityUpdates)
- [LinuxServer.io Images](https://docs.linuxserver.io/) - Docker image documentation

## Summary

**Update Strategy**:

- Automated security updates via unattended-upgrades
- Manual Docker container updates weekly
- Monthly system updates with reboot planning
- Version pinning for stability

**Key Commands**:

```bash
# Docker updates
docker compose pull && docker compose up -d

# Jellyfin update
sudo apt update && sudo apt upgrade jellyfin -y

# System update
sudo apt update && sudo apt upgrade -y

# Check unattended upgrades
systemctl status unattended-upgrades
```

**Best Practices**:

- Read release notes before updating
- Backup configurations before major changes
- Update during maintenance windows
- Verify functionality after updates
- Monitor logs for issues

Your services stay secure, stable, and up-to-date!

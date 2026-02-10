# UniFi Network Controller Configuration

UniFi Network Controller provides centralized management for Ubiquiti UniFi network devices including access points,
switches, and gateways.

> **IMPORTANT**: UniFi Controller runs as **Quadlet/Podman containers** (rootless) on the unifi-controller VM
> (192.168.0.19). Use `systemctl --user` commands for service management.

## Overview

- **VM**: unifi-controller (VMID 800, 192.168.0.19)
- **Ports**: 8443 (Web UI), 8080 (Device Inform), 3478 (STUN), 10001 (Discovery)
- **Deployment**: Quadlet/Podman with MongoDB 7.0
- **Playbook**: [`playbooks/services/unifi-controller.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/unifi-controller.yml)

## Access

- **Web UI**: https://unifi-controller.discus-moth.ts.net:8443
- **Local Network**: https://192.168.0.19:8443
- **Device Inform URL**: http://192.168.0.19:8080/inform

## Port Requirements

| Port | Protocol | Purpose | Access |
|------|----------|---------|--------|
| 8443 | TCP | Web UI (HTTPS) | Local + Tailscale |
| 8080 | TCP | Device Inform | Local only |
| 3478 | UDP | STUN | Local only |
| 10001 | UDP | Device Discovery | Local only |
| 6789 | TCP | Speed Test | Local only |
| 8843 | TCP | HTTPS Portal Redirect | Optional |
| 8880 | TCP | HTTP Portal Redirect | Optional |

## Deployment

### Via Ansible Playbook (Recommended)

```bash
# Deploy UniFi Controller
./bin/runtime/ansible-run.sh playbooks/services/unifi-controller.yml
```

The playbook:

1. Creates required directories and permissions
2. Deploys MongoDB 7.0 container (Quadlet)
3. Deploys UniFi Controller container (Quadlet)
4. Configures firewall rules
5. Sets up systemd user services with lingering

### Container Stack

The deployment uses two containers:

**MongoDB 7.0:**

- Image: `docker.io/library/mongo:7.0`
- Data: `/opt/unifi/mongodb`
- Network: Shared pod with UniFi Controller

**UniFi Controller:**

- Image: `ghcr.io/linuxserver/unifi-network-application:latest`
- Config: `/opt/unifi/config`
- Logs: `/opt/unifi/logs`

### Quadlet Files

Located at `~/.config/containers/systemd/`:

```text
~/.config/containers/systemd/
├── unifi-mongo.container
├── unifi-controller.container
└── unifi.pod
```

## Initial Setup (First-Time Configuration)

### 1. Access the Setup Wizard

1. Navigate to https://unifi-controller.discus-moth.ts.net:8443
2. Accept the self-signed certificate warning
3. Complete the setup wizard:
   - Create admin account
   - Configure controller name
   - Skip cloud account linking (optional)

### 2. Configure Controller Settings

1. Go to **Settings → System**
2. Set **Controller Hostname/IP**: `192.168.0.19`
3. Enable **Override Inform Host** if using Tailscale access

### 3. Set Inform URL for Device Adoption

For devices to find the controller:

1. Go to **Settings → System → Advanced**
2. Set **Inform Host**: `192.168.0.19`
3. Port should remain `8080`

## Device Adoption

### Automatic Discovery

Devices on the same Layer 2 network are automatically discovered:

1. Power on UniFi device
2. Device appears in **Devices** list as "Pending Adoption"
3. Click **Adopt**
4. Wait for provisioning to complete

### Manual Adoption (SSH)

For devices not automatically discovered:

```bash
# SSH to the UniFi device (default password: ubnt)
ssh ubnt@<device-ip>

# Set inform URL
set-inform http://192.168.0.19:8080/inform
```

### Adoption from Another Controller

1. SSH to device and run:

   ```bash
   set-inform http://192.168.0.19:8080/inform
   ```

2. Device will appear in new controller
3. May need to "Forget" device on old controller first

## Service Management

### Check Status

```bash
# Check pod status
systemctl --user status pod-unifi

# Check individual containers
systemctl --user status unifi-controller
systemctl --user status unifi-mongo
```

### View Logs

```bash
# Follow UniFi Controller logs
journalctl --user -u unifi-controller -f

# MongoDB logs
journalctl --user -u unifi-mongo -f

# Application logs directly
tail -f /opt/unifi/logs/server.log
```

### Start/Stop/Restart

```bash
# Restart entire stack
systemctl --user restart pod-unifi

# Restart just the controller
systemctl --user restart unifi-controller

# Stop all services
systemctl --user stop pod-unifi

# Start all services
systemctl --user start pod-unifi
```

## MongoDB Configuration

### Database Location

- Data directory: `/opt/unifi/mongodb`
- Database name: `unifi`
- Collections: Sites, devices, events, statistics

### Maintenance Commands

```bash
# Enter MongoDB shell
podman exec -it unifi-mongo mongosh

# Check database size
podman exec unifi-mongo mongosh --eval "db.stats()"

# Compact database (reduces disk usage)
podman exec unifi-mongo mongosh unifi --eval "db.runCommand({compact: 'event'})"
```

### Prune Old Data

UniFi stores extensive statistics. To manage growth:

1. Go to **Settings → System → Maintenance**
2. Adjust data retention periods:
   - Events: 7 days (default)
   - Alerts: 30 days
   - Statistics: 90 days

## Backup and Restore

### Automatic Backups

UniFi creates automatic backups:

1. Go to **Settings → System → Backup**
2. Configure:
   - **Enable Auto Backup**: Yes
   - **Retention**: 30 days
   - **Occurrence**: Monthly

Backups stored at: `/opt/unifi/config/data/backup/autobackup/`

### Manual Backup

1. Go to **Settings → System → Backup**
2. Click **Download Backup**
3. Save `.unf` file securely

### Command-Line Backup

```bash
# Copy backup files
cp -r /opt/unifi/config/data/backup/ ~/unifi-backups-$(date +%Y%m%d)/
```

### Restore from Backup

1. Fresh install: Upload `.unf` file during setup wizard
2. Existing install:
   - Go to **Settings → System → Backup**
   - Click **Restore** and upload `.unf` file
   - Controller will restart

## SSL Certificate Configuration

### Using Let's Encrypt (via Certbot)

```bash
# Generate certificate
certbot certonly --standalone -d unifi-controller.yourdomain.com

# Convert and import to UniFi
openssl pkcs12 -export -in fullchain.pem -inkey privkey.pem \
  -out unifi.p12 -name unifi -password pass:aircontrolenterprise

# Import to UniFi keystore
keytool -importkeystore -srckeystore unifi.p12 -srcstoretype PKCS12 \
  -srcstorepass aircontrolenterprise -destkeystore /opt/unifi/config/data/keystore \
  -deststorepass aircontrolenterprise
```

### Using Self-Signed (Default)

The default self-signed certificate works but shows browser warnings. For internal use, this is acceptable.

## Network Configuration Best Practices

### VLAN Setup

1. Define VLANs in **Settings → Networks**
2. Assign SSIDs to VLANs for traffic isolation
3. Configure inter-VLAN routing as needed

### Wireless Networks

1. Go to **Settings → WiFi**
2. Create networks with:
   - Descriptive names
   - Strong WPA3/WPA2 passwords
   - Appropriate band steering
   - Guest network isolation if needed

### Firewall Rules

1. Go to **Settings → Firewall & Security**
2. Create rules for:
   - IoT device isolation
   - Guest network restrictions
   - Port forwarding

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Device stuck "Adopting" | SSH to device, run `set-inform` manually |
| Can't access Web UI | Check container status, verify port 8443 open |
| Devices not discovered | Verify controller on same L2 network or use L3 adoption |
| MongoDB connection error | Check `unifi-mongo` container status and logs |
| High memory usage | Reduce data retention periods, compact database |
| Firmware upgrade fails | Check internet connectivity, try manual upgrade |
| Slow UI performance | Compact MongoDB, check VM resources |

### Common Log Locations

```text
/opt/unifi/logs/server.log         # Main application log
/opt/unifi/logs/mongod.log         # MongoDB operations
/opt/unifi/config/data/sites/      # Site-specific data
```

### Reset Controller Password

If locked out of the admin account:

```bash
# Enter MongoDB shell
podman exec -it unifi-mongo mongosh unifi

# Reset password (replace 'newpassword' with your password)
db.admin.updateOne(
  { "name": "admin" },
  { $set: { "x_shadow": "$6$rounds=5000$..." } }
)
```

Or restore from a backup with known credentials.

## See Also

- [Service Endpoints](service-endpoints.md) - All service URLs
- [VM Specifications](../reference/vm-specifications.md) - Hardware specifications
- [Networking Configuration](networking.md) - Network architecture
- [UniFi Documentation](https://help.ui.com/hc/en-us/categories/200320654-UniFi) - Official documentation

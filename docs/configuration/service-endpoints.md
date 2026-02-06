
# Service Endpoints

All service URLs and access methods for the Jellybuntu homelab.

## Quick Reference

### Via Tailscale (Recommended for Remote Access)

- **Home Assistant**: http://home-assistant.discus-moth.ts.net:8123
- **Satisfactory**: satisfactory-server.discus-moth.ts.net:7777
- **Jellyfin**: http://jellyfin.discus-moth.ts.net:8096
- **Tdarr**: http://jellyfin.discus-moth.ts.net:8265
- **Sonarr**: http://media-services.discus-moth.ts.net:8989
- **Radarr**: http://media-services.discus-moth.ts.net:7878
- **Prowlarr**: http://media-services.discus-moth.ts.net:9696
- **Jellyseerr**: http://media-services.discus-moth.ts.net:5055
- **Bazarr**: http://media-services.discus-moth.ts.net:6767
- **Huntarr**: http://media-services.discus-moth.ts.net:9705
- **Homarr**: http://media-services.discus-moth.ts.net:7575
- **Byparr**: http://media-services.discus-moth.ts.net:8191
- **qBittorrent**: http://download-clients.discus-moth.ts.net:8080
- **SABnzbd**: http://download-clients.discus-moth.ts.net:8081
- **AdGuard Home**: http://nas.discus-moth.ts.net:80 (DNS: 100.65.73.89:53)
- **Nexus Repository**: http://nas.discus-moth.ts.net:8081 (Registry: nas.discus-moth.ts.net:5001)
- **NAS**: http://nas.discus-moth.ts.net (Btrfs RAID1 storage, 192.168.0.15)
- **Prometheus**: http://monitoring.discus-moth.ts.net:9090
- **Alertmanager**: http://monitoring.discus-moth.ts.net:9093
- **Grafana**: http://monitoring.discus-moth.ts.net:3000
- **Uptime Kuma**: http://oracle-monitoring.discus-moth.ts.net:3001 (External monitoring on Oracle Cloud)
- **Woodpecker CI**: https://automation.discus-moth.ts.net (Web UI via Tailscale Funnel)
- **Lancache**: http://lancache.discus-moth.ts.net:80 (Game download cache)
- **UniFi Controller**: https://unifi-controller.discus-moth.ts.net:8443 (Network management)

### Via Local Network (Static IPs)

- **Home Assistant**: http://192.168.0.10:8123
- **Satisfactory**: 192.168.0.11:7777
- **Jellyfin**: http://192.168.0.12:8096
- **Tdarr**: http://192.168.0.12:8265
- **Sonarr**: http://192.168.0.13:8989
- **Radarr**: http://192.168.0.13:7878
- **Prowlarr**: http://192.168.0.13:9696
- **Jellyseerr**: http://192.168.0.13:5055
- **Bazarr**: http://192.168.0.13:6767
- **Huntarr**: http://192.168.0.13:9705
- **Homarr**: http://192.168.0.13:7575
- **Byparr**: http://192.168.0.13:8191
- **qBittorrent**: http://192.168.0.14:8080
- **SABnzbd**: http://192.168.0.14:8081
- **AdGuard Home**: http://192.168.0.15:80 (DNS: 192.168.0.15:53)
- **Nexus Repository**: http://192.168.0.15:8081 (Registry: 192.168.0.15:5001)
- **Prometheus**: http://192.168.0.16:9090
- **Alertmanager**: http://192.168.0.16:9093
- **Grafana**: http://192.168.0.16:3000
- **Woodpecker CI**: http://192.168.0.17:8000 (Web UI)
- **Lancache**: http://192.168.0.18:80 (HTTP), https://192.168.0.18:443 (SNI proxy)
- **UniFi Controller**: https://192.168.0.19:8443 (Network management)

## Deployment Types

| Service | Deployment | Notes |
|---------|------------|-------|
| Jellyfin | **Native** (systemd) | Uses `systemctl`/`journalctl`, NOT containerized |
| Tdarr | **Quadlet** (rootless Podman) | User systemd services |
| All Media Services (.13) | **Quadlet** (rootless Podman) | Sonarr, Radarr, Prowlarr, Jellyseerr, etc. |
| Download Clients (.14) | **Quadlet** (rootless Podman) | qBittorrent, SABnzbd, Gluetun VPN, Unpackerr |
| AdGuard Home (.15) | **Quadlet** (rootless Podman) | On NAS VM |
| Monitoring Services (.16) | **Quadlet** (rootless Podman) | Prometheus, Alertmanager, Grafana (Uptime Kuma on external) |
| Home Assistant | **Quadlet** (rootless Podman) | LinuxServer.io image |
| Satisfactory | Native (systemd) | SteamCMD + systemd service |
| Byparr | **Quadlet** (rootless Podman) | Cloudflare bypass |
| Homarr | **Quadlet** (rootless Podman) | Service dashboard |
| Recyclarr | **Quadlet** (rootless Podman) | Quality profiles sync |
| Unbound | **Quadlet** (rootless Podman) | DNS resolver |
| Woodpecker CI (.17) | **Quadlet** (rootless Podman) | Server + Agent |
| Nexus Repository (.15) | **Quadlet** (rootless Podman) | Container registry on NAS |
| Lancache (.18) | **Quadlet** (rootful Podman) | Game download cache (Steam, Epic, etc.) |
| UniFi Controller (.19) | **Quadlet** (rootless Podman) | MongoDB + LinuxServer UniFi app |

> **Important**: Most services now use **rootless Podman with Quadlet** (systemd integration). Use `systemctl --user`
commands, NOT `docker` or `docker-compose`.

## Service Management

### Quadlet-Based Services (Most Services)

All containerized services use **rootless Podman with Quadlet**, which generates systemd user services from `.container`
files. Management is done via `systemctl --user` commands.

#### Checking Service Status

```bash
# Check a specific service

systemctl --user status sonarr

# List all container services

systemctl --user list-units --type=service | grep -E '(sonarr|radarr|prowlarr|qbittorrent|sabnzbd|gluetun|jellyseerr)'

# Check if a service is enabled

systemctl --user is-enabled sonarr
```

#### Viewing Logs

```bash
# Follow logs in real-time

journalctl --user -u sonarr -f

# View last 100 lines

journalctl --user -u sonarr -n 100

# View logs since boot

journalctl --user -u sonarr -b

# Filter by time

journalctl --user -u sonarr --since "1 hour ago"
```

#### Restarting Services

```bash
# Restart a single service

systemctl --user restart sonarr

# Restart all media services

systemctl --user restart sonarr radarr prowlarr jellyseerr

# Restart download stack (order matters - VPN first)

systemctl --user restart gluetun qbittorrent sabnzbd unpackerr
```

#### Stopping/Starting Services

```bash
# Stop a service

systemctl --user stop sonarr

# Start a service

systemctl --user start sonarr

# Enable service to start at boot

systemctl --user enable sonarr

# Disable service from starting at boot

systemctl --user disable sonarr
```

#### Checking Container Status

```bash
# List running containers (requires XDG_RUNTIME_DIR)

export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps

# Check container logs directly

podman logs sonarr

# Inspect container configuration

podman inspect sonarr
```

> **Note**: For manual `podman` commands, you must set `XDG_RUNTIME_DIR=/run/user/$(id -u)` to access the rootless
Podman socket. However, `systemctl --user` and `journalctl --user` work without this environment variable.

#### Service Dependencies

Some services have dependencies that must be started first:

- **qBittorrent** depends on **Gluetun** (VPN network namespace)
- **SABnzbd** depends on **Gluetun** (VPN network namespace)
- **Unpackerr** depends on **qBittorrent** and **SABnzbd**
- **Tdarr Node** depends on **Tdarr Server**
- **Woodpecker Agent** depends on **Woodpecker Server**

Quadlet handles these dependencies automatically via `After=` and `Requires=`
directives in systemd units. Additionally, `BindsTo=` is used for critical
dependency pairs to ensure restart propagation:

- If a dependency (e.g., Gluetun, Tdarr Server) fails during boot then
  recovers, `Requires=` alone does **not** restart the dependent service.
  `BindsTo=` ensures the dependent container is stopped and restarted when
  its dependency restarts.
- **Affected pairs**: tdarr-node/tdarr-server, qbittorrent/gluetun,
  woodpecker-agent/woodpecker-server

### Native Services (Jellyfin, Satisfactory)

Jellyfin and Satisfactory run as **native systemd services** (not containers).

#### Jellyfin

```bash
# Check status (requires sudo)

sudo systemctl status jellyfin

# View logs

sudo journalctl -u jellyfin -f

# Restart

sudo systemctl restart jellyfin
```

#### Satisfactory

```bash
# Check status

systemctl --user status satisfactory

# View logs

journalctl --user -u satisfactory -f

# Restart

systemctl --user restart satisfactory
```

### Common Service Operations by VM

#### Media Services VM (192.168.0.13)

```bash
# SSH into VM

ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check all services

systemctl --user status sonarr radarr prowlarr jellyseerr byparr recyclarr

# Restart all

systemctl --user restart sonarr radarr prowlarr jellyseerr byparr recyclarr
```

#### Download Clients VM (192.168.0.14)

```bash
# SSH into VM

ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# Check all services

systemctl --user status gluetun qbittorrent sabnzbd unpackerr

# Restart all (VPN first!)

systemctl --user restart gluetun qbittorrent sabnzbd unpackerr
```

#### Monitoring VM (192.168.0.16)

```bash
# SSH into VM

ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net

# Check all services

systemctl --user status prometheus alertmanager grafana snmp-exporter blackbox-exporter

# Restart all

systemctl --user restart prometheus alertmanager grafana
```

Note: Uptime Kuma runs on external monitoring (Oracle Cloud) at oracle-monitoring.discus-moth.ts.net:3001

#### Woodpecker CI VM (192.168.0.17)

```bash
# SSH into VM

ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net

# Check all services

systemctl --user status woodpecker-server woodpecker-agent

# Restart all

systemctl --user restart woodpecker-server woodpecker-agent

# Check Tailscale Funnel status

tailscale funnel status
```

#### UniFi Controller VM (192.168.0.19)

```bash
# SSH into VM

ssh -i ~/.ssh/ansible_homelab ansible@unifi-controller.discus-moth.ts.net

# Check all services

systemctl --user status unifi-mongodb unifi-app

# Restart all

systemctl --user restart unifi-mongodb unifi-app

# View UniFi app logs

journalctl --user -u unifi-app -f
```

### Troubleshooting Service Issues

#### Service Won't Start

1. Check service status: `systemctl --user status <service>`
2. View full logs: `journalctl --user -u <service> -n 100`
3. Verify container file exists: `ls ~/.config/containers/systemd/<service>.container`
4. Reload systemd: `systemctl --user daemon-reload`
5. Check container health: `podman inspect <service> | grep -A 10 Health`

#### Permission Errors

- All containers run as UID/GID 3000 (mapped to host UID 102999)
- NFS mounts use `all_squash` with `anonuid=3000,anongid=3000`
- Check file ownership: `ls -la /mnt/storage/`

#### VPN/Network Issues (Download Clients)

1. Check Gluetun is running: `systemctl --user status gluetun`
2. Verify PIA connection: `journalctl --user -u gluetun | grep "Connected"`
3. Check port forwarding: `journalctl --user -u gluetun | grep "port forward"`
4. Test VPN: `podman exec gluetun curl ifconfig.me` (should show VPN IP)

## Port Reference

| Service | VM | Port | Protocol | Purpose |
|---------|-------|------|----------|---------|
| Home Assistant | .10 | 8123 | HTTP | Web UI |
| Satisfactory | .11 | 7777 | TCP | Server API |
| Satisfactory | .11 | 7777 | UDP | Game Traffic |
| Satisfactory | .11 | 8888 | TCP | Server Manager HTTPS |
| Jellyfin | .12 | 8096 | HTTP | Web UI |
| Jellyfin | .12 | 8920 | HTTPS | HTTPS UI |
| Jellyfin | .12 | 7359 | UDP | Discovery |
| Tdarr | .12 | 8265 | HTTP | Web UI |
| Tdarr | .12 | 8266 | TCP | Server (internal) |
| Tdarr | .12 | 8267 | TCP | Node (internal) |
| Sonarr | .13 | 8989 | HTTP | Web UI |
| Radarr | .13 | 7878 | HTTP | Web UI |
| Prowlarr | .13 | 9696 | HTTP | Web UI |
| Jellyseerr | .13 | 5055 | HTTP | Web UI |
| Bazarr | .13 | 6767 | HTTP | Web UI |
| Huntarr | .13 | 9705 | HTTP | Web UI |
| Homarr | .13 | 7575 | HTTP | Dashboard |
| Byparr | .13 | 8191 | HTTP | API |
| qBittorrent | .14 | 8080 | HTTP | Web UI |
| qBittorrent | .14 | Dynamic* | TCP/UDP | Incoming (PIA-assigned) |
| SABnzbd | .14 | 8081 | HTTP | Web UI |
| AdGuard Home | .15 | 80 | HTTP | Web UI |
| AdGuard Home | .15 | 53 | TCP/UDP | DNS Server |
| Nexus Repository | .15 | 8081 | HTTP | Web UI |
| Nexus Repository | .15 | 5001 | HTTP | Container Registry |
| Prometheus | .16 | 9090 | HTTP | Web UI |
| Alertmanager | .16 | 9093 | HTTP | Web UI |
| Grafana | .16 | 3000 | HTTP | Web UI |
| Woodpecker Server | .17 | 8000 | HTTP | Web UI |
| Woodpecker Server | .17 | 9000 | gRPC | Agent communication |
| Lancache | .18 | 80 | HTTP | Cache traffic |
| Lancache | .18 | 443 | HTTPS | SNI proxy |
| UniFi Controller | .19 | 8443 | HTTPS | Web UI |
| UniFi Controller | .19 | 8080 | HTTP | Device Inform |
| UniFi Controller | .19 | 3478 | UDP | STUN |
| UniFi Controller | .19 | 10001 | UDP | Device Discovery |

*qBittorrent uses dynamic port forwarding via PIA VPN (e.g., 46124). Port is automatically assigned and updated. See
[VPN Configuration Guide](vpn-gluetun.md) for details.

## Connecting Download Clients

**Note**: Download clients (qBittorrent and SABnzbd) route all outbound traffic through Gluetun VPN for privacy and
security. Inbound connections via Tailscale/local network work normally. See [VPN Configuration Guide](vpn-gluetun.md)
for details.

When configuring download clients in Sonarr/Radarr/Prowlarr:

### qBittorrent

- **Host**: `download-clients.discus-moth.ts.net` or `192.168.0.14`
- **Port**: `8080`
- **Username**: (set during qBittorrent setup)
- **Password**: (set during qBittorrent setup)

### SABnzbd

- **Host**: `download-clients.discus-moth.ts.net` or `192.168.0.14`
- **Port**: `8081`
- **API Key**: Found in SABnzbd Config > General > Security
- **Category**: Leave blank or use `tv`/`movies`

## SSH Access

All VMs are accessible via SSH with the Ansible key:

```bash
# Via Tailscale

ssh -i ~/.ssh/ansible_homelab ansible@<hostname>.discus-moth.ts.net

# Via Local IP

ssh -i ~/.ssh/ansible_homelab ansible@192.168.0.<ip>
```

**Examples**:

```bash
# Media services

ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Download clients

ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# Jellyfin

ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net
```

## Proxmox Web UI

- **URL**: https://jellybuntu.discus-moth.ts.net:8006 or https://192.168.0.1:8006
- **User**: root@pam or ansible@pve
- **Note**: Requires local network or Tailscale access

## Network Accessibility

### After Firewall Configuration (Playbook 12: configure-ufw-firewall-role)

- **SSH**: Tailscale (100.64.0.0/10) + LAN (192.168.0.0/24)
- **Web Services**: Local network (192.168.0.0/24) or Tailscale
- **Other Traffic**: Blocked by default

### Before Firewall

- All services accessible from local network
- SSH accessible from local network

## Troubleshooting Access

### Can't Access via Tailscale

1. Check Tailscale is running: `tailscale status`
2. Verify VM is on Tailscale network: `tailscale status | grep <vm>`
3. Try direct IP access instead

### Can't Access Web UI

1. Check service is running: `systemctl --user status <service>` (or `sudo systemctl status <service>` for Jellyfin)
2. Check container is running: `export XDG_RUNTIME_DIR=/run/user/$(id -u) && podman ps`
3. Verify firewall rules: `sudo ufw status`
4. Check port is listening: `sudo netstat -tulpn | grep <port>`
5. View service logs: `journalctl --user -u <service> -n 50`

### Can't SSH

1. Verify SSH key: `ls ~/.ssh/ansible_homelab`
2. Check SSH agent: `ssh-add ~/.ssh/ansible_homelab`
3. Try with verbose output: `ssh -v -i ~/.ssh/ansible_homelab ansible@<host>`

## See Also

- [Networking Configuration](networking.md)
- [Troubleshooting Guide](../maintenance/troubleshooting.md)
- [Security Configuration](security.md)

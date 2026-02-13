# Satisfactory Server Configuration

Satisfactory is a first-person open-world factory building game. This guide covers the dedicated server setup for
multiplayer sessions.

> **IMPORTANT**: Satisfactory runs as a **native systemd user service** on the satisfactory-server VM (192.168.40.11).
> Use `systemctl --user` commands. The server is NOT containerized.

## Overview

- **VM**: satisfactory-server (VMID 200, 192.168.40.11)
- **Ports**: 7777 (Game/API), 8888 (Server Manager)
- **Protocol**: TCP
- **Deployment**: Native systemd user service with SteamCMD
- **Install Path**: `~/SatisfactoryDedicatedServer/`
- **Save Path**: `~/.config/Epic/FactoryGame/Saved/SaveGames/`
- **Playbook**: [`playbooks/services/satisfactory.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/satisfactory.yml)

## Access

- **Tailscale**: satisfactory-server.discus-moth.ts.net:7777
- **Local Network**: 192.168.40.11:7777

## Deployment

### Via Ansible Playbook (Recommended)

```bash
# Deploy Satisfactory server
./bin/runtime/ansible-run.sh playbooks/services/satisfactory.yml
```

The playbook:

1. Installs SteamCMD and dependencies
2. Downloads Satisfactory Dedicated Server
3. Creates systemd user service
4. Configures firewall rules
5. Enables lingering for user services

### Manual Installation

```bash
# SSH to satisfactory VM
ssh -i ~/.ssh/ansible_homelab ansible@satisfactory-server.discus-moth.ts.net

# Install SteamCMD (if not already installed)
sudo apt update
sudo apt install steamcmd

# Download/Update Satisfactory server
steamcmd +force_install_dir ~/SatisfactoryDedicatedServer \
  +login anonymous \
  +app_update 1690800 validate \
  +quit
```

### Systemd Service

Located at `~/.config/systemd/user/satisfactory.service`:

```ini
[Unit]
Description=Satisfactory Dedicated Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=%h/SatisfactoryDedicatedServer
ExecStart=%h/SatisfactoryDedicatedServer/FactoryServer.sh -unattended
Restart=on-failure
RestartSec=30

[Install]
WantedBy=default.target
```

## Server Configuration

### Game Settings File

Located at `~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/Game.ini`:

```ini
[/Script/FactoryGame.FGGameMode]
; Autosave interval in seconds (0 to disable)
mAutosaveInterval=300.0

; Number of autosaves to keep
mNumAutosavesToKeep=5
```

### Engine Settings

Located at `~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/Engine.ini`:

```ini
[/Script/OnlineSubsystemUtils.IpNetDriver]
; Maximum tick rate
MaxNetTickRate=60

; Connection timeout
ConnectionTimeout=60.0

; Initial connect timeout
InitialConnectTimeout=60.0

[URL]
; Port configuration
Port=7777
```

### Server Settings

Located at `~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/ServerSettings.ini`:

```ini
[/Script/FactoryGame.FGServerSubsystem]
; Server password (optional)
mServerPassword=

; Admin password
mAdminPassword=YourAdminPassword

; Auto-pause when no players
mAutoPause=True

; Auto-save on disconnect
mAutoSaveOnDisconnect=True
```

## Initial Setup

### First-Time Configuration

1. **Start the server**:

   ```bash
   systemctl --user start satisfactory
   ```

2. **Connect to server** from Satisfactory game:
   - Server Manager → Add Server
   - Enter: `satisfactory-server.discus-moth.ts.net:7777`
   - Or: `192.168.40.11:7777`

3. **Claim the server** (first connection):
   - Set server name
   - Set admin password
   - Create or load a save game

### Port Requirements

| Port | Protocol | Purpose |
|------|----------|---------|
| 7777 | TCP | Game traffic and Server API |
| 8888 | TCP | Server Manager HTTPS (optional) |

Ensure these ports are open in the firewall:

```bash
sudo ufw allow 7777/tcp
sudo ufw allow 8888/tcp
```

## Service Management

### Check Status

```bash
systemctl --user status satisfactory
```

### View Logs

```bash
# Follow logs
journalctl --user -u satisfactory -f

# Recent logs
journalctl --user -u satisfactory -n 100

# Server-specific log file
tail -f ~/.config/Epic/FactoryGame/Saved/Logs/FactoryGame.log
```

### Start/Stop/Restart

```bash
# Start server
systemctl --user start satisfactory

# Stop server (graceful)
systemctl --user stop satisfactory

# Restart server
systemctl --user restart satisfactory

# Enable auto-start
systemctl --user enable satisfactory
```

## Save Game Management

### Save Location

```text
~/.config/Epic/FactoryGame/Saved/SaveGames/
└── server/
    └── <SessionName>/
        ├── <SaveName>.sav
        └── <SaveName>_autosave_*.sav
```

### Backup Saves

```bash
# Create backup
tar -czf ~/satisfactory-saves-$(date +%Y%m%d).tar.gz \
  -C ~/.config/Epic/FactoryGame/Saved SaveGames

# Copy to safe location
cp ~/satisfactory-saves-*.tar.gz /mnt/data/backups/
```

### Restore Saves

```bash
# Stop server
systemctl --user stop satisfactory

# Restore saves
tar -xzf ~/satisfactory-saves-YYYYMMDD.tar.gz \
  -C ~/.config/Epic/FactoryGame/Saved/

# Start server
systemctl --user start satisfactory
```

### Switch Save Games

1. Stop the server
2. Use Server Manager in-game to load different save
3. Or edit the save game reference in server config

## Server Updates

### Automatic Updates (via SteamCMD)

```bash
# Stop server
systemctl --user stop satisfactory

# Update server
steamcmd +force_install_dir ~/SatisfactoryDedicatedServer \
  +login anonymous \
  +app_update 1690800 validate \
  +quit

# Start server
systemctl --user start satisfactory
```

### Check Current Version

```bash
# Check installed version
cat ~/SatisfactoryDedicatedServer/buildinfo.txt

# Or in game logs
grep "Version" ~/.config/Epic/FactoryGame/Saved/Logs/FactoryGame.log
```

## Performance Tuning

Satisfactory server performance is optimized at three levels: infrastructure (Proxmox VM), service (systemd), and
application (game settings).

### Infrastructure-Level Optimization

The Satisfactory VM is provisioned with dedicated resources via OpenTofu:

| Setting | Value | Purpose |
|---------|-------|---------|
| CPU Cores | 4 | Factory simulation is CPU-intensive |
| CPU Affinity | Cores 4-7 | Dedicated cores prevent contention |
| Memory | 8GB | Large factories need substantial RAM |
| CPU Priority | 2048 units | High priority scheduling |

These settings are defined in `infrastructure/terraform/vms.tf` and applied at VM creation.

### Service-Level Optimization

The Ansible role configures systemd with performance tuning:

```ini
# /etc/systemd/system/satisfactory.service
[Service]
# CPU affinity matches Proxmox VM pinning
CPUAffinity=4-7
Nice=-10
IOSchedulingClass=best-effort
IOSchedulingPriority=0
LimitNOFILE=65536
```

| Setting | Value | Purpose |
|---------|-------|---------|
| `CPUAffinity` | 4-7 | Reinforces Proxmox CPU pinning at process level |
| `Nice` | -10 | High scheduling priority (-20 to 19, lower = higher priority) |
| `IOSchedulingClass` | best-effort | Balanced I/O scheduling |
| `IOSchedulingPriority` | 0 | Highest priority within class (0-7) |
| `LimitNOFILE` | 65536 | Increased file descriptor limit |

### Memory Configuration

Satisfactory server is memory-intensive. Current VM allocation:

- **Allocated**: 8GB RAM
- **Recommended for large factories**: 12-16GB RAM
- **CPU**: 4 cores (dedicated via pinning)

Monitor memory usage:

```bash
# Check current memory usage
free -h

# Watch memory over time
watch -n 5 free -h

# Check if swapping (bad for performance)
vmstat 1 5
```

### Network Optimization

For optimal multiplayer performance, configure Engine.ini:

```ini
# ~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/Engine.ini
[/Script/OnlineSubsystemUtils.IpNetDriver]
MaxNetTickRate=120
NetServerMaxTickRate=120
```

**Remote player considerations:**

- Tailscale adds latency (~10-50ms depending on distance)
- For players far from the server, consider port forwarding TCP 7777 for direct connection
- High factory complexity increases network traffic

### Monitoring & Diagnostics

Verify performance settings are applied:

```bash
# Check CPU affinity of server process
taskset -cp $(pgrep -f FactoryServer)

# Check process priority (NI column)
ps -o pid,ni,comm -p $(pgrep -f FactoryServer)

# Monitor CPU usage by core
htop  # Press F2 → Display options → Show CPU usage

# Check file descriptor limits
cat /proc/$(pgrep -f FactoryServer)/limits | grep "open files"

# Real-time resource monitoring
htop -p $(pgrep -f FactoryServer)
```

### Factory Design Best Practices

Large factories can strain server performance. Optimize in-game:

| Practice | Benefit |
|----------|---------|
| Use trains/trucks for long distances | Reduces belt entity count |
| Minimize belt density | Fewer entities to simulate |
| Use manifolds over load balancers | Simpler logic, less CPU |
| Consolidate power networks | Fewer power calculations |
| Build vertically | Reduces render complexity |
| Limit conveyor lifts | Each lift is multiple entities |

### Verifying Optimization

After deploying the role, verify all optimizations are active:

```bash
# SSH to server
ssh -i ~/.ssh/ansible_homelab ansible@satisfactory-server.discus-moth.ts.net

# Check systemd service settings
systemctl show satisfactory | grep -E "Nice|CPU|Limit"

# Verify CPU affinity
taskset -cp $(pgrep -f FactoryServer)

# Check system limits
grep satisfactory /etc/security/limits.conf
```

## Admin Commands

### In-Game Console

Access via `~` key (requires admin password):

```text
Server.SaveGame            # Force save
Server.Shutdown            # Shutdown server
Server.SetAutoSaveInterval # Change autosave interval
```

### Remote RCON (if enabled)

```bash
# Not natively supported, but community tools available
```

## Mods Support

### Installing Mods

Satisfactory Mod Manager handles mods:

1. Mods must be installed on both server and clients
2. Server mod folder: `~/SatisfactoryDedicatedServer/FactoryGame/Mods/`
3. Restart server after installing mods

### Compatibility Notes

- Major game updates may break mods
- Test mods on single-player first
- Keep mod list minimal for stability

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Server not starting | Check logs: `journalctl --user -u satisfactory` |
| Can't connect | Verify firewall allows TCP 7777/8888 |
| High memory usage | Normal for large factories; add more RAM |
| Server crashing | Check logs, verify game files, update server |
| Save corruption | Restore from backup, verify disk space |
| Slow performance | Reduce factory complexity, add resources |

## Backup Schedule Recommendation

Create a cron job for regular backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 4 AM
0 4 * * * tar -czf ~/satisfactory-saves-$(date +\%Y\%m\%d).tar.gz -C ~/.config/Epic/FactoryGame/Saved SaveGames
```

## Security Considerations

1. **Set admin password**: Always configure an admin password
2. **Server password**: Optional, but recommended for private servers
3. **Firewall**: Only allow UDP ports needed
4. **Updates**: Keep server updated for security fixes

## See Also

- [Satisfactory Troubleshooting](../troubleshooting/satisfactory.md)
- [Service Endpoints](service-endpoints.md)
- [VM Specifications](../reference/vm-specifications.md)

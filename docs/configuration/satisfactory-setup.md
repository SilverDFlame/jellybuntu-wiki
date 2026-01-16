# Satisfactory Server Configuration

Satisfactory is a first-person open-world factory building game. This guide covers the dedicated server setup for
multiplayer sessions.

> **IMPORTANT**: Satisfactory runs as a **native systemd user service** on the satisfactory-server VM (192.168.0.11).
> Use `systemctl --user` commands. The server is NOT containerized.

## Overview

- **VM**: satisfactory-server (VMID 200, 192.168.0.11)
- **Ports**: 7777 (Game), 15000 (Beacon), 15777 (Query)
- **Protocol**: UDP
- **Deployment**: Native systemd user service with SteamCMD
- **Install Path**: `~/SatisfactoryDedicatedServer/`
- **Save Path**: `~/.config/Epic/FactoryGame/Saved/SaveGames/`
- **Playbook**: [`playbooks/core/deploy-satisfactory.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/deploy-satisfactory.yml)

## Access

- **Tailscale**: satisfactory-server.discus-moth.ts.net:7777
- **Local Network**: 192.168.0.11:7777

## Deployment

### Via Ansible Playbook (Recommended)

```bash
# Deploy Satisfactory server
./bin/runtime/ansible-run.sh playbooks/core/deploy-satisfactory.yml
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
   - Enter: `satisfactory-server.discus-moth.ts.net:15777`
   - Or: `192.168.0.11:15777`

3. **Claim the server** (first connection):
   - Set server name
   - Set admin password
   - Create or load a save game

### Port Requirements

| Port | Protocol | Purpose |
|------|----------|---------|
| 7777 | UDP | Game traffic |
| 15000 | UDP | Beacon/NAT negotiation |
| 15777 | UDP | Query port (server browser) |

Ensure these ports are open in the firewall:

```bash
sudo ufw allow 7777/udp
sudo ufw allow 15000/udp
sudo ufw allow 15777/udp
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

### Memory Configuration

Satisfactory server is memory-intensive. Recommended VM specs:

- **Minimum**: 8GB RAM
- **Recommended**: 12-16GB RAM
- **CPU**: 4+ cores

### Process Priority

For better performance:

```bash
# Start with higher priority (add to service file)
ExecStart=/usr/bin/nice -n -5 %h/SatisfactoryDedicatedServer/FactoryServer.sh -unattended
```

### Network Optimization

```ini
# In Engine.ini
[/Script/OnlineSubsystemUtils.IpNetDriver]
MaxNetTickRate=120
NetServerMaxTickRate=120
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
| Can't connect | Verify firewall allows UDP 7777/15000/15777 |
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

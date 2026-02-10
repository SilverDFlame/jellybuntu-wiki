# Satisfactory Server Maintenance

Maintenance procedures for the Satisfactory dedicated game server.

> **IMPORTANT**: Satisfactory runs as a **native systemd user service** on the satisfactory-server VM (192.168.0.11).
> Use `systemctl --user` commands. The server is NOT containerized.

## Overview

- **VM**: satisfactory-server (VMID 200, 192.168.0.11)
- **Ports**: 7777 (Game), 15000 (Beacon), 15777 (Query) - All UDP
- **Install Path**: `~/SatisfactoryDedicatedServer/`
- **Save Path**: `~/.config/Epic/FactoryGame/Saved/SaveGames/`
- **Config Path**: `~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/`

## Routine Maintenance

### Daily Checks

```bash
# SSH to Satisfactory VM
ssh -i ~/.ssh/ansible_homelab ansible@satisfactory-server.discus-moth.ts.net

# Check service status
systemctl --user status satisfactory

# Check for connected players (in logs)
journalctl --user -u satisfactory --since "1 hour ago" | grep -i "player\|connect\|join"

# Check memory usage
free -h
ps aux | grep FactoryServer
```

### Weekly Maintenance

1. **Check disk space**:

   ```bash
   df -h /
   du -sh ~/SatisfactoryDedicatedServer/
   du -sh ~/.config/Epic/FactoryGame/Saved/
   ```

2. **Review logs for errors**:

   ```bash
   journalctl --user -u satisfactory --since "1 week ago" | grep -i "error\|crash\|fail" | tail -20
   ```

3. **Verify saves are being created**:

   ```bash
   ls -lt ~/.config/Epic/FactoryGame/Saved/SaveGames/server/ | head -10
   ```

4. **Check for game updates**:

   ```bash
   # Compare installed vs available
   cat ~/SatisfactoryDedicatedServer/buildinfo.txt

   # Check Steam for updates (just shows info, doesn't update)
   steamcmd +login anonymous +app_info_update 1 +app_info_print 1690800 +quit 2>/dev/null | grep -A 2 "buildid"
   ```

### Monthly Maintenance

1. **Update game server**
2. **Clean old save backups**
3. **Review server configuration**
4. **Verify firewall rules**

## Service Management

### Check Status

```bash
systemctl --user status satisfactory
```

### View Logs

```bash
# Follow systemd logs
journalctl --user -u satisfactory -f

# Recent logs
journalctl --user -u satisfactory -n 100

# Application log file
tail -f ~/.config/Epic/FactoryGame/Saved/Logs/FactoryGame.log
```

### Start/Stop/Restart

```bash
# Start server
systemctl --user start satisfactory

# Stop server (graceful - waits for autosave)
systemctl --user stop satisfactory

# Restart server
systemctl --user restart satisfactory

# Enable auto-start
systemctl --user enable satisfactory
```

### Graceful Shutdown

Before stopping, notify players and wait for autosave:

1. Notify players in-game
2. Wait for autosave (default: every 5 minutes)
3. Then stop service:

   ```bash
   systemctl --user stop satisfactory
   ```

## Server Updates

### Update via SteamCMD

```bash
# SSH to Satisfactory VM
ssh -i ~/.ssh/ansible_homelab ansible@satisfactory-server.discus-moth.ts.net

# Stop server
systemctl --user stop satisfactory

# Update server files
steamcmd +force_install_dir ~/SatisfactoryDedicatedServer \
  +login anonymous \
  +app_update 1690800 validate \
  +quit

# Start server
systemctl --user start satisfactory

# Verify version
cat ~/SatisfactoryDedicatedServer/buildinfo.txt
```

### Update via Ansible

```bash
# From ansible controller
./bin/runtime/ansible-run.sh playbooks/services/satisfactory.yml
```

### Verify Update

```bash
# Check version in log
grep -i "version" ~/.config/Epic/FactoryGame/Saved/Logs/FactoryGame.log | tail -5

# Check build info
cat ~/SatisfactoryDedicatedServer/buildinfo.txt
```

### Rollback (Manual)

SteamCMD doesn't support version pinning for Satisfactory. To rollback:

1. Restore from backup (see Backup Procedures)
2. Or wait for hotfix from Coffee Stain Studios

## Save Game Management

### Save Locations

```text
~/.config/Epic/FactoryGame/Saved/SaveGames/
├── server/                    # Server saves
│   └── <SessionName>/
│       ├── <SaveName>.sav           # Manual saves
│       └── <SaveName>_autosave_*.sav  # Autosaves
└── common/                    # Shared saves (if any)
```

### List Saves

```bash
# List all saves with dates
find ~/.config/Epic/FactoryGame/Saved/SaveGames -name "*.sav" -exec ls -lh {} \; | sort -k6,7

# Show most recent saves
ls -lt ~/.config/Epic/FactoryGame/Saved/SaveGames/server/*/*.sav | head -10
```

### Backup Saves

```bash
#!/bin/bash
# Save as ~/backup-satisfactory-saves.sh

BACKUP_DIR="/mnt/data/backups/satisfactory"
DATE=$(date +%Y%m%d-%H%M)

mkdir -p "$BACKUP_DIR"

# Backup saves (no need to stop server - autosaves are atomic)
tar -czf "$BACKUP_DIR/satisfactory-saves-${DATE}.tar.gz" \
  -C ~/.config/Epic/FactoryGame/Saved SaveGames

echo "Backup complete: $BACKUP_DIR/satisfactory-saves-${DATE}.tar.gz"
ls -lh "$BACKUP_DIR/satisfactory-saves-${DATE}.tar.gz"
```

### Restore Saves

```bash
# Stop server
systemctl --user stop satisfactory

# Backup current saves first
mv ~/.config/Epic/FactoryGame/Saved/SaveGames \
   ~/.config/Epic/FactoryGame/Saved/SaveGames.bak

# Restore from backup
tar -xzf /mnt/data/backups/satisfactory/satisfactory-saves-YYYYMMDD-HHMM.tar.gz \
  -C ~/.config/Epic/FactoryGame/Saved/

# Start server
systemctl --user start satisfactory
```

### Delete Old Autosaves

```bash
# Keep only last 5 autosaves per session
cd ~/.config/Epic/FactoryGame/Saved/SaveGames/server

for dir in */; do
  ls -t "${dir}"*_autosave_*.sav 2>/dev/null | tail -n +6 | xargs -r rm -v
done
```

## Configuration Management

### Configuration Files

```text
~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/
├── Engine.ini          # Engine settings (network, performance)
├── Game.ini            # Game settings (autosave)
├── ServerSettings.ini  # Server settings (password, autopause)
└── Scalability.ini     # Graphics settings (not relevant for server)
```

### Key Settings

**Engine.ini** (network settings):

```ini
[/Script/OnlineSubsystemUtils.IpNetDriver]
MaxNetTickRate=60
ConnectionTimeout=60.0
InitialConnectTimeout=60.0

[URL]
Port=7777
```

**Game.ini** (autosave settings):

```ini
[/Script/FactoryGame.FGGameMode]
mAutosaveInterval=300.0
mNumAutosavesToKeep=5
```

**ServerSettings.ini** (server settings):

```ini
[/Script/FactoryGame.FGServerSubsystem]
mServerPassword=
mAdminPassword=YourAdminPassword
mAutoPause=True
mAutoSaveOnDisconnect=True
```

### Apply Configuration Changes

```bash
# Stop server
systemctl --user stop satisfactory

# Edit configuration files
nano ~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/ServerSettings.ini

# Start server
systemctl --user start satisfactory
```

## Full Backup Procedures

### Backup Everything

```bash
#!/bin/bash
# Save as ~/backup-satisfactory.sh

BACKUP_DIR="/mnt/data/backups/satisfactory"
DATE=$(date +%Y%m%d)

mkdir -p "$BACKUP_DIR"

# Stop server for consistent backup
systemctl --user stop satisfactory

# Backup saves and config
tar -czf "$BACKUP_DIR/satisfactory-full-${DATE}.tar.gz" \
  -C ~/.config/Epic/FactoryGame Saved

# Optional: backup server installation
# tar -czf "$BACKUP_DIR/satisfactory-server-${DATE}.tar.gz" \
#   -C ~/ SatisfactoryDedicatedServer

# Start server
systemctl --user start satisfactory

echo "Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"/satisfactory-*-${DATE}.tar.gz
```

### Full Restore

```bash
# Stop server
systemctl --user stop satisfactory

# Remove current data
rm -rf ~/.config/Epic/FactoryGame/Saved

# Restore from backup
tar -xzf /mnt/data/backups/satisfactory/satisfactory-full-YYYYMMDD.tar.gz \
  -C ~/.config/Epic/FactoryGame/

# Start server
systemctl --user start satisfactory
```

### Schedule Automatic Backups

```bash
# Add to crontab
crontab -e

# Daily save backup at 4 AM
0 4 * * * /home/ansible/backup-satisfactory-saves.sh >> /var/log/satisfactory-backup.log 2>&1

# Weekly full backup at 4 AM Sunday
0 4 * * 0 /home/ansible/backup-satisfactory.sh >> /var/log/satisfactory-backup.log 2>&1
```

## Performance Monitoring

### Resource Usage

```bash
# Check server process
ps aux | grep FactoryServer

# Memory usage
free -h

# CPU usage
top -p $(pgrep FactoryServer) -n 1

# Detailed process info
htop -p $(pgrep FactoryServer)
```

### Network Monitoring

```bash
# Check active connections
ss -unp | grep 7777

# Monitor network traffic
iftop -f "udp port 7777"

# Check for port forwarding issues
sudo ufw status | grep -E "7777|15000|15777"
```

### Disk I/O

```bash
# Monitor disk I/O
iostat -x 1 5

# Check for large saves
du -sh ~/.config/Epic/FactoryGame/Saved/SaveGames/server/*
```

## Log Management

### View Logs

```bash
# Systemd logs
journalctl --user -u satisfactory -f

# Application log
tail -f ~/.config/Epic/FactoryGame/Saved/Logs/FactoryGame.log

# Search for specific events
grep -i "player\|save\|connect" ~/.config/Epic/FactoryGame/Saved/Logs/FactoryGame.log
```

### Clean Old Logs

```bash
# Remove logs older than 30 days
find ~/.config/Epic/FactoryGame/Saved/Logs -name "*.log" -mtime +30 -delete

# Check log directory size
du -sh ~/.config/Epic/FactoryGame/Saved/Logs/
```

### Log Rotation

The game handles log rotation automatically. Check for backup logs:

```bash
ls -la ~/.config/Epic/FactoryGame/Saved/Logs/
```

## Player Management

### Kick Players (via in-game console)

Players with admin access can use in-game console (`~` key):

```text
Server.KickPlayer <PlayerName>
Server.BanPlayer <PlayerName>
```

### View Connected Players

```bash
# Check recent connections in logs
journalctl --user -u satisfactory | grep -i "player\|join\|connect" | tail -20
```

### Change Admin Password

1. Stop server:

   ```bash
   systemctl --user stop satisfactory
   ```

2. Edit `~/.config/Epic/FactoryGame/Saved/Config/LinuxServer/ServerSettings.ini`:

   ```ini
   [/Script/FactoryGame.FGServerSubsystem]
   mAdminPassword=NewAdminPassword
   ```

3. Start server:

   ```bash
   systemctl --user start satisfactory
   ```

## Troubleshooting Common Issues

### Server Won't Start

```bash
# Check status
systemctl --user status satisfactory

# Check logs for errors
journalctl --user -u satisfactory -n 100

# Verify server files
steamcmd +force_install_dir ~/SatisfactoryDedicatedServer \
  +login anonymous \
  +app_update 1690800 validate \
  +quit

# Check systemd service file
cat ~/.config/systemd/user/satisfactory.service
```

### Players Can't Connect

```bash
# Verify server is running
systemctl --user status satisfactory

# Check firewall
sudo ufw status | grep -E "7777|15000|15777"

# Ensure ports are open
sudo ufw allow 7777/udp
sudo ufw allow 15000/udp
sudo ufw allow 15777/udp

# Check if server is listening
ss -ulnp | grep -E "7777|15000|15777"
```

### High Memory Usage

Large factories consume significant memory:

```bash
# Check current memory
ps -o pid,user,%mem,rss,command -p $(pgrep FactoryServer)

# If memory is critical, restart server
systemctl --user restart satisfactory
```

Consider increasing VM memory if consistently high:

- Minimum: 8GB RAM
- Recommended: 12-16GB RAM for large factories

### Server Crashing

```bash
# Check for crash dumps
ls -la ~/.config/Epic/FactoryGame/Saved/Crashes/

# Check logs around crash time
journalctl --user -u satisfactory --since "1 hour ago"

# Verify game files
steamcmd +force_install_dir ~/SatisfactoryDedicatedServer \
  +login anonymous \
  +app_update 1690800 validate \
  +quit
```

### Save Corruption

```bash
# Check save file integrity (look for very small files)
find ~/.config/Epic/FactoryGame/Saved/SaveGames -name "*.sav" -size -1k -ls

# Restore from recent autosave
ls -lt ~/.config/Epic/FactoryGame/Saved/SaveGames/server/*/*.sav | head -10

# Or restore from backup
```

## Maintenance Schedule

| Task | Frequency | Notes |
|------|-----------|-------|
| Service health check | Daily | Automated via monitoring |
| Check disk space | Weekly | Saves grow over time |
| Backup saves | Daily | Automated via cron |
| Full backup | Weekly | Includes config |
| Clean old autosaves | Weekly | Keep last 5 per session |
| Clean old logs | Monthly | Logs older than 30 days |
| Server updates | As released | Check Steam announcements |
| Verify save integrity | Monthly | Check for small/corrupt files |

## See Also

- [Satisfactory Configuration](../configuration/satisfactory-setup.md)
- [Satisfactory Troubleshooting](../troubleshooting/satisfactory.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [VM Specifications](../reference/vm-specifications.md)

# Satisfactory Server Troubleshooting

Troubleshooting guide for Satisfactory dedicated server issues.

> **IMPORTANT**: Satisfactory runs as a **native systemd service** (not Docker).
> Use `systemctl` and `journalctl` commands, NOT `docker` commands.

## Quick Checks

```bash
# Check Satisfactory service status
sudo systemctl status satisfactory

# View Satisfactory logs
sudo journalctl -u satisfactory -f

# Check if server is listening on game ports
sudo netstat -tulpn | grep -E "7777|15000|15777"

# Check server process
ps aux | grep FactoryServer
```

## Common Issues

### 1. Satisfactory Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start Satisfactory Server"
- Server immediately crashes after starting

**Diagnosis**:

```bash
# Check service status
sudo systemctl status satisfactory

# View detailed logs
sudo journalctl -u satisfactory -n 100 --no-pager

# Check for port conflicts
sudo lsof -i :7777
sudo lsof -i :15000
sudo lsof -i :15777

# Check server files
ls -la /opt/satisfactory/
```

**Solutions**:

1. **Port already in use**:

   ```bash
   # Find conflicting process
   sudo lsof -i :7777
   # Kill or stop the conflicting service
   ```

2. **Missing or corrupted server files**:

   ```bash
   # Reinstall/update server via SteamCMD
   sudo systemctl stop satisfactory
   sudo -u satisfactory /usr/games/steamcmd \
     +force_install_dir /opt/satisfactory \
     +login anonymous \
     +app_update 1690800 -beta public validate +quit
   sudo systemctl start satisfactory
   ```

3. **Permission issues**:

   ```bash
   # Fix ownership
   sudo chown -R satisfactory:satisfactory /opt/satisfactory
   sudo chmod +x /opt/satisfactory/FactoryServer.sh
   sudo systemctl restart satisfactory
   ```

4. **Corrupted save file**:

   ```bash
   # Backup and move save files
   sudo systemctl stop satisfactory
   sudo -u satisfactory mv /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames \
     /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames.bak
   sudo systemctl start satisfactory
   # Server will start with a new world
   ```

### 2. Can't Connect to Server

**Symptoms**:

- Game client shows "Connection timeout"
- Server not appearing in server list
- Can ping server but can't connect to game

**Diagnosis**:

```bash
# Check if server is running
sudo systemctl status satisfactory

# Check firewall rules
sudo ufw status

# Test local connectivity
curl -v telnet://localhost:7777

# Check if accessible from Tailscale
curl -v telnet://$(tailscale ip -4):7777

# Verify server is listening
sudo netstat -tulpn | grep 7777
```

**Solutions**:

1. **Firewall blocking**:

   ```bash
   # UFW should already allow these ports (configured by playbook)
   # But verify:
   sudo ufw status | grep -E "7777|15000|15777"

   # If missing, add rules:
   sudo ufw allow 7777/udp comment "Satisfactory Game Port"
   sudo ufw allow 15000/udp comment "Satisfactory Beacon Port"
   sudo ufw allow 15777/udp comment "Satisfactory Query Port"
   sudo ufw reload
   ```

2. **Server not fully started**:

   ```bash
   # Wait for server to fully initialize (can take 1-2 minutes)
   sudo journalctl -u satisfactory -f
   # Look for "LogNet: Browse: Successful" or similar
   ```

3. **Tailscale not connected**:

   ```bash
   # Check Tailscale status
   tailscale status

   # Restart if needed
   sudo systemctl restart tailscaled
   ```

4. **Connect via correct address**:

   - **Local network**: `192.168.0.11:7777`
   - **Tailscale**: `satisfactory-server.discus-moth.ts.net:7777`
   - Make sure game client is using the correct IP/hostname

### 3. Server Crashes or Restarts Unexpectedly

**Symptoms**:

- Server randomly crashes during gameplay
- Service shows "Active (running)" but players get disconnected
- Frequent automatic restarts

**Diagnosis**:

```bash
# Check crash logs
sudo journalctl -u satisfactory -n 200 --no-pager | grep -i "crash\|error\|fatal"

# Check system resources
free -h
df -h /opt/satisfactory

# Check for OOM (Out of Memory) kills
dmesg | grep -i "killed process"
sudo journalctl -k | grep -i "out of memory"

# Monitor memory usage
top -u satisfactory
```

**Solutions**:

1. **Out of memory**:

   ```bash
   # Check VM has enough RAM (should be 6GB)
   free -h

   # If memory is consistently maxed out, consider:
   # - Reducing number of concurrent players
   # - Increasing VM RAM in Proxmox
   # - Checking for memory leaks in mods
   ```

2. **Corrupted save file**:

   ```bash
   # Backup current save
   sudo systemctl stop satisfactory
   sudo -u satisfactory cp -r \
     /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames \
     /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames.backup-$(date +%Y%m%d)

   # Try loading an older autosave
   # (manually rename files in SaveGames directory)
   sudo systemctl start satisfactory
   ```

3. **Mod conflicts**:

   ```bash
   # Disable all mods and test
   sudo systemctl stop satisfactory
   sudo -u satisfactory rm -rf /opt/satisfactory/FactoryGame/Mods/*
   sudo systemctl start satisfactory
   # Re-enable mods one at a time via SMM to identify culprit
   ```

4. **Server update needed**:

   ```bash
   # Update to latest version
   sudo systemctl stop satisfactory
   sudo -u satisfactory /usr/games/steamcmd \
     +force_install_dir /opt/satisfactory \
     +login anonymous \
     +app_update 1690800 -beta public +quit
   sudo systemctl start satisfactory
   ```

### 4. High Lag / Poor Performance

**Symptoms**:

- Players experience lag or stuttering
- Server tick rate drops
- Delayed interactions with objects

**Diagnosis**:

```bash
# Check CPU usage
top -u satisfactory

# Check system load
uptime

# Monitor in real-time
htop

# Check if CPU cores are pinned (should be cores 2-3)
taskset -cp $(pgrep FactoryServer)

# Check disk I/O
iostat -x 1
```

**Solutions**:

1. **CPU not pinned to dedicated cores**:

   ```bash
   # Should be handled by Proxmox VM config
   # Verify in Proxmox: VM has cores 2-3 dedicated (pinned)
   # Check current CPU affinity
   taskset -cp $(pgrep FactoryServer)
   ```

2. **Too many concurrent players**:

   - Satisfactory is CPU-intensive with large factories
   - Consider limiting concurrent players
   - Optimize factory builds (fewer belts, use trucks/trains)

3. **Large save file**:

   ```bash
   # Check save file size
   sudo du -sh /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames/*

   # Large saves (>50MB) can cause performance issues
   # Consider starting a new world or optimizing factory
   ```

4. **Network latency**:

   ```bash
   # Test network latency from client to server
   ping satisfactory-server.discus-moth.ts.net

   # If using Tailscale from far away, consider direct connection
   # Port forward 7777 UDP on router if needed
   ```

### 5. Can't Update Server

**Symptoms**:

- SteamCMD fails to update
- Error: "No subscription" or "Invalid app id"
- Update downloads but server doesn't start

**Diagnosis**:

```bash
# Try manual update
sudo -u satisfactory /usr/games/steamcmd \
  +force_install_dir /opt/satisfactory \
  +login anonymous \
  +app_update 1690800 -beta public validate +quit

# Check for errors in output
```

**Solutions**:

1. **SteamCMD issues**:

   ```bash
   # Reinstall SteamCMD
   sudo apt update
   sudo apt install --reinstall steamcmd
   ```

2. **Disk space**:

   ```bash
   # Check available space
   df -h /opt/satisfactory

   # Satisfactory server needs ~15GB
   # Clean up old downloads if needed
   sudo rm -rf /opt/satisfactory/steamapps/downloading/*
   ```

3. **Network issues**:

   ```bash
   # Test connectivity to Steam
   ping steamcdn-a.akamaihd.net

   # Check DNS
   nslookup steamcdn-a.akamaihd.net
   ```

4. **Force clean reinstall**:

   ```bash
   sudo systemctl stop satisfactory
   sudo -u satisfactory rm -rf /opt/satisfactory/*
   sudo -u satisfactory /usr/games/steamcmd \
     +force_install_dir /opt/satisfactory \
     +login anonymous \
     +app_update 1690800 -beta public validate +quit
   # Note: This preserves saves (stored in .config/Epic/)
   sudo systemctl start satisfactory
   ```

### 6. Satisfactory Mod Manager (SMM) Issues

**Symptoms**:

- Can't connect to server via SMM SFTP
- SMM shows "Authentication failed"
- Can't control server from SMM

**Diagnosis**:

```bash
# Check if password authentication is enabled
sudo grep -r "PasswordAuthentication" /etc/ssh/sshd_config.d/

# Check ansible user groups
groups ansible

# Test SFTP connection manually
sftp ansible@satisfactory-server.discus-moth.ts.net
```

**Solutions**:

1. **SSH password authentication not enabled**:

   ```bash
   # Should be configured by playbook, but verify:
   cat /etc/ssh/sshd_config.d/50-smm-password-auth.conf
   # Should contain: PasswordAuthentication yes

   # If missing, recreate:
   # Create file with required settings:
   echo "# Enable password auth for SMM (Satisfactory Mod Manager) SFTP access" | \
     sudo tee /etc/ssh/sshd_config.d/50-smm-password-auth.conf > /dev/null
   echo "PasswordAuthentication yes" | \
     sudo tee -a /etc/ssh/sshd_config.d/50-smm-password-auth.conf > /dev/null
   sudo systemctl restart sshd
   ```

2. **Wrong password**:

   ```bash
   # Password is stored in group_vars/all.sops.yaml as vault_smm_ansible_password
   # Reset password with ansible playbook or manually:
   # sudo passwd ansible
   ```

3. **ansible user not in satisfactory group**:

   ```bash
   # Add to group
   sudo usermod -aG satisfactory ansible

   # Verify
   groups ansible | grep satisfactory
   ```

4. **SMM connection settings**:

   - Use **Simple Mode** (not Docker/Advanced)
   - Host: `satisfactory-server.discus-moth.ts.net` or `192.168.0.11`
   - Port: `22`
   - Username: `ansible`
   - Password: (from vault)
   - Path: `/opt/satisfactory`

5. **sudoers permissions for service control**:

   ```bash
   # Should be configured by playbook
   sudo cat /etc/sudoers.d/satisfactory-smm

   # Should allow ansible to control service without password
   # Test:
   sudo -u ansible sudo systemctl status satisfactory
   ```

### 7. Save Files Not Persisting

**Symptoms**:

- Server restarts with default world
- Progress lost after restart
- Can't find save files

**Diagnosis**:

```bash
# Check save file location
sudo ls -la /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames/

# Check ownership
sudo ls -la /opt/satisfactory/.config/Epic/FactoryGame/Saved/
```

**Solutions**:

1. **Saves in wrong location**:

   ```bash
   # Satisfactory saves are in user's home directory
   # Server runs as 'satisfactory' user with home /opt/satisfactory
   # Saves should be at:
   # /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames/

   # Check if .config exists
   sudo -u satisfactory mkdir -p /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames
   ```

2. **Permission issues**:

   ```bash
   # Fix ownership
   sudo chown -R satisfactory:satisfactory /opt/satisfactory/.config
   ```

3. **Backup save files**:

   ```bash
   # Manual backup
   sudo -u satisfactory tar -czf \
     /opt/satisfactory/saves-backup-$(date +%Y%m%d-%H%M).tar.gz \
     /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames/

   # List backups
   ls -lh /opt/satisfactory/saves-backup-*
   ```

## Advanced Troubleshooting

### Check System Configuration

```bash
# Verify service configuration
sudo systemctl show satisfactory

# Check user and permissions
id satisfactory

# Verify CPU affinity (if set in systemd service)
taskset -cp $(pgrep FactoryServer)

# Check system resources
free -h
df -h
uptime
```

### Monitor Server Performance

```bash
# Real-time monitoring
htop -u satisfactory

# Watch network connections
watch -n 2 'sudo netstat -an | grep -E "7777|15000|15777"'

# Monitor logs
sudo journalctl -u satisfactory -f

# Check disk usage over time
watch -n 5 'du -sh /opt/satisfactory'
```

### Debug Connection Issues

```bash
# Test UDP ports (requires nc/netcat)
nc -u -v satisfactory-server.discus-moth.ts.net 7777

# Check firewall with verbose output
sudo ufw status verbose

# Test from another machine on network
# From another VM or PC:
telnet 192.168.0.11 7777

# Capture network traffic (advanced)
sudo tcpdump -i any port 7777 -n
```

### Backup and Restore

```bash
# Full backup (server files + saves)
sudo systemctl stop satisfactory
sudo tar -czf /tmp/satisfactory-full-backup-$(date +%Y%m%d).tar.gz \
  /opt/satisfactory \
  /etc/systemd/system/satisfactory.service
sudo systemctl start satisfactory

# Backup saves only
sudo -u satisfactory tar -czf \
  /tmp/satisfactory-saves-$(date +%Y%m%d).tar.gz \
  /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames/

# Restore saves
sudo systemctl stop satisfactory
sudo tar -xzf /tmp/satisfactory-saves-*.tar.gz -C /
sudo chown -R satisfactory:satisfactory /opt/satisfactory/.config
sudo systemctl start satisfactory
```

### Reinstall from Scratch

```bash
# Complete reinstall (preserves saves)
sudo systemctl stop satisfactory

# Backup saves first!
sudo -u satisfactory tar -czf /tmp/saves-backup.tar.gz \
  /opt/satisfactory/.config/Epic/FactoryGame/Saved/SaveGames/

# Remove server files (but not home directory)
sudo rm -rf /opt/satisfactory/Engine
sudo rm -rf /opt/satisfactory/FactoryGame
sudo rm -rf /opt/satisfactory/FactoryServer.sh
sudo rm -rf /opt/satisfactory/steamapps

# Reinstall
sudo -u satisfactory /usr/games/steamcmd \
  +force_install_dir /opt/satisfactory \
  +login anonymous \
  +app_update 1690800 -beta public validate +quit

# Restore saves
sudo tar -xzf /tmp/saves-backup.tar.gz -C /

# Restart
sudo systemctl start satisfactory
```

## Getting Help

If issues persist after trying these solutions:

1. **Check Satisfactory server logs**:

   ```bash
   sudo journalctl -u satisfactory -n 500 --no-pager > /tmp/satisfactory.log
   ```

2. **Check system logs**:

   ```bash
   dmesg | tail -100
   ```

3. **Gather diagnostic info**:

   ```bash
   # System info
   uname -a
   lsb_release -a

   # Server version
   ls -la /opt/satisfactory/Engine/Binaries/Linux/

   # Resource usage
   free -h
   df -h
   ```

4. **Satisfactory community resources**:

   - Official wiki: https://satisfactory.wiki.gg/
   - Reddit: https://reddit.com/r/SatisfactoryGame
   - Discord: https://discord.gg/satisfactory
   - Dedicated server docs: https://satisfactory.wiki.gg/wiki/Dedicated_servers
   - SMM documentation: https://docs.ficsit.app/

## See Also

- [VM Specifications](../reference/vm-specifications.md) - Satisfactory VM resources
- [Networking Troubleshooting](networking.md) - Tailscale and firewall issues
- [Common Issues](common-issues.md) - Cross-service problems
- [Service Endpoints](../configuration/service-endpoints.md) - Connection details

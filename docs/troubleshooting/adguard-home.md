# AdGuard Home Troubleshooting

Troubleshooting guide for AdGuard Home DNS and ad blocking issues.

> **IMPORTANT**: AdGuard Home runs as a **rootless Podman container with Quadlet** on the NAS VM (192.168.30.15).
Use `systemctl --user` and `journalctl --user` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH into NAS VM
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Check AdGuard Home service status
systemctl --user status adguardhome

# View AdGuard Home logs
journalctl --user -u adguardhome -f

# Check if AdGuard is listening on DNS port
sudo netstat -tulpn | grep :53

# Check if web UI is accessible
sudo netstat -tulpn | grep :80

# Verify container is running
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps | grep adguardhome
```

## Common Issues

### 1. AdGuard Home Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start adguardhome.service"
- Container exits immediately
- DNS not resolving

**Diagnosis**:

```bash
# Check service status
systemctl --user status adguardhome

# View detailed logs
journalctl --user -u adguardhome -n 100 --no-pager

# Check for port conflicts (DNS port 53, Web UI port 80)
sudo lsof -i :53
sudo lsof -i :80

# Check container logs
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman logs adguardhome
```

**Solutions**:

1. **Port 53 (DNS) already in use**:

   ```bash
   # Check what's using port 53
   sudo lsof -i :53

   # Common culprit: systemd-resolved
   sudo systemctl status systemd-resolved

   # Disable systemd-resolved if needed (should be done by playbook)
   sudo systemctl disable --now systemd-resolved
   sudo rm /etc/resolv.conf
   echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf

   # Restart AdGuard
   systemctl --user restart adguardhome
   ```

2. **Port 80 (Web UI) already in use**:

   ```bash
   # Find what's using port 80
   sudo lsof -i :80

   # Stop conflicting service or change AdGuard port
   # Edit Quadlet configuration to use different port if needed
   ```

3. **Permission issues**:

   ```bash
   # Check config directory ownership
   ls -la ~/.config/adguardhome/

   # Fix permissions (should be owned by your user)
   chown -R $(whoami):$(whoami) ~/.config/adguardhome/
   ```

4. **Corrupted configuration**:

   ```bash
   # Check configuration file
   cat ~/.config/adguardhome/AdGuardHome.yaml

   # Restore from backup if corrupted
   systemctl --user stop adguardhome
   cp ~/.config/adguardhome/AdGuardHome.yaml.backup ~/.config/adguardhome/AdGuardHome.yaml
   systemctl --user start adguardhome
   ```

### 2. DNS Not Resolving

**Symptoms**:

- Queries timing out
- "DNS resolution failed" errors
- Can't browse internet
- `nslookup` or `dig` commands fail

**Diagnosis**:

```bash
# Test DNS resolution from NAS VM
nslookup google.com 192.168.30.15
nslookup google.com 100.65.73.89  # Tailscale IP

# Test from another machine
nslookup google.com 192.168.30.15

# Check if AdGuard is listening
sudo netstat -tulpn | grep :53

# Check AdGuard logs for queries
journalctl --user -u adguardhome | tail -50
```

**Solutions**:

1. **AdGuard not listening on correct interface**:

   ```bash
   # Check bind configuration in AdGuardHome.yaml
   cat ~/.config/adguardhome/AdGuardHome.yaml | grep bind_host

   # Should be 0.0.0.0 (all interfaces) or specific IPs
   # Edit if needed:
   nano ~/.config/adguardhome/AdGuardHome.yaml

   # Restart
   systemctl --user restart adguardhome
   ```

2. **Firewall blocking DNS traffic**:

   ```bash
   # Allow DNS traffic
   sudo ufw allow from 192.168.30.0/24 to any port 53 proto tcp
   sudo ufw allow from 192.168.30.0/24 to any port 53 proto udp
   sudo ufw allow from 100.64.0.0/10 to any port 53 proto tcp
   sudo ufw allow from 100.64.0.0/10 to any port 53 proto udp
   sudo ufw reload
   ```

3. **Upstream DNS servers not responding**:

   ```bash
   # Check upstream DNS configuration
   journalctl --user -u adguardhome | grep -i "upstream"

   # Test upstream servers
   nslookup google.com 1.1.1.1
   nslookup google.com 1.0.0.1

   # Configure in Web UI: Settings → DNS Settings → Upstream DNS servers
   # Recommended: 1.1.1.1, 1.0.0.1, 8.8.8.8
   ```

4. **AdGuard not started or crashed**:

   ```bash
   systemctl --user status adguardhome
   systemctl --user start adguardhome
   systemctl --user enable adguardhome
   ```

### 3. Can't Access Web UI

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://nas.discus-moth.ts.net:80
- Can't reach http://192.168.30.15:80

**Diagnosis**:

```bash
# Check if AdGuard is running
systemctl --user status adguardhome

# Check firewall rules
sudo ufw status

# Test local access
curl http://localhost:80

# Check if accessible from Tailscale IP
curl http://$(tailscale ip -4):80
```

**Solutions**:

1. **Firewall blocking HTTP port 80**:

   ```bash
   # Allow Web UI access
   sudo ufw allow from 192.168.30.0/24 to any port 80
   sudo ufw allow from 100.64.0.0/10 to any port 80
   sudo ufw reload
   ```

2. **AdGuard listening on wrong port or interface**:

   ```bash
   # Check bind configuration
   cat ~/.config/adguardhome/AdGuardHome.yaml | grep bind_port

   # Verify AdGuard is listening
   sudo netstat -tulpn | grep :80

   # Edit configuration if needed
   nano ~/.config/adguardhome/AdGuardHome.yaml
   # Look for:
   #   bind_port: 80
   #   bind_host: 0.0.0.0

   systemctl --user restart adguardhome
   ```

3. **Container networking issues**:

   ```bash
   # Check container ports
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman port adguardhome

   # Should show mappings for port 53 and 80
   # If missing, check Quadlet .container file
   cat ~/.config/containers/systemd/adguardhome.container | grep PublishPort
   ```

### 4. Ads Not Being Blocked

**Symptoms**:

- Ads still appearing on websites
- Ad domains not being filtered
- Blocking seems ineffective

**Diagnosis**:

```bash
# Check if filtering is enabled
cat ~/.config/adguardhome/AdGuardHome.yaml | grep filtering_enabled

# Test if known ad domain is blocked
nslookup ads.google.com 192.168.30.15

# Check blocklist status in logs
journalctl --user -u adguardhome | grep -i "blocklist\|filter"
```

**Solutions**:

1. **Filtering disabled**:
   - Access Web UI: http://nas.discus-moth.ts.net:80
   - Go to Settings → General Settings
   - Verify "Enable AdGuard DNS protection" is checked
   - Click Save

2. **Blocklists not updated or empty**:
   - Go to Filters → DNS blocklists
   - Check list count (should have thousands of rules)
   - Click "Update filters" to refresh
   - Add more blocklists:
     - AdGuard DNS filter (default)
     - Steven Black's hosts: `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
     - OISD Big List: `https://big.oisd.nl/`

3. **Client using different DNS server**:

   ```bash
   # On client machine, verify DNS server
   nslookup google.com
   # Should show: Server: 192.168.30.15 or 100.65.73.89

   # Check client DNS configuration
   cat /etc/resolv.conf   # Linux
   ipconfig /all          # Windows
   ```

4. **Browser using DNS-over-HTTPS (DoH)**:
   - Chrome/Firefox may bypass system DNS
   - Disable DoH in browser settings
   - Or configure AdGuard as DoH server (Settings → Encryption)

5. **Ad domain not in blocklist**:
   - Go to Query Log
   - Find unblocked ad domain
   - Add to custom blocklist (Filters → DNS blocklists → Add manually)

### 5. Query Log Not Working

**Symptoms**:

- Query log empty or not updating
- Can't see DNS queries
- "No data" in statistics

**Diagnosis**:

```bash
# Check if query logging is enabled
cat ~/.config/adguardhome/AdGuardHome.yaml | grep querylog_enabled

# Check disk space for logs
df -h ~/.config/adguardhome/
```

**Solutions**:

1. **Query logging disabled**:
   - Web UI → Settings → General Settings
   - Enable "Enable query logging"
   - Set retention period (e.g., 7 days)
   - Click Save

2. **Query log database corrupted**:

   ```bash
   systemctl --user stop adguardhome
   rm ~/.config/adguardhome/data/querylog.db*
   systemctl --user start adguardhome
   ```

3. **Insufficient disk space**:

   ```bash
   # Check available space
   df -h /home

   # Clean old logs if needed
   systemctl --user stop adguardhome
   rm -rf ~/.config/adguardhome/data/querylog.db.old
   systemctl --user start adguardhome
   ```

### 6. Statistics Not Showing

**Symptoms**:

- Dashboard shows "No data"
- Statistics reset unexpectedly
- Graphs empty

**Diagnosis**:

```bash
# Check statistics configuration
cat ~/.config/adguardhome/AdGuardHome.yaml | grep statistics_interval

# Check stats database
ls -lh ~/.config/adguardhome/data/stats.db
```

**Solutions**:

1. **Statistics disabled**:
   - Web UI → Settings → General Settings
   - Enable "Enable statistics"
   - Set retention interval (e.g., 24 hours, 7 days)
   - Click Save

2. **Statistics database corrupted**:

   ```bash
   systemctl --user stop adguardhome
   rm ~/.config/adguardhome/data/stats.db*
   systemctl --user start adguardhome
   # Statistics will rebuild
   ```

3. **Recent fresh install**:
   - Statistics accumulate over time
   - Wait a few hours for data to appear

### 7. Safe Browsing/Parental Control Not Working

**Symptoms**:

- Malicious sites not blocked
- Adult content filter ineffective
- Safe search not enforced

**Diagnosis**:

```bash
# Check safe browsing configuration
cat ~/.config/adguardhome/AdGuardHome.yaml | grep safe_browsing_enabled

# Test if safe browsing is active
journalctl --user -u adguardhome | grep -i "safe"
```

**Solutions**:

1. **Safe browsing features disabled**:
   - Web UI → Settings → General Settings
   - Enable "Use AdGuard browsing security web service"
   - Enable "Use AdGuard parental control web service"
   - Enable "Safe Search" for search engines
   - Click Save

2. **Upstream DNS blocking safe browsing checks**:
   - Ensure upstream DNS allows AdGuard's safe browsing queries
   - Use public DNS: 1.1.1.1, 8.8.8.8 (not filtering DNS)

3. **Per-client configuration needed**:
   - Go to Settings → Client Settings
   - Create client groups with different filtering rules
   - Apply safe browsing to specific clients

## Advanced Troubleshooting

### Reset AdGuard Configuration

```bash
# Backup configuration first
systemctl --user stop adguardhome
cp ~/.config/adguardhome/AdGuardHome.yaml ~/AdGuardHome.yaml.backup
cp -r ~/.config/adguardhome/data/ ~/adguardhome-data-backup/

# Remove configuration (will require setup wizard)
rm ~/.config/adguardhome/AdGuardHome.yaml
rm -rf ~/.config/adguardhome/data/

# Restart (will show setup wizard on first access)
systemctl --user start adguardhome
```

### Check Quadlet Configuration

```bash
# View generated systemd service
systemctl --user cat adguardhome

# View Quadlet .container file
cat ~/.config/containers/systemd/adguardhome.container

# Regenerate service from Quadlet
systemctl --user daemon-reload
systemctl --user restart adguardhome
```

### Container Resource Usage

```bash
# Check current resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats adguardhome --no-stream

# Check memory/CPU limits
podman inspect adguardhome | grep -A 5 "Memory\|Cpu"
```

### Network Debugging

```bash
# Enter container shell
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec -it adguardhome /bin/sh

# Inside container, test upstream DNS
nslookup google.com 1.1.1.1

# Test blocklist connectivity
wget -O- https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt | head

# Exit
exit
```

### Backup and Restore

```bash
# Backup AdGuard configuration
systemctl --user stop adguardhome
tar -czf ~/adguard-backup-$(date +%Y%m%d).tar.gz ~/.config/adguardhome/
systemctl --user start adguardhome

# Restore from backup
systemctl --user stop adguardhome
rm -rf ~/.config/adguardhome/
tar -xzf ~/adguard-backup-*.tar.gz -C ~/
systemctl --user start adguardhome
```

## Performance Optimization

### For High Query Volume

If serving DNS for many clients:

1. **Increase cache size**:
   - Settings → DNS Settings → Cache size
   - Increase to 10-20 MB for high traffic

2. **Enable parallel upstream queries**:
   - Settings → DNS Settings
   - Enable "Parallel requests to all upstream servers"

3. **Reduce logging verbosity**:
   - Settings → General Settings
   - Reduce query log retention to 24 hours
   - Disable statistics if not needed

## Getting Help

If issues persist after trying these solutions:

1. **Check AdGuard logs**:

   ```bash
   journalctl --user -u adguardhome -n 500 --no-pager > /tmp/adguardhome.log
   ```

2. **Enable debug logging**:

   Edit `~/.config/adguardhome/AdGuardHome.yaml`:

   ```yaml
   log_file: ""
   log_max_backups: 0
   log_max_size: 100
   log_max_age: 3
   log_compress: false
   log_localtime: false
   verbose: true  # Enable verbose logging
   ```

   Restart: `systemctl --user restart adguardhome`

3. **Gather diagnostic info**:

   ```bash
   # AdGuard version
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman exec adguardhome /opt/adguardhome/AdGuardHome --version

   # Configuration overview
   cat ~/.config/adguardhome/AdGuardHome.yaml

   # Network status
   sudo netstat -tulpn | grep -E ":53|:80"
   ```

4. **AdGuard community resources**:
   - Official docs: https://adguard.com/en/adguard-home/overview.html
   - Forum: https://forum.adguard.com/
   - GitHub: https://github.com/AdguardTeam/AdGuardHome/issues
   - Reddit: r/Adguard

## See Also

- [AdGuard Home Configuration Guide](../configuration/adguard-home.md) - Initial setup instructions
- [DNS Troubleshooting](dns.md) - DNS-specific issues
- [Networking Troubleshooting](networking.md) - Network configuration issues
- [NAS Troubleshooting](nas-nfs.md) - NAS VM issues
- [Service Endpoints](../configuration/service-endpoints.md) - AdGuard access information

# DNS Troubleshooting

Troubleshooting guide for AdGuard Home DNS service and DNS resolution issues.

## Quick Checks

```bash
# Test DNS resolution
dig @nas.discus-moth.ts.net google.com

# Test MagicDNS (.ts.net domains)
dig @nas.discus-moth.ts.net jellyfin.discus-moth.ts.net

# Check AdGuard Home container status
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net docker ps | grep adguard

# Check container logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net docker logs adguardhome --tail 50

# Check firewall rules
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net sudo ufw status | grep -E "(53|80)"
```

## Common Issues

### 1. DNS Not Resolving

**Symptoms**:

- Websites won't load
- DNS queries time out
- `dig` or `nslookup` returns no answer

**Diagnosis**:

```bash
# Test DNS directly to AdGuard Home
dig @nas.discus-moth.ts.net google.com

# Test with different domain
dig @nas.discus-moth.ts.net cloudflare.com

# Check if AdGuard Home container is running
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net docker ps | grep adguard

# Check container logs for errors
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net docker logs adguardhome --tail 100

# Test upstream DNS servers
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "docker exec adguardhome nslookup google.com 9.9.9.9"
```

**Solutions**:

1. **Container not running**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
   cd /opt/adguard-home
   docker compose up -d
   ```

2. **Upstream DNS servers unreachable**:
   - Check via Web UI: Settings → DNS Settings → Test upstreams
   - If DoT servers fail, temporarily switch to plaintext:
     - Web UI → Settings → DNS Settings → Upstream DNS servers
     - Change `tls://dns.quad9.net` to `9.9.9.9`
     - Change `tls://1dot1dot1dot1.cloudflare-dns.com` to `1.1.1.1`

3. **Firewall blocking DNS**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
   sudo ufw status | grep 53

   # If missing, add rules
   sudo ufw allow from 192.168.0.0/24 to any port 53
   sudo ufw allow from 100.64.0.0/10 to any port 53
   sudo ufw reload
   ```

4. **systemd-resolved conflict**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

   # Check if systemd-resolved is using port 53
   sudo lsof -i :53

   # Disable stub listener
   sudo sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
   sudo systemctl restart systemd-resolved

   # Restart AdGuard Home
   cd /opt/adguard-home
   docker compose restart
   ```

---

### 2. Slow DNS Resolution

**Symptoms**:

- Websites load slowly (5-10 second delay before loading)
- DNS query response time > 100ms
- Buffering when streaming media

**Diagnosis**:

```bash
# Test DNS response time
dig @nas.discus-moth.ts.net google.com +stats | grep "Query time"

# Check AdGuard Home dashboard
# Web UI → Dashboard → Average processing time

# Check container resource usage
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  docker stats adguardhome --no-stream
```

**Solutions**:

1. **Too many blocklists**:
   - Reduce number of blocklists in Web UI
   - Disable overlapping/redundant lists
   - Target: < 5-7 blocklists total
   - Recommended: Keep only OISD Big List + AdGuard DNS filter

2. **Upstream DNS slow**:
   - Web UI → Settings → DNS Settings → Test upstreams
   - Identify slow upstream (response time > 100ms)
   - Reorder upstreams to put faster ones first
   - Consider using faster upstreams (Cloudflare 1.1.1.1 is typically fastest)

3. **Cache size too small**:

   ```bash
   # Increase cache via Web UI
   # Settings → DNS Settings → Cache size
   # Increase from 4 MB to 8 MB
   ```

4. **NAS VM overloaded**:

   ```bash
   # Check NAS CPU/memory
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net htop

   # If high CPU, check what's consuming resources
   top -o %CPU

   # If high memory, reduce AdGuard Home query log retention
   # Web UI → Settings → DNS Settings → Query log settings
   # Reduce from 90 days to 30 days
   ```

---

### 3. MagicDNS Not Working (*.ts.net domains not resolving)

**Symptoms**:

- Can't access services via `*.discus-moth.ts.net` hostnames
- `dig jellyfin.discus-moth.ts.net` returns NXDOMAIN or SERVFAIL
- Tailscale IPs work, but hostnames don't

**Diagnosis**:

```bash
# Test MagicDNS resolution
dig @nas.discus-moth.ts.net jellyfin.discus-moth.ts.net

# Test MagicDNS directly
dig @100.100.100.100 jellyfin.discus-moth.ts.net

# Check AdGuard Home upstream config
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  cat /opt/adguard-home/conf/AdGuardHome.yaml | grep -A 5 "upstream_dns"
```

**Solutions**:

1. **MagicDNS upstream not configured**:
   - Web UI → Settings → DNS Settings → Upstream DNS servers
   - Verify first line is: `[/ts.net/]100.100.100.100`
   - If missing, add it at the **top of the list**
   - Click "Save"

2. **MagicDNS upstream ordered incorrectly**:
   - The `[/ts.net/]` line must be **first**
   - Other upstreams should be below it
   - Correct order:

     ```text
     [/ts.net/]100.100.100.100
     tls://dns.quad9.net
     tls://1dot1dot1dot1.cloudflare-dns.com
     ```

3. **Tailscale MagicDNS disabled**:
   - Visit Tailscale Admin Console → DNS
   - Verify "MagicDNS" toggle is **Enabled**
   - If disabled, enable it and wait 1-2 minutes for propagation

4. **Blocklist blocking *.ts.net**:
   - Check if domain is blocked: Web UI → Query Log → Search for `ts.net`
   - If blocked, add whitelist rule:
     - Web UI → Filters → Custom filtering rules
     - Add: `@@||ts.net^$important`
     - Click "Save"

---

### 4. Can't Access AdGuard Home Web UI

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://nas.discus-moth.ts.net:80

**Diagnosis**:

```bash
# Check if container is running
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net docker ps | grep adguard

# Check firewall rules for port 80
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net sudo ufw status | grep 80

# Test local access
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net curl -I http://localhost:80

# Test Tailscale access
curl -I http://nas.discus-moth.ts.net:80
```

**Solutions**:

1. **Container not running**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
   cd /opt/adguard-home
   docker compose up -d
   ```

2. **Firewall blocking port 80**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

   # Add firewall rule
   sudo ufw allow from 100.64.0.0/10 to any port 80 comment 'AdGuard Home Web UI (Tailscale)'
   sudo ufw reload

   # Verify rule added
   sudo ufw status | grep 80
   ```

3. **Port 80 conflict with another service**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

   # Check what's using port 80
   sudo lsof -i :80

   # If nginx or Apache is running, stop it
   sudo systemctl stop nginx
   # OR
   sudo systemctl stop apache2

   # Restart AdGuard Home
   cd /opt/adguard-home
   docker compose restart
   ```

4. **Wrong Tailscale IP configured**:

   ```bash
   # Get current Tailscale IP
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net tailscale ip -4

   # Access using IP directly
   curl -I http://<tailscale-ip>:80
   ```

---

### 5. AdGuard Home Container Keeps Restarting

**Symptoms**:

- Container restarts every few seconds or minutes
- `docker ps` shows "Restarting" status

**Diagnosis**:

```bash
# Check container status
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  docker ps -a | grep adguard

# Check recent logs for errors
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  docker logs adguardhome --tail 200

# Check for port conflicts
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  sudo lsof -i :53 -i :80
```

**Solutions**:

1. **Corrupted configuration**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
   cd /opt/adguard-home

   # Backup config
   sudo cp conf/AdGuardHome.yaml conf/AdGuardHome.yaml.bak

   # Check for syntax errors
   docker compose config

   # If config is invalid, restore from backup or re-deploy
   # Run playbook: ./bin/runtime/ansible-run.sh playbooks/14-configure-adguard-home-role.yml
   ```

2. **Out of memory**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

   # Check available memory
   free -h

   # If low, reduce AdGuard Home memory usage:
   # - Reduce query log retention (Web UI)
   # - Reduce cache size (Web UI)
   # - Reduce blocklist count
   ```

3. **Disk full**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

   # Check disk space
   df -h /opt/adguard-home

   # If low, clean up old query logs
   cd /opt/adguard-home/work
   sudo rm -rf querylog.json.*
   ```

---

### 6. Blocklist Update Failures

**Symptoms**:

- Blocklists show "Update failed" in Web UI
- Last update time is days/weeks old
- Error message: "Failed to download blocklist"

**Diagnosis**:

```bash
# Check AdGuard Home logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  docker logs adguardhome --tail 100 | grep -i "filter"

# Test blocklist URL manually
curl -I https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt

# Check if NAS has internet access
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net ping -c 3 google.com
```

**Solutions**:

1. **Network connectivity issue**:

   ```bash
   # Test DNS resolution from container
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
     docker exec adguardhome nslookup google.com

   # If fails, check if NAS can resolve DNS
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net nslookup google.com
   ```

2. **Blocklist URL changed or removed**:
   - Remove the broken blocklist from Web UI
   - Find replacement list (see docs/configuration/adguard-home.md)
   - Add new list with updated URL

3. **Rate limiting**:
   - Some blocklist providers rate limit requests
   - Wait 1 hour and retry
   - Stagger updates if you have many lists (don't update all at once)

4. **Certificate verification failure**:

   ```bash
   # Check container time (should match real time)
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net docker exec adguardhome date

   # If wrong, sync NAS time
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net sudo timedatectl set-ntp true
   ```

---

## Rollback to Tailscale ControlD

If AdGuard Home is completely broken and you need immediate DNS restoration:

1. **Tailscale Admin Console** → DNS
2. **Remove custom nameserver**:
   - Find the NAS IP (100.65.73.89)
   - Click "X" to remove it
3. **Re-enable ControlD**:
   - Click "Add nameserver"
   - Select "ControlD" (or other public DNS)
4. **Test DNS**:

   ```bash
   # From any VM
   nslookup google.com
   dig jellyfin.discus-moth.ts.net
   ```

**Note**: This disables ad blocking but restores DNS functionality immediately.

---

## Diagnostic Commands Reference

### DNS Resolution Tests

```bash
# Test specific DNS server
dig @nas.discus-moth.ts.net google.com

# Test with TCP (instead of UDP)
dig @nas.discus-moth.ts.net google.com +tcp

# Test specific record type
dig @nas.discus-moth.ts.net google.com A
dig @nas.discus-moth.ts.net google.com AAAA

# Show full response (including upstream used)
dig @nas.discus-moth.ts.net google.com +trace

# Test reverse DNS
dig @nas.discus-moth.ts.net -x 192.168.0.15
```

### Container Management

```bash
# View real-time logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  docker logs adguardhome -f

# Check container resource usage
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  docker stats adguardhome

# Restart container
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "cd /opt/adguard-home && docker compose restart"

# Rebuild container from scratch
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "cd /opt/adguard-home && docker compose down && docker compose up -d"
```

### Network Diagnostics

```bash
# Check DNS port availability
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  sudo lsof -i :53

# Check web UI port availability
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  sudo lsof -i :80

# Test connectivity from NAS to upstream DNS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  nc -zv 9.9.9.9 53

# Test DoT connectivity
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  openssl s_client -connect dns.quad9.net:853 -servername dns.quad9.net
```

### Configuration Inspection

```bash
# View current AdGuard Home config
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  cat /opt/adguard-home/conf/AdGuardHome.yaml

# View upstream DNS config
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  cat /opt/adguard-home/conf/AdGuardHome.yaml | grep -A 10 "upstream_dns"

# Check Docker Compose config
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  cat /opt/adguard-home/docker-compose.yml
```

---

## Performance Optimization

### If DNS is slow (> 50ms)

1. **Reduce blocklists** (target: 5-7 lists max)
2. **Use faster upstreams** (Cloudflare 1.1.1.1 is typically fastest)
3. **Increase cache size** (Settings → DNS Settings → 8-16 MB)
4. **Enable optimistic caching** (Settings → DNS Settings)
5. **Reduce query log retention** (30 days instead of 90)

### If NAS VM is resource-constrained

1. **Disable query logging** (Settings → Query log → Disable)
2. **Disable statistics** (Settings → Statistics → Disable)
3. **Reduce blocklist count** (use OISD Big List only)
4. **Lower cache size** (2-4 MB)

---

## See Also

- [AdGuard Home Configuration Guide](../configuration/adguard-home.md) - Complete setup and usage guide
- [Service Endpoints](../configuration/service-endpoints.md) - DNS service URLs and IPs
- [Network Configuration](../configuration/networking.md) - Network architecture and firewall rules
- [Common Issues](common-issues.md) - General troubleshooting procedures

---

## External Resources

- [AdGuard Home GitHub Issues](https://github.com/AdguardTeam/AdGuardHome/issues)
- [AdGuard Home Wiki](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [DNS Troubleshooting Guide (Cloudflare)](https://www.cloudflare.com/learning/dns/dns-troubleshooting/)
- [Tailscale DNS Documentation](https://tailscale.com/kb/1054/dns)

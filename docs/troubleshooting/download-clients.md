# Download Clients Troubleshooting

Troubleshooting guide for qBittorrent and SABnzbd download client issues.

## Quick Checks

```bash
# Check containers are running
docker ps | grep -E "qbittorrent|sabnzbd"

# View logs
docker logs qbittorrent --tail 100
docker logs sabnzbd --tail 100

# Check web access
curl http://localhost:8080  # qBittorrent
curl http://localhost:8081  # SABnzbd

# Verify NFS mount
df -h /mnt/data
```

## qBittorrent Issues

### 1. Can't Access qBittorrent Web UI

**Symptoms**:

- Connection refused on port 8080
- Can't reach http://download-clients.discus-moth.ts.net:8080

**Diagnosis**:

```bash
# Check container status
docker ps -a | grep qbittorrent

# Check logs
docker logs qbittorrent --tail 50

# Check port
sudo netstat -tulpn | grep 8080
```

**Solutions**:

1. **Container not running**:

   ```bash
   cd /opt/download-clients
   docker compose up -d qbittorrent
   ```

2. **Get default password**:

   ```bash
   docker logs qbittorrent 2>&1 | grep -i password
   # Default username: admin
   # Default password: shown in logs
   ```

3. **Firewall blocking**:

   ```bash
   sudo ufw allow from 192.168.0.0/24 to any port 8080
   sudo ufw allow from 100.64.0.0/10 to any port 8080
   sudo ufw reload
   ```

### 2. qBittorrent Downloads Not Starting

**Symptoms**:

- Torrents added but stay paused
- Error: "Disk write error"
- Permission denied errors

**Diagnosis**:

```bash
# Check directory permissions
ls -la /mnt/data/torrents

# Check disk space
df -h /mnt/data

# View qBittorrent logs
docker logs qbittorrent --tail 100
```

**Solutions**:

1. **Permission issues**:

   ```bash
   sudo chown -R 3000:3000 /mnt/data/torrents
   sudo chmod -R 775 /mnt/data/torrents
   ```

2. **Disk space full**:

   ```bash
   # Check what's using space
   du -sh /mnt/data/*

   # Clean up if needed
   ```

3. **Wrong save path**:
   - Options > Downloads > Default Save Path: `/data/torrents`
   - NOT `/mnt/data/` or other paths

### 3. qBittorrent Categories Not Working

**Symptoms**:

- Downloads go to wrong folder
- Category not applied
- Files mixed between TV and movies

**Diagnosis**:

- Check Options > Downloads > Automatic Torrent Management
- Verify categories in UI (right-click sidebar > Add category)

**Solutions**:

> **Note**: Automatic Torrent Management and categories are configured automatically via API during deployment (playbook
07). The following are for verification or manual fixes only.

1. **Verify Automatic Torrent Management** (should already be enabled):
   - Options > Downloads > Saving Management
   - ☑ "Automatic Torrent Management" should be enabled
   - Default Torrent Management Mode: **Automatic**

2. **Verify categories exist** (should already be created):
   - Check sidebar for `tv` and `movies` categories
   - `tv` → Save path: `/data/torrents/tv`
   - `movies` → Save path: `/data/torrents/movies`
   - If missing, re-run: `./bin/runtime/ansible-run.sh playbooks/core/07-configure-download-clients-role.yml`

3. **Configure in Sonarr/Radarr**:
   - Settings > Download Clients > [qBittorrent]
   - Category: `tv` (Sonarr) or `movies` (Radarr)

### 4. qBittorrent High CPU Usage

**Symptoms**:

- qBittorrent using excessive CPU
- System slow during downloads
- Web UI unresponsive

**Diagnosis**:

```bash
# Check CPU usage
docker stats qbittorrent

# Check number of active torrents
docker logs qbittorrent | grep -i "torrent"
```

**Solutions**:

> **Note**: Performance and connection limits are pre-configured via API during deployment (playbook 07). The following
are for verification only.

1. **Verify active torrent limits** (should already be set):
   - Options > BitTorrent
   - Maximum active downloads: 5
   - Maximum active uploads: 3
   - Maximum active torrents: 10

2. **Verify connection limits** (should already be set):
   - Options > Connection
   - Global maximum connections: 500
   - Maximum connections per torrent: 100

3. **Verify privacy/performance features** (should already be configured):
   - Options > BitTorrent
   - ☑ Anonymous Mode enabled
   - ☐ Enable DHT disabled
   - ☐ Enable PeX disabled
   - ☐ Enable Local Peer Discovery disabled
   - Encryption mode: "Prefer encryption"

## SABnzbd Issues

### 1. Can't Access SABnzbd Web UI

**Symptoms**:

- Connection refused on port 8081
- Can't reach http://download-clients.discus-moth.ts.net:8081
- Error: "Access denied - Hostname verification failed"

**Diagnosis**:

```bash
# Check container status
docker ps -a | grep sabnzbd

# Check logs
docker logs sabnzbd --tail 50

# Check configuration
docker exec sabnzbd cat /config/sabnzbd.ini | grep -E "host_whitelist|local_ranges"
```

**Solutions**:

1. **Container not running**:

   ```bash
   cd /opt/download-clients
   docker compose up -d sabnzbd
   ```

2. **Hostname verification failing**:
   - Config > General > Security
   - Host whitelist should include: `download-clients.discus-moth.ts.net, 192.168.0.14, localhost, 127.0.0.1, sabnzbd`
   - Or restart container (should be set by playbook)

3. **Local ranges misconfigured**:
   - Config > Special > local_ranges
   - Should include: `192.168.0.0/16, 172.16.0.0/12, 100.64.0.0/10`

### 2. SABnzbd Won't Download

**Symptoms**:

- NZBs added but don't download
- Error: "No servers available"
- Downloads fail immediately

**Diagnosis**:

```bash
# Check logs
docker logs sabnzbd --tail 100

# Check server config
docker exec sabnzbd cat /config/sabnzbd.ini | grep -A 5 "\\[servers\\]"
```

**Solutions**:

1. **No Usenet server configured**:
   - Config > Servers > Add Server
   - Enter provider details (host, port, username, password, connections)
   - Test server connection

2. **Server credentials wrong**:
   - Verify username/password with provider
   - Check subscription is active
   - Test with provider's web interface

3. **SSL/TLS issues**:
   - Try port 443 (SSL) or 119 (non-SSL)
   - Enable/disable SSL as needed

### 3. SABnzbd Permission Errors

**Symptoms**:

- Error: "Cannot create directory"
- Error: "Permission denied"
- Files not moving to complete folder

**Diagnosis**:

```bash
# Check directory permissions
ls -la /mnt/data/usenet

# Check SABnzbd's effective UID/GID
docker exec sabnzbd id

# Check volume mounts
docker inspect sabnzbd | grep -A 10 Mounts
```

**Solutions**:

1. **Fix permissions**:

   ```bash
   sudo chown -R 3000:3000 /mnt/data/usenet
   sudo chmod -R 775 /mnt/data/usenet
   ```

2. **Verify directory paths**:
   - Config > Folders
   - Temporary Download Folder: `/data/usenet/incomplete`
   - Completed Download Folder: `/data/usenet`

3. **Check container PUID/PGID** (should be 3000):

   ```bash
   docker exec sabnzbd printenv | grep -E "PUID|PGID"
   ```

### 4. SABnzbd Categories Not Working

**Symptoms**:

- Downloads go to wrong folder
- Sonarr/Radarr can't find completed downloads
- Categories not applied

**Diagnosis**:

- Config > Categories
- Check folder paths for `tv` and `movies` categories

**Solutions**:

1. **Create/fix categories**:
   - Config > Categories
   - Category `tv`: Folder = `tv` (relative to completed folder)
   - Category `movies`: Folder = `movies`

2. **Update Sonarr/Radarr**:
   - Settings > Download Clients > [SABnzbd]
   - Category: `tv` (Sonarr) or `movies` (Radarr)

### 5. SABnzbd API Issues

**Symptoms**:

- Sonarr/Radarr can't connect to SABnzbd
- Error: "API call failed"
- Authentication errors

**Diagnosis**:

```bash
# Get API key
docker exec sabnzbd cat /config/sabnzbd.ini | grep "^api_key"

# Test API
API_KEY="your_api_key_here"
curl "http://localhost:8080/api?mode=version&apikey=$API_KEY"
```

**Solutions**:

1. **Get correct API key**:
   - SABnzbd Config > General > Security > API Key
   - Copy this to Sonarr/Radarr download client settings

2. **Use correct port**:
   - From Sonarr/Radarr containers: Port `8080` (internal)
   - From external: Port `8081`
   - Host: `download-clients.discus-moth.ts.net` or `192.168.0.14`

3. **Test connectivity**:

   ```bash
   docker exec sonarr wget -O- "http://download-clients.discus-moth.ts.net:8081/sabnzbd/api?mode=version&apikey=YOUR_KEY"
   ```

## VPN (Gluetun) Issues

Download clients route traffic through Gluetun VPN for privacy. See [VPN Configuration
Guide](../configuration/vpn-gluetun.md) for full details.

### 1. VPN Not Connected

**Symptoms**:

- Gluetun container unhealthy
- Download clients have no internet access
- Logs show VPN connection errors

**Diagnosis**:

```bash
# Check Gluetun status
docker ps | grep gluetun
# Should show "healthy" status

# View Gluetun logs
docker logs gluetun --tail 100

# Check VPN connection
docker exec gluetun wget -qO- ifconfig.me
# Should show VPN provider's IP, not your home IP
```

**Solutions**:

1. **Invalid VPN credentials**:
   - Verify credentials in secrets file are correct
   - WireGuard: Check private key and address
   - OpenVPN: Check username and password
   - Redeploy: `./bin/runtime/ansible-run.sh playbooks/core/07-configure-download-clients-role.yml`

2. **VPN provider server issues**:

   ```bash
   # Check Gluetun logs for specific error
   docker logs gluetun | grep -i error

   # Try different server location (edit secrets file)
   sops group_vars/all.sops.yaml
   # Change: server_countries: "Switzerland,Netherlands"
   ```

3. **Protocol issues**:
   - Try switching between WireGuard and OpenVPN
   - Edit secrets file and change `vpn.protocol`
   - Redeploy configuration

### 2. Download Clients Have No Internet After Gluetun Deployment

**Symptoms**:

- qBittorrent/SABnzbd can't reach internet
- Trackers unreachable
- Usenet server connection fails

**Diagnosis**:

```bash
# Check if Gluetun is healthy
docker ps | grep gluetun

# Test internet from download clients
docker exec qbittorrent ping -c 3 8.8.8.8
docker exec sabnzbd wget -qO- --timeout=5 ifconfig.me
```

**Solutions**:

1. **Gluetun not healthy**:

   ```bash
   # Check Gluetun health
   docker inspect gluetun | grep Health -A 10

   # Restart Gluetun
   docker restart gluetun

   # Wait for healthy status, then restart download clients
   docker restart qbittorrent sabnzbd
   ```

2. **Firewall blocking local subnets**:
   - Verify `FIREWALL_OUTBOUND_SUBNETS` includes:
     - `192.168.0.0/24` (local network)
     - `100.64.0.0/10` (Tailscale)

   ```bash
   docker exec gluetun env | grep FIREWALL_OUTBOUND_SUBNETS
   ```

3. **Network mode misconfigured**:

   ```bash
   # Verify containers use Gluetun network
   docker inspect qbittorrent | grep NetworkMode
   # Should show: "container:gluetun"

   docker inspect sabnzbd | grep NetworkMode
   # Should show: "container:gluetun"
   ```

### 3. Can't Access Web UIs After VPN Deployment

**Symptoms**:

- qBittorrent/SABnzbd web UIs unreachable
- Tailscale access doesn't work
- Connection refused errors

**Diagnosis**:

```bash
# Check if Gluetun exposes correct ports
docker ps | grep gluetun
# Should show: 0.0.0.0:8080->8080/tcp, 0.0.0.0:8081->8081/tcp

# Test local access
curl -I http://localhost:8080  # qBittorrent
curl -I http://localhost:8081  # SABnzbd
```

**Solutions**:

1. **Gluetun not exposing ports**:
   - Check [`services/compose/services/gluetun.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/services/gluetun.yml) has correct port mappings
   - Redeploy: `./bin/runtime/ansible-run.sh playbooks/core/07-configure-download-clients-role.yml`

2. **SABnzbd wrong port**:
   - SABnzbd should listen on port 8081 internally (not 8080)

   ```bash
   docker exec sabnzbd cat /config/sabnzbd.ini | grep "^port"
   # Should show: port = 8081
   ```

3. **Firewall blocking inbound**:

   ```bash
   # Check UFW rules
   sudo ufw status | grep -E "8080|8081"

   # Allow if needed
   sudo ufw allow from 192.168.0.0/24 to any port 8080
   sudo ufw allow from 192.168.0.0/24 to any port 8081
   sudo ufw allow from 100.64.0.0/10 to any port 8080
   sudo ufw allow from 100.64.0.0/10 to any port 8081
   sudo ufw reload
   ```

### 4. Verifying VPN Kill-Switch Works

The kill-switch prevents download clients from leaking your real IP if VPN disconnects.

**Test procedure**:

```bash
# 1. Check current IP (should be VPN provider's)
docker exec qbittorrent wget -qO- ifconfig.me

# 2. Stop Gluetun
docker stop gluetun

# 3. Try to access internet (should FAIL)
docker exec qbittorrent wget -qO- --timeout=5 ifconfig.me
# Expected: Timeout or connection refused (kill-switch working)

# 4. Restart Gluetun
docker start gluetun

# 5. Wait for healthy status
docker ps | grep gluetun

# 6. Verify VPN reconnected
docker exec qbittorrent wget -qO- ifconfig.me
# Should show VPN IP again
```

**Expected behavior**: Download clients have NO internet access when Gluetun is stopped.

### 5. DNS Leak Detection

**Symptoms**:

- VPN connected but DNS queries go to ISP
- Your real location visible in DNS tests
- Privacy compromised

**Test procedure**:

1. Access qBittorrent web UI: `http://download-clients.discus-moth.ts.net:8080`
2. Navigate to: https://dnsleaktest.com
3. Run "Standard test" or "Extended test"

**Expected results**:

- All DNS servers should belong to VPN provider
- NO DNS servers from your ISP
- Location should match VPN server location

**Solutions if leaking**:

1. **Check Gluetun DNS configuration**:

   ```bash
   docker exec gluetun cat /etc/resolv.conf
   # Should show VPN provider's DNS servers
   ```

2. **Enable DNS over TLS (DoT)**:
   - Edit [`services/compose/services/gluetun.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/services/gluetun.yml)
   - Change: `DOT=on`
   - Change: `DOT_PROVIDERS=cloudflare` (or provider of choice)
   - Redeploy configuration

### 6. Slow Download Speeds with VPN

**Symptoms**:

- Downloads much slower than without VPN
- Torrents not connecting to peers
- Usenet downloads timing out

**Diagnosis**:

```bash
# Check VPN server location
docker logs gluetun | grep -i "connected to"

# Test speed from download client
docker exec qbittorrent wget -O /dev/null http://speedtest.tele2.net/100MB.zip
```

**Solutions**:

1. **Try WireGuard instead of OpenVPN**:
   - WireGuard is typically 20-30% faster
   - Edit secrets file: `vpn.protocol: wireguard`
   - Redeploy configuration

2. **Choose closer VPN server**:
   - Edit secrets file: `vpn.server_countries: "United States"` (or closer location)
   - Redeploy configuration

3. **Try different VPN provider server**:

   ```bash
   sops group_vars/all.sops.yaml
   # Change server_countries or add server_cities
   ```

4. **Check VPN provider port forwarding**:
   - Some providers support port forwarding for better torrent performance
   - See Gluetun wiki for provider-specific configuration

### 7. PIA Port Forwarding Not Working (Zero Upload Speed)

**Symptoms**:

- qBittorrent shows 0 upload speed
- Peers show flags: `? I E P` (connections not completing)
- Trackers report 0 seeds/leechers
- Port forwarding enabled but torrents won't seed

**How PIA Port Forwarding Works**:

1. PIA assigns a **dynamic forwarded port** (e.g., 46124) via API
2. Gluetun retrieves this port and writes it to `/tmp/gluetun/forwarded_port`
3. Ansible playbook automatically configures qBittorrent to listen on this port
4. **Automation script** syncs the port to Docker Compose and UFW firewall every 10 minutes

**Diagnosis**:

```bash
# 1. Check PIA forwarded port
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "docker exec gluetun cat /tmp/gluetun/forwarded_port"
# Example output: 46124

# 2. Check qBittorrent is listening on the same port
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "cat /opt/download-clients/services/qbittorrent/qBittorrent/qBittorrent.conf | grep 'Session\\Port='"
# Should match forwarded port

# 3. Check Docker is exposing the port
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "docker port gluetun | grep $(docker exec gluetun cat /tmp/gluetun/forwarded_port)"
# Should show: 46124/tcp -> 0.0.0.0:46124

# 4. Check UFW firewall allows the port
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "sudo ufw status | grep $(docker exec gluetun cat /tmp/gluetun/forwarded_port)"
# Should show ALLOW rules for the port

# 5. Verify Gluetun auto-configured its firewall
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "docker logs gluetun 2>&1 | grep 'setting allowed input port'"
# Should show: INFO [firewall] setting allowed input port XXXXX through interface tun0...

# 6. Check port sync automation status
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "systemctl status pia-port-sync.timer"
# Should show: active (waiting)

# 7. Check sync log for errors
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "cat /opt/download-clients/port-sync.log"
```

**Common Issues**:

1. **Port Mismatch (qBittorrent vs Docker vs UFW)**:
   - **Cause**: PIA port was updated but Docker/UFW not synced
   - **Solution**: Run sync script manually:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
     "sudo /opt/download-clients/sync-pia-port.sh"
   ```

2. **Gluetun Firewall Not Auto-Configured**:
   - **Cause**: Gluetun restarted before port forwarding initialized
   - **Solution**: Restart Gluetun and wait for healthy status:

   ```bash
   cd /opt/download-clients
   docker compose restart gluetun
   # Wait ~30 seconds
   docker ps | grep gluetun  # Should show "healthy"
   ```

3. **Old UFW Rules Still Present**:
   - **Cause**: Manual firewall rules for old port (e.g., 6881) still exist
   - **Check**: `sudo ufw status numbered | grep 6881`
   - **Solution**: Run sync script (it will clean up old rules)

4. **Anonymous Mode Blocking Handshakes**:
   - **Symptoms**: Peers connect but disconnect immediately (`? I E P` flags)
   - **Check**: qBittorrent Options → BitTorrent → "Enable anonymous mode"
   - **Solution**: Disable anonymous mode (doesn't provide additional privacy with VPN)

5. **No Leechers Available**:
   - **Symptoms**: Green connection icon, port forwarding working, but 0 upload
   - **Diagnosis**: Check tracker tab - if all show "0 Leeches" there's nobody to upload to
   - **Solution**: This is normal! Port forwarding IS working. Test with a popular torrent.

**Verifying Port Forwarding Works**:

In qBittorrent Web UI:

1. **Tools → Options → Connection**
2. Look at "Port used for incoming connections"
3. Should show the **same port** as Gluetun's forwarded port
4. **Green checkmark** = Port is reachable from internet ✅
5. **Red X** = Port unreachable (check firewall/Docker)

**Testing with DHT/PEX**:

- **Tools → Options → BitTorrent**
- ☑ Enable DHT (decentralized network) to find more peers
- ☑ Enable PEX (peer exchange)
- ☑ Enable Local Peer Discovery
- DHT nodes count should show at bottom of UI (e.g., "DHT: 259 nodes")

**Understanding Peer Flags**:

- **`?`** = Unknown/unestablished connection (normal during handshake)
- **`I`** = **Incoming connection** (GOOD! Port forwarding IS working)
- **`E`** = Encrypted connection
- **`P`** = uTP protocol
- **`D`** = Downloading from you (this is what you want to see)

**Automated Port Sync System**:

The infrastructure includes automated port synchronization:

- **Script**: `/opt/download-clients/sync-pia-port.sh`
- **Service**: `pia-port-sync.service` (systemd one-shot)
- **Timer**: `pia-port-sync.timer` (runs every 10 minutes + on boot)
- **What it does**:
  1. Reads PIA forwarded port from Gluetun
  2. Updates Docker Compose port mappings if changed
  3. Updates UFW firewall rules
  4. Recreates Gluetun container with new ports
  5. Logs to `/opt/download-clients/port-sync.log`

**Manual Port Sync**:

```bash
# Run immediately (doesn't wait for 10-minute timer)
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
  "sudo /opt/download-clients/sync-pia-port.sh"

# Check timer status
systemctl status pia-port-sync.timer

# Check last sync time
journalctl -u pia-port-sync.service -n 20

# View sync log
cat /opt/download-clients/port-sync.log
```

**Port Forwarding Lifecycle**:

- PIA forwarded ports **expire after 62 days**
- PIA may change your port during this time (rare)
- Automation handles port changes automatically
- No manual intervention required

**Solutions**:

1. **Re-run deployment playbook** (fixes all configuration):

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/core/07-configure-download-clients-role.yml
   ```

2. **Force immediate port sync**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
     "sudo /opt/download-clients/sync-pia-port.sh"
   ```

3. **Verify all components match**:

   ```bash
   # Get PIA port
   PIA_PORT=$(ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net \
     "docker exec gluetun cat /tmp/gluetun/forwarded_port")

   echo "PIA forwarded port: $PIA_PORT"

   # All of these should match $PIA_PORT:
   # - qBittorrent listening port
   # - Docker exposed port
   # - UFW allowed port
   # - Gluetun firewall allowed port
   ```

### 8. VPN Connected But Still Showing Real IP

**Symptoms**:

- Gluetun shows VPN connected
- Download clients still leak real IP
- IP check shows home IP, not VPN IP

**Diagnosis**:

```bash
# Check Gluetun IP
docker exec gluetun wget -qO- ifconfig.me

# Check qBittorrent IP
docker exec qbittorrent wget -qO- ifconfig.me

# Check SABnzbd IP
docker exec sabnzbd wget -qO- ifconfig.me
```

**Expected**: All three should show the SAME IP (VPN provider's IP)

**Solutions**:

1. **Containers not using Gluetun network**:

   ```bash
   # Verify network_mode
   docker inspect qbittorrent | grep -i networkmode
   docker inspect sabnzbd | grep -i networkmode
   # Both should show: "container:<gluetun_container_id>"
   ```

2. **Redeploy with correct network configuration**:

   ```bash
   cd /opt/download-clients
   docker compose down
   docker compose up -d
   ```

3. **Check for IPv6 leaks**:
   - Some VPNs don't support IPv6
   - Disable IPv6 on host if leaking:

   ```bash
   sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
   sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
   ```

## Unpackerr Integration

Unpackerr monitors download folders and automatically extracts archives after SABnzbd completes downloads. It's
configured to work seamlessly with SABnzbd.

### How It Works

1. **Sonarr/Radarr** → Sends NZB to SABnzbd with category (`tv` or `movies`)
2. **SABnzbd** → Downloads to `/data/usenet/incomplete`
3. **SABnzbd** → Verifies download, moves to `/data/usenet/tv` or `/data/usenet/movies`
4. **Unpackerr** → Detects archives (checks every 2 minutes)
5. **Unpackerr** → Extracts archives in place
6. **Unpackerr** → Notifies Sonarr/Radarr via API
7. **Sonarr/Radarr** → Imports and organizes media files

### Critical Configuration

**SABnzbd Must Have**:

- ✅ Direct Unpack: **DISABLED** (automated via playbook)
- ✅ Categories configured with proper paths
- ✅ Complete to: `/data/usenet/tv` (for TV) or `/data/usenet/movies` (for movies)

**Why Direct Unpack Must Be Disabled**:
If SABnzbd's Direct Unpack is enabled, BOTH SABnzbd and Unpackerr will try to extract the same archives, causing:

- Duplicate extraction (wasted CPU)
- File conflicts and corruption
- Failed imports in Sonarr/Radarr

### Troubleshooting Unpackerr

#### 1. Archives Not Being Extracted

**Symptoms**:

- RAR/ZIP files remain in download folders
- Sonarr/Radarr never import content
- No extraction activity in logs

**Diagnosis**:

```bash
# Check Unpackerr is running
docker ps | grep unpackerr

# Check logs
docker logs unpackerr --tail 100

# Check monitored paths
docker exec unpackerr env | grep UN_SONARR_0_PATHS
docker exec unpackerr env | grep UN_RADARR_0_PATHS
```

**Solutions**:

1. **Unpackerr not detecting archives**:

   ```bash
   # Verify SABnzbd categories are correct
   docker exec sabnzbd cat /config/sabnzbd.ini | grep -A 5 "\\[categories\\]"

   # Should show:
   # [[tv]]
   # dir = tv
   # [[movies]]
   # dir = movies
   ```

2. **Path mismatch**:
   - Unpackerr monitors: `/data/usenet/tv` and `/data/usenet/movies`
   - SABnzbd must complete to these exact paths
   - Check SABnzbd Config → Categories

3. **Permissions issues**:

   ```bash
   # Check Unpackerr can read/write
   ls -la /mnt/data/usenet/tv
   ls -la /mnt/data/usenet/movies

   # Should be owned by UID 3000:3000
   sudo chown -R 3000:3000 /mnt/data/usenet
   ```

#### 2. Duplicate Extraction (Both SABnzbd and Unpackerr)

**Symptoms**:

- Two sets of extracted files
- High CPU usage during downloads
- Corrupted or incomplete imports

**Diagnosis**:

```bash
# Check if SABnzbd's direct_unpack is disabled
docker exec sabnzbd cat /config/sabnzbd.ini | grep "^direct_unpack"
# Should show: direct_unpack = 0
```

**Solutions**:

1. **Re-run playbook to fix configuration**:

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/core/07-configure-download-clients-role.yml
   ```

2. **Manual fix** (if needed):
   - SABnzbd Config → Switches
   - Direct Unpack: **Disable**
   - Save and restart SABnzbd

#### 3. Unpackerr Not Notifying Sonarr/Radarr

**Symptoms**:

- Files extracted but never imported
- Sonarr/Radarr show "No files found" error
- Manual import required

**Diagnosis**:

```bash
# Check Unpackerr can reach *arr apps
docker exec unpackerr wget -qO- --timeout=5 http://media-services.discus-moth.ts.net:8989/api/v3/system/status
docker exec unpackerr wget -qO- --timeout=5 http://media-services.discus-moth.ts.net:7878/api/v3/system/status

# Check API keys are correct
docker exec unpackerr env | grep API_KEY
```

**Solutions**:

1. **Network connectivity**:
   - Verify media-services VM is accessible
   - Test: `ping media-services.discus-moth.ts.net`

2. **API key mismatch**:
   - Get correct API keys from Sonarr/Radarr (Settings → General → Security)
   - Verify they match in Unpackerr environment variables
   - Re-run playbook if needed

3. **Check Unpackerr logs for errors**:

   ```bash
   docker logs unpackerr | grep -i error
   ```

#### 4. Slow Extraction Performance

**Symptoms**:

- Extraction takes much longer than expected
- CPU maxed out during extraction
- Other services slow while extracting

**Diagnosis**:

```bash
# Check parallel extractions setting
docker exec unpackerr env | grep UN_PARALLEL
# Should show: UN_PARALLEL=1

# Monitor CPU during extraction
docker stats unpackerr
```

**Solutions**:

1. **Increase parallel extractions** (if you have spare CPU):
   - Edit [`services/compose/services/unpackerr.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/compose/services/unpackerr.yml)
   - Change: `UN_PARALLEL=2` (or higher)
   - Restart: `docker compose restart unpackerr`

2. **Lower extraction priority** (if impacting other services):
   - Unpackerr runs as UID 3000 (same priority as other services)
   - Can adjust Docker CPU shares if needed

### Verifying Everything Works

**Complete test workflow**:

```bash
# 1. Manually add a test NZB to SABnzbd
# 2. Watch SABnzbd complete the download
docker logs sabnzbd -f

# 3. Verify file appears in category folder
ls -lh /mnt/data/usenet/tv/  # or /movies

# 4. Watch Unpackerr detect and extract
docker logs unpackerr -f
# Should see: "Extracting: [filename]"

# 5. Watch Sonarr/Radarr import
docker logs sonarr -f  # or radarr
# Should see: "Imported: [filename]"

# 6. Verify final media is in correct location
ls -lh /mnt/data/media/TV\ Shows/  # or Movies
```

**Expected timeline**:

- SABnzbd download: Varies by file size
- Unpackerr detection: Within 2 minutes
- Extraction: 1-5 minutes (depending on size)
- Sonarr/Radarr import: Within 1 minute

### Configuration Reference

**Unpackerr Settings** (automated via playbook):

```yaml
Check Interval: 2 minutes
Start Delay: 1 minute
Retry Delay: 5 minutes
Max Retries: 3
Parallel Extractions: 1
Delete Original: false (keep RAR files for 5 minutes after extraction)
File Permissions: 0644
Directory Permissions: 0755
```

**SABnzbd Settings** (automated via playbook):

```ini
direct_unpack = 0          # Disabled - Unpackerr handles this
cleanup_list = .nzb, .par2, .sfv    # Clean metadata files
enable_recursive = 1       # Support nested archives
ignore_samples = 1         # Remove sample files
deobfuscate_final_filenames = 1   # Rename obfuscated files
```

## Common Issues (Both)

### 1. NFS Mount Issues

**Symptoms**:

- Can't write to download folders
- Downloads fail with I/O errors
- Containers crash

**Diagnosis**:

```bash
# Check NFS mount
df -h | grep /mnt/data
mount | grep /mnt/data

# Test write access
touch /mnt/data/test-download-clients.txt
rm /mnt/data/test-download-clients.txt
```

**Solutions**:

1. **NFS not mounted**:

   ```bash
   sudo mount -a
   # Or remount specifically
   sudo mount -t nfs nas.discus-moth.ts.net:/mnt/storage/data /mnt/data
   ```

2. **Check /etc/fstab**:

   ```bash
   grep /mnt/data /etc/fstab
   # Should have entry for NAS NFS share
   ```

### 2. Network Connectivity Issues

**Symptoms**:

- Can't reach indexers
- Slow download speeds
- Connection timeouts

**Diagnosis**:

```bash
# Test internet connectivity
docker exec qbittorrent ping -c 3 8.8.8.8
docker exec sabnzbd ping -c 3 8.8.8.8

# Test DNS
docker exec qbittorrent nslookup google.com
```

**Solutions**:

1. **DNS issues**:
   - Check /etc/resolv.conf on host
   - Verify DNS in docker-compose.yml

2. **Firewall blocking outbound**:

   ```bash
   sudo ufw status
   # Should allow outbound by default
   ```

## Advanced Troubleshooting

### Reset qBittorrent

```bash
# Backup config
docker compose stop qbittorrent
cp -r /opt/download-clients/qbittorrent/config /opt/download-clients/qbittorrent/config.bak

# Remove and recreate
docker compose up -d qbittorrent
```

### Reset SABnzbd

```bash
# Backup config
docker compose stop sabnzbd
cp -r /opt/download-clients/sabnzbd/config /opt/download-clients/sabnzbd/config.bak

# Remove config (will reset)
rm /opt/download-clients/sabnzbd/config/sabnzbd.ini

# Restart
docker compose up -d sabnzbd
```

## Getting Help

If issues persist:

1. **Collect logs**:

   ```bash
   docker logs qbittorrent --tail 500 > /tmp/qbittorrent.log
   docker logs sabnzbd --tail 500 > /tmp/sabnzbd.log
   ```

2. **Community Resources**:
   - qBittorrent: https://github.com/qbittorrent/qBittorrent/wiki
   - SABnzbd: https://sabnzbd.org/wiki/
   - Reddit: r/usenet, r/qbittorrent

## Quadlet Troubleshooting

Download clients have been migrated to rootless Podman with Quadlet systemd integration. This section covers
Quadlet-specific troubleshooting.

### Viewing Quadlet Configuration

**Quadlet Files Location**:

```bash
# View .container files
cat ~/.config/containers/systemd/<name>.container

# Example for qbittorrent
cat ~/.config/containers/systemd/qbittorrent.container

# List all Quadlet files
ls -la ~/.config/containers/systemd/
```

**Generated Systemd Services**:

```bash
# View generated systemd service
systemctl --user cat <name>

# Example for qbittorrent
systemctl --user cat qbittorrent

# View service status
systemctl --user status <name>
```

**File Locations**:

- Quadlet files: `/home/ansible/.config/containers/systemd/`
- Environment files: `/opt/download-clients/.env.qbittorrent`, `/opt/download-clients/.env.sabnzbd`
- Service data: `/opt/download-clients/services/<name>/`

### Common Quadlet Issues

#### Service Won't Start

**Symptoms**:

- Container fails to start after deployment
- Systemd service shows failed status
- Error: "podman start failed"

**Diagnosis**:

```bash
# Check service status
systemctl --user status qbittorrent
systemctl --user status sabnzbd

# View detailed logs
journalctl --user -u qbittorrent -xe
journalctl --user -u sabnzbd -xe

# View container logs (if container exists)
podman logs qbittorrent
podman logs sabnzbd

# Check .container file syntax
cat ~/.config/containers/systemd/qbittorrent.container
```

**Solutions**:

1. **Invalid .container file syntax**:

   ```bash
   # Reload systemd daemon
   systemctl --user daemon-reload

   # Try starting again
   systemctl --user start qbittorrent
   ```

2. **Port already in use**:

   ```bash
   # Check for port conflicts
   sudo ss -tulpn | grep 8080  # qBittorrent
   sudo ss -tulpn | grep 8081  # SABnzbd

   # Find what's using the port
   sudo lsof -i :8080
   ```

3. **Environment file missing**:

   ```bash
   # Verify environment files exist
   ls -la /opt/download-clients/.env.*

   # Should show:
   # .env.qbittorrent
   # .env.sabnzbd
   ```

4. **Re-run deployment playbook**:

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/core/07-configure-download-clients-role.yml
   ```

#### Port Binding Issues

**Symptoms**:

- Error: "permission denied" for port binding
- Can't access web UI on expected port
- Port < 1024 won't bind

**Diagnosis**:

```bash
# Check if rootless Podman can bind to low ports
sysctl net.ipv4.ip_unprivileged_port_start

# Check actual port bindings
podman port qbittorrent
podman port sabnzbd

# Verify container is listening
podman inspect qbittorrent | grep -A 10 PortBindings
```

**Solutions**:

1. **Rootless Podman can't bind to ports < 1024 by default**:
   - AdGuard Home example: Uses `net.ipv4.ip_unprivileged_port_start=53`
   - qBittorrent (8080) and SABnzbd (8081) don't need this
   - Check with: `sysctl net.ipv4.ip_unprivileged_port_start`

2. **Port conflict**:

   ```bash
   # Stop conflicting service
   sudo systemctl stop <conflicting-service>

   # Or change port in .container file and redeploy
   ```

3. **Firewall blocking**:

   ```bash
   # Allow ports through UFW
   sudo ufw allow from 192.168.0.0/24 to any port 8080
   sudo ufw allow from 192.168.0.0/24 to any port 8081
   sudo ufw allow from 100.64.0.0/10 to any port 8080
   sudo ufw allow from 100.64.0.0/10 to any port 8081
   sudo ufw reload
   ```

#### Container Dependencies Not Working

**Symptoms**:

- Container starts before dependency is ready
- Network errors connecting to other containers
- Containers crash on startup

**Diagnosis**:

```bash
# View Quadlet-generated dependencies
systemctl --user show qbittorrent | grep -E '(After|Requires|Wants)'
systemctl --user show sabnzbd | grep -E '(After|Requires|Wants)'

# Check dependency container status
podman ps | grep gluetun
podman ps | grep <dependency>

# View service definition
systemctl --user cat qbittorrent
```

**Solutions**:

1. **Verify container_depends_on in playbook**:
   - Check [`roles/podman_app/tasks/deploy_quadlet_single.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/podman_app/tasks/deploy_quadlet_single.yml)
   - Ensure `container_depends_on` list includes all dependencies
   - Example: qBittorrent depends on `gluetun.service`

2. **Check if dependency is running**:

   ```bash
   # List all running containers
   podman ps

   # Check specific dependency
   podman ps | grep gluetun
   systemctl --user status gluetun
   ```

3. **Manually verify dependencies**:

   ```bash
   # Should show Requires=gluetun.service
   systemctl --user show qbittorrent | grep Requires

   # Should show After=gluetun.service
   systemctl --user show qbittorrent | grep After
   ```

4. **Restart in correct order**:

   ```bash
   # Stop all
   systemctl --user stop qbittorrent sabnzbd gluetun

   # Start in dependency order
   systemctl --user start gluetun
   sleep 5  # Wait for healthy status
   systemctl --user start qbittorrent
   systemctl --user start sabnzbd
   ```

#### NFS Mount Issues

**Symptoms**:

- Container can't access /mnt/data
- Error: "no such file or directory"
- Downloads fail with I/O errors

**Diagnosis**:

```bash
# Check NFS mount status
df -h | grep /mnt/data
mount | grep /mnt/data

# View mount dependencies in .container file
cat ~/.config/containers/systemd/qbittorrent.container | grep RequiresMountsFor

# Check systemd mount dependency
systemctl --user show qbittorrent | grep RequiresMountsFor
```

**Solutions**:

1. **Verify NFS mount dependency in .container file**:

   ```bash
   # Should contain:
   # RequiresMountsFor=/mnt/data
   cat ~/.config/containers/systemd/qbittorrent.container
   ```

2. **Mount not ready**:

   ```bash
   # Verify mount is active
   systemctl status mnt-data.mount

   # Or check with df
   df -h /mnt/data

   # Manually mount if needed
   sudo mount -a
   ```

3. **View mount dependencies**:

   ```bash
   # Check generated dependencies
   systemctl --user show qbittorrent | grep mnt-data

   # Should show RequiresMountsFor=/mnt/data
   ```

4. **Restart with mount dependency**:

   ```bash
   # Stop service
   systemctl --user stop qbittorrent

   # Verify mount is ready
   df -h /mnt/data

   # Start service
   systemctl --user start qbittorrent
   ```

#### Permissions Issues

**Symptoms**:

- Can't write to /mnt/data
- Permission denied errors
- Files owned by wrong user

**Diagnosis**:

```bash
# Check file ownership on NFS mount
ls -la /mnt/data/torrents
ls -la /mnt/data/usenet

# Check container UID/GID
podman inspect qbittorrent | grep -E '"User"|"Group"'
podman inspect sabnzbd | grep -E '"User"|"Group"'

# Check effective user inside container
podman exec qbittorrent id
podman exec sabnzbd id
```

**Understanding Rootless Podman Permissions**:

- All containers run as rootless Podman (UID namespace)
- Containers run as UID 3000:3000 inside container
- NFS uses UID squashing: all writes become 3000:3000
- Host user `ansible` (UID 1000) maps to container root (UID 0)
- Container UID 3000 maps to host UID ~300000 (user namespace)

**Solutions**:

1. **Fix NFS permissions**:

   ```bash
   # On NAS (192.168.0.15), set ownership to 3000:3000
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
     "sudo chown -R 3000:3000 /mnt/storage/data/torrents /mnt/storage/data/usenet"

   # On download-clients VM, verify
   ls -la /mnt/data/torrents
   # Should show: drwxrwxr-x 3000 3000
   ```

2. **Check User= in .container file**:

   ```bash
   cat ~/.config/containers/systemd/qbittorrent.container | grep "^User="
   # Should show: User=3000:3000
   ```

3. **Verify PUID/PGID environment variables**:

   ```bash
   # Check environment file
   cat /opt/download-clients/.env.qbittorrent | grep -E "PUID|PGID"
   # Should show:
   # PUID=3000
   # PGID=3000
   ```

### Debugging Commands

**List All User Containers**:

```bash
# List running containers
podman ps

# List all containers (including stopped)
podman ps -a

# List containers with custom format
podman ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**View Container Logs**:

```bash
# View logs (last 100 lines)
podman logs qbittorrent --tail 100
podman logs sabnzbd --tail 100

# Follow logs in real-time
podman logs -f qbittorrent

# View logs with timestamps
podman logs -t qbittorrent

# View logs since specific time
podman logs --since 10m qbittorrent
```

**Inspect Container**:

```bash
# Full inspection
podman inspect qbittorrent

# Filter specific fields
podman inspect qbittorrent | grep -A 10 Mounts
podman inspect qbittorrent | grep -A 10 NetworkSettings
podman inspect qbittorrent | grep -A 5 Env

# Check network mode
podman inspect qbittorrent --format '{{.HostConfig.NetworkMode}}'

# Check user/group
podman inspect qbittorrent --format '{{.Config.User}}'
```

**Systemd Service Debugging**:

```bash
# Reload systemd daemon after changes
systemctl --user daemon-reload

# View service status
systemctl --user status qbittorrent

# View generated service file
systemctl --user cat qbittorrent

# View service properties
systemctl --user show qbittorrent

# Check for failed services
systemctl --user --failed

# Restart service
systemctl --user restart qbittorrent
```

**Quadlet Generator Output**:

```bash
# Force regeneration of systemd units
systemctl --user daemon-reload

# View generator status
systemctl --user status qbittorrent

# Check generated files
ls -la ~/.config/systemd/user/

# View Quadlet logs during generation
journalctl --user -u quadlet-generator
```

**Network Debugging**:

```bash
# Check port bindings
podman port qbittorrent
podman port sabnzbd

# Test network connectivity from container
podman exec qbittorrent ping -c 3 8.8.8.8
podman exec qbittorrent curl -I http://google.com

# Check container network settings
podman inspect qbittorrent --format '{{.NetworkSettings.IPAddress}}'
```

**Resource Usage**:

```bash
# View container stats (CPU, memory, I/O)
podman stats

# View specific container stats
podman stats qbittorrent sabnzbd

# View detailed resource usage
podman inspect qbittorrent | grep -A 20 Resources
```

## See Also

- [VPN Configuration Guide](../configuration/vpn-gluetun.md)
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Prowlarr Troubleshooting](prowlarr.md)
- [NAS/NFS Troubleshooting](nas-nfs.md)
- [Podman Troubleshooting](podman.md)

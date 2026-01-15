# VPN/Gluetun Troubleshooting

Gluetun provides VPN protection for qBittorrent downloads with automatic port forwarding. This guide covers
troubleshooting VPN connectivity, port forwarding, kill switch, and network isolation issues.

## Overview

- **VM**: download-clients (192.168.0.14)
- **Container**: gluetun
- **VPN Provider**: Private Internet Access (PIA)
- **Protected Services**: qBittorrent (SABnzbd does not use VPN)
- **Image**: docker.io/qmcgaw/gluetun:v3.41.0

## Quick Diagnostics

```bash
# SSH to download-clients VM
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# Check if Gluetun is running
docker ps | grep gluetun

# View logs
docker logs gluetun --tail 100

# Check VPN connection status
docker logs gluetun | grep -i "ip"

# View port forwarding status
docker logs gluetun | grep -i "port"

# Test VPN connectivity from qBittorrent
docker exec gluetun curl -s ifconfig.me
```

## Common Issues

### 1. VPN Not Connecting

**Symptoms**:

- Gluetun container keeps restarting
- Logs show "connection failed" or "authentication failed"
- qBittorrent web UI not accessible

**Diagnosis**:

```bash
# Check Gluetun logs for errors
docker logs gluetun | grep -i "error\|failed"

# Common errors:
# "AUTH_FAILED" - Wrong credentials
# "Connection timeout" - Network issues
# "TLS handshake failed" - Protocol/server issues
```

**Solutions**:

1. **Wrong VPN credentials**:
   - Verify PIA username/password in secrets file
   - PIA credentials are NOT the same as website login
   - Generate correct credentials at: https://www.privateinternetaccess.com/pages/client-control-panel
   - Look for "PPTP/L2TP/SOCKS Username" and "PPTP/L2TP/SOCKS Password"

2. **Network connectivity**:

   ```bash
   # Test internet connectivity from VM
   ping 8.8.8.8

   # Test DNS resolution
   nslookup privateinternetaccess.com
   ```

3. **VPN server issues**:

   ```bash
   # Check if specific server is down
   docker logs gluetun | grep "server"

   # Try different server region (edit compose file)
   # Then restart:
   docker restart gluetun
   ```

4. **Outdated Gluetun image**:

   ```bash
   # Update Gluetun
   cd /opt/media-stack
   docker compose pull gluetun
   docker compose up -d gluetun
   ```

### 2. Port Forwarding Not Working

**Symptoms**:

- qBittorrent shows "Not connectable"
- Slow download speeds
- Logs show "port forwarding failed"

**Diagnosis**:

```bash
# Check port forwarding status
docker logs gluetun | grep -i "port forward"

# Should see: "port forwarding is on and assigned port is XXXXX"

# Check qBittorrent listening port
# qBittorrent UI → Tools → Options → Connection
# Should match Gluetun forwarded port
```

**Solutions**:

1. **Port forwarding not enabled**:
   - Verify in gluetun.yml:

     ```yaml
     - VPN_PORT_FORWARDING=on
     - VPN_PORT_FORWARDING_PROVIDER=private internet access
     ```

   - Restart if changed: `docker restart gluetun`

2. **PIA server doesn't support port forwarding**:
   - Not all PIA servers support port forwarding
   - Leave `SERVER_REGIONS` blank (auto-selects port forwarding server)
   - Or manually set port-forwarding server:

     ```yaml
     - SERVER_REGIONS=US Los Angeles
     ```

3. **Port forwarding expired**:
   - PIA ports expire every 60 days
   - Gluetun auto-renews, but may fail
   - Restart Gluetun to get new port: `docker restart gluetun`

4. **qBittorrent port mismatch**:

   ```bash
   # Get Gluetun forwarded port
   docker logs gluetun | grep "port forward" | tail -1

   # Update qBittorrent automatically (already configured via port-sync script)
   # Or manually in qBittorrent: Tools → Options → Connection → Port
   ```

5. **Test port forwarding**:

   ```bash
   # Get forwarded port from logs
   PORT=$(docker logs gluetun 2>&1 | grep -oP 'port forwarding is on and assigned port is \K\d+' | tail -1)
   echo "Forwarded port: $PORT"

   # Test externally using port checker:
   # Visit: https://www.yougetsignal.com/tools/open-ports/
   # Enter your VPN IP and the forwarded port
   ```

### 3. VPN Connection Drops

**Symptoms**:

- Intermittent qBittorrent disconnections
- Downloads pause unexpectedly
- Logs show reconnection attempts

**Diagnosis**:

```bash
# Check for reconnection patterns
docker logs gluetun | grep -i "reconnect\|disconnect"

# Check container restart count
docker ps -a | grep gluetun

# Monitor in real-time
docker logs gluetun -f
```

**Solutions**:

1. **Unstable VPN server**:
   - Try different server region
   - Edit gluetun.yml:

     ```yaml
     - SERVER_REGIONS=US New York  # or other region
     ```

   - Restart: `docker restart gluetun`

2. **Network instability**:

   ```bash
   # Check for packet loss
   ping -c 100 8.8.8.8 | tail -5

   # Check DNS issues
   docker logs gluetun | grep -i "dns"
   ```

3. **Gluetun health check failing**:
   - Health check tests VPN connectivity every minute
   - If fails 3 times, container restarts
   - Check: `docker inspect gluetun | grep -A10 Health`

4. **PIA connection limits**:
   - PIA allows 10 simultaneous connections per account
   - Disconnect other devices if at limit

### 4. Kill Switch Not Working

**Symptoms**:

- Downloads continue when VPN disconnects
- Real IP exposed during VPN downtime

**Diagnosis**:

```bash
# Test kill switch
# 1. Get current VPN IP
docker exec gluetun curl -s ifconfig.me

# 2. Disconnect VPN (stop Gluetun)
docker stop gluetun

# 3. Try to access internet from qBittorrent (should fail)
docker exec -it qbittorrent curl --max-time 5 -s ifconfig.me
# Should timeout or fail (kill switch working)
```

**Solutions**:

1. **Kill switch is working** (connection should fail):
   - If curl times out, kill switch is functioning correctly
   - qBittorrent should show "No connection" when VPN down
   - This is expected behavior

2. **Kill switch bypassed** (connection succeeds - problem!):
   - Verify network mode in qbittorrent.yml:

     ```yaml
     network_mode: "service:gluetun"
     ```

   - Must be `service:gluetun`, NOT `host` or `bridge`
   - Recreate container if wrong:

     ```bash
     docker compose up -d --force-recreate qbittorrent
     ```

3. **Firewall rules not applied**:
   - Check Gluetun firewall config in gluetun.yml:

     ```yaml
     - FIREWALL_OUTBOUND_SUBNETS=192.168.0.0/24,100.64.0.0/10
     - FIREWALL_INPUT_PORTS=8080
     ```

   - Restart if changed: `docker restart gluetun`

### 5. Can't Access qBittorrent Web UI

**Symptoms**:

- qBittorrent web UI not loading
- Connection refused or timeout
- Works when VPN off, fails when VPN on

**Diagnosis**:

```bash
# Check if Gluetun is running
docker ps | grep gluetun

# Check qBittorrent container status
docker ps | grep qbittorrent

# Check logs
docker logs gluetun | grep -i "8080"
docker logs qbittorrent
```

**Solutions**:

1. **Gluetun not running**:

   ```bash
   docker start gluetun
   # Wait 30 seconds for VPN to connect
   docker start qbittorrent
   ```

2. **Port not exposed**:
   - Verify in gluetun.yml ports section:

     ```yaml
     ports:
       - 8080:8080  # qBittorrent Web UI
     ```

   - Restart if missing: `docker restart gluetun`

3. **Firewall blocking inbound**:
   - Check FIREWALL_INPUT_PORTS includes 8080:

     ```yaml
     - FIREWALL_INPUT_PORTS=8080
     ```

   - Restart if changed: `docker restart gluetun`

4. **qBittorrent not using Gluetun network**:

   ```bash
   # Verify network mode
   docker inspect qbittorrent | grep -i networkmode

   # Should show: "NetworkMode": "container:gluetun"
   # If not, recreate:
   docker compose up -d --force-recreate qbittorrent
   ```

5. **Access from correct network**:
   - Allowed networks: 192.168.0.0/24 (local) and 100.64.0.0/10 (Tailscale)
   - Test from local network or Tailscale
   - Block from other networks (security feature)

### 6. DNS Leaks

**Symptoms**:

- DNS queries not using VPN provider's DNS
- Real location revealed via DNS

**Diagnosis**:

```bash
# Test DNS leak
# Visit: https://dnsleaktest.com
# Should show VPN provider's DNS, NOT your ISP

# Or test via command line
docker exec gluetun nslookup google.com
# Should show VPN DNS server (PIA)
```

**Solutions**:

1. **DNS configuration**:
   - Check Gluetun DNS setting in gluetun.yml:

     ```yaml
     - DOT=off  # Use VPN provider's DNS
     ```

   - Alternative (use DNS over TLS):

     ```yaml
     - DOT=on
     - DOT_PROVIDERS=cloudflare  # or quad9, google
     ```

2. **DNS not working**:

   ```bash
   # Check Gluetun logs
   docker logs gluetun | grep -i "dns"

   # Restart Gluetun
   docker restart gluetun
   ```

3. **Verify DNS is private**:
   - DNS leak test should show:
     - VPN provider's DNS servers (PIA)
     - VPN location (e.g., Los Angeles)
     - **NOT** your ISP or home location

### 7. Slow VPN Performance

**Symptoms**:

- Download speeds much slower through VPN
- High latency
- Buffering on streaming

**Diagnosis**:

```bash
# Test VPN speed
docker exec gluetun curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -

# Check CPU usage
docker stats gluetun --no-stream

# Check if using UDP or TCP
docker logs gluetun | grep -i "protocol"
```

**Solutions**:

1. **Use UDP instead of TCP** (faster):
   - Already configured: `VPN_TYPE=openvpn`
   - PIA OpenVPN defaults to UDP
   - No change needed

2. **Change server location**:
   - Closer servers = faster speeds
   - Edit gluetun.yml:

     ```yaml
     - SERVER_REGIONS=US New York  # or closest region
     ```

3. **VPN provider throttling**:
   - Some ISPs throttle VPN traffic
   - Try different VPN port (edit compose if supported)

4. **Expected speed reduction**:
   - 10-30% speed loss is normal with VPN
   - Encryption overhead
   - Additional routing hops

5. **Switch VPN provider**:
   - If consistently slow, try different provider
   - See [VPN Configuration Guide](../configuration/vpn-gluetun.md) for alternatives

### 8. IP Address Not Changing

**Symptoms**:

- Public IP still shows home IP
- VPN appears connected but IP unchanged

**Diagnosis**:

```bash
# Check Gluetun's public IP (should be VPN IP)
docker exec gluetun curl -s ifconfig.me

# Compare to VM's public IP (should be different)
curl -s ifconfig.me

# Check logs for VPN connection
docker logs gluetun | grep -i "connected"
```

**Solutions**:

1. **VPN not actually connected**:

   ```bash
   # Check connection status
   docker logs gluetun | tail -20

   # Look for: "Connected to VPN" or similar
   # If missing, VPN failed to connect
   ```

2. **Checking wrong container**:
   - qBittorrent IP check:

     ```bash
     docker exec gluetun curl -s ifconfig.me  # This is correct!
     ```

   - Don't check from VM directly (that's not using VPN):

     ```bash
     curl -s ifconfig.me  # This will show home IP (expected)
     ```

3. **Restart Gluetun**:

   ```bash
   docker restart gluetun
   # Wait 30 seconds
   docker exec gluetun curl -s ifconfig.me
   ```

4. **VPN routing issue**:
   - Check routing table in Gluetun:

     ```bash
     docker exec gluetun ip route
     # Should show VPN gateway as default route
     ```

## Verification & Testing

### Complete VPN Test Checklist

```bash
# 1. Verify VPN connected
docker logs gluetun | grep -i "connected"

# 2. Check VPN IP (should be PIA IP, not home IP)
docker exec gluetun curl -s ifconfig.me

# 3. Verify port forwarding active
docker logs gluetun | grep "port forward"

# 4. Test DNS (should show VPN DNS)
docker exec gluetun nslookup google.com

# 5. Test kill switch (should timeout)
docker stop gluetun
docker exec -it qbittorrent curl --max-time 5 ifconfig.me  # Should fail
docker start gluetun

# 6. Test qBittorrent web UI accessible
curl http://download-clients.discus-moth.ts.net:8080
```

### DNS Leak Test

Visit https://dnsleaktest.com from qBittorrent container or from a device routing through VPN:

- Should show PIA DNS servers
- Should show VPN location (not home location)

### WebRTC Leak Test

Visit https://browserleaks.com/webrtc to check for WebRTC leaks (if using browser through VPN).

### Port Forwarding Test

1. Get forwarded port:

   ```bash
   docker logs gluetun | grep "port forward" | tail -1
   ```

2. Test port at: https://www.yougetsignal.com/tools/open-ports/

3. Should show port as "Open" when qBittorrent is running

## Advanced Configuration

### Change VPN Server Region

Edit gluetun.yml:

```yaml
- SERVER_REGIONS=US Los Angeles
# or
- SERVER_REGIONS=US New York
# or leave blank for auto-selection with port forwarding
```

Restart: `docker restart gluetun`

### Enable Debug Logging

```yaml
- LOG_LEVEL=debug
```

Restart and view detailed logs: `docker logs gluetun -f`

### Custom DNS

Use specific DNS servers:

```yaml
- DOT=on
- DOT_PROVIDERS=cloudflare
# or
- DNS_ADDRESS=1.1.1.1
```

### IPv6 Disable (if issues)

```yaml
- BLOCK_IPV6=on
```

## PIA-Specific Issues

### PIA Authentication Failed

- Verify credentials are **not** website login
- Use PPTP/L2TP credentials from client control panel
- Generate new credentials if needed

### PIA Port Forwarding Not Available

- Not all PIA servers support port forwarding
- Let Gluetun auto-select server (don't set SERVER_REGIONS)
- Or manually select port-forwarding server (see PIA docs)

### PIA Connection Limits

- PIA allows 10 simultaneous connections
- Disconnect unused devices
- Check active sessions at: https://www.privateinternetaccess.com/pages/client-control-panel

## Logs and Debugging

### Key Log Patterns

**Successful Connection**:

```text
[INFO] Connected to VPN
[INFO] Your IP address is: xxx.xxx.xxx.xxx (PIA)
[INFO] port forwarding is on and assigned port is 12345
```

**Connection Failed**:

```text
[ERROR] AUTH_FAILED
[ERROR] Exiting due to fatal error
```

**Port Forwarding Failed**:

```text
[WARN] port forwarding is not available
[ERROR] port forward: no port found
```

### Save Full Logs

```bash
docker logs gluetun > gluetun-debug.log
# Review for errors
grep -i "error\|failed\|warn" gluetun-debug.log
```

## Update Gluetun

```bash
# SSH to download-clients VM
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# Pull latest image
cd /opt/media-stack
docker compose pull gluetun
docker compose up -d gluetun

# Verify version
docker logs gluetun | grep "version"
```

## See Also

- [VPN Configuration Guide](../configuration/vpn-gluetun.md)
- [Download Clients Troubleshooting](download-clients.md)
- [Networking Troubleshooting](networking.md)
- [Common Issues](common-issues.md)

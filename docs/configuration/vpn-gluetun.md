# Gluetun VPN Configuration Guide

This guide explains how to configure Gluetun VPN to protect torrent traffic (qBittorrent) while maintaining Tailscale access.

**Important**: SABnzbd does NOT use VPN - usenet downloads are already encrypted via SSL/TLS.
See "Why SABnzbd Doesn't Use VPN" below.

---

## Overview

**Gluetun** is a lightweight VPN client container that routes other Docker containers through a VPN tunnel with
kill-switch protection. In the jellybuntu infrastructure, Gluetun protects download clients from ISP monitoring
while keeping services accessible via Tailscale.

### Key Benefits

- **Privacy & Security**: Hides download activity from ISP
- **Kill-Switch Protection**: Blocks traffic if VPN disconnects
- **DNS Leak Prevention**: Uses VPN provider's DNS
- **Zero Impact on Tailscale**: Services remain accessible via Tailscale network
- **Provider Flexibility**: Supports 60+ VPN providers

### Recommended VPN Provider

**VyprVPN** (Score: 95/100) - recommended for its independently audited no-logs policy.

**Rationale:**

- Independently audited no-logs policy (Leviathan Security 2018)
- Swiss jurisdiction (outside 5/9/14 Eyes)
- Owns all infrastructure (no third-party hosting)
- Included with usenet subscription (no additional cost)

**Alternatives:**

- PrivadoVPN (Score: 70/100) - Acceptable if VyprVPN has issues
- Any Gluetun-supported provider (60+ available)

---

## Network Architecture

```text
Internet
  |
  └─> Tailscale Network (unchanged)
      └─> download-clients.discus-moth.ts.net (192.168.0.14)
            ├─> Gluetun VPN Container
            │     └─> qBittorrent (network_mode: "service:gluetun")
            │           └─> Web UI: Port 8080
            │           └─> Torrent: Port 6881 (TCP/UDP) with port forwarding
            │
            └─> SABnzbd (network_mode: "host" - NO VPN)
                  └─> Web UI: Port 8081
                  └─> Uses SSL/TLS for usenet (already encrypted)
```

**How It Works:**

1. Gluetun establishes VPN connection to VyprVPN (Los Angeles)
2. qBittorrent routes all traffic through Gluetun's VPN network (privacy + port forwarding)
3. SABnzbd uses host network directly (no VPN - usenet already encrypted via SSL/TLS)
4. Inbound Tailscale connections work normally (web UI access unchanged)

---

## Why SABnzbd Doesn't Use VPN

SABnzbd is configured to use host networking and does NOT route through the VPN. This is intentional and
recommended for several reasons:

### 1. Usenet is Already Encrypted

- Usenet providers use **SSL/TLS encryption (port 563)**
- All traffic is encrypted end-to-end just like HTTPS
- VPN adds no additional security or privacy benefit

### 2. Privacy by Design

- Binary downloads are **not trackable** like BitTorrent swarms
- No public peer lists or DHT networks
- ISPs cannot see what you're downloading (only encrypted SSL traffic to usenet provider)

### 3. Performance Benefits

- **No VPN overhead**: Maximum download speeds
- **Lower latency**: Direct connection to usenet servers
- **No VPN failures**: Usenet downloads continue even if VPN drops

### 4. Compatibility

- Some usenet indexers may **block VPN IPs**
- Direct connection ensures reliable indexer access
- No risk of VPN IP being banned by providers

### 5. Servarr Official Recommendation

The Servarr project (Sonarr/Radarr) explicitly recommends **against** using VPN for usenet:

> "Usenet is encrypted via SSL/TLS. Using a VPN adds no privacy benefit and can cause connectivity issues."
>
> Source: [Servarr Wiki - VPN and Usenet](https://wiki.servarr.com/useful-tools#vpn-and-usenet)

### Testing Verification

You can verify SABnzbd is NOT using the VPN:

```bash
# Check SABnzbd IP (should be your home IP)
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
docker exec sabnzbd curl -s ifconfig.me

# Check qBittorrent IP (should be VPN IP)
docker exec qbittorrent curl -s ifconfig.me

# Check Gluetun VPN IP (should match qBittorrent)
docker exec gluetun wget -qO- ifconfig.me
```

**Expected**: SABnzbd shows different IP than qBittorrent/Gluetun

---

## Configuration Steps

### Step 1: Add VPN Credentials to Secrets File

Edit the encrypted secrets file to add VPN credentials:

```bash
sops group_vars/all.sops.yaml
```

Add the following structure (use the template from `vault-vpn-template.yml`):

```yaml
# VPN Configuration
vpn:
  provider: vyprvpn        # Or: privado, mullvad, protonvpn, nordvpn, etc.
  protocol: wireguard      # Or: openvpn

  # WireGuard Configuration (recommended)
  wireguard:
    private_key: "YOUR_WIREGUARD_PRIVATE_KEY"
    addresses: "YOUR_WIREGUARD_ADDRESS"  # Format: "10.x.x.x/32"

  # OpenVPN Configuration (alternative)
  openvpn:
    username: "YOUR_OPENVPN_USERNAME"
    password: "YOUR_OPENVPN_PASSWORD"

  # Server Selection
  server_countries: "Switzerland"  # Or: "United States", "Netherlands", etc.
  server_regions: ""               # Optional: specific regions
  server_cities: ""                # Optional: specific cities
  server_names: ""                 # Optional: specific server names
```

#### Getting VyprVPN Credentials

**For WireGuard (recommended):**

1. Log in to VyprVPN account dashboard
2. Navigate to WireGuard configuration section
3. Generate a new WireGuard configuration
4. Copy the following values:
   - **Private Key** → `vpn.wireguard.private_key`
   - **Address** → `vpn.wireguard.addresses` (format: `10.x.x.x/32`)

**For OpenVPN (alternative):**

1. Log in to VyprVPN account dashboard
2. Navigate to OpenVPN configuration section
3. Copy your OpenVPN username and password:
   - **Username** → `vpn.openvpn.username`
   - **Password** → `vpn.openvpn.password`

#### Server Location Recommendations

- **Switzerland**: Best privacy (Swiss jurisdiction, VyprVPN's home country)
- **Nearby locations**: Better performance (lower latency)
- **Multiple countries**: Use comma-separated list for failover

---

### Step 2: Configure VPN Provider Selection

**New in v2.0**: The infrastructure supports multiple VPN providers with easy switching.

Edit [`host_vars/download-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/download-clients.yml) to select your provider:

```yaml
# VPN Configuration
# Switch between providers by changing vpn_provider
# Options: "vyprvpn" (OpenVPN) or "privado" (WireGuard)
vpn_provider: "privado"  # Change this to switch providers
```

**Available providers:**

- **vyprvpn**: VyprVPN via Giganews (OpenVPN, Los Angeles)
- **privado**: Privado VPN (WireGuard, Portland OR)

To add more providers, see "Adding Additional VPN Providers" below.

---

### Step 3: Deploy Gluetun Configuration

The Gluetun configuration is already integrated into the download-clients playbook. Run the playbook to deploy:

```bash
./bin/runtime/ansible-run.sh playbooks/services/download-clients.yml
```

**What this does:**

1. Deploys Gluetun container with selected VPN configuration
2. Configures qBittorrent to route through Gluetun
3. Configures SABnzbd to route through Gluetun
4. Updates SABnzbd to listen on port 8081 (avoids conflict with qBittorrent)
5. Restarts services to apply changes

---

## Verification Steps

After deployment, verify the VPN is working correctly:

### 1. Check Gluetun VPN Connection

```bash
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
cd /opt/download-clients
docker logs gluetun | tail -20
```

**Expected output:**

```text
[INFO] VPN is up and running
[INFO] Public IP: <VPN_IP_ADDRESS>
```

### 2. Verify Public IP (Should Show VPN Provider's IP)

```bash
docker exec gluetun wget -qO- ifconfig.me
```

**Expected:** VPN provider's IP address (NOT your home IP)

### 3. Check Download Client Connectivity

**qBittorrent:**

```bash
docker exec qbittorrent wget -qO- ifconfig.me
```

**SABnzbd:**

```bash
docker exec sabnzbd wget -qO- ifconfig.me
```

**Expected:** Same VPN IP as Gluetun (both route through VPN)

### 4. Verify Tailscale Access Still Works

From your local machine or phone (connected to Tailscale):

```bash
# qBittorrent Web UI
curl -I http://download-clients.discus-moth.ts.net:8080

# SABnzbd Web UI
curl -I http://download-clients.discus-moth.ts.net:8081
```

**Expected:** HTTP 200 responses (web UIs accessible via Tailscale)

### 5. Test Kill-Switch Protection

**Stop Gluetun container:**

```bash
docker stop gluetun
```

**Try to access internet from download clients:**

```bash
docker exec qbittorrent wget -qO- --timeout=5 ifconfig.me
# Expected: Timeout or connection refused (kill-switch working)
```

**Restart Gluetun:**

```bash
docker start gluetun
```

---

## DNS Leak Testing

To verify DNS queries go through the VPN:

1. Access qBittorrent web UI: `http://download-clients.discus-moth.ts.net:8080`
2. Open browser console and navigate to: https://dnsleaktest.com
3. Click "Standard test" or "Extended test"
4. Verify all DNS servers belong to your VPN provider (not your ISP)

**Expected:**

- DNS servers should show VyprVPN (or your provider)
- NO DNS servers from your ISP

---

## Troubleshooting

### VPN Not Connecting

**Check Gluetun logs:**

```bash
docker logs gluetun
```

**Common issues:**

- **Invalid credentials**: Double-check VPN credentials in vault
- **Unsupported provider**: Verify provider name is correct (e.g., `vyprvpn`, not `vypr`)
- **Server unavailable**: Try different `server_countries` value

### Download Clients Can't Access Internet

**Verify Gluetun is healthy:**

```bash
docker ps | grep gluetun
# Should show "healthy" status
```

**Check firewall subnets:**

```bash
docker exec gluetun cat /gluetun/firewall-config.json
```

**Expected:**

```json
{
  "outbound_subnets": ["192.168.0.0/24", "100.64.0.0/10"]
}
```

### Web UIs Not Accessible via Tailscale

**Verify Gluetun firewall allows local subnets:**

The `FIREWALL_OUTBOUND_SUBNETS` in `gluetun.yml` should include:

- `192.168.0.0/24` (local network)
- `100.64.0.0/10` (Tailscale CGNAT range)

**Check Gluetun port mappings:**

```bash
docker ps | grep gluetun
# Should show: 0.0.0.0:8080->8080/tcp, 0.0.0.0:8081->8081/tcp
```

### SABnzbd Web UI Shows "Access Denied"

This means SABnzbd's `host_whitelist` needs updating.

**Verify configuration patch applied:**

```bash
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
cat /opt/download-clients/services/sabnzbd/sabnzbd.ini | grep host_whitelist
```

**Expected:**

```text
host_whitelist = download-clients.discus-moth.ts.net, 192.168.0.14, localhost, 127.0.0.1, sabnzbd
```

**If missing:** Re-run the download-clients playbook.

### Slow VPN Speeds

**Try different protocol:**

- Change `vpn.protocol` from `wireguard` to `openvpn` (or vice versa)
- WireGuard is usually faster, but some networks perform better with OpenVPN

**Try different server location:**

- Use geographically closer servers
- Example: `server_countries: "United States,Canada"`

**Check VPN provider status:**

- Some VPN servers may be congested
- Try different regions or cities

### Port Forwarding Not Working (VyprVPN/Giganews)

**Port checker shows "Closed"**:

1. **Verify NAT Firewall is disabled** in Giganews Control Panel:
   - Log in to https://www.giganews.com/controlpanel/
   - Check VyprVPN tab → NAT Firewall should show "Disabled"

2. **Restart Gluetun container** (VPN must reconnect after NAT Firewall change):

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
   cd /opt/download-clients
   docker restart gluetun
   ```

3. **Wait 2-3 minutes** for VPN connection to fully establish

4. **Check Gluetun firewall configuration**:

   ```bash
   docker logs gluetun | grep -i "firewall"
   # Should show FIREWALL_VPN_INPUT_PORTS=6881
   ```

5. **Verify qBittorrent is using port 6881**:
   - Settings → Connection → Listening Port = 6881
   - "Use random port on each start" = OFF

**qBittorrent shows "Firewalled" status**:

1. **Check Gluetun is healthy**:

   ```bash
   docker ps | grep gluetun
   # Should show "healthy" status
   ```

2. **Test with a popular torrent** (like Ubuntu ISO):
   - Some torrents have very few peers
   - Popular torrents will show incoming connections if port forwarding works

3. **Verify VPN IP is reachable**:

   ```bash
   docker exec gluetun wget -qO- ifconfig.me
   # Note the IP, then test from external port checker
   ```

**Still no incoming connections**:

1. **Contact Giganews support** to confirm NAT Firewall is fully disabled
2. **Try a different VyprVPN server location** (some servers may have restrictions)
3. **Check for ISP-level BitTorrent blocking** (rare but possible)

---

## Switching Between VPN Providers

**New Multi-Provider Architecture** (v2.0): The infrastructure supports multiple VPN providers configured
simultaneously. Switch between them instantly by changing a single variable.

### Quick Switch (Pre-Configured Providers)

To switch between pre-configured providers (VyprVPN ↔ Privado):

1. **Edit [`host_vars/download-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/download-clients.yml)**:

   ```yaml
   vpn_provider: "privado"  # Or: "vyprvpn"
   ```

2. **Redeploy**:

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/services/download-clients.yml
   ```

3. **Verify new provider**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
   docker exec gluetun wget -qO- ifconfig.me
   # Should show new provider's IP
   ```

**That's it!** No secrets file editing required (credentials already stored).

### Adding Additional VPN Providers

To add a new provider (e.g., Mullvad, ProtonVPN):

1. **Add credentials to secrets file**:

   ```bash
   sops group_vars/all.sops.yaml
   ```

   Add new section:

   ```yaml
   vpn:
     # Existing providers...
     wireguard:
       privado:
         private_key: "..."
       mullvad:  # New provider
         private_key: "NEW_PROVIDER_PRIVATE_KEY"
         addresses: "10.x.x.x/32"
   ```

2. **Add provider configuration to [`host_vars/download-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/download-clients.yml)**:

   ```yaml
   mullvad_config:
     protocol: "wireguard"
     location: "sweden-malmo"
     endpoint_ip: "x.x.x.x"
     endpoint_port: 51820
     addresses: "10.x.x.x/32"
     public_key: "SERVER_PUBLIC_KEY"
   ```

3. **Update `compose_files/services/gluetun.yml`**:

   Add new conditional block:

   ```yaml
   {% elif vpn_provider == "mullvad" %}
     - VPN_TYPE=wireguard
     - WIREGUARD_PRIVATE_KEY={{ vpn.wireguard.mullvad.private_key }}
     - WIREGUARD_ADDRESSES={{ mullvad_config.addresses }}
     # ... other vars
   {% endif %}
   ```

4. **Set as active provider in [`host_vars/download-clients.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/download-clients.yml)**:

   ```yaml
   vpn_provider: "mullvad"
   ```

5. **Deploy and verify**:

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/services/download-clients.yml
   docker exec gluetun wget -qO- ifconfig.me
   ```

---

## Supported VPN Providers

Gluetun supports 60+ VPN providers. See the complete list:

- [Gluetun Provider List](https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers)

**Popular providers:**

- VyprVPN (vyprvpn)
- Mullvad (mullvad)
- ProtonVPN (protonvpn)
- Private Internet Access (pia)
- NordVPN (nordvpn)
- Surfshark (surfshark)
- ExpressVPN (expressvpn)

Each provider has specific configuration requirements. See Gluetun docs for details.

---

## Advanced Configuration

### Port Forwarding (Better Torrent Performance)

Port forwarding allows other torrent peers to initiate connections to you, significantly improving download speeds
and swarm connectivity.

#### VyprVPN Port Forwarding (Giganews)

**Important**: VyprVPN does **not** have native port forwarding like Mullvad or ProtonVPN. Instead, it uses a different approach:

1. **Default**: NAT Firewall blocks all inbound connections
2. **For port forwarding**: Disable NAT Firewall (opens ALL inbound ports at VPN level)
3. **Security**: Use Gluetun's `FIREWALL_VPN_INPUT_PORTS` to restrict which specific ports are allowed

##### Step 1: Disable NAT Firewall in Giganews Control Panel

**For Giganews customers** (VyprVPN included with subscription):

1. Log in to **Giganews Control Panel**: https://www.giganews.com/controlpanel/
2. Click on the **VyprVPN** tab
3. Under **NAT Firewall**, click **Enable** (it will toggle to "Disabled")
4. You should see "Disabled NAT Firewall" confirmation message at the top
5. **Disconnect and reconnect** any active VPN connections

**Note**: NAT Firewall is included with Diamond memberships. If you don't see this option, contact Giganews support (24/7).

##### Step 2: Configure Gluetun to Allow Torrent Port

The Gluetun configuration already includes `FIREWALL_VPN_INPUT_PORTS=6881` in `compose_files/services/gluetun.yml`:

```yaml
environment:
  # Allow inbound connections from internet through VPN (for port forwarding)
  # NOTE: Requires NAT Firewall disabled in Giganews Control Panel
  - FIREWALL_VPN_INPUT_PORTS=6881
```

This restricts inbound VPN traffic to **only port 6881**, even though NAT Firewall is disabled (which opens all
ports at the VPN level).

##### Step 3: Configure qBittorrent

After deploying the configuration:

1. Access qBittorrent Web UI: `http://download-clients.discus-moth.ts.net:8080`
2. Navigate to **Settings** → **Connection**
3. Set **Listening Port** to `6881`
4. **Disable** "Use UPnP / NAT-PMP port forwarding from my router"
5. **Disable** "Use random port on each start"
6. Click **Save**

##### Step 4: Verify Port Forwarding is Working

**Check public IP and port**:

```bash
# Get VPN IP address
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
docker exec gluetun wget -qO- ifconfig.me
```

**Test port with external checker** (from another device):

- Visit: https://www.yougetsignal.com/tools/open-ports/
- Enter VPN IP and port `6881`
- Click "Check Port"

**Expected**: "Port 6881 is OPEN"

**Check qBittorrent status**:

- Look at bottom status bar in qBittorrent Web UI
- Network icon should be **green** (connected)
- Hover over it to see connection status

#### Private Internet Access (PIA) Port Forwarding (CURRENT CONFIGURATION)

**PIA** provides **automatic port forwarding** via Gluetun with no manual configuration needed. The current
jellybuntu infrastructure uses PIA.

##### How PIA Port Forwarding Works

1. **Gluetun connects to PIA** and requests a port forward via PIA's API
2. **PIA assigns a dynamic port** (changes on each VPN connection)
3. **Port forwarding script** automatically updates qBittorrent with the new port
4. **qBittorrent listens** on the PIA-assigned port for incoming connections

##### Required qBittorrent Configuration

**IMPORTANT**: After extensive testing, these specific settings are **REQUIRED** for PIA port forwarding to work correctly:

**Privacy Settings (Connection → BitTorrent tab):**

- ✅ **Enable DHT** - Required for peer discovery
- ✅ **Enable PeX** - Required for peer exchange
- ✅ **Enable Local Peer Discovery** - Required for LAN peer discovery
- ❌ **Anonymous Mode** - Must be DISABLED (conflicts with port forwarding)
- **Encryption Mode**: Allow encryption (not require)

**Connection Settings (Connection tab):**

- **Listening Port**: Dynamic (set by automation script, e.g., 46124)
- ❌ **Use UPnP/NAT-PMP** - Must be DISABLED
- ❌ **Use random port** - Must be DISABLED (automation handles port assignment)

**Why These Settings?**

Initially, the infrastructure was configured with DHT/PeX/LSD disabled and anonymous mode enabled for maximum
privacy. However, **extensive testing revealed**:

1. **Anonymous mode conflicts with port forwarding** - Prevents proper peer connections
2. **DHT/PeX/LSD are required** - Without these, peers cannot discover your forwarded port
3. **Port must be dynamically assigned** - PIA assigns different ports on each connection
4. **VPN already provides privacy** - DHT/PeX/LSD traffic is encrypted through VPN tunnel

**Security Note**: Even with DHT/PeX/LSD enabled, all traffic (including these protocols) is routed through the
encrypted VPN tunnel, so your real IP remains hidden.

##### Verification Steps

**1. Check PIA assigned port:**

```bash
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
cat /opt/download-clients/services/gluetun/forwarded_port.txt
```

**2. Verify qBittorrent is using the PIA port:**

- Open qBittorrent Web UI: http://download-clients.discus-moth.ts.net:8080
- Go to Settings → Connection
- Check "Port used for incoming connections" matches the PIA assigned port

**3. Test port is open:**

- Get VPN IP: `docker exec gluetun wget -qO- ifconfig.me`
- Visit https://www.yougetsignal.com/tools/open-ports/
- Test: VPN IP + port from step 1
- Expected: "Port is OPEN"

**4. Verify seeding is working:**

- qBittorrent bottom status bar shows green network icon
- Torrents show **incoming peer connections** (not just outgoing)
- Upload speeds increase over time as peers discover your forwarded port

##### Automated Port Updates

The infrastructure includes a systemd service (`pia-port-sync.service`) that:

- Monitors `/opt/download-clients/services/gluetun/forwarded_port.txt` for changes
- Automatically updates qBittorrent listening port via Web API
- Logs all port changes to journalctl

**Check port sync status:**

```bash
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net
sudo systemctl status pia-port-sync
sudo journalctl -u pia-port-sync -f  # Follow logs
```

##### Troubleshooting PIA Port Forwarding

**Port shows as closed:**

1. Wait 2-3 minutes after VPN connection for PIA to assign port
2. Check Gluetun logs: `docker logs gluetun | grep -i "port forward"`
3. Verify forwarded_port.txt exists and has a port number
4. Restart qBittorrent to force port update: `docker restart qbittorrent`

**No incoming connections:**

1. Verify DHT/PeX/LSD are enabled in qBittorrent settings
2. Verify anonymous mode is disabled
3. Test with a popular torrent (Ubuntu ISO) - unpopular torrents have few peers
4. Check qBittorrent bottom status bar for green network icon

**Port keeps changing:**

- This is normal - PIA assigns a new port on each VPN reconnection
- Automation script handles updates automatically
- Peers will re-discover your new port via DHT/PeX

---

#### Port Forwarding with Other Providers

Some VPN providers have **native port forwarding** integrated with Gluetun:

**Mullvad (automatic)**:

```yaml
vpn:
  provider: mullvad
  protocol: wireguard
  wireguard:
    private_key: "YOUR_KEY"
    addresses: "YOUR_ADDRESS"
  # Port forwarding is automatic with Mullvad
```

**ProtonVPN (automatic)**:

```yaml
vpn:
  provider: protonvpn
  protocol: wireguard
  wireguard:
    private_key: "YOUR_KEY"
    addresses: "YOUR_ADDRESS"
```

Gluetun automatically retrieves and exposes the forwarded port for these providers.

**Providers with native port forwarding**:

- Private Internet Access (PIA) - **CURRENT** (see section above)
- Mullvad (WireGuard)
- ProtonVPN (WireGuard)
- Perfect Privacy

See [Gluetun Port Forwarding Wiki](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/vpn-port-forwarding.md)
for complete list.

### Custom DNS Servers

To use custom DNS servers instead of VPN provider's:

Edit `compose_files/services/gluetun.yml`:

```yaml
environment:
  - DOT=on
  - DOT_PROVIDERS=cloudflare
```

Options:

- `cloudflare`: 1.1.1.1
- `google`: 8.8.8.8
- `quad9`: 9.9.9.9

### Multiple VPN Servers (Failover)

To configure multiple server locations for failover:

```yaml
vpn:
  provider: vyprvpn
  protocol: wireguard
  server_countries: "Switzerland,Netherlands,Sweden"
```

Gluetun will try servers in order if one fails.

---

## Security Considerations

### VPN Provider Trust Model

**What VPN Provider Can See:**

- Your public IP address (when you connect)
- Timing of connections
- Amount of data transferred

**What VPN Provider CANNOT See (with proper no-logs policy):**

- Download destinations (websites, torrents, etc.)
- File names or content
- DNS queries (if using VPN's DNS)

**Why VyprVPN is Recommended:**

- Independently verified no-logs policy
- Owns infrastructure (no third-party exposure)
- Swiss jurisdiction (strong privacy laws)

### Defense in Depth

VPN protection complements jellybuntu's existing security:

| Layer | Protection |
|-------|------------|
| **Tailscale** | Encrypted remote access, no public exposure |
| **UFW Firewall** | Minimal open ports, SSH restricted |
| **Gluetun VPN** | Download traffic hidden from ISP |
| **Kill-Switch** | No traffic leak if VPN fails |

### What VPN Does NOT Protect Against

- **Copyright notices if downloading without VPN**: Ensure VPN is working before starting downloads
- **Malware in downloads**: Use antivirus/content scanning
- **Compromised VPN provider**: Choose audited, reputable providers
- **Local network monitoring**: VPN only protects internet traffic, not local LAN

---

## Performance Impact

**Gluetun Resource Usage:**

- **CPU**: ~1-2% (lightweight Go application)
- **RAM**: ~50MB
- **Network**: Minimal overhead (WireGuard ~5%, OpenVPN ~10%)

**Expected Download Speeds:**

- **WireGuard**: 90-95% of non-VPN speeds
- **OpenVPN**: 80-90% of non-VPN speeds

**Factors affecting speed:**

- VPN server location (closer = faster)
- VPN provider infrastructure quality
- Your internet connection speed

---

## Further Reading

- [Gluetun GitHub](https://github.com/qdm12/gluetun)
- [Gluetun Wiki](https://github.com/qdm12/gluetun-wiki)
- [VyprVPN Audit Results](https://www.vyprvpn.com/blog/vyprvpn-passes-third-party-audit)

# Networking Troubleshooting

Troubleshooting guide for Tailscale, firewall, and network connectivity issues.

## Quick Checks

```bash
# Check Tailscale status
tailscale status

# Check firewall
sudo ufw status

# Check network interfaces
ip addr show

# Test connectivity
ping 8.8.8.8
ping google.com

# Check SSH access
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net
```

## Tailscale Issues

### 1. Can't Connect to Tailscale

**Symptoms**:

- `tailscale status` shows "Stopped" or error
- Can't access services via `.discus-moth.ts.net` hostnames
- Tailscale not in `ip addr` output

**Diagnosis**:

```bash
# Check service status
sudo systemctl status tailscaled

# View logs
sudo journalctl -u tailscaled -n 50

# Check if interface exists
ip addr show tailscale0
```

**Solutions**:

1. **Tailscale service not running**:

   ```bash
   sudo systemctl start tailscaled
   sudo systemctl enable tailscaled
   ```

2. **Not logged in**:

   ```bash
   sudo tailscale up
   # Follow authentication link if needed
   ```

3. **Key expired**:

   ```bash
   # Re-authenticate
   sudo tailscale up --auth-key=YOUR_AUTH_KEY
   ```

### 2. Tailscale Connected But Can't Reach Services

**Symptoms**:

- `tailscale status` shows connected
- Can't ping or access other Tailscale hosts
- DNS resolution fails for `.ts.net` hostnames

**Diagnosis**:

```bash
# Check if you can see other devices
tailscale status

# Try direct IP instead of hostname
ping 100.X.X.X  # Tailscale IP of target

# Test DNS resolution
nslookup media-services.discus-moth.ts.net

# Check routes
tailscale status --peers
```

**Solutions**:

1. **DNS resolution failing**:

   ```bash
   # Check MagicDNS is enabled
   tailscale status | grep -i dns

   # Use direct Tailscale IP as workaround
   ssh ansible@100.X.X.X
   ```

2. **Firewall blocking between Tailscale nodes**:
   - Check UFW rules on target VM
   - Should allow from 100.64.0.0/10

3. **Subnet routing issues**:

   ```bash
   # Check advertised routes
   tailscale status --self

   # Accept routes if needed
   tailscale up --accept-routes
   ```

### 3. Tailscale Hostname Wrong

**Symptoms**:

- VM shows up with wrong name in `tailscale status`
- Can't use expected hostname

**Diagnosis**:

```bash
# Check current hostname
tailscale status --self

# Check system hostname
hostname
```

**Solutions**:

1. **Set correct hostname**:

   ```bash
   # Update Tailscale hostname
   sudo tailscale up --hostname=media-services

   # Or set system hostname
   sudo hostnamectl set-hostname media-services
   sudo tailscale up
   ```

### 4. Tailscale Performance Issues

**Symptoms**:

- Slow connection over Tailscale
- High latency
- Frequent disconnections

**Diagnosis**:

```bash
# Check connection type (DERP vs direct)
tailscale status --peers

# Test latency
ping -c 10 media-services.discus-moth.ts.net

# Check network path
tailscale ping media-services
```

**Solutions**:

1. **Using DERP relay instead of direct**:
   - Check NAT/firewall allows UDP 41641
   - May need to configure port forwarding
   - DERP is slower but still functional

2. **Check for packet loss**:

   ```bash
   ping -c 100 media-services.discus-moth.ts.net
   ```

3. **Restart Tailscale**:

   ```bash
   sudo systemctl restart tailscaled
   ```

## UFW Firewall Issues

### 1. Can't SSH to VM

**Symptoms**:

- SSH connection refused or timeout
- Was working before firewall configuration
- Can access via Proxmox console but not SSH

**Diagnosis**:

```bash
# Check if SSH is listening
sudo netstat -tulpn | grep :22

# Check UFW status
sudo ufw status numbered

# Check if Tailscale network is allowed
sudo ufw status | grep 100.64.0.0/10
```

**Solutions**:

1. **SSH not allowed from your network**:

   ```bash
   # After firewall playbook, SSH is Tailscale + LAN
   # Use Tailscale hostname
   ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

   # Or temporarily allow from local network (NOT recommended for production)
   sudo ufw allow from 192.168.0.0/24 to any port 22
   ```

2. **Tailscale rule missing**:

   ```bash
   # Add SSH access from Tailscale network
   sudo ufw allow from 100.64.0.0/10 to any port 22 proto tcp comment 'SSH from Tailscale'
   sudo ufw reload
   ```

3. **UFW blocking everything**:

   ```bash
   # Check default policies
   sudo ufw status verbose

   # Should be: deny incoming, allow outgoing
   # If locked out, access via Proxmox console and fix rules
   ```

### 2. Can't Access Web Services

**Symptoms**:

- Can SSH but can't access web UIs
- Ports 8989, 7878, 8080, etc. not reachable
- Connection timeout

**Diagnosis**:

```bash
# Check if service is listening
sudo netstat -tulpn | grep -E "8989|7878|8080"

# Check UFW rules
sudo ufw status numbered

# Test locally (should work)
curl http://localhost:8989
```

**Solutions**:

1. **Firewall blocking service ports**:

   ```bash
   # Allow service ports from local network + Tailscale
   sudo ufw allow from 192.168.0.0/24 to any port 8989 comment 'Sonarr'
   sudo ufw allow from 100.64.0.0/10 to any port 8989 comment 'Sonarr - Tailscale'
   sudo ufw reload
   ```

2. **Wrong network specified**:
   - Check if accessing from allowed network
   - Local network: 192.168.0.0/24
   - Tailscale: 100.64.0.0/10

### 3. Locked Out of VM

**Symptoms**:

- Can't SSH or access any services
- UFW rules blocking everything
- Only Proxmox console access remains

**Diagnosis**:

```bash
# From Proxmox console, check UFW
sudo ufw status numbered

# Check if your IP is blocked
sudo ufw status | grep YOUR_IP
```

**Solutions**:

1. **Emergency access via Proxmox console**:
   - Access VM via Proxmox web UI
   - VM 4XX > Console

2. **Fix or disable UFW temporarily**:

   ```bash
   # Disable UFW temporarily
   sudo ufw disable

   # Fix rules and re-enable
   sudo ufw allow from 192.168.0.0/24
   sudo ufw allow from 100.64.0.0/10
   sudo ufw enable
   ```

3. **Reset UFW** (last resort):

   ```bash
   sudo ufw --force reset
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   # Re-run firewall playbook
   ```

## General Network Issues

### 1. No Internet Connectivity

**Symptoms**:

- Can't ping external IPs or domains
- Package updates fail
- Services can't reach internet

**Diagnosis**:

```bash
# Test IP connectivity
ping -c 3 8.8.8.8

# Test DNS
ping -c 3 google.com

# Check default gateway
ip route show default

# Check DNS servers
cat /etc/resolv.conf
```

**Solutions**:

1. **No default gateway**:

   ```bash
   # Check cloud-init config
   cat /etc/netplan/*.yaml

   # Should have gateway4: 192.168.0.1
   sudo netplan apply
   ```

2. **DNS not working**:

   ```bash
   # Check resolv.conf
   cat /etc/resolv.conf

   # Should have:
   # nameserver 9.9.9.9
   # nameserver 192.168.0.1

   # If using systemd-resolved
   sudo systemctl restart systemd-resolved
   ```

3. **Network interface down**:

   ```bash
   # Check interfaces
   ip addr show

   # Bring up if needed
   sudo ip link set eth0 up
   ```

### 2. Can't Reach Other VMs on Local Network

**Symptoms**:

- Can't ping other VMs by IP
- Can't connect to services on other VMs
- Local network isolation

**Diagnosis**:

```bash
# Test connectivity to gateway
ping 192.168.0.1

# Test connectivity to another VM
ping 192.168.0.13

# Check routing table
ip route show

# Check ARP table
ip neigh show
```

**Solutions**:

1. **Check both VMs' firewalls**:

   ```bash
   # On source VM
   sudo ufw status

   # On target VM
   sudo ufw allow from 192.168.0.0/24
   ```

2. **Network interface issue**:

   ```bash
   # Check interface is up
   ip link show

   # Check subnet is correct
   ip addr show | grep inet
   ```

### 3. DNS Resolution Not Working

**Symptoms**:

- Can ping IPs but not hostnames
- `nslookup` or `dig` fail
- "Name or service not known" errors

**Diagnosis**:

```bash
# Test DNS lookup
nslookup google.com

# Check DNS config
cat /etc/resolv.conf

# Test specific DNS server
nslookup google.com 9.9.9.9

# Check systemd-resolved
systemctl status systemd-resolved
```

**Solutions**:

1. **No DNS servers configured**:

   ```bash
   # Edit netplan
   sudo nano /etc/netplan/50-cloud-init.yaml

   # Add nameservers:
   #   nameservers:
   #     addresses: [9.9.9.9, 192.168.0.1]

   sudo netplan apply
   ```

2. **systemd-resolved issues**:

   ```bash
   # Restart service
   sudo systemctl restart systemd-resolved

   # Check status
   resolvectl status
   ```

## Docker Network Issues

### 1. Containers Can't Reach Internet

**Symptoms**:

- Containers can't download or update
- DNS resolution fails in containers
- Ping fails from inside container

**Diagnosis**:

```bash
# Test from inside container
docker exec sonarr ping -c 3 8.8.8.8
docker exec sonarr ping -c 3 google.com

# Check Docker network
docker network inspect bridge

# Check iptables (Docker uses this)
sudo iptables -L -n | grep -A 5 DOCKER
```

**Solutions**:

1. **DNS issues**:

   ```bash
   # Check Docker DNS
   docker exec sonarr cat /etc/resolv.conf

   # Set DNS in docker-compose.yml
   dns:
     - 9.9.9.9
     - 192.168.0.1
   ```

2. **Restart Docker**:

   ```bash
   sudo systemctl restart docker
   docker compose up -d
   ```

### 2. Containers Can't Communicate

**Symptoms**:

- Sonarr can't reach Prowlarr
- Services can't talk to each other
- Container name resolution fails

**Diagnosis**:

```bash
# Check containers are on same network
docker network ls
docker network inspect media-stack_default

# Test connectivity
docker exec sonarr ping prowlarr
docker exec sonarr nslookup prowlarr
```

**Solutions**:

1. **Not on same network**:
   - Verify all services use same docker-compose.yml
   - Or explicitly define shared network in compose file

2. **Use container names, not localhost**:
   - Correct: `http://prowlarr:9696`
   - Wrong: `http://localhost:9696`

## Advanced Troubleshooting

### Network Packet Capture

```bash
# Capture traffic on interface
sudo tcpdump -i eth0 -n -c 100

# Capture specific port
sudo tcpdump -i eth0 port 22 -n

# Capture Tailscale traffic
sudo tcpdump -i tailscale0 -n
```

### Check All Listening Ports

```bash
# List all listening ports
sudo netstat -tulpn

# Or with ss (newer)
sudo ss -tulpn
```

### Reset Network Stack

```bash
# Restart networking
sudo systemctl restart systemd-networkd

# Re-apply netplan
sudo netplan apply

# Flush DNS cache
sudo systemd-resolve --flush-caches

# Restart Docker networking
sudo systemctl restart docker
```

## Getting Help

If issues persist:

1. **Collect network info**:

   ```bash
   ip addr show > /tmp/network-debug.txt
   ip route show >> /tmp/network-debug.txt
   sudo ufw status numbered >> /tmp/network-debug.txt
   tailscale status >> /tmp/network-debug.txt
   ```

2. **Resources**:
   - Tailscale docs: https://tailscale.com/kb/
   - UFW guide: https://wiki.ubuntu.com/UncomplicatedFirewall
   - Docker networking: https://docs.docker.com/network/

## See Also

- [Common Issues](common-issues.md)
- [Podman Troubleshooting](podman.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [Security Configuration](../configuration/security.md)

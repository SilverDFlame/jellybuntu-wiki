# Network Performance Troubleshooting

Diagnose and resolve network performance issues including slow NFS transfers, Tailscale throughput, Docker networking,
and inter-VM communication.

## Quick Diagnostics

```bash
# Test VM to VM throughput
iperf3 -c media-services.discus-moth.ts.net

# Test NFS performance
dd if=/dev/zero of=/mnt/data/test.img bs=1M count=1000 oflag=direct

# Check network interface stats
ip -s link

# Check MTU
ip link show | grep mtu

# Test DNS resolution speed
time nslookup jellyfin.discus-moth.ts.net
```

## Common Issues

### 1. Slow NFS Performance

**Symptoms**: Slow file transfers, media buffering, slow library scans

**Test NFS Speed**:

```bash
# Write test (from client VM)
dd if=/dev/zero of=/mnt/data/test bs=1M count=1000 conv=fdatasync
# Should see: 80-120 MB/s on gigabit

# Read test
dd if=/mnt/data/test of=/dev/null bs=1M
# Should see: 100-120 MB/s
```

**Solutions**:

1. **Optimize NFS mount options**:

   ```bash
   # Check current options
   mount | grep /mnt/data

   # Recommended options in /etc/fstab:
   nas:/nas-storage /mnt/data nfs defaults,rw,hard,intr,rsize=131072,wsize=131072,timeo=14 0 0

   # Remount
   sudo umount /mnt/data
   sudo mount /mnt/data
   ```

2. **Check network not saturated**:

   ```bash
   # Monitor bandwidth
   sudo iftop -i ens18

   # Check for packet drops
   ip -s link show ens18
   ```

3. **Verify MTU matches** (see MTU section below)

4. **Use async NFS** (slight risk but much faster):

   ```bash
   # /etc/exports on NAS:
   /nas-storage 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)
   # Change sync to async for better performance
   ```

See [NAS/NFS Troubleshooting](nas-nfs.md) for detailed NFS optimization.

### 2. Slow Tailscale Performance

**Symptoms**: Slow access via Tailscale hostnames, high latency

**Test Tailscale Speed**:

```bash
# Direct connection test (should use DERP relay)
iperf3 -c media-services.discus-moth.ts.net

# Compare to local network
iperf3 -c 192.168.0.13
```

**Solutions**:

1. **Enable direct connections** (bypass DERP relay):
   - Tailscale uses DERP relays if direct connection impossible
   - Check: `tailscale status` (look for "direct" vs "relay")
   - Enable UPnP on router for NAT traversal

2. **Check Tailscale not rate-limited**:
   - Free tier: Unlimited (2024)
   - Check status: `tailscale status`

3. **Use local IPs for same-network access**:
   - If accessing from home network, use `192.168.0.x` instead of Tailscale IPs
   - Avoids Tailscale overhead

4. **Verify Tailscale MTU**:

   ```bash
   ip link show tailscale0
   # Should be 1280 (Tailscale default)
   ```

### 3. Podman Network Performance

**Symptoms**: Slow container-to-container communication

**Test Podman Network** (host networking):

```bash
# With host networking, containers share host's network
# Test connectivity to other services on same VM
podman exec sonarr curl -s http://localhost:7878 | head -5  # Radarr

# Test container to host
podman exec sonarr ping -c 4 192.168.0.13

# Check Podman network
podman network inspect podman
```

**Solutions**:

1. **Use host networking** (already configured via Quadlet):
   - All services use host networking for simplicity
   - Configured in Quadlet .container files with `Network=host`
   - Removes container network overhead

2. **Optimize Podman Network MTU**:

   ```bash
   # Check Podman network MTU
   podman network inspect podman | grep -i mtu

   # Set MTU via Quadlet if needed
   # Add to .container file: PodmanArgs=--network-alias=... --mtu=1500

   # Restart services
   systemctl --user restart sonarr radarr prowlarr
   ```

3. **Use macvlan for better performance** (advanced):
   - Gives containers direct network access
   - Complex setup, not needed for typical use

### 4. MTU Mismatch Issues

**Symptoms**: Intermittent connection drops, slow large transfers, works then breaks

**Check MTU**:

```bash
# Host interface
ip link show ens18 | grep mtu

# Podman (if using bridge network, not host)
podman network inspect podman | grep mtu

# Tailscale
ip link show tailscale0 | grep mtu

# NFS mount (check on both client and server)
ip link | grep mtu
```

**Standard MTUs**:

- Ethernet: 1500
- Tailscale: 1280
- Docker: 1500 (default)

**Solutions**:

1. **Match MTU across network path**:

   ```bash
   # Set interface MTU
   sudo ip link set dev ens18 mtu 1500

   # Make permanent in /etc/network/interfaces:
   iface ens18 inet static
     address 192.168.0.13/24
     gateway 192.168.0.1
     mtu 1500
   ```

2. **Test with different MTU sizes**:

   ```bash
   # Test max MTU without fragmentation
   ping -M do -s 1472 192.168.0.15  # 1472 + 28 headers = 1500
   # If fails, reduce: -s 1400, -s 1200, etc.
   ```

### 5. High Latency Between VMs

**Symptoms**: Slow API responses, delayed notifications

**Test Latency**:

```bash
# Basic ping
ping -c 20 media-services.discus-moth.ts.net

# Should be <1ms on local network
# If >5ms, investigate
```

**Solutions**:

1. **Check VM CPU not overloaded**:

   ```bash
   ssh ansible@media-services.discus-moth.ts.net
   top
   # High CPU = slow network processing
   ```

2. **Verify no packet loss**:

   ```bash
   ping -c 100 192.168.0.13 | tail -2
   # 0% packet loss expected
   ```

3. **Check Proxmox network not oversubscribed**:
   - Multiple VMs sharing 1Gbps uplink
   - Monitor Proxmox host network: `iftop`

### 6. Bandwidth Saturation

**Symptoms**: Everything slow during downloads

**Monitor Bandwidth**:

```bash
# Install iftop
sudo apt install iftop

# Real-time bandwidth monitor
sudo iftop -i ens18

# Or use nethogs (per-process)
sudo nethogs ens18
```

**Solutions**:

1. **Limit qBittorrent/SABnzbd speeds**:
   - qBittorrent: Tools → Options → Connection → Rate Limits
   - SABnzbd: Config → Servers → Speed Limit

2. **Use QoS on router** (external to VMs)

3. **Schedule bandwidth-heavy tasks**:
   - Run Sonarr/Radarr scans during off-hours
   - Stagger downloads

## Bandwidth Testing

### Test VM to VM

```bash
# On server VM (e.g., media-services)
iperf3 -s

# On client VM (e.g., jellyfin)
iperf3 -c media-services.discus-moth.ts.net -t 30

# Expected: 900+ Mbps on gigabit network
```

### Test NFS Throughout

```bash
# Large file write
dd if=/dev/zero of=/mnt/data/test bs=1M count=5000 conv=fdatasync
# Expected: 80-120 MB/s

# Large file read
dd if=/mnt/data/test of=/dev/null bs=1M
# Expected: 100-120 MB/s

# Clean up
rm /mnt/data/test
```

### Test Tailscale Throughput

```bash
# Via Tailscale hostname
iperf3 -c jellyfin.discus-moth.ts.net

# Compare to local IP
iperf3 -c 192.168.0.12

# Tailscale adds overhead, expect 10-30% slower if relayed
```

## Network Configuration Best Practices

1. **Use local IPs for same-network communication**:
   - Services on same VM: `localhost`
   - Services on local VMs: `192.168.0.x`
   - Only use Tailscale for remote access

2. **Optimize NFS**:
   - Use `rsize=131072,wsize=131072`
   - Consider `async` for better performance

3. **Match MTU** across all network paths

4. **Use host networking** for low-overhead services

5. **Monitor regularly** with `iftop`, `podman stats`

6. **Limit bandwidth** on download clients to prevent saturation

## See Also

- [NAS/NFS Troubleshooting](nas-nfs.md)
- [Networking Configuration](../configuration/networking.md)
- [Container Resource Management](../configuration/container-resource-management.md)
- [Common Issues](common-issues.md)

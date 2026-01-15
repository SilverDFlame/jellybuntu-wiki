# NAS/NFS Troubleshooting

Troubleshooting guide for Btrfs NAS and NFS mount issues.

## Quick Checks

```bash
# On NAS (192.168.0.15 / nas.discus-moth.ts.net)
# Check Btrfs filesystem
sudo btrfs filesystem show /mnt/storage
sudo btrfs filesystem usage /mnt/storage

# Check NFS server
sudo systemctl status nfs-kernel-server
sudo exportfs -v

# On client VMs
# Check NFS mount
df -h | grep /mnt/data
mount | grep /mnt/data

# Test write access
touch /mnt/data/test.txt && rm /mnt/data/test.txt
```

## NAS Issues

### 1. Can't SSH to NAS

**Symptoms**:

- Connection refused or timeout
- Can't reach nas.discus-moth.ts.net

**Diagnosis**:

```bash
# Test connectivity
ping nas.discus-moth.ts.net
ping 192.168.0.15

# Check if SSH port is open
nc -zv 192.168.0.15 22

# From Proxmox, check VM is running
qm status 300
```

**Solutions**:

1. **VM not running**:

   ```bash
   # On Proxmox
   qm start 300
   ```

2. **Firewall blocking**:
   - SSH accessible via Tailscale or local network after firewall configuration
   - Use Tailscale hostname: `ssh ansible@nas.discus-moth.ts.net`

3. **Check VM console in Proxmox**:
   - Access via Proxmox web UI
   - VM 300 > Console

### 2. Btrfs Filesystem Errors

**Symptoms**:

- Read/write errors
- "Input/output error" messages
- Data corruption warnings

**Diagnosis**:

```bash
# Check device stats
sudo btrfs device stats /mnt/storage

# Check filesystem
sudo btrfs check --readonly /mnt/storage

# View kernel messages
dmesg | grep -i btrfs | tail -20

# Check disk health
sudo smartctl -a /dev/sdb
sudo smartctl -a /dev/sdc
```

**Solutions**:

1. **Device errors detected**:

   ```bash
   # Run scrub to check integrity
   sudo btrfs scrub start /mnt/storage
   sudo btrfs scrub status /mnt/storage
   ```

2. **Filesystem corruption**:

   ```bash
   # Unmount and run check (DANGER: backup first!)
   sudo umount /mnt/storage
   sudo btrfs check --repair /mnt/storage
   sudo mount /mnt/storage
   ```

3. **Disk failure**:
   - Check SMART data for failing disk
   - Replace disk and rebalance:

     ```bash
     sudo btrfs device add /dev/sdX /mnt/storage
     sudo btrfs device delete /dev/OLD_DISK /mnt/storage
     sudo btrfs balance start /mnt/storage
     ```

### 3. Btrfs Filesystem Full

**Symptoms**:

- "No space left on device" error
- Can't write new files
- Btrfs shows space available but writes fail

**Diagnosis**:

```bash
# Check usage
sudo btrfs filesystem usage /mnt/storage
df -h /mnt/storage

# Check metadata
sudo btrfs filesystem df /mnt/storage

# List snapshots
sudo btrfs subvolume list /mnt/storage
```

**Solutions**:

1. **Metadata full** (common issue):

   ```bash
   # Balance metadata
   sudo btrfs balance start -m /mnt/storage
   ```

2. **Too many snapshots**:

   ```bash
   # List snapshots
   sudo btrfs subvolume list -s /mnt/storage

   # Delete old snapshots
   sudo btrfs subvolume delete /mnt/storage/@snapshots/@data/daily-YYYYMMDD-HHMMSS
   ```

3. **Actually full**:

   ```bash
   # Check what's using space
   sudo du -sh /mnt/storage/data/*

   # Clean up unnecessary files
   # Add more storage if needed
   ```

### 4. Snapshot Issues

**Symptoms**:

- Snapshots not being created
- Snapshot timer failing
- Too many snapshots

**Diagnosis**:

```bash
# Check snapshot timer
systemctl status snapshot-manager.timer
systemctl list-timers | grep snapshot

# View logs
sudo journalctl -u snapshot-manager.service -n 50

# List existing snapshots
sudo btrfs subvolume list -s /mnt/storage
```

**Solutions**:

1. **Timer not running**:

   ```bash
   sudo systemctl enable snapshot-manager.timer
   sudo systemctl start snapshot-manager.timer
   ```

2. **Snapshot script errors**:

   ```bash
   # Check logs
   sudo tail -f /var/log/btrfs-snapshots.log

   # Run manually to debug
   sudo /usr/local/bin/snapshot-manager.sh
   ```

3. **Clean up old snapshots**:

   ```bash
   # List all snapshots
   sudo btrfs subvolume list -s /mnt/storage/@snapshots/@data

   # Delete manually
   sudo btrfs subvolume delete /mnt/storage/@snapshots/@data/TYPE-DATE
   ```

### 5. NFS Server Not Running

**Symptoms**:

- Clients can't mount NFS
- "Connection refused" on port 2049
- NFS exports not showing

**Diagnosis**:

```bash
# Check NFS server status
sudo systemctl status nfs-kernel-server

# Check if NFS is listening
sudo netstat -tulpn | grep 2049

# Check exports
sudo exportfs -v

# Test locally
showmount -e localhost
```

**Solutions**:

1. **NFS server stopped**:

   ```bash
   sudo systemctl start nfs-kernel-server
   sudo systemctl enable nfs-kernel-server
   ```

2. **Exports not configured**:

   ```bash
   # Check /etc/exports
   cat /etc/exports

   # Should contain:
   # /mnt/storage/data 192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)
   # /mnt/storage/data 100.64.0.0/10(rw,sync,no_subtree_check,no_root_squash)

   # Reload exports
   sudo exportfs -ra
   ```

3. **Firewall blocking**:

   ```bash
   # Check UFW
   sudo ufw status

   # Should allow NFS from trusted networks
   sudo ufw allow from 192.168.0.0/24 to any port 2049
   sudo ufw allow from 100.64.0.0/10 to any port 2049
   ```

## NFS Client Issues

### 1. Can't Mount NFS Share

**Symptoms**:

- mount command fails
- "Connection refused" or "Connection timed out"
- "mount.nfs: access denied"

**Diagnosis**:

```bash
# Test connectivity to NAS (use direct IP for NFS)
ping 192.168.0.15

# Check if NFS server is accessible
showmount -e 192.168.0.15

# Test NFS port
nc -zv 192.168.0.15 2049

# Check mount command (direct IP for reliability)
sudo mount -t nfs 192.168.0.15:/mnt/storage/data /mnt/data -vvv
```

**Solutions**:

1. **NFS server not reachable**:
   - Verify NAS VM is running
   - Check network connectivity
   - Use direct IP: `192.168.0.15:/mnt/storage/data` (recommended for reliability)

2. **Wrong mount path**:
   - Should be: `192.168.0.15:/mnt/storage/data`
   - NOT: `/mnt/storage` or `/data`

3. **Permissions denied**:
   - Check NFS exports on server allow client's IP
   - Verify no_root_squash is set

4. **Mount point doesn't exist**:

   ```bash
   sudo mkdir -p /mnt/data
   sudo mount -t nfs 192.168.0.15:/mnt/storage/data /mnt/data
   ```

### 2. NFS Mount Read-Only or Permission Denied

**Symptoms**:

- Can read files but can't write
- "Permission denied" when creating files
- Files created with wrong ownership

**Diagnosis**:

```bash
# Check mount options
mount | grep /mnt/data

# Check directory permissions
ls -la /mnt/data

# Try to create file
touch /mnt/data/test.txt
```

**Solutions**:

1. **Mount is read-only**:

   ```bash
   # Remount as read-write
   sudo mount -o remount,rw /mnt/data
   ```

2. **Wrong ownership on NAS**:

   ```bash
   # On NAS
   sudo chown -R 3000:3000 /mnt/storage/data
   sudo chmod -R 775 /mnt/storage/data
   ```

3. **UID/GID mismatch**:

   ```bash
   # On client, verify nfsuser exists
   id nfsuser
   # Should show uid=3000 gid=3000

   # Create if missing
   sudo groupadd -g 3000 nfsusers
   sudo useradd -u 3000 -g 3000 -s /bin/false nfsuser
   ```

### 3. NFS Mount Lost After Reboot

**Symptoms**:

- Mount works manually but not after reboot
- /mnt/data is empty after restart

**Diagnosis**:

```bash
# Check /etc/fstab
cat /etc/fstab | grep /mnt/data

# Check mount service
systemctl status mnt-data.mount

# Try mounting manually
sudo mount -a
```

**Solutions**:

1. **Missing /etc/fstab entry**:

   ```bash
   # Add to /etc/fstab (use direct IP for reliability)
   192.168.0.15:/mnt/storage/data /mnt/data nfs defaults,_netdev 0 0

   # Test
   sudo mount -a
   ```

2. **Network not ready at boot**:
   - Ensure `_netdev` option is in /etc/fstab
   - This delays mount until network is up

### 4. Slow NFS Performance

**Symptoms**:

- File operations are slow
- High latency
- Timeouts

**Diagnosis**:

```bash
# Test read speed
time dd if=/mnt/data/testfile of=/dev/null bs=1M count=100

# Test write speed
time dd if=/dev/zero of=/mnt/data/testfile bs=1M count=100

# Check NFS stats
nfsstat -m

# Check network
ping -c 10 192.168.0.15
```

**Solutions**:

1. **Use better mount options**:

   ```bash
   # Remount with performance options
   sudo mount -o remount,rsize=131072,wsize=131072,hard,timeo=600,retrans=2 /mnt/data
   ```

2. **Network issues**:
   - Check for packet loss
   - Verify MTU settings
   - Use wired connection if possible

3. **NAS overloaded**:
   - Check NAS CPU/RAM usage
   - Reduce concurrent operations

## Advanced Troubleshooting

### Restore from Snapshot

```bash
# On NAS
# 1. Unmount on all clients first!

# 2. On NAS, unmount data subvolume
sudo umount /mnt/storage/data

# 3. Delete current data subvolume
sudo btrfs subvolume delete /mnt/storage/@data

# 4. Restore from snapshot
sudo btrfs subvolume snapshot \
  /mnt/storage/@snapshots/@data/daily-YYYYMMDD-HHMMSS \
  /mnt/storage/@data

# 5. Remount
sudo mount /mnt/storage/@data /mnt/storage/data

# 6. Clients can remount
```

### Run Manual Maintenance

```bash
# On NAS
# Scrub filesystem
sudo btrfs scrub start /mnt/storage
sudo btrfs scrub status -d /mnt/storage

# Balance filesystem
sudo btrfs balance start -dusage=50 /mnt/storage

# Defragment (careful with snapshots!)
sudo btrfs filesystem defragment -r /mnt/storage/data

# Check health
sudo btrfs device stats /mnt/storage
sudo btrfs filesystem usage /mnt/storage
```

### Debug NFS from Client

```bash
# Enable NFS debugging
sudo rpcdebug -m nfs -s all
sudo rpcdebug -m rpc -s all

# Mount with verbose logging (direct IP for reliability)
sudo mount -t nfs -vvv 192.168.0.15:/mnt/storage/data /mnt/data

# Check kernel logs
dmesg | grep -i nfs | tail -20

# Disable debugging when done
sudo rpcdebug -m nfs -c all
sudo rpcdebug -m rpc -c all
```

## Getting Help

If issues persist:

1. **Collect NAS logs**:

   ```bash
   # On NAS
   sudo journalctl -n 500 > /tmp/nas.log
   sudo tail -100 /var/log/btrfs-snapshots.log >> /tmp/nas.log
   sudo tail -100 /var/log/btrfs-maintenance.log >> /tmp/nas.log
   dmesg | tail -100 >> /tmp/nas.log
   ```

2. **Btrfs Resources**:
   - Official docs: https://btrfs.readthedocs.io/
   - Wiki: https://btrfs.wiki.kernel.org/

3. **NFS Resources**:
   - Ubuntu guide: https://ubuntu.com/server/docs/service-nfs
   - Linux NFS FAQ: http://nfs.sourceforge.net/

## See Also

- [Jellyfin Troubleshooting](jellyfin.md)
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Download Clients Troubleshooting](download-clients.md)
- [Networking Troubleshooting](networking.md)
- [NAS Setup Reference](../reference/nas-setup.md)
- [NFS Direct IP Migration](../reference/nfs-direct-ip-migration.md) - Why NFS uses direct IP

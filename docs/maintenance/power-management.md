# Power Management and VM Automation

Guide to VM startup/shutdown automation, maintenance procedures, and power management best practices.

## Overview

Proper VM startup and shutdown ordering ensures:

- **Dependencies respected**: NAS starts before NFS clients
- **Data integrity**: Services shutdown gracefully
- **Fast recovery**: Automatic restart after power loss
- **Maintenance**: Controlled shutdown for updates

**Automated Configuration**: VM autostart and boot order are configured automatically during initial deployment
(playbook `01-provision-vms.yml`). You can reconfigure anytime using the helper script
[`bin/bootstrap/lib/08-configure-vm-autostart.sh`](https://github.com/SilverDFlame/jellybuntu/blob/main/bin/bootstrap/lib/08-configure-vm-autostart.sh).

## VM Dependency Order

### Startup Order

**Priority 1 (Infrastructure)**:

1. **NAS** (VMID 300) - Provides NFS storage, must start first

**Priority 2 (Clients)**:

1. **Jellyfin** (VMID 400) - Depends on NFS for media
2. **Media Services** (VMID 401) - Depends on NFS for media/downloads
3. **Download Clients** (VMID 402) - Depends on NFS for downloads

**Priority 3 (Independent)**:

1. **Home Assistant** (VMID 100) - Independent, can start anytime
2. **Satisfactory Server** (VMID 200) - Independent game server

### Shutdown Order

**Reverse of startup to ensure data safety**:

1. **Satisfactory Server** (VMID 200)
2. **Home Assistant** (VMID 100)
3. **Download Clients** (VMID 402) - Stop downloads gracefully
4. **Media Services** (VMID 401) - Stop media management
5. **Jellyfin** (VMID 400) - Stop streaming
6. **NAS** (VMID 300) - Last to ensure all NFS writes complete

### Why This Order Matters

**NFS Dependencies**:

- Jellyfin, Media Services, and Download Clients mount NFS from NAS
- If NAS starts after clients → NFS mounts fail
- If NAS shuts down before clients → Risk of NFS stale file handles

**Data Integrity**:

- Downloads in progress need graceful shutdown
- Database writes need to complete
- Transcoding processes need to finish

## Proxmox Autostart Configuration

Configure VMs to start automatically after Proxmox host boots.

### Automated Configuration (Recommended)

**During Initial Deployment**:

Autostart configuration is applied automatically when you run playbook `01-provision-vms.yml`:

```bash
./bin/runtime/ansible-run.sh playbooks/core/01-provision-vms.yml
```

This configures all VMs with proper boot order and startup delays based on dependencies.

**Using Helper Script**:

To reconfigure autostart settings after deployment, use the helper script:

```bash
# Show current autostart configuration
./bin/bootstrap/08-configure-vm-autostart.sh --show

# Configure autostart (interactive)
./bin/bootstrap/08-configure-vm-autostart.sh

# Configure autostart (automatic, no prompts)
./bin/bootstrap/08-configure-vm-autostart.sh --auto

# Disable autostart for all VMs
./bin/bootstrap/08-configure-vm-autostart.sh --disable
```

The helper script:

- Connects to Proxmox via SSH
- Configures all VMs in dependency order
- Sets proper startup delays (30s for NAS, 20s for others)
- Sets graceful shutdown timeouts
- Verifies configuration after applying changes

**Configuration Details**:

```yaml
# From playbooks/vars.yml
NAS (300):         onboot=true, startup="order=1,up=30,down=60"
Jellyfin (400):    onboot=true, startup="order=2,up=20,down=60"
Media (401):       onboot=true, startup="order=3,up=20,down=60"
Downloads (402):   onboot=true, startup="order=4,up=20,down=120"
Home Asst (100):   onboot=true, startup="order=5,up=20,down=60"
Satisfactory (200):onboot=true, startup="order=6,up=20,down=60"
```

### Manual Configuration (Alternative)

If you prefer to configure manually instead of using the automated approach:

**Via Web UI**:

1. Access Proxmox: https://jellybuntu.discus-moth.ts.net:8006
2. Select VM from left panel
3. Click **Options** tab
4. Double-click **Start at boot**
5. Check **Start at boot**
6. Set **Startup order** (lower number = starts first)
7. Set **Startup delay** (seconds to wait before starting next VM)
8. Click **OK**

**Via CLI**:

```bash
# SSH to Proxmox host
ssh root@jellybuntu.discus-moth.ts.net

# Configure NAS (starts first, priority 1)
qm set 300 --onboot 1 --startup order=1,up=30

# Configure Jellyfin (priority 2, waits 30s after NAS)
qm set 400 --onboot 1 --startup order=2,up=20

# Configure Media Services (priority 3, waits 20s after Jellyfin)
qm set 401 --onboot 1 --startup order=3,up=20

# Configure Download Clients (priority 4, waits 20s after Media Services)
qm set 402 --onboot 1 --startup order=4,up=20

# Configure Home Assistant (priority 5, waits 20s)
qm set 100 --onboot 1 --startup order=5,up=20

# Configure Satisfactory (priority 6, waits 20s)
qm set 200 --onboot 1 --startup order=6,up=20
```

### Startup Parameters

**--onboot 1**: Enable auto-start
**order=N**: Startup order (1 = first, higher numbers start later)
**up=N**: Delay in seconds before starting next VM
**down=N**: Delay in seconds before shutting down next VM (optional)

### Verify Autostart Configuration

```bash
# Check all VMs
qm list

# Check specific VM config
qm config 300 | grep -E 'onboot|startup'

# View full startup configuration
pvesh get /nodes/jellybuntu/qemu --full 1 | grep -E 'vmid|onboot|startup'
```

### Disable Autostart

If you want VMs to NOT start automatically:

```bash
# Disable for specific VM
qm set 402 --onboot 0

# Or via Web UI: Options → Start at boot → uncheck
```

## Manual Power Management

### Start All VMs (Manual)

```bash
# SSH to Proxmox host
ssh root@jellybuntu.discus-moth.ts.net

# Start in dependency order with delays
qm start 300 && sleep 30  # NAS
qm start 400 && sleep 20  # Jellyfin
qm start 401 && sleep 20  # Media Services
qm start 402 && sleep 20  # Download Clients
qm start 100 && sleep 20  # Home Assistant
qm start 200              # Satisfactory
```

### Start Single VM

```bash
# Start specific VM
qm start <vmid>

# Example: Start Jellyfin
qm start 400

# Check status
qm status 400
```

### Stop All VMs (Graceful)

```bash
# Reverse order for graceful shutdown
qm shutdown 200 && sleep 30  # Satisfactory
qm shutdown 100 && sleep 30  # Home Assistant
qm shutdown 402 && sleep 60  # Download Clients (give time for downloads)
qm shutdown 401 && sleep 30  # Media Services
qm shutdown 400 && sleep 30  # Jellyfin
qm shutdown 300              # NAS (last)
```

### Stop Single VM

```bash
# Graceful shutdown (recommended)
qm shutdown <vmid>

# Force stop (if not responding)
qm stop <vmid>

# Example: Gracefully shutdown Jellyfin
qm shutdown 400

# Wait and check status
sleep 30
qm status 400
```

### Reboot VM

```bash
# Graceful reboot
qm reboot <vmid>

# Example: Reboot Media Services
qm reboot 401
```

## Automated Scripts

### Startup Script

Create script for controlled startup:

**File**: `/usr/local/bin/start-all-vms.sh`

```bash
#!/bin/bash
# Start all VMs in correct order

echo "Starting infrastructure VMs..."

# NAS first
echo "Starting NAS (300)..."
qm start 300
sleep 30

# Wait for NAS to be fully booted
echo "Waiting for NAS to fully boot..."
sleep 30

# Start NFS clients
echo "Starting Jellyfin (400)..."
qm start 400
sleep 20

echo "Starting Media Services (401)..."
qm start 401
sleep 20

echo "Starting Download Clients (402)..."
qm start 402
sleep 20

# Start independent VMs
echo "Starting Home Assistant (100)..."
qm start 100
sleep 20

echo "Starting Satisfactory Server (200)..."
qm start 200

echo "All VMs started!"
echo "Waiting for services to initialize..."
sleep 60

# Verify all running
echo "VM Status:"
qm list
```

**Installation**:

```bash
# On Proxmox host
sudo nano /usr/local/bin/start-all-vms.sh
# Paste script above

# Make executable
sudo chmod +x /usr/local/bin/start-all-vms.sh

# Run
sudo /usr/local/bin/start-all-vms.sh
```

### Shutdown Script

**File**: `/usr/local/bin/stop-all-vms.sh`

```bash
#!/bin/bash
# Stop all VMs in reverse order

echo "Shutting down all VMs gracefully..."

# Independent VMs first
echo "Shutting down Satisfactory Server (200)..."
qm shutdown 200
sleep 10

echo "Shutting down Home Assistant (100)..."
qm shutdown 100
sleep 10

# NFS clients
echo "Shutting down Download Clients (402)..."
qm shutdown 402
sleep 30  # Give time for downloads to pause

echo "Shutting down Media Services (401)..."
qm shutdown 401
sleep 20

echo "Shutting down Jellyfin (400)..."
qm shutdown 400
sleep 20

# NAS last
echo "Shutting down NAS (300)..."
qm shutdown 300
sleep 30

echo "Waiting for all VMs to shutdown..."
sleep 60

# Verify all stopped
echo "VM Status:"
qm list

# Check for any still running
RUNNING=$(qm list | grep running | wc -l)
if [ $RUNNING -gt 0 ]; then
  echo "WARNING: $RUNNING VMs still running"
  qm list | grep running
else
  echo "All VMs shutdown successfully"
fi
```

**Installation**:

```bash
sudo nano /usr/local/bin/stop-all-vms.sh
# Paste script above

sudo chmod +x /usr/local/bin/stop-all-vms.sh

# Run
sudo /usr/local/bin/stop-all-vms.sh
```

### Quick Status Check Script

**File**: `/usr/local/bin/vm-status.sh`

```bash
#!/bin/bash
# Check status of all VMs with names

echo "Jellybuntu VM Status:"
echo "===================="

vms=(
  "100:Home Assistant"
  "200:Satisfactory Server"
  "300:NAS"
  "400:Jellyfin"
  "401:Media Services"
  "402:Download Clients"
)

for vm in "${vms[@]}"; do
  vmid="${vm%%:*}"
  name="${vm##*:}"
  status=$(qm status $vmid | awk '{print $2}')

  if [ "$status" == "running" ]; then
    echo "✓ $name (VMID $vmid): $status"
  else
    echo "✗ $name (VMID $vmid): $status"
  fi
done
```

**Usage**:

```bash
sudo chmod +x /usr/local/bin/vm-status.sh
/usr/local/bin/vm-status.sh
```

## Maintenance Mode

### Entering Maintenance Mode

When performing maintenance on Proxmox host:

**Procedure**:

1. Notify users of downtime
2. Gracefully shutdown all VMs
3. Perform maintenance
4. Restart VMs in correct order

**Commands**:

```bash
# SSH to Proxmox host
ssh root@jellybuntu.discus-moth.ts.net

# Shutdown all VMs
/usr/local/bin/stop-all-vms.sh

# Perform maintenance (updates, configuration, etc.)
apt update && apt upgrade -y

# Reboot if needed
reboot

# After reboot, VMs auto-start (if configured)
# Or manually start:
/usr/local/bin/start-all-vms.sh
```

### Maintenance Mode for Single Service

**Example**: Updating Download Clients VM

```bash
# Stop VM
qm shutdown 402

# Perform maintenance via Proxmox console or after restart
# ...

# Start VM
qm start 402

# Verify services
sleep 60
ssh ansible@download-clients.discus-moth.ts.net "docker compose ps"
```

## Emergency Procedures

### Emergency Shutdown

If you need to shutdown everything immediately:

**Quick Shutdown**:

```bash
# Force stop all VMs (not graceful!)
for vm in 200 100 402 401 400 300; do
  qm stop $vm &
done

# Wait for all to complete
wait

echo "Emergency shutdown complete"
```

⚠️ **Warning**: This can cause data loss. Use only in emergencies (power failure imminent, hardware issue, etc.)

### Power Failure Recovery

After unexpected power loss:

**When Power Returns**:

1. Proxmox host boots
2. VMs auto-start if configured (see Autostart Configuration above)
3. Wait for all services to initialize (~5-10 minutes)
4. Verify services are functioning

**Manual Verification**:

```bash
# SSH to Proxmox (once network is up)
ssh root@jellybuntu.discus-moth.ts.net

# Check VM status
qm list

# Verify NFS mounts on clients
ssh ansible@jellyfin.discus-moth.ts.net "df -h | grep nfs"
ssh ansible@media-services.discus-moth.ts.net "df -h | grep nfs"

# Check Docker services
ssh ansible@media-services.discus-moth.ts.net "docker compose ps"
```

### Failed VM Recovery

If a VM fails to start:

**Diagnosis**:

```bash
# Check VM status
qm status <vmid>

# View VM logs
qm monitor <vmid>

# Check configuration
qm config <vmid>

# Try starting manually
qm start <vmid>

# View console (if available)
qm terminal <vmid>
```

**Solutions**:

```bash
# Reset VM (if hung)
qm reset <vmid>

# Restore from snapshot (if available)
qm listsnapshot <vmid>
qm rollback <vmid> <snapshot-name>

# Check disk space on host
df -h
pvesm status

# Check for conflicts (IP, MAC, etc.)
qm config <vmid> | grep -E 'net|ipconfig'
```

## Scheduled Reboots

### Weekly Reboot (Optional)

Some administrators prefer weekly reboots for stability.

**Cron Job on Proxmox**:

```bash
# Edit cron
crontab -e

# Add weekly reboot (Sunday 3 AM)
0 3 * * 0 /usr/local/bin/stop-all-vms.sh && sleep 300 && reboot

# Or use systemd timer (more robust)
```

**Systemd Timer** (Recommended):

**File**: `/etc/systemd/system/weekly-reboot.timer`

```ini
[Unit]
Description=Weekly VM Reboot Timer

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

**File**: `/etc/systemd/system/weekly-reboot.service`

```ini
[Unit]
Description=Weekly VM Reboot Service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/stop-all-vms.sh
ExecStart=/bin/sleep 300
ExecStart=/sbin/reboot
```

**Enable**:

```bash
systemctl daemon-reload
systemctl enable weekly-reboot.timer
systemctl start weekly-reboot.timer

# Check status
systemctl list-timers
```

### Disable Scheduled Reboots

```bash
systemctl stop weekly-reboot.timer
systemctl disable weekly-reboot.timer
```

## Monitoring VM States

### Real-Time Monitoring

**Proxmox Web UI**:

- Access: https://jellybuntu.discus-moth.ts.net:8006
- View: Summary tab shows all VM states
- Monitor: CPU, RAM, disk I/O per VM

**Command Line**:

```bash
# List all VMs with status
qm list

# Detailed status
qm status <vmid> --verbose

# Watch status (refreshes every 2 seconds)
watch -n 2 'qm list'
```

### Uptime Tracking

**Check VM uptime**:

```bash
# From Proxmox
qm status <vmid>

# From within VM
ssh ansible@<vm>.discus-moth.ts.net "uptime"
```

**Check Proxmox host uptime**:

```bash
ssh root@jellybuntu.discus-moth.ts.net "uptime"
```

## Best Practices

### ✅ Startup/Shutdown

- **Always use dependency order**: NAS first, clients second
- **Allow time between starts**: 20-30 seconds per VM
- **Graceful shutdown**: Use `qm shutdown`, not `qm stop`
- **Verify completion**: Check status before next operation
- **Monitor during**: Watch for errors during startup

### ✅ Automation

- **Configure autostart**: Ensures recovery from power loss
- **Set startup delays**: Prevents resource contention
- **Use scripts**: Consistency and documentation
- **Test procedures**: Verify scripts work before emergencies
- **Document changes**: Update documentation when modifying

### ✅ Maintenance

- **Schedule maintenance**: Plan downtime in advance
- **Notify users**: Inform before taking services offline
- **Snapshots before**: Create VM snapshots before major changes
- **Verify after**: Check all services functional after maintenance
- **Keep logs**: Document what was done

### ⚠️ Avoid

- **Force stop unless necessary**: Can cause data corruption
- **Starting all VMs at once**: Overwhelms host resources
- **Skipping NAS startup delay**: NFS clients will fail
- **Ignoring errors**: Address startup failures immediately
- **No autostart configured**: Manual intervention after power loss

## Resource Considerations

### Host Resource Usage During Startup

**CPU**: All VMs starting simultaneously can max out CPU
**Solution**: Stagger startup with delays

**RAM**: 36GB allocated to VMs, 48GB total
**Solution**: Start VMs incrementally to avoid memory pressure

**Disk I/O**: Multiple VMs booting creates I/O spikes
**Solution**: 20-30 second delays allow previous VM to settle

### Network During Startup

**DHCP**: VMs use static IPs, but Tailscale needs network
**Wait time**: Allow 30-60 seconds for network services to start

**NFS**: Clients retry mounts if NAS not ready
**Delay**: 30 second wait after NAS start ensures NFS is available

## Troubleshooting

### VM Won't Start

**Symptoms**: `qm start` fails or VM immediately stops

**Solutions**:

```bash
# Check VM configuration
qm config <vmid>

# Check for locked VM
qm unlock <vmid>

# Check disk availability
pvesm status

# View error in logs
journalctl -xe | grep "qemu-server"

# Try start with verbose
qm start <vmid> --verbose
```

### NFS Mounts Fail After Startup

**Symptoms**: `/mnt/data` not accessible on client VMs

**Solutions**:

```bash
# Check if NAS is running
qm status 300

# Check NFS server on NAS
ssh ansible@nas.discus-moth.ts.net "systemctl status nfs-server"

# Manually mount on client
ssh ansible@jellyfin.discus-moth.ts.net
sudo mount -a

# Check fstab
cat /etc/fstab | grep nfs

# Verify NFS exports on NAS
ssh ansible@nas.discus-moth.ts.net "sudo exportfs -v"
```

### Startup Sequence Too Slow

**Symptoms**: Takes 10+ minutes for all VMs to start

**Solutions**:

```bash
# Reduce startup delays (if stable)
qm set 400 --startup order=2,up=10  # Down from 30

# Check VM boot time
qm start <vmid>
time qm wait <vmid> --timeout 300

# Optimize VM settings
# - Reduce RAM if overallocated
# - Disable unnecessary services
# - Use SSD for VM disks
```

### Auto-Start Not Working

**Symptoms**: VMs don't start after Proxmox reboot

**Solutions**:

```bash
# Check onboot setting
qm config <vmid> | grep onboot

# Enable if not set
qm set <vmid> --onboot 1

# Check Proxmox boot services
systemctl status pvesr.service
systemctl status pve-ha-lrm.service

# Manually trigger autostart
qm start <vmid>
```

## Reference

### Related Documentation

- [Troubleshooting Guide](troubleshooting.md) - General troubleshooting
- [NFS Troubleshooting](../troubleshooting/nas-nfs.md) - NFS-specific issues
- [Architecture](../architecture.md) - VM dependencies
- [Service Endpoints](../configuration/service-endpoints.md) - Service locations

### External Resources

- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page) - Official docs
- [qm Command Reference](https://pve.proxmox.com/pve-docs/qm.1.html) - VM management
- [Proxmox Startup/Shutdown](https://pve.proxmox.com/wiki/Start_and_Stop_Order) - Official guide

## Summary

**VM Dependency Order**:

1. NAS (300) - First, provides NFS
2. Jellyfin (400) - NFS client
3. Media Services (401) - NFS client
4. Download Clients (402) - NFS client
5. Home Assistant (100) - Independent
6. Satisfactory (200) - Independent

**Key Commands**:

```bash
# Start all VMs
/usr/local/bin/start-all-vms.sh

# Stop all VMs
/usr/local/bin/stop-all-vms.sh

# Check status
/usr/local/bin/vm-status.sh

# Configure autostart
qm set <vmid> --onboot 1 --startup order=N,up=30
```

**Best Practices**:

- Configure autostart for disaster recovery
- Use proper startup delays (20-30s)
- Always shutdown gracefully
- Create scripts for consistency
- Monitor during operations

Your VMs power on and off in perfect harmony!

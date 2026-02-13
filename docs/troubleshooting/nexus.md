# Nexus Repository Troubleshooting

Troubleshooting guide for Nexus Repository Manager container registry issues.

> **IMPORTANT**: Nexus Repository runs as a **rootless Podman container with Quadlet** on NAS VM (192.168.30.15).
Use `systemctl --user` and `journalctl --user` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH into NAS VM
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Check Nexus service status
systemctl --user status nexus

# View Nexus logs
journalctl --user -u nexus -f

# Check web UI access (port 8081)
curl http://localhost:8081

# Check container registry access (port 5001)
curl http://localhost:5001/v2/

# Verify container is running
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman ps | grep nexus
```

## Common Issues

### 1. Nexus Service Won't Start

**Symptoms**:

- Service fails to start
- Error: "Failed to start nexus.service"
- Container exits immediately
- "Startup failed" in logs

**Diagnosis**:

```bash
# Check service status
systemctl --user status nexus

# View detailed logs
journalctl --user -u nexus -n 100 --no-pager

# Check for port conflicts
sudo lsof -i :8081
sudo lsof -i :5001

# Check container logs
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman logs nexus
```

**Solutions**:

1. **Ports already in use**:

   ```bash
   # Find conflicting processes
   sudo lsof -i :8081   # Web UI
   sudo lsof -i :5001   # Container registry

   # Stop conflicting services
   ```

2. **Permission issues**:

   ```bash
   # Nexus requires specific UID (200) ownership
   # Check data directory
   ls -la /opt/nexus/

   # Fix permissions (CRITICAL - must be UID 200)
   sudo chown -R 200:200 /opt/nexus/data/
   sudo chown -R 200:200 /opt/nexus/config/

   # Restart
   systemctl --user restart nexus
   ```

3. **Insufficient disk space**:

   ```bash
   # Check available space
   df -h /opt/nexus

   # Nexus requires several GB for blobs and artifacts
   # Clean up old images/artifacts if needed
   ```

4. **Java heap space errors**:

   ```bash
   # Check logs for OutOfMemoryError
   journalctl --user -u nexus | grep -i "OutOfMemory\|heap"

   # Increase heap size in Quadlet .container file
   nano ~/.config/containers/systemd/nexus.container

   # Add environment variable:
   # Environment=INSTALL4J_ADD_VM_PARAMS=-Xms2703m -Xmx2703m -XX:MaxDirectMemorySize=2703m

   systemctl --user daemon-reload
   systemctl --user restart nexus
   ```

5. **Corrupt configuration**:

   ```bash
   # Stop Nexus
   systemctl --user stop nexus

   # Backup and reset configuration
   sudo cp -r /opt/nexus/data /opt/nexus/data.backup
   sudo rm -rf /opt/nexus/data/*

   # Restart (will reinitialize)
   systemctl --user start nexus
   # Reconfigure via Web UI
   ```

### 2. Can't Access Web UI (Port 8081)

**Symptoms**:

- Browser shows "Connection refused" or times out
- Can't reach http://nas.discus-moth.ts.net:8081
- Can't reach http://192.168.30.15:8081

**Diagnosis**:

```bash
# Check if Nexus is running
systemctl --user status nexus

# Check if Nexus has started (can take 1-2 minutes)
journalctl --user -u nexus | grep -i "started"

# Check firewall rules
sudo ufw status

# Test local access
curl http://localhost:8081

# Check port is listening
sudo netstat -tulpn | grep 8081
```

**Solutions**:

1. **Nexus still starting up**:

   ```bash
   # Nexus takes 1-3 minutes to fully start
   # Watch logs until you see "Started Sonatype Nexus"
   journalctl --user -u nexus -f

   # Wait for startup message, then try accessing Web UI
   ```

2. **Firewall blocking**:

   ```bash
   # Allow Nexus Web UI port
   sudo ufw allow from 192.168.30.0/24 to any port 8081
   sudo ufw allow from 100.64.0.0/10 to any port 8081
   sudo ufw reload
   ```

3. **Container networking issues**:

   ```bash
   # Check container ports
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman port nexus

   # Should show:
   # 8081/tcp -> 0.0.0.0:8081
   # 5001/tcp -> 0.0.0.0:5001
   ```

4. **Service not enabled**:

   ```bash
   systemctl --user enable nexus
   systemctl --user start nexus
   ```

### 3. Can't Push/Pull Container Images (Port 5001)

**Symptoms**:

- `podman push nas.discus-moth.ts.net:5001/image:tag` fails
- "Connection refused" or "unauthorized" errors
- Registry not responding

**Diagnosis**:

```bash
# Test registry API endpoint
curl http://localhost:5001/v2/
# Should return: {} or {"repositories":[]}

curl http://192.168.30.15:5001/v2/
curl http://nas.discus-moth.ts.net:5001/v2/

# Check if registry connector is configured
# Web UI → Administration → Repository → Repositories → docker-hosted
```

**Solutions**:

1. **Firewall blocking registry port**:

   ```bash
   # Allow container registry port
   sudo ufw allow from 192.168.30.0/24 to any port 5001
   sudo ufw allow from 100.64.0.0/10 to any port 5001
   sudo ufw reload
   ```

2. **Docker repository not configured**:
   - Access Web UI: http://nas.discus-moth.ts.net:8081
   - Sign in (admin / check initial password)
   - Administration → Repository → Repositories
   - Verify "docker-hosted" repository exists on port 5001
   - If missing, create Docker (hosted) repository

3. **Authentication required**:

   ```bash
   # Login to registry before pushing
   podman login nas.discus-moth.ts.net:5001

   # Enter credentials:
   # Username: admin (or your Nexus user)
   # Password: (Nexus password)

   # Then retry push
   podman push nas.discus-moth.ts.net:5001/image:tag
   ```

4. **Registry using HTTPS but client expects HTTP**:

   ```bash
   # For insecure registry (HTTP), add to /etc/containers/registries.conf
   sudo nano /etc/containers/registries.conf

   # Add:
   [[registry]]
   location = "nas.discus-moth.ts.net:5001"
   insecure = true

   # Then retry push
   ```

5. **Anonymous pull disabled**:
   - Web UI → Administration → Security → Realms
   - Enable "Docker Bearer Token Realm"
   - Click Save
   - Restart Nexus: `systemctl --user restart nexus`

### 4. Initial Admin Password Not Working

**Symptoms**:

- Can't login with admin user
- "Invalid credentials" error
- Initial setup incomplete

**Diagnosis**:

```bash
# Check if initial password file exists
sudo cat /opt/nexus/data/admin.password

# If file doesn't exist, admin password was already changed
```

**Solutions**:

1. **Get initial admin password**:

   ```bash
   # For first-time setup, password is in admin.password file
   sudo cat /opt/nexus/data/admin.password

   # Copy password and login as:
   # Username: admin
   # Password: (from file)

   # After login, change password when prompted
   ```

2. **Initial password file deleted after setup**:
   - Password was already changed during initial setup
   - Use the password you set during initial setup
   - If forgotten, see "Reset admin password" below

3. **Reset admin password**:

   ```bash
   # Stop Nexus
   systemctl --user stop nexus

   # Access Nexus database to reset password
   # This requires Orient DB CLI or manual database editing
   # Easier: Restore from backup or reinitialize

   # Option 1: Restore from backup
   sudo cp -r /opt/nexus/data.backup/ /opt/nexus/data/
   sudo chown -R 200:200 /opt/nexus/data/

   # Option 2: Fresh start (loses all data!)
   sudo rm -rf /opt/nexus/data/*
   sudo chown -R 200:200 /opt/nexus/data/

   # Restart
   systemctl --user start nexus
   # Wait for startup, then get new admin password
   sudo cat /opt/nexus/data/admin.password
   ```

### 5. Disk Space Filling Up

**Symptoms**:

- "No space left on device" errors
- Nexus performance degraded
- Can't push new images

**Diagnosis**:

```bash
# Check disk usage
df -h /opt/nexus
du -sh /opt/nexus/data/*
du -sh /opt/nexus/data/blobs/

# Check blob store size in Web UI
# Administration → Repository → Blob Stores
```

**Solutions**:

1. **Clean up old/unused artifacts**:
   - Web UI → Browse
   - Navigate to docker-hosted repository
   - Select old/unused images
   - Delete

2. **Configure cleanup policies**:
   - Administration → Repository → Cleanup Policies
   - Create policy:
     - Name: docker-cleanup
     - Criteria: Last downloaded > 30 days, Last blob updated > 60 days
   - Apply to docker-hosted repository
   - Administration → System → Tasks
   - Create "Admin - Compact blob store" task

3. **Run manual cleanup**:
   - Administration → System → Tasks
   - Create "Admin - Execute cleanup policy" task
   - Run immediately

4. **Compact blob store**:
   - Administration → System → Tasks
   - Create "Admin - Compact blob store" task
   - Select blob store
   - Run immediately
   - This reclaims deleted space

5. **Increase disk allocation**:

   ```bash
   # If /opt/nexus is on root partition
   # Consider moving to larger disk or expanding partition

   # Example: Mount larger disk
   sudo mkdir /mnt/nexus-data
   # Mount larger disk to /mnt/nexus-data
   sudo rsync -av /opt/nexus/ /mnt/nexus-data/
   sudo mv /opt/nexus /opt/nexus.old
   sudo ln -s /mnt/nexus-data /opt/nexus
   sudo chown -R 200:200 /mnt/nexus-data/
   systemctl --user restart nexus
   ```

### 6. Slow Performance

**Symptoms**:

- Web UI very slow to load
- Image pulls/pushes take excessive time
- High CPU or memory usage

**Diagnosis**:

```bash
# Check resource usage
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats nexus --no-stream

# Check disk I/O
iostat -x 1 5

# Check Nexus logs for errors
journalctl --user -u nexus | grep -i "error\|slow\|timeout"
```

**Solutions**:

1. **Insufficient memory**:

   ```bash
   # Nexus needs at least 2GB heap
   # Edit Quadlet .container file to increase memory
   nano ~/.config/containers/systemd/nexus.container

   # Increase heap size:
   # Environment=INSTALL4J_ADD_VM_PARAMS=-Xms4096m -Xmx4096m -XX:MaxDirectMemorySize=4096m

   systemctl --user daemon-reload
   systemctl --user restart nexus
   ```

2. **Database needs rebuilding**:
   - Administration → System → Tasks
   - Create "Repair - Rebuild repository search" task
   - Run for all repositories

3. **Too many artifacts**:
   - Implement cleanup policies (see Issue #5)
   - Delete unused repositories
   - Compact blob stores

4. **Slow disk I/O**:

   ```bash
   # Test disk performance
   dd if=/dev/zero of=/opt/nexus/testfile bs=1M count=1024 oflag=direct

   # Consider moving to faster storage
   # Or optimize NFS mount if on network storage
   ```

### 7. Repository Health Check Failures

**Symptoms**:

- Health check shows errors
- "Repository is unhealthy" warnings
- Repositories showing offline

**Diagnosis**:

```bash
# Check logs for health check errors
journalctl --user -u nexus | grep -i "health\|check"

# Web UI → Administration → System → Support → System Information
# Check for reported issues
```

**Solutions**:

1. **Run repository repair**:
   - Administration → System → Tasks
   - Create "Repair - Rebuild repository metadata" task
   - Select affected repository
   - Run immediately

2. **Rebuild search index**:
   - Administration → System → Tasks
   - Create "Repair - Rebuild repository search" task
   - Run for all repositories

3. **Check blob store integrity**:
   - Administration → Repository → Blob Stores
   - Verify blob stores are accessible
   - Check disk space and permissions

4. **Restart Nexus**:

   ```bash
   systemctl --user restart nexus
   # Wait 2-3 minutes for full startup
   ```

### 8. Can't Delete Repository or Blob Store

**Symptoms**:

- "Cannot delete repository" error
- "Blob store in use" message
- Delete button disabled

**Diagnosis**:

```bash
# Check if repository has content
# Web UI → Browse → [Repository]

# Check for active tasks
# Administration → System → Tasks
```

**Solutions**:

1. **Repository has artifacts**:
   - Browse → [Repository]
   - Delete all artifacts first
   - Then delete repository

2. **Blob store in use by repository**:
   - Delete all repositories using the blob store first
   - Administration → Repository → Repositories
   - Then delete blob store

3. **Active cleanup tasks**:
   - Administration → System → Tasks
   - Stop any running cleanup tasks
   - Wait for completion
   - Then retry delete

## Advanced Troubleshooting

### Check Quadlet Configuration

```bash
# View generated systemd service
systemctl --user cat nexus

# View Quadlet .container file
cat ~/.config/containers/systemd/nexus.container

# Regenerate service from Quadlet
systemctl --user daemon-reload
systemctl --user restart nexus
```

### Container Resource Monitoring

```bash
# Monitor resource usage in real-time
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman stats nexus

# Check configured resource limits
podman inspect nexus | grep -A 10 "Memory\|Cpu"
```

### Access Nexus Logs Inside Container

```bash
# Enter container
export XDG_RUNTIME_DIR=/run/user/$(id -u)
podman exec -it nexus /bin/bash

# View Nexus logs
tail -f /nexus-data/log/nexus.log

# Check Java process
ps aux | grep java

# Exit
exit
```

### Database Integrity Check

```bash
# Stop Nexus
systemctl --user stop nexus

# Backup database
sudo tar -czf ~/nexus-db-backup-$(date +%Y%m%d).tar.gz /opt/nexus/data/db/

# Check OrientDB integrity (if available)
# Requires OrientDB CLI tools

# Restart
systemctl --user start nexus
```

### Backup and Restore

```bash
# Full backup (stop Nexus first for consistency)
systemctl --user stop nexus
sudo tar -czf ~/nexus-backup-$(date +%Y%m%d).tar.gz /opt/nexus/
systemctl --user start nexus

# Restore from backup
systemctl --user stop nexus
sudo rm -rf /opt/nexus/data/
sudo tar -xzf ~/nexus-backup-*.tar.gz -C /
sudo chown -R 200:200 /opt/nexus/
systemctl --user start nexus
```

### Export/Import Configuration

Using Nexus API (requires admin credentials):

```bash
# Export repository configuration
curl -u admin:password -X GET \
  "http://nas.discus-moth.ts.net:8081/service/rest/v1/repositories" \
  > nexus-repos-config.json

# Import repository configuration
# Use Web UI or API to recreate repositories
```

## Performance Tuning

### For Production Use

1. **Increase heap size**:

   ```bash
   # Edit Quadlet .container file
   nano ~/.config/containers/systemd/nexus.container

   # Set heap to 4-8GB depending on usage:
   # Environment=INSTALL4J_ADD_VM_PARAMS=-Xms4096m -Xmx4096m -XX:MaxDirectMemorySize=4096m
   ```

2. **Configure cleanup policies**:
   - Automatically delete old artifacts
   - Compact blob stores regularly
   - Prevents disk space issues

3. **Use proxy repositories for Docker Hub**:
   - Caches pulled images
   - Reduces external bandwidth
   - Faster pulls for repeated images

## Getting Help

If issues persist after trying these solutions:

1. **Collect logs**:

   ```bash
   journalctl --user -u nexus -n 1000 --no-pager > /tmp/nexus-systemd.log

   # Get Nexus internal logs
   sudo cat /opt/nexus/data/log/nexus.log > /tmp/nexus-internal.log
   ```

2. **Enable debug logging**:

   Web UI → Administration → System → Logging
   - Change ROOT logger to DEBUG
   - Check logs for detailed error information

3. **Gather diagnostic info**:

   ```bash
   # Nexus version (check Web UI footer or About page)

   # Container status
   export XDG_RUNTIME_DIR=/run/user/$(id -u)
   podman ps -a | grep nexus
   podman inspect nexus

   # Disk usage
   df -h /opt/nexus
   du -sh /opt/nexus/*
   ```

4. **Nexus community resources**:
   - Official docs: https://help.sonatype.com/repomanager3
   - Community forum: https://community.sonatype.com/
   - GitHub: https://github.com/sonatype/nexus-public/issues
   - Stack Overflow: Tag `nexus` or `nexus3`

## See Also

- [Nexus Registry Configuration](../configuration/nexus-registry.md) - Initial setup instructions
- [Nexus Maintenance](../maintenance/nexus-maintenance.md) - Cleanup and maintenance procedures
- [NAS Troubleshooting](nas-nfs.md) - NAS VM issues
- [Service Endpoints](../configuration/service-endpoints.md) - Nexus access information

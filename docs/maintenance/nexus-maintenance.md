# Nexus Repository Maintenance

Operational procedures for maintaining Nexus Repository Manager, including cleanup policies, disk
management, and scheduled tasks.

## Overview

Nexus Repository runs on the NAS VM (192.168.30.15) as a rootless Podman container. Without regular
maintenance, cached images and artifacts will accumulate and consume disk space.

**Key maintenance concerns:**

- Proxy repository caches grow unbounded
- Blob store requires periodic compaction
- Disk usage needs monitoring

## Storage Architecture

### Blob Store Location

```text
/opt/nexus/data/blobs/default/
```

All repositories share the `default` blob store. Artifacts are stored as content-addressable blobs with metadata.

### Directory Structure

```text
/opt/nexus/
├── data/
│   ├── blobs/default/     # Artifact storage
│   ├── db/                # OrientDB database
│   ├── log/               # Application logs
│   └── tmp/               # Temporary files
```

### Checking Disk Usage

```bash
# SSH to NAS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Check blob store size
du -sh /opt/nexus/data/blobs/

# Check total Nexus data
du -sh /opt/nexus/data/

# Check available disk space
df -h /opt/nexus/
```

## Cleanup Policies

Cleanup policies define rules for removing old or unused artifacts. They are created in the Nexus UI and applied to repositories.

### Creating Cleanup Policies

1. Navigate to: **Administration > Repository > Cleanup Policies**
2. Click **Create Cleanup Policy**
3. Configure:
   - **Name**: Descriptive name (e.g., `docker-proxy-cleanup`)
   - **Format**: Select repository format (e.g., `docker`)
   - **Criteria**: Set cleanup rules

### Recommended Policies

#### Docker Proxy Repositories

For `docker-hub-proxy`, `docker-ghcr-proxy`, `docker-gcr-proxy`, etc.:

| Setting | Value | Reason |
|---------|-------|--------|
| Last downloaded before | 30 days | Remove stale cached images |
| Asset name matcher | (leave empty) | Apply to all |

#### Docker Hosted Repository

For `docker-hosted` (custom images like `packer-ansible`):

| Setting | Value | Reason |
|---------|-------|--------|
| Component age | 90 days | Keep images for 3 months |
| Release type | All | Include all versions |

### Applying Policies to Repositories

1. Navigate to: **Administration > Repository > Repositories**
2. Select repository (e.g., `docker-hub-proxy`)
3. Scroll to **Cleanup** section
4. Select cleanup policy from dropdown
5. Save

## Image Retention

### Proxy Repositories

Proxy repositories cache images pulled from upstream registries. Retention is controlled by:

- **Cleanup policy**: Removes images not downloaded recently
- **Negative cache TTL**: How long to cache "not found" responses (default: 1440 minutes)
- **Metadata max age**: How often to re-check upstream (default: 1440 minutes)

### Hosted Repositories

Hosted repositories store custom images. Consider:

- **Version limits**: Keep only N most recent versions
- **Tag patterns**: Preserve certain tags (e.g., `latest`, `stable`)
- **Component age**: Remove components older than X days

## Disk Space Management

### Monitoring Thresholds

| Usage Level | Status | Action |
|-------------|--------|--------|
| < 70% | Normal | No action needed |
| 70-85% | Warning | Review cleanup policies |
| 85-95% | Critical | Run manual cleanup |
| > 95% | Emergency | Immediate intervention required |

### Manual Cleanup Procedure

If disk usage is critical:

1. **Run cleanup task immediately**:
   - Navigate to: **Administration > System > Tasks**
   - Find: **Admin - Cleanup repositories using their associated policies**
   - Click **Run**

2. **Compact blob store**:
   - Find: **Admin - Compact blob store**
   - Click **Run**

3. **Verify space reclaimed**:

   ```bash
   df -h /opt/nexus/
   ```

### Emergency Cleanup

If Nexus is unresponsive due to disk full:

```bash
# SSH to NAS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Stop Nexus
systemctl --user stop nexus

# Clear temporary files
rm -rf /opt/nexus/data/tmp/*

# Clear logs if necessary (preserves recent)
find /opt/nexus/data/log -name "*.log" -mtime +7 -delete

# Start Nexus
systemctl --user start nexus
```

## Scheduled Maintenance

Configure scheduled tasks in Nexus to run automatically.

### Recommended Tasks

Navigate to: **Administration > System > Tasks**

#### 1. Cleanup Repositories

- **Task**: Admin - Cleanup repositories using their associated policies
- **Schedule**: Daily at 02:00
- **Purpose**: Apply cleanup policies to all repositories

#### 2. Compact Blob Store

- **Task**: Admin - Compact blob store
- **Schedule**: Weekly on Sunday at 03:00
- **Purpose**: Reclaim disk space from deleted blobs

#### 3. Cleanup Unused Assets

- **Task**: Admin - Delete unused assets
- **Schedule**: Daily at 04:00
- **Purpose**: Remove orphaned assets not part of any component

### Creating a Scheduled Task

1. Navigate to: **Administration > System > Tasks**
2. Click **Create task**
3. Select task type
4. Configure:
   - **Task name**: Descriptive name
   - **Task frequency**: Cron expression or manual
   - **Repository**: Select target (or all)
5. Save

## Troubleshooting

### Disk Full Recovery

**Symptoms**: Nexus UI unresponsive, container crashes, write errors in logs.

**Resolution**:

1. Stop Nexus: `systemctl --user stop nexus`
2. Clear temp/logs as shown above
3. Start Nexus: `systemctl --user start nexus`
4. Run cleanup tasks immediately
5. Review and tighten cleanup policies

### Blob Store Corruption

**Symptoms**: "Blob not found" errors, missing artifacts.

**Resolution**:

1. Run: **Admin - Repair - Reconcile component database from blob store**
2. If persists, restore from backup (see backup-recovery.md)

### Slow Performance

**Symptoms**: UI sluggish, long pull times.

**Possible causes**:

- Database needs compaction
- Too many stored artifacts
- Insufficient memory

**Resolution**:

1. Run blob store compaction
2. Review cleanup policies
3. Consider increasing container memory limit

## See Also

- [Nexus Registry Configuration](../configuration/nexus-registry.md)
- [Backup and Recovery](backup-recovery.md)
- [Nexus Official Documentation](https://help.sonatype.com/en/sonatype-nexus-repository.html)

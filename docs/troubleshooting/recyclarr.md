# Recyclarr Troubleshooting

Recyclarr automatically syncs quality profiles and custom formats from TRaSH Guides to Sonarr and Radarr, ensuring
optimal media quality configurations.

## Overview

- **VM**: media-services (192.168.0.13)
- **Container**: recyclarr
- **Config Path**: `/opt/media-stack/recyclarr/config`
- **Image**: docker.io/recyclarr/recyclarr:7.4.1
- **Purpose**: Automate TRaSH Guides quality profile and custom format sync

## What Recyclarr Does

Recyclarr applies best-practice configurations from [TRaSH Guides](https://trash-guides.info/) to:

1. **Quality Definitions**: Bitrate ranges for quality levels
2. **Quality Profiles**: Which qualities to download and preferred order
3. **Custom Formats**: Release group preferences, encoding preferences, HDR formats, etc.
4. **Scores**: Numerical scores to prefer/reject certain release attributes

This eliminates manual configuration and ensures optimal media quality.

## Quick Diagnostics

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check if container exists
docker ps -a | grep recyclarr

# View logs from last run
docker logs recyclarr

# Check config file
sudo cat /opt/media-stack/recyclarr/config/recyclarr.yml

# Manual sync test
docker start recyclarr
docker logs recyclarr -f
```

## How Recyclarr Runs

**Important**: Recyclarr is **not** a continuously running service. It's designed to run periodically:

1. Container starts
2. Reads config from `/config/recyclarr.yml`
3. Syncs to Sonarr and Radarr
4. Exits (container stops)
5. Docker restart policy: `unless-stopped` (manual starts only)

### Running Sync Manually

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Start Recyclarr (runs sync then exits)
docker start recyclarr

# Follow logs to see sync progress
docker logs recyclarr -f

# Check result
docker logs recyclarr --tail 50
```

### Automated Sync Schedule

To run Recyclarr automatically, set up a cron job or systemd timer:

**Cron Example** (runs daily at 3 AM):

```bash
# Edit crontab
crontab -e

# Add line:
0 3 * * * docker start recyclarr
```

**Systemd Timer Example**:

```bash
# Create timer file
sudo nano /etc/systemd/system/recyclarr.timer
```

Add content:

```ini
[Unit]
Description=Run Recyclarr daily

[Timer]
OnCalendar=daily
OnCalendar=03:00
Persistent=true

[Install]
WantedBy=timers.target
```

Create service file:

```bash
sudo nano /etc/systemd/system/recyclarr.service
```

Add content:

```ini
[Unit]
Description=Recyclarr Sync
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/bin/docker start recyclarr
```

Enable timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now recyclarr.timer

# Check status
sudo systemctl list-timers recyclarr.timer
```

## Common Issues

### 1. Sync Failed - API Connection Error

**Symptoms**:

- Logs show "Failed to connect" or "Connection refused"
- Cannot reach Sonarr/Radarr API

**Diagnosis**:

```bash
# Check Recyclarr logs
docker logs recyclarr | grep -i error

# Common errors:
# "Failed to connect to http://localhost:8989"
# "Connection refused"
# "Timeout"
```

**Solutions**:

1. **Network mode issue**:
   - Recyclarr uses `network_mode: host`
   - This allows `localhost` URLs to work
   - Verify in compose file: `docker inspect recyclarr | grep NetworkMode`

2. **Sonarr/Radarr not running**:

   ```bash
   # Check if services are up
   docker ps | grep sonarr
   docker ps | grep radarr
   ```

3. **Wrong API key**:
   - Check API keys in Sonarr/Radarr:
     - Settings → General → Security → API Key
   - Verify config file has correct keys:

     ```bash
     sudo cat /opt/media-stack/recyclarr/config/recyclarr.yml | grep api_key
     ```

4. **Test connectivity manually**:

   ```bash
   # From host (Recyclarr uses host network)
   curl http://localhost:8989/api/v3/system/status
   curl http://localhost:7878/api/v3/system/status
   ```

### 2. Custom Format Sync Failures

**Symptoms**:

- Logs show "Custom format not found"
- Custom formats not appearing in Sonarr/Radarr
- Warnings about invalid trash_ids

**Diagnosis**:

```bash
# Check logs for custom format errors
docker logs recyclarr | grep -i "custom format"
docker logs recyclarr | grep -i "trash_id"
```

**Common Errors**:

- `Custom format with trash_id 'xxxxx' does not exist`
- `Failed to process custom format`

**Solutions**:

1. **Outdated trash_id**:
   - TRaSH Guides IDs occasionally change
   - Recyclarr auto-skips invalid IDs (by design)
   - Update config with current IDs from TRaSH Guides

2. **Unsupported custom format**:
   - Some custom formats are Radarr-only or Sonarr-only
   - Check TRaSH Guides for compatibility

3. **Verify custom formats in Sonarr/Radarr**:
   - Sonarr: Settings → Profiles → Custom Formats
   - Radarr: Settings → Custom Formats
   - Manually verify formats exist after sync

4. **Re-sync after errors**:

   ```bash
   # Run sync again
   docker start recyclarr
   docker logs recyclarr -f
   ```

### 3. Quality Profile Not Updated

**Symptoms**:

- Sync succeeds but quality profile unchanged
- Expected qualities/scores not applied

**Diagnosis**:

```bash
# Check logs for quality profile actions
docker logs recyclarr | grep -i "quality profile"
docker logs recyclarr | grep -i "WEB-2160p"
```

**Solutions**:

1. **Profile name mismatch**:
   - Recyclarr config specifies profile name: `WEB-2160p + 1080p`
   - Profile must exist in Sonarr with exact same name
   - Create profile manually if missing:
     - Sonarr → Settings → Profiles → Add
     - Name: `WEB-2160p + 1080p`

2. **Manual changes conflict**:
   - If you manually edited profile, Recyclarr may not override
   - Delete and recreate profile, then sync

3. **Verify in UI**:
   - Sonarr → Settings → Profiles → WEB-2160p + 1080p
   - Check:
     - Quality order matches config
     - Custom format scores applied
     - Upgrade until quality/score set correctly

4. **Reset and re-sync**:
   - Delete quality profile in Sonarr/Radarr
   - Re-create with correct name
   - Run Recyclarr sync again

### 4. Configuration File Errors

**Symptoms**:

- Recyclarr fails to start
- Logs show YAML parsing errors
- "Invalid configuration" messages

**Diagnosis**:

```bash
# Check logs for config errors
docker logs recyclarr | grep -i "error\|failed\|invalid"

# Verify config file syntax
sudo cat /opt/media-stack/recyclarr/config/recyclarr.yml
```

**Solutions**:

1. **YAML syntax error**:
   - Check indentation (use spaces, not tabs)
   - Verify colons and dashes
   - Use YAML validator: https://www.yamllint.com/

2. **Missing required fields**:
   - Verify `base_url` and `api_key` present for each instance
   - Check quality_definition type is valid

3. **Restore from backup**:

   ```bash
   # If config was working before
   sudo cp /opt/media-stack/recyclarr/config/recyclarr.yml.bak \
     /opt/media-stack/recyclarr/config/recyclarr.yml
   ```

4. **Re-deploy from Ansible** (if using playbook):

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/09-configure-recyclarr-role.yml
   ```

### 5. Permissions Issues

**Symptoms**:

- "Permission denied" errors
- Cannot read/write config file
- Container fails to start

**Diagnosis**:

```bash
# Check file ownership
ls -la /opt/media-stack/recyclarr/config/

# Check container user
docker inspect recyclarr | grep -i user
```

**Solutions**:

1. **Fix config directory permissions**:

   ```bash
   sudo chown -R 1000:1000 /opt/media-stack/recyclarr/config
   sudo chmod -R 755 /opt/media-stack/recyclarr/config
   ```

2. **Verify volume mount**:

   ```bash
   docker inspect recyclarr | grep -A5 Mounts
   ```

3. **Recreate container**:

   ```bash
   cd /opt/media-stack
   docker compose up -d recyclarr
   ```

### 6. Sync Takes Too Long or Times Out

**Symptoms**:

- Recyclarr runs for 5+ minutes
- Timeout errors
- Incomplete sync

**Solutions**:

1. **Large custom format list**:
   - Syncing 100+ custom formats is slow
   - Normal for comprehensive configs
   - Wait for completion (up to 10 minutes)

2. **Increase API timeout** (if needed):
   - Add to recyclarr.yml under each instance:

   ```yaml
   sonarr:
     web-2160p-1080p:
       base_url: http://localhost:8989
       api_key: YOUR_KEY
       timeout: 120  # seconds
   ```

3. **Reduce custom formats**:
   - Comment out less important trash_ids
   - Focus on essential formats only

4. **Check Sonarr/Radarr performance**:

   ```bash
   # Check if Sonarr/Radarr are slow
   docker stats sonarr radarr --no-stream
   ```

### 7. No Output in Logs

**Symptoms**:

- `docker logs recyclarr` shows nothing
- Container starts and stops immediately
- No error messages

**Diagnosis**:

```bash
# Check container status
docker ps -a | grep recyclarr

# Check exit code
docker inspect recyclarr | grep -i exitcode

# Try running with output
docker start -i recyclarr
```

**Solutions**:

1. **Container exited successfully**:
   - Exit code 0 = success
   - Check earlier log entries:

     ```bash
     docker logs recyclarr --tail 200
     ```

2. **No config file**:

   ```bash
   # Verify config exists
   ls -la /opt/media-stack/recyclarr/config/recyclarr.yml
   ```

3. **Silent failure**:
   - Try manual run with interactive output:

   ```bash
   docker run --rm -it \
     --network host \
     -v /opt/media-stack/recyclarr/config:/config \
     docker.io/recyclarr/recyclarr:7.4.1
   ```

## Verification After Sync

### Verify Sonarr Sync

1. **Check Quality Profile**:
   - Sonarr → Settings → Profiles → WEB-2160p + 1080p
   - Verify quality order and scores

2. **Check Custom Formats**:
   - Settings → Profiles → Custom Formats
   - Should see formats: BR-DISK, LQ, Repack/Proper, etc.

3. **Check Quality Definitions**:
   - Settings → Quality
   - Verify bitrate ranges updated

### Verify Radarr Sync

1. **Check Quality Profile**:
   - Radarr → Settings → Profiles → UHD Bluray + WEB
   - Verify quality order and scores

2. **Check Custom Formats**:
   - Settings → Custom Formats
   - Should see formats: DV HDR10, IMAX, Release Groups, etc.

3. **Test with Search**:
   - Search for a movie
   - Manual Search tab
   - Should see custom format badges and scores

## Manual Sync Best Practices

1. **Initial sync**: Run manually after setup to verify
2. **After config changes**: Always run manual sync to test
3. **Regular schedule**: Set up cron/timer for weekly syncs
4. **Before major downloads**: Sync before adding many new shows/movies
5. **After Sonarr/Radarr updates**: Re-sync to ensure compatibility

## Advanced Configuration

### Multiple Sonarr/Radarr Instances

Add additional instances (e.g., 4K separate instance):

```yaml
sonarr:
  web-2160p-1080p:
    base_url: http://localhost:8989
    api_key: KEY1
    # ... config ...

  sonarr-4k:
    base_url: http://localhost:8990  # different port
    api_key: KEY2
    # ... 4K-specific config ...
```

### Exclude Specific Custom Formats

To skip certain custom formats:

```yaml
custom_formats:
  - trash_ids:
      - format-id-to-include
    # Omit IDs you don't want
```

### Override Scores

Custom score overrides:

```yaml
custom_formats:
  - trash_ids:
      - 85c61753df5da1fb2aab6f2a47426b09  # BR-DISK
    assign_scores_to:
      - name: WEB-2160p + 1080p
        score: -5000  # Different from TRaSH default
```

## Logs and Debugging

### View Full Sync Log

```bash
# Complete log from last run
docker logs recyclarr

# Save to file for analysis
docker logs recyclarr > recyclarr-sync.log
```

### Log Patterns

**Successful Sync**:

```text
[INF] Processing Sonarr Server: web-2160p-1080p
[INF] Syncing Quality Definitions
[INF] Syncing Custom Formats
[INF] Syncing Quality Profiles: WEB-2160p + 1080p
[INF] Completed!
```

**Partial Success** (skipped invalid formats):

```text
[WRN] Custom format trash_id xxxxx does not exist, skipping
[INF] Completed with warnings
```

**Failure**:

```text
[ERR] Failed to connect to Sonarr API
[ERR] Sync failed
```

## Update Recyclarr

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Pull latest image
cd /opt/media-stack
docker compose pull recyclarr
docker compose up -d recyclarr

# Run sync with new version
docker start recyclarr
docker logs recyclarr -f
```

## Related TRaSH Guides

- **Quality Settings**: https://trash-guides.info/Sonarr/Sonarr-Quality-Settings-File-Size/
- **Custom Formats**: https://trash-guides.info/Radarr/Radarr-collection-of-custom-formats/
- **Quality Profiles**: https://trash-guides.info/Radarr/radarr-setup-quality-profiles/

## See Also

- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Media Quality Profiles Reference](../reference/media-quality-profiles.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [Media Services Workflow](../reference/media-services-workflow.md)

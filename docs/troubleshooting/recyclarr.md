# Recyclarr Troubleshooting

Recyclarr automatically syncs quality profiles and custom formats from TRaSH Guides to Sonarr and Radarr, ensuring
optimal media quality configurations.

> **IMPORTANT**: Recyclarr runs as a **rootless Podman container with Quadlet** on the media-services VM (192.168.30.13).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

- **VM**: media-services (192.168.30.13)
- **Container**: recyclarr
- **Config Path**: `~/.config/recyclarr/`
- **Deployment**: Rootless Podman with Quadlet
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

# Check service status
systemctl --user status recyclarr

# View logs from last run
journalctl --user -u recyclarr -n 100

# Check config file
cat ~/.config/recyclarr/recyclarr.yml

# Manual sync test
systemctl --user start recyclarr
journalctl --user -u recyclarr -f
```

## How Recyclarr Runs

**Important**: Recyclarr is **not** a continuously running service. It's designed to run periodically:

1. Service starts container
2. Reads config from `~/.config/recyclarr/recyclarr.yml`
3. Syncs to Sonarr and Radarr
4. Exits (container stops)
5. Run manually or via systemd timer

### Running Sync Manually

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Start Recyclarr (runs sync then exits)
systemctl --user start recyclarr

# Follow logs to see sync progress
journalctl --user -u recyclarr -f

# Check result
journalctl --user -u recyclarr -n 50
```

### Automated Sync Schedule

To run Recyclarr automatically, set up a systemd timer (recommended for Quadlet deployments):

**Systemd Timer Example** (runs daily at 3 AM):

```bash
# Create user timer file
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/recyclarr.timer
```

Add content:

```ini
[Unit]
Description=Run Recyclarr daily

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable timer:

```bash
systemctl --user daemon-reload
systemctl --user enable --now recyclarr.timer

# Check status
systemctl --user list-timers recyclarr.timer
```

**Note**: The Quadlet `.container` file already defines the service unit, so you only need the timer.

## Common Issues

### 1. Sync Failed - API Connection Error

**Symptoms**:

- Logs show "Failed to connect" or "Connection refused"
- Cannot reach Sonarr/Radarr API

**Diagnosis**:

```bash
# Check Recyclarr logs
journalctl --user -u recyclarr | grep -i error

# Common errors:
# "Failed to connect to http://localhost:8989"
# "Connection refused"
# "Timeout"
```

**Solutions**:

1. **Network mode issue**:
   - Recyclarr uses host networking via Quadlet
   - This allows `localhost` URLs to work
   - Verify in Quadlet file: `cat ~/.config/containers/systemd/recyclarr.container`

2. **Sonarr/Radarr not running**:

   ```bash
   # Check if services are up
   systemctl --user status sonarr
   systemctl --user status radarr
   podman ps | grep -E "sonarr|radarr"
   ```

3. **Wrong API key**:
   - Check API keys in Sonarr/Radarr:
     - Settings → General → Security → API Key
   - Verify config file has correct keys:

     ```bash
     cat ~/.config/recyclarr/recyclarr.yml | grep api_key
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
journalctl --user -u recyclarr | grep -i "custom format"
journalctl --user -u recyclarr | grep -i "trash_id"
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
   systemctl --user start recyclarr
   journalctl --user -u recyclarr -f
   ```

### 3. Quality Profile Not Updated

**Symptoms**:

- Sync succeeds but quality profile unchanged
- Expected qualities/scores not applied

**Diagnosis**:

```bash
# Check logs for quality profile actions
journalctl --user -u recyclarr | grep -i "quality profile"
journalctl --user -u recyclarr | grep -i "WEB-2160p"
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
journalctl --user -u recyclarr | grep -i "error\|failed\|invalid"

# Verify config file syntax
cat ~/.config/recyclarr/recyclarr.yml
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
   cp ~/.config/recyclarr/recyclarr.yml.bak ~/.config/recyclarr/recyclarr.yml
   ```

4. **Re-deploy from Ansible** (if using playbook):

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/services/media-services.yml --tags recyclarr
   ```

### 5. Permissions Issues

**Symptoms**:

- "Permission denied" errors
- Cannot read/write config file
- Container fails to start

**Diagnosis**:

```bash
# Check file ownership
ls -la ~/.config/recyclarr/

# Check container user mapping
podman inspect recyclarr | grep -i user
```

**Solutions**:

1. **Fix config directory permissions**:

   ```bash
   # Config owned by user running podman (rootless)
   chown -R $(id -u):$(id -g) ~/.config/recyclarr
   chmod -R 755 ~/.config/recyclarr
   ```

2. **Verify volume mount**:

   ```bash
   cat ~/.config/containers/systemd/recyclarr.container | grep -i volume
   ```

3. **Restart service**:

   ```bash
   systemctl --user restart recyclarr
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
   podman stats sonarr radarr --no-stream
   ```

### 7. No Output in Logs

**Symptoms**:

- `journalctl --user -u recyclarr` shows nothing
- Container starts and stops immediately
- No error messages

**Diagnosis**:

```bash
# Check service status
systemctl --user status recyclarr

# Check container status
podman ps -a | grep recyclarr

# Check exit code
podman inspect recyclarr | grep -i exitcode
```

**Solutions**:

1. **Container exited successfully**:
   - Exit code 0 = success
   - Check earlier log entries:

     ```bash
     journalctl --user -u recyclarr -n 200
     ```

2. **No config file**:

   ```bash
   # Verify config exists
   ls -la ~/.config/recyclarr/recyclarr.yml
   ```

3. **Silent failure**:
   - Try manual run with interactive output:

   ```bash
   podman run --rm -it \
     --network host \
     -v ~/.config/recyclarr:/config \
     docker.io/recyclarr/recyclarr:latest
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
journalctl --user -u recyclarr --no-pager

# Save to file for analysis
journalctl --user -u recyclarr --no-pager > recyclarr-sync.log
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
podman pull docker.io/recyclarr/recyclarr:latest

# Restart service with new image
systemctl --user restart recyclarr

# Run sync with new version
systemctl --user start recyclarr
journalctl --user -u recyclarr -f
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

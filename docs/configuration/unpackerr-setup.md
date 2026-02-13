# Unpackerr Automation Guide

Unpackerr is an application that automatically extracts archived downloads (RAR, ZIP, 7z, tar, etc.) for Sonarr and
Radarr, seamlessly integrating with your media automation workflow.

## Overview

- **VM**: download-clients (192.168.30.14)
- **Container**: unpackerr
- **Config Path**: `/opt/media-stack/unpackerr`
- **Image**: docker.io/golift/unpackerr:0.15.0
- **Purpose**: Automatic extraction of compressed media files

## Why Unpackerr?

Many torrent and usenet releases come as compressed archives (RAR, ZIP). Sonarr/Radarr expect extracted video files.
Unpackerr bridges this gap by:

1. **Monitoring** download paths for completed downloads
2. **Detecting** archived files referenced by Sonarr/Radarr
3. **Extracting** archives automatically
4. **Notifying** Sonarr/Radarr that files are ready
5. **Cleaning up** extracted archives (optional)

## How It Works

### Workflow

1. **Download Completes**:
   - qBittorrent or SABnzbd finishes downloading
   - Files placed in `/data/torrents/tv` or `/data/usenet/movies`
   - Many contain compressed archives (`.rar`, `.zip`, etc.)

2. **Unpackerr Detection**:
   - Polls Sonarr/Radarr APIs every 2 minutes (configurable)
   - Checks for downloads in "Downloaded" state
   - Identifies which downloads contain archives

3. **Extraction**:
   - Extracts archives in monitored paths
   - Preserves file permissions (644 for files, 755 for folders)
   - Runs as NFS user (UID/GID 1000) for proper ownership

4. **Notification**:
   - Notifies Sonarr/Radarr extraction is complete
   - Sonarr/Radarr imports the extracted media
   - Media moves to `/data/media/tv` or `/data/media/movies`

5. **Cleanup** (optional):
   - Can delete original archives after successful extraction
   - Default: archives kept for 5 minutes, then deleted

## Configuration

Unpackerr is configured via environment variables in the Docker Compose file.

### Core Settings

```yaml
# How often to check for archives
UN_INTERVAL: 2m

# Wait time before first check after startup
UN_START_DELAY: 1m

# Wait time before retrying failed extractions
UN_RETRY_DELAY: 5m

# Maximum extraction attempts
UN_MAX_RETRIES: 3

# Number of simultaneous extractions
UN_PARALLEL: 1
```

### File Permissions

```yaml
# Extracted file permissions
UN_FILE_MODE: 0644  # rw-r--r--

# Extracted directory permissions
UN_DIR_MODE: 0755   # rwxr-xr-x
```

### Sonarr Integration

```yaml
# Sonarr URL (can access via Tailscale hostname)
UN_SONARR_0_URL: http://media-services.discus-moth.ts.net:8989

# Sonarr API key
UN_SONARR_0_API_KEY: your-api-key

# Paths to monitor (must match Sonarr's download paths)
UN_SONARR_0_PATHS_0: /data/torrents/tv
UN_SONARR_0_PATHS_1: /data/usenet/tv

# Protocols to handle
UN_SONARR_0_PROTOCOLS: torrent,usenet

# API timeout
UN_SONARR_0_TIMEOUT: 10s

# Delete original archives after extraction
UN_SONARR_0_DELETE_ORIG: false

# Wait before deleting (if DELETE_ORIG=true)
UN_SONARR_0_DELETE_DELAY: 5m
```

### Radarr Integration

```yaml
# Radarr URL
UN_RADARR_0_URL: http://media-services.discus-moth.ts.net:7878

# Radarr API key
UN_RADARR_0_API_KEY: your-api-key

# Paths to monitor
UN_RADARR_0_PATHS_0: /data/torrents/movies
UN_RADARR_0_PATHS_1: /data/usenet/movies

# Other settings same as Sonarr
```

### Volume Mounts

**Critical**: Unpackerr must have access to the exact same paths as Sonarr/Radarr.

```yaml
volumes:
  # Data paths (same as Sonarr/Radarr see them)
  - /mnt/data:/data
```

This ensures:

- Unpackerr sees `/data/torrents/tv`
- Sonarr also sees `/data/torrents/tv`
- Paths match exactly for extraction to work

## Monitoring Unpackerr

### Check Logs

```bash
# SSH to download-clients VM
ssh -i ~/.ssh/ansible_homelab ansible@download-clients.discus-moth.ts.net

# View logs
docker logs unpackerr

# Follow logs in real-time
docker logs unpackerr -f

# See recent activity
docker logs unpackerr --tail 100
```

### Log Patterns

**Successful Extraction**:

```text
[INFO] Extracted: /data/torrents/movies/Movie.Title.2024/Movie.rar
[INFO] Sonarr notified for extraction: Movie Title
```

**No Archives Found**:

```text
[INFO] No extractions needed
```

**Extraction Failure**:

```text
[ERROR] Failed to extract: /data/torrents/tv/Show.S01E01/show.rar
[ERROR] Retry 1 of 3 in 5m
```

## Verification

### Test Extraction Workflow

1. **Download a compressed release**:
   - Search for media in Sonarr/Radarr
   - Choose a release marked as "RAR" or "ZIP"
   - Send to download client

2. **Monitor Unpackerr logs**:

   ```bash
   docker logs unpackerr -f
   ```

3. **Watch for extraction**:
   - After download completes (1-2 minutes)
   - Unpackerr should detect and extract
   - Sonarr/Radarr imports extracted media

4. **Verify import**:
   - Check Sonarr/Radarr → Activity → Queue (should clear)
   - Check Sonarr/Radarr → Series/Movies (media should appear)

### Check Integration

```bash
# Verify Unpackerr can reach Sonarr
docker exec unpackerr wget -qO- http://media-services.discus-moth.ts.net:8989/api/v3/system/status

# Verify Unpackerr can reach Radarr
docker exec unpackerr wget -qO- http://media-services.discus-moth.ts.net:7878/api/v3/system/status
```

## Troubleshooting

### Archives Not Being Extracted

**Symptoms**:

- Downloads complete but archives remain
- Sonarr/Radarr show "Waiting" or "Importing" indefinitely
- Unpackerr logs show no activity

**Diagnosis**:

```bash
# Check if Unpackerr is running
docker ps | grep unpackerr

# Check logs for errors
docker logs unpackerr | grep -i error

# Verify paths are mounted
docker exec unpackerr ls -la /data/torrents/tv
docker exec unpackerr ls -la /data/usenet/movies
```

**Solutions**:

1. **Path mismatch**:
   - Verify Unpackerr paths match Sonarr/Radarr exactly
   - Check `docker-compose-downloads.yml` volume mounts
   - Ensure `/mnt/data` is properly mounted on download-clients VM

2. **Wrong API key**:
   - Get API keys from Sonarr/Radarr:
     - Settings → General → Security → API Key
   - Update in compose file
   - Restart Unpackerr: `docker restart unpackerr`

3. **Permission issues**:

   ```bash
   # Check file ownership in download paths
   ls -la /mnt/data/torrents/tv

   # Should be owned by UID/GID 1000
   # If not, fix permissions:
   sudo chown -R 1000:1000 /mnt/data/torrents
   sudo chown -R 1000:1000 /mnt/data/usenet
   ```

4. **Polling interval**:
   - Default 2-minute check interval may feel slow
   - Reduce `UN_INTERVAL` if needed (e.g., `1m`)
   - Restart container after change

5. **Archive type not supported**:
   - Unpackerr supports: RAR, ZIP, 7z, tar, gz, bz2
   - Check logs for unsupported format errors
   - Consider different release if exotic compression used

### Extraction Failures

**Symptoms**:

- Logs show extraction attempts failing
- Archives remain after multiple retries

**Diagnosis**:

```bash
# Check for specific error messages
docker logs unpackerr | grep -i "failed"

# Common errors:
# - "No space left on device" → Disk full
# - "Permission denied" → Permission issue
# - "Corrupt archive" → Download incomplete/damaged
```

**Solutions**:

1. **Disk space**:

   ```bash
   # Check available space
   df -h /mnt/data

   # Free up space if needed
   ```

2. **Corrupt download**:
   - Delete download in qBittorrent/SABnzbd
   - Re-download from different source
   - Check qBittorrent/SABnzbd logs for download errors

3. **Password-protected archives**:
   - Unpackerr cannot extract password-protected archives
   - Avoid password-protected releases

4. **Incomplete multipart archives**:
   - RAR archives split into multiple parts (.r00, .r01, etc.)
   - All parts must be present for extraction
   - Check download completed fully

### High CPU/Memory Usage

**Symptoms**:

- Unpackerr consuming excessive resources
- System slowdown during extraction

**Diagnosis**:

```bash
# Check resource usage
docker stats unpackerr --no-stream
```

**Solutions**:

1. **Reduce parallel extractions**:
   - Set `UN_PARALLEL: 1` (already default)
   - Prevents multiple simultaneous extractions

2. **Increase check interval**:
   - Set `UN_INTERVAL: 5m` instead of `2m`
   - Reduces polling frequency

3. **Large archive size**:
   - Extracting 50GB+ archives is CPU/I/O intensive
   - Normal behavior, extraction will complete eventually
   - Monitor with `docker stats unpackerr`

### Sonarr/Radarr Not Notified

**Symptoms**:

- Archives extracted manually or by Unpackerr
- But Sonarr/Radarr doesn't import files

**Solutions**:

1. **Manual rescan**:
   - Sonarr → Activity → Queue → Manual Import
   - Or Sonarr → Series → (Select series) → Scan

2. **Verify webhook**:
   - Sonarr/Radarr should have webhooks configured automatically
   - But check: Settings → Connect
   - Should see Unpackerr webhook or equivalent

3. **Check import paths**:
   - Extracted files must be in Sonarr/Radarr's monitored paths
   - Verify paths with: `docker exec sonarr ls /data/torrents/tv`

## Advanced Configuration

### Multiple Sonarr/Radarr Instances

Add additional instances (e.g., for 4K):

```yaml
# 4K Sonarr instance
- UN_SONARR_1_URL=http://sonarr4k:8989
- UN_SONARR_1_API_KEY=different-api-key
- UN_SONARR_1_PATHS_0=/data/torrents/tv-4k

# 4K Radarr instance
- UN_RADARR_1_URL=http://radarr4k:7878
- UN_RADARR_1_API_KEY=different-api-key
- UN_RADARR_1_PATHS_0=/data/torrents/movies-4k
```

### Enable Debug Logging

For detailed troubleshooting:

```yaml
environment:
  - UN_DEBUG=true
```

Restart Unpackerr: `docker restart unpackerr`

View detailed logs: `docker logs unpackerr -f`

**Note**: Debug mode is very verbose. Disable after troubleshooting.

### Delete Archives After Extraction

To save disk space:

```yaml
# Enable archive deletion
- UN_SONARR_0_DELETE_ORIG=true
- UN_SONARR_0_DELETE_DELAY=5m

- UN_RADARR_0_DELETE_ORIG=true
- UN_RADARR_0_DELETE_DELAY=5m
```

**Warning**: Ensure extraction successful before enabling. Archives will be permanently deleted.

### Custom File Modes

Change extracted file permissions if needed:

```yaml
# More restrictive (owner only)
- UN_FILE_MODE=0600
- UN_DIR_MODE=0700

# More permissive (group writable)
- UN_FILE_MODE=0664
- UN_DIR_MODE=0775
```

## Best Practices

1. **Monitor initially**: Watch logs after setup to ensure working
2. **Keep archives temporarily**: Don't enable DELETE_ORIG until confident
3. **Sufficient disk space**: Extraction doubles space usage temporarily
4. **Match paths exactly**: Unpackerr, Sonarr, Radarr must see same paths
5. **Avoid compressed releases**: When possible, choose uncompressed releases

## Performance Considerations

- **Extraction is I/O intensive**: Large archives stress NFS network
- **Single extraction at a time**: `UN_PARALLEL=1` prevents overwhelming system
- **Background operation**: Extraction happens automatically, no user action needed
- **Typical extraction time**: 30-120 seconds for 2-5GB archive

## See Also

- [qBittorrent/SABnzbd Troubleshooting](../troubleshooting/download-clients.md)
- [Sonarr/Radarr Troubleshooting](../troubleshooting/sonarr-radarr.md)
- [Service Endpoints](service-endpoints.md)
- [Media Services Workflow](../reference/media-services-workflow.md)

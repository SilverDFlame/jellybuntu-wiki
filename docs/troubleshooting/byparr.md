# Byparr Troubleshooting

Byparr is a proxy service that bypasses Cloudflare and DDoS-GUARD protection, allowing Prowlarr to access indexers
that would otherwise be blocked. It uses the Camoufox browser (Firefox-based) for challenge solving.

> **IMPORTANT**: Byparr runs as a **rootless Podman container with Quadlet** on the media-services VM (192.168.30.13).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

- **VM**: media-services (192.168.30.13)
- **Port**: 8191
- **Container**: byparr
- **Image**: `ghcr.io/thephaseless/byparr:2.1.0` (pinned)
- **Browser**: Camoufox (Firefox-based)
- **Purpose**: Bypass Cloudflare protection for torrent indexers
- **Deployment**: Rootless Podman with Quadlet
- **Resources**: 1.5GB memory limit / 768MB reservation, PID limit 150
- **Init**: `container_init: true` (tini for zombie reaping)
- **Concurrency**: uvicorn limited to 3 workers

## Access

- **Tailscale**: http://media-services.discus-moth.ts.net:8191
- **Local Network**: http://192.168.30.13:8191

## Quick Diagnostics

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check service status
systemctl --user status byparr

# View logs
journalctl --user -u byparr -f

# Check if container is running
podman ps | grep byparr

# Check resource usage
podman stats byparr --no-stream

# Test endpoint
curl http://localhost:8191/
```

## How It Works

### Normal Indexer Access (Without Byparr)

1. Prowlarr makes HTTP request to indexer
2. Indexer responds with search results
3. Prowlarr processes and forwards to Sonarr/Radarr

### Protected Indexer Access (With Byparr)

1. Prowlarr detects Cloudflare challenge
2. Prowlarr forwards request to Byparr
3. Byparr uses Camoufox (Firefox-based) to solve challenge
4. Byparr returns solved cookies/content to Prowlarr
5. Prowlarr uses cookies to access indexer normally

## Prowlarr Integration

### Configure Byparr in Prowlarr

1. **Open Prowlarr**: http://media-services.discus-moth.ts.net:9696

2. **Navigate to Settings**:
   - Settings > Indexers > FlareSolverr

3. **Add Byparr**:
   - **Tags**: Leave empty (applies to all indexers) or add specific tag
   - **Host**: `http://byparr:8191/`
   - **Request Timeout**: `60` seconds (default)
   - Click **Test** to verify
   - Click **Save**

### Configure Indexers to Use Byparr

**Automatic** (Recommended):

- Most Cloudflare-protected indexers auto-detect need
- Prowlarr will automatically use Byparr when needed

**Manual** (if needed):

1. Settings > Indexers > (Select indexer)
2. Scroll to **Tags**
3. Add flaresolverr tag (if you tagged the proxy)
4. Save

### Verify Integration

1. **Test Indexer**:
   - Prowlarr > Indexers > (Select indexer)
   - Click **Test**
   - Should succeed if indexer uses Cloudflare

2. **Search Test**:
   - Prowlarr > Search
   - Enter search term
   - Watch for results from Cloudflare-protected indexers

3. **Check Byparr Logs**:

   ```bash
   journalctl --user -u byparr -f
   ```

   - Should show requests when Prowlarr uses it

## Common Issues

### 1. Byparr Not Responding

**Symptoms**:

- Prowlarr shows FlareSolverr timeout
- Test in Prowlarr fails
- Indexer searches fail

**Diagnosis**:

```bash
# Check service status
systemctl --user status byparr

# Check logs for errors
journalctl --user -u byparr -n 100

# Test endpoint directly
curl http://localhost:8191/
```

**Solutions**:

1. **Service not running**:

   ```bash
   systemctl --user start byparr
   systemctl --user enable byparr
   ```

2. **Port conflict**:

   ```bash
   # Check what's using port 8191
   sudo lsof -i :8191

   # If conflict, stop other service or change Byparr port
   ```

3. **Network connectivity from Prowlarr**:

   ```bash
   # Test from Prowlarr container
   podman exec prowlarr curl http://localhost:8191/
   ```

4. **Restart Byparr**:

   ```bash
   systemctl --user restart byparr
   ```

### 2. Indexer Still Being Blocked

**Symptoms**:

- Indexer search returns "Cloudflare blocked"
- Indexer test fails even with Byparr configured

**Diagnosis**:

```bash
# Check Byparr logs during indexer test
journalctl --user -u byparr -f

# Then test indexer in Prowlarr
```

**Solutions**:

1. **Byparr not configured in Prowlarr**:
   - Verify Prowlarr > Settings > Indexers > FlareSolverr is configured
   - Test the connection

2. **Indexer not using Byparr**:
   - Some indexers don't auto-detect need
   - Manually tag indexer with flaresolverr tag

3. **Challenge solving failed**:
   - Check logs for solving errors
   - Cloudflare may have updated protections
   - Update Byparr to latest version

4. **Increase timeout**:
   - Prowlarr > Settings > Indexers > FlareSolverr
   - Increase **Request Timeout** to 90-120 seconds
   - Save and test again

### 3. High Memory Usage

**Symptoms**:

- Byparr consuming excessive RAM
- System slowdown when Byparr active

**Diagnosis**:

```bash
# Check resource usage
podman stats byparr --no-stream

# Check for memory issues
journalctl --user -u byparr | grep -i memory
```

**Explanation**:

- Byparr uses Camoufox (Firefox-based browser)
- Memory usage is typically lower than Chrome-based solutions
- Container has 1.5GB memory limit / 768MB reservation
- Memory released after requests complete

**Solutions**:

1. **Normal behavior**:
   - Some memory usage during indexer searches is expected
   - Drops after searches complete
   - Monitor but no action needed if within container limits

2. **Memory leak** (if memory keeps growing):

   ```bash
   # Restart service to reclaim memory
   systemctl --user restart byparr
   ```

### 4. Slow Indexer Searches

**Symptoms**:

- Indexer searches take 30-60+ seconds
- Prowlarr timeouts

**Explanation**:

- Byparr must launch Camoufox, solve challenge, fetch results
- Much slower than direct HTTP requests
- 15-30 seconds is normal for Cloudflare-protected indexers

**Solutions**:

1. **Increase timeout** (if searches fail):
   - Prowlarr > Settings > Indexers > FlareSolverr
   - Set **Request Timeout**: 90-120 seconds

2. **Use non-Cloudflare indexers when possible**:
   - Prioritize indexers without Cloudflare
   - Reduces dependency on Byparr

3. **Accept slower speeds**:
   - Tradeoff for accessing protected indexers
   - Search results eventually arrive

### 5. Byparr Crashes or Restarts

**Symptoms**:

- Container repeatedly restarting
- Logs show crashes
- Indexer searches intermittently fail

**Diagnosis**:

```bash
# Check service restart count
systemctl --user status byparr

# Check for crash logs
journalctl --user -u byparr | grep -i "error\|crash\|fatal"

# Check system resources
free -h
df -h
```

**Solutions**:

1. **Out of memory**:

   ```bash
   # Check available memory
   free -h

   # If low, restart service
   systemctl --user restart byparr

   # Consider increasing VM RAM if persistent
   ```

2. **Disk space full**:

   ```bash
   # Check disk space
   df -h ~/.local/share/containers

   # Clean up if needed
   podman system prune -a
   ```

3. **Update Byparr**:

   ```bash
   podman pull ghcr.io/thephaseless/byparr:2.0.1
   systemctl --user restart byparr
   ```

### 6. Can't Solve Captcha/Challenge

**Symptoms**:

- Byparr logs show challenge solving failed
- Indexer returns captcha page

**Diagnosis**:

```bash
# Check logs for challenge details
journalctl --user -u byparr | grep -i "challenge\|captcha"
```

**Solutions**:

1. **Challenge type unsupported**:
   - Byparr handles Cloudflare JS challenges
   - Does NOT handle reCAPTCHA or interactive captchas
   - If indexer requires manual captcha, Byparr can't help

2. **Cloudflare updated protection**:
   - Update Byparr to latest version
   - Check GitHub issues for known problems

3. **IP banned/rate-limited**:
   - Indexer may have rate limits
   - Wait 15-30 minutes before retrying
   - Consider using VPN (Gluetun) for different IP

4. **Use alternative indexer**:
   - If specific indexer consistently fails
   - Find alternative indexer without Cloudflare

## Testing Byparr

### Manual API Test

```bash
# Basic health check
curl http://localhost:8191/

# Test challenge solving (example)
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{
    "cmd": "request.get",
    "url": "https://example-indexer.com",
    "maxTimeout": 60000
  }'
```

### Test from Prowlarr

1. Prowlarr > Settings > Indexers > FlareSolverr
2. Click **Test**
3. Should return success message

### Integration Test

1. Find a Cloudflare-protected indexer in Prowlarr
2. Run a search in Prowlarr
3. Watch Byparr logs: `journalctl --user -u byparr -f`
4. Should see request, challenge solving, and response

## Logs and Debugging

### Log Patterns

**Successful Request**:

```text
Solving challenge for https://example-indexer.com
Challenge solved successfully
```

**Failed Request**:

```text
Challenge solving failed: Timeout
Failed to bypass Cloudflare
```

## When to Use Byparr

**Use Byparr for**:

- Indexers with Cloudflare "Checking your browser" page
- Indexers with DDoS-GUARD protection
- Indexers that fail with "403 Forbidden"

**Don't need Byparr for**:

- Indexers without protection (most private trackers)
- Indexers with simple username/password auth
- Indexers that work fine in Prowlarr without it

## Alternative Solutions

If Byparr doesn't work:

1. **Use VPN** (Gluetun already deployed):
   - Different IP may bypass restrictions
   - Already configured for download-clients VM

2. **Find alternative indexers**:
   - Many indexers don't use Cloudflare
   - Prowlarr supports 500+ indexers

3. **Manual cookie extraction** (advanced):
   - Solve Cloudflare in browser
   - Extract cookies
   - Manually add to Prowlarr indexer config

## Resource Hardening

Byparr includes several resource controls to prevent runaway processes:

| Control | Value | Purpose |
|---------|-------|---------|
| PID Limit | 150 | Prevents fork bombs and runaway browser processes |
| uvicorn Workers | 3 | Limits concurrent request handling |
| `container_init` | true | Tini init process reaps zombie Camoufox children |
| Memory Limit | 1.5GB | Hard cap prevents OOM impact on other services |

### Camoufox Reaper

A systemd timer automatically kills stale Camoufox browser processes that exceed 15 minutes:

- **Timer**: Runs every 10 minutes
- **Action**: Kills Camoufox processes older than 15 minutes
- **Purpose**: Prevents browser processes from accumulating after failed challenge solves

**Check reaper status**:

```bash
systemctl --user status camoufox-reaper.timer
systemctl --user list-timers | grep camoufox
```

**Manual cleanup** (if stale processes accumulate):

```bash
# List Camoufox processes
pgrep -af camoufox

# Kill all Camoufox processes
pkill -f camoufox

# Restart Byparr
systemctl --user restart byparr
```

### 7. Stale Camoufox Processes

**Symptoms**:

- High memory usage from multiple browser processes
- Byparr becomes slow or unresponsive
- `podman stats` shows growing memory usage

**Diagnosis**:

```bash
# Check for stale processes inside the container
podman exec byparr pgrep -af camoufox

# Check process count
podman exec byparr ps aux | wc -l
```

**Solutions**:

1. **Reaper timer should handle this automatically** - verify it's running
2. **Manual restart** if reaper isn't catching them:

   ```bash
   systemctl --user restart byparr
   ```

3. **Check PID limit** - if hitting limit, processes can't spawn:

   ```bash
   podman inspect byparr | grep -i pid
   ```

## Update Byparr

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Pull pinned image
podman pull ghcr.io/thephaseless/byparr:2.1.0

# Restart service
systemctl --user restart byparr

# Verify version
journalctl --user -u byparr | grep "version"
```

## See Also

- [Prowlarr Troubleshooting](prowlarr.md)
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Common Issues](common-issues.md)
- [VPN/Gluetun Configuration](../configuration/vpn-gluetun.md)

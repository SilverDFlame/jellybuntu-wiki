# FlareSolverr Troubleshooting

FlareSolverr is a proxy service that bypasses Cloudflare and DDoS-GUARD protection, allowing Prowlarr to access indexers
that would otherwise be blocked.

## Overview

- **VM**: media-services (192.168.0.13)
- **Port**: 8191
- **Container**: flaresolverr
- **Purpose**: Bypass Cloudflare protection for torrent indexers
- **Image**: ghcr.io/flaresolverr/flaresolverr:v3.3.21

## Access

- **Tailscale**: http://media-services.discus-moth.ts.net:8191
- **Local Network**: http://192.168.0.13:8191

## Quick Diagnostics

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check if container is running
docker ps | grep flaresolverr

# View logs
docker logs flaresolverr --tail 100

# Check resource usage
docker stats flaresolverr --no-stream

# Test endpoint
curl http://localhost:8191/
```

## How It Works

### Normal Indexer Access (Without FlareSolverr)

1. Prowlarr makes HTTP request to indexer
2. Indexer responds with search results
3. Prowlarr processes and forwards to Sonarr/Radarr

### Protected Indexer Access (With FlareSolverr)

1. Prowlarr detects Cloudflare challenge
2. Prowlarr forwards request to FlareSolverr
3. FlareSolverr uses headless Chrome to solve challenge
4. FlareSolverr returns solved cookies/content to Prowlarr
5. Prowlarr uses cookies to access indexer normally

## Prowlarr Integration

### Configure FlareSolverr in Prowlarr

1. **Open Prowlarr**: http://media-services.discus-moth.ts.net:9696

2. **Navigate to Settings**:
   - Settings → Indexers → FlareSolverr

3. **Add FlareSolverr**:
   - **Tags**: Leave empty (applies to all indexers) or add specific tag
   - **Host**: `http://localhost:8191/` (same VM)
   - **Request Timeout**: `60` seconds (default)
   - Click **Test** to verify
   - Click **Save**

### Configure Indexers to Use FlareSolverr

**Automatic** (Recommended):

- Most Cloudflare-protected indexers auto-detect need
- Prowlarr will automatically use FlareSolverr when needed

**Manual** (if needed):

1. Settings → Indexers → (Select indexer)
2. Scroll to **Tags**
3. Add flaresolverr tag (if you tagged FlareSolverr)
4. Save

### Verify Integration

1. **Test Indexer**:
   - Prowlarr → Indexers → (Select indexer)
   - Click **Test**
   - Should succeed if indexer uses Cloudflare

2. **Search Test**:
   - Prowlarr → Search
   - Enter search term
   - Watch for results from Cloudflare-protected indexers

3. **Check FlareSolverr Logs**:

   ```bash
   docker logs flaresolverr -f
   ```

   - Should show requests when Prowlarr uses it

## Common Issues

### 1. FlareSolverr Not Responding

**Symptoms**:

- Prowlarr shows FlareSolverr timeout
- Test in Prowlarr fails
- Indexer searches fail

**Diagnosis**:

```bash
# Check if running
docker ps | grep flaresolverr

# Check logs for errors
docker logs flaresolverr

# Test endpoint directly
curl http://localhost:8191/
# Should return: {"msg":"FlareSolverr is ready!","version":"3.3.21","userAgent":"..."}
```

**Solutions**:

1. **Container not running**:

   ```bash
   cd /opt/media-stack
   docker compose up -d flaresolverr
   ```

2. **Port conflict**:

   ```bash
   # Check what's using port 8191
   sudo lsof -i :8191

   # If conflict, stop other service or change FlareSolverr port
   ```

3. **Network connectivity from Prowlarr**:

   ```bash
   # Test from Prowlarr container
   docker exec prowlarr curl http://localhost:8191/
   ```

4. **Restart FlareSolverr**:

   ```bash
   docker restart flaresolverr
   ```

### 2. Indexer Still Being Blocked

**Symptoms**:

- Indexer search returns "Cloudflare blocked"
- Indexer test fails even with FlareSolverr configured

**Diagnosis**:

```bash
# Check FlareSolverr logs during indexer test
docker logs flaresolverr -f

# Then test indexer in Prowlarr
```

**Solutions**:

1. **FlareSolverr not configured in Prowlarr**:
   - Verify Prowlarr → Settings → Indexers → FlareSolverr is configured
   - Test the FlareSolverr connection

2. **Indexer not using FlareSolverr**:
   - Some indexers don't auto-detect need
   - Manually tag indexer with flaresolverr tag

3. **FlareSolverr solving failed**:
   - Check logs for "Challenge solving failed"
   - Cloudflare may have updated protections
   - Update FlareSolverr to latest version

4. **Increase timeout**:
   - Prowlarr → Settings → Indexers → FlareSolverr
   - Increase **Request Timeout** to 90-120 seconds
   - Save and test again

### 3. High Memory Usage

**Symptoms**:

- FlareSolverr consuming 500MB-1GB+ RAM
- System slowdown when FlareSolverr active

**Diagnosis**:

```bash
# Check resource usage
docker stats flaresolverr --no-stream

# Check for memory leaks
docker logs flaresolverr | grep -i memory
```

**Explanation**:

- FlareSolverr uses headless Chrome (Chromium)
- Chrome is memory-intensive by design
- 500MB-1GB is normal during active use
- Memory released after requests complete

**Solutions**:

1. **Normal behavior**:
   - High memory during indexer searches is expected
   - Drops after searches complete
   - Monitor but no action needed if < 1.5GB

2. **Memory leak** (if memory keeps growing):

   ```bash
   # Restart container to reclaim memory
   docker restart flaresolverr
   ```

3. **Consider dedicated VM** (if persistent issues):
   - Move FlareSolverr to separate VM if resource constrained
   - Update Prowlarr config with new FlareSolverr URL

### 4. Slow Indexer Searches

**Symptoms**:

- Indexer searches take 30-60+ seconds
- Prowlarr timeouts

**Explanation**:

- FlareSolverr must launch Chrome, solve challenge, fetch results
- Much slower than direct HTTP requests
- 15-30 seconds is normal for Cloudflare-protected indexers

**Solutions**:

1. **Increase timeout** (if searches fail):
   - Prowlarr → Settings → Indexers → FlareSolverr
   - Set **Request Timeout**: 90-120 seconds

2. **Optimize Chrome args** (already set):

   ```yaml
   environment:
     - CHROME_ARGS=--no-sandbox,--disable-dev-shm-usage
   ```

3. **Use non-Cloudflare indexers when possible**:
   - Prioritize indexers without Cloudflare
   - Reduces dependency on FlareSolverr

4. **Accept slower speeds**:
   - Tradeoff for accessing protected indexers
   - Search results eventually arrive

### 5. FlareSolverr Crashes or Restarts

**Symptoms**:

- Container repeatedly restarting
- Logs show crashes
- Indexer searches intermittently fail

**Diagnosis**:

```bash
# Check container restart count
docker ps -a | grep flaresolverr

# Check for crash logs
docker logs flaresolverr | grep -i "error\|crash\|fatal"

# Check system resources
free -h
df -h
```

**Solutions**:

1. **Out of memory**:

   ```bash
   # Check available memory
   free -h

   # If low, restart container
   docker restart flaresolverr

   # Consider increasing VM RAM if persistent
   ```

2. **Disk space full**:

   ```bash
   # Check disk space
   df -h /opt/media-stack

   # Clean up if needed
   docker system prune -a
   ```

3. **Chrome crash**:
   - Check logs for "Chrome failed to start"
   - Verify `--no-sandbox` flag is set
   - May need to update FlareSolverr image

4. **Update FlareSolverr**:

   ```bash
   cd /opt/media-stack
   docker compose pull flaresolverr
   docker compose up -d flaresolverr
   ```

### 6. Can't Solve Captcha/Challenge

**Symptoms**:

- FlareSolverr logs show "Challenge solving failed"
- Indexer returns captcha page

**Diagnosis**:

```bash
# Check logs for challenge details
docker logs flaresolverr | grep -i "challenge\|captcha"
```

**Solutions**:

1. **Challenge type unsupported**:
   - FlareSolverr handles Cloudflare JS challenges
   - Does NOT handle reCAPTCHA or interactive captchas
   - If indexer requires manual captcha, FlareSolverr can't help

2. **Cloudflare updated protection**:
   - Update FlareSolverr to latest version
   - Check GitHub issues for known problems

3. **IP banned/rate-limited**:
   - Indexer may have rate limits
   - Wait 15-30 minutes before retrying
   - Consider using VPN (Gluetun) for different IP

4. **Use alternative indexer**:
   - If specific indexer consistently fails
   - Find alternative indexer without Cloudflare

## Testing FlareSolverr

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

1. Prowlarr → Settings → Indexers → FlareSolverr
2. Click **Test**
3. Should return success message

### Integration Test

1. Find a Cloudflare-protected indexer in Prowlarr
2. Run a search in Prowlarr
3. Watch FlareSolverr logs: `docker logs flaresolverr -f`
4. Should see request, challenge solving, and response

## Performance Optimization

### Already Applied Optimizations

The deployment includes optimized Chrome arguments:

```yaml
environment:
  - CHROME_ARGS=--no-sandbox,--disable-dev-shm-usage
```

- `--no-sandbox`: Allows Chrome to run in Docker
- `--disable-dev-shm-usage`: Prevents shared memory issues

### Additional Tuning (Optional)

**Reduce logging** (if logs too verbose):

```yaml
environment:
  - LOG_LEVEL=warn  # Only warnings and errors
  - LOG_HTML=false  # Don't log HTML responses
```

**Increase browser instances** (if many simultaneous requests):

```yaml
environment:
  - CHROME_ARGS=--no-sandbox,--disable-dev-shm-usage,--max-processes=5
```

## Logs and Debugging

### Enable Debug Logging

```yaml
environment:
  - LOG_LEVEL=debug
  - LOG_HTML=true  # Log HTML responses (very verbose!)
```

Restart: `docker restart flaresolverr`

### Log Patterns

**Successful Request**:

```text
[INFO] Solving challenge for https://example-indexer.com
[INFO] Challenge solved successfully in 15s
```

**Failed Request**:

```text
[ERROR] Challenge solving failed: Timeout
[ERROR] Failed to bypass Cloudflare
```

**Chrome Crash**:

```text
[FATAL] Chrome crashed or failed to start
```

## When to Use FlareSolverr

**Use FlareSolverr for**:

- Indexers with Cloudflare "Checking your browser" page
- Indexers with DDoS-GUARD protection
- Indexers that fail with "403 Forbidden"

**Don't need FlareSolverr for**:

- Indexers without protection (most private trackers)
- Indexers with simple username/password auth
- Indexers that work fine in Prowlarr without it

## Alternative Solutions

If FlareSolverr doesn't work:

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

## Update FlareSolverr

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Pull latest image
cd /opt/media-stack
docker compose pull flaresolverr
docker compose up -d flaresolverr

# Verify version
docker logs flaresolverr | grep "version"
```

## See Also

- [Prowlarr Troubleshooting](prowlarr.md)
- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Common Issues](common-issues.md)
- [VPN/Gluetun Configuration](../configuration/vpn-gluetun.md)

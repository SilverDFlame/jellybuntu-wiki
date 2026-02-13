# Prowlarr Troubleshooting

Troubleshooting guide for Prowlarr indexer management issues.

> **IMPORTANT**: Prowlarr runs as a **rootless Podman container with Quadlet** on the media-services VM (192.168.30.13).
> Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Quick Checks

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check service status
systemctl --user status prowlarr

# View logs
journalctl --user -u prowlarr -f

# Check container is running
podman ps | grep prowlarr

# View container logs
podman logs prowlarr --tail 100

# Check web UI access
curl http://localhost:9696

# Verify connectivity to download clients
curl http://download-clients.discus-moth.ts.net:8080
curl http://download-clients.discus-moth.ts.net:8081
```

## Common Issues

### 1. Can't Access Prowlarr Web UI

**Symptoms**:

- Connection refused on port 9696
- Timeout accessing http://media-services.discus-moth.ts.net:9696

**Diagnosis**:

```bash
# Check service status
systemctl --user status prowlarr

# Check container status
podman ps -a | grep prowlarr

# Check logs
podman logs prowlarr --tail 50

# Check port
ss -tlnp | grep 9696
```

**Solutions**:

1. **Service not running**:

   ```bash
   systemctl --user start prowlarr
   systemctl --user enable prowlarr
   ```

2. **Firewall blocking**:

   ```bash
   sudo ufw allow from 192.168.30.0/24 to any port 9696
   sudo ufw allow from 100.64.0.0/10 to any port 9696
   sudo ufw reload
   ```

3. **Quadlet configuration issue**:

   ```bash
   # Check Quadlet file
   cat ~/.config/containers/systemd/prowlarr.container

   # Reload and restart
   systemctl --user daemon-reload
   systemctl --user restart prowlarr
   ```

### 2. Indexers Failing to Connect

**Symptoms**:

- Indexer test fails
- Error: "Unable to connect to indexer"
- Search returns no results

**Diagnosis**:

```bash
# Test from container
podman exec prowlarr wget -O- https://example-indexer.com

# Check Byparr if using Cloudflare bypass
systemctl --user status byparr
podman ps | grep byparr
curl http://localhost:8191
```

**Solutions**:

1. **Indexer down or blocking**:
   - Check indexer website directly
   - Verify API keys/credentials
   - Check indexer status page

2. **Cloudflare protection**:
   - Ensure Byparr is running
   - Configure indexer to use Byparr
   - Settings > Indexers > [Indexer] > FlareSolverr: `http://byparr:8191`

3. **Rate limiting**:
   - Reduce search frequency
   - Disable/enable indexer to reset
   - Wait for rate limit to expire

### 3. App Sync Failures (Sonarr/Radarr)

**Symptoms**:

- Indexers don't appear in Sonarr/Radarr
- Sync shows failed
- Error: "Unable to add application"

**Diagnosis**:

```bash
# Test connectivity between services (all on same VM)
curl http://localhost:8989  # Sonarr
curl http://localhost:7878  # Radarr

# Check API connectivity
curl http://localhost:8989/api/v3/health
curl http://localhost:7878/api/v3/health
```

**Solutions**:

1. **Incorrect app configuration**:
   - Settings > Apps > Add Application
   - **Prowlarr Server**: `http://localhost:9696`
   - **Sonarr Server**: `http://localhost:8989`
   - **Radarr Server**: `http://localhost:7878`
   - Use localhost since all services are on same VM

2. **Wrong API keys**:
   - Get Sonarr API: Settings > General > Security > API Key
   - Get Radarr API: Settings > General > Security > API Key
   - Update in Prowlarr > Settings > Apps

3. **Force full sync**:
   - Settings > Apps > [App] > Full Sync

### 4. Search Returns No Results

**Symptoms**:

- Manual search returns nothing
- Sonarr/Radarr searches via Prowlarr fail
- "No results found" errors

**Diagnosis**:

- Check indexer status in Prowlarr > Indexers
- View search logs: System > Logs > Files
- Test individual indexers

**Solutions**:

1. **All indexers disabled**:
   - Indexers > Enable at least one indexer
   - Test indexer connectivity

2. **Search query issues**:
   - Try simpler search terms
   - Check indexer supports the content type
   - Verify indexer categories are configured

3. **Indexer rate limits**:
   - Check System > Tasks > Check Health
   - Wait for rate limits to reset
   - Reduce search frequency

### 5. Download Client Connection Issues

**Symptoms**:

- Can't add download clients
- Test fails with connection error
- Downloads don't start

**Diagnosis**:

```bash
# Test connectivity to download-clients VM
ping -c 3 download-clients.discus-moth.ts.net

# Test qBittorrent
curl http://download-clients.discus-moth.ts.net:8080

# Test SABnzbd
curl http://download-clients.discus-moth.ts.net:8081
```

**Solutions**:

1. **Wrong hostname**:
   - Use `download-clients.discus-moth.ts.net` or `192.168.30.14`
   - NOT `localhost` (download clients are on different VM)

2. **Correct download client settings**:
   - **qBittorrent**:
     - Host: `download-clients.discus-moth.ts.net`
     - Port: `8080`
     - Username: From qBittorrent settings
     - Password: From qBittorrent settings

   - **SABnzbd**:
     - Host: `download-clients.discus-moth.ts.net`
     - Port: `8081`
     - API Key: From SABnzbd Config > General > Security

### 6. Byparr Issues

**Symptoms**:

- Cloudflare-protected indexers fail
- Timeout errors on protected sites
- FlareSolverr connection errors in Prowlarr

**Diagnosis**:

```bash
# Check Byparr is running
systemctl --user status byparr
podman ps | grep byparr

# View logs
journalctl --user -u byparr -f
podman logs byparr --tail 50

# Test Byparr
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd":"request.get","url":"http://example.com"}'
```

**Solutions**:

1. **Byparr not running**:

   ```bash
   systemctl --user start byparr
   systemctl --user enable byparr
   ```

2. **Wrong Byparr URL in indexer**:
   - Edit indexer > FlareSolverr URL: `http://byparr:8191`
   - All services on same VM

3. **Byparr timeout**:
   - Increase timeout in indexer settings
   - Restart Byparr: `systemctl --user restart byparr`

## Advanced Troubleshooting

### Database Issues

```bash
# Stop Prowlarr
systemctl --user stop prowlarr

# Backup database
cp -r ~/.config/prowlarr ~/.config/prowlarr.bak

# Restart
systemctl --user start prowlarr
journalctl --user -u prowlarr -f
```

### Reset Indexers

```bash
# Backup config first
systemctl --user stop prowlarr

# Remove indexer database (keeps settings)
rm ~/.config/prowlarr/prowlarr.db-shm
rm ~/.config/prowlarr/prowlarr.db-wal

# Restart
systemctl --user start prowlarr
```

### Container Debugging

```bash
# Enter container
podman exec -it prowlarr /bin/bash

# Test connectivity
ping -c 3 192.168.30.14
wget -O- http://192.168.30.14:8080

# Test HTTP
wget -O- http://localhost:8989/api/v3/health
wget -O- http://localhost:8191

# Exit
exit
```

### Check Quadlet Configuration

```bash
# View Quadlet file
cat ~/.config/containers/systemd/prowlarr.container

# Regenerate systemd units
systemctl --user daemon-reload

# Check generated service
systemctl --user cat prowlarr
```

## Getting Help

If issues persist:

1. **Collect logs**:

   ```bash
   journalctl --user -u prowlarr -n 500 --no-pager > /tmp/prowlarr.log
   podman logs prowlarr --tail 500 >> /tmp/prowlarr.log
   ```

2. **Check Prowlarr Wiki**:
   - https://wiki.servarr.com/prowlarr

3. **Community Support**:
   - Discord: https://discord.gg/prowlarr
   - Reddit: r/prowlarr
   - GitHub: https://github.com/Prowlarr/Prowlarr

## See Also

- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Byparr Troubleshooting](byparr.md)
- [Download Clients Troubleshooting](download-clients.md)
- [Podman Troubleshooting](podman.md)
- [Networking Troubleshooting](networking.md)

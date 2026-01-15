# Prowlarr Troubleshooting

Troubleshooting guide for Prowlarr indexer management issues.

## Quick Checks

```bash
# Check container is running
docker ps | grep prowlarr

# View logs
docker logs prowlarr --tail 100

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
# Check container status
docker ps -a | grep prowlarr

# Check logs
docker logs prowlarr --tail 50

# Check port
sudo netstat -tulpn | grep 9696
```

**Solutions**:

1. **Container not running**:

   ```bash
   cd /opt/media-stack
   docker compose up -d prowlarr
   ```

2. **Firewall blocking**:

   ```bash
   sudo ufw allow from 192.168.0.0/24 to any port 9696
   sudo ufw allow from 100.64.0.0/10 to any port 9696
   sudo ufw reload
   ```

### 2. Indexers Failing to Connect

**Symptoms**:

- Indexer test fails
- Error: "Unable to connect to indexer"
- Search returns no results

**Diagnosis**:

```bash
# Test from container
docker exec prowlarr wget -O- https://example-indexer.com

# Check Flaresolverr if using Cloudflare bypass
docker ps | grep flaresolverr
curl http://localhost:8191
```

**Solutions**:

1. **Indexer down or blocking**:
   - Check indexer website directly
   - Verify API keys/credentials
   - Check indexer status page

2. **Cloudflare protection**:
   - Ensure Flaresolverr is running
   - Configure indexer to use Flaresolverr
   - Settings > Indexers > [Indexer] > FlareSolverr: `http://flaresolverr:8191`

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
# Test connectivity between containers
docker exec prowlarr ping sonarr
docker exec prowlarr ping radarr

# Check API connectivity
docker exec prowlarr wget -O- http://sonarr:8989/api/v3/health
docker exec prowlarr wget -O- http://radarr:7878/api/v3/health
```

**Solutions**:

1. **Incorrect app configuration**:
   - Settings > Apps > Add Application
   - **Prowlarr Server**: `http://prowlarr:9696` (not localhost!)
   - **Sonarr Server**: `http://sonarr:8989`
   - **Radarr Server**: `http://radarr:7878`
   - Use container names, not IPs or hostnames

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
# Test connectivity
docker exec prowlarr ping download-clients.discus-moth.ts.net

# Test qBittorrent
docker exec prowlarr wget -O- http://download-clients.discus-moth.ts.net:8080

# Test SABnzbd
docker exec prowlarr wget -O- http://download-clients.discus-moth.ts.net:8081
```

**Solutions**:

1. **Wrong hostname**:
   - Use `download-clients.discus-moth.ts.net` or `192.168.0.14`
   - NOT `localhost` or container names

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

### 6. Flaresolverr Issues

**Symptoms**:

- Cloudflare-protected indexers fail
- Timeout errors on protected sites
- FlareSolverr connection errors

**Diagnosis**:

```bash
# Check Flaresolverr is running
docker ps | grep flaresolverr

# View logs
docker logs flaresolverr --tail 50

# Test Flaresolverr
curl -X POST http://localhost:8191/v1 \
  -H "Content-Type: application/json" \
  -d '{"cmd":"request.get","url":"http://example.com"}'
```

**Solutions**:

1. **Flaresolverr not running**:

   ```bash
   cd /opt/media-stack
   docker compose up -d flaresolverr
   ```

2. **Wrong Flaresolverr URL in indexer**:
   - Edit indexer > FlareSolverr URL: `http://flaresolverr:8191`
   - NOT `localhost` or IP address

3. **Flaresolverr timeout**:
   - Increase timeout in indexer settings
   - Restart Flaresolverr: `docker compose restart flaresolverr`

## Advanced Troubleshooting

### Database Issues

```bash
# Stop Prowlarr
docker compose -f /opt/media-stack/docker-compose.yml stop prowlarr

# Backup database
cp -r /opt/media-stack/prowlarr/config /opt/media-stack/prowlarr/config.bak

# Restart
docker compose -f /opt/media-stack/docker-compose.yml up -d prowlarr
docker logs prowlarr -f
```

### Reset Indexers

```bash
# Backup config first
docker compose stop prowlarr

# Remove indexer database (keeps settings)
rm /opt/media-stack/prowlarr/config/prowlarr.db-shm
rm /opt/media-stack/prowlarr/config/prowlarr.db-wal

# Restart
docker compose up -d prowlarr
```

### Container Network Debugging

```bash
# Enter container
docker exec -it prowlarr /bin/bash

# Test connectivity
ping sonarr
ping radarr
ping flaresolverr
ping download-clients.discus-moth.ts.net

# Test HTTP
wget -O- http://sonarr:8989/api/v3/health
wget -O- http://flaresolverr:8191
```

## Getting Help

If issues persist:

1. **Collect logs**:

   ```bash
   docker logs prowlarr --tail 500 > /tmp/prowlarr.log
   ```

2. **Check Prowlarr Wiki**:
   - https://wiki.servarr.com/prowlarr

3. **Community Support**:
   - Discord: https://discord.gg/prowlarr
   - Reddit: r/prowlarr
   - GitHub: https://github.com/Prowlarr/Prowlarr

## See Also

- [Sonarr/Radarr Troubleshooting](sonarr-radarr.md)
- [Download Clients Troubleshooting](download-clients.md)
- [Podman Troubleshooting](podman.md)
- [Networking Troubleshooting](networking.md)

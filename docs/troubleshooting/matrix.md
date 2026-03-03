# Matrix/Synapse Troubleshooting

Troubleshooting guide for Matrix/Synapse communication server issues on the Elysium VM.

> **IMPORTANT**: Matrix services run as **rootless Podman containers with Quadlet** on the
> elysium VM (192.168.40.21). Use `systemctl --user` and `journalctl --user` commands.

## Quick Checks

```bash
# SSH to elysium VM
ssh -i ~/.ssh/ansible_homelab ansible@elysium.discus-moth.ts.net

# Check all container statuses
systemctl --user status postgres synapse livekit lk-jwt-service coturn synapse-admin

# List running containers (expect 6)
podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test Synapse health endpoint
curl -s http://localhost:8008/_matrix/client/versions

# Check pod status
podman pod ps

# View recent Synapse logs
journalctl --user -u synapse -n 50 --no-pager
```

## Common Issues

### 1. Synapse Won't Start

**Symptoms**:

- Synapse container exits immediately or enters restart loop
- Error in logs: `Error reading signing key` or database connection failures
- `curl http://localhost:8008/_matrix/client/versions` returns connection refused

**Diagnosis**:

```bash
# Check Synapse service status
systemctl --user status synapse

# Check Synapse logs for startup errors
journalctl --user -u synapse -n 100 --no-pager

# Check if PostgreSQL is running (Synapse depends on it)
systemctl --user status postgres
journalctl --user -u postgres -n 50 --no-pager

# Verify signing key exists and is not empty
ls -la /opt/matrix/synapse/data/elysium.discus-moth.ts.net.signing.key

# Check homeserver.yaml syntax
podman exec synapse python3 -c "import yaml; yaml.safe_load(open('/data/homeserver.yaml'))"
```

**Solutions**:

1. **PostgreSQL not running** (most common):

   ```bash
   # Start PostgreSQL first
   systemctl --user start postgres

   # Wait a few seconds, then start Synapse
   systemctl --user start synapse
   ```

2. **Empty or missing signing key**:

   ```bash
   # Check key file size
   stat /opt/matrix/synapse/data/elysium.discus-moth.ts.net.signing.key

   # If 0 bytes, remove it so Synapse regenerates on next start
   rm /opt/matrix/synapse/data/elysium.discus-moth.ts.net.signing.key
   systemctl --user restart synapse

   # If missing entirely, regenerate via bootstrap
   # Run from control node:
   # ./bin/runtime/ansible-run.sh playbooks/utility/matrix-bootstrap.yml
   ```

   > **Warning**: Never delete a non-empty signing key. It is the server's cryptographic identity.
   > Only remove 0-byte files left by interrupted startups.

3. **homeserver.yaml syntax error**:

   ```bash
   # Check for YAML errors
   journalctl --user -u synapse -n 100 --no-pager | grep -i "error\|yaml\|config"

   # Redeploy configuration from Ansible
   # Run from control node:
   # ./bin/runtime/ansible-run.sh playbooks/services/matrix.yml
   ```

4. **Data directory ownership**:

   ```bash
   # Synapse runs as UID 991 inside the container
   # Check ownership of data directory
   ls -la /opt/matrix/synapse/data/

   # Fix ownership if needed (requires podman unshare)
   podman unshare chown -R 991:991 /opt/matrix/synapse/data/
   systemctl --user restart synapse
   ```

### 2. LiveKit Connection Failures (No Voice/Video)

**Symptoms**:

- Element Call shows "Connecting..." indefinitely
- Voice/video calls don't establish
- "Failed to connect to LiveKit" errors in Element

**Diagnosis**:

```bash
# Check LiveKit service
systemctl --user status livekit

# Check LiveKit logs
journalctl --user -u livekit -n 50 --no-pager

# Check lk-jwt-service (issues JWTs for LiveKit auth)
systemctl --user status lk-jwt-service
journalctl --user -u lk-jwt-service -n 50 --no-pager

# Test LiveKit HTTP API
curl -s http://localhost:7880

# Check if WebRTC TCP port is listening
ss -tlnp | grep 7881

# Verify UDP media ports are open
sudo ufw status | grep -E "50000|7880|7881"
```

**Solutions**:

1. **LiveKit not running**:

   ```bash
   systemctl --user restart livekit
   ```

2. **lk-jwt-service not running** (Element Call can't get auth tokens):

   ```bash
   systemctl --user restart lk-jwt-service

   # Check if it can reach Synapse's OpenID endpoint
   curl -s http://localhost:8008/_matrix/federation/v1/openid/userinfo
   # Expected: 401 (unauthorized) — that's OK, it means the endpoint is reachable
   ```

3. **Firewall blocking media ports**:

   ```bash
   # Verify all required ports are open
   sudo ufw status | grep -E "7880|7881|50000"

   # If missing, add rules (should be managed by Ansible):
   sudo ufw allow 7880/tcp comment "LiveKit HTTP API"
   sudo ufw allow 7881/tcp comment "LiveKit WebRTC TCP"
   sudo ufw allow 50000:50060/udp comment "LiveKit media range"
   ```

4. **Well-known discovery not working** (Element can't find LiveKit):

   ```bash
   # Test well-known endpoint
   curl -s http://localhost:8008/.well-known/matrix/client | python3 -m json.tool

   # Should include org.matrix.msc4143.rtc_foci with livekit_service_url
   # If missing, check homeserver.yaml has extra_well_known_client_content configured
   ```

### 3. coturn Issues (TURN/STUN Failures)

**Symptoms**:

- Voice/video works on local network but not remotely
- WebRTC connections time out for remote users
- "TURN server unreachable" in client debug logs

**Diagnosis**:

```bash
# Check coturn service (runs on host network, NOT in pod)
systemctl --user status coturn

# Check coturn logs
journalctl --user -u coturn -n 50 --no-pager

# Verify TURN port is listening
ss -tulnp | grep 3478

# Check relay port range
sudo ufw status | grep -E "49152|3478"

# Test TURN connectivity (from client machine)
# curl -v telnet://elysium.discus-moth.ts.net:3478
```

**Solutions**:

1. **coturn not running**:

   ```bash
   systemctl --user restart coturn
   ```

2. **TURN auth secret mismatch** (coturn and Synapse must share the same secret):

   ```bash
   # Logs will show authentication failures
   journalctl --user -u coturn -n 100 --no-pager | grep -i "auth\|secret\|denied"

   # Redeploy configs to ensure secrets match
   # Run from control node:
   # ./bin/runtime/ansible-run.sh playbooks/services/matrix.yml
   ```

3. **Firewall blocking TURN/relay ports**:

   ```bash
   # Verify ports are open
   sudo ufw status | grep -E "3478|49152"

   # If missing:
   sudo ufw allow 3478/tcp comment "TURN TCP"
   sudo ufw allow 3478/udp comment "TURN UDP"
   sudo ufw allow 49152:49200/udp comment "coturn relay range"
   ```

4. **Tailscale subnet routing not advertised**:

   ```bash
   # Remote clients need to reach 192.168.40.21 via Tailscale
   # Verify subnet routes are advertised from the gateway node
   tailscale status

   # If relay candidates on 192.168.40.21 are unreachable,
   # check that 192.168.40.0/24 is advertised and approved in Tailscale admin
   ```

### 4. Database Issues

**Symptoms**:

- Synapse logs show `psycopg2.OperationalError` or connection refused on port 5432
- Rooms/messages fail to load
- "Internal server error" responses from Synapse API

**Diagnosis**:

```bash
# Check PostgreSQL status
systemctl --user status postgres

# Check PostgreSQL logs
journalctl --user -u postgres -n 100 --no-pager

# Verify database is accepting connections (from inside the pod)
podman exec postgres pg_isready -h localhost -p 5432 -U synapse

# Check database size
podman exec postgres psql -U synapse -c "SELECT pg_size_pretty(pg_database_size('synapse'));"

# Check for lock issues
podman exec postgres psql -U synapse -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

**Solutions**:

1. **PostgreSQL not running**:

   ```bash
   systemctl --user start postgres

   # Wait for it to be ready
   sleep 5
   podman exec postgres pg_isready -h localhost -p 5432 -U synapse

   # Then restart Synapse
   systemctl --user restart synapse
   ```

2. **Database corruption** (rare):

   ```bash
   # Check PostgreSQL logs for corruption messages
   journalctl --user -u postgres -n 200 --no-pager | grep -i "corrupt\|error\|fatal"

   # If needed, stop and check filesystem
   systemctl --user stop postgres
   ls -la /opt/matrix/postgres/data/
   systemctl --user start postgres
   ```

3. **Connection pool exhausted**:

   ```bash
   # Synapse uses cp_min=5, cp_max=10 connections
   # Check active connections
   podman exec postgres psql -U synapse -c "SELECT count(*) FROM pg_stat_activity;"

   # Restart Synapse to reset connection pool
   systemctl --user restart synapse
   ```

### 5. Federation Issues

Federation is **intentionally disabled** on this server. The federation domain whitelist is set
to an empty list (`federation_domain_whitelist: []`).

If you see federation-related errors in logs, they are expected and can be ignored. The federation
listener resource remains active only so that lk-jwt-service can call Synapse's OpenID userinfo
endpoint for token validation.

### 6. Synapse Admin UI Not Loading

**Symptoms**:

- `http://elysium.discus-moth.ts.net:8080` returns connection refused or blank page
- Admin UI loads but can't connect to Synapse

**Diagnosis**:

```bash
# Check Synapse Admin container
systemctl --user status synapse-admin

# Test port directly
curl -s http://localhost:8080 | head -20

# Check if Synapse is reachable from admin (same pod network)
curl -s http://localhost:8008/_matrix/client/versions
```

**Solutions**:

1. **Container not running**:

   ```bash
   systemctl --user restart synapse-admin
   ```

2. **Admin can't reach Synapse** (pod networking issue):

   ```bash
   # Restart the entire pod
   systemctl --user restart matrix-pod-pod
   ```

## Service Management Commands

### Pod Operations

```bash
# Restart all services in the pod
systemctl --user restart matrix-pod-pod

# Stop all services
systemctl --user stop matrix-pod-pod

# Start all services
systemctl --user start matrix-pod-pod

# Note: coturn is NOT in the pod — manage separately
systemctl --user restart coturn
```

### Individual Container Operations

```bash
# Restart a specific service
systemctl --user restart synapse
systemctl --user restart postgres
systemctl --user restart livekit
systemctl --user restart lk-jwt-service
systemctl --user restart synapse-admin
systemctl --user restart coturn
```

### Log Viewing

```bash
# Follow logs in real-time
journalctl --user -u synapse -f
journalctl --user -u postgres -f
journalctl --user -u livekit -f
journalctl --user -u coturn -f
journalctl --user -u lk-jwt-service -f
journalctl --user -u synapse-admin -f

# View last N lines
journalctl --user -u synapse -n 200 --no-pager

# Search logs for errors
journalctl --user -u synapse --no-pager | grep -i "error\|exception\|fatal"
```

### Health Checks

```bash
# Synapse API
curl -s http://localhost:8008/_matrix/client/versions | python3 -m json.tool

# LiveKit API
curl -s http://localhost:7880

# PostgreSQL
podman exec postgres pg_isready -h localhost -p 5432 -U synapse

# Container count (should be 6)
podman ps --format "{{.Names}}" | wc -l
```

## Advanced Troubleshooting

### Collect Diagnostic Information

```bash
# All container statuses
podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Pod status
podman pod ps

# System resources
free -h
df -h /opt/matrix

# Network connections
ss -tlnp | grep -E "8008|7880|7881|3478|5432|8080|8880"
```

### Redeploy from Ansible

If configuration is out of sync, redeploy from the control node:

```bash
# Redeploy all Matrix services
./bin/runtime/ansible-run.sh playbooks/services/matrix.yml

# Re-run bootstrap (safe to run multiple times)
./bin/runtime/ansible-run.sh playbooks/utility/matrix-bootstrap.yml
```

## See Also

- [Matrix Setup](../configuration/matrix-setup.md) — Full deployment guide
- [Networking Troubleshooting](networking.md) — Tailscale and firewall issues
- [Podman Troubleshooting](podman.md) — Container runtime issues
- [Common Issues](common-issues.md) — Cross-service problems
- [Service Endpoints](../configuration/service-endpoints.md) — Connection details

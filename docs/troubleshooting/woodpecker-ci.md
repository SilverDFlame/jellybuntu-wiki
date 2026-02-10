# Woodpecker CI Troubleshooting

Troubleshooting guide for Woodpecker CI issues.

> **Note**: Woodpecker CI runs as **rootless Podman with Quadlet** (systemd user services). Use `systemctl --user` and
> `journalctl --user` commands.

## Quick Checks

```bash
# SSH to Woodpecker VM
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net

# Check service status
systemctl --user status woodpecker-server woodpecker-agent

# View server logs
journalctl --user -u woodpecker-server -f

# View agent logs
journalctl --user -u woodpecker-agent -f

# Check containers running
podman ps

# Verify Tailscale Funnel
tailscale funnel status
```

## Common Issues

### 1. Web UI Not Accessible

**Symptoms**:

- Browser shows "Connection refused" or times out
- Cannot reach https://automation.discus-moth.ts.net

**Diagnosis**:

```bash
# Check server is running
systemctl --user status woodpecker-server

# Check port is listening
ss -tlnp | grep 8000

# Check Tailscale Funnel status
tailscale funnel status
```

**Solutions**:

1. **Server not running**:

   ```bash
   systemctl --user start woodpecker-server
   journalctl --user -u woodpecker-server -n 50
   ```

2. **Funnel not enabled**:

   ```bash
   tailscale funnel 443
   ```

3. **Firewall blocking**:

   ```bash
   sudo ufw status
   sudo ufw allow 8000/tcp
   ```

### 2. GitHub Login Fails

**Symptoms**:

- OAuth callback returns error
- "Invalid client_id" or "redirect_uri mismatch"

**Diagnosis**:

```bash
# Check OAuth configuration
journalctl --user -u woodpecker-server | grep -i oauth
```

**Solutions**:

1. **Verify OAuth App settings** in GitHub:
   - Homepage URL: `https://automation.discus-moth.ts.net`
   - Callback URL: `https://automation.discus-moth.ts.net/authorize`

2. **Check vault secrets**:

   ```bash
   sops -d group_vars/all.sops.yaml | grep woodpecker_github
   ```

3. **Verify environment variables**:

   ```bash
   podman inspect woodpecker-server | grep -A5 GITHUB
   ```

### 3. Webhooks Not Triggering Builds

**Symptoms**:

- Push/PR doesn't start pipeline
- GitHub webhook shows delivery failures

**Diagnosis**:

1. Check GitHub webhook delivery history (repository Settings > Webhooks)
2. Look for response codes (should be 200)

```bash
# Check server logs for webhook events
journalctl --user -u woodpecker-server | grep -i webhook
```

**Solutions**:

1. **Webhook URL incorrect**:
   - Correct URL: `https://automation.discus-moth.ts.net/hook`
   - Content type: `application/json`

2. **Webhook secret mismatch**:

   ```bash
   sops -d group_vars/all.sops.yaml | grep webhook_secret
   ```

   Ensure GitHub webhook secret matches vault value.

3. **Funnel not working**:

   ```bash
   # Test from external network
   curl -I https://automation.discus-moth.ts.net/healthz
   ```

4. **Repository not activated**:
   - Login to Woodpecker UI
   - Verify repository is activated and synced

### 4. Agent Won't Connect to Server

**Symptoms**:

- Agent container restarts repeatedly
- "connection refused" in agent logs

**Diagnosis**:

```bash
journalctl --user -u woodpecker-agent -n 50
```

**Solutions**:

1. **Agent secret mismatch**:

   ```bash
   # Both containers must have same secret
   sops -d group_vars/all.sops.yaml | grep agent_secret
   ```

2. **Server not ready**:

   ```bash
   # Restart in correct order
   systemctl --user restart woodpecker-server
   sleep 10
   systemctl --user restart woodpecker-agent
   ```

3. **Network issue**:

   ```bash
   # Agent connects via container network
   podman network inspect woodpecker-net
   ```

### 5. Pipeline Fails: Permission Denied

**Symptoms**:

- Build fails with "permission denied" errors
- Cannot mount volumes

**Diagnosis**:

```bash
journalctl --user -u woodpecker-agent | grep -i permission
```

**Solutions**:

1. **Trusted mode not enabled**:
   - Repository Settings > General > Enable "Trusted"
   - Required for volume mounts

2. **Podman socket permissions**:

   ```bash
   ls -la /run/user/$(id -u)/podman/podman.sock
   ```

3. **SELinux issues**:

   ```bash
   # Check for denials
   sudo ausearch -m avc -ts recent
   ```

### 6. Pipeline Fails: Image Pull Error

**Symptoms**:

- "image not found" or "pull access denied"
- Registry authentication failures

**Diagnosis**:

```bash
journalctl --user -u woodpecker-agent | grep -i pull
```

**Solutions**:

1. **Nexus registry not accessible**:

   ```bash
   curl -I http://nas.discus-moth.ts.net:5001/v2/
   ```

2. **Network configuration**:
   - Ensure `WOODPECKER_BACKEND_DOCKER_NETWORK` is set to `woodpecker-net`
   - Pipeline containers need network access

3. **Image tag doesn't exist**:
   - Verify image exists in Nexus registry
   - Check for typos in `.woodpecker/*.yml`

### 7. Database Corruption

**Symptoms**:

- Server fails to start
- SQLite errors in logs

**Diagnosis**:

```bash
journalctl --user -u woodpecker-server | grep -i sqlite
ls -la /opt/woodpecker/woodpecker-server/
```

**Solutions**:

1. **Backup and recreate**:

   ```bash
   systemctl --user stop woodpecker-server
   mv /opt/woodpecker/woodpecker-server/woodpecker.db \
      /opt/woodpecker/woodpecker-server/woodpecker.db.bak
   systemctl --user start woodpecker-server
   ```

   Note: This loses build history. Re-sync repositories after restart.

2. **Restore from backup** (if available):

   ```bash
   cp /mnt/nfs/backups/woodpecker.db /opt/woodpecker/woodpecker-server/
   systemctl --user restart woodpecker-server
   ```

### 8. Builds Stuck in Queue

**Symptoms**:

- Builds show "pending" indefinitely
- No agent picking up work

**Diagnosis**:

```bash
# Check agent is connected
journalctl --user -u woodpecker-agent | grep -i connected

# Check agent capacity
journalctl --user -u woodpecker-agent | grep -i workflow
```

**Solutions**:

1. **Agent not connected**: Restart agent (see issue #4)

2. **Max workflows reached**:

   ```bash
   # Default is 4 concurrent workflows
   # Check if workflows are stuck
   podman ps -a | grep woodpecker
   ```

3. **Resource exhaustion**:

   ```bash
   # Check system resources
   free -h
   df -h
   ```

## Service Recovery

### Full Service Restart

```bash
systemctl --user stop woodpecker-agent woodpecker-server
systemctl --user start woodpecker-server
sleep 10
systemctl --user start woodpecker-agent
```

### Redeploy via Ansible

```bash
./bin/runtime/ansible-run.sh playbooks/services/woodpecker-ci.yml
```

### Check Quadlet Configuration

```bash
ls -la ~/.config/containers/systemd/
cat ~/.config/containers/systemd/woodpecker-server.container
```

## Log Locations

| Log Type | Command |
|----------|---------|
| Server logs | `journalctl --user -u woodpecker-server` |
| Agent logs | `journalctl --user -u woodpecker-agent` |
| Container logs | `podman logs woodpecker-server` |
| System logs | `sudo journalctl -u user@1001` |

## Health Checks

### Server Health

```bash
curl http://localhost:8000/healthz
```

### Agent Health

```bash
curl http://localhost:3000/healthz
```

### Full System Check

```bash
# All checks in one
systemctl --user is-active woodpecker-server woodpecker-agent && \
curl -s http://localhost:8000/healthz && \
echo "Woodpecker healthy"
```

## See Also

- [Woodpecker CI Deployment](../deployment/woodpecker-ci.md)
- [Service Endpoints](../configuration/service-endpoints.md)
- [Drift Resolution](../maintenance/drift-resolution.md)

# Woodpecker CI Maintenance Guide

Guide for maintaining Woodpecker CI server and agent including log cleanup, build artifact management, secrets
rotation, and database maintenance.

## Overview

Woodpecker CI is a lightweight continuous integration server running on a dedicated VM (192.168.10.17 / automation.discus-moth.ts.net).

**Access**: http://automation.discus-moth.ts.net:8000

**Components**:

- **Woodpecker Server**: Web UI, API, pipeline orchestration
- **Woodpecker Agent**: Executes pipeline steps in containers
- **Database**: SQLite (embedded in server container)

**Deployment Details**:

- **Container Runtime**: Rootless Podman with Quadlet
- **Data Location**: `/opt/woodpecker/`
- **Configuration**: Environment-based via Quadlet
- **Integration**: Bitbucket Cloud via OAuth

## Routine Maintenance Overview

### Daily Tasks (Automated)

- Pipeline execution and logging
- Build artifact generation
- Container cleanup (failed builds)

### Weekly Tasks (Manual)

- Review build logs for errors
- Check disk space usage
- Verify agent connectivity

### Monthly Tasks (Manual)

- Clean old build logs
- Review and archive completed pipelines
- Check database size
- Review active secrets

### Quarterly Tasks (Manual)

- Rotate secrets and API keys
- Update container images
- Review pipeline configurations
- Backup database

## Log Management

### Understanding Woodpecker Logs

**Log locations**:

- **Server logs**: `journalctl --user -u woodpecker-server`
- **Agent logs**: `journalctl --user -u woodpecker-agent`
- **Build logs**: Stored in SQLite database (accessed via Web UI)

### Build Log Cleanup

Build logs accumulate in the database and can consume significant space over time.

**Check database size**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "du -sh /opt/woodpecker/woodpecker-server/woodpecker.sqlite"
```

**Expected size**:

- New installation: 50-100MB
- After 30 days: 200-500MB
- After 90 days: 500MB-2GB (depending on pipeline frequency)

**Manual log cleanup** (via API):

Woodpecker doesn't have built-in automatic log cleanup. Options:

**Option 1: Delete old pipelines via Web UI**:

1. Navigate to repository → Pipelines
2. Find old completed pipelines (> 90 days)
3. Click pipeline → Settings → Delete

**Option 2: Database vacuum** (reclaim space):

```bash
# Stop server
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user stop woodpecker-server"

# Vacuum database
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "sqlite3 /opt/woodpecker/woodpecker-server/woodpecker.sqlite 'VACUUM;'"

# Restart server
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user start woodpecker-server"
```

**Note**: Vacuum can take 5-15 minutes depending on database size.

### Container Logs

Woodpecker server and agent logs are managed by systemd journal.

**View recent server logs**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --user -u woodpecker-server -n 100"

# Follow logs in real-time
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --user -u woodpecker-server -f"
```

**View agent logs**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --user -u woodpecker-agent -n 100"
```

**Limit journal disk usage** (if logs consume too much space):

```bash
# Check current usage
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --disk-usage"

# Vacuum old logs (keep last 7 days)
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "sudo journalctl --vacuum-time=7d"
```

## Build Artifact Management

### Artifact Storage

Woodpecker doesn't manage artifacts directly - they're typically pushed to external storage (Nexus, S3, etc.).

**For this deployment**:

- **Docker images**: Stored in Nexus Docker registry (nas.discus-moth.ts.net:5000)
- **Build outputs**: Ephemeral (only exist during pipeline execution)

### Kaniko Layer Cache Cleanup

Kaniko builds Docker images and caches layers in Nexus (`docker-kaniko-cache` repository).

**Check cache size**:

1. Navigate to Nexus: http://nas.discus-moth.ts.net:8081
2. Login with admin credentials
3. Browse → docker-kaniko-cache
4. View storage usage

**Clean Kaniko cache** (if too large):

Nexus cleanup policies can be configured to automatically remove old cache layers.

**Manual cleanup via Nexus API**:

```bash
# List Kaniko cache components
curl -u admin:password \
  "http://nas.discus-moth.ts.net:8081/service/rest/v1/components?repository=docker-kaniko-cache"

# Delete specific component (requires component ID from above)
curl -X DELETE -u admin:password \
  "http://nas.discus-moth.ts.net:8081/service/rest/v1/components/{componentId}"
```

**Automated cleanup policy**:

1. Nexus → Repository → docker-kaniko-cache → Cleanup Policies
2. Create policy:
   - **Name**: kaniko-cache-cleanup
   - **Criteria**: Last downloaded > 30 days
   - **Action**: Delete
3. Assign policy to repository
4. Run cleanup task: Administration → Tasks → Execute (cleanup task)

### Docker Image Registry Cleanup

Images built by Woodpecker are pushed to Nexus Docker registry.

**View images**:

1. Nexus → Browse → docker-hosted
2. View all pushed images and tags

**Remove old images**:

1. Navigate to image
2. Click tag → Delete

**Automated cleanup** (recommended):

1. Nexus → Repository → docker-hosted → Cleanup Policies
2. Create policy for old images (e.g., > 90 days, not downloaded recently)

## Secrets Management

Woodpecker stores secrets for pipelines (credentials, API keys, etc.).

**Secrets are encrypted** in the database and accessible only via:

- Woodpecker Web UI (Organization/Repository settings)
- Woodpecker CLI
- Environment variables during pipeline execution

### Review Secrets

**Organization-level secrets**:

1. Woodpecker UI → Organization Settings → Secrets
2. Review all configured secrets
3. Remove unused secrets

**Repository-level secrets**:

1. Navigate to repository → Settings → Secrets
2. Review secrets specific to this repository

**Common secrets to review**:

- Docker registry credentials
- Cloud provider API keys
- SSH keys
- Webhook tokens

### Rotate Secrets

**When to rotate**:

- Quarterly as routine maintenance
- After team member changes
- If secret may have been exposed
- After security incidents

**Rotation process**:

**1. Generate new secret** (example: Docker registry token):

```bash
# Generate new Nexus Docker token via API or Web UI
curl -u admin:password -X POST \
  "http://nas.discus-moth.ts.net:8081/service/rest/v1/security/users/docker-push/change-password" \
  -H "Content-Type: text/plain" \
  -d "new-secure-password"
```

**2. Update secret in Woodpecker**:

1. Woodpecker UI → Repository → Settings → Secrets
2. Find secret (e.g., `docker_password`)
3. Click Edit → Enter new value → Save

**3. Test pipeline** with new secret:

```bash
# Trigger manual pipeline run
# Verify builds succeed with new credentials
```

**4. Revoke old secret**:

```bash
# Disable old credentials in target system (Nexus, cloud provider, etc.)
```

### Backup Secrets

**Secrets cannot be exported directly** from Woodpecker (encrypted in database).

**Recommendation**: Maintain secrets in external secret management system:

- **SOPS**: Encrypted secrets in Git (recommended for this deployment)
- **HashiCorp Vault**: Enterprise secret management
- **AWS Secrets Manager**: Cloud-based secret storage

**Current approach**:

Secrets are defined in [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml) and injected during Woodpecker deployment via Ansible.

**Backup secrets**:

```bash
# Secrets file is already encrypted with SOPS
cp group_vars/all.sops.yaml backups/all.sops.yaml.$(date +%Y%m%d)
```

## Database Maintenance

### Database Backup

Woodpecker uses SQLite for all data (pipelines, secrets, build logs, users).

**Manual backup**:

```bash
# Stop server to ensure consistency
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user stop woodpecker-server"

# Backup database
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "cp /opt/woodpecker/woodpecker-server/woodpecker.sqlite \
   ~/woodpecker-backup-$(date +%Y%m%d).sqlite"

# Restart server
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user start woodpecker-server"

# Download backup
scp -i ~/.ssh/ansible_homelab \
  ansible@automation.discus-moth.ts.net:~/woodpecker-backup-*.sqlite \
  ./backups/
```

**Automated backup via cron** (recommended):

```bash
# Add to crontab on automation VM
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net

# Edit crontab
crontab -e

# Add daily backup at 2 AM (no restart needed for online backup)
0 2 * * * sqlite3 /opt/woodpecker/woodpecker-server/woodpecker.sqlite ".backup /home/ansible/woodpecker-backup-$(date +\%Y\%m\%d).sqlite" && find /home/ansible/woodpecker-backup-*.sqlite -mtime +30 -delete
```

**Online backup** (doesn't require stopping server):

```bash
# Create online backup using SQLite backup command
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "sqlite3 /opt/woodpecker/woodpecker-server/woodpecker.sqlite \
   \".backup /home/ansible/woodpecker-backup-$(date +%Y%m%d).sqlite\""
```

### Database Restore

**From backup**:

```bash
# Stop server
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user stop woodpecker-server"

# Upload backup
scp -i ~/.ssh/ansible_homelab \
  ./backups/woodpecker-backup-YYYYMMDD.sqlite \
  ansible@automation.discus-moth.ts.net:~/

# Restore database
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "cp ~/woodpecker-backup-YYYYMMDD.sqlite \
   /opt/woodpecker/woodpecker-server/woodpecker.sqlite"

# Start server
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user start woodpecker-server"

# Verify restoration
curl -I http://automation.discus-moth.ts.net:8000
```

### Database Optimization

SQLite can become fragmented over time, especially with frequent builds.

**Optimize database** (reclaim space and improve performance):

```bash
# Stop server
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user stop woodpecker-server"

# Analyze and vacuum
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "sqlite3 /opt/woodpecker/woodpecker-server/woodpecker.sqlite 'PRAGMA integrity_check; VACUUM; ANALYZE;'"

# Restart server
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user start woodpecker-server"
```

**Run quarterly** or when database size exceeds 2GB.

### Database Size Monitoring

**Check current size**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "du -h /opt/woodpecker/woodpecker-server/woodpecker.sqlite"
```

**If database is too large** (> 5GB):

1. Clean old build logs (see "Build Log Cleanup")
2. Delete archived pipelines
3. Vacuum database
4. Consider migrating to PostgreSQL (supported by Woodpecker)

## Agent Maintenance

### Agent Health Checks

**Verify agent is connected**:

1. Woodpecker UI → Admin → Agents
2. Agent should show "Connected" status
3. Check last seen timestamp (should be recent)

**Via logs**:

```bash
# Check agent logs for connectivity
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --user -u woodpecker-agent -n 50 | grep -i connected"
```

### Agent Capacity

**Current configuration**: 1 agent, 2 concurrent builds

**Check concurrent build limit**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --user -u woodpecker-agent -n 5 | grep max"
```

**Adjust concurrent builds** (if needed):

Edit Woodpecker agent environment variable `WOODPECKER_MAX_WORKFLOWS` in playbook and redeploy.

### Agent Container Cleanup

Woodpecker agents create containers for each pipeline step. Failed builds can leave orphaned containers.

**List pipeline containers**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "podman ps -a --filter label=io.woodpecker-ci"
```

**Clean orphaned containers**:

```bash
# Remove stopped pipeline containers
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "podman container prune -f --filter label=io.woodpecker-ci"

# Remove unused images (built during pipelines)
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "podman image prune -a -f"
```

**Automate cleanup via cron**:

```bash
# Add to crontab
0 3 * * * podman container prune -f --filter label=io.woodpecker-ci && podman image prune -a -f
```

## Container Updates

Woodpecker server and agent run in containers with pinned versions.

**Current version** (check playbook for latest):

- Woodpecker Server: Pinned version (e.g., `v2.0.0`)
- Woodpecker Agent: Same version as server

### Update Process

**1. Check for new releases**:

- [Woodpecker Releases](https://github.com/woodpecker-ci/woodpecker/releases)
- Review changelog for breaking changes

**2. Backup before update**:

```bash
# Backup database
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "cp /opt/woodpecker/woodpecker-server/woodpecker.sqlite \
   ~/woodpecker-pre-update-$(date +%Y%m%d).sqlite"
```

**3. Update version in playbook**:

```bash
nano playbooks/services/woodpecker-ci.yml

# Update image tags:
containers:
  - name: woodpecker-server
    image: "docker.io/woodpeckerci/woodpecker-server:v2.1.0"
  - name: woodpecker-agent
    image: "docker.io/woodpeckerci/woodpecker-agent:v2.1.0"
```

**4. Re-deploy**:

```bash
./bin/runtime/ansible-run.sh playbooks/services/woodpecker-ci.yml
```

**5. Verify services**:

```bash
# Check service status
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user status woodpecker-server woodpecker-agent"

# Test Web UI
curl -I http://automation.discus-moth.ts.net:8000

# Trigger test pipeline
```

## Health Checks

### Service Status

**Check all Woodpecker services**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user status woodpecker-server woodpecker-agent"
```

**Expected output**:

```text
● woodpecker-server.service
   Loaded: loaded
   Active: active (running) since ...

● woodpecker-agent.service
   Loaded: loaded
   Active: active (running) since ...
```

### Web UI Accessibility

```bash
# Test Web UI
curl -I http://automation.discus-moth.ts.net:8000

# Expected: HTTP 200 OK
```

### Agent Connectivity

1. Woodpecker UI → Admin → Agents
2. Verify agent shows "Connected" status
3. Check "Last seen" timestamp (< 1 minute)

### Pipeline Execution Test

**Trigger manual pipeline**:

1. Navigate to repository in Woodpecker UI
2. Pipelines → New build (manual trigger)
3. Verify pipeline completes successfully
4. Check build logs for errors

## Troubleshooting

### Server Won't Start

**Symptom**: Woodpecker server fails to start after restart

**Solution**:

```bash
# Check logs for error
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --user -u woodpecker-server -n 100"

# Common issues:
# 1. Database corruption
#    - Restore from backup
# 2. Port conflict
#    - Check if port 8000 is in use
# 3. Configuration error
#    - Verify environment variables
```

### Agent Not Connecting

**Symptom**: Agent shows "Disconnected" in Woodpecker UI

**Solution**:

```bash
# Check agent logs
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "journalctl --user -u woodpecker-agent -n 100"

# Verify agent token matches server
# Re-deploy agent with correct token

# Test connectivity to server
curl http://localhost:9000/healthz  # gRPC endpoint
```

### Pipelines Failing to Start

**Symptom**: Pipelines stuck in "Pending" state

**Solution**:

1. Check agent is connected (UI → Admin → Agents)
2. Verify agent has capacity (not at max concurrent builds)
3. Check agent logs for container startup errors
4. Verify Podman socket is accessible: `/run/user/1000/podman/podman.sock`

### Webhook Not Triggering Builds

**Symptom**: Git push doesn't trigger pipeline

**Solution**:

1. **Check Bitbucket webhook configuration**:
   - Repository → Settings → Webhooks
   - Verify URL: `https://<tailscale-funnel-url>/hook`
   - Verify "Push" event is enabled

2. **Check Tailscale Funnel is active**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
     "tailscale funnel status"
   ```

3. **Check server logs for webhook delivery**:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
     "journalctl --user -u woodpecker-server -f | grep hook"
   ```

4. **Test webhook manually**:
   - Bitbucket → Settings → Webhooks → Test connection

### Database Locked Error

**Symptom**: Operations fail with "database is locked" error

**Solution**:

```bash
# Check for multiple server instances
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "podman ps | grep woodpecker"

# Stop all instances
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user stop woodpecker-server"

# Restart cleanly
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net \
  "systemctl --user start woodpecker-server"
```

## Best Practices

### DO

- Backup database before updates
- Clean old build logs quarterly
- Monitor disk space weekly
- Rotate secrets quarterly
- Pin container versions
- Use organization-level secrets for shared credentials
- Test pipelines after updates
- Review agent logs regularly

### DON'T

- Delete database without backup
- Run multiple server instances simultaneously
- Store secrets in plaintext in pipeline files
- Disable webhook signature validation
- Ignore database size growth
- Update server and agent to different versions
- Skip testing after secret rotation

## Maintenance Schedule Summary

### Weekly

- [ ] Check disk space usage
- [ ] Verify agent connectivity
- [ ] Review recent pipeline failures
- [ ] Check for webhook delivery issues

### Monthly

- [ ] Clean old build logs (> 90 days)
- [ ] Review and archive completed pipelines
- [ ] Check database size
- [ ] Review active secrets (remove unused)
- [ ] Prune orphaned containers and images

### Quarterly

- [ ] Rotate secrets and API keys
- [ ] Update container images
- [ ] Vacuum and optimize database
- [ ] Review pipeline configurations
- [ ] Backup database

### Annually

- [ ] Comprehensive security review
- [ ] Review Bitbucket OAuth integration
- [ ] Update Tailscale Funnel configuration
- [ ] Review and optimize cleanup policies

## Reference

### Related Documentation

- [Woodpecker Deployment Guide](../deployment/woodpecker-ci.md) - Initial setup
- [Woodpecker Troubleshooting](../troubleshooting/woodpecker-ci.md) - Detailed troubleshooting
- [Service Endpoints](../configuration/service-endpoints.md) - Access URLs
- [Updates Guide](updates.md) - General update procedures

### External Resources

- [Woodpecker CI Documentation](https://woodpecker-ci.org/docs/) - Official docs
- [Woodpecker GitHub](https://github.com/woodpecker-ci/woodpecker) - Source code and issues
- [SQLite Documentation](https://www.sqlite.org/docs.html) - Database optimization

## Summary

**Key Maintenance Tasks**:

- Weekly disk space monitoring (logs and database)
- Monthly build log cleanup
- Quarterly secret rotation and database optimization
- Regular backups before updates

**Key Commands**:

```bash
# Service status
systemctl --user status woodpecker-server woodpecker-agent

# View logs
journalctl --user -u woodpecker-server -n 100

# Backup database
sqlite3 /opt/woodpecker/woodpecker-server/woodpecker.sqlite \
  ".backup /home/ansible/woodpecker-backup-$(date +%Y%m%d).sqlite"

# Vacuum database
sqlite3 /opt/woodpecker/woodpecker-server/woodpecker.sqlite 'VACUUM;'

# Clean containers
podman container prune -f --filter label=io.woodpecker-ci
podman image prune -a -f
```

**Best Practices**:

- Backup database before major changes
- Monitor disk space weekly
- Rotate secrets quarterly
- Clean build artifacts monthly
- Pin container versions for stability

Your Woodpecker CI stays efficient and reliable!

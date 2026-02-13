# AdGuard Home Maintenance Guide

Guide for maintaining AdGuard Home DNS service including query log management, filter updates, DNS health monitoring,
and performance optimization.

## Overview

AdGuard Home is a network-wide DNS ad blocker and privacy protection service running on the NAS VM.

**Access**: http://nas.discus-moth.ts.net:80

**Credentials**: Stored in vault (`vault_services_admin_username` / `vault_services_admin_password`)

**Key Features**:

- Network-wide ad blocking and tracker prevention
- DNS-over-TLS (DoT) to upstream resolvers
- DNSSEC validation
- Tailscale MagicDNS integration
- Query logging and statistics

**Deployment Details**:

- **Host**: NAS VM (192.168.30.15 / nas.discus-moth.ts.net)
- **Container**: Rootless Podman with Quadlet
- **Data Location**: `/opt/adguard/`
  - Configuration: `/opt/adguard/conf/AdGuardHome.yaml`
  - Working data: `/opt/adguard/work/`

## Routine Maintenance Overview

### Daily Tasks (Automated)

- DNS query processing and logging
- Blocklist queries and caching
- Statistics aggregation

### Weekly Tasks (Manual)

- Review query logs for anomalies
- Check DNS resolution health
- Monitor disk space usage
- Review top blocked domains

### Monthly Tasks (Manual)

- Update blocklists manually (if auto-update disabled)
- Review and prune query logs
- Check filter list health
- Review client statistics

### Quarterly Tasks (Manual)

- Review and adjust retention policies
- Audit blocklists (remove redundant or broken lists)
- Update container image
- Backup configuration

## Query Log Management

### Query Log Overview

AdGuard Home logs all DNS queries for visibility and troubleshooting.

**Current retention**: 90 days (configurable)

**Log location**: `/opt/adguard/work/querylog.json` (rotated automatically)

### Check Query Log Size

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "du -sh /opt/adguard/work/querylog*"
```

**Expected size**:

- 1 week: 10-50MB
- 30 days: 50-200MB
- 90 days: 200-600MB (depending on network size)

**If logs are too large** (> 1GB):

1. Reduce retention period
2. Enable query log filtering
3. Exclude frequent internal queries

### Adjust Query Log Retention

**Via Web UI**:

1. Settings → DNS Settings → Query log settings
2. Change "Query log retention" (default: 90 days)
3. Options: 1 hour, 1 day, 7 days, 30 days, 90 days, 1 year
4. Click "Save"

**Recommended retention**:

- Home network: 7-30 days
- Small office: 30-90 days
- Large network: 90 days (balance between history and storage)

### Manual Query Log Cleanup

**Clear all query logs** (irreversible):

1. Settings → DNS Settings → Query log settings
2. Click "Clear logs" button
3. Confirm deletion
4. Logs are immediately purged

**Via SSH**:

```bash
# Stop AdGuard Home
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl --user stop adguardhome"

# Delete query logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "rm -f /opt/adguard/work/querylog.json*"

# Restart AdGuard Home
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl --user start adguardhome"
```

### Query Log Analysis

**View query log**:

1. Web UI → Query Log
2. Filter by:
   - Client IP
   - Domain name
   - Query type (A, AAAA, etc.)
   - Response status (blocked, allowed, etc.)

**Common analysis tasks**:

**Identify chatty clients**:

1. Dashboard → Top Clients
2. Find devices making excessive queries
3. Investigate application or service causing high query volume

**Find frequently blocked domains**:

1. Dashboard → Top Blocked Domains
2. Review if blocks are intentional
3. Whitelist legitimate domains if needed

**Troubleshoot DNS issues**:

1. Query Log → Filter by client IP
2. Find failed queries (NXDOMAIN, SERVFAIL)
3. Check if domain is incorrectly blocked or upstream DNS issue

## Filter List Maintenance

### Blocklist Overview

AdGuard Home uses multiple blocklists to block ads, trackers, malware, and unwanted content.

**Current configuration**: 9 comprehensive blocklists (~2.2M rules)

**List categories**:

- Base protection (AdGuard DNS Filter)
- Comprehensive protection (OISD, Hagezi, Steven Black)
- Adult content blocking (OISD NSFW, Hagezi Porn)
- Security (Anti-Malware, Block List Project)

### Automatic Filter Updates

Blocklists are updated automatically every 24 hours by default.

**Check update status**:

1. Filters → DNS Blocklists
2. View "Last updated" timestamp for each list
3. Status should show "Success"

**Adjust update frequency**:

1. Settings → DNS Settings → Filters update interval
2. Options: 1-720 hours
3. **Recommended**: 24-48 hours (balance between freshness and load)

### Manual Filter Update

**Update all blocklists immediately**:

1. Filters → DNS Blocklists
2. Click "Update now" button
3. AdGuard Home fetches all lists in parallel
4. Wait for completion (30 seconds to 5 minutes)

**Via SSH** (trigger via API):

```bash
# Not directly supported - use Web UI or restart container
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl --user restart adguardhome"

# Container restart triggers filter refresh
```

### Review and Audit Blocklists

**Monthly review checklist**:

1. **Check update failures**:
   - Filters → DNS Blocklists
   - Look for lists with error status
   - Remove broken lists or find alternative URLs

2. **Review redundancy**:
   - Multiple lists may block the same domains
   - Consider consolidating to fewer, comprehensive lists (e.g., OISD Big)
   - Reduces memory usage and update time

3. **Test for false positives**:
   - Monitor Query Log for legitimate blocked domains
   - Whitelist domains as needed
   - Consider disabling overly aggressive lists

### Add or Remove Blocklists

**Add new blocklist**:

1. Filters → DNS Blocklists
2. Click "Add blocklist" → "Add a custom list"
3. Enter:
   - **Name**: Descriptive name
   - **URL**: Blocklist URL
4. Click "Save"
5. List is fetched immediately

**Remove blocklist**:

1. Filters → DNS Blocklists
2. Find list to remove
3. Click trash icon
4. Confirm deletion
5. Rules are immediately removed

**Recommended blocklists** (see [AdGuard Configuration Guide](../configuration/adguard-home.md#recommended-additional-blocklists))

### Custom Filtering Rules

Custom rules allow fine-grained control beyond blocklists.

**View custom rules**:

1. Filters → Custom filtering rules
2. Shows all manual block/allow rules

**Common custom rules**:

**Whitelist domain**:

```text
@@||example.com^
```

**Whitelist with high priority**:

```text
@@||example.com^$important
```

**Block specific domain**:

```text
||ads.example.com^
```

**Block subdomain only**:

```text
|subdomain.example.com^
```

**Maintenance**:

- Review custom rules quarterly
- Remove obsolete rules
- Document reason for each rule (add comment with `! Comment`)

## DNS Health Monitoring

### Verify DNS Resolution

**Test DNS resolution** from AdGuard Home:

```bash
# Query via AdGuard Home
dig @nas.discus-moth.ts.net google.com

# Expected: ANSWER section with IP address
```

**Test from client device**:

```bash
# Query AdGuard Home (if configured as DNS server)
dig google.com

# Check which DNS server is being used
nslookup google.com

# Should show nas.discus-moth.ts.net or 100.65.73.89
```

### Upstream DNS Health

AdGuard Home uses multiple upstream DNS servers for redundancy.

**Current upstreams**:

1. Tailscale MagicDNS: `100.100.100.100` (for `*.ts.net`)
2. Quad9 DoT: `tls://dns.quad9.net`
3. Cloudflare DoT: `tls://1dot1dot1dot1.cloudflare-dns.com`

**Test upstream health**:

1. Settings → DNS Settings → Upstream DNS servers
2. Click "Test upstreams" button
3. All upstreams should show "OK"

**If upstream fails**:

- Temporary outage (wait and retry)
- Network connectivity issue (check internet connection)
- Upstream DNS changed endpoints (update URL)

### DNSSEC Validation

DNSSEC validates DNS responses to prevent spoofing.

**Check DNSSEC status**:

1. Settings → DNS Settings
2. Verify "DNSSEC" is enabled (checked)

**Test DNSSEC validation**:

```bash
# Test DNSSEC-signed domain
dig @nas.discus-moth.ts.net dnssec-failed.org

# Should return SERVFAIL (validation failed)
```

**If DNSSEC is broken**:

- Check upstream DNS supports DNSSEC
- Verify system time is accurate (DNSSEC is time-sensitive)
- Review AdGuard Home logs for validation errors

### Performance Monitoring

**Check query response time**:

1. Dashboard → Average processing time
2. **Target**: < 50ms
3. **Current**: ~33ms (excellent)

**If response time is high (> 100ms)**:

1. Check upstream DNS latency (Settings → Test upstreams)
2. Reduce number of blocklists (fewer rules = faster lookups)
3. Check NAS CPU/memory usage
4. Verify network latency to upstream servers

### Cache Performance

AdGuard Home caches DNS responses to improve performance.

**Current cache settings**:

- **Cache size**: 4MB (default)
- **Optimistic caching**: Enabled (serves stale cache while updating)

**Verify cache is working**:

1. Query a domain twice in quick succession
2. Second query should be faster (cache hit)

**Adjust cache size** (if needed):

1. Settings → DNS Settings → Cache configuration
2. Increase cache size (4MB → 8MB) for larger networks
3. Click "Save"

## Statistics Management

### Statistics Overview

AdGuard Home tracks DNS statistics for visibility.

**Current retention**: 90 days

**Statistics include**:

- Total queries
- Blocked queries
- Top queried domains
- Top blocked domains
- Top clients

### Review Statistics

1. Dashboard → Shows 24-hour statistics
2. Click time period selector (24h, 7d, 30d, 90d)
3. Review:
   - Block rate (typical: 10-30%)
   - Top clients (identify chatty devices)
   - Top domains (verify expected traffic)

### Adjust Statistics Retention

1. Settings → Statistics configuration
2. Change "Statistics retention" (default: 90 days)
3. Options: 1 day, 7 days, 30 days, 90 days, 1 year
4. Click "Save"

**Trade-off**:

- Longer retention = more historical data
- Longer retention = more disk space

### Clear Statistics

**Clear all statistics** (irreversible):

1. Settings → Statistics configuration
2. Click "Clear statistics" button
3. Confirm deletion
4. Statistics reset to zero

**Via SSH**:

```bash
# Stop AdGuard Home
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl --user stop adguardhome"

# Delete statistics
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "rm -f /opt/adguard/work/stats.db"

# Restart
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl --user start adguardhome"
```

## Cleanup Procedures

### Disk Space Management

AdGuard Home data can grow over time with query logs and statistics.

**Check total AdGuard disk usage**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "du -sh /opt/adguard/"
```

**Expected size**:

- Initial: 10-50MB
- After 30 days: 100-300MB
- After 90 days: 300MB-1GB

**If disk usage is high**:

1. Reduce query log retention (90d → 30d)
2. Reduce statistics retention (90d → 30d)
3. Clear old query logs manually
4. Remove redundant blocklists

### Container Log Cleanup

AdGuard Home container logs are managed by systemd journal.

**Check container log size**:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl --user -u adguardhome --disk-usage"
```

**Limit log retention**:

```bash
# Clean logs older than 7 days
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo journalctl --vacuum-time=7d"

# Or limit by size (keep last 100MB)
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo journalctl --vacuum-size=100M"
```

### Remove Unused Blocklists

**Identify redundant lists**:

1. Compare block counts across lists (Filters → DNS Blocklists)
2. Test disabling one list at a time
3. Monitor Query Log for increased allowed ads
4. Remove list if no impact observed

**Example**: If using OISD Big List + Hagezi Pro++, they overlap significantly. Consider keeping only one.

### Optimize Configuration File

AdGuard Home configuration file can accumulate old settings.

**Review configuration**:

```bash
# View config file
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "cat /opt/adguard/conf/AdGuardHome.yaml"
```

**Backup and clean** (manual, advanced):

1. Backup configuration (see "Backup and Restore" section)
2. Remove deprecated settings
3. Restart AdGuard Home
4. Verify functionality

## Backup and Restore

### Automated Backup

**Recommended**: Use automated backup script provided in repository.

**Script location**: `scripts/backup-adguard.sh`

**Configuration-only backup** (fastest, ~2KB):

```bash
./scripts/backup-adguard.sh --config-only
```

**Full backup** (config + logs + stats):

```bash
./scripts/backup-adguard.sh --full
```

**Backup location**: `./backups/adguard-home/`

**See**: [AdGuard Configuration Guide - Backup Section](../configuration/adguard-home.md#automated-backup-recommended)

### Automated Restore

**Script location**: `scripts/restore-adguard.sh`

**Restore from backup**:

```bash
./scripts/restore-adguard.sh backups/adguard-home/adguard-config-YYYYMMDD-HHMMSS.tar.gz
```

**See**: [AdGuard Configuration Guide - Restore Section](../configuration/adguard-home.md#automated-restore-recommended)

### Backup Schedule Recommendations

**Daily**: Config-only backups (before changes, automated via cron)
**Weekly**: Full backups (includes logs and stats)
**Before upgrades**: Always backup configuration

**Automated daily backup via cron**:

```bash
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/jellybuntu && ./scripts/backup-adguard.sh --config-only --retention 7
```

## Container Updates

AdGuard Home runs in a container with a pinned version for stability.

**Current version**: `v0.107.68` (pinned)

**Why pinned**: Prevents breaking changes in config schema, upstream DNS syntax, or filter list compatibility.

### Check for Updates

**Via Web UI**:

1. Settings → About
2. Check "Version" field
3. Compare with latest release: [AdGuard Home Releases](https://github.com/AdguardTeam/AdGuardHome/releases)

**Via CLI**:

```bash
# Check current version
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "podman exec adguardhome /opt/adguardhome/AdGuardHome --version"
```

### Update Process

**1. Review release notes** for breaking changes

**2. Backup configuration**:

```bash
./scripts/backup-adguard.sh --full
```

**3. Update version in role defaults**:

```bash
nano roles/adguard_home/defaults/main.yml

# Change version:
adguard_home_version: "v0.107.69"
```

**4. Re-run playbook**:

```bash
./bin/runtime/ansible-run.sh playbooks/networking/adguard-home.yml
```

**5. Verify functionality**:

```bash
# Test DNS resolution
dig @nas.discus-moth.ts.net google.com

# Check Web UI
curl -I http://nas.discus-moth.ts.net:80

# Review logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl --user -u adguardhome -n 50"
```

**6. Monitor for 24 hours** for any issues

## Troubleshooting

### Web UI Not Accessible

**Symptom**: Cannot access http://nas.discus-moth.ts.net:80

**Solution**:

```bash
# Check container status
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl --user status adguardhome"

# Check container logs
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl --user -u adguardhome -n 100"

# Check firewall
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ufw status | grep 80"

# Restart container
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "systemctl --user restart adguardhome"
```

### DNS Resolution Failing

**Symptom**: Queries to AdGuard Home timeout or fail

**Solution**:

```bash
# Test DNS directly
dig @nas.discus-moth.ts.net google.com

# If timeout, check container is running
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "podman ps | grep adguard"

# Check upstream DNS health
# Web UI → Settings → Test upstreams

# Verify port 53 is open
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo ufw status | grep 53"
```

### MagicDNS Not Working

**Symptom**: `*.ts.net` domains don't resolve

**Solution**:

1. Settings → DNS Settings → Upstream DNS servers
2. Verify first line is: `[/ts.net/]100.100.100.100`
3. If missing, add and save
4. Test: `dig @nas.discus-moth.ts.net jellyfin.discus-moth.ts.net`

### High Memory Usage

**Symptom**: AdGuard Home consuming > 500MB memory

**Solution**:

1. Reduce cache size (4MB → 2MB)
2. Reduce blocklist count (remove redundant lists)
3. Reduce query log retention (90d → 30d)
4. Reduce statistics retention (90d → 30d)
5. Restart container: `systemctl --user restart adguardhome`

### Blocklist Update Failures

**Symptom**: Lists fail to update with error status

**Solution**:

```bash
# Test internet connectivity
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "curl -I https://big.oisd.nl/"

# Check container logs for errors
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "journalctl --user -u adguardhome -n 100 | grep -i filter"

# Try manual update via Web UI
# Filters → DNS Blocklists → Update now

# If URL is broken, remove list and find alternative
```

### Too Many False Positives

**Symptom**: Legitimate sites blocked by filters

**Solution**:

1. **Identify blocking list**:
   - Query Log → Find blocked domain
   - Note which filter list blocked it

2. **Whitelist domain**:
   - Filters → Custom filtering rules
   - Add: `@@||example.com^`
   - Or click domain in Query Log → Unblock

3. **Disable aggressive list** (if too many false positives):
   - Filters → DNS Blocklists
   - Uncheck problematic list
   - Monitor for 24 hours

## Best Practices

### DO

- Backup configuration before updates
- Review query logs weekly for anomalies
- Monitor disk space monthly
- Test upstream DNS health quarterly
- Use automated backups (daily config, weekly full)
- Whitelist legitimate domains instead of disabling entire lists
- Document custom filtering rules with comments
- Review blocklists quarterly (remove broken or redundant)

### DON'T

- Disable DNSSEC (security risk)
- Use excessive blocklists (> 10-15 lists causes performance issues)
- Ignore update failures (broken lists should be removed)
- Clear logs without backup
- Disable query logging entirely (needed for troubleshooting)
- Update container without backing up configuration first

## Maintenance Schedule Summary

### Weekly

- [ ] Review query logs for anomalies
- [ ] Check DNS resolution health (`dig` test)
- [ ] Monitor disk space usage
- [ ] Review top blocked domains (verify no false positives)

### Monthly

- [ ] Update blocklists manually (if auto-update disabled)
- [ ] Review filter list health (check for update failures)
- [ ] Check memory usage
- [ ] Review client statistics (identify chatty devices)
- [ ] Prune query logs if disk space is high

### Quarterly

- [ ] Review and adjust retention policies (logs, stats)
- [ ] Audit blocklists (remove redundant or broken lists)
- [ ] Review custom filtering rules (remove obsolete)
- [ ] Update container image (check release notes first)
- [ ] Full backup of configuration

### Annually

- [ ] Comprehensive security review
- [ ] Review and optimize upstream DNS configuration
- [ ] Audit all configuration settings
- [ ] Plan capacity upgrades if needed

## Reference

### Related Documentation

- [AdGuard Home Configuration Guide](../configuration/adguard-home.md) - Detailed setup and usage
- [DNS Troubleshooting](../troubleshooting/dns.md) - Common DNS issues
- [Service Endpoints](../configuration/service-endpoints.md) - Access URLs
- [Updates Guide](updates.md) - General update procedures

### External Resources

- [AdGuard Home Wiki](https://github.com/AdguardTeam/AdGuardHome/wiki) - Official documentation
- [AdGuard Home GitHub](https://github.com/AdguardTeam/AdGuardHome) - Source code and issues
- [Firebog Blocklists](https://firebog.net/) - Curated blocklist collection
- [Tailscale DNS Documentation](https://tailscale.com/kb/1054/dns) - MagicDNS integration

## Summary

**Key Maintenance Tasks**:

- Weekly query log review and disk space monitoring
- Monthly blocklist health checks
- Quarterly configuration optimization and backups
- Regular performance monitoring

**Key Commands**:

```bash
# Service status
systemctl --user status adguardhome

# View logs
journalctl --user -u adguardhome -n 100

# Test DNS
dig @nas.discus-moth.ts.net google.com

# Backup
./scripts/backup-adguard.sh --config-only

# Check disk usage
du -sh /opt/adguard/
```

**Best Practices**:

- Backup before updates
- Monitor query logs weekly
- Review blocklists quarterly
- Whitelist instead of disabling filters
- Use automated backups daily
- Test DNS health regularly

Your AdGuard Home stays efficient, secure, and provides reliable DNS filtering!

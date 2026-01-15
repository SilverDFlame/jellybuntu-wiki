# AdGuard Home Configuration Guide

Complete setup and management guide for AdGuard Home DNS service.

**Access**: http://nas.discus-moth.ts.net:80

**Credentials**: Stored in vault (`vault_services_admin_username` / `vault_services_admin_password`)

---

## Overview

AdGuard Home is a network-wide DNS ad blocker and privacy protection service running on the NAS VM. It provides:

- **Ad Blocking**: Blocks ads and trackers at the DNS level for all devices
- **Privacy Protection**: Encrypted DNS-over-TLS (DoT) to upstream resolvers
- **DNSSEC**: Validates DNS responses to prevent spoofing
- **Custom Filtering**: Fine-grained control over blocked and allowed domains
- **Query Logging**: Complete visibility into DNS queries across the network
- **MagicDNS Integration**: Seamlessly resolves Tailscale `.ts.net` domains

---

## Architecture

### Deployment Details

- **Host**: NAS VM (192.168.0.15 / nas.discus-moth.ts.net)
- **Container**: Docker Compose deployment
- **Ports**:
  - Web UI: `80/tcp`
  - DNS: `53/udp` and `53/tcp`
- **Data Location**: `/opt/adguard-home/`
  - Config: `/opt/adguard-home/conf/AdGuardHome.yaml`
  - Data: `/opt/adguard-home/work/`

### Upstream DNS Configuration

AdGuard Home uses a multi-tier upstream DNS strategy:

1. **Tailscale MagicDNS**: `100.100.100.100` (for `*.ts.net` domains)
2. **Primary**: Quad9 DoT (`tls://dns.quad9.net`)
3. **Secondary**: Cloudflare DoT (`tls://1dot1dot1dot1.cloudflare-dns.com`)
4. **Fallback**: Quad9 plaintext (`9.9.9.11`, `149.112.112.11`)

### Network Access

- **Local Network**: `192.168.0.0/24` → Full DNS access
- **Tailscale**: `100.64.0.0/10` → Full DNS + Web UI access
- **Firewall**: UFW rules configured automatically during deployment

---

## Common Tasks

### Accessing the Web UI

1. Navigate to http://nas.discus-moth.ts.net:80
2. Login with credentials from vault
3. Dashboard shows:
   - Total queries (last 24 hours)
   - Blocked queries percentage
   - Top queried domains
   - Top blocked domains

---

### Adding Blocklists

**Settings → DNS Settings → DNS blocklists** <!-- markdownlint-disable-line MD036 -->

AdGuard Home comes pre-configured with three blocklists:

1. AdGuard DNS filter (general ads and trackers)
2. AdAway Default Blocklist (mobile ads)
3. MalwareDomainList.com (malware protection)

#### Recommended Additional Blocklists

**For comprehensive ad blocking:**

- **OISD Big List**: `https://big.oisd.nl/`
  - All-in-one blocklist, very comprehensive
  - Includes ads, trackers, malware, phishing
  - ~1.5M domains

**For privacy protection:**

- **Steven Black's Unified Hosts**: `https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts`
  - Well-maintained, balanced approach
  - ~150K domains

**For advanced blocking:**

- **Hagezi's Pro++ DNS Blocklist**: `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt`
  - Aggressive blocking (may require whitelisting)
  - Includes tracking, telemetry, ads, crypto miners
  - ~1M domains

- **NextDNS Ads & Trackers**: `https://raw.githubusercontent.com/nextdns/metadata/master/privacy/native/alexa`
  - Focuses on native app tracking
  - Good for mobile devices

**For family safety:**

- **Hagezi's Threat Intelligence Feeds**: `https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt`
  - Malware, phishing, scam protection
  - ~500K domains

#### How to Add a Blocklist

1. **Settings → DNS Settings → DNS blocklists**
2. Click "Add blocklist" → "Add a custom list"
3. Enter:
   - **Name**: Descriptive name (e.g., "OISD Big List")
   - **URL**: Blocklist URL from above
4. Click "Save"
5. AdGuard Home will fetch and apply the list immediately
6. Lists auto-update every 24 hours (configurable)

#### Adjusting Update Frequency

**Settings → DNS Settings → Filters update interval** <!-- markdownlint-disable-line MD036 -->

- Default: 24 hours
- Range: 1-720 hours
- Recommendation: 24-48 hours for balance between freshness and performance

#### Managing Blocklists

**View Current Blocklists:**

1. **Filters → DNS blocklists**
2. Shows all enabled blocklists with:
   - Name and source URL
   - Number of rules loaded
   - Last update timestamp
   - Update status (success/failure)

**Update Blocklists Manually:**

- Click "Update now" button at top of blocklist page
- Forces immediate update of all blocklists
- Useful after adding new lists or troubleshooting

**Remove a Blocklist:**

1. **Filters → DNS blocklists**
2. Find the blocklist to remove
3. Click the trash icon next to the list
4. Confirm removal
5. Rules are immediately removed from filtering engine

**Temporarily Disable a Blocklist:**

1. **Filters → DNS blocklists**
2. Uncheck the checkbox next to the blocklist name
3. Click "Save" or changes apply automatically
4. List remains in configuration but rules are not applied
5. Re-enable by checking the box again

**Troubleshooting Blocklist Issues:**

*Blocklist Failed to Update:*

- Check internet connectivity from NAS VM
- Verify blocklist URL is still valid (test in browser)
- Check AdGuard Home logs: `docker logs adguardhome | grep -i filter`
- Try manual update via "Update now" button

*Too Many False Positives:*

- Temporarily disable suspected blocklist
- Test if issue persists
- If resolved, either remove blocklist or whitelist specific domains
- Use Query Log to identify which list is blocking legitimate domains

**Currently Deployed Blocklists:**

This AdGuard Home instance has **9 comprehensive blocklists** configured:

**Tier 1: Base Protection** (pre-configured)

1. **AdGuard DNS Filter** (~144K rules)
   - Default AdGuard blocklist
   - Ads, tracking, malware

**Tier 2: Comprehensive Protection** <!-- markdownlint-disable-line MD036 -->

1. **OISD Big List** (~500K rules)
   - https://big.oisd.nl/
   - Comprehensive ad, tracking, malware blocker
   - Low false positives, actively maintained

2. **Hagezi's Pro++** (~1.7M rules)
   - https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.plus.txt
   - Aggressive protection: ads, tracking, malware, scams, DoH/VPN bypass
   - May require occasional whitelisting

3. **Steven Black's Unified Hosts** (~187K rules)
   - https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts
   - Ads, malware, fake news, gambling, porn
   - Well-tested, modular approach

**Tier 3: Adult Content Blocking** <!-- markdownlint-disable-line MD036 -->

1. **OISD NSFW** (~207K rules)
   - https://nsfw.oisd.nl/
   - Comprehensive adult/NSFW content blocking
   - Minimal false positives

2. **Hagezi's Porn Blocklist Ultimate** (~248K rules)
   - https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/ultimate.txt
   - Aggressive adult content, escort services, dating apps
   - Very thorough coverage

3. **Block List Project - Porn** (~205K rules)
   - https://blocklistproject.github.io/Lists/adguard/porn-ags.txt
   - Community-driven pornography blocker
   - Actively updated

**Tier 5: Security & Malware** <!-- markdownlint-disable-line MD036 -->

1. **DandelionSprout Anti-Malware** (~28K rules)
   - https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareAdGuard.txt
   - Malware, phishing, typosquatting protection
   - Security-focused

2. **Block List Project - Malware** (~248K rules)
   - https://blocklistproject.github.io/Lists/adguard/malware-ags.txt
   - Malware, ransomware, C2 servers
   - Essential security layer

**Total: ~2.2 million blocking rules** <!-- markdownlint-disable-line MD036 -->

**Performance Notes:**

- With 2.2M rules loaded, expect DNS query latency of 40-60ms
- Memory usage: ~200-400MB (well within NAS 6GB capacity)
- Auto-updates: Every 24 hours at random times to avoid load spikes

---

### Whitelisting Domains

If a legitimate site is blocked:

1. **Filters → Custom filtering rules**
2. Add whitelist rule:

   ```text
   @@||example.com^
   ```

3. Click "Save"

**Common domains to whitelist:**

```text
@@||s.youtube.com^$important
@@||googleads.g.doubleclick.net^
@@||settings-win.data.microsoft.com^
```

---

### Viewing Query Logs

**Query Log** (sidebar)

- Shows real-time DNS queries from all devices
- Filter by:
  - Client IP
  - Domain name
  - Query type (A, AAAA, etc.)
  - Response status (blocked, allowed, etc.)
- Click any query to:
  - Add domain to allowlist/blocklist
  - View full query details

**Retention**: 90 days (configurable in Settings → DNS Settings → Query log settings)

---

### Managing Statistics

**Dashboard** shows aggregated statistics

**Settings → Statistics configuration**:

- **Retention period**: 90 days (default)
- **Ignored domains**: Domains to exclude from stats
- **Ignored clients**: IPs to exclude from stats

**Top Clients** shows which devices make the most queries (useful for identifying chatty devices)

---

### Customizing DNS Settings

**Settings → DNS Settings** <!-- markdownlint-disable-line MD036 -->

#### Important Settings

| Setting                | Current Value     | Description                        |
|------------------------|-------------------|------------------------------------|
| **Rate limit**         | 20 queries/sec/IP | Prevents DNS amplification attacks |
| **DNSSEC**             | Enabled           | Validates DNS responses            |
| **Cache size**         | 4 MB              | Speeds up repeated queries         |
| **Optimistic caching** | Enabled           | Serves stale cache while updating  |
| **Query logging**      | Enabled           | Logs all DNS queries               |

#### Upstream DNS Servers

**Settings → DNS Settings → Upstream DNS servers** <!-- markdownlint-disable-line MD036 -->

Current configuration:

```text
[/ts.net/]100.100.100.100
tls://dns.quad9.net
tls://1dot1dot1dot1.cloudflare-dns.com
```

- First line: Routes `*.ts.net` queries to Tailscale MagicDNS
- Other lines: Encrypted DoT to public resolvers

**Don't change** unless you have a specific reason (breaks MagicDNS compatibility)

---

### Blocking Specific Domains

**Filters → Custom filtering rules** <!-- markdownlint-disable-line MD036 -->

Add custom block rules:

```text
||ads.example.com^
||telemetry.company.com^
||tracker.malicious.com^
```

Syntax:

- `||domain.com^` - Blocks domain.com and all subdomains
- `|domain.com^` - Blocks only exact match
- `@@||domain.com^` - Whitelist (unblock)
- `@@||domain.com^$important` - Whitelist with high priority

---

### Monitoring Performance

**Dashboard → Average processing time** <!-- markdownlint-disable-line MD036 -->

- Target: < 50ms
- Current: ~33ms (excellent)

**Query Log** shows response time for each query

If response times increase:

1. Check upstream DNS health (Settings → DNS Settings → Test upstreams)
2. Check NAS CPU/memory usage
3. Consider reducing blocklist count
4. Check network latency to upstream DNS servers

---

## Updating AdGuard Home

### Container Updates

AdGuard Home runs in a Docker container using the `latest` tag, which means it auto-updates when the container restarts.

**Manual update:**

```bash
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
cd /opt/adguard-home
docker compose pull
docker compose up -d
```

**Check version:**

- **Settings → About** shows current version
- Dashboard may show "Update available" notification

### Blocklist Updates

**Automatic**: Lists update every 24 hours by default

**Manual update:**

1. **Settings → DNS Settings → DNS blocklists**
2. Click "Check for updates"
3. AdGuard Home will re-fetch all enabled lists

---

## Backup and Restore

Automated backup and restore scripts are provided for AdGuard Home. These scripts handle configuration, query logs,
statistics, and ensure safe restoration with automatic safety backups.

### Automated Backup (Recommended)

**Script Location**: `scripts/backup-adguard.sh`

#### Quick Start

**Configuration-only backup** (fastest, ~2KB):

```bash
./scripts/backup-adguard.sh --config-only
```

**Full backup** (config + query logs + stats, ~varies):

```bash
./scripts/backup-adguard.sh --full
```

#### Backup Options

| Option             | Description                               | Default                  |
|--------------------|-------------------------------------------|--------------------------|
| `--config-only`    | Backup only configuration files           | N/A                      |
| `--full`           | Backup configuration + query logs + stats | Yes                      |
| `--retention N`    | Keep only last N backups                  | 7                        |
| `--backup-dir DIR` | Custom backup directory                   | `./backups/adguard-home` |

#### Examples

**Daily config backup with 14-day retention**:

```bash
./scripts/backup-adguard.sh --config-only --retention 14
```

**Weekly full backup with custom location**:

```bash
./scripts/backup-adguard.sh --full --backup-dir /mnt/backups/adguard
```

#### Backup Contents

**Config-only backup** (~2KB):

- `/opt/adguard-home/conf/AdGuardHome.yaml` - All configuration including:
  - Blocklists and custom filtering rules
  - Upstream DNS servers
  - Client settings
  - DNS rewrites
  - All Web UI settings

**Full backup** (size varies by usage):

- Configuration (as above)
- Query logs (last 90 days)
- Statistics (last 90 days)
- Session data

**What's NOT included**:

- Docker container or image (reinstall via playbook)
- Blocklist cache files (re-downloaded on first start)

#### Automated Scheduling

**Setup daily backups with cron** (config-only):

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /home/olieran/coding/mirrors/jellybuntu && ./scripts/backup-adguard.sh --config-only --retention 7 >> /var/log/adguard-backup.log 2>&1
```

**Setup weekly full backups**:

```bash
# Add weekly backup every Sunday at 3 AM
0 3 * * 0 cd /home/olieran/coding/mirrors/jellybuntu && ./scripts/backup-adguard.sh --full --retention 4 >> /var/log/adguard-backup.log 2>&1
```

---

### Automated Restore (Recommended)

**Script Location**: `scripts/restore-adguard.sh`

#### Quick Start

**Restore from backup**:

```bash
./scripts/restore-adguard.sh backups/adguard-home/adguard-config-20251028-161306.tar.gz
```

**List available backups**:

```bash
./scripts/restore-adguard.sh
```

#### What the Restore Script Does

1. **Safety First**: Creates a safety backup of current configuration before restore
2. **Stops Container**: Safely stops AdGuard Home
3. **Restores Files**: Extracts backup to `/opt/adguard-home/`
4. **Fixes Permissions**: Ensures correct ownership
5. **Restarts Container**: Brings AdGuard Home back online
6. **Verifies**: Checks container status

#### Restore Process

```bash
# 1. List available backups
ls -lh backups/adguard-home/

# 2. Choose backup to restore
./scripts/restore-adguard.sh backups/adguard-home/adguard-config-20251028-161306.tar.gz

# 3. Confirm restore (type 'yes' when prompted)

# 4. Wait for completion (typically 10-30 seconds)

# 5. Verify restoration
dig @nas.discus-moth.ts.net google.com
# Check Web UI: http://nas.discus-moth.ts.net:80
```

#### Safety Backup

The restore script automatically creates a pre-restore backup saved on the NAS:

```text
/tmp/adguard-pre-restore-<timestamp>.tar.gz
```

This backup is preserved in case the restore fails or you need to rollback.

**To recover from failed restore**:

```bash
# SSH to NAS
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net

# Find safety backup
ls -lh /tmp/adguard-pre-restore-*.tar.gz

# Manually restore if needed
cd /opt/adguard-home
docker compose down
sudo tar -xzf /tmp/adguard-pre-restore-<timestamp>.tar.gz -C /
docker compose up -d
```

---

### Manual Backup (Alternative)

If you prefer manual backups or the automated scripts are unavailable:

**Via Web UI**:

1. **Settings → Settings → Export**
2. Click "Export settings"
3. Saves `AdGuardHomeBackup.zip` to your computer
4. **Note**: Only includes configuration, not query logs/stats

**Via SSH**:

```bash
# Config only
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo tar -czf ~/adguard-backup-$(date +%Y%m%d).tar.gz /opt/adguard-home/conf"

# Full backup
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net \
  "sudo tar -czf ~/adguard-backup-$(date +%Y%m%d).tar.gz /opt/adguard-home/conf /opt/adguard-home/work"

# Download backup
scp -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net:~/adguard-backup-*.tar.gz ./
```

### Manual Restore (Alternative)

**Via Web UI**:

1. **Settings → Settings → Import**
2. Upload `AdGuardHomeBackup.zip`
3. Click "Import"
4. Container restarts automatically

**Via SSH**:

```bash
# Stop container
ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
cd /opt/adguard-home
docker compose down

# Extract backup
sudo tar -xzf ~/adguard-backup-YYYYMMDD.tar.gz -C /

# Fix permissions
sudo chown -R ansible:ansible /opt/adguard-home

# Restart container
docker compose up -d
```

---

### Backup Best Practices

**Recommended Backup Strategy**:

- **Daily**: Config-only backups (7-day retention)
- **Weekly**: Full backups (4-week retention)
- **Before major changes**: Manual config backup
- **Before upgrades**: Full backup

**Storage Recommendations**:

- **Local**: Fast access for quick restores
- **Off-site**: Cloud storage (Backblaze, AWS S3) for disaster recovery
- **NAS**: Additional copy on NAS RAID array

**Testing Backups**:

- **Monthly**: Verify backup files can be extracted
- **Quarterly**: Test full restore procedure in staging environment

**Retention Guidelines**:

- Config-only: 7-14 days (small size, minimal storage impact)
- Full backups: 4-8 weeks (balance between history and storage)
- Major milestone backups: Keep indefinitely (before/after major changes)

---

## Troubleshooting

### Web UI Not Accessible

1. **Check container status:**

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
   docker ps | grep adguard
   ```

   - Should show `Up` status

2. **Check firewall:**

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
   sudo ufw status | grep 80
   ```

   - Should show `ALLOW` from `100.64.0.0/10`

3. **Check container logs:**

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@nas.discus-moth.ts.net
   docker logs adguardhome --tail 50
   ```

### DNS Not Resolving

1. **Test DNS directly:**

   ```bash
   dig @nas.discus-moth.ts.net google.com
   ```

   - Should return an answer

2. **Check Tailscale DNS configuration:**
   - Tailscale Admin Console → DNS
   - Verify custom nameserver is set to NAS IP (100.65.73.89)

3. **Check upstream DNS servers:**
   - **Settings → DNS Settings → Test upstreams**
   - All upstreams should show "OK"

### MagicDNS Not Working

**Problem**: `*.ts.net` domains not resolving

**Solution**:

1. **Settings → DNS Settings → Upstream DNS servers**
2. Verify first line is: `[/ts.net/]100.100.100.100`
3. If missing, add it and click "Save"
4. Test: `dig @nas.discus-moth.ts.net jellyfin.discus-moth.ts.net`

### High Memory Usage

**Normal behavior**: AdGuard Home caches queries in memory

**If excessive (> 500 MB)**:

1. **Settings → DNS Settings → Cache configuration**
2. Reduce cache size from 4 MB to 2 MB
3. Reduce query log retention (Settings → DNS Settings → Query log settings)
4. Reduce statistics retention to 30 days

### Blocklist Update Failures

**Problem**: Lists fail to update

**Causes & Solutions**:

1. **Network connectivity issue**
   - Test: `curl -I https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt`
   - Should return `200 OK`

2. **Blocklist URL changed or removed**
   - Remove broken list
   - Find updated URL or replacement list

3. **Rate limiting**
   - Wait 1 hour and retry
   - Stagger list updates if many lists configured

---

## Advanced Configuration

### Client-Specific Settings

**Settings → Client settings** <!-- markdownlint-disable-line MD036 -->

Allows per-device configuration:

- Custom blocklists for specific clients
- Disable filtering for trusted devices
- Custom upstream DNS for specific clients

**Example**: Allow ads on guest devices, block on all others

1. Add client by IP or MAC address
2. Configure tags (e.g., "guest")
3. Create tag-specific rules

### Custom DNS Rewrites

**Settings → DNS Settings → DNS rewrites** <!-- markdownlint-disable-line MD036 -->

Useful for:

- Internal service resolution
- Overriding public DNS
- Custom local domains

**Example**: Resolve `nas.local` to NAS IP

```text
nas.local → 192.168.0.15
```

### DoH (DNS-over-HTTPS) Setup

Not currently enabled, but can be configured:

**Settings → Encryption Settings** <!-- markdownlint-disable-line MD036 -->

1. Enable DoH/DoT for clients
2. Requires TLS certificate (Let's Encrypt or self-signed)
3. Clients must support DoH (modern browsers, Android 9+)

**Not recommended** for this deployment (Tailscale already encrypts traffic)

---

## Maintenance Schedule

### Weekly

- [ ] Check dashboard for anomalies (unusual query spikes, high block rate)
- [ ] Review top blocked domains (ensure no false positives)

### Monthly

- [ ] Review and prune blocklists (remove redundant lists)
- [ ] Check for AdGuard Home updates
- [ ] Verify backup integrity

### Quarterly

- [ ] Review firewall rules (ensure still appropriate)
- [ ] Test restore procedure
- [ ] Review query log retention (adjust if needed)

---

## See Also

- [DNS Troubleshooting Guide](../troubleshooting/dns.md) - Common DNS issues and diagnostics
- [Service Endpoints](service-endpoints.md) - All service URLs and IPs
- [Network Configuration](networking.md) - Network architecture and firewall rules
- [Phase 2 Deployment](../deployment/phase2-networking.md) - How AdGuard Home was deployed

---

## External Resources

- [AdGuard Home Wiki](https://github.com/AdguardTeam/AdGuardHome/wiki)
- [AdGuard Home GitHub](https://github.com/AdguardTeam/AdGuardHome)
- [Blocklist Collection](https://github.com/blocklistproject/Lists)
- [Firebog Blocklists](https://firebog.net/) - Curated collection of reputable blocklists
- [Tailscale DNS Documentation](https://tailscale.com/kb/1054/dns)

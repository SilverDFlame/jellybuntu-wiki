# Uptime Kuma Setup Guide

Uptime Kuma is a self-hosted monitoring tool that provides service availability tracking and status pages for the
Jellybuntu infrastructure.

## Access

- **URL**: http://monitoring.discus-moth.ts.net:3001 (or http://192.168.10.16:3001)
- **First-time Setup**: Required on initial access
- **Data Persistence**: SQLite database stored in `uptime_kuma_data` volume

## Initial Setup

### 1. First-Time Access

When you first access Uptime Kuma, you'll be prompted to create an admin account:

1. Navigate to http://monitoring.discus-moth.ts.net:3001
2. Click "Create your admin account"
3. Enter credentials:
   - **Username**: Use vault credentials (`vault_services_admin_username`)
   - **Password**: Use vault credentials (`vault_services_admin_password`)
4. Click "Create"

The admin account is persisted in the SQLite database and survives container restarts.

### 2. Configure Settings

After login, configure global settings:

1. Click on your username (top right) → **Settings**
2. **General**:
   - Primary Base URL: `http://monitoring.discus-moth.ts.net:3001`
   - Timezone: Set to your local timezone
3. **Appearance**:
   - Theme: Choose between Light, Dark, or Auto
4. **Notifications**:
   - Default notification: Configure global default (optional)

## Creating Monitors

### Monitor Types

Uptime Kuma supports multiple monitor types:

- **HTTP(s)**: Web service availability checks
- **TCP Port**: Check if specific ports are open
- **Ping**: ICMP ping checks
- **DNS**: DNS query checks
- **Docker Container**: Monitor container health

### Recommended Monitors for Jellybuntu

Create monitors for all web services using these details:

#### Media Services VM (192.168.30.13)

| Service    | Type    | URL/Host                                 | Port | Check Interval |
|------------|---------|------------------------------------------|------|----------------|
| Sonarr     | HTTP(s) | http://media-services.discus-moth.ts.net | 8989 | 60s            |
| Radarr     | HTTP(s) | http://media-services.discus-moth.ts.net | 7878 | 60s            |
| Prowlarr   | HTTP(s) | http://media-services.discus-moth.ts.net | 9696 | 60s            |
| Jellyseerr | HTTP(s) | http://media-services.discus-moth.ts.net | 5055 | 60s            |
| Bazarr     | HTTP(s) | http://media-services.discus-moth.ts.net | 6767 | 60s            |
| Huntarr    | HTTP(s) | http://media-services.discus-moth.ts.net | 9705 | 60s            |
| Homarr     | HTTP(s) | http://media-services.discus-moth.ts.net | 7575 | 60s            |

#### Download Clients VM (192.168.30.14)

| Service     | Type    | URL/Host                                   | Port | Check Interval |
|-------------|---------|--------------------------------------------|------|----------------|
| qBittorrent | HTTP(s) | http://download-clients.discus-moth.ts.net | 8080 | 60s            |
| SABnzbd     | HTTP(s) | http://download-clients.discus-moth.ts.net | 8081 | 60s            |

#### Other Services

| Service        | Type    | URL/Host                                 | Port | Check Interval |
|----------------|---------|------------------------------------------|------|----------------|
| Jellyfin       | HTTP(s) | http://jellyfin.discus-moth.ts.net       | 8096 | 60s            |
| Home Assistant | HTTP(s) | http://home-assistant.discus-moth.ts.net | 8123 | 60s            |
| AdGuard Home   | HTTP(s) | http://nas.discus-moth.ts.net            | 80   | 60s            |

#### Monitoring Stack Self-Checks

| Service    | Type    | URL/Host                             | Port | Check Interval |
|------------|---------|--------------------------------------|------|----------------|
| Prometheus | HTTP(s) | http://monitoring.discus-moth.ts.net | 9090 | 60s            |
| Grafana    | HTTP(s) | http://monitoring.discus-moth.ts.net | 3000 | 60s            |

### Creating a Monitor (Step-by-Step)

1. Click **Add New Monitor**
2. Fill in the form:
   - **Monitor Type**: HTTP(s)
   - **Friendly Name**: Service name (e.g., "Sonarr")
   - **URL**: Full service URL (e.g., http://media-services.discus-moth.ts.net:8989)
   - **Heartbeat Interval**: 60 seconds (recommended)
   - **Retries**: 3 (default)
   - **Accepted Status Codes**: 200-299 (default)
3. **Advanced Options** (optional):
   - **Max Redirects**: 10
   - **Upside Down Mode**: Disabled (unless checking for expected failures)
4. Click **Save**

### Organizing Monitors with Tags

Use tags to organize monitors by category:

1. Create tags: Click **Manage Tags**
2. Add categories:
   - `media` (Sonarr, Radarr, Jellyseerr, etc.)
   - `downloads` (qBittorrent, SABnzbd)
   - `jellyfin` (Jellyfin service)
   - `monitoring` (Prometheus, Grafana)
   - `automation` (Home Assistant)
   - `dns` (AdGuard Home)
3. Apply tags to monitors when creating/editing them

## Notification Channels

### Supported Notification Types

Uptime Kuma supports 90+ notification providers:

- Discord
- Slack
- Email (SMTP)
- Telegram
- Pushover
- Webhook
- And many more...

### Setting Up Discord Notifications

1. Create a Discord webhook:
   - Go to your Discord server
   - Server Settings → Integrations → Webhooks
   - Click "New Webhook"
   - Choose a channel (e.g., #alerts)
   - Copy the webhook URL
2. In Uptime Kuma:
   - Click **Settings** → **Notifications**
   - Click **Setup Notification**
   - **Notification Type**: Discord
   - **Friendly Name**: "Discord Alerts"
   - **Discord Webhook URL**: Paste the webhook URL
   - **Test**: Click to verify it works
   - **Save**
3. Apply to monitors:
   - Edit each monitor
   - Under **Notifications**, enable "Discord Alerts"
   - Save

### Setting Up Email Notifications (SMTP)

1. In Uptime Kuma:
   - Click **Settings** → **Notifications**
   - Click **Setup Notification**
   - **Notification Type**: Email (SMTP)
   - **Friendly Name**: "Email Alerts"
2. Configure SMTP settings:
   - **Hostname**: Your SMTP server (e.g., smtp.gmail.com)
   - **Port**: 587 (TLS) or 465 (SSL)
   - **Security**: STARTTLS or SSL/TLS
   - **Username**: Your email address
   - **Password**: App-specific password (if using Gmail)
   - **From Email**: Sender address
   - **To Email**: Recipient address(es)
3. **Test** and **Save**
4. Apply to monitors

## Status Pages

### Creating a Public Status Page

1. Click **Status Pages**
2. Click **New Status Page**
3. Configure:
   - **Title**: "Jellybuntu Services Status"
   - **Description**: Brief description of your services
   - **Theme**: Light, Dark, or Auto
   - **Show Tags**: Enable to group services
   - **Domain Names**: Optional custom domain
4. **Add Monitors**: Drag monitors from the list to the status page
5. **Save**

### Accessing the Status Page

- **URL**: http://monitoring.discus-moth.ts.net:3001/status/[slug]
- **Public Access**: Status pages can be accessed without authentication
- **Customization**: Supports custom CSS, header, and footer

## Maintenance Mode

Use Maintenance Mode to suppress alerts during planned maintenance:

1. Click **Maintenance**
2. Click **Schedule Maintenance**
3. Configure:
   - **Title**: "Planned Maintenance"
   - **Description**: What's being maintained
   - **Affected Monitors**: Select monitors
   - **Date Range**: Start and end times
   - **Strategy**: Choose between "Single Maintenance Window" or "Recurring"
4. **Save**

During maintenance, affected monitors show a wrench icon and don't send alerts.

## Data Management

### Backup and Restore

**Manual Backup**:

```bash
# SSH to monitoring VM
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net

# Create backup of Uptime Kuma data volume
podman volume export uptime_kuma_data > ~/uptime-kuma-backup-$(date +%Y%m%d).tar
```

**Restore from Backup**:

```bash
# SSH to monitoring VM
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net

# Stop Uptime Kuma container
podman stop uptime-kuma

# Restore volume from backup
cat uptime-kuma-backup-YYYYMMDD.tar | podman volume import uptime_kuma_data -

# Start Uptime Kuma
podman start uptime-kuma
```

### Database Location

Uptime Kuma stores all data in `/app/data/kuma.db` inside the container:

- Monitor configurations
- Historical uptime data
- Notification settings
- User accounts
- Status page configurations

This maps to the `uptime_kuma_data` Podman volume on the host.

## API Access

Uptime Kuma provides a REST API for automation:

### Generating API Keys

1. Click your username → **Settings**
2. Navigate to **API Keys**
3. Click **Generate**
4. **Name**: Descriptive name (e.g., "Ansible Automation")
5. **Expiration**: Never (or set expiration date)
6. **Copy the API key** (shown only once!)

### API Usage Example

```bash
# Get all monitors
curl -H "X-API-Key: YOUR_API_KEY" \
  http://monitoring.discus-moth.ts.net:3001/api/monitors

# Create a new monitor (requires API library or complex JSON payload)
# Recommended: Use lucasheld.uptime_kuma Ansible collection instead
```

## Troubleshooting

### Can't Access Web UI

1. Check container is running:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "podman ps | grep uptime-kuma"
   ```

2. Check logs:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "podman logs uptime-kuma"
   ```

3. Verify port is listening:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "ss -tlnp | grep 3001"
   ```

### Monitors Showing Down (False Positives)

1. Check DNS resolution from monitoring VM:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "nslookup media-services.discus-moth.ts.net"
   ```

2. Test connectivity manually:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "curl -I http://media-services.discus-moth.ts.net:8989"
   ```

3. Check firewall rules:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "sudo ufw status"
   ```

### Notifications Not Sending

1. Verify notification configuration:
   - Settings → Notifications → Edit notification
   - Click **Test** to verify it works

2. Check monitor notification settings:
   - Edit monitor → Notifications
   - Ensure notification channel is enabled

3. Check Uptime Kuma logs for errors:

   ```bash
   ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net "podman logs uptime-kuma --tail 50"
   ```

### High Memory Usage

Uptime Kuma stores historical data in SQLite. If memory usage grows:

1. Reduce data retention period:
   - Settings → Data Retention
   - Set to 90 days (default is 180 days)

2. Clear old data:
   - Settings → Data Retention → **Clear Stats**

## Best Practices

1. **Check Intervals**: Use 60-second intervals for most services (balance between responsiveness and resource usage)
2. **Retry Count**: Set to 3 retries to avoid false positives during brief network hiccups
3. **Tags**: Use tags to organize monitors by service category
4. **Status Pages**: Create public status pages for user-facing services
5. **Maintenance Windows**: Schedule maintenance mode before planned downtime
6. **Backup Regularly**: Backup the `uptime_kuma_data` volume weekly
7. **API Keys**: Generate API keys for automation instead of using admin credentials

## Integration with Prometheus/Grafana

While Uptime Kuma provides binary up/down monitoring, complement it with Prometheus/Grafana for:

- Detailed performance metrics (CPU, RAM, disk usage)
- Trend analysis and capacity planning
- Root cause diagnostics

**Workflow**:

1. Uptime Kuma alerts you that a service is down
2. Use Grafana to investigate resource usage trends leading up to the failure
3. Use Prometheus to identify specific bottlenecks (CPU spikes, memory exhaustion, etc.)

## See Also

- [Monitoring Stack Setup](monitoring-stack-setup.md) - Prometheus/Grafana configuration
- [Service Endpoints](service-endpoints.md) - All service URLs and ports
- [Troubleshooting: Monitoring](../troubleshooting/monitoring.md) - Common monitoring issues
- [Uptime Kuma Official Docs](https://github.com/louislam/uptime-kuma/wiki)

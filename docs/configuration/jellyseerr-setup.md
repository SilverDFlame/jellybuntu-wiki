# Jellyseerr Setup Guide

Jellyseerr is a request management and media discovery tool that integrates with Jellyfin, Plex, and Emby to allow users
to request TV shows and movies.

## Overview

- **VM**: media-services (192.168.30.13)
- **Port**: 5055
- **Container**: jellyseer
- **Config Path**: `/opt/media-stack/jellyseer/config`
- **Image**: docker.io/fallenbagel/jellyseerr:2.1.0

## Access

- **Tailscale**: http://media-services.discus-moth.ts.net:5055
- **Local Network**: http://192.168.30.13:5055

## Initial Setup

### 1. First-Time Configuration

When you first access Jellyseerr, you'll go through a setup wizard:

1. **Access the Web UI**:

   ```bash
   # Via browser
   http://media-services.discus-moth.ts.net:5055
   ```

2. **Select Media Server**:
   - Choose **Jellyfin** (or Plex/Emby if using those)
   - Click "Use Jellyfin"

3. **Configure Jellyfin Connection**:
   - **Server URL**: `http://jellyfin.discus-moth.ts.net:8096` or `http://192.168.30.12:8096`
   - **Login**: Use your Jellyfin admin credentials
   - **Email Address**: Your email for notifications
   - Click "Sign In"

4. **Sync Jellyfin Libraries**:
   - Jellyseerr will import your existing Jellyfin libraries
   - Select which libraries to sync (typically Movies and TV Shows)
   - Click "Continue"

5. **Configure Sonarr** (TV Shows):
   - **Server URL**: `http://media-services.discus-moth.ts.net:8989` or `http://192.168.30.13:8989`
   - **API Key**: Found in Sonarr → Settings → General → Security → API Key
   - **Quality Profile**: Select your preferred profile (e.g., "HD-1080p")
   - **Root Folder**: `/data/media/tv`
   - **Enable Scan**: Check this to add to Sonarr when approved
   - **Enable Automatic Search**: Check to start download immediately
   - Click "Test" to verify, then "Add"

6. **Configure Radarr** (Movies):
   - **Server URL**: `http://media-services.discus-moth.ts.net:7878` or `http://192.168.30.13:7878`
   - **API Key**: Found in Radarr → Settings → General → Security → API Key
   - **Quality Profile**: Select your preferred profile (e.g., "HD-1080p")
   - **Root Folder**: `/data/media/movies`
   - **Minimum Availability**: Choose when to search (e.g., "Released")
   - **Enable Scan**: Check this to add to Radarr when approved
   - **Enable Automatic Search**: Check to start download immediately
   - Click "Test" to verify, then "Add"

7. **Finish Setup**:
   - Click "Finish Setup"
   - You'll be redirected to the Jellyseerr dashboard

### 2. Post-Setup Configuration

#### User Management

1. Navigate to **Settings → Users**
2. **Import Jellyfin Users**:
   - Jellyseerr automatically imports users from Jellyfin
   - Users can sign in with their Jellyfin credentials
3. **Set User Permissions**:
   - **Admin**: Full access to all settings
   - **Manage Requests**: Can approve/deny requests
   - **Request**: Can make requests (default for all users)
   - **Auto-Approve Movies**: User's movie requests are automatically approved
   - **Auto-Approve TV**: User's TV requests are automatically approved
4. **Configure Request Limits** (optional):
   - Set movie/TV request limits per user per day/week/month
   - Located in **Settings → Users → [User] → Edit**

#### Notification Configuration

1. Navigate to **Settings → Notifications**
2. Configure notification agents:

**Email Notifications**:

- Enable Email Agent
- Configure SMTP settings
- Set notification types (Request Approved, Request Available, etc.)

**Discord Notifications** (optional):

- Enable Discord Agent
- Add Webhook URL from Discord server settings
- Configure notification types
- Customize notification messages

**Telegram Notifications** (optional):

- Enable Telegram Agent
- Add Bot Token and Chat ID
- Configure notification types

#### General Settings

1. Navigate to **Settings → General**
2. Configure:
   - **Application Title**: Customize the title (default: Jellyseerr)
   - **Application URL**: Set external URL if using reverse proxy
   - **Display Language**: Set default language
   - **Discover Region**: Set region for content discovery (affects release dates)
   - **Discover Language**: Set language for content discovery
   - **Hide Available Media**: Hide media that's already in Jellyfin
   - **Enable CSRF Protection**: Recommended for security

## Common Configurations

### Auto-Approval for Specific Users

For trusted users who don't need request approval:

1. Go to **Settings → Users**
2. Click on the user
3. Enable:
   - **Auto-Approve Movies**
   - **Auto-Approve TV**
4. Save changes

### Request Limits

To prevent request abuse:

1. Go to **Settings → Users → [User] → Edit**
2. Set:
   - **Movie Request Limit**: e.g., 10 per week
   - **TV Request Limit**: e.g., 5 per week
3. Save changes

### 4K Content Handling

If using separate 4K Sonarr/Radarr instances:

1. Go to **Settings → Services**
2. Add additional Sonarr/Radarr instances:
   - Name them "Sonarr 4K" / "Radarr 4K"
   - Point to 4K instances
   - Set 4K quality profiles
3. Users can select 4K when requesting (if enabled)

## User Workflow

### Making a Request

1. **Search for Content**:
   - Use the search bar or browse discover section
   - Click on the media you want

2. **Request Media**:
   - Click "Request" button
   - Select seasons (for TV shows)
   - Add optional message
   - Submit request

3. **Track Request Status**:
   - Navigate to **Requests** tab
   - See status: Pending, Approved, Available
   - Receive notifications when status changes

### Approving Requests (Admin/Manage Requests)

1. Navigate to **Requests** tab
2. View pending requests
3. Click request to see details
4. Approve or Deny with optional comment
5. Approved requests automatically send to Sonarr/Radarr

## Integration Verification

### Test Sonarr Integration

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Check Sonarr logs for Jellyseerr activity
docker logs sonarr | grep -i jellyseerr

# Verify webhook is configured in Sonarr
# Sonarr → Settings → Connect → Look for Jellyseerr webhook
```

### Test Radarr Integration

```bash
# Check Radarr logs for Jellyseerr activity
docker logs radarr | grep -i jellyseerr

# Verify webhook is configured in Radarr
# Radarr → Settings → Connect → Look for Jellyseerr webhook
```

### Test Jellyfin Sync

1. Add new media to Jellyfin manually
2. Wait for Jellyseerr to sync (runs every 6 hours by default)
3. Or trigger manual sync: **Settings → Jellyfin → Sync Libraries**
4. Verify media shows as "Available" in Jellyseerr

## Maintenance

### Update Jellyseerr

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Pull latest image and restart
cd /opt/media-stack
docker compose pull jellyseer
docker compose up -d jellyseer
```

### Backup Configuration

```bash
# Backup Jellyseerr config
sudo tar -czf jellyseerr-config-backup-$(date +%Y%m%d).tar.gz \
  /opt/media-stack/jellyseer/config

# Copy to NAS for safekeeping
sudo cp jellyseerr-config-backup-*.tar.gz /mnt/data/backups/
```

### Reset Admin Password

If locked out:

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Stop container
docker stop jellyseer

# Edit database directly (advanced)
cd /opt/media-stack/jellyseer/config
sudo apt install sqlite3
sudo sqlite3 db/db.sqlite3

# View users
SELECT * FROM user;

# Reset admin (user ID 1) password to blank (will prompt on next login)
# This is complex - easier to restore from backup or reinstall

# Restart container
docker start jellyseer
```

## Configuration Files

### Main Database

- **Location**: `/opt/media-stack/jellyseer/config/db/db.sqlite3`
- **Type**: SQLite database
- **Contains**: Users, requests, settings

### Logs

- **Location**: `/opt/media-stack/jellyseer/config/logs/`
- **View in container**: `docker logs jellyseer`

## Advanced Configuration

### API Access

Jellyseerr has a REST API for automation:

- **API Docs**: http://media-services.discus-moth.ts.net:5055/api-docs
- **API Key**: Found in **Settings → General → API Key**

Example API usage:

```bash
# Get all requests
curl -H "X-Api-Key: YOUR_API_KEY" \
  http://media-services.discus-moth.ts.net:5055/api/v1/request

# Search for content
curl -H "X-Api-Key: YOUR_API_KEY" \
  "http://media-services.discus-moth.ts.net:5055/api/v1/search?query=Breaking+Bad"
```

### Custom CSS

To customize appearance:

1. Go to **Settings → General**
2. Scroll to **Custom CSS**
3. Add custom CSS rules

## Security Considerations

1. **Limit External Access**: If exposing to internet, use reverse proxy with HTTPS
2. **Enable CSRF Protection**: Settings → General → Enable CSRF Protection
3. **Review User Permissions**: Regularly audit user permissions
4. **Set Request Limits**: Prevent abuse by limiting requests per user
5. **Monitor Requests**: Regularly check request log for suspicious activity

## See Also

- [Sonarr/Radarr Troubleshooting](../troubleshooting/sonarr-radarr.md)
- [Service Endpoints](service-endpoints.md)
- [Jellyseerr Troubleshooting](../troubleshooting/jellyseerr.md)
- [Media Services Workflow](../reference/media-services-workflow.md)

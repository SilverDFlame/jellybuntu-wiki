# User Onboarding Guide

Complete guide for creating and configuring user accounts across all Jellybuntu services.

## Overview

This guide covers setting up new users for media consumption and request management. Admin tasks like service
configuration are covered in other guides.

## User Types

**Media Consumer** (Most common):

- Access Jellyfin to watch content
- Request media via Jellyseerr
- No access to automation services

**Power User** (Optional):

- Everything Media Consumer has
- Plus: Monitor downloads in qBittorrent/SABnzbd
- Plus: View automation in Sonarr/Radarr

**Admin**:

- Full access to all services
- Configuration and troubleshooting

## Quick Start (Media Consumer)

**Goal**: User can watch content and make requests in ~10 minutes.

1. Create Jellyfin account
2. Create Jellyseerr account (auto from Jellyfin)
3. Share access URLs
4. Done!

## Step 1: Create Jellyfin User

### 1.1 Create User Account

**As Admin**:

1. Access Jellyfin: http://jellyfin.discus-moth.ts.net:8096
2. Dashboard → Users → **+** (Add User)
3. **Name**: User's name (e.g., "John")
4. **Password**: Set secure password
5. **Save**

### 1.2 Configure User Permissions

**Library Access**:

- [ ] Enable access to Movies library
- [ ] Enable access to TV Shows library
- [ ] Disable access to admin libraries (if any)

**Feature Access**:

- [x] Allow media playback
- [x] Allow audio playback that requires transcoding
- [x] Allow video playback that requires transcoding
- [ ] Allow media deletion (usually no)
- [ ] Allow subtitle management (optional)

**Remote Access**:

- [x] Allow remote access to server
- [x] Force remote connection over HTTPS (if configured)

**Playback**:

- Max streaming bitrate: 120 Mbps (default, auto-adjusts)
- Max transcoding streams: 1-2 (prevents server overload)

**Save** user configuration.

### 1.3 Test Jellyfin Access

1. Open new incognito/private browser window
2. Navigate to: http://jellyfin.discus-moth.ts.net:8096
3. Sign in with new user credentials
4. Verify libraries visible and playable

## Step 2: Create Jellyseerr User

### 2.1 Import from Jellyfin (Automatic)

Jellyseerr automatically imports users from Jellyfin:

**As Admin**:

1. Access Jellyseerr: http://media-services.discus-moth.ts.net:5055
2. Settings → Users
3. Click "Import Users from Jellyfin"
4. Wait for sync to complete
5. New user should appear in user list

### 2.2 Configure User Permissions

Click on imported user → Edit:

**Request Permissions**:

- [x] Request (allow user to request content)
- [ ] Auto-Approve Movies (only for trusted users)
- [ ] Auto-Approve Series (only for trusted users)

**Request Limits** (optional, prevents abuse):

- Movie Requests: 10 per week (adjust as needed)
- Series Requests: 5 per week

**Notification Settings**:

- [ ] Enable Discord notifications (if configured)
- [ ] Enable email notifications (if SMTP configured)

**Save** user settings.

### 2.3 User First Login

**As User**:

1. Navigate to: http://media-services.discus-moth.ts.net:5055
2. Click "Sign In"
3. Select "Jellyfin" (if multiple options)
4. Use Jellyfin username/password
5. First login creates Jellyseerr profile

## Step 3: Share Access Information

Provide user with access details:

```text
**Jellybuntu Media Server Access**

Jellyfin (Watch Content):
- URL: http://jellyfin.discus-moth.ts.net:8096
- Username: [their username]
- Password: [their password]
-
Jellyseerr (Request Content):
- URL: http://media-services.discus-moth.ts.net:5055
- Login: Use same Jellyfin credentials

Via Tailscale (Remote Access):
- Install Tailscale on your device
- Join network: [your tailnet name]
- Then use above URLs

Tips:
- Request TV shows and movies via Jellyseerr
- Content usually available within 1-24 hours
- Check Jellyfin regularly for new additions
```

## Optional: Power User Setup

For users who want to monitor downloads:

### qBittorrent Access

1. Create qBittorrent web UI password:
   - Tools → Options → Web UI
   - Set different password per user (or share admin)
2. Share URL: http://download-clients.discus-moth.ts.net:8080

**Permissions**: Read-only recommended (can't modify settings)

### SABnzbd Access

1. Access SABnzbd UI: http://download-clients.discus-moth.ts.net:8081
2. Config → General → Security
3. Note: SABnzbd doesn't have user accounts (share API key or admin access)

**Recommendation**: Only share with trusted power users.

### Sonarr/Radarr Access

**Not recommended for regular users**. These are admin tools.

If needed:

- URL: http://media-services.discus-moth.ts.net:8989 (Sonarr)
- URL: http://media-services.discus-moth.ts.net:7878 (Radarr)
- Authentication: Enable in Settings → General

## User Mobile Apps

### Jellyfin Apps

**iOS/iPadOS**:

- App Store → "Jellyfin"
- Free, official app

**Android**:

- Play Store → "Jellyfin"
- Free, official app

**Configuration**:

1. Open app → Add Server
2. Server Address: `http://jellyfin.discus-moth.ts.net:8096`
3. Or via Tailscale: (same URL, ensure Tailscale running)
4. Sign in with credentials

### Jellyseerr Mobile

**Web Browser** (All platforms):

- Safari/Chrome → http://media-services.discus-moth.ts.net:5055
- Add to Home Screen for app-like experience

**No official mobile app**, but web UI is mobile-friendly.

## Managing User Requests

### As Admin: Approve Requests

**Jellyseerr**:

1. Requests tab
2. View pending requests
3. Approve or Deny with optional comment
4. Approved requests automatically send to Sonarr/Radarr

### Monitor Request Status

Users can track requests:

1. Jellyseerr → Requests
2. Status:
   - **Pending**: Awaiting admin approval
   - **Approved**: Sent to Sonarr/Radarr, searching
   - **Available**: Downloaded and in Jellyfin

### Notify Users

**Automatic** (if configured):

- Email/Discord notifications on status changes
- Jellyseerr Settings → Notifications

**Manual**:

- Add comment on request in Jellyseerr
- Direct message via Discord/etc.

## User Troubleshooting

### Can't Sign Into Jellyfin

**Check**:

1. Username/password correct (case-sensitive)
2. User account enabled (Dashboard → Users)
3. Remote access enabled for user

**Reset Password** (Admin):

1. Dashboard → Users → Click user
2. "Reset Password" button
3. Provide new password to user

### Can't Sign Into Jellyseerr

**Most common**:

- Use Jellyfin credentials, not separate password
- Jellyseerr uses Jellyfin for authentication

**Fix**:

1. Ensure Jellyfin login works first
2. Try Jellyseerr with same credentials
3. Clear browser cache if issues persist

### No Libraries Visible in Jellyfin

**Admin Check**:

1. Dashboard → Users → [User] → Library Access
2. Ensure Movies and TV Shows enabled
3. Save changes
4. User needs to refresh or re-login

### Content Not Appearing

**Timeline**:

- Request approved → Sonarr/Radarr searches (minutes)
- Download starts → Completes (minutes to hours)
- Imported to Jellyfin → Scan runs (up to 30 minutes)
- **Total**: 30 minutes to 24 hours typical

**Check Status**:

1. Jellyseerr → Requests → View request status
2. If "Available", check Jellyfin library scan ran

### Buffering or Playback Issues

See [Jellyfin Troubleshooting](../troubleshooting/jellyfin.md).

**Quick Fixes**:

- Lower quality in playback settings
- Ensure good network connection
- Check Jellyfin transcoding not overloaded

## Best Practices

### For Admins

1. **Set request limits** to prevent abuse
2. **Don't auto-approve** new users initially
3. **Monitor disk space** regularly
4. **Run Recyclarr** to maintain quality profiles
5. **Weekly backups** of user databases

### For Users

1. **Check Jellyfin first** before requesting (avoid duplicates)
2. **Be patient** - downloads take time
3. **Report issues** to admin if content problematic
4. **Use Jellyseerr** instead of asking admin directly
5. **Don't share credentials** outside household

## Security Considerations

### Password Strength

- Require strong passwords (12+ characters)
- Use password manager
- Different password per user

### Access Control

- Only share Tailscale with trusted users
- Firewall blocks external access (SSH via Tailscale + LAN)
- Services not exposed to internet directly

### Monitoring

- Review Jellyfin → Dashboard → Activity regularly
- Check for suspicious login attempts
- Monitor disk usage for unusual growth

## See Also

- [Jellyseerr Setup Guide](jellyseerr-setup.md)
- [Jellyfin Troubleshooting](../troubleshooting/jellyfin.md)
- [Service Integration Checklist](service-integration-checklist.md)
- [Service Endpoints](service-endpoints.md)

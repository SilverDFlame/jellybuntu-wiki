# Service Integration Checklist

Step-by-step checklist for connecting all services together and verifying the complete media automation workflow.

## Prerequisites

- All services deployed and accessible
- Basic understanding of service purposes
- Admin access to all service UIs

## Integration Overview

```text
Prowlarr (Indexers) → Sonarr/Radarr (Automation) → Download Clients → Unpackerr → Jellyfin (Streaming)
                              ↓
                         Jellyseerr (Requests) → Users
                              ↓
                          Bazarr (Subtitles)
```

## Phase 1: Indexer Management (Prowlarr)

### 1.1 Configure Prowlarr

- [ ] Access Prowlarr: http://media-services.discus-moth.ts.net:9696
- [ ] Settings → General → Authentication → Form (Login Required)
- [ ] Settings → General → Security → Copy **API Key** (save for later)

### 1.2 Add Indexers to Prowlarr

- [ ] Indexers → Add Indexer
- [ ] Add at least 3-5 indexers:
  - Public: 1337x, RARBG, ThePirateBay
  - Private: Add your private trackers (if any)
- [ ] Test each indexer after adding

### 1.3 Configure FlareSolverr (for Cloudflare-protected indexers)

- [ ] Settings → Indexers → FlareSolverr
- [ ] Tags: (leave empty for all)
- [ ] Host: `http://localhost:8191/`
- [ ] Test → Save

## Phase 2: Media Automation (Sonarr/Radarr)

### 2.1 Configure Sonarr

- [ ] Access Sonarr: http://media-services.discus-moth.ts.net:8989
- [ ] Settings → General → Authentication → Forms
- [ ] Settings → General → Security → Copy **API Key**

**Prowlarr Integration**:

- [ ] Sonarr: Settings → General → Copy API Key
- [ ] Prowlarr: Settings → Apps → Add → Sonarr
- [ ] Prowlarr URL: `http://localhost:9696`
- [ ] Sonarr URL: `http://localhost:8989`
- [ ] Sonarr API Key: (paste)
- [ ] Test → Save
- [ ] Click "Sync App Indexers" button

**Download Clients**:

- [ ] Settings → Download Clients → Add → qBittorrent
  - Name: qBittorrent
  - Host: `download-clients.discus-moth.ts.net` or `192.168.0.14`
  - Port: `8080`
  - Username: `admin`
  - Password: (your qBittorrent password)
  - Category: `tv`
  - Test → Save

- [ ] Settings → Download Clients → Add → SABnzbd
  - Name: SABnzbd
  - Host: `download-clients.discus-moth.ts.net` or `192.168.0.14`
  - Port: `8081`
  - API Key: (from SABnzbd Config → General → API Key)
  - Category: `tv`
  - Test → Save

**Media Management**:

- [ ] Settings → Media Management → Root Folders → Add
  - Path: `/data/media/tv`
- [ ] Enable: Rename Episodes, Replace Illegal Characters
- [ ] Unmonitor Deleted Episodes: Yes

### 2.2 Configure Radarr

- [ ] Access Radarr: http://media-services.discus-moth.ts.net:7878
- [ ] Settings → General → Authentication → Forms
- [ ] Settings → General → Security → Copy **API Key**

**Prowlarr Integration**:

- [ ] Prowlarr: Settings → Apps → Add → Radarr
- [ ] Radarr URL: `http://localhost:7878`
- [ ] Radarr API Key: (paste)
- [ ] Test → Save
- [ ] Click "Sync App Indexers"

**Download Clients** (same as Sonarr):

- [ ] qBittorrent: Category: `movies`
- [ ] SABnzbd: Category: `movies`

**Media Management**:

- [ ] Settings → Media Management → Root Folders → Add
  - Path: `/data/media/movies`
- [ ] Enable movie renaming and illegal character replacement

## Phase 3: Download Clients

### 3.1 Configure qBittorrent

- [ ] Access: http://download-clients.discus-moth.ts.net:8080
- [ ] Default login: `admin` / `adminadmin`
- [ ] Tools → Options → Web UI → Change password
- [ ] Tools → Options → Downloads:
  - Default Save Path: `/data/torrents`
  - Keep incomplete torrents in: `/data/torrents/incomplete`
  - Append `.!qB` extension: Yes
- [ ] Tools → Options → Connection:
  - Listening Port: (check "Use UPnP/NAT-PMP" or note PIA forwarded port)
- [ ] Apply settings

### 3.2 Configure SABnzbd

- [ ] Access: http://download-clients.discus-moth.ts.net:8081
- [ ] Run Setup Wizard on first access
- [ ] Config → Folders:
  - Temporary Download Folder: `/data/usenet/incomplete`
  - Completed Download Folder: `/data/usenet`
- [ ] Config → Servers → Add Server:
  - Add your usenet provider details
  - Enable SSL (port 563)
  - Test connection
- [ ] Config → Categories:
  - `tv` → Folder: `/data/usenet/tv`
  - `movies` → Folder: `/data/usenet/movies`
- [ ] Config → General → API Key: Copy for use in Sonarr/Radarr

## Phase 4: Subtitle Automation (Bazarr)

### 4.1 Configure Bazarr

- [ ] Access Bazarr: http://media-services.discus-moth.ts.net:6767
- [ ] Settings → General → Security → Copy **API Key**

**Sonarr Integration**:

- [ ] Settings → Sonarr → Enabled: Yes
- [ ] URL: `http://localhost:8989`
- [ ] API Key: (Sonarr API Key)
- [ ] Test → Save

**Radarr Integration**:

- [ ] Settings → Radarr → Enabled: Yes
- [ ] URL: `http://localhost:7878`
- [ ] API Key: (Radarr API Key)
- [ ] Test → Save

**Subtitle Providers**:

- [ ] Settings → Providers
- [ ] Add at least 2-3 providers (OpenSubtitles, Subscene, etc.)
- [ ] Configure languages: English (or your preferred languages)

## Phase 5: Media Server (Jellyfin)

### 5.1 Configure Jellyfin

- [ ] Access: http://jellyfin.discus-moth.ts.net:8096
- [ ] Complete initial setup wizard
- [ ] Add Libraries:
  - Type: Movies, Folder: `/data/media/movies`
  - Type: Shows, Folder: `/data/media/tv`
- [ ] Dashboard → Scheduled Tasks → Scan Media Library:
  - Set schedule (e.g., every 30 minutes)

### 5.2 Generate Jellyfin API Key

- [ ] Dashboard → Advanced → API Keys
- [ ] Click **+** to add new key
- [ ] Name: "Homarr" or "Jellyseerr"
- [ ] Copy API key for use in other services

## Phase 6: Request Management (Jellyseerr)

### 6.1 Configure Jellyseerr

- [ ] Access: http://media-services.discus-moth.ts.net:5055
- [ ] Run setup wizard:
  - Select Jellyfin
  - Jellyfin URL: `http://jellyfin.discus-moth.ts.net:8096`
  - Sign in with Jellyfin admin
  - Sync libraries

**Sonarr Integration**:

- [ ] Sonarr URL: `http://media-services.discus-moth.ts.net:8989`
- [ ] API Key: (Sonarr API Key)
- [ ] Quality Profile: Select default
- [ ] Root Folder: `/data/media/tv`
- [ ] Enable scan and automatic search
- [ ] Test → Add

**Radarr Integration**:

- [ ] Radarr URL: `http://media-services.discus-moth.ts.net:7878`
- [ ] API Key: (Radarr API Key)
- [ ] Quality Profile: Select default
- [ ] Root Folder: `/data/media/movies`
- [ ] Enable scan and automatic search
- [ ] Test → Add

## Phase 7: Dashboard (Homarr)

### 7.1 Verify Homarr Dashboard

- [ ] Access: http://media-services.discus-moth.ts.net:7575
- [ ] Verify all service tiles configured:
  - Sonarr: http://media-services.discus-moth.ts.net:8989
  - Radarr: http://media-services.discus-moth.ts.net:7878
  - Prowlarr: http://media-services.discus-moth.ts.net:9696
  - qBittorrent: http://download-clients.discus-moth.ts.net:8080
  - SABnzbd: http://download-clients.discus-moth.ts.net:8081
  - Jellyfin: Shows library counts

If widgets not working, check the container logs for API connectivity issues.

## Integration Testing

### Test 1: Manual Search and Download

- [ ] **Sonarr**: Search for a TV show → Add → Monitor
- [ ] Check Sonarr → Activity → Queue (download should appear)
- [ ] Check qBittorrent/SABnzbd (download active)
- [ ] Wait for completion
- [ ] Check Sonarr imports to `/data/media/tv`
- [ ] Check Jellyfin shows new episode

### Test 2: Automatic Search via Prowlarr

- [ ] **Prowlarr**: Search → Enter TV show or movie name
- [ ] Results from all configured indexers should appear
- [ ] Click "Grab" on a result
- [ ] Should automatically send to Sonarr/Radarr based on type

### Test 3: Request via Jellyseerr

- [ ] **Jellyseerr**: Search for media
- [ ] Click "Request"
- [ ] Request should appear in Jellyseerr → Requests
- [ ] Request should automatically create entry in Sonarr/Radarr
- [ ] Media should download and import automatically

### Test 4: Subtitle Download

- [ ] Wait for media to be added to Jellyfin
- [ ] **Bazarr**: Should automatically detect new media
- [ ] Bazarr: Series/Movies → Check subtitles downloading
- [ ] Verify subtitles appear in Jellyfin player

### Test 5: End-to-End Workflow

- [ ] User requests media via Jellyseerr
- [ ] Sonarr/Radarr searches via Prowlarr
- [ ] Downloads via qBittorrent/SABnzbd
- [ ] Unpackerr extracts (if archived)
- [ ] Sonarr/Radarr imports to media folder
- [ ] Bazarr downloads subtitles
- [ ] Jellyfin detects via library scan
- [ ] User watches in Jellyfin

**Expected Time**: 5-60 minutes depending on download speed and content size.

## Common Connection Errors

### "Connection refused" or "Timeout"

**Causes**:

- Wrong URL (use correct hostname/IP)
- Service not running
- Firewall blocking
- Wrong port

**Solutions**:

- Verify service running: `docker ps | grep service-name`
- Test URL in browser
- Check firewall: `sudo ufw status`

### "Unauthorized" or "Authentication failed"

**Causes**:

- Wrong API key
- Authentication not enabled in target service

**Solutions**:

- Re-copy API key (no extra spaces)
- Enable authentication in service settings

### "Not found" or "404"

**Causes**:

- Incorrect API endpoint
- Service version mismatch

**Solutions**:

- Verify URLs don't include `/api` suffix
- Update services to latest versions

## Integration Matrix

| From Service | To Service | Connection Type | URL/Host | Authentication |
|--------------|------------|-----------------|----------|----------------|
| Prowlarr | Sonarr | API | localhost:8989 | API Key |
| Prowlarr | Radarr | API | localhost:7878 | API Key |
| Sonarr | qBittorrent | API | 192.168.0.14:8080 | User/Pass |
| Sonarr | SABnzbd | API | 192.168.0.14:8081 | API Key |
| Radarr | qBittorrent | API | 192.168.0.14:8080 | User/Pass |
| Radarr | SABnzbd | API | 192.168.0.14:8081 | API Key |
| Bazarr | Sonarr | API | localhost:8989 | API Key |
| Bazarr | Radarr | API | localhost:7878 | API Key |
| Jellyseerr | Jellyfin | API | jellyfin:8096 | Jellyfin Auth |
| Jellyseerr | Sonarr | API | localhost:8989 | API Key |
| Jellyseerr | Radarr | API | localhost:7878 | API Key |
| Homarr | All | HTTP | Various | Service URLs |
| Unpackerr | Sonarr | API | media-services:8989 | API Key |
| Unpackerr | Radarr | API | media-services:7878 | API Key |

## See Also

- [Service Endpoints](service-endpoints.md)
- [User Onboarding Guide](user-onboarding.md)
- [Jellyseerr Setup](jellyseerr-setup.md)

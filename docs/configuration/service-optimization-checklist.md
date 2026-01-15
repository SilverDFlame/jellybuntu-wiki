# Service Optimization Checklist

Quick reference for optimizing newly deployed services.

**Last Updated**: 2025-10-24

---

## 1. Update Homarr Dashboard

### Add Service to Homarr

1. Go to http://media-services.discus-moth.ts.net:7575
2. Edit Mode → Add Widget/App
3. Configure the service tile with URL and icon

**Dashboard access**: http://media-services.discus-moth.ts.net:7575

**What Changed**:

- ✅ Added Huntarr to Homarr (Media Management section)
- ✅ Added Bazarr widget integration

---

## 2. Configure Bazarr (Priority)

**Guide**: [docs/configuration/bazarr-setup.md](bazarr-setup.md)

### Quick Setup (15 minutes)

1. **Initial Wizard** → Complete general settings
2. **Connect Sonarr** → localhost:8989 + API key
3. **Connect Radarr** → localhost:7878 + API key
4. **Add Providers** → OpenSubtitles, Subscene, TVSubtitles, YIFY
5. **Set Language** → English Only profile
6. **Configure Options** → UTF-8, Use Scene Name, Adaptive Search
7. **Set Schedule** → Library sync every 6h, search every 3h
8. **Initial Sync** → Full sync from Sonarr/Radarr

### Expected Result

- Bazarr syncs your TV/Movie library from Sonarr/Radarr
- Automatically downloads subtitles for new content
- Upgrades subtitles for 7 days if better ones are found
- Stores .srt files next to media files

---

## 3. Configure Huntarr (Priority)

**Guide**: [docs/configuration/huntarr-setup.md](huntarr-setup.md)

### Quick Setup (10 minutes)

1. **Connect Sonarr** → localhost:8989 + API key
2. **Connect Radarr** → localhost:7878 + API key
3. **Search Settings** → 24h interval, Medium depth, 70% min score
4. **Quality Profiles** → Match Sonarr/Radarr profiles
5. **Content Discovery** → Enable Missing Episodes, Sequels, Franchises
6. **Initial Scan** → Sync library and discover content

### Recommended Start Settings (Conservative)

```text
Search Interval: 24 hours
Auto-Add: Enabled
Minimum Score: 85%
Find Missing Episodes: ✅
Find Sequels/Prequels: ✅
Find Franchise: ❌ (enable later if desired)
Find Similar: ❌ (can be overwhelming)
```

### Expected Result

- Huntarr scans library every 24 hours
- Finds missing episodes from monitored series
- Discovers sequels/prequels to owned movies
- Auto-adds to Sonarr/Radarr for download

---

## 4. Optimize qBittorrent (Optional)

**Access**: http://download-clients.discus-moth.ts.net:8080

### Recommended Settings

**Tools → Options → Connection**:

- Global Maximum Connections: `500`
- Maximum Connections per Torrent: `100`
- Upload Slots per Torrent: `14`

**Tools → Options → Speed**:

- Global Download Limit: Unlimited (or set based on your preference)
- Global Upload Limit: `10 MB/s` (adjust based on your upload speed)
- Alternative Rate Limits: Configure for daytime vs nighttime

**Tools → Options → BitTorrent**:

- Enable DHT: ✅
- Enable PeX: ✅
- Enable Local Peer Discovery: ✅
- Encryption: `Allow encryption` (VPN already encrypts)
- Anonymous Mode: ❌ (can reduce peers)

**Tools → Options → Advanced → qBittorrent Section**:

- Async IO threads: `10`
- File pool size: `5000`

---

## 5. SABnzbd Configuration (Automated)

**Access**: http://download-clients.discus-moth.ts.net:8081

### Automatically Configured Settings

- ✅ Newshosting: 60 connections (Priority 10)
- ✅ Giganews: 40 connections (Priority 20)
- ✅ Folders: `/data/usenet/incomplete` → `/data/usenet`
- ✅ Categories: `tv` and `movies` configured
- ✅ **Direct Unpack: DISABLED** (Unpackerr handles extraction)
- ✅ **Cleanup List**: `.nzb, .par2, .sfv` (auto-delete metadata)
- ✅ **Deobfuscate filenames**: Enabled (for Sonarr/Radarr)

### Unpackerr Integration

SABnzbd is configured to work harmoniously with Unpackerr:

1. **SABnzbd** → Downloads files to `/data/usenet/incomplete`
2. **SABnzbd** → Verifies download, moves to `/data/usenet/tv` or `/data/usenet/movies`
3. **Unpackerr** → Detects archives (checks every 2 minutes)
4. **Unpackerr** → Extracts archives in place
5. **Unpackerr** → Notifies Sonarr/Radarr via API
6. **Sonarr/Radarr** → Imports and organizes to `/mnt/data/media/`

**Why This Works**:

- SABnzbd downloads and verifies (what it does best)
- Unpackerr extracts and coordinates with *arr apps (specialized tool)
- No duplicate extraction or wasted CPU cycles
- Proper API notifications ensure smooth imports

### Optional Manual Tweaks

**Config → Folders**:

- **Watch Folder**: `/data/usenet/watch` (for manual NZB drops)

---

## 6. Verify Recyclarr Configuration (Already Complete)

**Quality Profiles**:

- ✅ Sonarr: WEB-2160p + 1080p
- ✅ Radarr: UHD Bluray + WEB

**Custom Formats**:

- ✅ HDR formats (DV, HDR10, HDR10+)
- ✅ IMAX and special editions
- ✅ Release group tiers
- ✅ Unwanted content filters
- ✅ Streaming service tags

**Status**: Already applied via playbook 09-configure-recyclarr-role.yml

---

## 7. Verify Jellyfin Optimization (Already Complete)

**Performance Optimizations**:

- ✅ CPU governor: Performance mode
- ✅ Scheduling priority: Nice -10 (high priority)
- ✅ I/O scheduling: Realtime class
- ✅ System limits: Unlimited memlock, 65536 file descriptors
- ✅ 4 CPU cores allocated

**Status**: Already configured via playbook 11-configure-jellyfin-role.yml

---

## Priority Order

### Must Do Now

1. ✅ Add service to Homarr dashboard
2. ✅ Configure Bazarr (subtitle automation)
3. ✅ Configure Huntarr (content discovery)

### Optional (As Needed)

1. ⚪ Fine-tune qBittorrent settings
2. ⚪ Enable SABnzbd deobfuscation
3. ⚪ Adjust Huntarr aggressiveness

---

## Next Steps

Run these commands:

```bash
# 1. Get Bazarr API key and add to secrets file

sops group_vars/all.sops.yaml

# 2. Add service to Homarr dashboard at http://media-services.discus-moth.ts.net:7575

# 3. Follow configuration guides
# - docs/configuration/bazarr-setup.md
# - docs/configuration/huntarr-setup.md

```

---

**Estimated Time**: 30-40 minutes total for all configurations

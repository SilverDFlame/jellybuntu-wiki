# Sonarr Configuration Guide

Complete setup guide for Sonarr TV show management.

**Access**: http://media-services.discus-moth.ts.net:8989

---

## Overview

- **VM**: media-services (VMID 401, 192.168.0.13)
- **Port**: 8989
- **Deployment**: Podman container (rootless)
- **Media Path**: `/data/media/tv/`

---

## Episode Naming

Proper episode naming ensures Jellyfin correctly identifies seasons and episodes. Incorrect naming formats
can cause episodes to appear in wrong seasons.

Navigate to **Settings → Media Management → Episode Naming**.

### Basic Settings

| Setting | Value |
|---------|-------|
| **Rename Episodes** | ✅ Enabled |
| **Replace Illegal Characters** | ✅ Enabled |
| **Colon Replacement** | `Smart Replace` |

### Episode Formats

**Standard Episode Format:**

```text
{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}
```

Example: `The Series Title's! - S01E01 - Episode Title (1) WEBDL-1080p Proper`

**Daily Episode Format:**

```text
{Series Title} - {Air-Date} - {Episode Title} {Quality Full}
```

Example: `The Series Title's! - 2013-10-30 - Episode Title (1) WEBDL-1080p Proper`

**Anime Episode Format:**

```text
{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}
```

Example: `The Series Title's! - S01E01 - Episode Title WEBDL-1080p v2`

> **Note:** Using standard `S00E00` format for anime (instead of absolute numbering) ensures Jellyfin
> correctly maps episodes to seasons. This fixed issues where episodes appeared in wrong seasons.

### Folder Formats

**Series Folder Format:**

```text
{Series CleanTitleYear} {ImdbId}
```

Example: `The Series Title's! 2010 tt12345`

> **Why include IMDb ID?** Helps Jellyfin unambiguously identify the series, especially for shows with
> common names or reboots.

**Season Folder Format:**

```text
Season {season:00}
```

Example: `Season 01`

**Specials Folder Format:**

```text
Specials
```

### Multi-Episode Settings

| Setting | Value |
|---------|-------|
| **Multi Episode Style** | `Prefixed Range` |

Example: `The Series Title's! - S01E01-E03 - Episode Title WEBDL-1080p`

---

## Root Folders

Navigate to **Settings → Media Management → Root Folders**.

| Path | Purpose |
|------|---------|
| `/data/media/tv` | TV show library |

---

## Download Clients

Navigate to **Settings → Download Clients**.

### qBittorrent (Torrents)

| Setting | Value |
|---------|-------|
| **Name** | `qBittorrent` |
| **Enable** | ✅ |
| **Host** | `download-clients.discus-moth.ts.net` |
| **Port** | `8080` |
| **Use SSL** | ❌ |
| **URL Base** | (empty) |
| **Username** | `admin` |
| **Password** | (your password) |
| **Category** | `tv-sonarr` |

### SABnzbd (Usenet)

| Setting | Value |
|---------|-------|
| **Name** | `SABnzbd` |
| **Enable** | ✅ |
| **Host** | `download-clients.discus-moth.ts.net` |
| **Port** | `8085` |
| **Use SSL** | ❌ |
| **URL Base** | (empty) |
| **API Key** | (from SABnzbd → Config → General) |
| **Category** | `tv` |

---

## Indexers

Indexers are managed by **Prowlarr** and synced automatically to Sonarr.

See Prowlarr configuration for indexer setup.

---

## Quality Profiles

Quality profiles are managed by **Recyclarr** and synced automatically.

See [TRaSH Guides](https://trash-guides.info/Sonarr/) for profile recommendations.

---

## Troubleshooting

### Episodes Showing in Wrong Season (Jellyfin)

**Symptom**: Episodes appear in incorrect seasons in Jellyfin, especially for anime.

**Cause**: Incorrect episode naming format or absolute numbering conflicts with Jellyfin's season detection.

**Fix**:

1. Use standard `S00E00` format (not absolute numbering) for anime
2. Include year and IMDb ID in series folder format: `{Series CleanTitleYear} {ImdbId}`
3. Rename existing files:
   - Series → Select series → Series Editor → Rename Files
4. Refresh metadata in Jellyfin:
   - Dashboard → Libraries → TV Shows → Scan Library

### Files Not Importing

1. Check download client category matches Sonarr config (`tv-sonarr` for qBittorrent, `tv` for SABnzbd)
2. Verify file permissions on `/data/media/tv/`
3. Check Sonarr logs: **System → Logs**
4. Ensure root folder path is correct

### Series Not Found

1. Try searching by TVDb ID or IMDb ID
2. Check if series exists on TheTVDB
3. For anime, ensure series type is set to **Anime**

---

## Related Documentation

- [Bazarr Setup](bazarr-setup.md) - Subtitle management (connects to Sonarr)
- [Tdarr Flow Configuration](tdarr-flow-configuration.md) - Transcoding (processes Sonarr imports)
- [Service Endpoints](service-endpoints.md) - All service URLs

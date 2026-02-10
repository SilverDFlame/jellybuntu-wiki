# Media Quality Profiles and Custom Formats

This guide covers setting up quality profiles and custom formats for Sonarr and Radarr based on [Trash
Guides](https://trash-guides.info) recommendations.

## Folder Structure (Trash Guides)

We use the recommended Trash Guides folder structure for proper hardlinks support:

```text
/mnt/data/
├── torrents/
│   ├── movies/     # qBittorrent downloads for movies
│   ├── tv/         # qBittorrent downloads for TV
│   └── incomplete/ # Incomplete downloads
└── media/
    ├── movies/     # Radarr library
    └── tv/         # Sonarr library
```

**Benefits:**

- Hardlinks enabled (instant moves, no disk space duplication)
- All media on same filesystem
- Consistent paths across containers

## Setup Steps

### 1. Configure Folder Structure

The Trash Guides folder structure is automatically configured during Phase 2 (Btrfs NAS setup) and Phase 3 (service deployment):

```bash
# Phase 2: Creates folder structure on Btrfs NAS
./bin/runtime/ansible-run.sh playbooks/main-phase2-bootstrap.yml

# Phase 3: Mounts NFS and deploys services
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

No manual folder structure configuration is needed.

### 2. Configure qBittorrent

Access: `http://download-clients.discus-moth.ts.net:8080`

**Note**: qBittorrent is **automatically configured** by Phase 3 deployment with categories (tv, movies) and Automatic
Torrent Management. You only need to verify the configuration below is correct:

**Settings -> Downloads:**

- Default Save Path: `/data/torrents`
- Keep incomplete torrents in: `/data/torrents/incomplete`
- Copy .torrent files to: `/data/torrents/torrent-files`

**Settings -> Downloads -> Saving Management:**

- ✅ Automatic Torrent Management
- Default Torrent Management Mode: **Automatic**
- When Category Save Path changed: **Relocate torrent**
- When Default Save Path changed: **Relocate affected torrents**
- When Category changed: **Relocate affected torrents**

**Create Categories:**

1. Right-click in categories section → Add category
   - Category: `tv`
   - Save path: `/data/torrents/tv`

2. Right-click in categories section → Add category
   - Category: `movies`
   - Save path: `/data/torrents/movies`

### 3. Configure Sonarr

Access: `http://media-services.discus-moth.ts.net:8989`

#### Add Root Folder

1. **Settings** → **Media Management** → **Root Folders**
2. Click **Add Root Folder**
3. Enter: `/data/media/tv`
4. Click **OK**

#### Add Download Client

1. **Settings** → **Download Clients** → **Add** → **qBittorrent**
2. Configure:
   - Name: `qBittorrent`
   - Host: `qbittorrent` (Docker service name)
   - Port: `8080`
   - Username: (your qBittorrent username)
   - Password: (your qBittorrent password)
   - Category: `tv`
3. Click **Test** → **Save**

#### Quality Profiles (Trash Guides Recommendations)

**WEB-1080p Profile** (Recommended for most users):

1. **Settings** → **Profiles** → **Add**
2. Name: `WEB-1080p`
3. Upgrades Allowed: ✅
4. Upgrade Until: `Bluray-1080p`
5. Quality Order (top to bottom):
   - Bluray-1080p
   - WEB-1080p
   - HDTV-1080p
   - Bluray-720p
   - WEB-720p
   - HDTV-720p

**Anime Profile** (if you watch anime):

1. Follow the Trash Guides: https://trash-guides.info/Sonarr/sonarr-setup-quality-profiles-anime/

#### Custom Formats (Automated with Recyclarr)

Custom formats can be automatically configured using our Recyclarr playbook. See the **Automated Setup with Recyclarr**
section below for complete setup instructions.

Recyclarr will automatically configure:

1. **x265 (HD)** - Prefer x265 for space savings
2. **HDR/DV** - Prefer HDR content
3. **Repack/Proper** - Get fixed releases
4. **Streaming Services** - Prefer specific services
5. **HQ Release Groups** - Prefer quality release groups

**Manual Setup (Not Recommended):**

- Follow TRaSH Custom Format Guide: https://trash-guides.info/Sonarr/sonarr-setup-custom-formats/
- Manually import via Sonarr → Settings → Custom Formats → Import

### 4. Configure Radarr

Access: `http://media-services.discus-moth.ts.net:7878`

#### Add Root Folder

1. **Settings** → **Media Management** → **Root Folders**
2. Click **Add Root Folder**
3. Enter: `/data/media/movies`
4. Click **OK**

#### Add Download Client

1. **Settings** → **Download Clients** → **Add** → **qBittorrent**
2. Configure:
   - Name: `qBittorrent`
   - Host: `qbittorrent`
   - Port: `8080`
   - Username: (your qBittorrent username)
   - Password: (your qBittorrent password)
   - Category: `movies`
3. Click **Test** → **Save**

#### Quality Profiles (Trash Guides Recommendations)

**HD Bluray + WEB Profile** (Recommended):

1. **Settings** → **Profiles** → **Add**
2. Name: `HD Bluray + WEB`
3. Upgrades Allowed: ✅
4. Upgrade Until: `Bluray-1080p`
5. Quality Order (top to bottom):
   - Bluray-1080p
   - WEB-1080p
   - Bluray-720p
   - WEB-720p

**UHD Bluray + WEB Profile** (4K content):

1. Name: `UHD Bluray + WEB`
2. Upgrade Until: `Bluray-2160p`
3. Quality Order:
   - Bluray-2160p
   - WEB-2160p
   - Bluray-1080p
   - WEB-1080p

#### Custom Formats (Automated with Recyclarr)

Custom formats can be automatically configured using our Recyclarr playbook. See the **Automated Setup with Recyclarr**
section below for complete setup instructions.

Recyclarr will automatically configure:

1. **Movie Versions** - Prefer IMAX Enhanced editions
2. **HQ Release Groups** - Prefer quality release groups (UHD Bluray tiers)
3. **Unwanted** - Block 3D, obfuscated releases, scene releases
4. **Repack/Proper** - Get fixed releases
5. **Streaming Services** - Tag content by streaming service

**Manual Setup (Not Recommended):**

- Follow TRaSH Custom Format Guide: https://trash-guides.info/Radarr/radarr-setup-custom-formats/
- Manually import via Radarr → Settings → Custom Formats → Import

### 5. Configure Prowlarr

Access: `http://media-services.discus-moth.ts.net:9696`

#### Add Indexers

1. **Indexers** → **Add Indexer**
2. Search for your indexers (public/private trackers)
3. Configure authentication if needed
4. Test and Save

#### Sync Apps

1. **Settings** → **Apps** → **Add Application**
2. Add **Sonarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Sonarr Server: `http://sonarr:8989`
   - API Key: (copy from Sonarr → Settings → General → Security → API Key)
   - Sync Level: **Full Sync**

3. Add **Radarr**:
   - Prowlarr Server: `http://prowlarr:9696`
   - Radarr Server: `http://radarr:7878`
   - API Key: (copy from Radarr → Settings → General → Security → API Key)
   - Sync Level: **Full Sync**

4. Click **Test All** → **Save**

Now Prowlarr will automatically sync all indexers to both Sonarr and Radarr!

## Verification

### Test Hardlinks

After setting up, download a test file and verify hardlinks are working:

```bash
# From your control machine
ansible -i inventory.ini media_services -m shell -a "ls -li /mnt/data/torrents/tv/ /mnt/data/media/tv/"
```

If hardlinks are working, you'll see the same inode number for files in both locations (first column).

### Check Disk Usage

```bash
ansible -i inventory.ini media_services -m shell -a "df -h /mnt/data"
```

With hardlinks, moving files from torrents to media shouldn't increase disk usage.

## Automated Setup with Recyclarr

Recyclarr automates the configuration of custom formats and quality profiles based on TRaSH Guides recommendations. Our
playbook handles the complete setup, including secure API key storage in Ansible Vault.

### Prerequisites

1. **Complete Steps 1-5 above** to set up folder structure, qBittorrent, Sonarr, Radarr, and Prowlarr
2. **Get API Keys** from your services:
   - Sonarr: Settings → General → Security → API Key
   - Radarr: Settings → General → Security → API Key

### Step 1: Add API Keys to Secrets File

Edit the encrypted secrets file to add your API keys:

```bash
sops group_vars/all.sops.yaml
```

Add or uncomment these lines with your actual API keys:

```yaml
# Media Services API Keys
vault_sonarr_api_key: "your_actual_sonarr_api_key_here"
vault_radarr_api_key: "your_actual_radarr_api_key_here"
```

Save and exit (`:wq` in vim).

### Step 2: Run the Recyclarr Configuration Playbook

```bash
./bin/runtime/ansible-run.sh playbooks/09-configure-recyclarr-role.yml
```

Or run as part of Phase 3:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

This playbook will:

1. Validate that API keys are present in the vault
2. Create the Recyclarr configuration directory
3. Generate a Recyclarr config file with your API keys
4. Add Recyclarr to the Docker Compose stack
5. Run an initial sync to configure custom formats

### Step 3: Verify Configuration

Check that custom formats were applied:

**Sonarr:**

1. Go to http://media-services.discus-moth.ts.net:8989
2. Navigate to **Settings** → **Custom Formats**
3. You should see formats like "WEB Tier 01", "HQ-WEBDL", "Repack/Proper", etc.
4. Go to **Settings** → **Profiles** → **WEB-1080p**
5. Verify custom format scores are configured

**Radarr:**

1. Go to http://media-services.discus-moth.ts.net:7878
2. Navigate to **Settings** → **Custom Formats**
3. You should see formats like "IMAX Enhanced", "UHD Bluray Tier 01", streaming service tags, etc.
4. Go to **Settings** → **Profiles** → **HD Bluray + WEB**
5. Verify custom format scores are configured

### Manual Sync (Optional)

To manually sync Recyclarr at any time:

```bash
# From your control machine
ansible -i inventory.ini media_services -m shell -a "docker exec recyclarr recyclarr sync"
```

### Automatic Sync Schedule (Recommended)

TRaSH Guides recommends syncing daily to get updated custom formats. Set up a cron job on the media-services VM:

```bash
# SSH into media-services
ssh ansible@media-services.discus-moth.ts.net

# Add cron job (runs daily at 3 AM)
sudo crontab -e

# Add this line:
0 3 * * * cd /opt/media-stack && docker exec recyclarr recyclarr sync
```

### Configuration Details

The playbook configures:

**Sonarr - WEB-1080p Profile:**

- Quality definition optimized for series
- Prefers WEB releases from top-tier sources (WEB Tier 01-03)
- Scores HQ release groups highly
- Blocks low-quality formats (BR-DISK, x265 HD)
- Upgrades until Bluray-1080p quality

**Radarr - HD Bluray + WEB Profile:**

- Quality definition optimized for movies
- Prefers UHD Bluray tiers and IMAX Enhanced
- Tags content by streaming service (Netflix, Amazon, etc.)
- Blocks unwanted formats (3D, scene releases, obfuscated)
- Upgrades until Bluray-1080p quality

Configuration file location: `/opt/recyclarr/config/recyclarr.yml` on the media-services VM

## Recommended Resources

- **Trash Guides**: https://trash-guides.info/
- **Recyclarr** (automate custom formats): https://recyclarr.dev/
- **TRaSH Discord**: https://trash-guides.info/discord
- **Sonarr Wiki**: https://wiki.servarr.com/sonarr
- **Radarr Wiki**: https://wiki.servarr.com/radarr

## Troubleshooting

### Hardlinks Not Working

**Symptoms:** Files are copied instead of instant-moved, disk usage doubles.

**Causes:**

- Download and media folders on different filesystems
- Incorrect Docker volume mappings
- NFS mounts configured separately

**Solution:**
Ensure both `/mnt/data/torrents` and `/mnt/data/media` are on the same NFS mount (`/mnt/data`).

### Permission Errors

**Symptoms:** Sonarr/Radarr can't move files, permission denied errors.

**Solution:**
Verify PUID/PGID match NFS user:

```bash
ansible -i inventory.ini media_services -m shell -a "docker exec sonarr id"
```

Should show `uid=3000(abc) gid=3000(abc)`.

### Categories Not Working in qBittorrent

**Symptoms:** Sonarr/Radarr downloads go to wrong folder.

**Solution:**

- Verify categories are created in qBittorrent
- Verify category paths use `/data/torrents/{tv|movies}`
- Verify Automatic Torrent Management is enabled

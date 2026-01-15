# Bazarr Configuration Guide

Complete setup guide for Bazarr subtitle management.

**Access**: http://media-services.discus-moth.ts.net:6767

---

## 1. Initial Setup Wizard

When you first access Bazarr, you'll see a setup wizard.

### General Settings

- **Analytics**: Disable (optional)
- **Port**: 6767 (already configured)
- Click "Next"

---

## 2. Connect to Sonarr

**Settings → Sonarr** <!-- markdownlint-disable-line MD036 -->

1. Click "Add"
2. Configure:
   - **Address**: `sonarr` (Docker service name) or `localhost`
   - **Port**: `8989`
   - **Base URL**: Leave empty (just `/`)
   - **API Key**: Copy from Sonarr → Settings → General → Security → API Key
   - **Minimum Score For Episodes**: `85` (recommended - 0-100 scale, higher = stricter matching)
   - **Download Only Monitored**: ✅ Enabled (ensures subtitles only download for monitored episodes)
3. Click "Test" to verify connection
4. Click "Add" or "OK" to save

---

## 3. Connect to Radarr

**Settings → Radarr** <!-- markdownlint-disable-line MD036 -->

1. Click "Add"
2. Configure:
   - **Address**: `radarr` (Docker service name) or `localhost`
   - **Port**: `7878`
   - **Base URL**: Leave empty (just `/`)
   - **API Key**: Copy from Radarr → Settings → General → Security → API Key
   - **Minimum Score For Movies**: `85` (recommended)
   - **Download Only Monitored**: ✅ Enabled (ensures subtitles only download for monitored movies)
3. Click "Test" to verify connection
4. Click "Add" or "OK" to save

---

## 4. Configure Subtitle Providers

**Settings → Providers** <!-- markdownlint-disable-line MD036 -->

### Recommended Providers for English Subtitles

1. **OpenSubtitles.com** (Best database, requires free account)
   - Click "Add" → OpenSubtitles.com
   - Username: Your OpenSubtitles username (create at opensubtitles.com)
   - Password: Your OpenSubtitles password
   - Click "Add"
   - **Note**: Free tier has rate limits

2. **Addic7ed** (TV shows - high quality, requires free account)
   - Click "Add" → Addic7ed
   - Username: Your Addic7ed username (create at addic7ed.com)
   - Password: Your Addic7ed password
   - Click "Add"
   - **Note**: Best for TV shows, community-curated

3. **Podnapisi** (No configuration needed)
   - Click "Add" → Podnapisi
   - No configuration needed
   - Click "Add"

4. **SuperSubtitles** (No configuration needed)
   - Click "Add" → SuperSubtitles
   - No configuration needed
   - Click "Add"

5. **Subdl** (Requires API key)
   - Click "Add" → Subdl
   - API Key: Get from subdl.com (requires free account)
   - Click "Add"
   - **Note**: Skip if you don't want to create an account

6. **subf2m.co** (Requires User-Agent header)
   - Click "Add" → subf2m.co
   - User-Agent: `Mozilla/5.0` (or any browser user-agent string)
   - Click "Add"
   - **Note**: May be unreliable

### Provider Priority

Drag providers to set priority (top = highest priority):

**Recommended order:**

1. OpenSubtitles.com (largest database)
2. Addic7ed (best for TV shows)
3. Podnapisi (good quality)
4. Subdl (good coverage)
5. subf2m.co (backup)
6. SuperSubtitles (backup)

---

## 5. Configure Languages

**Settings → Languages** <!-- markdownlint-disable-line MD036 -->

### Languages Filter

1. Click "Add"
2. Select languages you want:
   - **English** (primary)
   - Add others as needed (Spanish, French, etc.)

### Languages Profiles

1. Click "Add Profile"
2. Name: `English Only`
3. Languages:
   - Add: `English`
   - **Must Contain**: Leave empty (unless you need specific attributes like "forced" or "hearing impaired")
   - **Must Not Contain**: Leave empty
4. Click "Add"

### Default Settings

- **Single Language**: ✅ Enabled (one subtitle file per language)
- **Embedded Subtitles Preferences**: `Prefer external subtitles`

---

## 6. Configure Subtitles Options

**Settings → Subtitles** <!-- markdownlint-disable-line MD036 -->

### Subtitles Options

- **Wanted Languages**: Select your profile (`English Only`)
- **Use Original Format**: ✅ Enabled (keeps original subtitle timing)
- **Use Scene Name**: ✅ Enabled (better matching)
- **Sync Subtitles**: ❌ Disabled (unless you have sync issues)
- **Hearing Impaired**: `Prefer non-hearing impaired` (personal preference)
- **UTF-8 Encoding**: ✅ Enabled (ensures proper character display)

### Anti-Captcha Options

- **Anti-Captcha Provider**: `None` (unless you hit captcha issues)

### Performance

- **Adaptive Searching**: ✅ Enabled (reduces API calls)
- **Search Enabled**: ✅ Enabled
- **Minimum Movie File Size**: `20` MB (skip sample files)
- **Minimum Episode File Size**: `20` MB

---

## 7. Configure Scheduler

**Settings → Scheduler** <!-- markdownlint-disable-line MD036 -->

### Update Library

- **Sync Series/Movies from Sonarr/Radarr**: Every `6 hours`

### Search Subtitles

- **Search for Missing Subtitles**: Every `3 hours`

### Upgrade Subtitles

- **Upgrade Previously Downloaded Subtitles**: Every `24 hours`
- **Upgrade for 7 days after download**: ✅ Enabled (finds better subtitles)

---

## 8. Initial Library Sync

After configuration:

1. Go to **Settings → Sonarr** → Click "Full Sync"
2. Go to **Settings → Radarr** → Click "Full Sync"
3. Wait for library sync to complete (check **System → Tasks**)
4. Go to **Series** or **Movies** to see your library

---

## 9. Manual Subtitle Search (Optional)

To manually search for subtitles:

1. Go to **Series** or **Movies**
2. Find an item missing subtitles (red indicator)
3. Click on the item
4. Click "Search" button
5. Select desired subtitle from results
6. Click "Download"

---

## 10. Verify Operation

**Check System Status**:

- **System → Tasks** - Verify scheduled tasks are running
- **System → Logs** - Check for any errors
- **History** - View subtitle download history

**Expected Behavior**:

- Bazarr syncs with Sonarr/Radarr every 6 hours
- Searches for missing subtitles every 3 hours
- Automatically downloads best-matching subtitles based on score (85+)
- Upgrades subtitles for 7 days if better ones are found

---

## Common Settings Adjustments

### If You Want Forced Subtitles Only

**Settings → Languages → Profile → English** <!-- markdownlint-disable-line MD036 -->

- **Must Contain**: `forced`

### If You Want Hearing Impaired (SDH)

**Settings → Subtitles** <!-- markdownlint-disable-line MD036 -->

- **Hearing Impaired**: `Prefer hearing impaired`

### If Subtitles Are Out of Sync

**Settings → Subtitles** <!-- markdownlint-disable-line MD036 -->

- **Sync Subtitles**: ✅ Enabled
- **Use embedded subtitles**: ✅ Enabled (for reference timing)

---

## Integration with Sonarr/Radarr

Bazarr automatically:

- ✅ Syncs your library from Sonarr/Radarr
- ✅ Monitors for new episodes/movies
- ✅ Downloads subtitles based on your quality profile
- ✅ Stores subtitles next to media files (`/data/media/tv/` and `/data/media/movies/`)
- ✅ Updates Jellyfin automatically (Jellyfin scans for new .srt files)

**No additional configuration needed in Sonarr/Radarr or Jellyfin!**

---

## Troubleshooting

### Subtitles Not Downloading

1. Check provider status: **System → Providers**
2. Lower minimum score: **Settings → Sonarr/Radarr** → Change to `70`
3. Add more providers: **Settings → Providers**

### Connection Errors to Sonarr/Radarr

1. Verify API keys are correct
2. Check hostname is `localhost` (not Tailscale hostname)
3. Test connection: **Settings → Sonarr/Radarr** → "Test" button

### Wrong Language Downloaded

1. Check language profile: **Settings → Languages**
2. Verify "Single Language" is enabled
3. Clear cache: **System → Tasks** → "Clear All Subtitles Cache"

---

**Status**: Ready for configuration
**Next Steps**: Follow steps 1-8 to complete Bazarr setup

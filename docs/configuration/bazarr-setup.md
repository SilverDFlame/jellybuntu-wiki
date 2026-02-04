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

### Core Providers

1. **OpenSubtitles.com** (Largest database, requires free account)
   - Click "Add" → OpenSubtitles.com
   - Username: Your OpenSubtitles username (create at opensubtitles.com)
   - Password: Your OpenSubtitles password
   - Click "Add"
   - **Note**: Free tier has daily download limits; best for hash-matching

2. **Gestdown** (Addic7ed proxy - no account needed)
   - Click "Add" → Gestdown
   - No configuration needed
   - Click "Add"
   - **Note**: Proxies Addic7ed with caching, avoids rate limits. Best for TV shows

3. **Podnapisi** (No configuration needed)
   - Click "Add" → Podnapisi
   - No configuration needed
   - Click "Add"
   - **Note**: Good quality, reliable

### Anime Providers

Anime providers require AniDB integration to look up anime IDs.

**Step 1: Register an AniDB HTTP API Client** <!-- markdownlint-disable-line MD036 -->

1. Create an account at [anidb.net](https://anidb.net) if needed
2. Log in and go to [API Client Page](http://anidb.net/perl-bin/animedb.pl?show=client)
3. Click **Add New Project** tab
4. Enter a project name (e.g., "mybazarr") → click **+ Add Project**
5. On the project page, click **Add Client** (top right)
6. Enter a unique client name (e.g., "mybazarrclient")
7. Set Version to `1` → click **Add Client**

**Step 2: Configure AniDB Integration in Bazarr** <!-- markdownlint-disable-line MD036 -->

**Settings → Providers → Integrations** <!-- markdownlint-disable-line MD036 -->

1. Find the **AniDB** section
2. **Client**: Your client name in **lowercase** (e.g., `mybazarrclient`)
3. **Client Version**: `1` (or the version you registered)

> **Important:** The client name must be lowercase regardless of how AniDB displays it.

**Step 3: Enable Anime Providers** <!-- markdownlint-disable-line MD036 -->

1. **Animetosho** (Anime subtitles)
   - Click "Add" → Animetosho
   - Search Threshold: `6` (default, increase if missing subtitles)
   - Click "Enable"
   - **Note**: Skips non-anime content; other providers still work for those

2. **Jimaku** (Japanese subtitles - requires free API key)
   - Create account at [jimaku.cc](https://jimaku.cc)
   - Go to account settings → API section → generate API key
   - Click "Add" → Jimaku.cc
   - **API key**: Paste your Jimaku API key
   - **Search by name if no AniList ID**: ✅ Enabled (recommended for better coverage)
   - Click "Enable"
   - **Note**: Good for Japanese fansubs; subtitles may have quality/timing variations

### AI-Generated Subtitles (Optional)

1. **Whisper** (Self-hosted AI transcription/translation)
   - Requires running [SubGen](https://github.com/McCloudS/subgen) container
   - Click "Add" → Whisper
   - Endpoint: `http://<subgen-host>:9000` (adjust to your setup)
   - Timeout: `3600` (1 hour - needed for long movies)
   - Click "Add"
   - **Note**: Generates subtitles from audio when providers fail. Can translate Japanese
     audio to English. Lower scores (~67% episodes, ~51% movies) - adjust minimum score
     if using as fallback

### Provider Priority

Drag providers to set priority (top = highest priority):

**Recommended order:**

1. OpenSubtitles.com (largest database, hash matching)
2. Gestdown (high-quality TV show subs via Addic7ed)
3. Animetosho (anime-specific)
4. Jimaku (anime-specific)
5. Podnapisi (reliable general provider)
6. Whisper (fallback - generates from audio)

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
4. For anime: Verify Sonarr has AniDB IDs (Animetosho needs this)

### Whisper Not Being Used

Whisper generates subtitles with lower scores (~67% for episodes, ~51% for movies).
If Whisper subtitles aren't downloading automatically:

1. Lower minimum score to `50` in **Settings → Sonarr/Radarr**
2. Or manually search and select Whisper results

### Connection Errors to Sonarr/Radarr

1. Verify API keys are correct
2. Check hostname is `localhost` (not Tailscale hostname)
3. Test connection: **Settings → Sonarr/Radarr** → "Test" button

### Wrong Language Downloaded

1. Check language profile: **Settings → Languages**
2. Verify "Single Language" is enabled
3. Clear cache: **System → Tasks** → "Clear All Subtitles Cache"

### Anime Subtitles Not Found

1. Ensure Animetosho and Jimaku providers are enabled
2. Verify Sonarr is using AniDB metadata (helps Animetosho matching)
3. Try manual search - anime releases often have specific naming

---

**Status**: Ready for configuration
**Next Steps**: Follow steps 1-8 to complete Bazarr setup

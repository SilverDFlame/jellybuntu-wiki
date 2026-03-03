# Huntarr Configuration Guide

Complete setup guide for Huntarr - automated missing content discovery.

**Access**: http://media-services.discus-moth.ts.net:9705

---

## What is Huntarr?

Huntarr automatically finds:

- **Missing episodes** from monitored series
- **Sequels/prequels** to movies you already have
- **Related content** from the same franchise
- **Content from the same actors/directors**

It scans your Sonarr/Radarr libraries and automatically adds missing content to your monitored lists.

---

## 1. Initial Access

1. Navigate to: http://media-services.discus-moth.ts.net:9705
2. You may see a login screen or go directly to the dashboard
3. Default credentials (if prompted):
   - **Username**: `admin` (check documentation)
   - **Password**: `admin` (change immediately)

---

## 2. Connect to Sonarr

**Settings → Sonarr** <!-- markdownlint-disable-line MD036 -->

1. Click "Add Sonarr Instance" or similar
2. Configure:
   - **Name**: Sonarr
   - **Hostname/IP**: `localhost`
   - **Port**: `8989`
   - **Base URL**: Leave empty
   - **API Key**: Copy from Sonarr → Settings → General → Security → API Key
   - **Use SSL**: ❌ Disabled (localhost connection)
3. Click "Test" to verify connection
4. Click "Save"

---

## 3. Connect to Radarr

**Settings → Radarr** <!-- markdownlint-disable-line MD036 -->

1. Click "Add Radarr Instance" or similar
2. Configure:
   - **Name**: Radarr
   - **Hostname/IP**: `localhost`
   - **Port**: `7878`
   - **Base URL**: Leave empty
   - **API Key**: Copy from Radarr → Settings → General → Security → API Key
   - **Use SSL**: ❌ Disabled (localhost connection)
3. Click "Test" to verify connection
4. Click "Save"

---

## 4. ⚠️ Configure Automatic Scheduling (CRITICAL)

**Settings → Scheduling** <!-- markdownlint-disable-line MD036 -->

**⚠️ IMPORTANT**: Without a schedule configured, Huntarr will NOT automatically search for missing episodes! This is the
most commonly missed configuration step.

### Create a Daily Search Schedule

1. Navigate to **Settings** → **Scheduling**
2. In the **"Add New Schedule"** section:
   - **Time**: Set the hour and minute (e.g., `03:00` for 3 AM)
   - **Frequency**: Click **"Daily (All Days)"**
   - **Action**: Select **"Enable"**
   - **App**: Select **"All Apps (Global)"** (searches both Sonarr and Radarr)
3. Click **"+ Add Schedule"** button
4. Verify the schedule appears in **"Current Schedules"** below

**Recommended Schedule**:

```text
Time: 03:00 (3 AM - low traffic time)
Frequency: Daily (All Days)
Action: Enable
App: All Apps (Global)
```

**Why This Matters**:

- RSS feeds in Sonarr/Radarr only catch NEW releases (last 24-48 hours)
- Backlog episodes from older series require active searching
- Without this schedule, Huntarr only runs when manually triggered
- This schedule makes Huntarr search for ALL missing content daily

**Verify Scheduling Works**:

- After saving, check **Main** → **Hunt Manager**
- Look at **"How Long Ago"** column - should update after scheduled run
- Check **Home** dashboard for **"Live Hunts Executed"** counter

---

## 5. Configure Search Settings (Optional)

**Settings → Search** (or similar section)

*Note: These settings may not be available in all Huntarr versions. If you don't see them, the scheduling configured in
Step 4 is sufficient.*

### General Search Settings

- **Search Interval**: Controlled by schedule in Step 4
- **Search Depth**: `Medium` (balance between thoroughness and speed)
- **Auto-Add to Monitored**: ✅ Enabled (automatically monitor found content)
- **Minimum Score**: `70%` (minimum match confidence to add content)

### Content Discovery Options

- **Find Missing Episodes**: ✅ Enabled
- **Find Sequels/Prequels**: ✅ Enabled
- **Find Franchise Content**: ✅ Enabled (Star Wars, Marvel, etc.)
- **Find Similar Content**: ❌ Disabled (can be overwhelming)
- **Find Actor Collections**: ❌ Disabled (optional - can add a lot of content)

---

## 6. Configure Quality Profiles (Optional)

**Settings → Quality** (or similar)

### Sonarr Quality Profile

- **Default Profile**: `WEB-2160p + 1080p` (match your Sonarr profile)
- **Upgrade Allowed**: ✅ Enabled

### Radarr Quality Profile

- **Default Profile**: `UHD Bluray + WEB` (match your Radarr profile)
- **Upgrade Allowed**: ✅ Enabled

---

## 7. Configure Notifications (Optional)

**Settings → Notifications** <!-- markdownlint-disable-line MD036 -->

### Notification Events

- **Content Added**: ✅ Enabled
- **Content Downloaded**: ❌ Disabled (Sonarr/Radarr handle this)
- **Errors**: ✅ Enabled

### Notification Methods

Choose your preferred method:

- **Discord**: Webhook URL
- **Slack**: Webhook URL
- **Email**: SMTP settings
- **Pushover**: API key + User key

---

## 8. Initial Library Scan

After configuration:

1. Go to **Dashboard** or **Library**
2. Click "Scan Library" or "Sync Now"
3. Wait for initial scan to complete (may take 10-30 minutes depending on library size)
4. Review discovered content in **Discovered** or **Found Content** section

---

## 9. Review Discovered Content

**Discovered Content Section**:

### For Each Found Item

1. **Review Match**: Verify it's correct content
2. **Check Score**: Higher score = better match
3. **Actions**:
   - ✅ **Add to Monitored**: Automatically add to Sonarr/Radarr
   - ⏭️ **Skip**: Ignore this content
   - 🚫 **Ignore Forever**: Never suggest again

### Bulk Actions

- **Add All Above Score**: Add all content with score > X%
- **Skip All Below Score**: Ignore content with score < X%

---

## 10. Automated Operation

Once configured, Huntarr runs automatically:

1. **Scheduled searches** run daily (from Step 4)
2. **Scans** your Sonarr/Radarr libraries for missing content
3. **Identifies** missing episodes, sequels, and franchise content
4. **Triggers searches** in Sonarr/Radarr for missing items
5. **Sonarr/Radarr** use Prowlarr to find releases
6. **Download clients** grab the content
7. **Repeat** on the next scheduled run

---

## 11. Fine-Tuning

### If Too Much Content is Added

- Increase **Minimum Score** to 80-90%
- Disable **Find Franchise Content**
- Disable **Find Similar Content**
- Change **Auto-Add** to manual approval

### If Missing Content You Want

- Decrease **Minimum Score** to 60-70%
- Enable **Find Similar Content**
- Increase **Search Depth** to High
- Manually search for specific franchises

### If Scans Take Too Long

- Decrease **Search Depth** to Low
- Disable **Find Actor Collections**
- Run schedule less frequently (every 2-3 days)

---

## 12. Common Use Cases

### Example 1: Find Missing MCU Movies

1. Go to **Search** or **Franchises**
2. Search for "Marvel Cinematic Universe"
3. Review found content
4. Add all missing MCU movies to Radarr

### Example 2: Complete TV Series

1. Huntarr automatically detects partially downloaded series
2. Triggers searches in Sonarr for missing episodes
3. Sonarr downloads automatically via Prowlarr

### Example 3: Find Sequels

1. Huntarr scans your movie library
2. Identifies movies with sequels/prequels you don't have
3. Triggers searches in Radarr for them

---

## 13. Verify Operation

**Check Dashboard**:

- **Last Scan**: Timestamp of most recent scan
- **Content Found**: Number of items discovered
- **Searches Triggered**: Number of searches sent to Sonarr/Radarr
- **Errors**: Any connection or API issues

**Check Hunt Manager**:

- **Main** → **Hunt Manager**
- Review **"How Long Ago"** column for each series/movie
- Verify scheduled runs are occurring daily

**Expected Behavior**:

- Huntarr runs searches daily at scheduled time (e.g., 3 AM)
- Discovers missing content based on your library
- Triggers automatic searches in Sonarr/Radarr
- Missing episodes appear in Sonarr/Radarr and start downloading

---

## Integration with Sonarr/Radarr

Huntarr works seamlessly with your existing setup:

1. ✅ **Huntarr** → Identifies missing content
2. ✅ **Sonarr/Radarr** → Adds to monitored lists
3. ✅ **Prowlarr** → Searches indexers
4. ✅ **qBittorrent/SABnzbd** → Downloads content
5. ✅ **Sonarr/Radarr** → Organizes and renames files
6. ✅ **Jellyfin** → Streams content

**No additional configuration needed in Sonarr/Radarr!**

---

## Troubleshooting

### Huntarr Not Searching Automatically (MOST COMMON)

**Symptoms**: Missing episodes not being found, no automatic searches happening

**Diagnosis**:

1. Navigate to **Settings** → **Scheduling**
2. Check **"Current Schedules"** section at the bottom
3. If empty: No schedule configured!

**Solution**:

1. Follow **Step 4** above to create a daily schedule
2. Set time to 3 AM (or your preferred time)
3. Frequency: Daily (All Days)
4. App: All Apps (Global)
5. Verify schedule appears in "Current Schedules"

**Why This Happens**:

- Huntarr does NOT come with a default schedule
- RSS sync in Sonarr only catches NEW releases (24-48 hours)
- Backlog episodes require Huntarr's scheduled searches
- Without a schedule, Huntarr only runs when manually triggered

### Connection Errors

1. Verify API keys are correct
2. Check hostname is `localhost` (not Tailscale hostname)
3. Ensure Sonarr/Radarr are running
4. Test connection in Settings

### No Content Found (After Schedule is Configured)

1. Check **Search Depth** is not set to Low
2. Verify **Minimum Score** is not too high (>90%)
3. Enable more discovery options (Franchise, Similar)
4. Manually trigger a library scan

### Too Much Content Added

1. Increase **Minimum Score** to 80%+
2. Disable **Auto-Add to Monitored**
3. Review and manually approve suggestions
4. Disable **Find Similar Content**

### Duplicate Content

1. Huntarr checks existing library before adding
2. If duplicates occur, check Sonarr/Radarr settings
3. Verify content matching settings are correct

---

## Recommended Settings Summary

**Conservative Setup** (less content, higher quality):

```text
Search Interval: 24 hours
Search Depth: Medium
Auto-Add: Enabled
Minimum Score: 85%
Find Missing Episodes: ✅ Enabled
Find Sequels/Prequels: ✅ Enabled
Find Franchise: ❌ Disabled
Find Similar: ❌ Disabled
```

**Aggressive Setup** (more content, completionist):

```text
Search Interval: 12 hours
Search Depth: High
Auto-Add: Enabled
Minimum Score: 70%
Find Missing Episodes: ✅ Enabled
Find Sequels/Prequels: ✅ Enabled
Find Franchise: ✅ Enabled
Find Similar: ✅ Enabled
```

---

**Status**: Ready for configuration
**Next Steps**: Follow steps 1-8 to complete Huntarr setup
**Recommended Approach**: Start with Conservative settings, adjust based on results

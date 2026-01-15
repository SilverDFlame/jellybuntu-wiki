# Tdarr Transcode Profiles Guide

Step-by-step guide for creating Tdarr flows using the actual Tdarr UI plugins.

## Quality Standards Summary

Based on `configs/recyclarr-config.yml`:

### Sonarr (TV Shows) - WEB-2160p + 1080p

- **Primary**: 2160p (4K) and 1080p
- **Fallback**: 720p accepted
- **Upgrade path**: Up to Bluray-2160p
- **HDR**: No preference (may receive both HDR and SDR 4K content)

### Radarr (Movies) - UHD Bluray + WEB

- **Primary**: 2160p (4K UHD) and 1080p
- **HDR**: Preferred (+600 score) - **MUST PRESERVE**
- **IMAX**: Preferred (+800 score)
- **Fallback**: 720p accepted

## Tdarr Strategy

### Core Principles

1. **Never downscale** - Keep 2160p as 2160p, 1080p as 1080p
2. **Preserve HDR when present** - Critical for HDR content from any resolution
3. **Branch on HDR status** - Apply 10-bit and HDR params only to actual HDR content
4. **Target codec**: H.265 (HEVC) for 60% smaller files vs H.264
5. **Skip optimized content** - Don't re-transcode H.265 files
6. **Preserve audio** - Copy all tracks unless transcoding needed

### 4-Branch Architecture

The unified flow handles all content types:

| Branch | Resolution | HDR | 10-Bit | HDR Params | CRF |
|--------|------------|-----|--------|------------|-----|
| 4K HDR | 2160p | Yes | Yes | Yes | 23 |
| 4K SDR | 2160p | No | No | No | 23 |
| 1080p HDR | 1080p | Yes | Yes | Yes | 21 |
| 1080p SDR | 1080p | No | No | No | 21 |

**Why this matters:**

- SDR content gets ~10-15% smaller files without unnecessary 10-bit encoding
- 1080p HDR content (rare but exists) gets proper HDR preservation
- Each content type uses optimal settings

## How Tdarr Flows Work

Flows use a plugin-based system where you drag and drop plugins to build processing logic:

1. **Check plugins** (orange `?` icon) - Filter files based on properties
2. **FFmpegCommand plugins** (gear icon) - Build the transcode command
3. **Execute plugin** - Run the FFmpeg command
4. **Tool plugins** - Additional logic (comments, variables, etc.)

Each check plugin has two branches:

- **Green arrow** (✓) - Condition is TRUE, continue
- **Red arrow** (✗) - Condition is FALSE, skip or go to different branch

---

## Flow 1: 4K UHD H.265 (HDR and SDR Branches)

**Purpose**: Transcode 4K content to H.265 with proper handling for both HDR and SDR content

### Flow Configuration

- **Name**: `4K UHD - H.265 with HDR/SDR Branching`
- **Libraries**: TV Shows and Movies
- **Enable**: After testing

### Step-by-Step Plugin Setup

#### Step 1: Check Video Resolution = 4K

- **Plugin**: `Check Video Resolution` (Video section, orange `?`)
- **Config**: Default (enabled)
- **Branch logic** (plugin has 9 outputs):
  - **Output 6: "File is 4KUHD"** → Connect to Check Video Codec
  - All other outputs → Leave unconnected or route to 1080p branch

#### Step 2: Check Video Codec ≠ H.265

- **Plugin**: `Check Video Codec` (Video section, orange `?`)
- **Config**:
  - Codecs to check: `hevc, h265`
  - Invert match: `Yes` (so it triggers if NOT H.265)
- **Branch logic**:
  - **Output #2 (does not have codec)**: Continue to HDR check
  - **Output #1 (has codec)**: End flow (skip, already optimized)

#### Step 3: Check HDR Video (BRANCHING - Critical!)

- **Plugin**: `Check HDR Video` (Video section, orange `?`)
- **Config**: Default (detects HDR10, HDR10+, Dolby Vision)
- **Branch logic**:
  - **Output #1 (is HDR)**: → Route to 4K HDR encoding path
  - **Output #2 (is not HDR)**: → Route to 4K SDR encoding path

**IMPORTANT**: This plugin MUST branch to different paths, not just detect!

---

### 4K HDR Path (Output #1 from Check HDR Video)

#### Step 4a: Begin FFmpeg Command - 4K HDR

- **Plugin**: `Begin Command` (FFmpegCommand section, gear icon)

#### Step 5a: Set Video Encoder - 4K HDR

- **Plugin**: `Set Video Encoder`
- **Config**:
  - Encoder: `libx265`
  - Preset: `medium`
  - CRF: `23`

#### Step 6a: Enable 10-Bit Video

- **Plugin**: `10 Bit Video` (FFmpegCommand section, gear icon)
- **Config**: Enable (REQUIRED for HDR - preserves 10-bit color depth)

#### Step 7a: Add Custom Arguments for HDR

- **Plugin**: `Custom Arguments` (FFmpegCommand section, gear icon)
- **Config**: Add these arguments:

  ```text
  -pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc"
  ```

  - **Critical**: These parameters preserve HDR metadata
  - Connect output → Shared plugins (Set Container)

---

### 4K SDR Path (Output #2 from Check HDR Video)

#### Step 4b: Begin FFmpeg Command - 4K SDR

- **Plugin**: `Begin Command` (FFmpegCommand section, gear icon)

#### Step 5b: Set Video Encoder - 4K SDR

- **Plugin**: `Set Video Encoder`
- **Config**:
  - Encoder: `libx265`
  - Preset: `medium`
  - CRF: `23`
  - **NO 10-Bit Video plugin** (standard 8-bit for SDR)
  - **NO HDR Custom Arguments** (not needed for SDR)
  - Connect output → Shared plugins (Set Container)

---

### Shared Plugins (Both 4K paths merge here)

#### Set Container

- **Plugin**: `Set Container` (FFmpegCommand section, gear icon)
- **Config**: `.mkv` (best for preserving all tracks)

#### Custom Arguments (-sn)

- **Plugin**: `Custom Arguments`
- **Config**: `-sn` (excludes subtitles to prevent WebVTT errors)

#### Execute FFmpeg Command

- **Plugin**: `Execute` (FFmpegCommand section, play icon `▶`)

#### Replace Original File

- **Plugin**: `Replace Original File` (File section, green arrow)

### Expected Results

**4K HDR:**

- **Input**: 4K HDR H.264 file (~40GB)
- **Output**: 4K H.265 file (~25GB, 60-70% size)
- **HDR**: Fully preserved with 10-bit color

**4K SDR:**

- **Input**: 4K SDR H.264 file (~35GB)
- **Output**: 4K H.265 file (~20GB, 60-70% size)
- **Note**: ~10-15% smaller than HDR due to 8-bit encoding

---

## Flow 2: 1080p H.265 (HDR and SDR Branches)

**Purpose**: Transcode 1080p content to H.265 with proper handling for both HDR and SDR content

### Flow Configuration

- **Name**: `1080p FHD - H.265 with HDR/SDR Branching`
- **Libraries**: TV Shows and Movies
- **Enable**: After 4K flow tested

### Step-by-Step Plugin Setup

#### Step 1: Check Video Resolution = 1080p

- **Plugin**: `Check Video Resolution`
- **Config**: Resolution: `1080p`
- **Branch logic**:
  - **Output #4 (1080p)**: Continue to Check Video Codec
  - Other outputs: Route elsewhere or leave unconnected

#### Step 2: Check Video Codec ≠ H.265

- **Plugin**: `Check Video Codec`
- **Config**:
  - Codecs: `hevc, h265`
  - Invert: `Yes`
- **Branch logic**:
  - **Output #2 (does not have codec)**: Continue to HDR check
  - **Output #1 (has codec)**: End flow (skip, already optimized)

#### Step 3: Check HDR Video (BRANCHING - Critical!)

- **Plugin**: `Check HDR Video` (Video section, orange `?`)
- **Config**: Default (detects HDR10, HDR10+, Dolby Vision)
- **Branch logic**:
  - **Output #1 (is HDR)**: → Route to 1080p HDR encoding path
  - **Output #2 (is not HDR)**: → Route to 1080p SDR encoding path

**Note**: 1080p HDR content is rare but exists (some streaming services, anime). Must handle properly!

---

### 1080p HDR Path (Output #1 from Check HDR Video)

#### Step 4a: Begin FFmpeg Command - 1080p HDR

- **Plugin**: `Begin Command`

#### Step 5a: Set Video Encoder - 1080p HDR

- **Plugin**: `Set Video Encoder`
- **Config**:
  - Encoder: `libx265`
  - Preset: `medium`
  - CRF: `21`

#### Step 6a: Enable 10-Bit Video

- **Plugin**: `10 Bit Video`
- **Config**: Enable (REQUIRED for HDR - preserves 10-bit color depth)

#### Step 7a: Add Custom Arguments for HDR

- **Plugin**: `Custom Arguments`
- **Config**: Add these arguments:

  ```text
  -pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -x265-params "hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc"
  ```

  - Connect output → Shared plugins (Set Container)

---

### 1080p SDR Path (Output #2 from Check HDR Video)

#### Step 4b: Begin FFmpeg Command - 1080p SDR

- **Plugin**: `Begin Command`

#### Step 5b: Set Video Encoder - 1080p SDR

- **Plugin**: `Set Video Encoder`
- **Config**:
  - Encoder: `libx265`
  - Preset: `medium`
  - CRF: `21`
  - **NO 10-Bit Video plugin** (standard 8-bit for SDR)
  - **NO HDR Custom Arguments** (not needed for SDR)
  - Connect output → Shared plugins (Set Container)

---

### Shared Plugins (Both 1080p paths merge here)

#### Set Container

- **Plugin**: `Set Container`
- **Config**: `.mkv`

#### Custom Arguments (-sn)

- **Plugin**: `Custom Arguments`
- **Config**: `-sn` (excludes subtitles to prevent WebVTT errors)

#### Execute

- **Plugin**: `Execute`

#### Replace Original File

- **Plugin**: `Replace Original File`

### Expected Results

**1080p HDR:**

- **Input**: 1080p HDR H.264 (~15GB)
- **Output**: 1080p H.265 (~8GB, 50-60% size)
- **HDR**: Fully preserved with 10-bit color

**1080p SDR:**

- **Input**: 1080p SDR H.264 (~12GB)
- **Output**: 1080p H.265 (~6GB, 50-60% size)
- **Note**: Slightly smaller than HDR due to 8-bit encoding

---

## Flow 3: 720p - Skip Recommended

**Recommendation**: Don't create this flow. 720p files are already small, and transcoding provides minimal benefit.
Focus processing power on 4K and 1080p content.

If you must transcode 720p:

- Use same plugins as Flow 2
- Change resolution check to `720p`
- Increase CRF to `23` (lower quality acceptable for 720p)

---

## Quality Settings Comparison

### CRF (Constant Rate Factor) Guide

For **H.265 (x265)**:

- **CRF 18**: Visually lossless (~30-40% compression)
- **CRF 21**: Excellent quality, recommended for 1080p (~50% compression)
- **CRF 23**: Good quality, recommended for 4K (~60% compression)
- **CRF 25**: Acceptable quality (~70% compression)
- **CRF 28**: Noticeable quality loss (not recommended)

**Rule of thumb**: Lower CRF = higher quality + larger file

### Preset Guide

- **Ultrafast**: Fastest encode, largest file, worst compression
- **Superfast**: Very fast
- **Veryfast**: Fast
- **Faster**: Balanced speed
- **Fast**: Good balance
- **Medium**: **Recommended** - Best balance of speed/quality/size
- **Slow**: Better compression, 2-3x slower than medium
- **Slower**: Best compression, 4-5x slower than medium
- **Veryslow**: Marginal improvement, 6-8x slower

**Recommendation**: Use `medium` preset. Going slower provides minimal benefit for significant time cost.

---

## Example: Recommended 4K Setup

For your Jellyfin VM (4 cores, 8GB RAM), start conservatively:

### Initial Configuration

- **Concurrent transcodes**: `1` (adjust after monitoring)
- **Health check interval**: `30 seconds`
- **Process file size limit**: `No limit`
- **Transcode cache**: `/opt/jellyfin/tdarr/temp`

### Worker Settings (Tdarr Node)

- **Transcode threads**: `2` (leaves 2 cores for Jellyfin)
- **Health check threads**: `2`
- **Transcode nice level**: `10` (lower priority)

### Scheduling (Optional)

If CPU impact is too high during day:

- **Schedule**: `02:00-06:00` (off-peak hours)
- **Pause transcode**: Outside schedule window

---

## Library Configuration

### TV Shows Library

- **Source**: `/media/tv`
- **Enabled flows**:
  - 4K UHD - H.265 with HDR
  - 1080p FHD - H.265
- **File pattern**: `**/*.{mkv,mp4,avi}`
- **Rescan interval**: `24 hours`

### Movies Library

- **Source**: `/media/movies`
- **Enabled flows**:
  - 4K UHD - H.265 with HDR (HIGH PRIORITY)
  - 1080p FHD - H.265
- **File pattern**: `**/*.{mkv,mp4,avi}`
- **Rescan interval**: `24 hours`

**Important**: Movies library should prioritize HDR preservation flow.

---

## Testing Workflow

Before enabling on full library:

### 1. Test Single File

- Select a large 4K H.264 file (>10GB)
- Manually trigger transcode
- Verify:
  - File size reduced
  - Quality maintained (spot check)
  - HDR preserved (if applicable)
  - Playback works in Jellyfin

### 2. Test Small Batch

- Enable flow on single library
- Limit to 5-10 files
- Monitor:
  - CPU usage (should stay <80% per core)
  - Memory usage (node should stay <2GB)
  - Transcode time (note for planning)
  - VM stability

### 3. Monitor First 24 Hours

- Check VM memory: `ssh ansible@jellyfin "free -h"`
- Check container stats: `ssh ansible@jellyfin "docker stats --no-stream tdarr-node"`
- Check transcode logs in Tdarr UI
- Verify Jellyfin playback unaffected

### 4. Scale Up

- If stable, enable on full libraries
- Adjust concurrent transcodes if needed (can go to 2 if resources allow)
- Consider scheduling for off-peak hours

---

## Storage Savings Estimate

Based on typical compression ratios:

### TV Shows (assuming mix of 1080p and 4K)

- **Original**: 10TB of H.264 content
- **After transcode**: ~5-6TB (40-50% reduction)
- **Savings**: 4-5TB

### Movies (assuming mostly 4K HDR)

- **Original**: 20TB of H.264/H.264 content
- **After transcode**: ~12-14TB (30-40% reduction)
- **Savings**: 6-8TB

**Note**: Already-compressed H.265 files won't be re-transcoded, so actual savings depend on your current library composition.

---

## Troubleshooting

### HDR Content Looks Washed Out After Transcode

- **Cause**: HDR metadata not preserved
- **Fix**: Use FFmpeg with full HDR parameters (see Flow 1)
- **Verify**: Check file properties in Jellyfin or MediaInfo

### Transcode Too Slow

- **Cause**: Preset too slow or CRF too low
- **Fix**:
  - Change preset from `medium` to `fast`
  - Increase CRF from 23 to 25 (slightly lower quality)
  - Enable hardware acceleration if available

### File Larger After Transcode

- **Cause**: Source already well-compressed or CRF too low
- **Fix**:
  - Enable quality check plugin (auto-revert)
  - Increase CRF value
  - Skip files that don't benefit from transcode

### Jellyfin Won't Play Transcoded Files

- **Cause**: Missing codecs or incompatible container
- **Fix**:
  - Ensure output format is `.mkv` or `.mp4`
  - Check FFmpeg version (should be 6.0+)
  - Verify all audio/subtitle tracks copied

---

## Performance Expectations

### Transcode Speed (Approximate)

On Jellyfin VM (4-core, performance mode):

| Resolution | CRF | Preset | Speed (FPS) | Time for 2hr Movie |
|-----------|-----|--------|-------------|-------------------|
| 2160p (4K) | 23 | medium | 10-15 FPS | 5-8 hours |
| 1080p | 21 | medium | 30-50 FPS | 1.5-2.5 hours |
| 720p | 23 | medium | 60-100 FPS | 30-60 minutes |

**Note**: Actual speeds depend on source complexity (action scenes slower than dialogue).

### Daily Processing Capacity

With 1 concurrent transcode, 24/7:

- **4K content**: 3-5 movies per day (6-8 hours each)
- **1080p content**: 8-12 movies per day (2-3 hours each)
- **Mixed**: ~4-6TB processed per week

With off-peak scheduling (4 hours/night):

- **4K content**: ~1 movie per night
- **1080p content**: 2-3 movies per night

---

## Maintenance

### Weekly Checks

- Review transcode queue status
- Check error logs for failed transcodes
- Verify storage savings (Tdarr statistics page)
- Monitor VM resource usage trends

### Monthly Review

- Evaluate CRF settings based on quality vs size trade-off
- Consider adjusting concurrent transcodes if resources stable
- Review and optimize flows based on patterns

### When to Pause Transcoding

- Heavy Jellyfin usage (family movie night)
- System updates or maintenance
- High VM resource usage from other services

---

## Additional Resources

- **Tdarr Documentation**: https://docs.tdarr.io/
- **FFmpeg H.265 Guide**: https://trac.ffmpeg.org/wiki/Encode/H.265
- **TRaSH Guides**: https://trash-guides.info/ (reference for quality)
- **HDR Metadata Guide**: https://x265.readthedocs.io/en/stable/cli.html

---

## Quick Reference: Recommended Settings

### 4K HDR Content

```bash
Codec: H.265 (libx265)
Preset: medium
CRF: 23
Pixel Format: yuv420p10le
HDR: Preserve (full parameters in Flow 1)
```

### 1080p Content

```bash
Codec: H.265 (libx265)
Preset: medium
CRF: 21
Pixel Format: yuv420p
```

### Worker Configuration

```bash
Concurrent transcodes: 1
Transcode threads: 2
Nice level: 10
Health check interval: 30s
```

# Tdarr Flow Configuration - Media Optimization

**Flow Name**: `Media Optimization - H.265 with HDR`

Complete configuration for the 4-branch flow that handles HDR and SDR content at both 4K and 1080p resolutions.

## Flow Overview

This flow uses a **4-branch architecture** that:

1. Checks video resolution (4K vs 1080p)
2. Checks HDR status within each resolution branch
3. Routes to appropriate encoder settings based on both resolution AND HDR status
4. Preserves HDR metadata only for actual HDR content (reduces file size for SDR)
5. Merges all branches back to shared container/execution plugins

### Why 4 Branches?

| Branch | 10-Bit | HDR Params | CRF | Use Case |
|--------|--------|------------|-----|----------|
| 4K HDR | Yes | Yes | 23 | Most 4K movies (Radarr HDR +600 score) |
| 4K SDR | No | No | 23 | Some 4K TV shows (Sonarr no HDR preference) |
| 1080p HDR | Yes | Yes | 21 | Rare streaming content, anime |
| 1080p SDR | No | No | 21 | Most 1080p content |

**Benefits of proper branching:**

- SDR content doesn't get unnecessary 10-bit encoding (~10-15% smaller files)
- 1080p HDR content (rare but exists) gets proper HDR preservation
- Each content type uses optimal encoder settings

## Complete Plugin List (in order)

### Initial Processing

1. **Input File** - Entry point (receives files from queue)
   - **CRITICAL**: This node is required for any flow to work
   - Drag from "Flow Plugins > Input/Output" section
   - This must be the very first node in your flow
2. **Comment** - Documentation
3. **Check Video Resolution** - Routes files based on resolution

### 4K Branch

1. **Check Video Codec - 4K** - Skip if already H.265
2. **Check HDR Video - 4K** - Detect HDR content and branch accordingly

#### 4K HDR Sub-Branch

1. **FFmpeg Command: Begin Command - 4K HDR** - Start building FFmpeg command
2. **FFmpeg Command: Set Video Encoder - 4K HDR** - Configure H.265 encoding
   - Encoder: `hevc`
   - Preset: `medium`
   - CRF: `23`
3. **FFmpeg Command: 10 Bit Video** - Preserve 10-bit color depth (required for HDR)
4. **FFmpeg Command: Custom Arguments - 4K HDR** - HDR metadata preservation
   - Output Arguments: `-pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc
     -x265-params hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc`

#### 4K SDR Sub-Branch

1. **FFmpeg Command: Begin Command - 4K SDR** - Start building FFmpeg command
2. **FFmpeg Command: Set Video Encoder - 4K SDR** - Configure H.265 encoding
   - Encoder: `hevc`
   - Preset: `medium`
   - CRF: `23`
   - (No 10 Bit Video plugin - standard 8-bit for SDR)
   - (No HDR Custom Arguments - not needed for SDR)

### 1080p Branch

1. **Check Video Codec - 1080p** - Skip if already H.265
2. **Check HDR Video - 1080p** - Detect HDR content and branch accordingly

#### 1080p HDR Sub-Branch

1. **FFmpeg Command: Begin Command - 1080p HDR** - Start building FFmpeg command
2. **FFmpeg Command: Set Video Encoder - 1080p HDR** - Configure H.265 encoding
   - Encoder: `hevc`
   - Preset: `medium`
   - CRF: `21`
3. **FFmpeg Command: 10 Bit Video** - Preserve 10-bit color depth (required for HDR)
4. **FFmpeg Command: Custom Arguments - 1080p HDR** - HDR metadata preservation
   - Output Arguments: `-pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc
     -x265-params hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc`

#### 1080p SDR Sub-Branch

1. **FFmpeg Command: Begin Command - 1080p SDR** - Start building FFmpeg command
2. **FFmpeg Command: Set Video Encoder - 1080p SDR** - Configure H.265 encoding
   - Encoder: `hevc`
   - Preset: `medium`
   - CRF: `21`
   - (No 10 Bit Video plugin - standard 8-bit for SDR)
   - (No HDR Custom Arguments - not needed for SDR)

### Shared Plugins (All 4 Branches Merge Here)

1. **FFmpeg Command: Set Container** - Set output format
    - Container: `.mkv`
2. **FFmpeg Command: Custom Arguments** - Handle streams incompatible with MKV container
    - Output Arguments: `-map_chapters 0 -dn -sn`
3. **FFmpeg Command: Execute** - Run the FFmpeg command
4. **Replace Original File** - Replace source with transcoded file

**Note on Custom Arguments**: These flags handle streams that are incompatible with the Matroska container:

- `-map_chapters 0` - Preserves chapter markers by converting to MKV-native format
- `-dn` - Skips data streams (bin_data chapters, attached pictures) that cause muxer errors
- `-sn` - Skips subtitle streams (WebVTT codec incompatible with MKV)

Without these flags, MP4 files containing data streams (common in anime/PTerWEB releases) fail with:
`Only audio, video, and subtitles are supported for Matroska.`

Bazarr automatically re-downloads subtitles as external `.srt` files within ~9 hours of transcoding
(see "Subtitle Management Strategy" section below). Audio streams are automatically copied. Embedded cover art is lost
but Jellyfin uses external/scraped artwork anyway.

## Connection Map

### Entry Point

- **Input File** output → **Comment** input (flow starts here)

### Resolution Routing

- **Comment** output → **Check Video Resolution** input
- **Check Video Resolution** output #6 (4KUHD) → **Check Video Codec - 4K** input
- **Check Video Resolution** output #4 (1080p) → **Check Video Codec - 1080p** input

### 4K Branch Connections

- **Check Video Codec - 4K** output #2 (does not have codec) → **Check HDR Video - 4K** input

**4K HDR Path:**

- **Check HDR Video - 4K** output #1 (is HDR) → **Begin Command - 4K HDR** input
- **Begin Command - 4K HDR** → **Set Video Encoder - 4K HDR** → **10 Bit Video** → **Custom Arguments (4K HDR)**
- **Custom Arguments (4K HDR)** output → **Set Container** input

**4K SDR Path:**

- **Check HDR Video - 4K** output #2 (is not HDR) → **Begin Command - 4K SDR** input
- **Begin Command - 4K SDR** → **Set Video Encoder - 4K SDR**
- **Set Video Encoder - 4K SDR** output → **Set Container** input

### 1080p Branch Connections

- **Check Video Codec - 1080p** output #2 (does not have codec) → **Check HDR Video - 1080p** input

**1080p HDR Path:**

- **Check HDR Video - 1080p** output #1 (is HDR) → **Begin Command - 1080p HDR** input
- **Begin Command - 1080p HDR** → **Set Video Encoder - 1080p HDR** → **10 Bit Video** → **Custom Arguments (1080p HDR)**
- **Custom Arguments (1080p HDR)** output → **Set Container** input

**1080p SDR Path:**

- **Check HDR Video - 1080p** output #2 (is not HDR) → **Begin Command - 1080p SDR** input
- **Begin Command - 1080p SDR** → **Set Video Encoder - 1080p SDR**
- **Set Video Encoder - 1080p SDR** output → **Set Container** input

### Shared Plugin Chain

- **Set Container** → **Custom Arguments** → **Execute** → **Replace Original File**

## How It Works

### File Flow Example 1: 4K HDR Movie

1. File enters flow
2. Check Video Resolution detects 4K → Routes to 4K branch (output #6)
3. Check Video Codec detects H.264 → Continue (output #2)
4. **Check HDR Video detects HDR10 → Routes to 4K HDR path (output #1)**
5. Begin Command - 4K HDR starts building FFmpeg command
6. Set Video Encoder adds: `-c:v libx265 -preset medium -crf 23`
7. 10 Bit Video adds: `-pix_fmt yuv420p10le`
8. Custom Arguments (4K HDR) adds HDR metadata preservation parameters
9. Merges to shared plugins
10. Set Container sets output to `.mkv`
11. Custom Arguments adds: `-map_chapters 0 -dn -sn` (preserves chapters, excludes data/subtitle streams)
12. Execute runs the complete FFmpeg command (audio streams automatically copied)
13. Replace Original File swaps original with transcoded version

**Result**: 4K H.265 file with HDR metadata preserved, 10-bit color, all audio tracks intact, ~60-70% size reduction.

### File Flow Example 2: 4K SDR TV Show

1. File enters flow
2. Check Video Resolution detects 4K → Routes to 4K branch (output #6)
3. Check Video Codec detects H.264 → Continue (output #2)
4. **Check HDR Video detects SDR → Routes to 4K SDR path (output #2)**
5. Begin Command - 4K SDR starts building FFmpeg command
6. Set Video Encoder adds: `-c:v libx265 -preset medium -crf 23`
7. (No 10 Bit Video - uses standard 8-bit)
8. (No HDR Custom Arguments - not needed)
9. Merges to shared plugins
10. Set Container sets output to `.mkv`
11. Custom Arguments adds: `-map_chapters 0 -dn -sn`
12. Execute runs the complete FFmpeg command
13. Replace Original File swaps original with transcoded version

**Result**: 4K H.265 file, 8-bit color, ~60-70% size reduction. ~10-15% smaller than if 10-bit was applied.

### File Flow Example 3: 1080p HDR Streaming Content

1. File enters flow
2. Check Video Resolution detects 1080p → Routes to 1080p branch (output #4)
3. Check Video Codec detects H.264 → Continue (output #2)
4. **Check HDR Video detects HDR → Routes to 1080p HDR path (output #1)**
5. Begin Command - 1080p HDR starts building FFmpeg command
6. Set Video Encoder adds: `-c:v libx265 -preset medium -crf 21`
7. 10 Bit Video adds: `-pix_fmt yuv420p10le`
8. Custom Arguments (1080p HDR) adds HDR metadata preservation parameters
9. Merges to shared plugins
10. Set Container sets output to `.mkv`
11. Custom Arguments adds: `-map_chapters 0 -dn -sn`
12. Execute runs the complete FFmpeg command
13. Replace Original File swaps original with transcoded version

**Result**: 1080p H.265 file with HDR metadata preserved, 10-bit color, ~50-60% size reduction.

### File Flow Example 4: 1080p SDR TV Show

1. File enters flow
2. Check Video Resolution detects 1080p → Routes to 1080p branch (output #4)
3. Check Video Codec detects H.264 → Continue (output #2)
4. **Check HDR Video detects SDR → Routes to 1080p SDR path (output #2)**
5. Begin Command - 1080p SDR starts building FFmpeg command
6. Set Video Encoder adds: `-c:v libx265 -preset medium -crf 21`
7. (No 10 Bit Video - uses standard 8-bit)
8. (No HDR Custom Arguments - not needed)
9. Merges to shared plugins
10. Set Container sets output to `.mkv`
11. Custom Arguments adds: `-map_chapters 0 -dn -sn`
12. Execute runs the complete FFmpeg command
13. Replace Original File swaps original with transcoded version

**Result**: 1080p H.265 file, 8-bit color, ~50-60% size reduction.

### File Flow Example 5: Already H.265

1. File enters flow
2. Check Video Resolution detects resolution → Routes to appropriate branch
3. Check Video Codec detects hevc → Stops (output #1 "has codec" is not connected)

**Result**: File skipped, no transcoding needed

## Subtitle Management Strategy

### Why Subtitles Are Excluded

Embedded WebVTT subtitle streams (common in WEB-DL releases) cause transcode failures:

- **Error**: `Subtitle codec 0 is not supported` / `Could not write header`
- **Root cause**: Matroska muxer cannot handle WebVTT codec with BlockAdditions metadata
- **Exit code**: 218 (ffmpeg failure)

**Solution**: The `-sn` flag in the Custom Arguments plugin excludes all subtitle streams from transcoding, preventing
these failures.

### Automatic Subtitle Re-Download via Bazarr

After transcoding removes embedded subtitles, Bazarr automatically handles subtitle management:

**Workflow Timeline**:

1. **Transcode completes** - File has no embedded subtitles
2. **Library sync** (every 6 hours) - Bazarr detects transcoded file
3. **Missing detection** - Bazarr identifies missing subtitles
4. **Automatic search** (every 3 hours) - Searches subtitle providers
5. **Download** - Saves matching `.srt` files (score 85+) next to media files
6. **Jellyfin pickup** - Automatically detects and uses new `.srt` files

**Expected Time**: ~9 hours worst-case (6hr sync + 3hr search)

### Why External Subtitles Are Better

**Advantages over embedded WebVTT**:

- ✅ **No transcode failures** - Removes codec compatibility issues
- ✅ **Universal compatibility** - `.srt` works everywhere
- ✅ **Easy management** - Replace/update without re-encoding video
- ✅ **Automatic upgrades** - Bazarr finds better subtitles over 7 days
- ✅ **Smaller file sizes** - External subtitles don't bloat video files
- ✅ **Multiple languages** - Bazarr can download multiple subtitle tracks

### Bazarr Configuration

Ensure Bazarr is configured (see `docs/configuration/bazarr-setup.md`):

- ✅ Connected to Sonarr/Radarr
- ✅ Subtitle providers enabled (OpenSubtitles, Addic7ed, etc.)
- ✅ English language profile configured
- ✅ Scheduled searches enabled (every 3 hours)

**No additional configuration needed for Tdarr integration!**

## Quality Settings Breakdown

### 4K HDR Content

- **CRF 23**: Good quality, 60-70% compression
- **Preset medium**: Balanced speed/quality
- **10-bit color**: Required for HDR color depth
- **HDR metadata**: Full BT.2020 color space, SMPTE 2084 transfer

**Expected**: ~15-25 minutes per 2-hour movie (GPU) | ~5-8 hours (CPU-only)

### 4K SDR Content

- **CRF 23**: Good quality, 60-70% compression
- **Preset medium**: Balanced speed/quality
- **8-bit color**: Standard for SDR (no 10-bit overhead)
- **No HDR parameters**: Not needed for SDR

**Expected**: ~15-25 minutes per 2-hour movie (GPU) | ~5-8 hours (CPU-only)

### 1080p HDR Content

- **CRF 21**: Excellent quality, 50-60% compression
- **Preset medium**: Same encoding speed as 4K
- **10-bit color**: Required for HDR color depth
- **HDR metadata**: Full BT.2020 color space, SMPTE 2084 transfer

**Expected**: ~6-10 minutes per 2-hour movie (GPU) | ~1.5-2.5 hours (CPU-only)

### 1080p SDR Content

- **CRF 21**: Excellent quality, 50-60% compression
- **Preset medium**: Same encoding speed as 4K
- **8-bit color**: Standard for SDR (no 10-bit overhead)
- **No HDR parameters**: Not needed for SDR

**Expected**: ~6-10 minutes per 2-hour movie (GPU) | ~1.5-2.5 hours (CPU-only)

## Library Assignment

After saving the flow, assign it to your libraries:

1. Go to **Libraries** in Tdarr
2. Select your **Movies** library
3. Under **Transcode**, select: `Media Optimization - H.265 with HDR`
4. Repeat for **TV Shows** library

## Testing Workflow

Before enabling on full libraries:

### Test 1: Single 4K HDR File

1. Find a large 4K HDR H.264 file (>10GB)
2. Manually trigger transcode in Tdarr
3. Monitor progress in Tdarr UI
4. After completion, verify:
   - File size reduced (~60-70%)
   - HDR metadata preserved (check with MediaInfo)
   - Playback works in Jellyfin
   - Video quality acceptable

### Test 2: Single 1080p File

1. Find a 1080p H.264 file (~5-15GB)
2. Manually trigger transcode
3. After completion, verify:
   - File size reduced (~50-60%)
   - Quality excellent
   - Playback works

### Test 3: Already H.265 File

1. Find or create an H.265 file
2. Run through flow
3. Verify: File skipped, not re-transcoded

### Test 4: Small Batch (5-10 files)

1. Enable flow on one library
2. Let it process 5-10 files automatically
3. Monitor:
   - CPU usage (should stay <80% per core)
   - Memory usage (tdarr-node should stay <2GB)
   - VM stability
   - Processing times

### Test 5: Monitor First 24 Hours

```bash
# Check VM resources

ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net "free -h"
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net "podman stats --no-stream tdarr-node"

# Check Jellyfin still responsive

curl -I http://jellyfin.discus-moth.ts.net:8096
```

If stable after 24 hours, enable on full libraries.

## Worker Configuration

Configure the Tdarr Node for optimal performance based on your hardware.

### GPU Transcoding (GTX 1080 NVENC) - Recommended

With GPU passthrough enabled, NVENC handles all encoding work:

| Setting | Recommended Value | Rationale |
|---------|-------------------|-----------|
| **GPU Workers** | **2** | GTX 1080 NVENC 2-stream limit (unpatched) |
| **CPU Workers** | **0** | GPU handles encoding; CPU unnecessary |
| **Health Check CPU** | **1** | Health checks don't use GPU |

**Why GPU Workers = 2:**

- The GTX 1080 can decode unlimited streams but NVIDIA artificially limits consumer cards to 2 simultaneous encodes
- This is a driver lock, not a performance limitation
- Apply the [NVENC patch](https://github.com/keylase/nvidia-patch) to unlock 3-4+ concurrent GPU transcodes

**Performance with NVENC:**

| Content Type | Speed | Time for 2hr Movie |
|--------------|-------|-------------------|
| 4K H.264 → H.265 | 5-8x realtime | **15-25 minutes** |
| 4K HEVC re-encode | 3-5x realtime | **25-40 minutes** |
| 1080p → H.265 | 15-20x realtime | **6-8 minutes** |

### CPU-Only Transcoding (Legacy/Fallback)

If GPU is unavailable, use these conservative CPU settings:

- **Transcode CPU**: `1` (REQUIRED for 4K content - see details below)
- **Transcode threads**: `2` (leaves 2 cores for Jellyfin)
- **Health check threads**: `2`

**Why single concurrent transcode for CPU:**

- Each 4K CPU transcode consumes ~2 cores at 100%
- With 2 concurrent 4K transcodes = 4 cores maxed out = instability
- Testing showed 100% success with 1 worker, immediate failures with 2

**Note**: The "Transcode threads" setting controls how many cores each individual transcode uses, not how many
transcodes run simultaneously.

### Scheduling (Optional)

If CPU impact too high during daytime:

- **Schedule**: `02:00-06:00` (off-peak hours)
- **Pause outside schedule**: Enabled

### Monitoring

- Check queue status daily
- Review error logs weekly
- Verify storage savings monthly
- Monitor resource usage during transcodes (`podman stats tdarr-node`)

## Expected Results

### Storage Savings

Based on typical H.264 → H.265 conversion:

**TV Shows** (mix of 1080p and 4K):

- Original: 10TB
- After: ~5-6TB
- Savings: 4-5TB (40-50%)

**Movies** (mostly 4K HDR):

- Original: 20TB
- After: ~12-14TB
- Savings: 6-8TB (30-40%)

### Processing Capacity

**With GPU (GTX 1080 NVENC, 2 concurrent workers):**

Running 24/7 with 2 GPU workers:

- **4K content**: **50-80 movies/day** (15-25 min per movie × 2 workers)
- **4K TV episodes**: **200+ episodes/day** (3-5 min per episode × 2 workers)
- **1080p**: **150+ movies/day** (6-8 min per movie × 2 workers)
- **Mixed libraries**: **~50-100TB processed/week**

With off-peak scheduling (4 hours/night):

- **4K movies**: 10-15 movies/night
- **4K TV episodes**: 40-60 episodes/night
- **1080p**: 30-40 movies/night

**After applying NVENC patch (3-4 GPU workers):**

Processing capacity increases by 50-100% with 3-4 concurrent GPU transcodes.

**CPU-Only Fallback (4-core VM, 1 concurrent transcode):**

- **4K content**: 3-5 movies/day (~5-8 hours per movie)
- **1080p**: 8-12 movies/day
- **Mixed libraries**: ~4-6TB processed/week

## Troubleshooting

### Flow Fails Immediately with "No last successful plugin"

**Symptom**: Every file fails at Step W09, worker disconnects
**Cause**: Missing "Input File" node at the start of flow
**Fix**:

1. Open flow in Flow Editor
2. Add "Input File" node from "Flow Plugins > Input/Output"
3. Connect "Input File" output → "Comment" input
4. Save flow

### Flow Not Processing Files

- Check library assignment
- Verify flow is enabled
- Check file pattern matches (*.mkv,*.mp4, etc.)
- Review Tdarr logs for errors

### HDR Looks Washed Out

- Verify Custom Arguments contain full HDR parameters
- Check 10 Bit Video plugin is enabled
- Use MediaInfo to verify HDR metadata in output file

### Transcode Too Slow

- Reduce concurrent transcodes to 1
- Consider changing preset from `medium` to `fast`
- Increase CRF values (23→25 for 4K, 21→23 for 1080p)

### File Larger After Transcode

- Source may already be well-compressed
- Consider adding "Compare File Size" plugin before "Replace Original File"
- Skip already-optimized content

### Node Crash/Out of Memory

- Reduce concurrent transcodes
- Check memory limits on tdarr-node container (should be 2GB)
- Verify VM has sufficient free memory

### MP4 Fails with "Only audio, video, and subtitles are supported"

**Symptom**: Transcode fails with error:
`Only audio, video, and subtitles are supported for Matroska.`

**Cause**: MP4 files (common in anime/PTerWEB releases) contain data streams that MKV cannot handle:

- `bin_data` streams (chapter metadata stored as binary)
- Attached pictures (embedded cover art as PNG/JPEG)

**Fix**: Ensure Custom Arguments plugin includes `-dn` flag:

```text
-map_chapters 0 -dn -sn
```

- `-map_chapters 0` converts chapters to MKV-native format (preserves chapter markers)
- `-dn` skips data streams entirely
- `-sn` skips subtitle streams (existing fix for WebVTT)

**Impact**: Chapters are preserved. Embedded cover art is lost but Jellyfin uses external/scraped artwork.

## Maintenance

### Weekly

- Review transcode queue
- Check error logs
- Verify storage savings

### Monthly

- Evaluate CRF settings (quality vs size trade-off)
- Consider adjusting concurrent transcodes
- Review flow efficiency

## Flow Diagram

```text
                              Input File
                                  ↓
                              [Comment]
                                  ↓
                      [Check Video Resolution]
                    /                           \
           (#6: 4KUHD)                      (#4: 1080p)
                ↓                                 ↓
      [Check Codec - 4K]              [Check Codec - 1080p]
           ↓ (#2)                           ↓ (#2)
    [Check HDR Video - 4K]          [Check HDR Video - 1080p]
        /           \                    /           \
   (#1: HDR)    (#2: SDR)          (#1: HDR)    (#2: SDR)
       ↓            ↓                  ↓            ↓
[Begin Cmd    [Begin Cmd         [Begin Cmd    [Begin Cmd
  4K HDR]      4K SDR]           1080p HDR]    1080p SDR]
       ↓            ↓                  ↓            ↓
[Set Encoder  [Set Encoder       [Set Encoder  [Set Encoder
  CRF 23]      CRF 23]            CRF 21]       CRF 21]
       ↓            │                  ↓            │
[10 Bit Video]      │            [10 Bit Video]     │
       ↓            │                  ↓            │
[Custom Args        │            [Custom Args       │
 HDR params]        │             HDR params]       │
       ↓            ↓                  ↓            ↓
       └────────────┴──────────────────┴────────────┘
                              ↓
                    [Set Container: .mkv]
                              ↓
            [Custom Arguments: -map_chapters 0 -dn -sn]
              (preserves chapters, excludes data/subs)
                              ↓
                          [Execute]
                    (auto-copies audio)
                              ↓
                  [Replace Original File]
                              ↓
                       Transcoded File
                   (Bazarr re-downloads
                     subtitles as .srt)
```

### Branch Summary

| Path | 10-Bit | HDR Args | CRF |
|------|--------|----------|-----|
| 4K HDR | ✓ | ✓ | 23 |
| 4K SDR | ✗ | ✗ | 23 |
| 1080p HDR | ✓ | ✓ | 21 |
| 1080p SDR | ✗ | ✗ | 21 |

## Reference Files

- **Transcode profiles guide**: `docs/configuration/tdarr-transcode-profiles.md`
- **Sonarr/Radarr quality profiles**: `configs/recyclarr-config.yml`
- **Service endpoints**: `docs/configuration/service-endpoints.md`

## Credits

Flow designed to align with Sonarr/Radarr quality standards:

- **Sonarr**: WEB-2160p + 1080p profile
- **Radarr**: UHD Bluray + WEB profile (HDR preferred +600 score)

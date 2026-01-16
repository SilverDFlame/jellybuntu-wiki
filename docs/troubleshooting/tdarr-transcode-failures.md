# Tdarr Transcode Failures - Troubleshooting Guide

## Diagnosing Mass Transcode Failures

If you're seeing many files failing (e.g., 120+ errors), follow this systematic approach to identify the root cause.

### Step 1: View Error Details in Tdarr UI

1. Open Tdarr Web UI: `http://jellyfin.discus-moth.ts.net:8265`
2. Click on the **"Transcode: Error/Cancelled"** tab at the top
3. Click on **one of the failed files** in the list
4. Look for the **error message** or **transcode log**
5. Identify the specific FFmpeg error or plugin failure

### Step 2: Common Error Patterns and Fixes

#### Error: "No last successful plugin" / Worker disconnects immediately

**Symptom**:

- Step W02: Loading flow ✓
- Step W09: [-error-] Job end ✗
- "No last successful plugin"
- Worker disconnected

**Cause**: Missing "Input File" node at the start of the flow
**Fix**:

1. Open flow in Flow Editor (`http://jellyfin.discus-moth.ts.net:8265/flow-editor`)
2. Add "Input File" node from "Flow Plugins > Input/Output" section
3. Connect: **Input File** output → **Comment** (or first plugin) input
4. Save flow and retest

**Why this happens**: The "Input File" node is the entry point that receives files from the transcode queue. Without it,
the flow has nowhere to inject files, causing immediate failure.

---

#### Error: "Output file is larger than input"

**Symptom**: Files marked as error because output exceeds input size
**Cause**: Flow has no size comparison plugin
**Fix**: Add "Compare File Size" plugin before "Replace Original File"

**Add this plugin**:

- Plugin: `Compare File Size` (Classic Plugins > File)
- Config: Revert if output larger
- Insert between "Execute" and "Replace Original File"

---

#### Error: "Cannot find codec 'libx265'" or "Unknown encoder"

**Symptom**: FFmpeg cannot find H.265 encoder
**Cause**: FFmpeg not compiled with x265 support
**Fix**: Check FFmpeg installation in container

```bash
# Check FFmpeg version and codecs
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "podman exec tdarr-node ffmpeg -version"

# Check if libx265 is available
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "podman exec tdarr-node ffmpeg -encoders 2>&1 | grep 265"
```

**Expected output**: Should show `libx265` encoder listed

---

#### Error: Invalid HDR parameters or "Unrecognized option"

**Symptom**: FFmpeg rejects HDR metadata parameters
**Cause**: Syntax error in Custom Arguments (HDR)
**Common issues**:

- Missing quotes around x265-params
- Incorrect parameter format
- Unsupported x265 options

**Verify HDR Custom Arguments plugin contains**:

```text
-pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -x265-params hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc
```

**Fix**: Copy the exact parameter string above into the Custom Arguments plugin

**IMPORTANT**: Do NOT include quotes around the x265-params value - FFmpeg will treat them as literal characters and
cause x265 parsing errors

---

#### Error: "Permission denied" or "Cannot write to temp directory"

**Symptom**: Transcode fails when trying to write output file
**Cause**: Permissions issue on temp directory
**Fix**: Check permissions on `/opt/jellyfin/tdarr/temp`

```bash
# Check temp directory permissions
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "ls -ld /opt/jellyfin/tdarr/temp"

# Fix permissions if needed
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "sudo chown -R 1000:1000 /opt/jellyfin/tdarr/temp"
```

---

#### Error: "No such file or directory" for input files

**Symptom**: Tdarr cannot find the source media files
**Cause**: NFS mount issue or incorrect path mapping
**Fix**: Verify media mount in container

```bash
# Check if media is mounted correctly in container
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "podman exec tdarr-node ls -l /media/movies /media/tv"

# Verify NFS mount on host
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "ls -l /mnt/data/media/movies /mnt/data/media/tv"
```

---

#### Error: "Output format not recognized" or "Invalid container"

**Symptom**: MKV container creation fails
**Cause**: Set Container plugin misconfigured or FFmpeg issue
**Fix**: Verify "Set Container" plugin

1. Open flow in Tdarr UI
2. Find "Set Container" plugin
3. Verify it's set to `.mkv` (with the dot)
4. Save flow and retest

---

#### Error: Duplicate streams or "FFmpeg failed" with stream mapping warnings

**Symptom**:

- FFmpeg shows warnings like "Multiple -codec options specified"
- Stream mapping shows duplicate entries (e.g., Stream #0:1 → both #0:1 and #0:13)
- Transcode fails immediately after starting

**Cause**: Flow has redundant stream mapping commands
**Common configuration error**: Having both individual stream mappings AND wildcard mappings (e.g., `-map 0:a`)

**Fix**: Remove the "Custom Arguments (Audio/Subs)" plugin entirely

1. Open flow in Tdarr UI
2. Find and DELETE the "Custom Arguments - Audio/Subtitle Preservation" plugin (if present)
3. The FFmpeg flow plugins automatically copy all audio/subtitle streams
4. No additional mapping configuration is needed
5. Save flow and retest

**Why this happens**: Earlier versions of the flow guide incorrectly included a plugin with `-c:a copy -map 0:a -c:s
copy -map 0:s?` which duplicates the automatic stream mapping performed by the FFmpeg command builder.

---

#### Error: Mass failures with multiple concurrent transcodes / FFmpeg crashes at frame 0-7

**Symptom**:

- Single files transcode successfully (100% success rate)
- When 2+ concurrent transcodes are enabled, mass failures occur
- FFmpeg crashes at frame 0-7 with exit code null
- Error logs show process termination with no specific error message
- Example: 73 files failing rapidly in succession after queue unpaused

**Cause**: **Resource contention** on systems with limited CPU cores

- Each 4K transcode consumes approximately **2 CPU cores** at 100% utilization
- On a 4-core system: 2 concurrent 4K transcodes = all 4 cores maxed out
- This creates:
  - CPU process starvation (not enough cycles for all processes)
  - Memory pressure on tdarr-node container
  - FFmpeg instability and premature termination
  - Kernel scheduling conflicts

**Fix**: Limit concurrent transcodes to 1 worker

**Steps to configure**:

1. Open Tdarr Web UI: `http://jellyfin.discus-moth.ts.net:8265`
2. Click **"Nodes"** in the top navigation
3. Find your node (e.g., "JellyfinNode") and click **"Options"**
4. Locate **"Transcode CPU"** setting (controls concurrent transcode limit)
5. Change value from `2` to `1`
6. Save settings
7. Monitor queue - files should now succeed sequentially

**Verification**:

```bash
# Monitor CPU usage during transcodes
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "podman stats --no-stream tdarr-node"

# With single worker, CPU should be ~200-250% (2-2.5 cores out of 4)
# With dual workers, CPU would hit 400% (all 4 cores maxed)
```

**Expected behavior after fix**:

- ✅ Files process one at a time (sequential)
- ✅ Each transcode completes successfully
- ✅ CPU usage stays under 250% per transcode
- ✅ No mass failures

**Future upgrade path**:
If you upgrade to a system with more CPU cores (6-8 cores minimum):

- 6 cores: Can support 2 concurrent 4K transcodes
- 8 cores: Can support 3 concurrent 4K transcodes
- Formula: `(Total cores - 2 for overhead) / 2 cores per transcode = Max concurrent`

**Why this happens**: 4K H.265 encoding is extremely CPU-intensive. The libx265 encoder with `medium` preset requires
sustained multi-core performance. When two transcodes compete for the same limited CPU resources, the kernel cannot
provide sufficient cycles to both processes, causing FFmpeg to terminate prematurely.

**Note**: This limitation is specific to 4K content. 1080p transcodes may allow higher concurrency (2-3 workers) even on
a 4-core system, as they consume fewer CPU resources (~1-1.5 cores per transcode).

---

#### Error: Audio/subtitle stream mapping fails

**Symptom**: FFmpeg error with `-map 0:a` or `-map 0:s?`
**Cause**: File has no audio/subtitle streams, or mapping syntax incorrect
**Fix**: Add error handling to audio mapping

**Update Custom Arguments (Audio/Subs) to**:

```text
-c:a copy -map 0:a? -c:s copy -map 0:s?
```

Note the `?` after `-map 0:a` makes audio optional

---

#### Error: "Subtitle codec 0 is not supported" / WebVTT subtitle failures

**Symptom**:

- FFmpeg error: `Unknown/unsupported AVCodecID S_TEXT/WEBVTT`
- Error: `Could not find codec parameters for stream X (Subtitle: none): unknown codec`
- Error: `Subtitle codec 0 is not supported`
- Error: `Could not write header (incorrect codec parameters ?): Function not implemented`
- Exit code: 218 (ffmpeg failure)
- Transcode fails immediately after x265 encoder initialization

**Cause**: Embedded WebVTT subtitle streams with BlockAdditions metadata

- Common in WEB-DL releases (especially from streaming services)
- Matroska muxer cannot handle WebVTT codec with special BlockAdditions metadata
- FFmpeg reports "Function not implemented" when trying to copy these streams

**Example affected files**:

```text
Steven.Universe.S03E01.MULTI.1080p.MAX.WEB-DL.DDP2.0.H.264-AndreMor.mkv
Steven.Universe.S03E08.MULTI.1080p.MAX.WEB-DL.DDP2.0.H.264-AndreMor.mkv
```

**Fix**: Add Custom Arguments plugin to exclude subtitles

1. Open flow in Tdarr UI (`http://jellyfin.discus-moth.ts.net:8265/flow-editor`)
2. Find the **"Set Container"** plugin in the shared section (after both branches merge)
3. Add a new plugin between "Set Container" and "Execute":
   - Plugin type: **"FFmpeg Command: Custom Arguments"**
   - Name: `Exclude Subtitles` (for clarity)
   - **Output Arguments**: `-sn`
4. Save flow
5. Re-transcode failed files

**Flow order after fix**:

```text
Set Container (.mkv)
   ↓
Custom Arguments (-sn)  ← NEW
   ↓
Execute
   ↓
Replace Original File
```

**What the `-sn` flag does**:

- Tells ffmpeg to skip all subtitle streams during transcode
- Prevents WebVTT codec errors by not attempting to copy problematic streams
- Audio and video streams are still automatically copied

**Subtitle restoration via Bazarr**:

After transcoding completes without embedded subtitles, Bazarr automatically handles subtitle management:

**Timeline**:

1. Transcode completes (no subtitles in output file)
2. Bazarr syncs with Sonarr/Radarr (every 6 hours)
3. Bazarr detects missing subtitles
4. Bazarr searches providers (every 3 hours)
5. Downloads matching .srt files (score 85+)
6. Jellyfin automatically picks up external .srt files

**Expected time**: approximately 9 hours worst-case (6hr sync + 3hr search)

**Why external subtitles are better**:

- No transcode failures
- Universal .srt compatibility
- Easy to replace/update without re-encoding
- Bazarr automatically upgrades to better subtitles over 7 days
- Smaller video file sizes

**Verification**:

```bash
# Check if Bazarr is running and configured
curl -I http://media-services.discus-moth.ts.net:6767

# After transcode, verify file has no subtitle streams
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "podman exec jellyfin ffprobe -v error -select_streams s -show_entries stream=index,codec_name -of default=noprint_wrappers=1 '/path/to/transcoded/file.mkv'"

# Should return empty (no subtitle streams)
```

**See also**: `docs/configuration/tdarr-flow-configuration.md` (Subtitle Management Strategy section)

---

#### Error: "Conversion failed" with no specific error

**Symptom**: Generic failure message with no details
**Cause**: Usually a plugin connection or command building issue
**Fix**: Verify flow connections

1. Open flow in Tdarr UI
2. Check all plugins are connected (no orphaned plugins)
3. Verify branch merge points:
   - Both 4K and 1080p branches connect to "Custom Arguments (Audio/Subs)"
   - All plugins in sequence are connected
4. Save flow and retest

---

### Step 3: Test Flow with Single File

To isolate the issue:

1. **Pause the queue**: Stop automatic processing
2. **Select a single small file** (preferably 1080p, <5GB)
3. **Manually trigger transcode** from Tdarr UI
4. **Watch the progress** and error in real-time
5. **Read the full error log** for that file

---

### Step 4: Verify Flow Configuration

Compare your flow against the reference configuration in `docs/configuration/tdarr-flow-configuration.md`:

#### Required Plugins (in order)

1. **Input File** (CRITICAL - entry point, must be first!)
2. Comment
3. Check Video Resolution

3-4. Check Video Codec (4K and 1080p branches)

1. Check HDR Video (4K branch only)
6-7. Begin Command (separate for each branch)
8-9. Set Video Encoder (CRF 23 for 4K, CRF 21 for 1080p)
2. 10 Bit Video (4K branch only)
3. Custom Arguments - HDR (4K branch only)
4. Set Container (shared)
5. Custom Arguments - Exclude Subtitles with `-sn` (shared, prevents WebVTT errors)
6. Execute (shared)
7. Replace Original File (shared)

#### Critical Configuration Values

- **4K Video Encoder**: libx265, preset medium, CRF 23
- **1080p Video Encoder**: libx265, preset medium, CRF 21
- **HDR Custom Arguments**: -pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -x265-params hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc (NO quotes around x265-params!) <!-- markdownlint-disable-line MD013 -->
- **Container**: .mkv
- **Subtitle Exclusion**: -sn (in Custom Arguments plugin between Set Container and Execute)
- **Audio**: Automatically copied (no additional plugin needed)
- **Subtitles**: Excluded during transcode, re-downloaded by Bazarr as external .srt files

---

### Step 5: Check Container Resources

Ensure the tdarr-node container has sufficient resources:

```bash
# Check container stats
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "podman stats --no-stream tdarr-node"

# Check container logs for OOM or resource issues
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net \
  "journalctl --user -u tdarr-node 2>&1 | tail -50"
```

**Healthy metrics**:

- CPU: <400% (across 4 cores)
- Memory: <1.5GB (limit is 2GB)
- No OOM (Out of Memory) errors

---

### Step 6: Reset and Rebuild Flow (Last Resort)

If all else fails:

1. **Export successful flow configuration** (if you have one working)
2. **Delete the problematic flow**
3. **Clear the transcode queue** (reset error files)
4. **Rebuild flow from scratch** using the guide in `docs/configuration/tdarr-flow-configuration.md`
5. **Test with single file before enabling on library**

---

## Quick Diagnostic Checklist

Run through this checklist to quickly identify common issues:

- [ ] **Flow has "Input File" node at the start** (most common issue!)
- [ ] **Transcode CPU set to 1** (concurrent transcode limit - see concurrency section)
- [ ] **Custom Arguments with `-sn` flag** between "Set Container" and "Execute" (prevents WebVTT subtitle errors)
- [ ] Verified error message from Tdarr UI (not just scan metadata)
- [ ] Checked FFmpeg is available in container (`ffmpeg -version`)
- [ ] Confirmed libx265 encoder is available
- [ ] Verified all plugin connections in flow (no orphaned plugins)
- [ ] Checked temp directory permissions
- [ ] Confirmed NFS media mounts are accessible
- [ ] Tested with single small file (1080p <5GB)
- [ ] Reviewed HDR Custom Arguments syntax (no quotes around x265-params!)
- [ ] Verified Audio/Subs Custom Arguments are NOT needed (auto-copied)
- [ ] Checked container resource usage (CPU/memory)
- [ ] If mass failures: Test single file to verify flow, then check concurrent transcode setting
- [ ] If WebVTT subtitle errors: Verify `-sn` flag is present in Custom Arguments plugin

---

## Getting Help

If you're still stuck:

1. **Capture full error log** from one failed file in Tdarr UI
2. **Export flow configuration** as JSON
3. **Check FFmpeg version** and available encoders
4. **Review** `docs/configuration/tdarr-flow-configuration.md` for reference implementation

## Related Documentation

- **Flow Configuration**: `docs/configuration/tdarr-flow-configuration.md`
- **Transcode Profiles Guide**: `docs/configuration/tdarr-transcode-profiles.md`
- **General Tdarr Troubleshooting**: `docs/troubleshooting/tdarr.md`
- **Service Endpoints**: `docs/configuration/service-endpoints.md`

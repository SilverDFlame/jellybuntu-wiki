# GPU Passthrough Configuration

Guide for configuring NVIDIA GPU passthrough on Proxmox for Jellyfin and Tdarr hardware transcoding.

## Overview

GPU passthrough allows the GTX 1080 to be used directly by the Jellyfin VM for NVENC hardware
transcoding, significantly reducing CPU load and improving transcode performance.

**Benefits:**

- **10x faster transcoding** compared to CPU-only
- **Lower power consumption** during transcoding
- **Free CPU** for other tasks (Sonarr/Radarr scanning, etc.)
- **Better quality** at lower bitrates with NVENC

## Prerequisites

- AMD EPYC 7313P CPU with IOMMU support
- NVIDIA GTX 1080 GPU (or compatible)
- Proxmox VE 8.x
- IOMMU enabled in BIOS/UEFI

## Step 1: Configure Proxmox Host

Run the Proxmox host configuration playbook:

```bash
./bin/runtime/ansible-run.sh playbooks/core/00-configure-proxmox-host.yml
```

This configures:

- GRUB IOMMU parameters (`amd_iommu=on iommu=pt`)
- VFIO kernel modules
- GPU binding to vfio-pci driver
- NVIDIA driver blacklist on host
- RAM disk for transcoding cache

**Reboot required after first run.**

## Step 2: Verify IOMMU Configuration

After reboot, verify IOMMU is enabled:

```bash
ssh root@proxmox "dmesg | grep -i iommu"
# Should show: AMD-Vi: Interrupt remapping enabled
```

Check GPU is bound to vfio-pci:

```bash
ssh root@proxmox "lspci -nnk | grep -A3 NVIDIA"
# Should show: Kernel driver in use: vfio-pci
```

## Step 3: Add GPU to Jellyfin VM

Find GPU PCI address:

```bash
ssh root@proxmox "lspci | grep -i nvidia"
# Example: 41:00.0 VGA compatible controller: NVIDIA Corporation GP104 [GeForce GTX 1080]
```

Set machine type to q35 (required for PCIe passthrough):

```bash
ssh root@proxmox "qm set 400 -machine q35"
```

Add GPU passthrough to Jellyfin VM (VMID 400):

```bash
ssh root@proxmox "qm set 400 -hostpci0 81:00,pcie=1,rombar=1"
```

**Note:** The `machine = "q35"` setting is now in the Terraform config, so future `tofu apply` runs will preserve it.

Verify configuration:

```bash
ssh root@proxmox "qm config 400 | grep hostpci"
# Should show: hostpci0: 41:00,pcie=1,rombar=1
```

**Note:** This step requires root access to Proxmox and cannot be done via Terraform due to API
limitations with IOMMU operations.

## Step 4: Install NVIDIA Drivers in VM

Start the Jellyfin VM and run the Jellyfin role with GPU enabled:

```bash
# In host_vars/jellyfin.yml or playbooks/vars.yml
jellyfin_gpu_enabled: true
jellyfin_ramdisk_enabled: true

# Run the playbook
./bin/runtime/ansible-run.sh playbooks/core/10-configure-jellyfin-role.yml
```

Verify driver installation:

```bash
ssh ansible@jellyfin "nvidia-smi"
```

## Step 5: Configure Jellyfin for NVENC

In Jellyfin web UI:

1. Go to **Dashboard > Playback > Transcoding**
2. Set **Hardware acceleration** to `NVIDIA NVENC`
3. Enable **Enable hardware encoding**
4. Set **Transcode path** to `/var/lib/jellyfin/transcodes` (symlinked to RAM disk)
5. Save and restart Jellyfin

## Step 6: Configure Tdarr for NVENC

Tdarr automatically detects GPU if available. Run the Tdarr playbook:

```bash
./bin/runtime/ansible-run.sh playbooks/core/15-configure-tdarr-role.yml
```

The playbook will:

- Detect GPU availability
- Configure NVIDIA environment variables
- Pass GPU devices to container
- Use RAM disk for transcoding cache

## RAM Disk Configuration

The RAM disk at `/mnt/transcode-cache` is configured on the Proxmox host:

```text
/mnt/transcode-cache/
├── jellyfin/    # Jellyfin transcodes (32GB available)
└── tdarr/       # Tdarr transcodes (shared 32GB)
```

**Benefits:**

- Zero SSD wear from transcoding temp files
- Maximum I/O speed (RAM bandwidth)
- Automatic cleanup on reboot
- 32GB capacity handles multiple concurrent transcodes

## Verification

### Test Jellyfin Hardware Transcoding

1. Play a video that requires transcoding (e.g., 4K HEVC on a device that only supports 1080p H.264)
2. Check Jellyfin dashboard - should show "HW" indicator
3. Monitor GPU usage: `ssh ansible@jellyfin "nvidia-smi"`

### Test Tdarr Hardware Transcoding

1. Queue a transcode job in Tdarr web UI
2. Monitor GPU: `ssh ansible@jellyfin "nvidia-smi"`
3. Check temp files: `ssh ansible@jellyfin "ls -la /mnt/transcode-cache/tdarr/"`

### Verify RAM Disk Usage

```bash
ssh root@proxmox "df -h /mnt/transcode-cache"
```

## Troubleshooting

### GPU Not Detected in VM

```bash
# Check GPU passthrough in Proxmox
ssh root@proxmox "qm config 400 | grep hostpci"

# Check IOMMU groups
ssh root@proxmox "find /sys/kernel/iommu_groups/* -type l | sort -V"

# Check GPU binding on host
ssh root@proxmox "lspci -nnk | grep -A3 NVIDIA"
```

### NVIDIA Driver Not Loading

```bash
# Check dmesg for errors
ssh ansible@jellyfin "dmesg | grep -i nvidia"

# Reinstall driver
ssh ansible@jellyfin "sudo apt install --reinstall nvidia-driver"
```

### IOMMU Group Issues

If GPU shares IOMMU group with other devices, you may need to pass all devices in the group or use
ACS override patch.

Check IOMMU groups:

```bash
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done
done
```

### RAM Disk Not Mounted

```bash
# Check fstab entry
ssh root@proxmox "grep transcode-cache /etc/fstab"

# Mount manually
ssh root@proxmox "mount /mnt/transcode-cache"

# Verify
ssh root@proxmox "df -h /mnt/transcode-cache"
```

## Performance Expectations

| Transcode Type | CPU Only | NVENC (GTX 1080) |
|----------------|----------|------------------|
| 4K HEVC → 1080p H.264 | 0.5-1x realtime | 5-8x realtime |
| 1080p HEVC → 1080p H.264 | 2-3x realtime | 10-15x realtime |
| 1080p H.264 → 720p H.264 | 4-5x realtime | 15-20x realtime |

## See Also

- [EPYC 7313P Optimization](../reference/epyc-7313p-optimization.md) - BIOS settings for IOMMU and performance
- [Architecture Overview](../architecture.md) - GPU allocation and VM layout
- [Resource Allocation](resource-allocation.md) - CPU and memory allocation strategy

## References

- [Proxmox PCI Passthrough Wiki](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [Jellyfin Hardware Acceleration](https://jellyfin.org/docs/general/administration/hardware-acceleration/)
- [NVIDIA NVENC Support Matrix](https://developer.nvidia.com/video-encode-and-decode-gpu-support-matrix-new)

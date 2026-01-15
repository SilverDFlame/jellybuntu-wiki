# Packer Golden Image Build Troubleshooting

Quick troubleshooting guide for Packer builds of Ubuntu 24.04 golden images.

---

## Common Issues

### Build Times Out After 30 Minutes

**Symptoms**:

```text
==> ubuntu_base: Waiting for SSH to become available...
[30 minutes later]
==> ubuntu_base: Timeout waiting for SSH
```

**Cause**: Autoinstall is waiting for manual confirmation that Packer didn't send in time.

**Solution**:

1. **Watch the Proxmox console** (this is critical):

   ```text
   https://jellybuntu.discus-moth.ts.net:8006
   → VM 9000 → Console
   ```

2. **If you see this prompt**:

   ```text
   Continue with autoinstall? (yes|no)
   [cursor blinking]
   ```

   The wait time in boot_command needs to be increased.

   Edit [`infrastructure/packer/ubuntu-server/ubuntu-base.pkr.hcl`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/ubuntu-server/ubuntu-base.pkr.hcl):

   ```hcl
   boot_command = [
     # ... other lines ...
     "<wait2m>",     # Increase from <wait1m> to <wait2m>
     "yes<enter>"
   ]
   ```

3. **Rebuild**:

   ```bash
   cd infrastructure/packer/ubuntu-server/
   packer build .
   ```

**Prevention**: Our configuration already includes automated confirmation. This issue only occurs if your Proxmox host
is slow or the mirror download is delayed.

---

### Build Hangs After "Waiting for cloud-init"

**Symptoms**:

```text
==> ubuntu_base: Provisioning with shell script: inline
    ubuntu_base: Waiting for cloud-init to complete...
[hangs indefinitely]
```

**Cause**: Cloud-init failed or is stuck.

**Solution**:

1. **SSH to the VM** (in another terminal):

   ```bash
   # Get IP from Proxmox console or:
   ssh root@jellybuntu.discus-moth.ts.net "qm guest cmd 9000 network-get-interfaces" | jq

   # SSH to VM:
   ssh -i ~/.ssh/ansible_homelab ansible@<vm-ip>
   ```

2. **Check cloud-init status**:

   ```bash
   cloud-init status
   # If "error" or "disabled", check logs:
   sudo journalctl -u cloud-init
   ```

3. **If cloud-init is stuck**, the build provisioner will automatically continue after timeout (this is already configured).

**Prevention**: Already handled in configuration with fallback:

```hcl
"cloud-init status --wait || echo 'Cloud-init wait timed out, continuing...'"
```

---

### VM Boots But SSH Connection Fails

**Symptoms**:

- Proxmox console shows login prompt
- Packer keeps trying to connect via SSH
- Eventually times out

**Cause**: SSH service not running or networking issue.

**Diagnosis**:

Log in via Proxmox console and check:

```bash
# 1. Is SSH running?
sudo systemctl status ssh
# Should show: active (running)

# 2. Is SSH listening?
sudo ss -tlnp | grep :22
# Should show sshd on port 22

# 3. Does VM have an IP?
ip addr show ens18
# Should show IP address

# 4. Can you SSH locally?
ssh localhost
# Should connect
```

**Common Fixes**:

**If SSH not running**:

```bash
sudo systemctl start ssh
sudo systemctl enable ssh
```

**If no IP address**:

```bash
sudo dhclient ens18
```

**If firewall blocking**:

```bash
sudo ufw status
# Should be inactive during build
```

**Prevention**: Our user-data configuration already ensures SSH is enabled. This issue is rare.

---

### "Error: ISO file not found"

**Symptoms**:

```text
Error: ISO file not found: local:iso/ubuntu-24.04.3-live-server-amd64.iso
```

**Cause**: Ubuntu ISO not uploaded to Proxmox.

**Solution**:

```bash
# Download ISO to Proxmox
ssh root@jellybuntu.discus-moth.ts.net "cd /var/lib/vz/template/iso && wget https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso"

# Verify:
ssh root@jellybuntu.discus-moth.ts.net "ls -lh /var/lib/vz/template/iso/ubuntu-24.04*.iso"
```

---

### "QEMU guest agent is not running"

**Symptoms**:

```text
[DEBUG] Unable to get address: 500 QEMU guest agent is not running
```

**Cause**: Ubuntu 24.04 has a bug where qemu-guest-agent doesn't auto-start.

**Status**: ✅ **Already fixed in our configuration** with this workaround in `http/user-data`:

```yaml
- curtin in-target --target=/target -- systemctl enable qemu-guest-agent
- curtin in-target --target=/target -- systemctl daemon-reload
```

**If still seeing errors**, verify the fix is in your user-data file:

```bash
grep "daemon-reload" infrastructure/packer/ubuntu-server/http/user-data
```

---

### Template Already Exists

**Symptoms**:

```text
Error: VM with ID 9000 already exists
```

**Cause**: Previous build left a template or VM with the same ID.

**Solution**:

**Option 1: Delete old template** (recommended for rebuilds):

```bash
ssh root@jellybuntu.discus-moth.ts.net "qm destroy 9000"
```

**Option 2: Use different VMID**:
Edit [`infrastructure/packer/ubuntu-server/variables.pkr.hcl`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/ubuntu-server/variables.pkr.hcl):

```hcl
vm_id = 9001  # Change from 9000
```

---

## Debugging Tools

### Enable Debug Logging

```bash
cd infrastructure/packer/ubuntu-server/

# Enable verbose logging
export PACKER_LOG=1
export PACKER_LOG_PATH=./packer-debug.log

# Run build
packer build -on-error=abort .

# After failure, review last 200 lines:
tail -200 packer-debug.log | less
```

### Monitor Build in Real-Time

**Always watch the Proxmox console** during builds to see exactly what's happening:

**Web Console** (easiest):

```text
https://jellybuntu.discus-moth.ts.net:8006
→ Navigate to VM 9000
→ Click "Console"
```

**SSH Console**:

```bash
ssh root@jellybuntu.discus-moth.ts.net
qm terminal 9000
# Press Enter to activate
# Press Ctrl+O to exit
```

### Test Manual Build

If automated build keeps failing, test manually:

1. **Comment out boot_command** in ubuntu-base.pkr.hcl:

   ```hcl
   # boot_command = [ ... ]  # Temporarily disable
   ```

2. **Start build**:

   ```bash
   packer build .
   ```

3. **Manually interact with installer** in Proxmox console:
   - Press `e` at GRUB menu
   - Add `autoinstall ds=nocloud` to kernel line
   - Press F10 to boot
   - Watch for errors
   - Type `yes` when prompted

4. **This helps identify** where the automated process is failing.

---

## Expected Build Timeline

After all fixes are applied, builds should follow this timeline:

```text
Time     | Stage                        | What You See
---------|------------------------------|--------------------------------
0:00     | VM Creation                  | Packer creates VM 9000
0:10     | Boot                         | GRUB menu → boot command runs
0:15     | Autoinstall Starts           | "Contacting mirror..."
0:30     | Package Download             | Progress bar, package names
1:30     | Installation                 | "Installing system..."
2:00     | Late Commands                | Running late-commands
2:05     | First Reboot                 | VM reboots
2:10     | Login Prompt + SSH Available | ← Packer connects here
2:15     | Provisioners Start           | Shell scripts execute
4:00     | Package Installation         | Installing Podman, tools
5:30     | Ansible Playbook             | Security baseline
6:00     | Cleanup                      | Template cleanup
6:30     | Template Created             | Build complete!
```

**Total**: 6-10 minutes

**If your build doesn't follow this timeline**, something is wrong. Check the console to see where it diverges.

---

## When to Get More Help

If you've tried the above and are still stuck:

1. **Check the detailed guide**: See [`infrastructure/packer/TROUBLESHOOTING.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/TROUBLESHOOTING.md) in the repository

2. **Gather diagnostic info**:
   - What stage does it fail? (VM creation, boot, autoinstall, SSH, provisioners)
   - What do you see in Proxmox console?
   - What's in `packer-debug.log`?
   - Can you manually SSH to the VM after boot?

3. **Check for known issues**:
   - Network connectivity to Ubuntu mirrors
   - Proxmox host resources (CPU, RAM, disk space)
   - Tailscale connectivity to Proxmox host

---

## Quick Reference

### Build Command

```bash
cd infrastructure/packer/ubuntu-server/
packer build .
```

### With Debugging

```bash
export PACKER_LOG=1
export PACKER_LOG_PATH=./packer-debug.log
packer build -on-error=abort .
```

### Check Template Exists

```bash
ssh root@jellybuntu.discus-moth.ts.net "qm list | grep 9000"
```

### Test SSH to Build VM

```bash
# While build is running or after failure:
ssh -i ~/.ssh/ansible_homelab ansible@<vm-ip>
```

### View Proxmox Task Logs

```bash
ssh root@jellybuntu.discus-moth.ts.net
tail -f /var/log/pve/tasks/active/*
```

---

## Related Documentation

- [`infrastructure/packer/README.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/README.md) - Setup and usage
- [`infrastructure/packer/TROUBLESHOOTING.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/TROUBLESHOOTING.md) - Detailed technical guide
- [Phase 1 Deployment](../deployment/phase1-infrastructure.md) - Golden image deployment workflow
- [Architecture Overview](../architecture.md) - Infrastructure design

---

**Last Updated**: November 2024

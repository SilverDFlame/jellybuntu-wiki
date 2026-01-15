# TrueNAS Setup Guide

This guide covers the manual setup steps required for TrueNAS Scale after the automated VM provisioning.

## Prerequisites

- TrueNAS VM has been created by the provisioning playbook (`01-provision-vms.yml`)
- VM has 32GB boot disk and 2x 500GB data disks
- Ansible SSH key has been added to TrueNAS admin user

## 1. Install TrueNAS Scale

1. Boot the TrueNAS VM from the ISO (it should boot automatically)
2. Follow the TrueNAS Scale installation wizard:
   - Select the 32GB disk as the boot device
   - Set admin password (remember this for SSH/Web UI access)
   - Configure network settings with **static IP**:
     - IP Address: `192.168.0.15/24`
     - Gateway: `192.168.0.1`
     - DNS: `192.168.0.1` and `9.9.9.9`
   - Complete installation and reboot

3. Access TrueNAS Web UI at `http://192.168.0.15`:
   - Login with username: `admin`
   - Password: (the one you set during installation)

4. Enable SSH service with password authentication:
   - In TrueNAS Web UI, go to **System Settings** → **Services**
   - Find **SSH** in the services list
   - Click the **pencil/edit icon** to configure SSH settings
   - Ensure **"Log in as Root with Password"** is **enabled** (this allows admin user password login)
   - Click **Save**
   - Toggle the SSH service to **ON**
   - (Optional) Click **Start Automatically** to enable SSH on boot
   - Test SSH access from your control machine (should prompt for password):

     ```bash
     ssh admin@<current-ip>
     ```

   **Important**: Password authentication must be enabled for Ansible playbooks. You can add SSH keys later for
   key-based authentication.

## 2. Create ZFS Pool

1. In TrueNAS Web UI, go to **Storage** → **Create Pool**
2. Name the pool: `tank`
3. Add the two 500GB disks:
   - Layout: **Mirror** (for redundancy)
   - Or **Stripe** (for maximum space, no redundancy)
4. Click **Create**

## 3. Create NFS User and Group

The NFS user and group must have specific UID/GID values that match the configuration in `vault.yml` (default: 3000).

### Via TrueNAS Web UI:

1. Go to **Credentials** → **Local Groups**
2. Click **Add**:
   - Group Name: `nfsusers`
   - GID: `3000` (or the value in your vault.yml)
   - Click **Save**

3. Go to **Credentials** → **Local Users**
4. Click **Add**:
   - Username: `nfsuser`
   - User ID: `3000` (or the value in your vault.yml)
   - Primary Group: `nfsusers`
   - Home Directory: `/nonexistent`
   - Shell: `nologin`
   - Disable Password: **Checked**
   - Click **Save**

### Via SSH (Alternative Method):

```bash
ssh admin@192.168.0.15

# Create group
sudo groupadd -g 3000 nfsusers

# Create user
sudo useradd -u 3000 -g nfsusers -s /usr/sbin/nologin -M nfsuser
```

### Update Vault if Using Different UID/GID:

If you created the user/group with different IDs, update your vault:

```bash
ansible-vault edit vault.yml
```

Update these values:
```yaml
vault_nfs_uid: 3000  # Change to your UID
vault_nfs_gid: 3000  # Change to your GID
```

## 4. Create Dataset for Unified Media Storage

Following [TraSH Guides recommendations](https://trash-guides.info/File-and-Folder-Structure/How-to-set-up/Docker/),
create a single unified dataset that will contain all media and downloads in an organized structure.

1. In TrueNAS Web UI, go to **Datasets**
2. Click **Add Dataset** for the `tank` pool:
   - Name: `data`
   - Click **Save**

3. Set permissions on the dataset:
   - Select `tank/data` → **Edit** → **Permissions**
   - Owner: `nfsuser` (UID 3000)
   - Group: `nfsusers` (GID 3000)
   - **ACL Type**: POSIX
   - **ACL Preset**: POSIX_RESTRICTED
   - Access Mode: `770` (owner and group full access, others blocked)
   - Apply **Recursively**
   - Click **Save**

### TrueNAS Web UI Configuration Steps:

When setting permissions, you'll be prompted to select an ACL preset. Follow these steps:

1. Navigate to **Datasets** in TrueNAS Web UI
2. Select the `tank/data` dataset
3. Click **Edit** → **Permissions**
4. When prompted "Select a preset ACL":
   - Choose **POSIX_RESTRICTED**
5. Verify the following settings are configured:
   - Owner: `nfsuser` (UID 3000)
   - Group: `nfsusers` (GID 3000)
   - Access Mode shows: `770`
6. Check **Apply permissions recursively**
7. Click **Save**

**Why POSIX_RESTRICTED (770)?**

- **Security**: Only `nfsuser:nfsusers` (UID/GID 3000) can access the data
- **Isolation**: All Docker containers run as PUID=3000, PGID=3000, matching this user
- **Protection**: Prevents unauthorized access from other users or services
- **NFS Alignment**: Matches the NFS Maproot configuration (nfsuser:nfsusers)
- **Simplicity**: Clean permission model - only media services need access

**Folder Structure**: The Ansible playbook (09-configure-nfs-and-migrate-to-storage.yml) will automatically create the
TraSH Guides folder structure inside this dataset:

```
/mnt/tank/data/
├── torrents/
│   ├── tv/
│   ├── movies/
│   └── incomplete/
├── usenet/
│   ├── tv/
│   ├── movies/
│   └── incomplete/
└── media/
    ├── tv/
    └── movies/
```

**Why this structure?**

- **Hardlinks work**: Sonarr/Radarr can instantly move files from downloads to media without copying
- **Atomic moves**: File operations are instant, not copy+delete
- **No double disk usage**: Downloaded files and final media share the same inode
- **TraSH Guides compliant**: Follows community best practices

## 5. Create NFS Share

Create a single NFS share for the unified data structure:

1. In TrueNAS Web UI, go to **Shares** → **Unix (NFS) Shares**
2. Click **Add**:
   - Path: `/mnt/tank/data`
   - Description: `Unified media storage (TraSH Guides structure)`
   - Authorized Networks: Add both networks:
     - `192.168.0.0/24` (local network)
     - `100.64.0.0/10` (Tailscale network)
   - Maproot User: `nfsuser`
   - Maproot Group: `nfsusers`
   - Click **Save**

   **Note**: Including the Tailscale network (`100.64.0.0/10`) is required since the media services VM will connect to
   TrueNAS over Tailscale.

3. Start the NFS service:
   - Go to **System Settings** → **Services**
   - Enable **NFS** service
   - Click **Start**

## 6. Configure Tailscale (Recommended)

Install Tailscale via TrueNAS Apps (recommended method):

1. In TrueNAS Web UI, go to **Apps** → **Discover Apps**
2. Search for "Tailscale" and install the official app
3. Configure with your Tailscale auth key from https://login.tailscale.com/admin/settings/keys
4. Start the Tailscale app
5. Verify access at: `http://truenas.discus-moth.ts.net`

After Tailscale is running, you can access TrueNAS from anywhere on your Tailscale network.

**Note**: TrueNAS Apps require a ZFS pool to be configured before installation. This is why Tailscale installation comes
after pool and storage setup.

## 7. Add Ansible SSH Key (Optional - For Key-Based Authentication)

**Note**: This step is optional. Ansible playbooks can use password authentication (configured in Section 1 and
vault.yml). Adding an SSH key allows password-less authentication.

To enable key-based authentication for Ansible:

1. Copy your public key:

   ```bash
   cat ~/.ssh/ansible_homelab.pub
   ```

2. In TrueNAS Web UI, go to **Credentials** → **Local Users**
3. Edit the `admin` user
4. In the **SSH Public Key** field, paste the contents of `ansible_homelab.pub`
5. Click **Save**

Test Ansible connectivity:
```bash
ansible -i inventory.ini truenas -m ping
```

**Security Note**: After adding the SSH key, you can optionally disable password authentication by editing the SSH
service settings and unchecking "Log in as Root with Password". However, keep password authentication enabled if you
want to maintain the ability to SSH with a password.

## 8. Run NFS Mount Playbook

After completing the above steps, run the NFS configuration playbook on the media services VM:

```bash
cd playbooks
ansible-playbook -i ../inventory.ini 09-configure-nfs-and-migrate-to-storage.yml
```

This playbook will:

- Install NFS client on media services VM
- Create matching nfsuser/nfsusers with the UID/GID from vault.yml (default: 3000)
- Mount the NFS share at `/mnt/data` using Tailscale hostname
- Create the TraSH Guides folder structure (torrents, usenet, media subdirectories)
- Configure `/etc/fstab` for persistent mount
- Restart media services to use NFS storage

## 9. Verify NFS Mount

SSH into the media services VM and verify the mount:

```bash
ssh ansible@media-services.discus-moth.ts.net

# Check mount
mount | grep nfs
df -h | grep nfs

# Verify TraSH Guides folder structure was created
ls -la /mnt/data
ls -la /mnt/data/torrents
ls -la /mnt/data/usenet
ls -la /mnt/data/media

# Test write access
touch /mnt/data/torrents/test.txt
rm /mnt/data/torrents/test.txt

# Check permissions (should be owned by nfsuser:nfsuser)
ls -la /mnt/data
```

Expected output (POSIX_RESTRICTED / 770 permissions):
```
drwxrwx--- 5 nfsuser nfsusers 4096 ... data
drwxrwx--- 4 nfsuser nfsusers 4096 ... torrents
drwxrwx--- 4 nfsuser nfsusers 4096 ... usenet
drwxrwx--- 4 nfsuser nfsusers 4096 ... media
```

Note: Permissions show `rwxrwx---` (770):

- Owner (nfsuser): read, write, execute
- Group (nfsusers): read, write, execute
- Others: no access

## 10. Redeploy Media Services

If you've already deployed the media services stack, redeploy it to use the correct NFS UID/GID:

```bash
cd playbooks
ansible-playbook -i ../inventory.ini 05-configure-media-services.yml
```

This will recreate the Docker Compose file with the PUID/PGID values from your vault.yml (default: PUID=3000,
PGID=3000). If you specified different UID/GID values in the vault, those will be used instead.

**Important**: The UID/GID used by Docker containers must match the NFS user created in TrueNAS. Both are configured
from `vault_nfs_uid` and `vault_nfs_gid` in vault.yml.

## Troubleshooting

### NFS Mount Permission Denied

- Verify UID/GID match between TrueNAS and media services VM
- Check NFS share permissions in TrueNAS
- Verify `Maproot User` and `Maproot Group` are set correctly in NFS share config
- Ensure Tailscale network (`100.64.0.0/10`) is in the Authorized Networks list

### Cannot Write to NFS Shares

- Check dataset permissions in TrueNAS
- Verify the nfsuser owns the datasets
- Check NFS service is running in TrueNAS

### Ansible Cannot Connect to TrueNAS

- Verify SSH key is added to admin user in TrueNAS
- Test manual SSH: `ssh -i ~/.ssh/ansible_homelab admin@truenas.discus-moth.ts.net`
- Check Tailscale connectivity

### NFS Mounts Not Connecting

- Verify Tailscale is running on both TrueNAS and media services VM
- Test connectivity: `ping truenas.discus-moth.ts.net` from media services VM
- Check NFS service is running: `systemctl status nfs-server` on TrueNAS
- Verify firewall allows NFS traffic (port 2049)

## Additional Configuration

### Snapshots (Recommended)

1. Go to **Data Protection** → **Periodic Snapshot Tasks**
2. Create snapshot schedules for `tank/media` and `tank/downloads`
3. Recommended: Hourly snapshots, keep for 7 days

### Backup (Recommended)

Consider setting up TrueNAS Cloud Sync or Replication tasks to backup your media and downloads to an external location.

### SMART Monitoring

1. Go to **Data Protection** → **S.M.A.R.T. Tests**
2. Enable weekly short tests and monthly long tests for your disks

## References

- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
- [NFS Share Configuration](https://www.truenas.com/docs/scale/scaletutorials/shares/nfs/addnfsshare/)
- [Dataset Permissions](https://www.truenas.com/docs/scale/scaletutorials/datasets/)

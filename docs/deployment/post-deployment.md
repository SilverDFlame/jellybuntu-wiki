# Post-Deployment Configuration

Manual configuration steps to complete after Phase 3 deployment and before running Phase 4.

## Overview

After Phase 3 completes, your services are deployed but require manual configuration through their web UIs. This guide
walks you through:

1. Retrieving API keys from Sonarr and Radarr
2. Adding API keys to the encrypted vault
3. Configuring download clients
4. Verifying service connectivity
5. Running Phase 4 for final configuration and security hardening

## Prerequisites

- Phase 3 deployment completed successfully
- All services accessible via Tailscale hostnames
- Access to the vault password

## Step 1: Retrieve API Keys

### Sonarr API Key

1. Access Sonarr: `http://media-services.discus-moth.ts.net:8989`
2. Navigate to **Settings** → **General** (show advanced settings)
3. Scroll to **Security** section
4. Copy the **API Key**
5. Save this key for Step 2

### Radarr API Key

1. Access Radarr: `http://media-services.discus-moth.ts.net:7878`
2. Navigate to **Settings** → **General** (show advanced settings)
3. Scroll to **Security** section
4. Copy the **API Key**
5. Save this key for Step 2

## Step 2: Add API Keys to Secrets File

1. Edit the encrypted secrets file:

   ```bash
   sops group_vars/all.sops.yaml
   ```

2. Add or update these lines:

   ```yaml
   # Media Services API Keys
   vault_sonarr_api_key: "your_sonarr_api_key_here"
   vault_radarr_api_key: "your_radarr_api_key_here"
   ```

3. Replace the placeholder values with your actual API keys
4. Save and exit (`:wq` in vi/vim)

## Step 3: Configure Download Clients

### Configure Prowlarr

> **Note**: qBittorrent is automatically configured via API during deployment (playbook 07), including paths,
categories, performance limits, and privacy settings. Manual configuration is minimal.

1. Access Prowlarr: `http://media-services.discus-moth.ts.net:9696`
2. Navigate to **Settings** → **Download Clients**
3. Add download clients:

   **qBittorrent**:

   - Host: `download-clients.discus-moth.ts.net`
   - Port: `8080`
   - Username: `admin`
   - Password: (from secrets file `services_admin_password`)

   **SABnzbd**:

   - Host: `download-clients.discus-moth.ts.net`
   - Port: `8081`
   - API Key: (get from SABnzbd: Config → General → API Key)

4. Add indexers in **Indexers** section
5. Navigate to **Settings** → **Apps** and add:
   - Sonarr (Full Sync)
     - Prowlarr Server: `http://prowlarr:9696`
     - Sonarr Server: `http://sonarr:8989`
     - API Key: (from Step 1)
   - Radarr (Full Sync)
     - Prowlarr Server: `http://prowlarr:9696`
     - Radarr Server: `http://radarr:7878`
     - API Key: (from Step 1)

### Configure Sonarr Download Clients

1. Access Sonarr: `http://media-services.discus-moth.ts.net:8989`
2. Navigate to **Settings** → **Download Clients**
3. Add the same download clients as above

### Configure Radarr Download Clients

1. Access Radarr: `http://media-services.discus-moth.ts.net:7878`
2. Navigate to **Settings** → **Download Clients**
3. Add the same download clients as above

## Step 4: Verify Connectivity

### Check NFS Mounts

SSH into a service VM and verify NFS storage is mounted:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net
df -h | grep /mnt/data
ls -la /mnt/data
```

You should see the NFS mount and directory structure:

- `/mnt/data/media/tv`
- `/mnt/data/media/movies`
- `/mnt/data/torrents/`
- `/mnt/data/usenet/`

### Test Download Client Connectivity

1. In Sonarr/Radarr, go to **Settings** → **Download Clients**
2. Click **Test** on each download client
3. All should show green checkmarks

### Test Indexer Connectivity

1. In Prowlarr, go to **Indexers**
2. Click **Test All**
3. Verify all indexers respond successfully

## Step 5: Run Phase 4

Once all manual configuration is complete and verified:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

Phase 4 will:

1. Configure Recyclarr with TRaSH Guides custom formats
2. Enable UFW firewall (SSH from Tailscale + LAN)
3. Configure unattended security updates

**Note**: SSH remains accessible via both Tailscale hostnames and local network IPs (LAN fallback for outages).

## Troubleshooting

### Can't Access Services

- Verify Tailscale is running on your local machine
- Check that VMs are connected to Tailscale: `tailscale status`
- Try accessing via IP address as fallback (before Phase 4)

### Download Clients Not Connecting

- Verify download client VMs are running
- Check Docker containers: `docker ps`
- Verify network connectivity between VMs
- Check firewall rules (before Phase 4)

### NFS Mount Issues

- Check NAS VM is running
- Verify NFS server is active: `sudo systemctl status nfs-server` (on NAS)
- Check exports: `sudo exportfs -v` (on NAS)
- Remount if needed: `sudo mount -a` (on client VM)

### API Key Issues

- Ensure API keys were copied correctly (no extra spaces)
- Verify secrets file was saved after editing
- View secrets: `sops -d group_vars/all.sops.yaml`

## Next Steps

After Phase 4 completes:

1. **Configure Jellyseerr**:
   - Link to Jellyfin server
   - Connect to Sonarr/Radarr
   - Set up user authentication

2. **Configure Jellyfin**:
   - Add media libraries pointing to `/data/media/`
   - Configure transcoding settings
   - Set up user accounts

3. **Test Automation**:
   - Request a show/movie in Jellyseerr
   - Verify it appears in Sonarr/Radarr
   - Monitor download progress
   - Confirm it appears in Jellyfin

4. **Customize Settings**:
   - Adjust quality profiles in Sonarr/Radarr
   - Configure notification agents
   - Set up custom formats (Recyclarr handles most of this)

## Reference

- [Sonarr Documentation](https://wiki.servarr.com/sonarr)
- [Radarr Documentation](https://wiki.servarr.com/radarr)
- [Prowlarr Documentation](https://wiki.servarr.com/prowlarr)
- [TRaSH Guides](https://trash-guides.info/)
- [Jellyfin Documentation](https://jellyfin.org/docs/)

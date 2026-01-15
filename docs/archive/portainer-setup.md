# Portainer Setup Guide

Portainer is a lightweight Docker management UI that provides an easy-to-use interface for managing containers, images,
networks, and volumes.

## Overview

- **VM**: media-services (192.168.0.13)
- **Ports**: 9000 (HTTP), 9443 (HTTPS)
- **Container**: portainer
- **Data Path**: `/opt/media-stack/portainer`
- **Image**: docker.io/portainer/portainer-ce:2.24.0 (Community Edition)

## Access

- **Tailscale HTTP**: http://media-services.discus-moth.ts.net:9000
- **Tailscale HTTPS**: https://media-services.discus-moth.ts.net:9443
- **Local Network HTTP**: http://192.168.0.13:9000
- **Local Network HTTPS**: https://192.168.0.13:9443

## Initial Setup

### 1. First-Time Access

When you first access Portainer, you'll need to create an admin account:

1. **Access the Web UI**:

   ```bash
   # Via browser (HTTP - recommended for initial setup)
   http://media-services.discus-moth.ts.net:9000
   ```

2. **Create Admin User** (must be done within 5 minutes of first startup):
   - **Username**: admin (recommended)
   - **Password**: Create a strong password (minimum 12 characters)
   - Confirm password
   - Click "Create user"

   > **Important**: If you don't create a user within 5 minutes, Portainer will lock itself. To reset, you need to
   restart the container.

3. **Connect to Local Docker Environment**:
   - Select "Get Started" or "Local"
   - Portainer will automatically connect to the local Docker socket
   - Click "Connect"

4. **Dashboard Overview**:
   - You'll see the "local" environment
   - Shows containers, images, volumes, networks summary

### 2. Reset If Initial Setup Times Out

If you didn't create an admin account in time:

```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Restart Portainer to reset the timer
docker restart portainer

# Access within 5 minutes and create admin account
```

## Environment Configuration

### Local Environment

The local environment is automatically configured and manages Docker on the media-services VM:

1. Go to **Home**
2. Click on **local** environment
3. You'll see overview of:
   - Running/stopped containers
   - Images
   - Volumes
   - Networks
   - Stacks (Docker Compose applications)

### Add Remote Environments (Optional)

To manage other VMs (jellyfin, download-clients, nas):

#### Option A: Portainer Agent (Recommended)

On each remote VM, deploy the Portainer agent:

```bash
# SSH to remote VM (e.g., jellyfin)
ssh -i ~/.ssh/ansible_homelab ansible@jellyfin.discus-moth.ts.net

# Run Portainer agent
docker run -d \
  -p 9001:9001 \
  --name portainer_agent \
  --restart=unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  portainer/agent:latest
```

Then in Portainer UI:

1. Go to **Environments** → **Add environment**
2. Select **Agent**
3. **Name**: jellyfin (or appropriate name)
4. **Environment URL**: `jellyfin.discus-moth.ts.net:9001` or `192.168.0.12:9001`
5. Click **Add environment**

Repeat for other VMs (download-clients, nas).

#### Option B: Docker API (Less Secure)

Requires exposing Docker API - not recommended for security reasons.

## User Management

### Create Additional Users

1. Go to **Settings** → **Users**
2. Click **Add user**
3. Fill in:
   - **Username**: User login name
   - **Password**: Set strong password
4. Click **Create user**

### Assign User Roles

Portainer has two built-in roles:

- **Administrator**: Full access to all features
- **User**: Limited access (can only view/manage authorized resources)

To set role:

1. **Settings** → **Users** → Click on user
2. Select role
3. Save

### Team Management (Optional)

For organizing users:

1. Go to **Settings** → **Teams**
2. Click **Add team**
3. Name the team
4. Add users to team
5. Use teams when assigning resource access

## Container Management

### View Containers

1. Navigate to environment (e.g., **local**)
2. Click **Containers**
3. See all containers with status, ports, resource usage

### Common Container Operations

**Start/Stop/Restart Container**:

1. Select container(s) using checkbox
2. Click **Start**, **Stop**, or **Restart** button

**View Container Logs**:

1. Click on container name
2. Go to **Logs** tab
3. Use controls to:
   - Auto-refresh
   - Show timestamps
   - Change number of lines
   - Search logs

**View Container Stats**:

1. Click on container name
2. Go to **Stats** tab
3. See real-time CPU, memory, network, I/O usage

**Execute Commands in Container**:

1. Click on container name
2. Go to **Console** tab
3. Choose shell (usually `/bin/sh` or `/bin/bash`)
4. Click **Connect**
5. Execute commands interactively

**Inspect Container**:

1. Click on container name
2. Go to **Inspect** tab
3. See full container configuration JSON

### Update Container

To pull new image and recreate container:

1. Click on container name
2. Click **Recreate** button
3. Options:
   - **Pull latest image**: Check this to update
   - **Always pull**: Always pull even if cached
4. Click **Recreate**

## Stack Management (Docker Compose)

Portainer calls Docker Compose applications "Stacks".

### View Existing Stack

1. Go to **Stacks**
2. See deployed stacks (your Docker Compose deployments)
3. Click stack name to view:
   - Services
   - Containers
   - Editor (view/edit compose file)

### Deploy New Stack

1. Go to **Stacks** → **Add stack**
2. Choose method:
   - **Web editor**: Paste docker-compose.yml content
   - **Upload**: Upload compose file
   - **Git repository**: Deploy from git

3. **Web Editor Example**:
   - **Name**: my-app
   - **Web editor**: Paste docker-compose.yml
   - **Environment variables** (optional): Add env vars
   - Click **Deploy the stack**

### Update Stack

1. Go to **Stacks** → Click stack name
2. Go to **Editor** tab
3. Modify docker-compose.yml
4. Click **Update the stack**
5. Options:
   - **Prune services**: Remove services no longer defined
   - **Pull and redeploy**: Pull latest images

### Remove Stack

1. Go to **Stacks**
2. Select stack(s)
3. Click **Remove**
4. Confirm removal

## Image Management

### View Images

1. Go to **Images**
2. See all Docker images with:
   - Repository and tag
   - Image ID
   - Size
   - Date created

### Pull Image

1. Go to **Images**
2. Click **Pull image**
3. Enter:
   - **Image**: e.g., `nginx:latest`
   - **Registry**: Docker Hub (default) or custom
4. Click **Pull the image**

### Remove Unused Images

1. Go to **Images**
2. Select unused images
3. Click **Remove**
4. Or use **Prune unused images** to remove all at once

### Build Image

1. Go to **Images**
2. Click **Build a new image**
3. Options:
   - **Web editor**: Paste Dockerfile
   - **Upload**: Upload Dockerfile
4. **Image name**: e.g., `my-image:latest`
5. Click **Build the image**

## Volume Management

### View Volumes

1. Go to **Volumes**
2. See all Docker volumes with:
   - Name
   - Driver
   - Mount point
   - Size

### Browse Volume Contents

1. Click on volume name
2. Click **Browse** button
3. Navigate filesystem
4. View/download files

### Create Volume

1. Go to **Volumes**
2. Click **Add volume**
3. **Name**: volume name
4. **Driver**: local (default)
5. Click **Create the volume**

### Backup Volume

Using browse feature:

1. Click on volume → **Browse**
2. Select files/folders
3. Click **Download** to backup locally

Or SSH to VM:
```bash
# List volumes
docker volume ls

# Backup volume
docker run --rm \
  -v volume-name:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/volume-backup.tar.gz -C /data .
```

## Network Management

### View Networks

1. Go to **Networks**
2. See Docker networks with connected containers

### Create Network

1. Go to **Networks**
2. Click **Add network**
3. **Name**: network name
4. **Driver**: bridge (default) or custom
5. Click **Create the network**

## Settings and Configuration

### Change Admin Password

1. Go to **Settings** (gear icon)
2. Click **Users** → **admin**
3. **New password**: Enter new password
4. Confirm password
5. Click **Update password**

### Enable HTTPS

Portainer supports HTTPS on port 9443:

1. Portainer will auto-generate self-signed certificate
2. Access: https://media-services.discus-moth.ts.net:9443
3. Accept self-signed certificate warning in browser

For custom certificate:
```bash
# SSH to media-services VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# Place certificate files
sudo mkdir -p /opt/media-stack/portainer/certs
sudo cp your-cert.crt /opt/media-stack/portainer/certs/portainer.crt
sudo cp your-key.key /opt/media-stack/portainer/certs/portainer.key

# Update compose file to mount certificates
# Add to volumes:
#   - ./portainer/certs:/certs

# Restart Portainer
docker restart portainer
```

### Authentication Settings

1. Go to **Settings** → **Authentication**
2. Options:
   - **Internal**: Portainer's built-in authentication (default)
   - **LDAP**: Integrate with LDAP server
   - **OAuth**: Use OAuth provider

### Session Timeout

1. Go to **Settings** → **Settings**
2. **User session timeout**: Set timeout (default: 8 hours)
3. Click **Save settings**

## Best Practices

### Security

1. **Use Strong Admin Password**: 16+ characters, mix of types
2. **Enable HTTPS**: Use port 9443 for encrypted connections
3. **Limit User Access**: Only grant admin to trusted users
4. **Regular Updates**: Keep Portainer updated
5. **Firewall**: Restrict access to trusted networks (Tailscale/local)

### Resource Management

1. **Monitor Stats**: Regularly check container resource usage
2. **Clean Up**: Remove unused images, volumes, networks
3. **Log Rotation**: Check container logs don't fill disk

### Backup

Backup Portainer data:
```bash
# Backup Portainer config/data
sudo tar -czf portainer-backup-$(date +%Y%m%d).tar.gz \
  /opt/media-stack/portainer

# Copy to NAS
sudo cp portainer-backup-*.tar.gz /mnt/data/backups/
```

## Advanced Features

### Webhooks

Create webhooks to update containers automatically:

1. Click on container name
2. Go to **Webhooks** tab
3. Click **Create a webhook**
4. Copy webhook URL
5. Use webhook to trigger container recreation:

   ```bash
   curl -X POST https://webhook-url
   ```

### App Templates

Deploy pre-configured applications:

1. Go to **App Templates**
2. Browse available templates
3. Click template to deploy
4. Configure parameters
5. Deploy

### Registry Management

Add custom Docker registries:

1. Go to **Registries**
2. Click **Add registry**
3. Choose registry type (Docker Hub, GitLab, etc.)
4. Enter credentials
5. Save

## Troubleshooting

### Can't Access Web UI

```bash
# Check if container is running
docker ps | grep portainer

# Check logs
docker logs portainer

# Restart if needed
docker restart portainer
```

### Forgot Admin Password

```bash
# Reset admin password (requires container restart)
docker stop portainer

# Start with password reset flag
docker run --rm \
  -v /opt/media-stack/portainer:/data \
  docker.io/portainer/portainer-ce:2.24.0 \
  --admin-password='$(htpasswd -nb -B admin your-new-password | cut -d ":" -f 2)'

# Restart normally
docker start portainer
```

Or easier method:
```bash
# Remove Portainer data (lose all settings!)
docker stop portainer
sudo rm -rf /opt/media-stack/portainer
docker start portainer
# Reconfigure from scratch
```

### Can't Connect to Docker

```bash
# Verify Docker socket permissions
ls -l /var/run/docker.sock

# Should be accessible by docker group
# Portainer container needs socket access
```

## See Also

- [Service Endpoints](../configuration/service-endpoints.md)
- [Docker Troubleshooting](docker-troubleshooting.md)
- [Common Issues](../troubleshooting/common-issues.md)

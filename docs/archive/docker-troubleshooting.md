# Docker Troubleshooting

Troubleshooting guide for Docker and Docker Compose issues.

## Quick Checks

```bash
# Check Docker service
sudo systemctl status docker

# List running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Check Docker logs
sudo journalctl -u docker -n 50

# Check Docker version
docker --version
docker compose version
```

## Common Issues

### 1. Docker Service Not Running

**Symptoms**:

- `docker ps` fails with "Cannot connect to the Docker daemon"
- Services won't start
- Docker commands hang

**Diagnosis**:

```bash
# Check service status
sudo systemctl status docker

# View logs
sudo journalctl -u docker -n 100 --no-pager

# Check if docker socket exists
ls -la /var/run/docker.sock
```

**Solutions**:

1. **Service stopped**:

   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

2. **Socket permission issues**:

   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER

   # Log out and back in for changes to take effect
   # Or use newgrp
   newgrp docker
   ```

3. **Docker daemon crashed**:

   ```bash
   # Check logs for errors
   sudo journalctl -u docker -n 200 --no-pager

   # Restart Docker
   sudo systemctl restart docker
   ```

### 2. Container Won't Start

**Symptoms**:

- `docker compose up` fails
- Container immediately exits
- "Container X exited with code 1"

**Diagnosis**:

```bash
# Check container status
docker ps -a | grep CONTAINER_NAME

# View container logs
docker logs CONTAINER_NAME --tail 100

# Inspect container
docker inspect CONTAINER_NAME

# Try starting manually
docker start CONTAINER_NAME
docker logs CONTAINER_NAME -f
```

**Solutions**:

1. **Port already in use**:

   ```bash
   # Find what's using the port
   sudo lsof -i :PORT_NUMBER

   # Stop conflicting service or change port
   ```

2. **Permission issues**:

   ```bash
   # Check volume mount permissions
   ls -la /path/to/mounted/volume

   # Fix ownership (3000:3000 for media services)
   sudo chown -R 3000:3000 /path/to/mounted/volume
   ```

3. **Missing or invalid config**:

   ```bash
   # Check for config errors
   docker logs CONTAINER_NAME

   # Verify environment variables
   docker exec CONTAINER_NAME env
   ```

4. **Image pull failed**:

   ```bash
   # Pull image manually
   docker pull IMAGE_NAME:TAG

   # Check Docker Hub for image availability
   ```

### 3. Container Keeps Restarting

**Symptoms**:

- Container status shows "Restarting"
- Service unavailable intermittently
- High CPU usage from Docker

**Diagnosis**:

```bash
# Check container status
docker ps -a | grep CONTAINER_NAME

# View logs for crash cause
docker logs CONTAINER_NAME --tail 200

# Check restart policy
docker inspect CONTAINER_NAME | grep -A 5 RestartPolicy

# Monitor in real-time
docker stats CONTAINER_NAME
```

**Solutions**:

1. **Application error**:
   - Check logs for specific error messages
   - Fix configuration issues
   - Ensure all dependencies are met

2. **Resource limits**:

   ```bash
   # Check if container is OOM killed
   docker inspect CONTAINER_NAME | grep OOMKilled

   # Increase memory limit in docker-compose.yml
   mem_limit: 2g
   ```

3. **Health check failing**:

   ```bash
   # Check health check config
   docker inspect CONTAINER_NAME | grep -A 10 Healthcheck

   # Temporarily remove health check to debug
   ```

### 4. Docker Compose Issues

**Symptoms**:

- `docker compose up` fails
- "service X not found" errors
- Syntax errors in compose file

**Diagnosis**:

```bash
# Validate compose file
docker compose config

# Check for syntax errors
docker compose -f docker-compose.yml config

# View what would be created
docker compose config --services
```

**Solutions**:

1. **Invalid YAML syntax**:

   ```bash
   # Check indentation (use spaces, not tabs)
   # Validate online: https://www.yamllint.com/

   # Check for common errors
   docker compose config
   ```

2. **Wrong compose file**:

   ```bash
   # Specify file explicitly
   docker compose -f /opt/media-stack/docker-compose.yml up -d

   # Check current directory
   pwd
   ```

3. **Service not found**:

   ```bash
   # Check service names in compose file
   docker compose config --services

   # Use correct service name
   docker compose up -d SERVICE_NAME
   ```

### 5. Volume Mount Issues

**Symptoms**:

- Data not persisting
- "Permission denied" in containers
- Wrong files showing in container

**Diagnosis**:

```bash
# Check volume mounts
docker inspect CONTAINER_NAME | grep -A 20 Mounts

# Check if bind mount exists on host
ls -la /path/to/mount

# Check permissions
ls -ld /path/to/mount

# Test from inside container
docker exec CONTAINER_NAME ls -la /mount/path
docker exec CONTAINER_NAME touch /mount/path/test.txt
```

**Solutions**:

1. **Mount path doesn't exist**:

   ```bash
   # Create directory on host
   sudo mkdir -p /path/to/mount

   # Set correct ownership
   sudo chown -R 3000:3000 /path/to/mount
   ```

2. **Permission denied**:

   ```bash
   # Fix permissions for NFS mounts
   sudo chown -R 3000:3000 /mnt/data

   # For local mounts
   sudo chown -R 3000:3000 /opt/media-stack
   ```

3. **Wrong path in container**:
   - Check docker-compose.yml volume mappings
   - Format: `HOST_PATH:CONTAINER_PATH`
   - Example: `/mnt/data:/data`

### 6. Network Issues

**Symptoms**:

- Containers can't reach each other
- Container can't reach internet
- DNS resolution fails

**Diagnosis**:

```bash
# List networks
docker network ls

# Inspect network
docker network inspect NETWORK_NAME

# Test connectivity between containers
docker exec sonarr ping prowlarr

# Test internet from container
docker exec sonarr ping -c 3 8.8.8.8
docker exec sonarr ping -c 3 google.com
```

**Solutions**:

1. **Containers on different networks**:

   ```bash
   # Check which network containers are on
   docker inspect CONTAINER_NAME | grep NetworkMode

   # Use same network in docker-compose.yml
   # Or create shared network
   ```

2. **DNS not working**:

   ```bash
   # Add DNS to docker-compose.yml
   services:
     sonarr:
       dns:
         - 9.9.9.9
         - 192.168.0.1
   ```

3. **Use container names, not localhost**:
   - Correct: `http://prowlarr:9696`
   - Wrong: `http://localhost:9696`

### 7. High Disk Usage

**Symptoms**:

- Disk space filling up
- "No space left on device" errors
- Docker using too much space

**Diagnosis**:

```bash
# Check Docker disk usage
docker system df

# Check detailed usage
docker system df -v

# Find large containers
docker ps -as

# Find large images
docker images --format "{{.Repository}}:{{.Tag}}\t{{.Size}}" | sort -k2 -h
```

**Solutions**:

1. **Clean up unused resources**:

   ```bash
   # Remove stopped containers
   docker container prune

   # Remove unused images
   docker image prune

   # Remove unused volumes
   docker volume prune

   # Remove everything unused (CAREFUL!)
   docker system prune -a --volumes
   ```

2. **Large log files**:

   ```bash
   # Check log sizes
   sudo du -sh /var/lib/docker/containers/*/*-json.log | sort -h

   # Clear specific container logs
   sudo truncate -s 0 /var/lib/docker/containers/CONTAINER_ID/*-json.log

   # Set log rotation in docker-compose.yml
   logging:
     options:
       max-size: "10m"
       max-file: "3"
   ```

3. **Old build cache**:

   ```bash
   # Remove build cache
   docker builder prune
   ```

## Advanced Troubleshooting

### Reset Docker Completely

```bash
# DANGER: This removes ALL containers, images, volumes

# Stop all containers
docker stop $(docker ps -aq)

# Remove all containers
docker rm $(docker ps -aq)

# Remove all images
docker rmi $(docker images -q)

# Remove all volumes
docker volume rm $(docker volume ls -q)

# Restart Docker
sudo systemctl restart docker
```

### Fix Docker Daemon Issues

```bash
# Check daemon config
cat /etc/docker/daemon.json

# Reset to defaults
sudo systemctl stop docker
sudo mv /etc/docker/daemon.json /etc/docker/daemon.json.bak
sudo systemctl start docker
```

### Container Shell Access

```bash
# Access running container shell
docker exec -it CONTAINER_NAME /bin/bash

# Or if bash not available
docker exec -it CONTAINER_NAME /bin/sh

# Run commands as root
docker exec -u root -it CONTAINER_NAME /bin/bash
```

### Debug Container Networking

```bash
# Enter container
docker exec -it CONTAINER_NAME /bin/bash

# Inside container, test connectivity
ping sonarr
ping 8.8.8.8
nslookup google.com
wget -O- http://prowlarr:9696

# Check DNS config
cat /etc/resolv.conf

# Check hosts file
cat /etc/hosts
```

### View Docker Events

```bash
# Monitor Docker events in real-time
docker events

# Filter events for specific container
docker events --filter container=sonarr

# Check past events
docker events --since '2023-01-01' --until '2023-01-02'
```

## Docker Compose Specific

### Rebuild After Changes

```bash
# Rebuild and restart
docker compose down
docker compose build --no-cache
docker compose up -d

# Or force recreate
docker compose up -d --force-recreate
```

### View Compose Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f sonarr

# Tail logs
docker compose logs --tail=100 sonarr
```

### Scale Services

```bash
# Not typically used in this setup, but available
docker compose up -d --scale SERVICE_NAME=3
```

## Getting Help

If issues persist:

1. **Collect diagnostic info**:

   ```bash
   docker version > /tmp/docker-debug.txt
   docker info >> /tmp/docker-debug.txt
   docker ps -a >> /tmp/docker-debug.txt
   docker system df >> /tmp/docker-debug.txt
   sudo journalctl -u docker -n 200 >> /tmp/docker-debug.txt
   ```

2. **Docker Resources**:
   - Official docs: https://docs.docker.com/
   - Docker forums: https://forums.docker.com/
   - Stack Overflow: https://stackoverflow.com/questions/tagged/docker

## See Also

- [Sonarr/Radarr Troubleshooting](../troubleshooting/sonarr-radarr.md)
- [Download Clients Troubleshooting](../troubleshooting/download-clients.md)
- [Prowlarr Troubleshooting](../troubleshooting/prowlarr.md)
- [Networking Troubleshooting](../troubleshooting/networking.md)
- [Common Issues](../troubleshooting/common-issues.md)

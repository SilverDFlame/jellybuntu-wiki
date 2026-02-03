# Home Assistant Configuration

Home Assistant is an open-source home automation platform that allows you to control and automate smart devices,
create custom dashboards, and build powerful automations.

> **IMPORTANT**: Home Assistant runs as a **rootless Podman container with Quadlet** on the home-assistant VM
> (192.168.0.10). Use `systemctl --user` and `podman` commands, NOT `docker` commands.

## Overview

- **VM**: home-assistant (VMID 100, 192.168.0.10)
- **Port**: 8123
- **Deployment**: Rootless Podman with Quadlet
- **Config Path**: `~/.config/homeassistant/`
- **Playbook**: [`playbooks/core/deploy-home-assistant.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/deploy-home-assistant.yml)

## Access

- **Tailscale**: http://home-assistant.discus-moth.ts.net:8123
- **Local Network**: http://192.168.0.10:8123

## Deployment

### Via Ansible Playbook (Recommended)

```bash
# Deploy Home Assistant
./bin/runtime/ansible-run.sh playbooks/core/deploy-home-assistant.yml
```

### Quadlet Configuration

Located at `~/.config/containers/systemd/homeassistant.container`:

```ini
[Unit]
Description=Home Assistant
After=network-online.target
Wants=network-online.target

[Container]
Image=ghcr.io/home-assistant/home-assistant:stable
ContainerName=homeassistant
Network=host
Volume=%h/.config/homeassistant:/config:Z
Environment=TZ=America/Denver
# For USB device access (Z-Wave, Zigbee):
# AddDevice=/dev/ttyUSB0

[Service]
Restart=always
TimeoutStartSec=300

[Install]
WantedBy=default.target
```

## Initial Setup

### First-Time Configuration

1. **Access Home Assistant**: http://home-assistant.discus-moth.ts.net:8123
2. **Create Account**: Set up owner username and password
3. **Name Your Home**: Provide a name and location
4. **Discover Devices**: Home Assistant will scan for compatible devices
5. **Complete Setup**: Finish the onboarding wizard

### Directory Structure

```text
~/.config/homeassistant/
├── configuration.yaml    # Main configuration file
├── automations.yaml      # Automation definitions
├── scripts.yaml          # Script definitions
├── scenes.yaml           # Scene definitions
├── secrets.yaml          # Sensitive values (not in git)
├── custom_components/    # HACS and custom integrations
├── www/                  # Custom frontend assets
├── blueprints/           # Automation blueprints
└── .storage/             # Internal state storage
```

## Configuration File

### Main Configuration (configuration.yaml)

```yaml
# Basic configuration
homeassistant:
  name: Home
  latitude: !secret latitude
  longitude: !secret longitude
  elevation: !secret elevation
  unit_system: imperial
  currency: USD
  time_zone: America/Denver

# Enable frontend
frontend:
  themes: !include_dir_merge_named themes

# Enable mobile app
mobile_app:

# Enable history and logbook
history:
recorder:
logbook:

# Enable configuration UI
config:

# HTTP configuration
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.0.0/24
    - 100.64.0.0/10  # Tailscale

# Include other files
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
```

### Secrets File (secrets.yaml)

Store sensitive values separately:

```yaml
latitude: 39.7392
longitude: -104.9903
elevation: 1609
```

## Integrations

### Adding Integrations

1. Settings → Devices & Services → Add Integration
2. Search for the integration
3. Follow the setup wizard
4. Configure options

### Common Integrations

| Integration | Purpose | Setup |
|-------------|---------|-------|
| Mobile App | Control via phone | Install companion app |
| Tailscale | Network access | Discovered automatically |
| MQTT | IoT device communication | Requires MQTT broker |
| Google Home | Voice control | Link accounts |
| HomeKit | Apple device control | Generate pairing code |

### Monitoring Integration

Connect Home Assistant to your monitoring stack:

```yaml
# In configuration.yaml
prometheus:
  namespace: homeassistant
```

Access metrics at: `http://192.168.0.10:8123/api/prometheus`

## Dashboards

### Creating Custom Dashboards

1. Overview → Edit Dashboard
2. Add cards for devices and entities
3. Organize into views/tabs
4. Save changes

### Card Types

| Card Type | Use Case |
|-----------|----------|
| Entity | Simple state display |
| Button | Quick actions |
| Gauge | Sensor values |
| History Graph | Historical data |
| Media Control | Media players |
| Thermostat | Climate control |

### Example Dashboard Layout

```yaml
# Lovelace dashboard example
title: Home
views:
  - title: Overview
    cards:
      - type: weather-forecast
        entity: weather.home
      - type: entities
        title: Lights
        entities:
          - light.living_room
          - light.bedroom
      - type: media-control
        entity: media_player.jellyfin
```

## Automations

### Creating Automations

1. Settings → Automations & Scenes → Create Automation
2. Define trigger (what starts it)
3. Define conditions (optional)
4. Define actions (what happens)

### Example Automation

```yaml
# automations.yaml
- id: 'lights_on_sunset'
  alias: Turn on lights at sunset
  trigger:
    - platform: sun
      event: sunset
      offset: "-00:30:00"
  condition:
    - condition: state
      entity_id: person.owner
      state: home
  action:
    - service: light.turn_on
      target:
        area_id: living_room
      data:
        brightness_pct: 75
```

### Automation Templates

Use blueprints for common automations:

1. Settings → Automations → Blueprints
2. Browse community blueprints
3. Import and customize

## HACS (Home Assistant Community Store)

### Installing HACS

```bash
# SSH to home-assistant VM
ssh -i ~/.ssh/ansible_homelab ansible@home-assistant.discus-moth.ts.net

# Download HACS
cd ~/.config/homeassistant
wget -O - https://get.hacs.xyz | bash -

# Restart Home Assistant
systemctl --user restart homeassistant
```

### Using HACS

1. Settings → Integrations → Add Integration → HACS
2. Authorize with GitHub
3. Browse and install:
   - Custom integrations
   - Lovelace cards
   - Themes
   - Python scripts

## Device Integration

### USB Device Passthrough

For Z-Wave/Zigbee USB sticks:

1. Pass through USB device in Proxmox

1. Update Quadlet file:

   ```ini
   [Container]
   AddDevice=/dev/ttyUSB0
   ```

1. Restart service:

   ```bash
   systemctl --user daemon-reload
   systemctl --user restart homeassistant
   ```

### Network Devices

Most network devices are discovered automatically:

- Philips Hue bridges
- Sonos speakers
- Chromecast devices
- Smart TVs

## Backup and Restore

### Creating Backups

**Via UI**:

1. Settings → System → Backups
2. Create Backup
3. Download the backup file

**Via Command Line**:

```bash
# Stop Home Assistant
systemctl --user stop homeassistant

# Create backup
tar -czf ~/homeassistant-backup-$(date +%Y%m%d).tar.gz \
  -C ~/.config homeassistant

# Copy to safe location
cp ~/homeassistant-backup-*.tar.gz /mnt/data/backups/

# Start Home Assistant
systemctl --user start homeassistant
```

### Restoring Backups

**Via UI**:

1. Settings → System → Backups
2. Upload backup file
3. Restore

**Via Command Line**:

```bash
# Stop Home Assistant
systemctl --user stop homeassistant

# Restore backup
rm -rf ~/.config/homeassistant
tar -xzf ~/homeassistant-backup-YYYYMMDD.tar.gz -C ~/.config/

# Start Home Assistant
systemctl --user start homeassistant
```

## Service Management

### Check Status

```bash
systemctl --user status homeassistant
```

### View Logs

```bash
# Follow logs
journalctl --user -u homeassistant -f

# Recent logs
journalctl --user -u homeassistant -n 100

# Errors only
journalctl --user -u homeassistant | grep -i error
```

### Restart Service

```bash
systemctl --user restart homeassistant
```

### Update Home Assistant

```bash
# Pull latest image
podman pull ghcr.io/home-assistant/home-assistant:stable

# Restart service
systemctl --user restart homeassistant

# Check version in UI: Settings → About
```

## Security Configuration

### Authentication

1. Settings → Users → Add User
2. Configure permissions
3. Enable MFA (optional but recommended)

### Network Security

```yaml
# In configuration.yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.0.0/24    # Local network
    - 100.64.0.0/10     # Tailscale
  ip_ban_enabled: true
  login_attempts_threshold: 5
```

### API Access

Generate long-lived access tokens:

1. Profile (bottom left) → Security
2. Long-Lived Access Tokens → Create Token
3. Store securely for external integrations

## Performance Tuning

### Database Configuration

```yaml
# In configuration.yaml
recorder:
  db_url: sqlite:////config/home-assistant_v2.db
  purge_keep_days: 10
  commit_interval: 1
  exclude:
    domains:
      - automation
      - updater
    entity_globs:
      - sensor.weather_*
```

### Reduce Logging

```yaml
# In configuration.yaml
logger:
  default: warning
  logs:
    homeassistant.components.http: warning
    homeassistant.components.recorder: warning
```

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Can't access web UI | Check service: `systemctl --user status homeassistant` |
| Integration not working | Check logs for errors, verify credentials |
| Slow performance | Check database size, reduce history retention |
| Automations not running | Verify conditions, check automation trace |
| Config errors | Use Developer Tools → YAML to validate |

## See Also

- [Home Assistant Troubleshooting](../troubleshooting/home-assistant.md)
- [Service Endpoints](service-endpoints.md)
- [Monitoring Stack Setup](monitoring-stack-setup.md)

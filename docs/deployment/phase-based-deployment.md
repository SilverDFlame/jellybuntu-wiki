# Phase-Based Deployment Guide

Overview of the phased deployment approach for Jellybuntu infrastructure.

## Overview

The Jellybuntu deployment is broken into 4 distinct phases to provide better visibility, easier troubleshooting, and
logical separation of concerns. Each phase can be run independently and has clear success criteria.

**Total Deployment Time**: 20-30 minutes (all phases)

## Deployment Phases

### Phase 1: Infrastructure Provisioning (3-5 minutes)

**Purpose**: Provision all virtual machines on Proxmox

**Prerequisites**:

- Tailscale installed and running on Proxmox host
- Tailscale SSH enabled (recommended)
- Initial setup completed (SOPS secrets, SSH keys, Proxmox API user)

**What it does**:

- Creates cloud-init template (VMID 9000)
- Clones 6 VMs from template
- Configures VM resources, networking, and storage
- Starts all VMs

**Command**:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml
```

**Success Criteria**:

- All 6 VMs created and running
- VMs accessible via SSH (IP addresses)
- Cloud-init completed on all VMs

**Detailed Guide**: [Phase 1: Infrastructure](phase1-infrastructure.md)

---

### Phase 2: Networking Configuration (4-6 minutes)

**Purpose**: Configure storage infrastructure and VPN mesh network

**What it does**:

- Configures Btrfs RAID1 on NAS VM
- Sets up NFS server with exports
- Installs Tailscale on all VMs
- Registers VMs on Tailscale network

**Command**:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml
```

**Success Criteria**:

- NAS has Btrfs RAID1 array operational
- NFS exports available
- All VMs connected to Tailscale
- VMs accessible via Tailscale hostnames

**Detailed Guide**: [Phase 2: Networking](phase2-networking.md)

---

### Phase 3: Services Deployment (8-12 minutes)

**Purpose**: Deploy all applications and services

**What it does**:

- Deploys Home Assistant (Docker)
- Deploys Satisfactory game server (SteamCMD)
- Deploys media services (Sonarr, Radarr, Prowlarr, Jellyseerr, Flaresolverr)
- Deploys download clients (qBittorrent, SABnzbd)
- **Auto-configures qBittorrent** via Web API
- Mounts NFS storage on all client VMs
- Deploys Jellyfin with optimizations

**Command**:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

**Success Criteria**:

- All Docker containers running
- Jellyfin service active
- NFS mounts present on all clients
- qBittorrent configured with password from secrets file
- All services accessible via web UI

**Detailed Guide**: [Phase 3: Services](phase3-services.md)

---

### Manual Configuration Step (15 minutes)

**Not a playbook - requires manual steps** <!-- markdownlint-disable-line MD036 -->

After Phase 3, you must manually:

1. Retrieve API keys from Sonarr and Radarr
2. Add API keys to secrets file
3. Configure download clients in Prowlarr/Sonarr/Radarr
4. Verify connectivity between services

See [post-deployment.md](post-deployment.md) for detailed steps.

---

### Phase 4: Security Hardening (3-5 minutes)

**Purpose**: Apply security hardening and final configuration

**What it does**:

- Configures Recyclarr with TRaSH Guides (requires API keys from vault)
- Enables UFW firewall (SSH from Tailscale + LAN)
- Configures unattended security updates

**Command**:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

**Prerequisites**:

- Phase 3 completed
- API keys added to vault
- Download clients configured

**Success Criteria**:

- Recyclarr configured and synced
- Firewall active (SSH via Tailscale + LAN)
- Unattended upgrades enabled
- All services secured

**Detailed Guide**: [Phase 4: Post-Deployment](phase4-post-deployment.md)

---

## Quick Reference

### Run All Phases (Option A - Single Command)

```bash
./bin/runtime/ansible-run.sh playbooks/main.yml
```

**Note**: This runs Phases 1-3 automatically, but you'll still need to:

1. Complete manual configuration steps
2. Run Phase 4 separately

### Run Phase-by-Phase (Option B - Recommended)

```bash
# Phase 1: Infrastructure
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml

# Phase 2: Networking
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml

# Phase 3: Services
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml

# Manual Configuration (follow post-deployment.md)

# Phase 4: Security Hardening
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

## Phase Dependencies

```text
Phase 1 (Infrastructure)
    ↓
Phase 2 (Networking)
    ↓
Phase 3 (Services)
    ↓
Manual Configuration
    ↓
Phase 4 (Security)
```

**Important**: Each phase depends on the previous phase being completed successfully. Do not skip phases.

## When to Use Phase-Based Deployment

### ✅ Recommended For

- **First-time deployment** - Better visibility into each step
- **Troubleshooting** - Isolate issues to specific phases
- **Learning** - Understand infrastructure layer by layer
- **Incremental updates** - Re-run specific phases after changes

### ⚠️ Consider All-at-Once For

- **Repeat deployments** - You know everything works
- **Time-constrained** - Need fastest deployment
- **Automated CI/CD** - Scripted deployments

## Troubleshooting by Phase

### Phase 1 Issues

- **VM creation fails**: Check Proxmox resources, storage space
- **Cloud-init timeout**: Verify network connectivity, DNS
- **Template creation fails**: Check ISO availability, storage pool

See [Phase 1 Guide](phase1-infrastructure.md#troubleshooting)

### Phase 2 Issues

- **Btrfs creation fails**: Check disk passthrough, disk health
- **NFS exports fail**: Verify NFS server installed, firewall rules
- **Tailscale fails**: Check API key, key expiration, network access

See [Phase 2 Guide](phase2-networking.md#troubleshooting)

### Phase 3 Issues

- **Docker containers fail**: Check NFS mounts, Docker installed
- **qBittorrent config fails**: Verify vault credentials, API access
- **Jellyfin won't start**: Check port availability, service status

See [Phase 3 Guide](phase3-services.md#troubleshooting)

### Phase 4 Issues

- **Recyclarr fails**: Check API keys in vault, Sonarr/Radarr access
- **Firewall blocks SSH**: Use Tailscale hostnames, not IPs
- **Unattended upgrades fail**: Check package manager, system updates

See [Phase 4 Guide](phase4-post-deployment.md#troubleshooting)

## Verification Checklist

After each phase, verify:

### ✅ Phase 1 Complete

- [ ] All VMs visible in Proxmox (`qm list`)
- [ ] All VMs powered on
- [ ] Can SSH to VMs via IP address
- [ ] Cloud-init completed (check `/var/log/cloud-init.log`)

### ✅ Phase 2 Complete

- [ ] Btrfs array healthy (`btrfs filesystem show`)
- [ ] NFS exports present (`exportfs -v`)
- [ ] All VMs in Tailscale (`tailscale status`)
- [ ] Can SSH to VMs via Tailscale hostname

### ✅ Phase 3 Complete

- [ ] Docker containers running (`docker ps`)
- [ ] Jellyfin service active (`systemctl status jellyfin`)
- [ ] NFS mounts present (`df -h | grep nfs`)
- [ ] qBittorrent login works with vault password
- [ ] All web UIs accessible

### ✅ Phase 4 Complete

- [ ] Recyclarr synced (check Sonarr/Radarr custom formats)
- [ ] Firewall active (`ufw status`)
- [ ] SSH via IP blocked, Tailscale works
- [ ] Unattended upgrades enabled

## Re-Running Individual Phases

You can re-run any phase independently:

```bash
# Re-run just Phase 2 (e.g., after changing NAS configuration)
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml

# Re-run just Phase 3 (e.g., after adding a new service)
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

**Note**: Re-running a phase is idempotent - it will only change what needs to be changed.

## Phase Timing Breakdown

| Phase | Min Time | Max Time | Variables |
|-------|----------|----------|-----------|
| Phase 1 | 3 min | 5 min | VM count, Proxmox speed |
| Phase 2 | 4 min | 6 min | Disk size, Tailscale registration |
| Phase 3 | 8 min | 12 min | Docker pulls, service count |
| Manual | 10 min | 20 min | User speed, familiarity |
| Phase 4 | 3 min | 5 min | API response times |
| **Total** | **28 min** | **48 min** | Full deployment |

## Next Steps

1. **Prerequisites**: Ensure you've completed [initial setup](initial-setup.md) (Phases 0-3)
2. **Deploy**: Follow phase-by-phase deployment
3. **Configure**: Complete manual configuration steps
4. **Harden**: Run Phase 4 for security
5. **Validate**: Test end-to-end functionality

## Reference

- [Initial Setup Guide](initial-setup.md) - Complete walkthrough
- [Architecture Overview](../architecture.md) - Infrastructure design
- [Playbooks Reference](../reference/playbooks.md) - Detailed playbook documentation
- [Troubleshooting Guides](../troubleshooting/common-issues.md) - Service-specific issues

## Summary

Phase-based deployment provides:

- ✅ **Visibility** - See progress at each layer
- ✅ **Control** - Pause between phases to verify
- ✅ **Troubleshooting** - Isolate issues by phase
- ✅ **Flexibility** - Re-run individual phases as needed
- ✅ **Learning** - Understand infrastructure build process

For most users, we recommend the phase-by-phase approach for the initial deployment, then using the all-at-once approach
for subsequent deployments once you're familiar with the system.

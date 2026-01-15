# Golden Image Deployment Workflow

This document describes the modern infrastructure deployment workflow using Packer, OpenTofu, and Ansible.

## Overview

The infrastructure modernization introduces a three-tier provisioning system:

```text
┌─────────────────────────────────────────────────────────────┐
│                    1. PACKER (Golden Image)                 │
│  Build base template with pre-installed packages & config   │
│                                                              │
│  Input:  Ubuntu 24.04 ISO                                   │
│  Output: VM-9000 Template                                   │
│                                                              │
│  Includes:                                                   │
│    • Ubuntu 24.04 LTS (fully updated)                       │
│    • Podman container runtime                               │
│    • QEMU Guest Agent                                       │
│    • node_exporter for monitoring                           │
│    • Security baseline (SSH hardening, etc.)                │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│               2. OPENTOFU (Infrastructure)                  │
│     Clone VMs from golden image, configure resources        │
│                                                              │
│  Input:  VM-9000 Template                                   │
│  Output: 7 VMs (NAS, Jellyfin, Media Services, etc.)        │
│                                                              │
│  Configures:                                                 │
│    • VM cloning from golden image                           │
│    • CPU cores, memory, storage                             │
│    • Static IP assignment                                   │
│    • CPU pinning (Satisfactory server)                      │
│    • Additional disks (NAS storage)                         │
│    • Boot order and startup sequencing                      │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│              3. ANSIBLE (Configuration)                     │
│    Configure services, applications, and networking         │
│                                                              │
│  Input:  Running VMs from OpenTofu                          │
│  Output: Fully configured media server infrastructure       │
│                                                              │
│  Configures:                                                 │
│    • Tailscale VPN mesh network                             │
│    • NFS server (NAS) and clients                           │
│    • Docker Compose services (Sonarr, Radarr, etc.)         │
│    • Jellyfin native installation                           │
│    • Firewall rules (UFW)                                   │
│    • Automatic security updates                             │
└─────────────────────────────────────────────────────────────┘
```

## Why This Architecture?

### Advantages

**1. Speed** <!-- markdownlint-disable-line MD036 -->

- VMs boot in ~30 seconds (vs 5-10 minutes for cloud-init)
- No package installation during VM provisioning
- System updates pre-applied to golden image

**2. Consistency** <!-- markdownlint-disable-line MD036 -->

- Every VM starts from identical base
- Reduces configuration drift
- Easier troubleshooting (known good baseline)

**3. Maintainability** <!-- markdownlint-disable-line MD036 -->

- Separation of concerns (infrastructure vs configuration)
- Update base image once, re-clone all VMs
- Infrastructure as Code (IaC) for VM provisioning

**4. Scalability** <!-- markdownlint-disable-line MD036 -->

- Add new VMs quickly by cloning golden image
- Easy to rebuild individual VMs
- Template versioning for rollbacks

### What Each Layer Handles

| Layer | Responsibility | Example Tasks |
|-------|----------------|---------------|
| **Packer** | Base OS & common packages | Install Podman, QEMU agent, system updates, security hardening |
| **OpenTofu** | VM infrastructure | Create VMs, assign IPs, configure CPU/memory/storage |
| **Ansible** | Service configuration | Install Docker containers, configure Tailscale, set up NFS |

## Step-by-Step Deployment

### Prerequisites

1. **Install tools on your workstation:**

   ```bash
   # Packer
   wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
   unzip packer_1.10.0_linux_amd64.zip
   sudo mv packer /usr/local/bin/

   # OpenTofu
   curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh | sudo bash

   # Ansible (if not already installed)
   sudo apt install ansible  # or use setup.sh
   ```

2. **Configure Proxmox credentials:**

   ```bash
   # Run setup script to create SOPS secrets and SSH keys
   ./setup.sh

   # Edit secrets file to add Proxmox password
   sops group_vars/all.sops.yaml
   ```

### Phase 1: Build Golden Image

**Time: ~15-20 minutes (one-time, or when updating base image)** <!-- markdownlint-disable-line MD036 -->

```bash
cd infrastructure/packer/ubuntu-server

# Configure variables
cp variables.auto.pkrvars.hcl.example variables.auto.pkrvars.hcl
# Edit variables.auto.pkrvars.hcl with your Proxmox details

# Build golden image (creates VM-9000)
packer build .
```

**Outputs:**

- VM-9000 template in Proxmox
- All base packages installed
- Security baseline applied
- Ready to clone

See the Packer configuration in [`infrastructure/packer/`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/) for detailed Packer documentation.

### Phase 2: Provision VMs with OpenTofu

**Time: ~5-10 minutes (for all 7 VMs)** <!-- markdownlint-disable-line MD036 -->

```bash
cd infrastructure/terraform

# Initialize OpenTofu (first time only)
tofu init

# Review changes
tofu plan -var="proxmox_password=$(sops -d ../../group_vars/all.sops.yaml | grep proxmox_password | awk '{print $2}')"

# Apply infrastructure
tofu apply -var="proxmox_password=$(sops -d ../../group_vars/all.sops.yaml | grep proxmox_password | awk '{print $2}')"
```

**Alternative: Use Ansible playbook wrapper** <!-- markdownlint-disable-line MD036 -->

```bash
./bin/runtime/ansible-run.sh playbooks/core/01-provision-vms.yml
```

**Outputs:**

- 7 VMs cloned from VM-9000
- Each VM configured with correct CPU/memory/storage
- Static IPs assigned
- VMs started and ready for Ansible

See the OpenTofu configuration in [`infrastructure/terraform/`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/) for details.

### Phase 3: Configure Services with Ansible

**Time: ~30-45 minutes (full stack deployment)** <!-- markdownlint-disable-line MD036 -->

Run the phase-based playbooks in order:

```bash
# Phase 1: Infrastructure provisioning (if not done via OpenTofu)
./bin/runtime/ansible-run.sh playbooks/phases/phase1-infrastructure.yml

# Phase 2: Networking (NAS + Tailscale)
./bin/runtime/ansible-run.sh playbooks/phases/phase2-networking.yml

# Phase 3: Services (media stack)
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml

# Phase 4: Post-deployment (firewall, updates)
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

See [phase-based-deployment.md](phase-based-deployment.md) for detailed Ansible deployment.

## Updating the Golden Image

When you need to update the base image (e.g., Ubuntu version bump, add common packages):

```bash
# 1. Build new golden image
cd infrastructure/packer/ubuntu-server
packer build .

# 2. Test with a single VM (optional but recommended)
cd ../../terraform
tofu apply -target=module.monitoring.proxmox_virtual_environment_vm.vm

# 3. If test successful, rebuild all VMs
# WARNING: This will destroy and recreate all VMs!
tofu destroy
tofu apply
```

**Note:** For production systems, use blue/green deployment or rolling updates instead of destroying all VMs at once.

## Troubleshooting

### Packer Build Fails

See [Packer Troubleshooting](../troubleshooting/packer.md) for comprehensive troubleshooting.

Common issues:

- **SSH timeout**: Check boot order (should be `scsi0;scsi1;net0`)
- **Autoinstall stuck**: Verify `boot_command` includes `yes<enter>` for confirmation
- **Network issues**: Ensure Proxmox host can reach Ubuntu mirror

### OpenTofu Apply Fails

```bash
# Check state
tofu state list

# See detailed errors
tofu plan

# Force refresh if state is out of sync
tofu refresh
```

### VMs Don't Boot After Cloning

1. Check that golden image (VM-9000) is marked as template
2. Verify cloud-init drive is present: `qm config <vmid> | grep ide2`
3. Check boot order: `qm config <vmid> | grep boot`

### Ansible Can't Connect to VMs

```bash
# Test SSH manually
ssh -i ~/.ssh/ansible_homelab ansible@<vm-ip>

# Check Tailscale status (if Phase 2 ran)
tailscale status

# Verify VM is running
qm list | grep <vmid>
```

## Legacy vs Modern Workflow

### Old Workflow (Deprecated)

```text
Ansible creates cloud-init template (VM-9000)
    ↓
Ansible clones VMs and waits 5-10 minutes for cloud-init
    ↓
Ansible installs packages on each VM
    ↓
Ansible configures services
```

**Problems:**

- Slow (cloud-init first boot takes 5-10 minutes per VM)
- Duplicate package installation across VMs
- Mixing infrastructure and configuration in Ansible
- Hard to version or update base image

### New Workflow (Current)

```text
Packer builds golden image once (15 minutes)
    ↓
OpenTofu clones VMs (5 minutes total)
    ↓
Ansible configures services (30 minutes)
```

**Benefits:**

- Fast VM provisioning (30 seconds per VM)
- Packages pre-installed in golden image
- Clear separation of concerns
- Easy to version and update golden image

## Advanced Topics

### Golden Image Versioning

To maintain multiple golden image versions:

```hcl
# infrastructure/terraform/variables.tf
variable "golden_image_id" {
  description = "VMID of Packer-built golden image template"
  type        = number
  default     = 9000  # Change to 9001, 9002, etc. for different versions
}
```

Build multiple templates:

```bash
cd infrastructure/packer/ubuntu-server
packer build -var 'vm_id=9000' -var 'vm_name=ubuntu-server-2024-11' .
packer build -var 'vm_id=9001' -var 'vm_name=ubuntu-server-2024-12' .
```

### Customizing Golden Image

Edit provisioning scripts:

- [`infrastructure/packer/ubuntu-server/scripts/install-common.sh`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/ubuntu-server/scripts/install-common.sh) - Common packages
- [`infrastructure/packer/ubuntu-server/scripts/install-podman.sh`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/ubuntu-server/scripts/install-podman.sh) - Container runtime
- [`infrastructure/packer/ubuntu-server/ansible/security-baseline.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/packer/ubuntu-server/ansible/security-baseline.yml) - Security hardening

### Testing Golden Image Changes

Before rebuilding all VMs:

```bash
# Test with monitoring VM (low-impact)
cd infrastructure/terraform
tofu destroy -target=module.monitoring.proxmox_virtual_environment_vm.vm
tofu apply -target=module.monitoring.proxmox_virtual_environment_vm.vm

# Verify it works
ssh ansible@monitoring.discus-moth.ts.net
```

## See Also

- [Phase-Based Deployment Guide](phase-based-deployment.md)
- [Packer Troubleshooting](../troubleshooting/packer.md)

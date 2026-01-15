# Terraform/OpenTofu Modules

Reusable OpenTofu modules for Proxmox VM infrastructure.

## Overview

The Jellybuntu infrastructure uses modular OpenTofu configurations to provision VMs on Proxmox.
All modules are located in [`infrastructure/terraform/modules/`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/modules/).

## Available Modules

| Module | Purpose | Use Case |
|--------|---------|----------|
| `proxmox-vm` | Base VM module | Standard application servers |
| `proxmox-vm-pinned` | CPU-pinned VM | Game servers, real-time workloads |
| `proxmox-vm-storage` | Multi-disk VM | NAS, file servers, databases |
| `proxmox-vm-gpu` | GPU passthrough | Hardware transcoding (future) |

## Module Selection Guide

```text
Do you need multiple disks?
├── YES → Use proxmox-vm-storage
└── NO
    └── Do you need dedicated CPU cores?
        ├── YES → Use proxmox-vm-pinned
        └── NO → Use proxmox-vm (base module)
```

## Quick Examples

### Standard VM (proxmox-vm)

```hcl
module "jellyfin" {
  source = "./modules/proxmox-vm"

  vm_name   = "jellyfin"
  vm_id     = 400
  cores     = 4
  memory    = 8192
  disk_size = "80G"
  ip_address = "192.168.0.12"
}
```

### CPU-Pinned VM (proxmox-vm-pinned)

```hcl
module "satisfactory" {
  source = "./modules/proxmox-vm-pinned"

  vm_name      = "satisfactory-server"
  vm_id        = 200
  cpu_affinity = "2-3"  # Dedicate cores 2-3
  cores        = 2
  memory       = 6144
  ip_address   = "192.168.0.11"
}
```

### Storage VM (proxmox-vm-storage)

```hcl
module "nas" {
  source = "./modules/proxmox-vm-storage"

  vm_name   = "nas"
  vm_id     = 300
  disk_size = "32G"
  additional_disks = [
    { size = "500G", storage_pool = "local-zfs" },
    { size = "500G", storage_pool = "local-zfs" }
  ]
  startup_order = 1  # Start first
  ip_address    = "192.168.0.15"
}
```

## Full Documentation

For complete module documentation including all variables, outputs, and advanced usage:

- **[Modules Library README][modules-readme]** - Comprehensive guide with examples
- **[proxmox-vm][proxmox-vm]** - Base module documentation
- **[proxmox-vm-pinned][proxmox-vm-pinned]** - CPU pinning documentation
- **[proxmox-vm-storage][proxmox-vm-storage]** - Multi-disk documentation

[modules-readme]: https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/modules/README.md
[proxmox-vm]: https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/modules/proxmox-vm/README.md
[proxmox-vm-pinned]: https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/modules/proxmox-vm-pinned/README.md
[proxmox-vm-storage]: https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/modules/proxmox-vm-storage/README.md

## Related Documentation

- [Architecture Overview](../architecture.md) - VM layout and resource allocation
- [Infrastructure CLAUDE.md][infra-claude] - IaC development guide

[infra-claude]: https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/CLAUDE.md

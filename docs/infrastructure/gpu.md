# GPU

> GTX 1080 PCIe passthrough to k3s for Jellyfin transcoding and Tdarr media processing.

## Proxmox Passthrough

The GTX 1080 is removed from the Proxmox host's GPU pool and passed through exclusively to the **k8s-gpu**
VM (VMID 411, 192.168.30.41). PCIe passthrough is configured post-deployment via Ansible — the
`bpg/proxmox` Terraform provider does not manage passthrough devices directly.

Requirements on the Proxmox host:

- IOMMU enabled in BIOS (AMD-Vi) and kernel (`iommu=pt`)
- GPU bound to `vfio-pci` driver before the VM starts
- GPU and its audio function in the same IOMMU group (passed through together)

Inside the VM, the GPU is visible as a standard NVIDIA device and managed by the standard driver stack.

## NVIDIA in k3s

The `k3s_gpu_node` Ansible role configures the full NVIDIA stack on the k8s-gpu VM:

1. **Kernel modules** — `linux-modules-nvidia-580-generic` installed before the driver to prevent the OEM
   kernel module variant from being pulled in.
2. **Driver** — `nvidia-driver-580` (Ubuntu 24.04 package, driver series 580).
3. **Container Toolkit** — NVIDIA Container Toolkit 1.18.2 provides `nvidia-container-runtime`.
4. **containerd config** — k3s containerd is configured to use `nvidia-container-runtime` as the default
   runtime via `/var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl`. k3s auto-detects the runtime
   from `/usr/bin/nvidia-container-runtime`.
5. **NVENC patch** — the [keylase/nvidia-patch](https://github.com/keylase/nvidia-patch) script removes
   the artificial 2-stream NVENC encode limit on consumer GPUs, allowing both Jellyfin and Tdarr to encode
   concurrently.

Source:
[`roles/k3s_gpu_node/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/k3s_gpu_node),
[`host_vars/k8s-gpu.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/k8s-gpu.yml)

## NVIDIA Device Plugin

The NVIDIA device plugin is deployed via Flux HelmRelease into `kube-system`:

```yaml
chart: nvidia-device-plugin
version: "0.18.2"
nodeSelector:
  jellybuntu.io/role: gpu
tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
```

The plugin advertises `nvidia.com/gpu` resources to the scheduler so pods can request GPU access.

Source:
[`clusters/jellybuntu/infrastructure/controllers/nvidia-device-plugin.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/clusters/jellybuntu/infrastructure/controllers/nvidia-device-plugin.yaml)

## Time-Slicing

The device plugin is configured with GPU time-slicing to advertise the single physical GTX 1080 as
**2 logical GPU resources**:

```yaml
config:
  map:
    default: |-
      version: v1
      sharing:
        timeSlicing:
          resources:
            - name: nvidia.com/gpu
              replicas: 2
```

This allows Jellyfin and Tdarr to each hold a `nvidia.com/gpu: "1"` resource claim simultaneously.
The GPU executes their encode/decode workloads by time-multiplexing — there is no memory isolation
between slices, so both pods share VRAM.

The NVENC patch ensures both streams can encode concurrently without hitting the consumer-GPU encode
session limit.

## Node Scheduling

The k8s-gpu node carries a `NoSchedule` taint and a node label:

```yaml
# host_vars/k8s-gpu.yml
k3s_node_labels:
  - "nvidia.com/gpu.present=true"
k3s_node_taints:
  - "nvidia.com/gpu=true:NoSchedule"
```

A custom node label `jellybuntu.io/role: gpu` is also applied. GPU workloads (Jellyfin, Tdarr) use both
a `nodeSelector` and a matching toleration to land exclusively on this node:

```yaml
defaultPodOptions:
  nodeSelector:
    jellybuntu.io/role: gpu
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
```

Non-GPU workloads are never scheduled on this node because they lack the toleration.

Source:
[`clusters/jellybuntu/gpu/`](https://github.com/SilverDFlame/jellybuntu/tree/main/clusters/jellybuntu/gpu)

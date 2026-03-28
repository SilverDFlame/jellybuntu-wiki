# Troubleshooting

Quick reference for common failure modes. Each entry: symptom → likely cause → fix.

## k3s / Flux

### Pod in CrashLoopBackOff

**Cause:** Application error, missing config, or failed dependency.

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

Check events at the bottom of `describe` output for the immediate failure reason.

### Flux Kustomization Stuck or Not Reconciling

**Cause:** Build error in manifests, git connectivity issue, or dependency not ready.

```bash
flux get kustomizations
flux logs --follow
flux describe kustomization <name>
```

Force a reconcile:

```bash
flux reconcile kustomization flux-system --with-source
```

### HelmRelease Failed

**Cause:** Bad chart values, missing secret, or upstream chart error.

```bash
flux get helmreleases -A
flux describe helmrelease <name> -n <namespace>
kubectl describe helmrelease <name> -n <namespace>
```

### GPU Not Detected in Pod

**Cause:** NVIDIA device plugin not running, container runtime not configured, or node taint
missing toleration.

```bash
# Check device plugin
kubectl get pods -n kube-system | grep nvidia

# Check node GPU taint
kubectl describe node k8s-gpu | grep -A5 Taint

# Check GPU is visible in node capacity
kubectl describe node k8s-gpu | grep -A10 "Allocatable"

# Expected: nvidia.com/gpu: 1
```

Ensure the workload has:

```yaml
tolerations:
  - key: "nvidia.com/gpu"
    operator: "Equal"
    value: "present"
    effect: "NoSchedule"
resources:
  limits:
    nvidia.com/gpu: 1
```

### Flux Not Syncing New Commits

**Cause:** GitRepository source not polling, or token expired.

```bash
flux get sources git -A
flux reconcile source git flux-system
```

---

## NFS / Storage

### NFS Mount Failure on VM Startup

**Cause:** NAS not reachable, NFS service not running, or firewall blocking port 2049.

```bash
# Ping NAS
ping 192.168.30.15

# Check NFS export from client
showmount -e 192.168.30.15

# Check NFS service on NAS
ssh nas.discus-moth.ts.net sudo systemctl status nfs-kernel-server

# Re-mount manually
sudo mount -t nfs 192.168.30.15:/mnt/storage/data /mnt/data
```

### Permission Denied on NFS Share

**Cause:** UID/GID mismatch. NFS squashes to UID/GID 3000 (`nfs_uid`/`nfs_gid` from vault).

```bash
# Check file ownership on NAS
ssh nas.discus-moth.ts.net ls -ln /mnt/storage/data/

# Verify container/process is running as UID 3000
id
# or inside a pod:
kubectl exec -it <pod> -n <namespace> -- id
```

Fix: ensure the service or container runs as UID/GID 3000, or re-run the NAS playbook to
correct export permissions.

### PVC Not Bound (k3s)

**Cause:** NFS provisioner not running, StorageClass misconfigured, or NFS server unreachable
from the cluster.

```bash
kubectl get pvc -A
kubectl describe pvc <name> -n <namespace>

# Check NFS provisioner pods
kubectl get pods -n nfs-system

# Check default StorageClass
kubectl get storageclass
```

Verify NFS server is reachable from the cluster nodes:

```bash
ssh k8s-media.discus-moth.ts.net showmount -e 192.168.30.15
```

---

## DNS / Certificates

### Service Unreachable by Hostname

**Cause:** AdGuard DNS rewrite missing, MetalLB VIP not assigned, or Traefik ingress not
configured.

```bash
# Test DNS resolution
dig jellyfin.discus-moth.ts.net @<adguard-ip>

# Check MetalLB VIP assignment
kubectl get svc -n traefik-system

# Check Traefik ingress routes
kubectl get ingressroute -A
```

Verify AdGuard has a rewrite for the hostname pointing to the Traefik VIP (`192.168.30.200`).

### TLS Certificate Expired or Not Issuing

**Cause:** Cloudflare API token expired, Let's Encrypt rate limit hit, or Traefik ACME
challenge failing.

```bash
# Check Traefik logs
kubectl logs -n traefik-system deployment/traefik | grep -i acme

# Check certificate file on reverse-proxy VM (if VM-hosted Traefik)
ssh reverse-proxy.discus-moth.ts.net sudo ls -la /opt/traefik/acme/

# Restart Traefik to force certificate refresh
kubectl rollout restart deployment/traefik -n traefik-system
```

Verify the Cloudflare API token in the vault (`vault_cloudflare_dns_api_token`) is still valid
and has `Zone:DNS:Edit` permissions for the domain.

---

## Ansible / Deployment

### Vault Decryption Fails

**Cause:** Age key not present or wrong key file location.

```bash
ls ~/.config/sops/age/keys.txt
sops --decrypt group_vars/all.sops.yaml | head -5
```

### Playbook Fails on SSH Connection

**Cause:** VM not yet reachable (still booting), or SSH key not deployed.

```bash
# Test direct SSH
ssh ansible@<vm-ip>

# Check VM is up
ping <vm-ip>
```

For Phase 1/2 use IP-direct connection; for Phase 3+ Tailscale must be running.

### Tailscale Not Installed / VM Not Reachable by Hostname

**Cause:** Phase 2 not completed, or Tailscale auth key expired.

```bash
ssh <vm-ip> sudo tailscale status
```

Re-run the Tailscale playbook with a fresh auth key:

```bash
sops group_vars/all.sops.yaml   # update vault_tailscale_api_key
./bin/runtime/ansible-run.sh playbooks/networking/tailscale.yml
```

---

## Monitoring

### Prometheus Not Scraping a Target

**Cause:** node_exporter not running on target host, firewall blocking port 9100, or
Prometheus config not updated.

```bash
# On target VM
ssh <vm>.discus-moth.ts.net sudo systemctl status node_exporter

# Check Prometheus targets UI
# http://monitoring.discus-moth.ts.net:9090/targets
```

Re-run exporters playbook to reinstall:

```bash
./bin/runtime/ansible-run.sh playbooks/monitoring/exporters.yml
```

### Grafana Dashboard Missing Data

**Cause:** Prometheus data source not configured or scrape gap.

Check Prometheus is running and targets are up, then verify the Grafana data source URL
points to `http://monitoring.discus-moth.ts.net:9090`.

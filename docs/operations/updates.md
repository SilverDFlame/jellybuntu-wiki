# Updates

> Procedures for keeping the OS, VM-hosted services, and k3s cluster services up to date.

## OS Patches (All VMs)

Unattended upgrades are configured on all VMs by Phase 4 (`system-hardening` role). Security
patches apply automatically. For manual patching across all hosts:

```bash
# Run OS updates on all Ansible-managed VMs
./bin/runtime/ansible-run.sh playbooks/system/system-timezone.yml

# Or target a specific host group
ansible all -m apt -a "upgrade=dist update_cache=yes" --become -i inventory/
```

Check unattended-upgrades status on a VM:

```bash
ssh <vm>.discus-moth.ts.net sudo systemctl status unattended-upgrades
sudo journalctl -u unattended-upgrades -n 50
```

## VM-Hosted Service Updates (Podman containers)

Services running as Podman containers are updated by re-running their playbooks. The playbook
pulls the latest image (or the pinned version in vars) and restarts the container.

```bash
# Update a single service
./bin/runtime/ansible-run.sh playbooks/services/jellyfin.yml
./bin/runtime/ansible-run.sh playbooks/services/traefik-proxy.yml
./bin/runtime/ansible-run.sh playbooks/services/home-assistant.yml

# Update all services (Phase 3 re-run)
./bin/runtime/ansible-run.sh playbooks/phases/phase3-services.yml
```

Container image versions are set in `playbooks/vars.yml` or per-service vars files. To pin a
specific version, update the image tag there before running the playbook.

### Release Checker

The `release-checker` task in the `common` role checks for new upstream releases and sends
notifications. Each VM has a staggered check schedule to avoid simultaneous requests.

```bash
# Manually trigger release check on a specific VM
ssh <vm>.discus-moth.ts.net sudo systemctl start release-checker.service
sudo journalctl -u release-checker.service -n 30
```

## k3s Cluster Service Updates (Flux/Helm)

Services deployed via Flux are updated by bumping the chart version or image tag in the
`jellybuntu-helm` repository and pushing to `main`.

### Update a Helm Chart Version

1. Edit the `HelmRelease` in `jellybuntu-helm`:

```yaml
# clusters/jellybuntu/<layer>/<service>-helmrelease.yaml
spec:
  chart:
    spec:
      chart: <chart-name>
      version: "<new-version>"   # bump this
```

1. Validate locally:

```bash
kubectl kustomize clusters/jellybuntu/
```

1. Commit and push to `main` — Flux reconciles within 10 minutes

### Force Immediate Reconciliation

```bash
# Reconcile all kustomizations
flux reconcile kustomization flux-system --with-source

# Reconcile a specific HelmRelease
flux reconcile helmrelease <name> -n <namespace>
```

### Check Helm Release Status After Update

```bash
flux get helmreleases -A
kubectl describe helmrelease <name> -n <namespace>
```

## k3s Node Updates

k3s itself is installed by the `k3s` Ansible role. To update the k3s binary on nodes:

1. Update the `k3s_version` variable in the k3s role vars
2. Re-run the cluster playbook:

```bash
./bin/runtime/ansible-run.sh playbooks/infrastructure/k3s-cluster.yml
```

Drain each worker before the update to avoid workload disruption:

```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
# After k3s updates and node is Ready:
kubectl uncordon <node-name>
```

## Monitoring Stack Updates

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase5-monitoring.yml
```

## Traefik Certificate Renewal

Traefik uses Let's Encrypt with Cloudflare DNS-01 challenges. Certificates auto-renew before
expiry. No manual action needed unless renewal fails — see [Troubleshooting](../troubleshooting.md).

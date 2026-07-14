# Monitoring

> Prometheus + Grafana stack for infrastructure metrics, alerting, and dashboards

| Field | Value |
|-------|-------|
| **Runs on** | `monitoring` VM (rootless Podman, not k3s) |
| **Access** | `http://monitoring.discus-moth.ts.net:3000` (Grafana) |
| **Port** | 9090 (Prometheus), 3000 (Grafana), 9093 (Alertmanager) |
| **Repo** | `jellybuntu` -> `playbooks/monitoring/stack.yml` |

## Components

| Container | Port | Purpose |
|-----------|------|---------|
| Prometheus | 9090 | Metrics collection, 30-day retention |
| Grafana | 3000 | Dashboards and visualisation |
| Alertmanager | 9093 | Alert routing (Discord webhooks) |
| SNMP Exporter | 9116 | MikroTik router and switch metrics |
| Blackbox Exporter | 9115 | HTTP/TCP endpoint probing |

## In-Cluster Stack (kube-prometheus-stack)

The `monitoring` VM is the **external** plane. A second, **in-cluster** plane runs inside
k3s for deep Kubernetes + workload metrics:

| Component | Where | Purpose |
|-----------|-------|---------|
| kube-prometheus-stack | k3s `monitoring` ns | Prometheus + Grafana + Alertmanager for cluster/pod metrics |
| postgres-exporter | k3s `monitoring` ns | Scrapes the central PostgreSQL VM (`192.168.30.16`) — `pg_stat_activity`, `pg_settings`, connection-slot usage |

- Repo: `jellybuntu-helm` -> `clusters/jellybuntu/monitoring/`.
- Prometheus is reachable via a Cilium L2 LoadBalancer VIP (`.202`).
- Alertmanager routes to Discord via an `AlertmanagerConfig` CR (must carry the Watchdog +
  InfoInhibitor null-routes).
- **postgres-exporter** connects as the read-only `postgres_exporter` role (`pg_monitor`
  grant, DSN in a SOPS secret). It only touches the `postgres` DB — its cluster-wide
  collectors work via the grant, so no per-DB `CONNECT` is needed. Metrics on `:9187`,
  scraped by a `ServiceMonitor`. This is what sized the per-role connection limits (see
  jellybuntu#275).

```bash
# In-cluster components
kubectl get pods -n monitoring
kubectl logs -f deployment/postgres-exporter -n monitoring
```

## Key Config

- All containers run as rootless Podman with systemd user services on the `monitoring` VM
- Node exporters run on each VM/host and are managed by
  [`playbooks/monitoring/exporters.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/monitoring/exporters.yml)
- Prometheus config is a Jinja2 template at
  `roles/monitoring_stack/templates/prometheus.yml.j2`; rendered on deploy
- Alertmanager sends alerts to Discord via a webhook URL stored in vault
- SNMP Exporter scrapes MikroTik router (`192.168.0.1`) and switch (`192.168.0.2`)
- Uptime Kuma runs externally (Vultr) for independent uptime checks

## Common Operations

```bash
# Check service status (run on monitoring VM)
systemctl --user status prometheus.service
systemctl --user status grafana.service
systemctl --user status alertmanager.service

# View logs
journalctl --user -u prometheus -f
journalctl --user -u grafana -f

# Restart a container
systemctl --user restart prometheus.service
systemctl --user restart grafana.service
```

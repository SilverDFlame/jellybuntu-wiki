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

## Key Config

- All containers run as rootless Podman with systemd user services on the `monitoring` VM
- Node exporters run on each VM/host and are managed by
  [`playbooks/monitoring/exporters.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/monitoring/exporters.yml)
- Prometheus config is a Jinja2 template at
  `roles/monitoring_stack/templates/prometheus.yml.j2`; rendered on deploy
- Alertmanager sends alerts to Discord via a webhook URL stored in vault
- SNMP Exporter scrapes MikroTik router (`192.168.0.1`) and switch (`192.168.0.2`)
- Uptime Kuma runs externally (Oracle Cloud) for independent uptime checks

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

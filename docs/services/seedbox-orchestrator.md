# Seedbox Orchestrator

> NAS-side pipeline that pulls completed downloads off the Ultra.cc seedbox (NZBget +
> Deluge) to the NAS, then hands them to the *arr apps

| Field | Value |
|-------|-------|
| **Runs on** | `nas` VM (systemd services + timers), **not** k3s |
| **Access** | No web UI — headless poller |
| **State DB** | PostgreSQL on the `db` VM (`192.168.30.16`), phase-machine per download |
| **Repo** | `jellybuntu` -> `roles/seedbox_orchestrator/` |

Replaces the former in-cluster SABnzbd usenet client. Usenet (**NZBget**) and a second
**Deluge** now run remotely on the Ultra.cc seedbox jail; the orchestrator moves finished
files home over rclone.

## How It Works

- Two systemd services: `seedbox-orch-poller` and `seedbox-orch-retention`, each with a timer.
- **Torrent side** — polls seedbox Deluge RPC state; rclone-pulls completed sets to the NAS.
- **NZB side** — discovers successful NZBget history entries; rclone-pulls completed sets to
  `/mnt/storage/data/downloads/nzbget/<…>/`. After `seedbox_orch_retention_days` days it
  deletes the seedbox-side history entry (`editqueue HistoryFinalDelete`), gated on the NAS
  file still being present.
- Every download is a row in the Postgres phase-machine (`nzb_state` / `torrent_state`),
  keyed by `nz_id` (usenet) or infohash (torrent).

## CLI

Run on the `nas` VM. Torrent verbs: `poll`, `retention`, `repull`, `migrate`.
NZB verbs: `poll-nzb`, `retention-nzb`.

```bash
# Revive a terminally-failed torrent pull once the blocker is fixed
seedbox_orch repull --infohash <40hex>[,<40hex>...]

# Same for the NZB side
seedbox_orch repull-nzb --nz-id <id>

# Health-check the poller (no status verb / no psql needed)
journalctl -u seedbox-orch-poller -n 200 | jq ...   # --since is broken on the NAS; use -n N
```

## Gotchas

- A pull that fails `seedbox_orch_poll_max_pull_attempts` times (default 10, ~7–8 h with
  backoff) retires to the terminal **`failed`** phase — inert, never retried. Distinct from
  **`retired`** (successful seed, then aged out). `repull` resets `pulled`/`failed` rows back
  to `seen`; it only re-runs the seedbox→NAS pull, **not** the tracker grab.
- Retention reaps the seedbox copy only for `injected` rows (gated on NAS being clean) —
  never for `retired`/`failed`.
- High-rate `soft_stuck` WARN logs are benign (NZB retention is disabled by design; rows
  wedge in `pulled`).
- Paths containing `&` or non-UTF-8 are rejected by the path validator on both sides.

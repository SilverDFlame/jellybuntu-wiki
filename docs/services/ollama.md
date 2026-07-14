# Ollama

> GPU-hosted embedding/inference server — provides `nomic-embed-text` embeddings and small
> LLM inference to cluster consumers

| Field | Value |
|-------|-------|
| **Runs on** | k3s `gpu` namespace on `k8s-gpu` (NVIDIA GPU) |
| **Access** | `https://ollama.elysium.industries` (also in-cluster `:11434`) |
| **Port** | 11434 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/gpu/ollama.yaml` |

Consumers: cavemem embeddings (`nomic-embed-text`, 768-dim) and the AIOps augur alert-
enrichment pipeline (`qwen3:4b`). Node-agnostic — replaced the dead local embedding backend.

## Key Config

- Image pinned to the Nexus path (`192.168.30.15:5001/ollama/ollama`), digest-pinned via
  Flux ImagePolicy.
- `OLLAMA_KEEP_ALIVE: "5m"` — keeps the embed model warm but releases VRAM when idle so
  Jellyfin/Tdarr transcodes aren't starved on the shared 8 GB GPU.
- `postStart` hook pulls `nomic-embed-text` on boot.
- Models persisted on the `ollama-models` PVC.
- Tolerates the `nvidia.com/gpu` taint; requests `nvidia.com/gpu: "1"`. Memory 1 Gi request
  / 4 Gi limit.

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/ollama -n gpu

# List loaded models
kubectl exec -it deployment/ollama -n gpu -- ollama list

# Pull a model
kubectl exec -it deployment/ollama -n gpu -- ollama pull nomic-embed-text
```

## Gotchas

- The embeddings endpoint **must** be `https` — plain `http` returns 308 redirects that
  break clients.

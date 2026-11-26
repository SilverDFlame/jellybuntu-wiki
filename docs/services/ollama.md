# Ollama

> GPU-hosted embedding/inference server: provides `qwen3-embedding:0.6b` embeddings and small
> LLM inference to cluster consumers

| Field | Value |
|-------|-------|
| **Runs on** | k3s `gpu` namespace on `k8s-gpu` (NVIDIA GPU) |
| **Access** | `https://ollama.elysium.industries` (also in-cluster `:11434`) |
| **Port** | 11434 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/gpu/ollama.yaml` |

Consumers: cavemem embeddings (`qwen3-embedding:0.6b`, 1024-dim) and the AIOps augur alert-
enrichment pipeline (`qwen3:4b`). Node-agnostic; it replaced the dead local embedding backend.

## Key Config

- Image pinned to the Nexus path (`192.168.30.15:5001/ollama/ollama`), digest-pinned via
  Flux ImagePolicy.
- `OLLAMA_KEEP_ALIVE: "5m"` — keeps the embed model warm but releases VRAM when idle so
  Jellyfin/Tdarr transcodes aren't starved on the shared 8 GB GPU.
- `OLLAMA_CONTEXT_LENGTH: "32768"`: the legacy `/api/embeddings` endpoint has no per-request
  context override, so the server default would reject long inputs with HTTP 500 ("input length
  exceeds the context length") and wedge cavemem's backfill. 32768 is the model's full context.
- `postStart` hook pulls `qwen3-embedding:0.6b` on boot.
- Models persisted on the `ollama-models` PVC.
- Tolerates the `nvidia.com/gpu` taint; requests `nvidia.com/gpu: "1"`. Memory 2 Gi request
  / 4 Gi limit.

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/ollama -n gpu

# List loaded models
kubectl exec -it deployment/ollama -n gpu -- ollama list

# Pull a model
kubectl exec -it deployment/ollama -n gpu -- ollama pull qwen3-embedding:0.6b
```

## Gotchas

- The embeddings endpoint **must** be `https` — plain `http` returns 308 redirects that
  break clients.
- Switching the embedding model changes the vector size, so cavemem must re-embed: its stored
  vectors from the old model are cleared and rebuilt on the next worker pass.

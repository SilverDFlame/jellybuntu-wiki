#!/usr/bin/env bash
# PreToolUse hook: Block Read tool from accessing plaintext secret files.
# This is a docs-only repo, so the surface is small — but Claude Code's own
# .credentials.json and any age private keys must never enter the transcript.
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

basename=$(basename "$file_path")

case "$basename" in
  .credentials.json|credentials.json)
    echo "BLOCKED: Credentials file must not be read into the session transcript." >&2
    exit 2
    ;;
  keys.txt|age-key.txt|*.age)
    if echo "$file_path" | grep -qv '\.example'; then
      echo "BLOCKED: Age private key file must not be read into the session." >&2
      exit 2
    fi
    ;;
esac

exit 0

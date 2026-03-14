#!/usr/bin/env bash
# Run this BEFORE recording: ./demo-prep.sh && asciinema rec ...
set -e

echo "Fetching API key..."
REAL_KEY=$(sudo -u openclaw-svc podman secret inspect openclaw01.ANTHROPIC_API_KEY --showsecret \
  | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['SecretData'])")
printf '%s' "$REAL_KEY" > /tmp/.demo-key

echo "Destroying old cage (if any)..."
agentcage cage destroy demo --yes >/dev/null 2>&1 || true
rm -f /tmp/cage.yaml

echo "Ready. Run:"
echo "  asciinema rec demo.cast -c ./demo.sh --cols 110 --rows 32 --overwrite"

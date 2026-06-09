#!/usr/bin/env bash
# omega-cron trigger script
# Sends a cron: prefixed message to the OmegaClaw Telegram bot via the Bot API.
# No new bot needed — uses the same TG_BOT_TOKEN already configured for OmegaClaw.
#
# Usage:
#   ./trigger.sh <skill> <task> [payload]
#   Examples:
#     ./trigger.sh ping health-check
#     ./trigger.sh instagram weekly-post
#     ./trigger.sh summary daily-morning "focus on new followers"
#
# Environment variables (set in OmegaClaw's .env or export directly):
#   TG_BOT_TOKEN   — bot token from @BotFather (already set for OmegaClaw)
#   TG_CHAT_ID     — your Telegram chat ID (already bound after auth)
#
# The bot will receive this as a plain message prefixed with "cron:".
# OmegaClaw's cron-handler.metta parses and dispatches it.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
: "${TG_BOT_TOKEN:?TG_BOT_TOKEN env var required}"
: "${TG_CHAT_ID:?TG_CHAT_ID env var required}"

BOT_API="https://api.telegram.org/bot${TG_BOT_TOKEN}"

# ── Args ──────────────────────────────────────────────────────────────────────
SKILL="${1:-}"
TASK="${2:-}"
PAYLOAD="${3:-}"

if [[ -z "$SKILL" || -z "$TASK" ]]; then
  echo "Usage: $0 <skill> <task> [payload]" >&2
  echo "  skill  — category: ping, test, instagram, summary, backup, memory" >&2
  echo "  task   — specific action: weekly-post, daily-morning, etc." >&2
  echo "  payload — optional free-text argument (passed to the handler)" >&2
  exit 1
fi

# Build the cron message body
# Format: cron:<skill>:<task>[:<payload>]
CRON_MSG="cron:${SKILL}:${TASK}"
if [[ -n "$PAYLOAD" ]]; then
  CRON_MSG="${CRON_MSG}:${PAYLOAD}"
fi

# ── Send ──────────────────────────────────────────────────────────────────────
echo "Sending: ${CRON_MSG}"

RESPONSE=$(curl -s -X POST "${BOT_API}/sendMessage" \
  -d "chat_id=${TG_CHAT_ID}" \
  -d "text=${CRON_MSG}" \
  --max-time 15)

# Check Telegram API response
OK=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ok', False))" 2>/dev/null || echo "False")

if [[ "$OK" == "True" ]]; then
  echo "Trigger sent successfully."
else
  ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description', 'unknown error'))" 2>/dev/null || echo "parse error")
  echo "Telegram API error: ${ERROR}" >&2
  exit 1
fi
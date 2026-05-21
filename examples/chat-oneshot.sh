#!/usr/bin/env bash
# example: chat-oneshot.sh — kirim 1 prompt, dapat response, exit
#
# Usage: ./chat-oneshot.sh "prompt-nya"
#
# Skip Claude Code TUI, langsung pakai curl ke endpoint.
# Bagus buat scripting / cron / CI.

set -euo pipefail

CONFIG="${HERMES_CONFIG:-$HOME/.config/hermes-claude/config}"
[ -f "$CONFIG" ] || { echo "config not found: $CONFIG" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"

PROMPT="${1:?usage: $0 \"prompt-nya\"}"

curl -s "${HERMES_ENDPOINT}/v1/messages" \
  -H "x-api-key: $HERMES_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d "$(jq -n \
        --arg model "$HERMES_MODEL" \
        --arg prompt "$PROMPT" \
        '{model: $model, max_tokens: 2048,
          messages: [{role:"user", content: $prompt}]}')" \
  | jq -r '.content[0].text // .error.message // .'

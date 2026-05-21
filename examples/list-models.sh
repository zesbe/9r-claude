#!/usr/bin/env bash
# example: list-models.sh — list semua model dari endpoint dengan detail
#
# Usage: ./list-models.sh [--json]

set -euo pipefail

CONFIG="${HERMES_CONFIG:-$HOME/.config/hermes-claude/config}"
[ -f "$CONFIG" ] || { echo "config not found: $CONFIG" >&2; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"

JSON=0
[ "${1:-}" = "--json" ] && JSON=1

if [ "$JSON" = "1" ]; then
  curl -s "${HERMES_ENDPOINT}/v1/models" \
    -H "Authorization: Bearer $HERMES_API_KEY" | jq
  exit 0
fi

models=$(curl -s "${HERMES_ENDPOINT}/v1/models" \
  -H "Authorization: Bearer $HERMES_API_KEY" \
  | jq -r '.data[].id' | sort)

count=$(echo "$models" | wc -l)
echo "$count model di $HERMES_ENDPOINT:"
echo ""

# Group by family
echo "$models" | awk -F/ '{
  fam=$2;
  sub(/-thinking.*/, "", fam);
  sub(/-agentic.*/, "", fam);
  sub(/-[0-9.]+$/, "", fam);
  print fam "|" $0
}' | sort | awk -F'|' '
  $1 != prev { print ""; print "  " toupper($1) ":"; prev=$1 }
  { print "    " $2 }'

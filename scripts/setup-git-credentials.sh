#!/usr/bin/env bash
# setup-git-credentials.sh — simpan token GitHub di git credential helper
# biar gak perlu paste token tiap push.
#
# Usage:
#   ./setup-git-credentials.sh
#   (akan prompt token; input gak kelihatan)

set -euo pipefail

USER="${GITHUB_USER:-zesbe}"
EMAIL="${GITHUB_EMAIL:-yudiharyanto41@gmail.com}"

# Configure git identity if not set
git config --global user.name "$USER" 2>/dev/null || true
git config --global user.email "$EMAIL" 2>/dev/null || true

# Use libsecret if available (most secure on Linux), fallback to store
if command -v git-credential-libsecret >/dev/null 2>&1; then
  git config --global credential.helper libsecret
  echo "==> using libsecret credential helper (encrypted)"
elif command -v git-credential-cache >/dev/null 2>&1; then
  git config --global credential.helper 'cache --timeout=86400'
  echo "==> using cache credential helper (24h timeout)"
else
  git config --global credential.helper store
  echo "==> using store credential helper (plain ~/.git-credentials, chmod 600)"
fi

# Read token without echo
printf "Paste GitHub token (ghp_... atau github_pat_...): "
stty -echo
read -r TOKEN
stty echo
printf "\n"

[ -n "$TOKEN" ] || { echo "error: token kosong" >&2; exit 1; }

# Verify token works
echo "==> verifying token..."
HTTP=$(curl -s -o /tmp/gh-verify.json -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  https://api.github.com/user)

if [ "$HTTP" != "200" ]; then
  echo "error: token invalid (HTTP $HTTP)" >&2
  cat /tmp/gh-verify.json >&2
  rm -f /tmp/gh-verify.json
  exit 1
fi

LOGIN=$(jq -r .login /tmp/gh-verify.json)
rm -f /tmp/gh-verify.json
echo "==> token valid (user: $LOGIN)"

# Store in credential helper
printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n' \
  "$USER" "$TOKEN" | git credential approve

# Tighten perms on credentials file if used
if [ -f "$HOME/.git-credentials" ]; then
  chmod 600 "$HOME/.git-credentials"
fi

echo "==> done. Test: git push (di repo yang udah remote-nya github.com)"

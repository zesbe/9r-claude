#!/usr/bin/env bash
# install.sh — one-liner installer untuk 9r-claude
#
# Quick install:
#   curl -fsSL https://raw.githubusercontent.com/zesbe/hermes-claude/main/scripts/install.sh | bash
#
# Custom prefix:
#   curl -fsSL .../install.sh | PREFIX=$HOME/.local bash

set -euo pipefail

REPO="${REPO:-zesbe/hermes-claude}"
BRANCH="${BRANCH:-main}"
PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="$PREFIX/bin"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"

PRIMARY="9r-claude"
LEGACY="hermes-claude"
EXTRA=(kiro2claude kiro2claude-summary kiro-compact)

c_green() { printf '\033[32m%s\033[0m' "$*"; }
c_red()   { printf '\033[31m%s\033[0m' "$*"; }
c_dim()   { printf '\033[2m%s\033[0m' "$*"; }
info()    { echo "$(c_green '==>') $*"; }
warn()    { echo "$(c_red 'warn:') $*" >&2; }
die()     { echo "$(c_red 'error:') $*" >&2; exit 1; }

# Pre-flight checks
command -v curl >/dev/null || die "curl required"
command -v claude >/dev/null || warn "claude (Claude Code CLI) not found in PATH — install: npm i -g @anthropic-ai/claude-code"

mkdir -p "$BINDIR"

info "downloading from $REPO@$BRANCH"

# Primary binary
url="$RAW/bin/$PRIMARY"
dst="$BINDIR/$PRIMARY"
if curl -fsSL --max-time 30 "$url" -o "$dst.tmp"; then
  chmod +x "$dst.tmp"
  mv "$dst.tmp" "$dst"
  echo "  $(c_green '✓') $dst"
else
  rm -f "$dst.tmp"
  die "gagal download $url"
fi

# Legacy alias as symlink
ln -sf "$PRIMARY" "$BINDIR/$LEGACY"
echo "  $(c_green '✓') $BINDIR/$LEGACY $(c_dim '-> '"$PRIMARY")"

# Bridge tools
for b in "${EXTRA[@]}"; do
  url="$RAW/bin/$b"
  dst="$BINDIR/$b"
  if curl -fsSL --max-time 30 "$url" -o "$dst.tmp"; then
    chmod +x "$dst.tmp"
    mv "$dst.tmp" "$dst"
    echo "  $(c_green '✓') $dst"
  else
    rm -f "$dst.tmp"
    warn "gagal download $url (skip)"
  fi
done

# PATH check
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BINDIR"; then
  warn "$BINDIR belum di PATH"
  echo "    tambahin ke shell rc: $(c_dim "echo 'export PATH=\"$BINDIR:\$PATH\"' >> ~/.bashrc")"
fi

info "$(c_green 'install selesai')"
echo ""
echo "  Next:"
echo "    $(c_dim 1.) 9r-claude config"
echo "    $(c_dim 2.) 9r-claude test"
echo "    $(c_dim 3.) 9r-claude         $(c_dim '# yolo default ON sejak v0.4')"
echo ""
echo "  Docs: https://github.com/$REPO"

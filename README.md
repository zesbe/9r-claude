# hermes-claude

Wrapper Claude Code CLI buat endpoint custom (9router / Hermes / proxy Anthropic-compatible lainnya). Set endpoint + API key + model sekali, terus pakai `claude` seperti biasa — semua arg di-pass through.

Bonus: tools buat handle long sessions (auto-compact Kiro, import sesi Kiro ke Claude).

## Fitur

- Wizard interaktif buat first-time setup
- Per-tier model mapping (Opus / Sonnet / Haiku) ala 9router demo, kompatibel dengan `/model` picker bawaan Claude Code
- Auto-detect & pick model dari endpoint via `/v1/models`
- Subcommand lengkap: `show`, `models`, `pick-model`, `set-endpoint`, `set-key`, `set-model`, `test`, `reset`, `edit`
- Mask API key di output (gak pernah kelihatan utuh)
- Bridge tools: import sesi Kiro CLI ke Claude, auto-compact long sessions

## Install

**One-liner (paling cepat):**

```bash
curl -fsSL https://raw.githubusercontent.com/zesbe/hermes-claude/main/scripts/install.sh | bash
```

**Atau clone + make:**

```bash
git clone https://github.com/zesbe/hermes-claude.git
cd hermes-claude
make install              # install ke ~/.local/bin
```

Manual install (kalau gak mau pakai make):

```bash
install -Dm755 bin/hermes-claude        ~/.local/bin/hermes-claude
install -Dm755 bin/kiro2claude          ~/.local/bin/kiro2claude
install -Dm755 bin/kiro2claude-summary  ~/.local/bin/kiro2claude-summary
install -Dm755 bin/kiro-compact         ~/.local/bin/kiro-compact
```

Pastikan `~/.local/bin` ada di PATH.

## Quick Start

```bash
# 1. Setup (first time)
hermes-claude config
# masukin endpoint (cth: https://9r.zesbe.my.id), API key, pick model dari list

# 2. Verify
hermes-claude show
hermes-claude test

# 3. Jalankan
hermes-claude                              # interaktif
hermes-claude -p "halo, apa kabar"         # one-shot
hermes-claude --resume                     # resume session picker
```

## Config File

Disimpan di `~/.config/hermes-claude/config` (chmod 600), format key-value bash:

```bash
HERMES_ENDPOINT="https://9r.zesbe.my.id"
HERMES_API_KEY="sk-..."
HERMES_MODEL="kr/claude-opus-4.7-thinking"
# Optional per-tier overrides (kalau gak ke-set, pake DEFAULT di wrapper)
HERMES_OPUS_MODEL="kr/claude-opus-4.7-thinking"
HERMES_SONNET_MODEL="kr/claude-sonnet-4.6-thinking"
HERMES_HAIKU_MODEL="kr/claude-haiku-4.5"
```

## Subcommands

```
hermes-claude                       launch claude pakai config aktif
hermes-claude <args>                launch claude + pass-through args
hermes-claude -- <args>             eksplisit pass-through (kalo arg bentrok)

CONFIG (one-time setup):
  hermes-claude config              wizard interaktif (endpoint+key+model)
  hermes-claude reset               hapus config (confirm dulu)

VIEW:
  hermes-claude show                lihat config aktif (key dimask)
  hermes-claude models              list semua model di endpoint
  hermes-claude version             versi wrapper

EDIT:
  hermes-claude set-endpoint <url>  ganti base URL
  hermes-claude set-key <key>       ganti API key
  hermes-claude set-model [model]   ganti model (kosong = picker)
  hermes-claude pick-model          picker fzf/numbered
  hermes-claude edit                buka config di $EDITOR

DEBUG:
  hermes-claude test                ping endpoint, verify auth
  HERMES_VERBOSE=1 hermes-claude    print endpoint+model sebelum exec
```

## Cara Kerja

Wrapper inject env vars sebelum `exec claude`:

```
ANTHROPIC_BASE_URL              = endpoint (tanpa /v1, Claude append sendiri)
ANTHROPIC_AUTH_TOKEN            = API key
ANTHROPIC_DEFAULT_OPUS_MODEL    = model untuk tier Opus
ANTHROPIC_DEFAULT_SONNET_MODEL  = model untuk tier Sonnet
ANTHROPIC_DEFAULT_HAIKU_MODEL   = model untuk tier Haiku
ANTHROPIC_MODEL                 = backward-compat single-model
ANTHROPIC_SMALL_FAST_MODEL      = haiku (untuk compaction & summary)
```

Kenapa per-tier? Karena Claude Code `/model` picker switch antar tier (Opus/Sonnet/Haiku), bukan model spesifik. Kalau cuma `ANTHROPIC_MODEL` yang ke-set, picker jadi error karena dia coba pakai model ID lokal Claude Code yang gak dikenal endpoint.

`ANTHROPIC_API_KEY` di-unset eksplisit (kalau ke-set bareng `ANTHROPIC_AUTH_TOKEN` Claude Code complain auth conflict & fallback ke akun resmi).

## Bridge Tools

### kiro-compact — fork sesi Kiro panjang ke sesi baru

```bash
kiro-compact                      # compact sesi Kiro terakhir, launch sesi baru
kiro-compact --last 50            # bawa 50 turn terakhir (default 30)
kiro-compact <session-id>         # compact sesi spesifik
kiro-compact --print              # preview ringkasan tanpa launch
kiro-compact --save out.md        # save ringkasan ke file
```

Use case: Kiro sering kena rate limit kalau sesi udah panjang. Tool ini bikin sesi baru dengan ringkasan turn-turn terakhir sebagai opening message.

### kiro2claude-summary — import sesi Kiro ke Claude Code

```bash
kiro2claude-summary ~/.kiro/sessions/cli/<id>.jsonl --cwd ~ --last 30
# Output kasih session ID, terus:
hermes-claude --resume <session-id>
```

Use case: lo punya sesi panjang di Kiro tapi mau lanjutin di Claude Code. Tool ini extract first prompt + last N turn jadi 1 user message yang clean (tanpa thinking signatures, tanpa tool_use ID mismatch), kompatibel buat di-`/resume` di Claude Code.

### kiro2claude — full replay (eksperimen)

Coba replay full history Kiro ke Claude. Ngelawan banyak constraint (token limit, signature validation, tool ID tracking). Pake `kiro2claude-summary` aja, lebih reliable.

## Pitfalls (Yang Gua Temuin Saat Build)

- **`/model` di Claude Code override `ANTHROPIC_MODEL`** dengan model ID lokal (e.g. `claude-opus-4-7[1m]`) yang gak dikenal endpoint custom. Solusi: pakai per-tier env vars. Kalau mau ganti model, keluar Claude → `hermes-claude set-model` atau `hermes-claude pick-model`.
- **Trailing `/v1` di endpoint** harus di-strip — Claude Code append `/v1` sendiri. Wrapper otomatis handle ini.
- **Thinking signatures** dari sesi Anthropic asli gak valid di endpoint relay (9router). `kiro2claude-summary` strip thinking blocks.
- **Orphan tool_use** (Kiro session keinterrupt) bikin API balikin 400. Padding stub tool_result dilakukan otomatis.
- **Token budget** > context window → 400 "Improperly formed request". `kiro2claude-summary` truncate ke ~2 MB / ~500k token by default.
- **Rate limit** balikin 400 dengan pesan "(reset after Xs)". Tunggu reset window-nya, bukan masalah konfigurasi.

## Lihat Juga

- `docs/curl-examples.md` — curl commands buat test endpoint langsung
- `docs/troubleshooting.md` — fix common issues
- `examples/` — contoh script otomasi

## License

MIT

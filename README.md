# 9r-claude

Wrapper Claude Code CLI buat endpoint custom (9router / Hermes / proxy Anthropic-compatible lainnya). Set endpoint + API key + model sekali, terus pakai `claude` seperti biasa — semua arg di-pass through.

**v0.4 update — yolo mode default ON.** Cukup `9r-claude` aja, otomatis pakai `--dangerously-skip-permissions` ala `gemini -y`. Mau matikan: `9r-claude --no-yolo` atau `9r-claude yolo off`.

> **Catatan:** Repo ini dulu namanya `hermes-claude`. Binary `hermes-claude` masih ada sebagai symlink ke `9r-claude` jadi gak break script lama.

Bonus: tools buat handle long sessions (auto-compact Kiro, import sesi Kiro ke Claude).

## Fitur

- **Yolo mode default** — tinggal `9r-claude`, langsung auto-accept semua permission Claude Code
- Wizard interaktif buat first-time setup
- Per-tier model mapping (Opus / Sonnet / Haiku) ala 9router demo, kompatibel dengan `/model` picker bawaan Claude Code
- Auto-detect & pick model dari endpoint via `/v1/models`
- Subcommand lengkap: `show`, `models`, `pick-model`, `set-endpoint`, `set-key`, `set-model`, `yolo`, `test`, `reset`, `edit`
- Mask API key di output (gak pernah kelihatan utuh)
- Auto-migrate config lama dari `~/.config/hermes-claude` ke `~/.config/9r-claude`
- Bridge tools: import sesi Kiro CLI ke Claude, auto-compact long sessions

## Install

**One-liner (paling cepat):**

```bash
curl -fsSL https://raw.githubusercontent.com/zesbe/9r-claude/main/scripts/install.sh | bash
```

**Atau clone + make:**

```bash
git clone https://github.com/zesbe/9r-claude.git
cd 9r-claude
make install              # install ke ~/.local/bin
```

Manual install:

```bash
install -Dm755 bin/9r-claude            ~/.local/bin/9r-claude
ln -sf 9r-claude                        ~/.local/bin/hermes-claude
install -Dm755 bin/kiro2claude          ~/.local/bin/kiro2claude
install -Dm755 bin/kiro2claude-summary  ~/.local/bin/kiro2claude-summary
install -Dm755 bin/kiro-compact         ~/.local/bin/kiro-compact
```

Pastikan `~/.local/bin` ada di PATH.

## Quick Start

```bash
# 1. Setup (first time)
9r-claude config
# masukin endpoint (cth: https://9r.zesbe.my.id atau http://127.0.0.1:20128),
# API key, pick model dari list

# 2. Verify
9r-claude show
9r-claude test

# 3. Jalankan (yolo default ON sejak v0.4)
9r-claude                              # interaktif, auto-bypass permission
9r-claude -p "halo, apa kabar"         # one-shot
9r-claude --resume                     # resume session picker
9r-claude --no-yolo                    # kalau mau permission prompt normal
```

## Ganti Endpoint / API Key / Model

```bash
# Ganti endpoint (mis. dari tunnel public ke local 9router)
9r-claude set-endpoint http://127.0.0.1:20128
9r-claude set-endpoint https://9r.zesbe.my.id

# Ganti API key
9r-claude set-key sk-xxxxxxxxxxxxxxxx

# Ganti default model
9r-claude set-model kr/claude-sonnet-4.5
9r-claude pick-model           # picker fzf/numbered (interaktif)

# Lihat hasil
9r-claude show
9r-claude models               # list semua model di endpoint
```

Untuk override per-tier (Opus/Sonnet/Haiku) tanpa wizard, edit langsung config:

```bash
9r-claude edit
# lalu isi/ubah:
# HERMES_OPUS_MODEL="kr/claude-opus-4.7-thinking"
# HERMES_SONNET_MODEL="kr/claude-sonnet-4.6-thinking"
# HERMES_HAIKU_MODEL="kr/claude-haiku-4.5"
```

## Yolo Mode (Auto-Accept Permission)

Default sejak v0.4 sudah ON. Override priority (tertinggi → terendah):

```bash
9r-claude --no-yolo            # 1. flag --no-yolo (sekali jalan, paksa OFF)
9r-claude -y                   # 2. flag -y / --yolo (sekali jalan, paksa ON; redundant karena default ON)
HERMES_YOLO=0 9r-claude        # 3. env var (per-run override)
9r-claude yolo off             # 4. simpan permanen di config
9r-claude yolo on              # ...nyalain lagi
9r-claude yolo status          # cek state
```

## Config File

Disimpan di `~/.config/9r-claude/config` (chmod 600), format key-value bash:

```bash
HERMES_ENDPOINT="https://9r.zesbe.my.id"
HERMES_API_KEY="sk-..."
HERMES_MODEL="kr/claude-opus-4.7-thinking"
HERMES_YOLO="1"  # 0 = matikan permanen
# Optional per-tier overrides
HERMES_OPUS_MODEL="kr/claude-opus-4.7-thinking"
HERMES_SONNET_MODEL="kr/claude-sonnet-4.6-thinking"
HERMES_HAIKU_MODEL="kr/claude-haiku-4.5"
```

Config lama di `~/.config/hermes-claude/config` di-migrate otomatis sekali waktu pertama kali `9r-claude` dijalankan.

## Subcommands

```
9r-claude                       launch claude pakai config aktif (yolo default ON)
9r-claude <args>                launch claude + pass-through args
9r-claude -- <args>             eksplisit pass-through (kalo arg bentrok)
9r-claude -y / --yolo           paksa yolo ON (sekali jalan)
9r-claude --no-yolo             paksa yolo OFF (sekali jalan)

CONFIG (one-time setup):
  9r-claude config              wizard interaktif (endpoint+key+model)
  9r-claude reset               hapus config (confirm dulu)

VIEW:
  9r-claude show                lihat config aktif (key dimask)
  9r-claude models              list semua model di endpoint
  9r-claude version             versi wrapper

EDIT:
  9r-claude set-endpoint <url>  ganti base URL
  9r-claude set-key <key>       ganti API key
  9r-claude set-model [model]   ganti model (kosong = picker)
  9r-claude pick-model          picker fzf/numbered
  9r-claude yolo on|off|status  toggle bypass permission permanen
  9r-claude edit                buka config di $EDITOR

DEBUG:
  9r-claude test                ping endpoint, verify auth
  HERMES_VERBOSE=1 9r-claude    print endpoint+model sebelum exec
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

Kalau yolo aktif, wrapper juga inject flag `--dangerously-skip-permissions` ke `claude` (gak duplikat kalau user udah pass manual).

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
9r-claude --resume <session-id>
```

Use case: lo punya sesi panjang di Kiro tapi mau lanjutin di Claude Code. Tool ini extract first prompt + last N turn jadi 1 user message yang clean (tanpa thinking signatures, tanpa tool_use ID mismatch), kompatibel buat di-`/resume` di Claude Code.

### kiro2claude — full replay (eksperimen)

Coba replay full history Kiro ke Claude. Ngelawan banyak constraint (token limit, signature validation, tool ID tracking). Pake `kiro2claude-summary` aja, lebih reliable.

## Pitfalls (Yang Gua Temuin Saat Build)

- **`/model` di Claude Code override `ANTHROPIC_MODEL`** dengan model ID lokal (e.g. `claude-opus-4-7[1m]`) yang gak dikenal endpoint custom. Solusi: pakai per-tier env vars. Kalau mau ganti model, keluar Claude → `9r-claude set-model` atau `9r-claude pick-model`.
- **Trailing `/v1` di endpoint** harus di-strip — Claude Code append `/v1` sendiri. Wrapper otomatis handle ini.
- **Yolo mode bypass safety** — auto-accept semua permission. Hati-hati di codebase yang sensitif. Pake `--no-yolo` atau `9r-claude yolo off` kalau mau prompt normal.
- **Thinking signatures** dari sesi Anthropic asli gak valid di endpoint relay (9router). `kiro2claude-summary` strip thinking blocks.
- **Orphan tool_use** (Kiro session keinterrupt) bikin API balikin 400. Padding stub tool_result dilakukan otomatis.
- **Token budget** > context window → 400 "Improperly formed request". `kiro2claude-summary` truncate ke ~2 MB / ~500k token by default.
- **Rate limit** balikin 400 dengan pesan "(reset after Xs)". Tunggu reset window-nya, bukan masalah konfigurasi.

## Changelog

- **v0.4.0** — Rename `hermes-claude` → `9r-claude` (alias lama tetap jalan via symlink). Yolo mode default ON. Tambah subcommand `yolo on|off|status`, flag `-y` / `--yolo` / `--no-yolo`, env `HERMES_YOLO`. Auto-migrate config dari `~/.config/hermes-claude` → `~/.config/9r-claude`.
- **v0.2.0** — Initial public release.

## Lihat Juga

- `docs/curl-examples.md` — curl commands buat test endpoint langsung
- `docs/troubleshooting.md` — fix common issues
- `examples/` — contoh script otomasi

## License

MIT

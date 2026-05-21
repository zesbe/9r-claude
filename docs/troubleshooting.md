# Troubleshooting

Daftar masalah yang sering ketemu pas pakai `9r-claude` + cara fix-nya.

## Setup & Config

### "config belum lengkap. Jalankan: 9r-claude config"

Belum jalanin wizard. Run:

```bash
9r-claude config
```

Atau set manual:

```bash
9r-claude set-endpoint "https://9r.zesbe.my.id"
9r-claude set-key "sk-..."
9r-claude set-model "kr/claude-opus-4.7-thinking"
```

### "binary 'claude' (Claude Code CLI) tidak ditemukan di PATH"

Install Claude Code dulu:

```bash
# via npm
npm install -g @anthropic-ai/claude-code

# verifikasi
which claude
claude --version
```

### Config file kemana?

```
~/.config/9r-claude/config        # default
$XDG_CONFIG_HOME/9r-claude/config # kalau XDG_CONFIG_HOME ke-set
```

Edit langsung kalau perlu:

```bash
9r-claude edit
# atau
$EDITOR ~/.config/9r-claude/config
```

## Connection & Auth

### HTTP 200 dari `9r-claude test` tapi error pas chat

Biasanya satu dari tiga ini:

1. **Model `/model` picker override**. Liat banner Claude Code — kalau di pojok ada "Opus 4" (bukan "Opus 4.7"), berarti picker udah override. Keluar Claude, run `9r-claude pick-model`, terus masuk lagi tanpa nyentuh `/model`.

2. **Trailing slash di endpoint**. Wrapper auto-strip, tapi kalau lo edit config manual mungkin nyelip. Cek:
   ```bash
   9r-claude show
   # endpoint harus tanpa trailing / atau /v1
   ```

3. **API key expired / di-rotate**. Test ulang:
   ```bash
   9r-claude test
   ```

### "API Error: 400 Invalid JSON body"

Kalau pas `/resume` sesi yang besar — kemungkinan thinking blocks dari sesi sebelumnya gak compatible dengan endpoint relay (signature mismatch).

Fix: jangan resume sesi yang isinya banyak thinking. Atau kalau sesi itu hasil import dari Kiro, regen pake `kiro2claude-summary` (yang strip thinking).

### "[400]: Improperly formed request"

Beberapa penyebab:

- **Token over limit**: total context window kelewat (~1M token untuk Opus 4.7). Kalau import sesi panjang, pake `kiro2claude-summary` yang truncate ke ~500k token.
- **Orphan tool_use**: turn assistant punya tool_use tanpa tool_result match-nya. `kiro2claude-summary` auto-pad. Kalau sesi asli Claude yang error, biasanya hasil interrupt — start sesi baru.
- **Model gak dikenal**: cek `9r-claude models` apakah model di config ada di list endpoint.

### "[400]: ... (reset after Xs)" atau "[403]: ... (reset after Xs)"

Itu **rate limit**, bukan format error. Tunggu sesuai countdown (`reset after 1m 30s` = tunggu 90 detik), terus coba lagi.

Verifikasi:

```bash
sleep 60 && 9r-claude test
```

Kalau abis sleep 200 (HTTP), berarti emang rate limit. Pertimbangin upgrade tier endpoint atau spread request lewat 2-3 proxy.

### "API key required for remote API access"

API key gak ke-kirim atau salah. Cek:

```bash
9r-claude show           # api key harus muncul (di-mask)
cat ~/.config/9r-claude/config | grep KEY
```

Kalau key di config keisi nilai masked (`sk-5d1...a61f`), lo nge-paste output dari `show`, bukan key asli. Set ulang:

```bash
9r-claude set-key "sk-real-key-here"
```

## Model Selection

### `/model` di Claude Code error: "claude-opus-4-7[1m] not exist"

Picker bawaan Claude Code map ke `ANTHROPIC_DEFAULT_OPUS_MODEL`. Kalau env var itu gak ke-set bener, picker fallback ke ID lokal yang gak dikenal endpoint.

Fix: pastiin per-tier env vars ke-export oleh wrapper. Jalanin:

```bash
HERMES_VERBOSE=1 9r-claude
# Liat output sebelum claude jalan, harus ada:
# ==> opus model:  kr/claude-opus-4.7-thinking
# ==> sonnet:      kr/claude-sonnet-4.6-thinking
# ==> haiku:       kr/claude-haiku-4.5
```

Kalau kosong / salah, edit config:

```bash
9r-claude edit
# tambahin / fix:
HERMES_OPUS_MODEL="kr/claude-opus-4.7-thinking"
HERMES_SONNET_MODEL="kr/claude-sonnet-4.6-thinking"
HERMES_HAIKU_MODEL="kr/claude-haiku-4.5"
```

### Switch model tanpa keluar Claude

Susah — `ANTHROPIC_MODEL` di-bake ke env saat launch. Kalau lo butuh switch model in-session, pake `/model` picker (yang map ke per-tier env vars). Pilih Opus / Sonnet / Haiku, masing-masing route ke model di tier-nya.

Kalau mau ganti model di tier yang sama (misalnya Opus thinking → Opus thinking-agentic), keluar Claude:

```bash
9r-claude pick-model
9r-claude
```

## Session Management

### `--resume` gak nemu sesi yang baru di-import

Claude Code pakai **filename** sebagai session ID, bukan field di dalam JSONL. `kiro2claude-summary` udah handle ini, tapi kalau lo bikin file manual, pastiin filename = sessionId field.

Cek:

```bash
ls ~/.claude/projects/-home-zesbe/
# session ID = nama file tanpa .jsonl
```

Resume:

```bash
9r-claude --resume <filename-without-jsonl>
```

### Banyak sesi pendek `/model` `/exit` di picker

Bersihin:

```bash
cd ~/.claude/projects/-home-zesbe
# list sesi <5KB (biasanya cuma command stub)
find . -name "*.jsonl" -size -5k -ls
# hapus
find . -name "*.jsonl" -size -5k -delete
```

### Sesi Kiro panjang kena rate limit terus

Pake `kiro-compact`:

```bash
kiro-compact                    # auto-compact sesi terakhir
kiro-compact --last 50          # bawa 50 turn terakhir
```

Atau migrate ke Claude Code permanen:

```bash
kiro2claude-summary ~/.kiro/sessions/cli/<id>.jsonl --cwd ~ --last 30
9r-claude --resume <session-id-from-output>
```

## Performance

### Response lambat

- **Streaming gak aktif?** Default Claude Code pakai streaming. Kalau lo override jadi `stream:false`, latency naik karena nunggu full response.
- **Endpoint jauh?** Cek latency:
  ```bash
  time curl -s -o /dev/null "$ENDPOINT/v1/models" -H "Authorization: Bearer $KEY"
  ```
- **Thinking model lambat?** Model `-thinking` butuh waktu reasoning. Kalau gak butuh deep reasoning, pake non-thinking variant.

### Compaction terlalu agresif

`ANTHROPIC_SMALL_FAST_MODEL` default ke Haiku — kalau Haiku gak available di endpoint, set ke model yang ada:

```bash
9r-claude edit
# tambah baris:
HERMES_HAIKU_MODEL="kr/claude-sonnet-4.6"  # fallback ke sonnet
```

## Reset Total

Kalau semua udah kacau dan mau mulai dari nol:

```bash
9r-claude reset                         # hapus config 9r-claude
rm -rf ~/.claude/projects/                  # hapus semua sesi Claude (HATI-HATI)
9r-claude config                        # setup ulang
```

## Debug Mode

```bash
HERMES_VERBOSE=1 9r-claude              # print info wrapper
ANTHROPIC_LOG=debug 9r-claude           # claude debug logs
```

Kalau masih bingung, capture full request:

```bash
HERMES_VERBOSE=1 9r-claude -p "test" 2>&1 | tee /tmp/debug.log
```

Ada error gak ke-cover di sini? Buka issue di GitHub repo dengan:

- Output `9r-claude show` (key di-mask, jangan paste yang asli)
- Output `9r-claude test`
- Error message persis (copy-paste, jangan re-type)

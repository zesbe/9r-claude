# curl Examples — Test Endpoint Langsung

Kalau mau test endpoint Anthropic-compatible (9router/Hermes/proxy lain) tanpa Claude Code, semua command di sini siap copy-paste. Ganti `$ENDPOINT` dan `$KEY` sesuai punya lo.

```bash
export ENDPOINT="https://9r.zesbe.my.id"
export KEY="sk-..."
export MODEL="kr/claude-opus-4.7-thinking"
```

## 1. Health Check / Test Auth

Yang paling cepet — kirim 1 request kecil, cek status code.

```bash
curl -s -w "\nHTTP %{http_code}\n" \
  -X POST "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "max_tokens": 20,
    "messages": [{"role":"user","content":"say hi in 3 words"}]
  }'
```

Expected: `HTTP 200` + JSON dengan `content[0].text` "Hi there friend" atau sejenis.

## 2. List Available Models

OpenAI-compat endpoint (banyak proxy support ini, including 9router).

```bash
curl -s "$ENDPOINT/v1/models" \
  -H "Authorization: Bearer $KEY" \
  | jq -r '.data[].id'
```

Output sample dari 9router:

```
kr/claude-opus-4.7
kr/claude-opus-4.7-agentic
kr/claude-opus-4.7-thinking
kr/claude-opus-4.7-thinking-agentic
kr/claude-sonnet-4.6-thinking
kr/claude-haiku-4.5
...
```

## 3. Chat Sederhana (Non-Streaming)

```bash
curl -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "max_tokens": 500,
    "messages": [
      {"role":"user","content":"Apa itu Docker dalam 3 kalimat?"}
    ]
  }' | jq -r '.content[0].text'
```

## 4. Streaming Response (SSE)

```bash
curl -N -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "max_tokens": 500,
    "stream": true,
    "messages": [{"role":"user","content":"hitung 1 sampai 10"}]
  }'
```

Parse SSE stream, extract teks aja:

```bash
curl -N -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model":"'"$MODEL"'","max_tokens":500,"stream":true,
    "messages":[{"role":"user","content":"halo"}]
  }' \
  | grep '^data: ' \
  | sed 's/^data: //' \
  | jq -r 'select(.type=="content_block_delta") | .delta.text // empty' \
  | tr -d '\n'
echo
```

## 5. Multi-Turn Conversation

```bash
curl -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "max_tokens": 1000,
    "messages": [
      {"role":"user","content":"Bahasa Inggris dari halo apa?"},
      {"role":"assistant","content":"Hello atau hi."},
      {"role":"user","content":"Kalau yang formal?"}
    ]
  }' | jq -r '.content[0].text'
```

## 6. Dengan System Prompt

```bash
curl -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "max_tokens": 500,
    "system": "Kamu adalah expert PostgreSQL. Jawab singkat & teknis.",
    "messages": [
      {"role":"user","content":"Apa beda VACUUM dan VACUUM FULL?"}
    ]
  }' | jq -r '.content[0].text'
```

## 7. Tool Use

```bash
curl -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "max_tokens": 1024,
    "tools": [{
      "name": "get_weather",
      "description": "Get current weather for a city",
      "input_schema": {
        "type": "object",
        "properties": {
          "city": {"type":"string","description":"City name"}
        },
        "required": ["city"]
      }
    }],
    "messages": [
      {"role":"user","content":"Cuaca Jakarta hari ini gimana?"}
    ]
  }' | jq
```

Response bakal punya `content[]` dengan `tool_use` block. Lo execute tool-nya, lalu kirim ulang dengan `tool_result`:

```bash
curl -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "max_tokens": 1024,
    "tools": [{ "...": "same as above" }],
    "messages": [
      {"role":"user","content":"Cuaca Jakarta hari ini gimana?"},
      {"role":"assistant","content":[
        {"type":"text","text":"Aku cek dulu."},
        {"type":"tool_use","id":"toolu_01abc","name":"get_weather","input":{"city":"Jakarta"}}
      ]},
      {"role":"user","content":[
        {"type":"tool_result","tool_use_id":"toolu_01abc","content":"32C, hujan ringan"}
      ]}
    ]
  }' | jq -r '.content[0].text'
```

## 8. Bandingin Beberapa Model

```bash
for m in kr/claude-haiku-4.5 kr/claude-sonnet-4.6-thinking kr/claude-opus-4.7-thinking; do
  echo "=== $m ==="
  curl -s "$ENDPOINT/v1/messages" \
    -H "x-api-key: $KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d '{
      "model":"'"$m"'","max_tokens":80,
      "messages":[{"role":"user","content":"Sebutkan 3 prinsip OOP"}]
    }' | jq -r '.content[0].text'
  echo
done
```

## 9. Hitung Token (Count Tokens API)

```bash
curl -s "$ENDPOINT/v1/messages/count_tokens" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "'"$MODEL"'",
    "messages": [{"role":"user","content":"Halo apa kabar?"}]
  }' | jq
```

## 10. Auth Variants

Banyak endpoint terima dua header sekaligus:

```bash
# Anthropic native style
-H "x-api-key: $KEY"

# OpenAI style (Bearer)
-H "Authorization: Bearer $KEY"
```

9router & sebagian besar proxy Anthropic-compat support keduanya. `hermes-claude` pakai `ANTHROPIC_AUTH_TOKEN` yang nge-generate `Authorization: Bearer` header.

## Common Errors

| HTTP | Pesan | Penyebab |
|---|---|---|
| 200 | (success) | OK |
| 400 | "Improperly formed request" | Body invalid (missing field, model unknown, payload terlalu besar) |
| 400 | "(reset after Xs)" | Rate limit, tunggu sesuai countdown |
| 401 | "API key required" | API key salah / kosong |
| 403 | "HTTP 403 (reset after Xs)" | Rate limit di upstream |
| 404 | "Not Found" | Endpoint salah (cth: pakai `/messages` tanpa `/v1`) |
| 413 | "Payload too large" | Total token over context limit |
| 429 | "Too Many Requests" | Rate limit (klasik) |
| 503 | "Service Unavailable" | Upstream Anthropic down / maintenance |

## Debugging Tips

```bash
# Tampilkan request + response headers
curl -v "$ENDPOINT/v1/messages" ...

# Save response ke file buat dianalisa
curl -s "$ENDPOINT/v1/messages" ... -o /tmp/response.json
jq '.' /tmp/response.json

# Time the request
time curl -s "$ENDPOINT/v1/messages" ... -o /dev/null

# Body dari file (untuk payload besar yg susah inline)
echo '{"model":"...","messages":[...]}' > /tmp/req.json
curl -s "$ENDPOINT/v1/messages" \
  -H "x-api-key: $KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  --data-binary @/tmp/req.json
```

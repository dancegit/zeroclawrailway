# Modal GPU TTS Skill

Use Modal.com for GPU-accelerated text-to-speech generation.

## Overview

Modal provides serverless GPU containers. The TTS service runs on A10G GPUs for fast audio generation.

## Endpoints

| Endpoint | Use Case | Timeout |
|----------|----------|---------|
| `MODAL_TTS_ENDPOINT` | Regular TTS (<5000 chars) | 600s |
| `MODAL_TTS_LONG_ENDPOINT` | Long-form TTS (>5000 chars) | 1200s |

## Request Format

```bash
curl -X POST "$MODAL_TTS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"text": "Your text here", "voice": "am_adam", "speed": 1.0, "lang": "en-us"}'
```

## Response Format

```json
{
  "audio_base64": "...",
  "sample_rate": 24000,
  "format": "wav"
}
```

## Available Voices

| Voice | Gender | Accent |
|-------|--------|--------|
| `am_adam` | Male | American |
| `am_echo` | Male | American |
| `am_eric` | Male | American |
| `af_sarah` | Female | American |
| `af_nicole` | Female | American |
| `bf_emma` | Female | British |
| `bm_george` | Male | British |

## Helper Script

```bash
modal_tts() {
    local text="$1"
    local output="$2"
    local voice="${3:-am_adam}"
    local speed="${4:-1.0}"
    local tmp="/tmp/modal_tts_$$.json"
    
    curl -s -X POST "${MODAL_TTS_ENDPOINT}" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"$text\", \"voice\": \"$voice\", \"speed\": $speed}" \
      -o "$tmp"
    
    python3 -c "import json,base64; d=json.load(open('$tmp')); open('$output','wb').write(base64.b64decode(d['audio_base64']))"
    rm -f "$tmp"
    
    echo "Audio saved to: $output"
}

# Usage:
# modal_tts "Hello world" /zeroclaw-data/.zeroclaw/workspace/tts-output/test.wav am_adam 1.0
```

## Long Text Handling

For texts >5000 characters, use the long endpoint with chunking:

```bash
curl -X POST "$MODAL_TTS_LONG_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Very long text...",
    "voice": "am_adam",
    "speed": 1.0,
    "lang": "en-us",
    "chunk_size": 5000
  }'
```

## Environment Variables

Set in Railway:
- `ZEROCLAW_MODAL_TTS_ENDPOINT` - Auto-exported to `MODAL_TTS_ENDPOINT`

## Troubleshooting

### Timeout on first request

First request cold-starts the GPU container (10-30s). Subsequent requests are fast.

### InvalidProtobuf error

Model files are downloaded during image build. If you see this error, redeploy the Modal app.

### Connection refused

Check that the endpoint URL is correct and the app is deployed.

## Deployment

The Modal app is at: `/home/per/development/gitrepos/modal-kokoro-tts/app.py`

```bash
export MODAL_TOKEN_ID="your-token-id"
export MODAL_TOKEN_SECRET="your-token-secret"
modal deploy app.py
```

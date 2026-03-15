# Modal GPU TTS Skill

Use Modal.com for GPU-accelerated text-to-speech generation.

## Overview

Modal provides serverless GPU containers. The TTS service runs on T4 GPUs for fast audio generation.

## Endpoints

| Endpoint | Use Case | Timeout |
|----------|----------|---------|
| `MODAL_TTS_ENDPOINT` | Regular TTS (<5000 chars) | 600s |
| `MODAL_TTS_CONVERSE_ENDPOINT` | Multi-voice conversation/debate | 1200s |

## Single Voice Request

```bash
curl -X POST "$MODAL_TTS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"text": "Your text here", "voice": "am_adam", "speed": 1.0, "lang": "en-us"}'
```

## Multi-Voice Conversation (News Anchor / Debate Style)

```bash
curl -X POST "$MODAL_TTS_CONVERSE_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "dialogue": [
      {"voice": "bm_george", "text": "Good morning! Welcome to your daily news briefing."},
      {"voice": "af_sarah", "text": "Thanks! Let us dive into today top stories."},
      {"voice": "bm_george", "text": "In technology news today..."},
      {"voice": "af_sarah", "text": "And in science, researchers have discovered..."}
    ],
    "pause_ms": 500,
    "speed": 1.0
  }'
```

## Response Format

```json
{
  "audio_base64": "...",
  "sample_rate": 24000,
  "format": "wav",
  "segments_processed": 4
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
| `af_sky` | Female | American |
| `bf_emma` | Female | British |
| `bm_george` | Male | British |
| `bm_fable` | Male | British |
| `bm_lewis` | Male | British |
| `bf_alice` | Female | British |
| `bf_lily` | Female | British |

## Helper Script for Single Voice

```bash
modal_tts() {
    local text="$1"
    local output="$2"
    local voice="${3:-am_adam}"
    local speed="${4:-1.0}"
    local tmp="/tmp/modal_tts_$$.json"
    
    curl -s -X POST "${MODAL_TTS_ENDPOINT}" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"$text\", \"voice\": \"$voice\", \"speed\": $speed, \"password\": \"$MODAL_TTS_PASSWORD\"}" \
      -o "$tmp"
    
    python3 -c "import json,base64; d=json.load(open('$tmp')); open('$output','wb').write(base64.b64decode(d['audio_base64']))"
    rm -f "$tmp"
    
    echo "Audio saved to: $output"
}

# Usage:
# modal_tts "Hello world" /zeroclaw-data/.zeroclaw/workspace/tts-output/test.wav am_adam 1.0
```

## Helper Script for Conversation TTS

```bash
converse_tts() {
    local dialogue_json="$1"
    local output="$2"
    local pause_ms="${3:-500}"
    local tmp="/tmp/converse_tts_$$.json"
    
    curl -s -X POST "${MODAL_TTS_CONVERSE_ENDPOINT}" \
      -H "Content-Type: application/json" \
      -d "{\"dialogue\": $dialogue_json, \"pause_ms\": $pause_ms, \"password\": \"$MODAL_TTS_PASSWORD\"}" \
      -o "$tmp"
    
    python3 -c "import json,base64; d=json.load(open('$tmp')); open('$output','wb').write(base64.b64decode(d['audio_base64']))"
    rm -f "$tmp"
    
    echo "Conversation audio saved to: $output"
}

# Usage:
# dialogue='[{"voice": "bm_george", "text": "Hello!"}, {"voice": "af_sarah", "text": "Hi there!"}]'
# converse_tts "$dialogue" /zeroclaw-data/.zeroclaw/workspace/tts-output/convo.wav 500
```

## Environment Variables

Set in Railway:
- `ZEROCLAW_MODAL_TTS_ENDPOINT` - Auto-exported to `MODAL_TTS_ENDPOINT`
- `ZEROCLAW_MODAL_TTS_CONVERSE_ENDPOINT` - Auto-exported to `MODAL_TTS_CONVERSE_ENDPOINT`
- `ZEROCLAW_MODAL_TTS_PASSWORD` - Auto-exported to `MODAL_TTS_PASSWORD`

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

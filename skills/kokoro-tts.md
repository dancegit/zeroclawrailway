# Kokoro TTS Skill

Text-to-speech synthesis for generating audio files from text. Supports single voice and multi-voice conversations.

## Prerequisites

- `ZEROCLAW_KOKORO_ENABLED=true` must be set
- Model files are downloaded automatically on first use (~50MB)
- **IMPORTANT**: kokoro-tts requires FILE input, NOT stdin

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ZEROCLAW_KOKORO_ENABLED` | `false` | Enable Kokoro TTS |
| `ZEROCLAW_KOKORO_VOICE` | `am_adam` | Default voice |
| `ZEROCLAW_KOKORO_SPEED` | `1.0` | Speech speed (0.5-2.0) |
| `ZEROCLAW_KOKORO_TIMEOUT` | `1200` | Timeout in seconds |
| `ZEROCLAW_KOKORO_OUTPUT_DIR` | `$WORKSPACE/tts-output` | Output directory |
| `ZEROCLAW_KOKORO_MODEL_DIR` | `$WORKSPACE/.kokoro-models` | Model files directory |

## Available Voices

| Voice | Description |
|-------|-------------|
| `am_adam` | Male, American English (recommended default) |
| `am_echo` | Male, American English |
| `am_eric` | Male, American English |
| `bm_george` | Male, British English |
| `bm_fable` | Male, British English |
| `bm_lewis` | Male, British English |
| `af_sarah` | Female, American English |
| `af_nicole` | Female, American English |
| `af_sky` | Female, American English |
| `bf_emma` | Female, British English |
| `bf_alice` | Female, British English |
| `bf_lily` | Female, British English |

## Output Directory

Audio files are saved to: `$WORKSPACE/tts-output/` (default)
Override with: `ZEROCLAW_KOKORO_OUTPUT_DIR`

---

## Usage

### Single Voice: Text to Audio

```bash
echo "Hello, this is a test message." > /tmp/input.txt
kokoro-tts --voice am_adam /tmp/input.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav
rm /tmp/input.txt
```

### Adjust Speed (0.5 - 2.0)

```bash
echo "Slow down a bit" > /tmp/slow.txt
kokoro-tts --voice am_adam --speed 0.8 /tmp/slow.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/slow.wav
rm /tmp/slow.txt
```

### Long Text Handling

For texts >10,000 characters:
1. Set `ZEROCLAW_KOKORO_TIMEOUT=1200` (already set)
2. Consider splitting into smaller chunks
3. Use `--split-output` for very long texts:

```bash
kokoro-tts --voice am_adam /path/to/long.txt --split-output /zeroclaw-data/.zeroclaw/workspace/tts-output/chunks/
```

---

## Modal GPU Acceleration

**GPU-accelerated TTS via Modal endpoint is available!**

When `MODAL_TTS_ENDPOINT` is set, use it for faster GPU-accelerated TTS.

### Environment Variables

| Variable | Description |
|----------|-------------|
| `MODAL_TTS_ENDPOINT` | Modal single-voice TTS endpoint URL |
| `MODAL_TTS_CONVERSE_ENDPOINT` | Modal multi-voice conversation endpoint URL |
| `MODAL_TTS_PASSWORD` | Password for TTS endpoint |

### Single Voice Request (GPU)

```bash
curl -s -X POST "$MODAL_TTS_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, this is a GPU-accelerated test.", "voice": "am_adam", "speed": 1.0, "password": "'"$MODAL_TTS_PASSWORD"'"}' \
  -o /tmp/response.json

python3 -c "import json,base64; d=json.load(open('/tmp/response.json')); open('/zeroclaw-data/.zeroclaw/workspace/tts-output/modal_audio.wav','wb').write(base64.b64decode(d['audio_base64']))"
```

### Multi-Voice Conversation (News Anchor / Debate Style)

Use the converse endpoint for generating dialogue between multiple speakers:

```bash
curl -s -X POST "$MODAL_TTS_CONVERSE_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "dialogue": [
      {"voice": "bm_george", "text": "Good morning! Welcome to your daily news briefing."},
      {"voice": "af_sarah", "text": "Thanks! Let me walk you through today top stories."},
      {"voice": "bm_george", "text": "In technology news today..."},
      {"voice": "af_sarah", "text": "And in science, researchers have discovered..."}
    ],
    "pause_ms": 500,
    "password": "'"$MODAL_TTS_PASSWORD"'"
  }' \
  -o /tmp/conv.json

python3 -c "import json,base64; d=json.load(open('/tmp/conv.json')); open('/zeroclaw-data/.zeroclaw/workspace/tts-output/conversation.wav','wb').write(base64.b64decode(d['audio_base64']))"
```

### Response Format

```json
{
  "audio_base64": "...",
  "sample_rate": 24000,
  "format": "wav",
  "segments_processed": 4
}
```

### Voice Pair Recommendations

For natural-sounding conversations:

| Style | Anchor (Host) | Commentator (Guest) |
|-------|---------------|---------------------|
| News Broadcast | `bm_george` (British male) | `af_sarah` (American female) |
| Casual Chat | `am_adam` (American male) | `bf_emma` (British female) |
| Tech Podcast | `am_eric` (American male) | `af_nicole` (American female) |
| Academic | `bm_lewis` (British male) | `bf_alice` (British female) |

### Multi-Voice Helper Script

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

---

## Sending Audio via Telegram

After generating an audio file, send it as an attachment using the **absolute path**:

```
Use the send_attachment tool with the absolute path to the generated audio file:
/zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav
```

**IMPORTANT**: Always use absolute paths when sending attachments. Relative paths will not work.

## Example Workflows

### Single Voice Audio Message

```bash
# Create temp file with text
echo "Once upon a time, in a magical forest..." > /tmp/story.txt
# Convert to audio
kokoro-tts --voice am_adam --speed 0.9 /tmp/story.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/story.wav
# Clean up
rm /tmp/story.txt
# Send to user
# Use: /zeroclaw-data/.zeroclaw/workspace/tts-output/story.wav
```

### Multi-Voice Conversation (News Briefing)

```bash
# Build dialogue for news briefing
dialogue='[
  {"voice": "bm_george", "text": "Welcome to the morning news briefing for today."},
  {"voice": "af_sarah", "text": "We have some exciting stories to share with you."},
  {"voice": "bm_george", "text": "First up, technology news."},
  {"voice": "af_sarah", "text": "Researchers have made a breakthrough in AI."}
]'

# Generate conversation audio
curl -s -X POST "$MODAL_TTS_CONVERSE_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "{\"dialogue\": $dialogue, \"pause_ms\": 500, \"password\": \"$MODAL_TTS_PASSWORD\"}" \
  -o /tmp/conv.json

python3 -c "import json,base64; d=json.load(open('/tmp/conv.json')); open('/zeroclaw-data/.zeroclaw/workspace/tts-output/briefing.wav','wb').write(base64.b64decode(d['audio_base64']))"

# Send to user
# Use: /zeroclaw-data/.zeroclaw/workspace/tts-output/briefing.wav
```

---

## Troubleshooting

### "Input file required" error

kokoro-tts requires a file input, not stdin. Always write text to a temp file first:

```bash
# WRONG - stdin not supported:
echo "Hello" | kokoro-tts --voice am_adam - output.wav

# CORRECT - use temp file:
echo "Hello" > /tmp/input.txt
kokoro-tts --voice am_adam /tmp/input.txt output.wav
```

### Model files not found

First run downloads models automatically. If failed:
1. Check `ZEROCLAW_KOKORO_MODEL_DIR` environment variable
2. Ensure directory exists and is writable

### Audio quality issues

- Try different voices
- Adjust speed (slower = clearer)
- Ensure input text has proper punctuation for natural pauses

### File too large for Telegram

- Telegram has a 50MB limit per file
- Split long content into multiple files using `--split-output`
- Use mp3 format for smaller files: `--format mp3`

### Timeout on long texts

If generation times out:
1. Check `ZEROCLAW_KOKORO_TIMEOUT` is set high enough (default: 1200s)
2. Split text into smaller chunks
3. Use `--split-output` option for automatic chunking

### Modal endpoint errors

If the Modal GPU endpoint returns errors:
1. Check `MODAL_TTS_ENDPOINT` and `MODAL_TTS_CONVERSE_ENDPOINT` are set
2. Verify `MODAL_TTS_PASSWORD` is correct
3. First request may take 10-30s for GPU cold start
4. Check the response JSON for `error` field

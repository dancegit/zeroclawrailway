# Kokoro TTS Skill

Text-to-speech synthesis for generating audio files from text.

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
| `ZEROCLAW_KOKORO_TIMEOUT` | `1200` | Timeout in seconds (increase for long texts) |
| `ZEROCLAW_KOKORO_OUTPUT_DIR` | `$WORKSPACE/tts-output` | Output directory |
| `ZEROCLAW_KOKORO_MODEL_DIR` | `$WORKSPACE/.kokoro-models` | Model files directory |

## Available Voices

| Voice | Description |
|-------|-------------|
| `am_adam` | Male, American English (recommended default) |
| `bm_george` | Male, British English |
| `af_sarah` | Female, American English |
| `af_nicole` | Female, American English |
| `af_sky` | Female, American English |
| `bf_emma` | Female, British English |

## Output Directory

Audio files are saved to: `$WORKSPACE/tts-output/` (default)
Override with: `ZEROCLAW_KOKORO_OUTPUT_DIR`

## Usage

### Basic: Text string to audio file

```bash
# Write text to temp file, then convert
echo "Hello, this is a test message." > /tmp/input.txt
kokoro-tts --voice am_adam /tmp/input.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav
rm /tmp/input.txt
```

### File to audio

```bash
kokoro-tts --voice am_adam --speed 1.0 /path/to/input.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav
```

### Adjust speed (0.5 - 2.0)

```bash
echo "Slow down a bit" > /tmp/slow.txt
kokoro-tts --voice am_adam --speed 0.8 /tmp/slow.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/slow.wav
rm /tmp/slow.txt
```

### Long text handling

For texts >10,000 characters:
1. Set `ZEROCLAW_KOKORO_TIMEOUT=1200` (already set)
2. Consider splitting into smaller chunks
3. Use `--split-output` for very long texts:

```bash
kokoro-tts --voice am_adam /path/to/long.txt --split-output /zeroclaw-data/.zeroclaw/workspace/tts-output/chunks/
```

## Modal GPU Acceleration

**Note**: Modal is configured but kokoro-tts CLI does NOT automatically use it. GPU acceleration requires a custom Modal wrapper app.

Current setup:
- `ZEROCLAW_MODAL_ENABLED=true` - Modal credentials are set
- `ZEROCLAW_MODAL_GPU_TYPE=a10g` - GPU type configured
- Kokoro runs on CPU by default (slower for long texts)

For GPU acceleration, you would need to:
1. Create a Modal app that wraps kokoro-tts
2. Deploy it as an endpoint
3. Call the endpoint instead of local kokoro-tts

## Sending Audio via Telegram

After generating an audio file, send it as an attachment using the **absolute path**:

```
Use the send_attachment tool with the absolute path to the generated audio file:
/zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav
```

**IMPORTANT**: Always use absolute paths when sending attachments. Relative paths will not work.

## Example Workflow: Generate and Send Audio Message

1. Generate the audio file:
```bash
# Create temp file with text
echo "Once upon a time, in a magical forest..." > /tmp/story.txt
# Convert to audio
kokoro-tts --voice am_adam --speed 0.9 /tmp/story.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/story.wav
# Clean up
rm /tmp/story.txt
```

2. Verify the file exists:
```bash
ls -la /zeroclaw-data/.zeroclaw/workspace/tts-output/story.wav
```

3. Send to user via Telegram:
```
Send attachment: /zeroclaw-data/.zeroclaw/workspace/tts-output/story.wav
```

## Helper Function for Easy TTS

You can create a helper script to simplify TTS generation:

```bash
# Add to ~/.bashrc or create as /usr/local/bin/tts-quick
tts-quick() {
    local text="$1"
    local output="$2"
    local voice="${3:-am_adam}"
    local speed="${4:-1.0}"
    local tmp_file="/tmp/tts-input-$$.txt"
    
    echo "$text" > "$tmp_file"
    kokoro-tts --voice "$voice" --speed "$speed" "$tmp_file" "$output"
    rm "$tmp_file"
}

# Usage:
# tts-quick "Hello world" /zeroclaw-data/.zeroclaw/workspace/tts-output/hello.wav am_adam 1.0
```

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

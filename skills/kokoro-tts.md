# Kokoro TTS Skill

Text-to-speech synthesis for generating audio files from text.

## Prerequisites

- `ZEROCLAW_KOKORO_ENABLED=true` must be set
- Model files are downloaded automatically on first use (~50MB)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ZEROCLAW_KOKORO_ENABLED` | `false` | Enable Kokoro TTS |
| `ZEROCLAW_KOKORO_VOICE` | `af_sarah` | Default voice |
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

### Basic: stdin to audio file

```bash
echo "Hello, this is a test message." | kokoro-tts --voice am_adam - output.wav
```

### File to audio

```bash
kokoro-tts --voice am_adam --speed 1.0 input.txt output.wav
```

### Long text (increase timeout)

For long scripts, the TTS may timeout and fall back to gTTS (which uses a female voice). To prevent this:

1. Set `ZEROCLAW_KOKORO_TIMEOUT=1200` or higher
2. Or use Modal GPU for faster processing

## Troubleshooting

### Timeout falling back to gTTS female voice

If you hear a female voice instead of the configured male voice, the Kokoro TTS timed out and fell back to gTTS.

**Fix:** Increase the timeout:
```bash
railway variable set ZEROCLAW_KOKORO_TIMEOUT=120 --service YOUR_SERVICE
```

### Model download taking too long

First-run model download (~50MB) may take time. Subsequent runs will be faster.

### From file to audio

```bash
kokoro-tts --voice af_sarah --speed 1.0 /path/to/input.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav
```

### Adjust speed (0.5 - 2.0)

```bash
echo "Slow down a bit" | kokoro-tts --voice af_sarah --speed 0.8 - /zeroclaw-data/.zeroclaw/workspace/tts-output/slow.wav
```

### Long text (use Modal for GPU acceleration)

For texts >10,000 characters, enable Modal GPU:

```bash
# Requires ZEROCLAW_MODAL_ENABLED=true
kokoro-tts --voice af_sarah --use-modal /path/to/long.txt /zeroclaw-data/.zeroclaw/workspace/tts-output/long.wav
```

## Sending Audio via Telegram

After generating an audio file, send it as an attachment using the **absolute path**:

```
Use the send_attachment tool with the absolute path to the generated audio file:
/zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav
```

**IMPORTANT**: Always use absolute paths when sending attachments. Relative paths will not work.

## Example Workflow: Generate and Send Bedtime Story

1. Generate the audio file:
```bash
echo "Once upon a time, in a magical forest..." | kokoro-tts --voice af_sarah --speed 0.9 - /zeroclaw-data/.zeroclaw/workspace/tts-output/bedtime_story.wav
```

2. Verify the file exists:
```bash
ls -la /zeroclaw-data/.zeroclaw/workspace/tts-output/bedtime_story.wav
```

3. Send to user via Telegram:
```
Send attachment: /zeroclaw-data/.zeroclaw/workspace/tts-output/bedtime_story.wav
```

## Troubleshooting

### Model files not found
- First run downloads models automatically
- If failed, check `ZEROCLAW_KOKORO_MODEL_DIR` environment variable

### Audio quality issues
- Try different voices
- Adjust speed (slower = clearer)
- Ensure input text is properly formatted (add punctuation for pauses)

### File too large for Telegram
- Telegram has a 50MB limit per file
- Split long content into multiple files
- Use lower sample rate if supported

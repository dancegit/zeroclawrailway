# Telegram Attachments Skill

How to send files, images, and audio via ZeroClaw's Telegram channel.

## Critical Rule: Always Use Absolute Paths

When sending attachments via Telegram, you **MUST use absolute paths**. Relative paths will fail.

**Correct**:
```
/zeroclaw-data/.zeroclaw/workspace/tts-output/audio.wav
```

**Wrong** (will not work):
```
./tts-output/audio.wav
tts-output/audio.wav
~/workspace/tts-output/audio.wav
```

## Workspace Paths

The workspace is located at: `/zeroclaw-data/.zeroclaw/workspace/`

Common directories:
- TTS output: `/zeroclaw-data/.zeroclaw/workspace/tts-output/`
- Obsidian vault: `/zeroclaw-data/.zeroclaw/workspace/vault/` (or `$OBSIDIAN_VAULT_PATH`)
- Cloned repos: `/zeroclaw-data/.zeroclaw/workspace/<repo-name>/`

## How to Send Attachments

When you have a file to send to the user:

1. **Generate or locate the file** using absolute path
2. **Verify the file exists** before sending
3. **Use the send_attachment tool** with the absolute path

### Example: Send Generated Audio

```bash
# 1. Generate audio
echo "Hello world" | kokoro-tts --voice af_sarah - /zeroclaw-data/.zeroclaw/workspace/tts-output/hello.wav

# 2. Verify file exists
ls -la /zeroclaw-data/.zeroclaw/workspace/tts-output/hello.wav

# 3. Send to user
# Use the send_attachment tool with path: /zeroclaw-data/.zeroclaw/workspace/tts-output/hello.wav
```

### Example: Send Image from Workspace

```
# Use the send_attachment tool with path: /zeroclaw-data/.zeroclaw/workspace/images/diagram.png
```

### Example: Send Document

```
# Use the send_attachment tool with path: /zeroclaw-data/.zeroclaw/workspace/reports/report.pdf
```

## Supported File Types

### Images
- `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`
- Telegram displays these inline

### Audio
- `.wav`, `.mp3`, `.ogg`, `.m4a`
- `.wav` recommended for TTS output (best quality)
- Telegram may transcode to `.ogg` for voice messages

### Video
- `.mp4`, `.webm`, `.mov`
- Max 50MB per file

### Documents
- `.pdf`, `.doc`, `.docx`, `.txt`, `.md`
- Max 50MB per file

## Common Mistakes

### 1. Using relative paths
```
❌ WRONG: ./output/audio.wav
❌ WRONG: output/audio.wav
✅ CORRECT: /zeroclaw-data/.zeroclaw/workspace/tts-output/audio.wav
```

### 2. Not verifying file exists before sending
Always run `ls -la <path>` first to confirm:
```bash
ls -la /zeroclaw-data/.zeroclaw/workspace/tts-output/audio.wav
# Should show file size and permissions
```

### 3. File too large
- Telegram limit: 50MB per file
- For large TTS outputs, split into parts

## Debugging Attachment Issues

If attachment fails to send:

1. Check the path is absolute: starts with `/`
2. Verify file exists: `ls -la <path>`
3. Check file size: `du -h <path>`
4. Verify file permissions: should be readable
5. Try with a smaller test file first

## Quick Reference

| Action | Command |
|--------|---------|
| Get workspace path | `echo $WORKSPACE_DIR` or `/zeroclaw-data/.zeroclaw/workspace/` |
| List TTS files | `ls -la /zeroclaw-data/.zeroclaw/workspace/tts-output/` |
| Check file size | `du -h /path/to/file` |
| Verify readable | `test -r /path/to/file && echo "readable"` |

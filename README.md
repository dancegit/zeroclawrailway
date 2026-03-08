# ZeroClaw Railway Image

Custom Docker image for deploying ZeroClaw on Railway with Telegram channel support.

## Features

- Generates config from environment variables at runtime
- Supports Telegram channel out of the box
- No hardcoded secrets

## Required Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ZAI_API_KEY` | ZAI API key | Yes |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | For Telegram |
| `ZEROCLAW_MODEL` | Model to use (default: glm-5) | No |
| `DEFAULT_PROVIDER` | Provider (default: zai) | No |
| `TELEGRAM_ALLOWED_USERS` | JSON array of allowed users (default: ["*"]) | No |

## Usage

### Railway

1. Create a new service from this image: `your-org/zeroclawrailway:latest`
2. Set the required environment variables
3. Deploy

### Local

```bash
docker build -t zeroclaw-railway .
docker run -e ZAI_API_KEY=your-key -e TELEGRAM_BOT_TOKEN=your-token zeroclaw-railway
```

## Image Source

Based on [ghcr.io/zeroclaw-labs/zeroclaw:latest](https://github.com/zeroclaw-labs/zeroclaw)

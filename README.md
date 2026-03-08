# ZeroClaw Railway Image

Custom Docker image for deploying ZeroClaw on Railway with Telegram channel support.

## Features

- Generates config from environment variables at runtime
- Supports Telegram channel out of the box
- **Secure by default**: Gateway requires pairing and does not allow public binding
- No hardcoded secrets
- Includes development tools: git, gh CLI, Node.js, Rust/Cargo, vim, neovim, htop, bun, fastfetch

## Security Configuration

By default, the gateway is secured:
- `require_pairing = true` - Clients must pair before accessing the API
- `allow_public_bind = false` - Gateway only accessible via tunnel or localhost

Override these with environment variables:
- `ZEROCLAW_REQUIRE_PAIRING` - Set to `false` to disable pairing requirement
- `ZEROCLAW_ALLOW_PUBLIC_BIND` - Set to `true` to allow public binding (NOT RECOMMENDED)

## Required Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ZAI_API_KEY` | ZAI API key | Yes |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | For Telegram |
| `ZEROCLAW_MODEL` | Model to use (default: glm-5) | No |
| `DEFAULT_PROVIDER` | Provider (default: zai) | No |
| `TELEGRAM_ALLOWED_USERS` | JSON array of allowed users (default: ["*"]) | No |
| `ZEROCLAW_REQUIRE_PAIRING` | Require pairing for gateway (default: true) | No |
| `ZEROCLAW_ALLOW_PUBLIC_BIND` | Allow public binding (default: false) | No |

## Included Packages

The image includes these tools (installed via apt-get):
- `git` - Version control
- `gh` - GitHub CLI
- `nodejs` - Node.js runtime
- `cargo` - Rust package manager
- `vim` / `neovim` - Text editors
- `htop` - System monitor
- `bun` - JavaScript runtime

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

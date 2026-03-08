# ZeroClaw Railway Image

Custom Docker image for deploying ZeroClaw on Railway with **multi-channel support**.

## Features

- Generates config from environment variables at runtime
- **Dynamic SOUL.md generation** from repository analysis for context-aware agents
- Supports **all ZeroClaw providers** via environment variables
- **Multi-channel support**: Telegram, Discord, Slack, Matrix, WhatsApp, and more
- **Secure by default**: Gateway bound to localhost only, NOT exposed to internet
- No hardcoded secrets
- **Full autonomy mode** - autonomous execution within policy bounds
- Comprehensive development tools pre-installed

## Security Configuration

The gateway is **NOT exposed to the internet**:
- `host = "127.0.0.1"` - Gateway only accessible from localhost
- `require_pairing = true` - Even local access requires pairing
- `allow_public_bind = false` - Cannot bind to public interfaces

Only configured **channels** can interact with the agent.

---

## Environment Variables

### Core Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_API_KEY` | Generic API key (fallback for all providers) | - |
| `ZEROCLAW_PROVIDER` | Default provider name | - |
| `ZEROCLAW_MODEL` | Default model name | - |
| `ZEROCLAW_TEMPERATURE` | Temperature (0.0-2.0) | `0.7` |
| `ZEROCLAW_WORKSPACE` | Workspace directory path | `/zeroclaw-data/.zeroclaw/workspace` |
| `ZEROCLAW_CONFIG_DIR` | Config directory path | - |

### Provider Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `ZEROCLAW_PROVIDER` | Provider name | `openrouter`, `openai`, `anthropic`, `zai`, `ollama` |
| `ZEROCLAW_MODEL` | Model name | `openrouter/auto`, `gpt-4o`, `claude-sonnet-4` |
| `ZEROCLAW_MODEL_PROVIDER` | Alternative provider setting | `openrouter` |

### Provider-Specific API Keys

| Variable | Provider |
|----------|----------|
| `ZAI_API_KEY` | Z.AI |
| `OPENAI_API_KEY` | OpenAI |
| `ANTHROPIC_API_KEY` | Anthropic |
| `OPENROUTER_API_KEY` | OpenRouter |
| `GEMINI_API_KEY` | Google Gemini |
| `GLM_API_KEY` | GLM / Zhipu |
| `OLLAMA_API_KEY` | Ollama (for remote) |
| `GROQ_API_KEY` | Groq |
| `MISTRAL_API_KEY` | Mistral |
| `DEEPSEEK_API_KEY` | DeepSeek |
| `XAI_API_KEY` | X.AI / Grok |
| `TOGETHER_API_KEY` | Together AI |
| `FIREWORKS_API_KEY` | Fireworks AI |
| `PERPLEXITY_API_KEY` | Perplexity |
| `COHERE_API_KEY` | Cohere |

### Autonomy Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_AUTONOMY_LEVEL` | Autonomy level: `read_only`, `supervised`, `full` | `full` |
| `ZEROCLAW_WORKSPACE_ONLY` | Restrict filesystem to workspace only | `false` |
| `ZEROCLAW_BLOCK_HIGH_RISK` | Block high-risk commands | `false` |
| `ZEROCLAW_REQUIRE_PAIRING` | Require pairing for gateway access | `true` |
| `ZEROCLAW_ALLOW_PUBLIC_BIND` | Allow binding to 0.0.0.0 | `false` |

### Gateway Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_GATEWAY_PORT` | Gateway server port | `42617` |
| `ZEROCLAW_GATEWAY_HOST` | Gateway server host | `127.0.0.1` |
| `PORT` | Alternative port (Railway convention) | - |
| `HOST` | Alternative host (Railway convention) | - |

### Web Search Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_WEB_SEARCH_ENABLED` | Enable web search | - |
| `ZEROCLAW_WEB_SEARCH_PROVIDER` | Web search provider | - |
| `ZEROCLAW_BRAVE_API_KEY` | Brave Search API key | - |
| `ZEROCLAW_WEB_SEARCH_MAX_RESULTS` | Max search results (1-10) | - |
| `ZEROCLAW_WEB_SEARCH_TIMEOUT_SECS` | Search timeout in seconds | - |

### Skills Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_OPEN_SKILLS_ENABLED` | Enable open skills (`true`/`false`) | `false` |
| `ZEROCLAW_OPEN_SKILLS_DIR` | Open skills directory | - |
| `ZEROCLAW_SKILLS_PROMPT_MODE` | Skills prompt mode (`full`/`compact`) | `full` |

### Runtime Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_REASONING_ENABLED` | Enable reasoning mode | - |

### Git/GitHub Configuration

| Variable | Description |
|----------|-------------|
| `GITHUB_TOKEN` | GitHub personal access token for authenticated clone |
| `GH_TOKEN` | GitHub CLI token |
| `GIT_AUTHOR_NAME` | Git author name |
| `GIT_AUTHOR_EMAIL` | Git author email |
| `GIT_COMMITTER_NAME` | Git committer name |
| `GIT_COMMITTER_EMAIL` | Git committer email |
| `ZEROCLAW_GIT_REPOS` | Comma-separated list of repos to clone at startup |

**ZEROCLAW_GIT_REPOS formats:**
- `owner/repo` — Short format (expanded to GitHub URL)
- `https://github.com/owner/repo.git` — Full URL
- `owner/repo,another/repo` — Multiple repos

Uses `GITHUB_TOKEN` or `GH_TOKEN` for authenticated cloning if available. Clones into workspace directory with `--depth 1`.

### SOUL.md/AGENTS.md Generation

Dynamic agent context generation from repository analysis. These files provide task-specific context to agents at spawn time.

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_SOUL_GENERATE_DYNAMIC` | Generate SOUL.md from repo analysis | `false` |
| `ZEROCLAW_SOUL_DESCRIPTION_INPUT` | Base soul description template | - |
| `ZEROCLAW_SOUL_ANALYZE_DEPTH` | Max directory depth for analysis | `2` |
| `ZEROCLAW_SOUL_MAX_SIZE_KB` | Max SOUL.md size before truncation | `50` |
| `ZEROCLAW_AGENTS_GENERATE_DYNAMIC` | Generate AGENTS.md with role definitions | `false` |
| `ZEROCLAW_AGENTS_DESCRIPTION_INPUT` | Base agent description template | - |

**What gets generated in SOUL.md:**
- Repository structure overview (top-level files by type)
- Technology stack detection (Rust, Node.js, Python, Go, Docker, etc.)
- README summary (first 30 lines)
- Operating context (workspace path, autonomy level, git config)
- Agent instructions for task execution workflow

**Example configuration:**
```bash
ZEROCLAW_SOUL_GENERATE_DYNAMIC=true
ZEROCLAW_SOUL_DESCRIPTION_INPUT="You are an expert full-stack developer working on a SaaS application."
ZEROCLAW_SOUL_ANALYZE_DEPTH=3
ZEROCLAW_GIT_REPOS=owner/repo
```

---

## Channel Configuration

ZeroClaw supports **multiple communication channels**. Configure them via environment variables or in `config.toml`.

### Supported Channels

| Channel | Description | Config Key |
|---------|-------------|------------|
| **CLI** | Command-line interface (built-in) | `cli` |
| **Telegram** | Telegram bot | `telegram` |
| **Discord** | Discord bot | `discord` |
| **Slack** | Slack bot | `slack` |
| **Mattermost** | Self-hosted chat | `mattermost` |
| **Matrix** | Decentralized chat (matrix.org) | `matrix` |
| **WhatsApp** | Business Cloud API or Web mode | `whatsapp` |
| **Signal** | Encrypted messaging | `signal` |
| **Webhook** | HTTP endpoint | `webhook` |
| **iMessage** | macOS only | `imessage` |
| **Email** | SMTP email | `email` |
| **IRC** | IRC channels | `irc` |
| **Lark / Feishu** | ByteDance collaboration | `lark`, `feishu` |
| **DingTalk** | Alibaba collaboration | `dingtalk` |
| **QQ** | Tencent QQ | `qq` |
| **Nostr** | Decentralized protocol | `nostr` |
| **Linq** | Custom channel | `linq` |
| **Nextcloud Talk** | Self-hosted chat | `nextcloud_talk` |

### Telegram Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather | Yes |
| `TELEGRAM_ALLOWED_USERS` | JSON array of allowed users/IDs | No (default: `["*"]`) |

**Example config.toml:**
```toml
[channels_config]
cli = true

[channels_config.telegram]
bot_token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
allowed_users = ["*"]  # Or specific usernames/IDs
stream_mode = "partial"
mention_only = false
```

### Discord Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `DISCORD_BOT_TOKEN` | Bot token from Discord Developer Portal | Yes |
| `DISCORD_GUILD_ID` | Server ID to restrict bot | No |
| `DISCORD_ALLOWED_USERS` | JSON array of allowed user IDs | No |

**Example config.toml:**
```toml
[channels_config.discord]
bot_token = "your-discord-bot-token"
guild_id = "123456789012345678"
allowed_users = ["*"]
mention_only = false
listen_to_bots = false
```

### Slack Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `SLACK_BOT_TOKEN` | Bot OAuth token (xoxb-...) | Yes |
| `SLACK_APP_TOKEN` | App-level token for Socket Mode (xapp-...) | No |
| `SLACK_CHANNEL_ID` | Channel ID to restrict bot | No |

**Example config.toml:**
```toml
[channels_config.slack]
bot_token = "xoxb-your-bot-token"
app_token = "xapp-your-app-token"
channel_id = "C1234567890"
allowed_users = ["*"]
```

### Matrix Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `MATRIX_HOMESERVER` | Homeserver URL (e.g., `https://matrix.org`) | Yes |
| `MATRIX_ACCESS_TOKEN` | Access token for bot account | Yes |
| `MATRIX_ROOM_ID` | Room ID (e.g., `!abc123:matrix.org`) | Yes |
| `MATRIX_ALLOWED_USERS` | JSON array of allowed user IDs | No |

**Example config.toml:**
```toml
[channels_config.matrix]
homeserver = "https://matrix.org"
access_token = "your-access-token"
user_id = "@bot:matrix.org"
room_id = "!abc123:matrix.org"
allowed_users = ["@user:matrix.org"]
```

### WhatsApp Configuration

| Variable | Description | Mode |
|----------|-------------|------|
| `WHATSAPP_ACCESS_TOKEN` | Meta Business access token | Cloud API |
| `WHATSAPP_PHONE_NUMBER_ID` | Phone number ID from Meta | Cloud API |
| `WHATSAPP_VERIFY_TOKEN` | Webhook verify token | Cloud API |
| `WHATSAPP_APP_SECRET` | App secret (or `ZEROCLAW_WHATSAPP_APP_SECRET`) | Cloud API |
| `WHATSAPP_SESSION_PATH` | Session database path | Web mode |
| `WHATSAPP_ALLOWED_NUMBERS` | JSON array of allowed numbers | Both |

**Example config.toml (Cloud API):**
```toml
[channels_config.whatsapp]
access_token = "your-meta-access-token"
phone_number_id = "123456789012345"
verify_token = "your-verify-token"
app_secret = "your-app-secret"
allowed_numbers = ["+1234567890"]
```

### Webhook Configuration

| Variable | Description | Required |
|----------|-------------|----------|
| `WEBHOOK_PORT` | Port to listen on | Yes |
| `WEBHOOK_SECRET` | Secret for signature verification | No |

**Example config.toml:**
```toml
[channels_config.webhook]
port = 8080
secret = "your-webhook-secret"
```

---

## Allowed Commands

The agent can execute these commands:

| Category | Commands |
|----------|----------|
| **Git & GitHub** | `git`, `gh` |
| **Node.js** | `npm`, `node`, `npx`, `yarn`, `pnpm` |
| **Rust** | `cargo`, `rustc`, `rustup`, `rustfmt` |
| **Python** | `python3`, `pip3`, `pip`, `black` |
| **HTTP Clients** | `curl`, `wget`, `http`, `https` |
| **Database Clients** | `psql`, `mysql`, `redis-cli`, `sqlite3` |
| **Cloud & Secrets** | `aws`, `vault` |
| **Code Quality** | `eslint`, `prettier` |
| **Data Processing** | `jq`, `yq` |
| **System** | `ls`, `cat`, `grep`, `find`, `echo`, `pwd`, `wc`, `head`, `tail`, `date` |
| **File Ops** | `mkdir`, `mv`, `cp`, `touch`, `rm` |
| **Editors** | `vim`, `nano` |
| **Process Management** | `htop`, `ps`, `kill` |

---

## Included Packages

| Package | Description |
|---------|-------------|
| `git` | Version control |
| `gh` | GitHub CLI |
| `nodejs` / `npm` | Node.js runtime |
| `cargo` / `rustup` | Rust toolchain |
| `python3` / `pip3` | Python runtime |
| `httpie` | HTTP client (better than curl) |
| `postgresql-client` | PostgreSQL client |
| `mysql-client` | MySQL client |
| `redis-tools` | Redis client |
| `sqlite3` | SQLite client |
| `aws-cli` | AWS CLI v2 |
| `vault` | HashiCorp Vault CLI |
| `jq` | JSON processor |
| `yq` | YAML processor |
| `eslint` | JavaScript linter |
| `prettier` | Code formatter |
| `black` | Python formatter |
| `vim` / `nano` | Text editors |
| `htop` | System monitor |

---

## Usage

### Railway

1. Create a new service from this image: `ghcr.io/your-org/zeroclawrailway:latest`
2. Set the required environment variables
3. Deploy

### Local

```bash
docker build -t zeroclaw-railway .
docker run \
  -e ZEROCLAW_PROVIDER=zai \
  -e ZAI_API_KEY=your-key \
  -e TELEGRAM_BOT_TOKEN=your-token \
  -e GITHUB_TOKEN=your-github-pat \
  zeroclaw-railway
```

### Multi-Channel Example

```bash
docker run \
  -e ZEROCLAW_PROVIDER=openrouter \
  -e OPENROUTER_API_KEY=your-key \
  -e TELEGRAM_BOT_TOKEN=your-telegram-token \
  -e DISCORD_BOT_TOKEN=your-discord-token \
  -e SLACK_BOT_TOKEN=xoxb-your-slack-token \
  zeroclaw-railway
```

---

## ZeroClaw Native Documentation

For complete documentation of all ZeroClaw features, see the official docs:

### Official Documentation

- **ZeroClaw Repository**: [github.com/zeroclaw-labs/zeroclaw](https://github.com/zeroclaw-labs/zeroclaw)
- **Configuration Reference**: [docs/config-reference.md](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/config-reference.md)
- **Channels Reference**: [docs/channels-reference.md](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/channels-reference.md)
- **Providers Reference**: [docs/providers-reference.md](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/providers-reference.md)
- **Commands Reference**: [docs/commands-reference.md](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/commands-reference.md)
- **Troubleshooting**: [docs/troubleshooting.md](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/troubleshooting.md)

### Key Configuration Files

- **Environment Variables**: [docs/config-reference.md#environment-variables](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/config-reference.md#environment-variables)
- **Autonomy Settings**: [docs/config-reference.md#autonomy](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/config-reference.md#autonomy)
- **Channel Setup**: [docs/channels-reference.md](https://github.com/zeroclaw-labs/zeroclaw/blob/main/docs/channels-reference.md)

---

## Image Source

Based on [ghcr.io/zeroclaw-labs/zeroclaw:latest](https://github.com/zeroclaw-labs/zeroclaw)

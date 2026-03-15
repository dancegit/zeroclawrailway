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
| `ZEROCLAW_PROVIDER` | Provider name or custom endpoint | `custom:https://api.example.com/v1`, `openrouter`, `openai`, `anthropic`, `zai`, `ollama` |
| `ZEROCLAW_MODEL` | Model name | `glm-5`, `openrouter/auto`, `gpt-4o`, `claude-sonnet-4` |
| `ZEROCLAW_MODEL_PROVIDER` | Alternative provider setting | `openrouter` |

**Custom OpenAI-Compatible Endpoints:**

Use `custom:https://your-api.com/v1` format for OpenAI-compatible APIs:

```
ZEROCLAW_PROVIDER=custom:https://api.your-provider.com/v1
ZEROCLAW_MODEL=your-model
ZEROCLAW_API_KEY=your-api-key
```

**Note:** Setting `ZEROCLAW_PROVIDER=openai` with `OPENAI_BASE_URL` does NOT work - ZeroClaw ignores the base URL. Use `custom:https://...` instead.

### Provider-Specific API Keys

| Variable | Provider |
|----------|----------|
| `OPENCODE_API_KEY` | OpenCode (opencode-go) |
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

### Integration Configuration

ZeroClaw supports various integrations for productivity and information gathering.

#### Todoist Integration

| Variable | Description | Required |
|----------|-------------|----------|
| `TODOIST_API_TOKEN` | Todoist API token from Settings → Integrations | Yes |

**Get your token:** [Todoist Settings → Integrations → API Token](https://todoist.com/app/settings/integrations)

**CLI Commands:**
```bash
todoist-cli list              # List all tasks
todoist-cli list --today      # Today's tasks
todoist-cli list --overdue    # Overdue tasks
todoist-cli add "Buy groceries" --due "tomorrow"
todoist-cli add "Meeting" --project Work --priority 4
todoist-cli complete TASK_ID
todoist-cli projects          # List projects
todoist-cli today             # Today's tasks
todoist-cli briefing          # Daily briefing
```

#### Gmail/Google Calendar Integration

| Variable | Description | Required |
|----------|-------------|----------|
| `GMAIL_CLIENT_ID` | Google OAuth2 client ID | Yes |
| `GMAIL_CLIENT_SECRET` | Google OAuth2 client secret | Yes |
| `GMAIL_REFRESH_TOKEN` | OAuth2 refresh token | Yes |

**Setup Instructions:**

1. **Create Google OAuth2 Credentials:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Create a new project or select existing
   - Click "Create Credentials" → "OAuth client ID"
   - Select "Desktop app" as application type
   - Copy Client ID and Client Secret

2. **Enable APIs:**
   - Enable Gmail API: `https://console.cloud.google.com/apis/library/gmail.googleapis.com`
   - Enable Calendar API: `https://console.cloud.google.com/apis/library/calendar-json.googleapis.com`

3. **Generate Refresh Token:**
   
   Run the helper script locally (not in container):
   ```bash
   python3 scripts/google-oauth-helper.py \
     --client-id "YOUR_CLIENT_ID" \
     --client-secret "YOUR_CLIENT_SECRET" \
     --scopes all
   ```
   
   Visit the URL shown, authorize the app, and paste the code.
   The script outputs the `GMAIL_REFRESH_TOKEN`.

4. **Set in Railway:**
   ```bash
   railway variable set GMAIL_CLIENT_ID=xxx
   railway variable set GMAIL_CLIENT_SECRET=xxx
   railway variable set GMAIL_REFRESH_TOKEN=xxx
   ```

**Validate Token:**
```bash
google-oauth-helper --validate \
  --client-id "xxx" \
  --client-secret "xxx" \
  --refresh-token "xxx"
```
- Label management

#### IMAP/POP3 Email Support

| Variable | Description | Required |
|----------|-------------|----------|
| `IMAP_HOST` | IMAP server hostname | Yes |
| `IMAP_PORT` | IMAP server port (default: 993) | No |
| `IMAP_USER` | IMAP username | Yes |
| `IMAP_PASSWORD` | IMAP password | Yes |
| `SMTP_HOST` | SMTP server hostname | For sending |
| `SMTP_PORT` | SMTP server port (default: 587) | No |
| `SMTP_USER` | SMTP username | For sending |
| `SMTP_PASSWORD` | SMTP password | For sending |

**Features:**
- Email retrieval via IMAP
- Email sending via SMTP
- Multiple account support

#### Obsidian Integration

| Variable | Description | Default |
|----------|-------------|---------|
| `OBSIDIAN_VAULT_PATH` | Path to Obsidian vault | `$WORKSPACE/obsidian-vault` |

**CLI Commands:**
```bash
obsidian-helper list                    # List all notes
obsidian-helper list --tag project      # Notes by tag
obsidian-helper search "keyword"        # Search notes
obsidian-helper search "regex" --regex  # Regex search
obsidian-helper create "Notes/Meeting" --title "Meeting Notes"
obsidian-helper append "Notes/Meeting" "Follow up with John"
obsidian-helper daily                   # Create/append daily note
obsidian-helper tags                    # List all tags
obsidian-helper read "Notes/Meeting"    # Read note content
```

**Features:**
- Markdown note management
- Frontmatter parsing and creation
- Daily notes support
- Tag-based organization
- Full-text search

#### News Aggregation

| Variable | Description | Required |
|----------|-------------|----------|
| `TWITTER_BEARER_TOKEN` | Twitter/X API bearer token | No |
| `TWITTER_API_KEY` | Twitter/X API key | No |
| `TWITTER_API_SECRET` | Twitter/X API secret | No |
| `TWITTER_ACCESS_TOKEN` | Twitter/X access token | No |
| `TWITTER_ACCESS_SECRET` | Twitter/X access secret | No |
| `NEWS_API_KEY` | NewsAPI.org API key | No |
| `RSS_FEEDS` | Comma-separated list of RSS feed URLs | No |

**Features:**
- RSS feed parsing
- Twitter/X timeline access
- News aggregation and summarization

#### Text-to-Speech (Kokoro TTS)

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_KOKORO_ENABLED` | Enable Kokoro TTS integration | `false` |
| `ZEROCLAW_KOKORO_VOICE` | Default voice | `am_adam` |
| `ZEROCLAW_KOKORO_SPEED` | Speech speed (0.5-2.0) | `1.0` |
| `ZEROCLAW_KOKORO_LANG` | Language code | `en-us` |
| `ZEROCLAW_KOKORO_TIMEOUT` | TTS generation timeout (seconds) | `1200` |
| `ZEROCLAW_KOKORO_MODEL_DIR` | Model files directory | `$WORKSPACE/.kokoro-models` |
| `ZEROCLAW_KOKORO_OUTPUT_DIR` | Output directory for audio | `$WORKSPACE/tts-output` |

**Available Voices:**
- `am_adam` — Male, American English (recommended default)
- `bm_george` — Male, British English
- `af_sarah` — Female, American English
- `af_nicole` — Female, American English
- `af_sky` — Female, American English
- `bf_emma` — Female, British English

**Features:**
- Convert text to speech from TXT, EPUB, PDF files
- stdin support for piping text
- No API keys required — runs locally on CPU
- Model files (~50MB) downloaded on first use

**Timeout Configuration:**

For long texts, increase the timeout to prevent falling back to gTTS:
```bash
ZEROCLAW_KOKORO_TIMEOUT=120
```

If Kokoro TTS times out the the system falls back to gTTS (Google TTS) which uses a female voice. Increase the timeout to ensure the configured male voice is used. You: **Set `ZEROCLAW_KOKORO_TIMEOUT` on all zeroclaw services:
```bash
railway variable set ZEROCLAW_KOKORO_TIMEOUT=120 --service zeroclaw-personal-assistant
railway variable set ZEROCLAW_KOKORO_TIMEOUT=120 --service zeroclawrailway-improver
railway variable set ZEROCLAW_KOKORO_TIMEOUT=120 --service zeroclaw_general_dev_bot
```

**GPU Acceleration with Modal:**

For faster TTS generation (especially for long texts), use Modal GPU acceleration:

#### Modal.com GPU Acceleration (Optional)

Deploy a GPU-accelerated TTS endpoint on Modal for faster audio generation.

| Variable | Description | Required |
|----------|-------------|----------|
| `ZEROCLAW_MODAL_TTS_ENDPOINT` | Modal TTS endpoint URL | Yes (after deploying) |
| `ZEROCLAW_MODAL_TOKEN_ID` | Modal token ID (or `MODAL_TOKEN_ID`) | Yes |
| `ZEROCLAW_MODAL_TOKEN_SECRET` | Modal token secret (or `MODAL_TOKEN_SECRET`) | Yes |

**Setup:**
1. Create account at [modal.com](https://modal.com)
2. Deploy the TTS service: [modal-kokoro-tts](https://github.com/your-org/modal-kokoro-tts)
3. Copy the endpoint URL after deployment
4. Set `ZEROCLAW_MODAL_TTS_ENDPOINT` in Railway

**When to use Modal:**
- Large text-to-speech jobs (>10k characters)
- Faster processing needed (GPU vs CPU)
- Batch processing multiple files

**Cost:** Pay-per-second GPU usage (~$0.0002/sec for A10G)

### Runtime Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `ZEROCLAW_REASONING_ENABLED` | Enable reasoning mode | - |
| `ZEROCLAW_MAX_TOOL_ITERATIONS` | Maximum tool iterations before stopping | `200` |
| `ZEROCLAW_COMPACT_CONTEXT` | Context compaction (false for large models like glm-5) | `false` |
| `ZEROCLAW_MAX_HISTORY_MESSAGES` | Maximum history messages to retain | `200` |
| `ZEROCLAW_UBUNTU_INSTALL_EXTRA_PACKAGES` | Comma-separated list of extra Ubuntu packages to install at startup | - |

**ZEROCLAW_UBUNTU_INSTALL_EXTRA_PACKAGES examples:**
- Single package: `ffmpeg`
- Multiple packages: `ffmpeg,imagemagick,pandoc`
- With spaces (ignored): `ffmpeg, imagemagick, pandoc`

Packages are installed at container startup via `apt-get install -y --no-install-recommends`. Useful for adding tools like:
- `ffmpeg` — Audio/video processing
- `imagemagick` — Image manipulation
- `pandoc` — Document conversion
- `graphviz` — Diagram generation
- `texlive-latex-base` — LaTeX support

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

#### Full Git Operations Support

The agent can perform **all git operations** including network operations via the shell tool:

| Git Operation | Risk Level | Approval Required? |
|---------------|------------|-------------------|
| `git status`, `git log`, `git diff` | Low | No |
| `git fetch` | Low | No |
| `git pull` | Low | No |
| `git push` | Medium | No (pre-configured) |
| `git merge` | Medium | No (pre-configured) |
| `git rebase` | Medium | No (pre-configured) |
| `git commit`, `git add`, `git checkout` | Medium | No (pre-configured) |

**How it works:** The `require_approval_for_medium_risk = false` setting in the autonomy config allows the agent to execute medium-risk git commands without explicit approval. This is safe for Railway deployments where the agent is the only user.

**Example agent usage:**
```
User: Push the changes to main
Agent: [uses shell tool] git push origin main
```

**SSH Authentication:** For pushing to private repos, mount your SSH credentials:
```bash
docker run -v ~/.ssh:/zeroclaw-data/.ssh:ro ...
```

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
| `TELEGRAM_ALLOWED_USERS` | JSON array of allowed users/IDs | Yes (default: `[]` = no one) |

**Example config.toml:**
```toml
[channels_config]
cli = true

[channels_config.telegram]
bot_token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
allowed_users = ["your_username"]  # Required: set to specific usernames/IDs
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
allowed_users = ["your_discord_id"]
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
allowed_users = ["U1234567890"]
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
| **Todoist** | `todoist-cli` (list, add, complete, today, briefing) |
| **Obsidian** | `obsidian-helper` (search, list, create, daily, tags) |
| **Google OAuth** | `google-oauth-helper` (generate, validate) |
| **TTS** | `kokoro-tts` |
| **GPU** | `modal` |

---

## Integration Usage Examples

### Todoist Integration

```bash
# Environment setup
TODOIST_API_TOKEN=your-todoist-api-token

# Agent commands
User: "Add a task to buy groceries tomorrow"
User: "Show my tasks for today"
User: "Generate a daily briefing"
```

### Gmail Integration

```bash
# Environment setup
GMAIL_CLIENT_ID=your-client-id.apps.googleusercontent.com
GMAIL_CLIENT_SECRET=your-client-secret
GMAIL_REFRESH_TOKEN=your-refresh-token

# Agent commands
User: "Show unread emails from today"
User: "Search for emails about project X"
User: "Draft an email to john@example.com"
```

### IMAP Email

```bash
# Environment setup
IMAP_HOST=imap.gmail.com
IMAP_PORT=993
IMAP_USER=your-email@gmail.com
IMAP_PASSWORD=your-app-password
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587

# Agent commands
User: "Check for new emails"
User: "List emails from the last 24 hours"
```

### Obsidian Vault

```bash
# Environment setup
OBSIDIAN_VAULT_PATH=/zeroclaw-data/.zeroclaw/workspace/my-vault
OBSIDIAN_SYNC_ENABLED=true

# Agent commands
User: "Create a note titled 'Meeting Notes' with today's date"
User: "Search my vault for references to 'project alpha'"
User: "Append to my daily note"
```

### News Aggregation

```bash
# Environment setup
TWITTER_BEARER_TOKEN=your-twitter-bearer-token
NEWS_API_KEY=your-newsapi-key
RSS_FEEDS=https://feeds.bbci.co.uk/news/rss.xml,https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml

# Agent commands
User: "Summarize today's top tech news"
User: "Check my RSS feeds for updates"
User: "What's trending on Twitter?"
```

---

## Included Packages

### System Packages

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

### Python Integration Packages

| Package | Description |
|---------|-------------|
| `todoist-api-python` | Todoist API client |
| `google-api-python-client` | Google API client library |
| `google-auth-oauthlib` | Google OAuth2 authentication |
| `python-dateutil` | Date/time handling |
| `pytz` | Timezone support |
| `icalendar` | Calendar event parsing |
| `feedparser` | RSS/Atom feed parsing |
| `beautifulsoup4` | HTML/XML parsing |
| `lxml` / `html5lib` | HTML parsers |
| `requests-oauthlib` | OAuth for APIs |
| `tweepy` | Twitter/X API client |
| `schedule` | Job scheduling |
| `imapclient` | IMAP email client |
| `python-frontmatter` | Markdown frontmatter parsing |
| `markdown` | Markdown processing |
| `pyyaml` | YAML processing |
| `kokoro-tts` | Kokoro TTS engine (ONnx-based) |
| `modal` | Modal.com serverless GPU platform |

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

### Personal Assistant Example (with Integrations)

```bash
docker run \
  -e ZEROCLAW_PROVIDER=openrouter \
  -e OPENROUTER_API_KEY=your-key \
  -e TELEGRAM_BOT_TOKEN=your-telegram-token \
  -e TODOIST_API_TOKEN=your-todoist-token \
  -e GMAIL_CLIENT_ID=your-gmail-client-id \
  -e GMAIL_CLIENT_SECRET=your-gmail-client-secret \
  -e GMAIL_REFRESH_TOKEN=your-gmail-refresh-token \
  -e OBSIDIAN_VAULT_PATH=/zeroclaw-data/.zeroclaw/workspace/my-vault \
  -e RSS_FEEDS="https://feeds.bbci.co.uk/news/rss.xml,https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml" \
  -v /path/to/obsidian-vault:/zeroclaw-data/.zeroclaw/workspace/my-vault \
  zeroclaw-railway
```

### TTS-Enabled Example

```bash
docker run \
  -e ZEROCLAW_PROVIDER=openrouter \
  -e OPENROUTER_API_KEY=your-key \
  -e TELEGRAM_BOT_TOKEN=your-telegram-token \
  -e ZEROCLAW_KOKORO_ENABLED=true \
  -e ZEROCLAW_KOKORO_VOICE=af_sarah \
  -v ./tts-output:/zeroclaw-data/.zeroclaw/workspace/tts-output \
  zeroclaw-railway
```

### GPU-Accelerated TTS (with Modal)
```bash
docker run \
  -e ZEROCLAW_PROVIDER=openrouter \
  -e OPENROUTER_API_KEY=your-key \
  -e ZEROCLAW_KOKORO_ENABLED=true \
  -e ZEROCLAW_MODAL_ENABLED=true \
  -e ZEROCLAW_MODAL_TOKEN_ID=your-token-id \
  -e ZEROCLAW_MODAL_TOKEN_SECRET=your-token-secret \
  zeroclaw-railway
```

---

## State Persistence Architecture

ZeroClaw Railway services need to persist customizations across deployments. This section describes the architecture for external state storage.

### The Problem

- **Schedules, RSS feeds, preferences lost on redeployment** - Each new deployment starts fresh
- **Railway service IDs change** - Cannot rely on platform-specific IDs
- **Service names are stable** - `my-service-name` remains the same
- **Multi-platform support needed** - Railway, Fly.io, Render, etc.

### Solution: External State Store

```
┌─────────────────────────────────────────────────────────────────┐
│                    State Persistence Layer                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Service Identity: service_name + owner + platform              │
│  Key: "railway:your-org:your-service-name"                      │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   NeonDB     │  │   Redis      │  │   Git Repo   │           │
│  │ (PostgreSQL) │  │  (Hot State) │  │ (Config Ver) │           │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │
│         │                 │                 │                    │
│         └─────────────────┴─────────────────┘                   │
│                           │                                      │
│                    State Manager API                             │
│                           │                                      │
└───────────────────────────┼─────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
     ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
     │  service-1  │ │  service-2  │ │  service-3  │
     └─────────────┘ └─────────────┘ └─────────────┘
```

### State Categories

| Category | Storage | Examples | TTL |
|----------|---------|----------|-----|
| **Schedules** | NeonDB | Daily RSS, reminders, periodic tasks | Persistent |
| **Preferences** | NeonDB | User settings, feed URLs, channels | Persistent |
| **Runtime State** | Redis | Active schedules, cached data, sessions | 24h |
| **Configs** | Git Repo | Nix home.nix, skills, AGENTS.md | Versioned |
| **Generated Content** | S3/R2 | PDFs, audio files, images | 30 days |

### Service Identity

Services are identified by a composite key that remains stable across deployments:

```bash
# Identity components (set via environment variables)
ZEROCLAW_SERVICE_NAME=my-service       # Your service name
ZEROCLAW_SERVICE_OWNER=my-org          # Your org/username
ZEROCLAW_PLATFORM=railway              # Deployment platform

# Composite state key
STATE_KEY="${ZEROCLAW_PLATFORM}:${ZEROCLAW_SERVICE_OWNER}:${ZEROCLAW_SERVICE_NAME}"
# Example: "railway:my-org:my-service"
```

### Database Schema (NeonDB)

```sql
-- Service registry
CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_key VARCHAR(255) UNIQUE NOT NULL,
    service_name VARCHAR(255) NOT NULL,
    owner VARCHAR(255) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    last_deployment TIMESTAMP DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

-- Schedules (RSS feeds, reminders, periodic tasks)
CREATE TABLE schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_key VARCHAR(255) REFERENCES services(state_key) ON DELETE CASCADE,
    schedule_type VARCHAR(50) NOT NULL,    -- 'cron', 'interval', 'once'
    schedule_expr VARCHAR(100) NOT NULL,   -- '0 21:25 * * *', '3600s'
    task_type VARCHAR(100) NOT NULL,       -- 'rss_aggregate', 'reminder', 'custom'
    task_config JSONB NOT NULL,            -- Task-specific configuration
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    last_run TIMESTAMP,
    next_run TIMESTAMP,
    run_count INTEGER DEFAULT 0
);

-- User preferences
CREATE TABLE preferences (
    service_key VARCHAR(255) REFERENCES services(state_key) ON DELETE CASCADE,
    key VARCHAR(255) NOT NULL,
    value JSONB NOT NULL,
    updated_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (service_key, key)
);

-- RSS feed subscriptions
CREATE TABLE rss_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_key VARCHAR(255) REFERENCES services(state_key) ON DELETE CASCADE,
    feed_url VARCHAR(500) NOT NULL,
    feed_name VARCHAR(255),
    category VARCHAR(100),                 -- 'science', 'geopolitics', 'tech'
    enabled BOOLEAN DEFAULT true,
    last_fetched TIMESTAMP,
    etag VARCHAR(255),
    last_error TEXT,
    UNIQUE(service_key, feed_url)
);

-- Generated content metadata
CREATE TABLE generated_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_key VARCHAR(255) REFERENCES services(state_key) ON DELETE CASCADE,
    content_type VARCHAR(50) NOT NULL,     -- 'pdf', 'audio', 'image'
    storage_url VARCHAR(500) NOT NULL,     -- S3/R2 URL
    source_task VARCHAR(100),              -- 'rss_aggregate', 'tts'
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,
    metadata JSONB DEFAULT '{}'
);

-- Create indexes
CREATE INDEX idx_schedules_service ON schedules(service_key);
CREATE INDEX idx_schedules_next_run ON schedules(next_run) WHERE enabled = true;
CREATE INDEX idx_preferences_service ON preferences(service_key);
CREATE INDEX idx_rss_service ON rss_subscriptions(service_key);
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ZEROCLAW_STATE_STORE_ENABLED` | Enable state persistence | `true` |
| `ZEROCLAW_STATE_STORE_URL` | PostgreSQL connection URL | Yes |
| `ZEROCLAW_STATE_STORE_REDIS_URL` | Redis URL for hot state | Optional |
| `ZEROCLAW_SERVICE_NAME` | Unique service name | Yes |
| `ZEROCLAW_SERVICE_OWNER` | Owner/org identifier | Yes |
| `ZEROCLAW_PLATFORM` | Deployment platform | Yes |
| `ZEROCLAW_STATE_CONTENT_BUCKET` | S3/R2 bucket for generated content | Optional |

### State Manager API

The state manager is implemented as a Python module in `scripts/state_manager.py`:

```python
# Example usage in docker-entrypoint.sh or ZeroClaw skills

from state_manager import StateManager

# Initialize with environment variables
state = StateManager(
    service_name=os.environ.get("ZEROCLAW_SERVICE_NAME", "default-service"),
    owner=os.environ.get("ZEROCLAW_SERVICE_OWNER", "default-owner"),
    platform=os.environ.get("ZEROCLAW_PLATFORM", "railway")
)

# Save a schedule
state.save_schedule(
    schedule_type="cron",
    schedule_expr="0 21:25 * * *",
    task_type="rss_aggregate",
    task_config={
        "feeds": ["https://example.com/rss"],
        "channels": ["telegram"],
        "include_images": True,
        "format": "pdf"
    }
)

# Restore schedules on startup
schedules = state.get_schedules()
for sched in schedules:
    # Re-register with ZeroClaw's scheduler
    register_schedule(sched)

# Save preference
state.set_preference("default_voice", "af_sarah")
state.set_preference("rss_categories", ["science", "geopolitics"])

# Get preference
voice = state.get_preference("default_voice")

# Save generated content reference
state.save_content(
    content_type="pdf",
    storage_url="s3://bucket/reports/2026-03-10.pdf",
    source_task="rss_aggregate",
    expires_days=30
)
```

### State Restoration Flow

On container startup:

```
1. docker-entrypoint.sh runs
2. State Manager initializes with service identity
3. If STATE_STORE_ENABLED=true:
   a. Connect to NeonDB
   b. Register/update service in registry
   c. Restore schedules → re-register with ZeroClaw scheduler
   d. Restore preferences → set environment variables
   e. Restore RSS subscriptions → configure feed reader
4. Continue with normal startup
```

### Example: RSS Schedule Persistence

**User creates schedule:**
```
User: "Aggregate science news daily at 9:25 UTC and send to this channel"
```

**ZeroClaw:**
1. Creates schedule in memory
2. Calls `state.save_schedule()` to persist to NeonDB
3. Schedule survives redeployments

**On next deployment:**
1. `docker-entrypoint.sh` calls `state.get_schedules()`
2. Restores: "Aggregate science news daily at 9:25 UTC"
3. ZeroClaw continues sending daily reports

### Example: Nix Config Persistence

The `NIX_HOME_MANAGER_GITHUB_REPO` already provides config versioning:

```
1. User: "Install ripgrep and fd tools"
2. ZeroClaw updates home.nix in the git repo
3. Commits and pushes changes
4. Next deployment pulls updated config
5. Tools are automatically installed via home-manager
```

### Implementation Files

```
scripts/
├── state_manager.py          # Core state management API
├── state_schedules.py        # Schedule-specific operations
├── state_preferences.py      # Preference management
└── state_content.py          # Generated content tracking

skills/
├── state-persistence.md      # Skill documentation for ZeroClaw
└── rss-scheduling.md         # RSS-specific scheduling docs
```

### NeonDB Setup

1. Create a NeonDB project: https://neon.tech
2. Get connection string from dashboard
3. Set environment variable:
   ```bash
   ZEROCLAW_STATE_STORE_URL=postgresql://user:pass@ep-xxx.us-east-2.aws.neon.tech/zeroclaw_state?sslmode=require
   ```
4. Tables are auto-created on first run

### Cost Estimate (NeonDB Free Tier)

- **Free tier**: 0.5 GB storage, 100 hours compute/month
- **Estimated usage per service**: ~1MB storage, ~5 hours/month
- **Supports**: ~100 services on free tier

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

## Required API Keys & Placeholders Checklist

This section lists all environment variables that require user-specific values. Variables with placeholder values (`YOUR_*_HERE`) must be replaced before use.

### Core API Keys (Required)

| Variable | Placeholder | Where to Get |
|----------|-------------|--------------|
| `ZEROCLAW_API_KEY` | - | Your LLM provider API key |
| `OPENAI_API_KEY` | - | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| `ANTHROPIC_API_KEY` | - | [console.anthropic.com](https://console.anthropic.com/) |
| `OPENROUTER_API_KEY` | - | [openrouter.ai/keys](https://openrouter.ai/keys) |
| `ZAI_API_KEY` | - | Z.AI platform |

### Channel Configuration

| Variable | Placeholder | Where to Get |
|----------|-------------|--------------|
| `TELEGRAM_BOT_TOKEN` | - | [@BotFather](https://t.me/botfather) on Telegram |
| `DISCORD_BOT_TOKEN` | - | [Discord Developer Portal](https://discord.com/developers/applications) |
| `SLACK_BOT_TOKEN` | - | Slack App OAuth & Permissions |

### Integration API Keys

| Variable | Placeholder | Where to Get |
|----------|-------------|--------------|
| `TODOIST_API_TOKEN` | - | [Todoist Settings → Integrations](https://todoist.com/app/settings/integrations) |
| `GITHUB_TOKEN` | - | [GitHub Settings → Developer settings → PAT](https://github.com/settings/tokens) |

### Google Integration (Placeholders)

These variables have placeholder values that **must be replaced**:

| Variable | Current Placeholder | Setup Steps |
|----------|---------------------|-------------|
| `GMAIL_CLIENT_ID` | `YOUR_GMAIL_CLIENT_ID_HERE` | Create OAuth2 credentials in [Google Cloud Console](https://console.cloud.google.com/apis/credentials) |
| `GMAIL_CLIENT_SECRET` | `YOUR_GMAIL_CLIENT_SECRET_HERE` | From the same OAuth2 credentials |
| `GMAIL_REFRESH_TOKEN` | `YOUR_GMAIL_REFRESH_TOKEN_HERE` | Generate using `scripts/google-oauth-helper.py` |

**Quick Setup for Google:**
```bash
# 1. Create OAuth2 credentials (Desktop app type)
# 2. Enable Gmail API and Calendar API
# 3. Generate refresh token:
python3 scripts/google-oauth-helper.py \
  --client-id "YOUR_CLIENT_ID" \
  --client-secret "YOUR_CLIENT_SECRET" \
  --scopes all

# 4. Set in Railway:
railway variable set GMAIL_CLIENT_ID=xxx
railway variable set GMAIL_CLIENT_SECRET=xxx
railway variable set GMAIL_REFRESH_TOKEN=xxx
```

### GPU Acceleration (Optional)

| Variable | Placeholder | Where to Get |
|----------|-------------|--------------|
| `ZEROCLAW_MODAL_TOKEN_ID` | - | [modal.com](https://modal.com) → Settings → Tokens |
| `ZEROCLAW_MODAL_TOKEN_SECRET` | - | Created with token ID |
| `ZEROCLAW_MODAL_TTS_ENDPOINT` | - | Deploy modal-kokoro-tts service first |

### Nix Home-Manager Skills

| Variable | Example | Description |
|----------|---------|-------------|
| `ZEROCLAW_ENABLED_NIX_SKILLS` | `ddg-search,weather,pdf` | Comma-separated list of skills to enable |
| `NIX_HOME_MANAGER_GITHUB_REPO` | `your-org/zeroclawrailway-nix-home-manager` | GitHub repo with home.nix config |

### Finding Placeholders in Your Environment

```bash
# Check for placeholder values in Railway
railway variable list --service YOUR_SERVICE -k | grep "YOUR_"

# Or use JSON output
railway variable list --service YOUR_SERVICE --json | jq 'to_entries[] | select(.value | contains("YOUR_"))'
```

---

## Image Source

Based on [ghcr.io/zeroclaw-labs/zeroclaw:latest](https://github.com/zeroclaw-labs/zeroclaw)
# Build trigger ter 10 mar 2026 10:24:51 WET


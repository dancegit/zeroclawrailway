#!/bin/sh
set -e

# Set HOME to our data directory so zeroclaw finds ~/.zeroclaw/config.toml
export HOME=/zeroclaw-data

mkdir -p /zeroclaw-data/.zeroclaw
mkdir -p /zeroclaw-data/.zeroclaw/workspace

# Gateway binds to localhost only - NOT exposed to internet
# Telegram channel works independently and doesn't need public gateway
REQUIRE_PAIRING="${ZEROCLAW_REQUIRE_PAIRING:-true}"
ALLOW_PUBLIC_BIND="${ZEROCLAW_ALLOW_PUBLIC_BIND:-false}"

# Set default allowed users if not provided (must be valid TOML array with quoted strings)
TELEGRAM_ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-[\"*\"]}"

# Autonomy level: "read_only", "supervised", or "full" (default: full for max autonomy)
AUTONOMY_LEVEL="${ZEROCLAW_AUTONOMY_LEVEL:-full}"

# Whether to restrict operations to workspace directory only
WORKSPACE_ONLY="${ZEROCLAW_WORKSPACE_ONLY:-false}"

# Whether to block high-risk commands (rm -rf, etc.)
BLOCK_HIGH_RISK="${ZEROCLAW_BLOCK_HIGH_RISK:-false}"

# Build config.toml - leave values empty to let env vars take precedence via apply_env_overrides()
cat > /zeroclaw-data/.zeroclaw/config.toml << EOF
# Provider config - env vars (ZEROCLAW_*) take precedence via apply_env_overrides()
api_key = ""
default_provider = ""
default_model = ""
default_temperature = 0.7

[memory]
backend = "sqlite"
auto_save = true

[gateway]
port = 42617
host = "127.0.0.1"
require_pairing = ${REQUIRE_PAIRING}
allow_public_bind = ${ALLOW_PUBLIC_BIND}

[autonomy]
level = "${AUTONOMY_LEVEL}"
workspace_only = ${WORKSPACE_ONLY}
max_actions_per_hour = 100
max_cost_per_day_cents = 1000
require_approval_for_medium_risk = false
block_high_risk_commands = ${BLOCK_HIGH_RISK}

allowed_commands = [
allowed_commands = [
    "git", "gh",
    "npm", "node", "npx", "yarn", "pnpm",
    "cargo", "rustc", "rustup", "rustfmt",
    "python3", "pip3", "pip", "black",
    "curl", "wget", "http", "https",
    "psql", "mysql", "redis-cli", "sqlite3",
    "aws", "vault",
    "eslint", "prettier",
    "jq", "yq",
    "ls", "cat", "grep", "find", "echo", "pwd", "wc", "head", "tail", "date",
    "mkdir", "mv", "cp", "touch", "rm",
    "vim", "nano",
    "htop", "ps", "kill"
]

forbidden_paths = []

shell_env_passthrough = [
    "GITHUB_TOKEN",
    "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL",
    "GIT_COMMITTER_NAME", 
    "GIT_COMMITTER_EMAIL",
    "GH_TOKEN"
]

allowed_roots = []

auto_approve = ["file_read", "memory_recall"]

always_ask = []

non_cli_excluded_tools = []
EOF

if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
cat >> /zeroclaw-data/.zeroclaw/config.toml << EOF

[channels_config]
cli = true

[channels_config.telegram]
bot_token = "${TELEGRAM_BOT_TOKEN}"
allowed_users = ${TELEGRAM_ALLOWED_USERS}
EOF
fi

chmod 600 /zeroclaw-data/.zeroclaw/config.toml

exec "$@"

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

# Autonomy level: "read_only", "supervised", or "full"
# supervised = acts but requires approval for risky operations (recommended)
# full = autonomous execution within policy bounds
AUTONOMY_LEVEL="${ZEROCLAW_AUTONOMY_LEVEL:-supervised}"

# Whether to restrict operations to workspace directory only
WORKSPACE_ONLY="${ZEROCLAW_WORKSPACE_ONLY:-false}"

# Whether to block high-risk commands (rm -rf, etc.)
BLOCK_HIGH_RISK="${ZEROCLAW_BLOCK_HIGH_RISK:-false}"

# Provider configuration - use ZEROCLAW_* env vars which take precedence
# These can be overridden at runtime via Railway variables
# ZeroClaw's apply_env_overrides() will use these env vars if config.toml values are empty

# Build config.toml - leave values empty to let env vars take precedence via apply_env_overrides()
cat > /zeroclaw-data/.zeroclaw/config.toml << EOF
# Provider config - env vars (ZEROCLAW_*) take precedence via apply_env_overrides()
# Set these in Railway: ZEROCLAW_API_KEY, ZEROCLAW_PROVIDER, ZEROCLAW_MODEL
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
block_high_risk_commands = ${BLOCK_HIGH_RISK}
max_actions_per_hour = 100

allowed_commands = [
    "git", "gh", "npm", "node", "npx", "yarn", "pnpm",
    "cargo", "rustc", "rustup",
    "python3", "pip3", "pip",
    "ls", "cat", "grep", "find", "echo", "pwd", "wc", "head", "tail", "date",
    "mkdir", "mv", "cp", "touch", "rm",
    "curl", "wget",
    "vim", "nano"
]

shell_env_passthrough = [
    "GITHUB_TOKEN",
    "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL",
    "GIT_COMMITTER_NAME", 
    "GIT_COMMITTER_EMAIL",
    "GH_TOKEN"
]
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

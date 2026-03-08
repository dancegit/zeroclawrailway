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

cat > /zeroclaw-data/.zeroclaw/config.toml << EOF
api_key = "${ZAI_API_KEY:-}"
default_provider = "${DEFAULT_PROVIDER:-zai}"
default_model = "${ZEROCLAW_MODEL:-glm-5}"
default_temperature = 0.7

[memory]
backend = "sqlite"
auto_save = true

[gateway]
port = 42617
host = "127.0.0.1"
require_pairing = ${ZEROCLAW_REQUIRE_PAIRING:-true}
allow_public_bind = ${ZEROCLAW_ALLOW_PUBLIC_BIND:-false}
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

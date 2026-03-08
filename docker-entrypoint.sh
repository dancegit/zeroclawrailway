#!/bin/sh
set -e

mkdir -p /zeroclaw-data/.zeroclaw

cat > /zeroclaw-data/.zeroclaw/config.toml << EOF
api_key = "${ZAI_API_KEY:-}"
default_provider = "${DEFAULT_PROVIDER:-zai}"
default_model = "${ZEROCLAW_MODEL:-glm-5}"

[memory]
backend = "sqlite"
auto_save = true

[gateway]
port = 42617
host = "0.0.0.0"
require_pairing = false
allow_public_bind = true
EOF

if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
cat >> /zeroclaw-data/.zeroclaw/config.toml << EOF

[channels_config.telegram]
bot_token = "${TELEGRAM_BOT_TOKEN}"
allowed_users = ${TELEGRAM_ALLOWED_USERS:-["*"]}
EOF
fi

chmod 600 /zeroclaw-data/.zeroclaw/config.toml

exec "$@"

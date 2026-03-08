FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies + development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Base system
    ca-certificates \
    curl \
    wget \
    git \
    gnupg \
    lsb-release \
    # Editors & monitoring
    vim \
    nano \
    htop \
    # Archive utilities
    xz-utils \
    unzip \
    # Process management
    procps \
    # Network tools
    netcat-openbsd \
    dnsutils \
    # HTTP client (better than curl for APIs)
    httpie \
    # GitHub CLI
    gh \
    # Database clients
    postgresql-client \
    mysql-client \
    redis-tools \
    # SQLite (useful for debugging)
    sqlite3 \
    # Python (for pip, black, etc.)
    python3 \
    python3-pip \
    python3-venv \
    # Node.js (for npm, eslint, prettier)
    nodejs \
    npm \
    # Build essentials (for compiling native modules)
    build-essential \
    # jq for JSON processing
    jq \
    # yq for YAML processing
    yq \
    && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain (cargo + rustfmt + clippy)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
ENV PATH="/root/.cargo/bin:${PATH}"

# Install global npm packages for code quality
RUN npm install -g \
    eslint \
    prettier \
    typescript \
    ts-node \
    pnpm \
    yarn

# Install Python packages for code quality
RUN pip3 install --break-system-packages \
    black \
    ruff \
    mypy \
    httpie \
    requests

# Install AWS CLI v2
RUN curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip && \
    unzip /tmp/awscli.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscli.zip

# Install Vault CLI
RUN curl -sL https://releases.hashicorp.com/vault/1.18.0/vault_1.18.0_linux_amd64.zip -o /tmp/vault.zip && \
    unzip /tmp/vault.zip -d /usr/local/bin && \
    rm /tmp/vault.zip && \
    chmod +x /usr/local/bin/vault

# Verify installations
RUN echo "=== Verifying installations ===" && \
    git --version && \
    node --version && \
    npm --version && \
    cargo --version && \
    rustfmt --version && \
    gh --version | head -1 && \
    http --version && \
    psql --version && \
    mysql --version && \
    redis-cli --version && \
    aws --version && \
    vault --version && \
    jq --version && \
    yq --version && \
    python3 --version && \
    pip3 --version && \
    eslint --version && \
    prettier --version && \
    black --version && \
    echo "=== All tools installed successfully ==="

# Download and install ZeroClaw
ADD https://github.com/zeroclaw-labs/zeroclaw/releases/download/v0.1.7/zeroclaw-x86_64-unknown-linux-gnu.tar.gz /tmp/zeroclaw.tar.gz

RUN tar xzf /tmp/zeroclaw.tar.gz -C /usr/local/bin zeroclaw && \
    rm /tmp/zeroclaw.tar.gz && \
    chmod +x /usr/local/bin/zeroclaw

# Copy and setup entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV HOME=/zeroclaw-data

WORKDIR /zeroclaw-data

EXPOSE 42617

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["zeroclaw", "daemon"]

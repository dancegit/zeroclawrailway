FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    gnupg \
    lsb-release \
    vim \
    nano \
    htop \
    xz-utils \
    unzip \
    procps \
    netcat-openbsd \
    dnsutils \
    httpie \
    gh \
    postgresql-client \
    mysql-client \
    redis-tools \
    sqlite3 \
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    build-essential \
    jq \
    yq \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/go/bin:/root/go/bin:/root/.cargo/bin:${PATH}"

RUN curl -sL https://go.dev/dl/go1.23.4.linux-amd64.tar.gz | tar -C /usr/local -xzf -

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default

RUN curl -sL https://github.com/ast-grep/ast-grep/releases/latest/download/app-x86_64-unknown-linux-gnu.zip -o /tmp/sg.zip && \
    unzip /tmp/sg.zip -d /tmp/sg && \
    mv /tmp/sg/sg /usr/local/bin/sg && \
    chmod +x /usr/local/bin/sg && \
    rm -rf /tmp/sg /tmp/sg.zip

RUN npm install -g \
    eslint \
    prettier \
    typescript \
    ts-node \
    pnpm \
    yarn \
    jest \
    vitest \
    tsx

RUN pip3 install --break-system-packages \
    black \
    ruff \
    mypy \
    httpie \
    requests \
    poetry \
    pytest \
    pytest-asyncio

RUN curl -sL https://github.com/mongodb-js/mongosh/releases/latest/download/mongosh-2.3.7-linux-x64.tgz | tar -C /usr/local/bin -xzf - mongosh

RUN curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip && \
    unzip /tmp/awscli.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscli.zip

RUN curl -sL https://releases.hashicorp.com/vault/1.18.0/vault_1.18.0_linux_amd64.zip -o /tmp/vault.zip && \
    unzip /tmp/vault.zip -d /usr/local/bin && \
    rm /tmp/vault.zip && \
    chmod +x /usr/local/bin/vault

RUN curl -sL https://github.com/Orange-OpenSource/hurl/releases/latest/download/hurl_5.0.1_amd64.deb -o /tmp/hurl.deb && \
    apt-get install -y /tmp/hurl.deb && \
    rm /tmp/hurl.deb

RUN curl -sL https://github.com/tstack/lnav/releases/latest/download/lnav-0.12.0-linux.x86_64.tar.gz | tar -C /usr/local -xzf - && \
    ln -sf /usr/local/lnav-0.12.0/lnav /usr/local/bin/lnav

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

RUN echo "=== Verifying installations ===" && \
    git --version && \
    go version && \
    node --version && \
    npm --version && \
    cargo --version && \
    rustfmt --version && \
    gh --version | head -1 && \
    http --version && \
    hurl --version | head -1 && \
    psql --version && \
    mysql --version && \
    redis-cli --version && \
    mongosh --version | head -1 && \
    aws --version | head -1 && \
    vault --version | head -1 && \
    sg --version | head -1 && \
    jq --version && \
    yq --version | head -1 && \
    python3 --version && \
    pip3 --version && \
    poetry --version | head -1 && \
    pytest --version | head -1 && \
    eslint --version | head -1 && \
    prettier --version | head -1 && \
    black --version | head -1 && \
    lnav --version | head -1 && \
    docker --version | head -1 && \
    echo "=== All tools installed successfully ==="

ADD https://github.com/zeroclaw-labs/zeroclaw/releases/download/v0.1.7/zeroclaw-x86_64-unknown-linux-gnu.tar.gz /tmp/zeroclaw.tar.gz

RUN tar xzf /tmp/zeroclaw.tar.gz -C /usr/local/bin zeroclaw && \
    rm /tmp/zeroclaw.tar.gz && \
    chmod +x /usr/local/bin/zeroclaw

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV HOME=/zeroclaw-data

WORKDIR /zeroclaw-data

EXPOSE 42617

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["zeroclaw", "daemon"]

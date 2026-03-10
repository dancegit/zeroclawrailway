FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git gnupg lsb-release \
    vim nano htop xz-utils unzip procps \
    netcat-openbsd dnsutils httpie gh \
    postgresql-client mysql-client redis-tools sqlite3 \
    python3 python3-pip python3-venv nodejs npm build-essential jq yq \
    espeak-ng \
    && rm -rf /var/lib/apt/lists/*
ENV PATH="/usr/local/go/bin:/root/.cargo/bin:/root/.local/bin:/opt/venv/bin:${PATH}"
RUN curl -sL https://go.dev/dl/go1.23.4.linux-amd64.tar.gz | tar -C /usr/local -xzf -
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default
RUN curl -sL https://github.com/ast-grep/ast-grep/releases/latest/download/app-x86_64-unknown-linux-gnu.zip -o /tmp/sg.zip && \
    unzip /tmp/sg.zip -d /tmp/sg && mv /tmp/sg/sg /usr/local/bin/sg && chmod +x /usr/local/bin/sg && rm -rf /tmp/sg /tmp/sg.zip
RUN npm install -g eslint prettier typescript ts-node pnpm yarn jest vitest
RUN python3 -m venv /opt/venv && /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install black ruff mypy requests poetry pytest pytest-asyncio httpie \
    todoist-api-python \
    google-api-python-client google-auth-httplib2 google-auth-oauthlib \
    python-dateutil pytz icalendar \
    feedparser beautifulsoup4 requests-oauthlib tweepy \
    schedule \
    imapclient \
    python-frontmatter markdown pyyaml \
    lxml html5lib \
    kokoro-tts \
    modal
RUN apt-get update && apt-get install -y --no-install-recommends lnav && rm -rf /var/lib/apt/lists/*
RUN curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscli.zip && \
    unzip /tmp/awscli.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscli.zip
RUN curl -sL https://releases.hashicorp.com/vault/1.18.0/vault_1.18.0_linux_amd64.zip -o /tmp/vault.zip && \
    unzip /tmp/vault.zip -d /usr/local/bin && rm /tmp/vault.zip && chmod +x /usr/local/bin/vault
RUN echo "=== Verifying ===" && \
    git --version && node --version && go version && cargo --version && \
    gh --version | head -1 && http --version && \
    psql --version && mysql --version && redis-cli --version && \
    aws --version && vault --version && \
    jq --version && yq --version | head -1 && \
    python3 --version && eslint --version | head -1 && \
    echo "=== Done ==="

RUN mkdir -p /etc/nix && \
    echo "build-users-group =" > /etc/nix/nix.conf && \
    echo "sandbox = false" >> /etc/nix/nix.conf && \
    mkdir -m 0755 /nix && \
    curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes && \
    . /root/.nix-profile/etc/profile.d/nix.sh && \
    nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager && \
    nix-channel --update && \
    nix-shell '<home-manager>' -A install && \
    echo "Nix and home-manager installed"
ENV PATH="/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:${PATH}"
ADD https://github.com/zeroclaw-labs/zeroclaw/releases/download/v0.1.7/zeroclaw-x86_64-unknown-linux-gnu.tar.gz /tmp/zeroclaw.tar.gz
RUN tar xzf /tmp/zeroclaw.tar.gz -C /usr/local/bin zeroclaw && rm /tmp/zeroclaw.tar.gz && chmod +x /usr/local/bin/zeroclaw
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
COPY scripts/ /usr/local/bin/zeroclaw-scripts/
COPY skills/ /zeroclaw-skills/
RUN chmod +x /usr/local/bin/zeroclaw-scripts/*.py && \
    ln -s /usr/local/bin/zeroclaw-scripts/todoist-cli.py /usr/local/bin/todoist-cli && \
    ln -s /usr/local/bin/zeroclaw-scripts/google-oauth-helper.py /usr/local/bin/google-oauth-helper && \
    ln -s /usr/local/bin/zeroclaw-scripts/obsidian-helper.py /usr/local/bin/obsidian-helper
ENV HOME=/zeroclaw-data
WORKDIR /zeroclaw-data
EXPOSE 42617
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["zeroclaw", "daemon"]

FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    nodejs \
    npm \
    cargo \
    vim \
    htop \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN git --version && node --version && cargo --version

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

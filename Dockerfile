FROM alpine:3.20

RUN apk add --no-cache ca-certificates curl && \
    curl -fsSLO https://github.com/zeroclaw-labs/zeroclaw/releases/latest/download/zeroclaw-x86_64-unknown-linux-musl.tar.gz | tar xzf - -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/zeroclaw

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /zeroclaw-data

EXPOSE 42617

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["zeroclaw", "daemon"]

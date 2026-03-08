FROM alpine:3.20

RUN apk add --no-cache ca-certificates curl

ADD https://github.com/zeroclaw-labs/zeroclaw/releases/download/v0.1.0/zeroclaw-x86_64-unknown-linux-musl.tar.gz -O /tmp/zeroclaw.tar.gz
RUN tar xzf - /tmp/zeroclaw.tar.gz -C /usr/local/bin/zeroclaw && rm /tmp/zeroclaw.tar.gz

COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

WORKDIR /zeroclaw-data

EXPOSE 42617

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["zeroclaw", "daemon"]

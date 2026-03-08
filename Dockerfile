FROM ghcr.io/zeroclaw-labs/zeroclaw:latest

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /zeroclaw-data

EXPOSE 42617

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["zeroclaw", "daemon"]

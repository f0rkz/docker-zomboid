FROM ghcr.io/f0rkz/docker-steamcmd:v1.1.3
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT /entrypoint.sh

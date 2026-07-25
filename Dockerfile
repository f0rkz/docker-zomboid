# syntax=docker/dockerfile:1

ARG STEAMCMD_IMAGE=ghcr.io/f0rkz/docker-steamcmd:2
FROM ${STEAMCMD_IMAGE}

LABEL org.opencontainers.image.title="Project Zomboid Dedicated Server" \
      org.opencontainers.image.description="Project Zomboid dedicated server powered by SteamCMD" \
      org.opencontainers.image.source="https://github.com/f0rkz/docker-zomboid" \
      org.opencontainers.image.licenses="MIT"

COPY --chown=steam:steam entrypoint.sh /usr/local/bin/zomboid-entrypoint

EXPOSE 16261/udp 16262/udp

VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/zomboid-entrypoint"]

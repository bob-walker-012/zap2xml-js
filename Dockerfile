# Multi-stage: build the TypeScript, ship only node + dist.
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY tsconfig.json rollup.config.ts ./
COPY src ./src
RUN npm run build

FROM node:22-alpine

LABEL org.opencontainers.image.title="zap2xml-js" \
      org.opencontainers.image.description="Container build of jef/zap2xml (MIT): same XMLTV output, Unraid-friendly (PUID/PGID, /data volume, status.json)" \
      org.opencontainers.image.source="https://github.com/bob-walker-012/zap2xml-js" \
      org.opencontainers.image.licenses="MIT"

RUN apk add --no-cache su-exec tzdata

ENV OUTPUT_FILE=/data/xmltv.xml \
    LINEUP_ID=USA-lineupId-DEFAULT \
    POSTAL_CODE=30309 \
    COUNTRY=USA \
    TIMESPAN=6 \
    SLEEP_TIME=21600 \
    RUN_ONCE=false \
    PUID=99 \
    PGID=100 \
    UMASK=022 \
    TZ=America/New_York

WORKDIR /app
COPY --from=build /app/dist ./dist
COPY package.json ./
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh
RUN chmod 755 /entrypoint.sh /healthcheck.sh && mkdir -p /data

VOLUME ["/data"]
HEALTHCHECK --interval=5m --timeout=15s --start-period=15m --retries=3 CMD /healthcheck.sh
CMD ["/entrypoint.sh"]
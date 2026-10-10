ARG BUILD_FROM
FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG MATRIX_VERSION="MatriX.146.UN"

ENV TS_CONF_PATH="/data" \
    TS_TORR_DIR="/data/torrents"

RUN apk add --no-cache \
        ca-certificates \
        curl \
        jq \
        nginx \
        tzdata \
    && case "${BUILD_ARCH}" in \
        amd64)   ASSET_ARCH="amd64" ;; \
        aarch64) ASSET_ARCH="arm64" ;; \
        armv7)   ASSET_ARCH="arm7"  ;; \
        i386)    ASSET_ARCH="386"   ;; \
        *) echo "Unsupported architecture: ${BUILD_ARCH}"; exit 1 ;; \
    esac \
    && curl -fsSL -o /usr/bin/torrserver \
        "https://github.com/bylampa/Matrix/releases/download/${MATRIX_VERSION}/TorrServer-linux-${ASSET_ARCH}" \
    && chmod a+x /usr/bin/torrserver

COPY run.sh /run.sh
COPY nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /run/nginx
RUN chmod a+x /run.sh

VOLUME ["/data"]

CMD [ "/run.sh" ]


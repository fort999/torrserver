#!/usr/bin/with-contenv bashio
set -eo pipefail

bashio::log.info "Starting TorrServer MatriX initialization..."

# 8090 is occupied by the Ingress-aware nginx proxy.
TS_PORT=8091
TS_CONF_PATH="/data"
TS_TORR_DIR="/data/torrents"

mkdir -p "${TS_CONF_PATH}"
mkdir -p "${TS_TORR_DIR}"

FLAGS="--path ${TS_CONF_PATH} --torrentsdir ${TS_TORR_DIR} --port ${TS_PORT} --logpath /dev/stdout"

# HTTP Auth configuration
if bashio::config.true 'httpauth'; then
    bashio::log.info "HTTP Authentication is enabled"
    FLAGS="${FLAGS} --httpauth"
    ACCESS_DB="${TS_CONF_PATH}/accs.db"
    
    jq_args=(-n)
    for key in $(bashio::config 'logins|keys'); do
        USERNAME=$(bashio::config "logins[${key}].username")
        PASSWORD=$(bashio::config "logins[${key}].password")
        jq_args+=( --arg "${USERNAME}" "${PASSWORD}" )
        bashio::log.info "Configured user: ${USERNAME}"
    done
    
    jq "${jq_args[@]}" '$ARGS.named' > "${ACCESS_DB}"
else
    bashio::log.info "HTTP Authentication is disabled"
fi

# Proxy configuration
PROXY_MODE=$(bashio::config 'proxymode')
if [ "${PROXY_MODE}" != "disabled" ]; then
    PROXY_URL=$(bashio::config 'proxyurl')
    if [ -n "${PROXY_URL}" ]; then
        bashio::log.info "Proxy enabled: mode=${PROXY_MODE}"
        FLAGS="${FLAGS} --proxymode ${PROXY_MODE} --proxyurl ${PROXY_URL}"
    else
        bashio::log.warning "Proxy mode is set to '${PROXY_MODE}', but 'proxyurl' is empty. Ignoring proxy."
    fi
fi

# Web access log
if bashio::config.true 'weblog'; then
    FLAGS="${FLAGS} --weblogpath /dev/stdout"
fi

# Telegram bot token
if bashio::config.has_value 'tgtoken'; then
    TG_TOKEN=$(bashio::config 'tgtoken')
    if [ -n "${TG_TOKEN}" ]; then
        FLAGS="${FLAGS} --tg ${TG_TOKEN}"
    fi
fi

# Don't kill torrents on disconnect
if bashio::config.true 'dontkill'; then
    FLAGS="${FLAGS} --dontkill"
fi

# Read-only DB mode
if bashio::config.true 'rdb'; then
    FLAGS="${FLAGS} --rdb"
fi

# Memory allocator tuning for Go
export GODEBUG="madvdontneed=1"

bashio::log.info "TorrServer port: ${TS_PORT}"
bashio::log.info "Launching TorrServer MatriX..."

/usr/bin/torrserver ${FLAGS} &
TORRSERVER_PID=$!

nginx -g 'daemon off;' &
NGINX_PID=$!

cleanup() {
    kill "${TORRSERVER_PID}" "${NGINX_PID}" 2>/dev/null || true
}

trap cleanup TERM INT

wait -n "${TORRSERVER_PID}" "${NGINX_PID}"
STATUS=$?

cleanup
wait "${TORRSERVER_PID}" "${NGINX_PID}" 2>/dev/null || true
exit "${STATUS}"

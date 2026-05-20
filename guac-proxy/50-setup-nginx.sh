#!/bin/sh
set -e

to_bool() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

log() {
    echo "[guacweb-setup] $*"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        log "missing required command: $1"
        exit 1
    }
}

ensure_openssl() {
    if command -v openssl >/dev/null 2>&1; then
        return 0
    fi

    if command -v apk >/dev/null 2>&1; then
        log "openssl not found, attempting to install with apk"
        apk add --no-cache openssl >/dev/null 2>&1 || true
    fi

    command -v openssl >/dev/null 2>&1
}

validate_cert_files() {
    CERT_PATH="$1"
    KEY_PATH="$2"

    [ -s "$CERT_PATH" ] || {
        log "certificate file missing: $CERT_PATH"
        return 1
    }
    [ -s "$KEY_PATH" ] || {
        log "key file missing: $KEY_PATH"
        return 1
    }

    ensure_openssl || {
        log "openssl unavailable, skip deep cert validation"
        return 0
    }

    openssl x509 -in "$CERT_PATH" -noout >/dev/null 2>&1 || {
        log "certificate parse failed: $CERT_PATH"
        return 1
    }

    openssl pkey -in "$KEY_PATH" -noout >/dev/null 2>&1 || {
        log "key parse failed: $KEY_PATH"
        return 1
    }

    cert_pub="$(openssl x509 -in "$CERT_PATH" -pubkey -noout 2>/dev/null | openssl sha256)"
    key_pub="$(openssl pkey -in "$KEY_PATH" -pubout 2>/dev/null | openssl sha256)"

    [ "$cert_pub" = "$key_pub" ] || {
        log "certificate and key do not match"
        return 1
    }

    return 0
}

generate_self_signed_cert() {
    CERT_PATH="$1"
    KEY_PATH="$2"

    ensure_openssl || {
        log "openssl unavailable, cannot generate self-signed certificate"
        return 1
    }
    mkdir -p "$CERT_DIR"

    log "generating self-signed localhost certificate"
    if ! openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -keyout "$KEY_PATH" \
        -out "$CERT_PATH" \
        -days 3650 \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
        >/dev/null 2>&1; then
        log "openssl addext unsupported, retrying without SAN extension"
        openssl req \
            -x509 \
            -nodes \
            -newkey rsa:2048 \
            -keyout "$KEY_PATH" \
            -out "$CERT_PATH" \
            -days 3650 \
            -subj "/CN=localhost" \
            >/dev/null 2>&1
    fi
}

WEB_HTTPS_ENABLE="$(to_bool "${GUAC_WEB_HTTPS_ENABLE:-false}")"
API_HTTPS_ENABLE="$(to_bool "${LMS_API_HTTPS_ENABLE:-false}")"
WEB_VERIFY_CERT="$(to_bool "${GUAC_WEB_HTTPS_VERIFY_CERT:-false}")"
API_VERIFY_CERT="$(to_bool "${LMS_API_HTTPS_VERIFY_CERT:-${GUAC_WEB_HTTPS_VERIFY_CERT:-false}}")"
CERT_DIR="/etc/nginx/certs"
WEB_CERT_NAME="${GUAC_WEB_CERT_FILE:-localhost.crt}"
WEB_KEY_NAME="${GUAC_WEB_KEY_FILE:-localhost.key}"
API_CERT_NAME="${LMS_API_CERT_FILE:-${GUAC_WEB_CERT_FILE:-localhost.crt}}"
API_KEY_NAME="${LMS_API_KEY_FILE:-${GUAC_WEB_KEY_FILE:-localhost.key}}"
WEB_CERT_PATH="${CERT_DIR}/${WEB_CERT_NAME}"
WEB_KEY_PATH="${CERT_DIR}/${WEB_KEY_NAME}"
API_CERT_PATH="${CERT_DIR}/${API_CERT_NAME}"
API_KEY_PATH="${CERT_DIR}/${API_KEY_NAME}"
BRIDGE_PORT="${CLIPBOARD_BRIDGE_PORT:-18080}"
WEB_PORT="${GUAC_WEB_PORT:-8888}"

WEB_SSL_LISTEN_SUFFIX=""
WEB_SSL_BLOCK=""
API_SSL_LISTEN_SUFFIX=""
API_SSL_BLOCK=""

if [ "$WEB_HTTPS_ENABLE" = "true" ] || [ "$API_HTTPS_ENABLE" = "true" ]; then
    mkdir -p "$CERT_DIR"
fi

if [ "$WEB_HTTPS_ENABLE" = "true" ]; then
    if [ "$WEB_VERIFY_CERT" = "true" ]; then
        log "Guacamole web HTTPS enabled with strict certificate validation"
        validate_cert_files "$WEB_CERT_PATH" "$WEB_KEY_PATH" || exit 1
    else
        log "Guacamole web HTTPS enabled without strict certificate validation"
        if ! validate_cert_files "$WEB_CERT_PATH" "$WEB_KEY_PATH"; then
            generate_self_signed_cert "$WEB_CERT_PATH" "$WEB_KEY_PATH"
            validate_cert_files "$WEB_CERT_PATH" "$WEB_KEY_PATH" || exit 1
        fi
    fi

    WEB_SSL_BLOCK="
    ssl_certificate ${WEB_CERT_PATH};
    ssl_certificate_key ${WEB_KEY_PATH};
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;"
    WEB_SSL_LISTEN_SUFFIX=" ssl"
else
    log "Guacamole web HTTPS disabled, serving HTTP on ${WEB_PORT}"
fi

if [ "$API_HTTPS_ENABLE" = "true" ]; then
    if [ "$API_VERIFY_CERT" = "true" ]; then
        log "LM Studio API HTTPS enabled with strict certificate validation"
        validate_cert_files "$API_CERT_PATH" "$API_KEY_PATH" || exit 1
    else
        log "LM Studio API HTTPS enabled without strict certificate validation"
        if ! validate_cert_files "$API_CERT_PATH" "$API_KEY_PATH"; then
            generate_self_signed_cert "$API_CERT_PATH" "$API_KEY_PATH"
            validate_cert_files "$API_CERT_PATH" "$API_KEY_PATH" || exit 1
        fi
    fi

    API_SSL_BLOCK="
    ssl_certificate ${API_CERT_PATH};
    ssl_certificate_key ${API_KEY_PATH};
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;"
    API_SSL_LISTEN_SUFFIX=" ssl"
else
    log "LM Studio API HTTPS disabled, serving HTTP on 1234"
fi

cat > /etc/nginx/conf.d/default.conf <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen ${WEB_PORT}${WEB_SSL_LISTEN_SUFFIX};
    server_name _;${WEB_SSL_BLOCK}

    client_max_body_size 2m;

    location = /clipboard-bridge.js {
        root /usr/share/nginx/html;
        add_header Cache-Control "no-store" always;
    }

    location /__clipboard_bridge/ {
        proxy_pass http://lmstudio:${BRIDGE_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        add_header Cache-Control "no-store" always;
    }

    location /lm-api/ {
        proxy_pass http://lmstudio:1234/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600s;
    }

    location / {
        proxy_pass http://guacamole:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Accept-Encoding "";
        sub_filter_once on;
        sub_filter_types text/html application/xhtml+xml;
        sub_filter '</body>' '<script src="/clipboard-bridge.js?v=20260519simple3"></script></body>';
        sub_filter '</BODY>' '<script src="/clipboard-bridge.js?v=20260519simple3"></script></BODY>';
    }
}

server {
    listen 1234${API_SSL_LISTEN_SUFFIX};
    server_name _;${API_SSL_BLOCK}

    location / {
        proxy_pass http://lmstudio:1234;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600s;
    }
}
EOF

nginx -t >/dev/null 2>&1 || {
    log "nginx config test failed"
    nginx -t || true
    exit 1
}

log "nginx runtime config generated (web_https=${WEB_HTTPS_ENABLE}, api_https=${API_HTTPS_ENABLE}, web_cert=${WEB_CERT_PATH}, api_cert=${API_CERT_PATH})"

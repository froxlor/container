#!/bin/bash

set -e

SSL_CERT_DIR="${SSL_CERT_DIR:-/opt/froxlor/ssl}"
SSL_CERT="${SSL_CERT:-$SSL_CERT_DIR/stunnel.pem}"
SSL_KEY="${SSL_KEY:-$SSL_CERT_DIR/stunnel.pem}"
SSL_PORT="${SSL_PORT:-8443}"
HTTP_PORT="${HTTP_PORT:-8000}"

# Enable SSL termination when FROXLOR_OCTANE_HTTPS or FROXLOR_FORCE_HTTPS is true
if [ "${FROXLOR_OCTANE_HTTPS:-false}" = "true" ] || [ "${FROXLOR_FORCE_HTTPS:-false}" = "true" ]; then
    # Generate a self-signed certificate if none is provided.
    mkdir -p "$SSL_CERT_DIR"
    if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
        echo "No SSL certificate found, generating self-signed certificate..."
        openssl req -x509 -nodes -newkey rsa:4096 \
            -keyout "$SSL_KEY" \
            -out "$SSL_CERT" \
            -days 365 \
            -subj "/CN=froxlor/O=froxlor"
        echo "Self-signed certificate generated at $SSL_CERT"
    else
        echo "Using existing SSL certificate: $SSL_CERT"
    fi

    chmod 600 "$SSL_KEY"
    chmod 644 "$SSL_CERT"

    # stunnel configuration.
    STUNNEL_CONF="/etc/stunnel/froxlor.conf"
    mkdir -p /etc/stunnel

    cat > "$STUNNEL_CONF" <<EOF
; stunnel configuration for froxlor SSL termination
foreground = no
pid = /var/run/stunnel-froxlor.pid

[froxlor-https]
accept  = 0.0.0.0:${SSL_PORT}
connect = 127.0.0.1:${HTTP_PORT}
cert    = ${SSL_CERT}
key     = ${SSL_KEY}
EOF

    echo "Starting stunnel (HTTPS on port $SSL_PORT -> HTTP on port $HTTP_PORT)..."
    stunnel "$STUNNEL_CONF"

    export FROXLOR_FORCE_HTTPS=true
else
    echo "SSL termination disabled; serving froxlor over HTTP on port $HTTP_PORT."
    export FROXLOR_FORCE_HTTPS=false
fi

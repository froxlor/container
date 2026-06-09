#!/bin/bash
set -e

APP_DIR="${APP_DIR:-/var/www/html/froxlor}"
SSL_CERT_DIR="${SSL_CERT_DIR:-/etc/ssl/froxlor}"
SSL_CERT="${SSL_CERT:-$SSL_CERT_DIR/cert.pem}"
SSL_KEY="${SSL_KEY:-$SSL_CERT_DIR/key.pem}"
SSL_PORT="${SSL_PORT:-8443}"
HTTP_PORT="${HTTP_PORT:-8000}"

# Bootstrap froxlor if the project does not exist yet
if [ ! -f "$APP_DIR/composer.json" ]; then
    echo "Bootstrapping froxlor, please be patient..."
    composer create-project --no-interaction --quiet froxlor/froxlor:dev-develop "$APP_DIR"
fi

# Move existing .env file
if [ -f "$APP_DIR/.env" ]; then
    echo "Moved .env to .env.backup, we only use the docker environment."
    mv "$APP_DIR/.env" "$APP_DIR/.env.backup"
fi

# Generate a self-signed certificate if none is provided
mkdir -p "$SSL_CERT_DIR"
if [ ! -f "$SSL_CERT" ] || [ ! -f "$SSL_KEY" ]; then
    echo "No SSL certificate found – generating self-signed certificate..."
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

# stunnel configuration
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

# Ensure HTTPS in application
export FORCE_HTTPS=true

# Execute the command passed to the container
exec "$@"

#!/bin/bash
# SPDX-FileCopyrightText: 2026 the froxlor Team (see AUTHORS)
# SPDX-License-Identifier: LGPL-3.0-or-later WITH LicenseRef-froxlor-Extension-Package-Exception
#
# This file is part of the froxlor project.
#
# This library is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version, with the froxlor
# Extension Package Exception (see LICENSE-EXCEPTION).
#
# This library is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library. If not, see
# <https://www.gnu.org/licenses/>.

# Web server of the container: Caddy serves public/ and hands PHP to php-fpm (bin/run.sh starts
# both). Sourced by the entrypoint, writes the Caddyfile.

set -e

SSL_CERT_DIR="${SSL_CERT_DIR:-/opt/froxlor/ssl}"
SSL_CERT="${SSL_CERT:-$SSL_CERT_DIR/froxlor.pem}"
SSL_KEY="${SSL_KEY:-$SSL_CERT_DIR/froxlor.pem}"
SSL_PORT="${SSL_PORT:-8443}"
HTTP_PORT="${HTTP_PORT:-8000}"
CADDYFILE="${CADDYFILE:-/etc/caddy/Caddyfile}"

mkdir -p "$(dirname "$CADDYFILE")"

cat > "$CADDYFILE" <<EOF
{
    admin off
    auto_https off
}

(froxlor) {
    root * ${APP_DIR:-/var/www/html/froxlor}/public
    encode zstd gzip
    php_fastcgi 127.0.0.1:9000
    file_server
}

:${HTTP_PORT} {
    import froxlor
}
EOF

# HTTPS listener when FROXLOR_HTTPS is true (FROXLOR_OCTANE_HTTPS of older compose files and
# FROXLOR_FORCE_HTTPS switch it on as well)
if [ "${FROXLOR_HTTPS:-false}" = "true" ] || [ "${FROXLOR_OCTANE_HTTPS:-false}" = "true" ] || [ "${FROXLOR_FORCE_HTTPS:-false}" = "true" ]; then
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

    cat >> "$CADDYFILE" <<EOF

:${SSL_PORT} {
    tls ${SSL_CERT} ${SSL_KEY}
    import froxlor
}
EOF

    echo "HTTPS on port $SSL_PORT, HTTP on port $HTTP_PORT."
else
    echo "HTTPS disabled; serving froxlor over HTTP on port $HTTP_PORT."
fi

# The web server tells PHP the scheme of each request. https is only forced when asked for
# (TLS ends at a reverse proxy in front of the container).
export FROXLOR_FORCE_HTTPS="${FROXLOR_FORCE_HTTPS:-false}"

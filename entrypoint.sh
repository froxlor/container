#!/bin/bash

set -e

APP_DIR="${APP_DIR:-/var/www/html/froxlor}"

# Bootstrap froxlor if the project does not exist yet
if [ ! -f "$APP_DIR/composer.json" ]; then
    echo "Bootstrapping froxlor, please be patient..."
    composer create-project --no-interaction --quiet froxlor/froxlor:dev-main "$APP_DIR"
    echo "Bootstrap completed."
else
    echo "Existing froxlor found, skip initialization."
fi

# Change dir to app directory
cd "$APP_DIR"

# Include stunnel for SSL termination
source /opt/froxlor/bin/stunnel.sh

# Update .env to reflect the docker environment variables
source /opt/froxlor/bin/env.sh

# Execute the command passed to the container
exec "$@"

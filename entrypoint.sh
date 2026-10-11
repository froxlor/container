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

set -e

APP_DIR="${APP_DIR:-/var/www/html/froxlor}"

# Bootstrap froxlor if the project does not exist yet
if [ ! -f "$APP_DIR/composer.json" ]; then
    echo "Bootstrapping froxlor, please be patient..."
    COMPOSER=composer.json composer create-project --no-interaction --quiet froxlor/froxlor:dev-main "$APP_DIR"
    echo "Bootstrap completed."
else
    echo "Existing froxlor found, skip initialization."
fi

# Change dir to app directory
cd "$APP_DIR"

# composer (COMPOSER, see Dockerfile) and the package management work on composer.local.json, so
# composer.json stays as the skeleton ships it; the package management keeps it in sync afterwards
if [ ! -f composer.local.json ]; then
    if [ -f vendor/froxlor/packages/src/Support/LocalComposerFile.php ]; then
        php -r 'require "vendor/autoload.php"; (new Froxlor\Packages\Support\LocalComposerFile(getcwd()))->sync();'
    else
        cp composer.json composer.local.json
    fi
fi

# Include stunnel for SSL termination
source /opt/froxlor/bin/stunnel.sh

# Update .env to reflect the docker environment variables
source /opt/froxlor/bin/env.sh

# Execute the command passed to the container
exec "$@"

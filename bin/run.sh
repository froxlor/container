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

# Production processes of the froxlor container under supervisord, each restarted when it ends:
# the web server (Octane with Swoole), the queue workers (Horizon with Redis, otherwise queue:work
# for the default, the node-setup and the environment-jails queue) and the scheduler. Development uses "composer run serve".

set -e

cd "${APP_DIR:-/var/www/html/froxlor}"

# migrations and lifecycle hooks of the installed packages
php artisan froxlor:packages:sync --no-interaction || echo "froxlor: package sync failed, starting anyway" >&2

QUEUE="$(php -r 'require "vendor/autoload.php"; $app = require "bootstrap/app.php"; $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap(); echo config("queue.default");' 2>/dev/null || echo database)"
CONF=/tmp/froxlor-supervisord.conf

program() {
    cat <<CONF
[program:$1]
command=$2
directory=$(pwd)
autostart=true
autorestart=true
startretries=10
stopwaitsecs=${3:-60}
stopasgroup=true
killasgroup=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

CONF
}

{
    cat <<CONF
[supervisord]
nodaemon=true
logfile=/dev/null
logfile_maxbytes=0
pidfile=/tmp/froxlor-supervisord.pid

[unix_http_server]
file=/tmp/froxlor-supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///tmp/froxlor-supervisor.sock

CONF
    # a Swoole server left behind by a crashed "octane:start" keeps the port: ended before every start
    # (asked first, then killed with its workers)
    program octane "/opt/froxlor/bin/octane.sh"
    if [ "$QUEUE" = "redis" ]; then
        # waits for running jobs on stop (node setups up to 21 minutes, jail jobs up to 31)
        program horizon "php artisan horizon" 1900
    else
        program queue "php artisan queue:work --queue=default --tries=1 --timeout=3600 --sleep=3" 3700
        program node-setup "php artisan queue:work --queue=node-setup --tries=1 --timeout=1260 --sleep=3" 1300
        program environment-jails "php artisan queue:work environment-jails --queue=environment-jails --tries=3 --timeout=1860 --sleep=3" 1900
    fi
    program scheduler "php artisan schedule:work"
} > "$CONF"

exec supervisord -c "$CONF"

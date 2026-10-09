#!/bin/sh
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

# Starts Octane (Swoole) for supervisord. A server of a crashed earlier start still holds the port
# and Octane's state file: it is asked to stop, then killed with its workers.
if pgrep -f "[s]woole_http_server: master process" > /dev/null; then
    pkill -TERM -f "[s]woole_http_server: master process"
    for _ in 1 2 3 4 5; do
        pgrep -f "[s]woole_http_server" > /dev/null || break
        sleep 1
    done
    pkill -KILL -f "[s]woole_http_server" || true
fi
exec php artisan octane:start --server=swoole --host=0.0.0.0 --port=8000

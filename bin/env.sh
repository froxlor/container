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

echo "Update .env to reflect the docker environment variables..."

{
    [ -f .env.example ] && cat .env.example
    [ -f .env ] && cat .env
    printenv | grep '^FROXLOR_' | sed 's/^FROXLOR_//'
} | awk -F= '
    /^[A-Za-z_][A-Za-z0-9_]*=/ {
        key = $1
        val = substr($0, length(key) + 2)

        if (val ~ /[ \t]/ && substr(val, 1, 1) != "\"") {
            val = "\"" val "\""
        }

        if (!(key in seen)) {
            order[++n] = key
            seen[key] = 1
        }
        env[key] = key "=" val
    }

    END {
        for (i = 1; i <= n; i++) {
            print env[order[i]]
        }
    }
' > .env.tmp && mv .env.tmp .env

echo "Update completed."

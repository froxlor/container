#!/bin/bash

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

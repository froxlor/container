#!/bin/bash

set -e

echo "Update .env to reflect the docker environment variables..."

{
    [ -f .env.example ] && cat .env.example
    [ -f .env ] && cat .env
    printenv | grep '^FROXLOR_' | sed 's/^FROXLOR_//'
} | awk -F= '
    /^[A-Za-z_][A-Za-z0-9_]*=/ {
        env[$1] = $0
    }

    END {
        for (key in env) {
            print env[key]
        }
    }
' | sort > .env.tmp && mv .env.tmp .env

echo "Update completed."

#!/usr/bin/env bash
set -e

mkdir -p /twrp

if ! mountpoint -q /twrp; then
    mergerfs /tmp:/vscode:/workspaces /twrp \
        -o defaults,allow_other,use_ino,category.create=mfs
fi

exec "$@"

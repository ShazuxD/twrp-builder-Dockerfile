#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${ENABLE_SWAP,,}" == "y" ]]; then
	if swapon --show | grep -q "$SWAPFILE"; then
	    echo "Swap already enabled"
	    exit 0
	fi

	if [ ! -f "$SWAPFILE" ]; then
	    fallocate -l "$ENABLED_SWAP_SIZE" "$SWAPFILE"
	    chmod 600 "$SWAPFILE"
	fi

mkswap "$SWAPFILE"
swapon "$SWAPFILE"

fi

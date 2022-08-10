#!/usr/bin/env bash
if [ -z "$1" ]; then
    echo "Usage: $0 <network-code>"
    echo "Example: $0 kag-testnet"
    exit 1
fi

export NETWORK_CODE=${1,,} # kag-testnet, kag-mainnet, etc
docker-compose -f docker-compose.yaml --project-name $NETWORK_CODE down -v
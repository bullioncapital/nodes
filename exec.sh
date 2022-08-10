#!/usr/bin/env bash
NETWORK_CODE=${1,,}
SERVICE_NAME=${2,,}
if [ -z "$NETWORK_CODE" ] || [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <network_code> <service_name>"
    echo "       network_code   : kag-testnet|kau-testnet|kag-mainnet|kau-mainnet"
    echo "       service_name   : core|horizon|db"
    exit 1
fi

CONTAINER_NAME="${NETWORK_CODE}_${SERVICE_NAME}"
docker exec -it $CONTAINER_NAME bash
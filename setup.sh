#!/usr/bin/env bash
declare -A NETWORK_PASSPHRASES=(
    ["kau-mainnet"]="Kinesis Live"
    ["kag-mainnet"]="Kinesis KAG Live"
    ["kau-testnet"]="Kinesis UAT"
    ["kag-testnet"]="Kinesis KAG UAT"
)

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <NETWORK_CODE> <HORIZON_HTTP_PORT>"
    echo "   e.g $0 kag-testnet 8000"
    exit 1
fi

export NETWORK_CODE=${1,,}
export HORIZON_HTTP_PORT=${2:-8000}
export NETWORK_PASSPHRASE=${NETWORK_PASSPHRASES[$NETWORK_CODE]}

echo "============================================="
echo "NETWORK_CODE: ${NETWORK_CODE}"
echo "NETWORK_PASSPHRASE: ${NETWORK_PASSPHRASE}"
echo "HORIZON_HTTP_PORT: ${HORIZON_HTTP_PORT}"
echo "============================================="

docker-compose -f docker-compose.yml --project-name $NETWORK_CODE up -d

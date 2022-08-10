#!/usr/bin/env bash
cp /config/${NETWORK_CODE}_stellar-core.cfg /etc/stellar/stellar-core.cfg
sed -i "s|#DATABASE_URL|$DATABASE_URL|g" /etc/stellar/stellar-core.cfg

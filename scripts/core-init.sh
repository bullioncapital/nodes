#!/usr/bin/env bash
#################################################################################
# Update stellar-core.cfg DATABASE_URL from environment variable
#
cp /config/${NETWORK_CODE}_stellar-core.cfg /etc/stellar/stellar-core.cfg
sed -i "s|#DATABASE_URL|$DATABASE_URL|g" /etc/stellar/stellar-core.cfg

# Kinesis Blockchain Nodes

For simplicity, we are going to use `docker-compose` to orchestrate all components. If you want to deploy node to your production please consult with your system admin.

The following docker images are used:

- `postgres:13` is used for sotring both stellar-core and horizon data
- `abxit/kinesis-core:v17.4.0-kinesis.2` Stellar-core forked
- `abxit/kinesis-horizon:v2.8.3-kinesis.2` Horizon forked

There are a few things that you need to understand before we start:

- Kinesis launched two blockchain networks one backed by `GOLD (KAU)` another backed by `SILVER (KAG)`
- Each chain has it own testnet and mainnet therefore we've got **two testnets** and **two mainnets**
- You can always utilise Kinesis Horizon servers to interact with the underline blockchain network

Kinesis Blockchain Networks:

| Fiat Asset | Asset Code | Environment | Network Passphrase | Horizon Server                      |
| ---------- | ---------- | ----------- | ------------------ | ----------------------------------- |
| GOLD       | KAU        | Mainnet     | Kinesis Live       | https://kau-mainnet.kinesisgroup.io |
| SILVER     | KAG        | Mainnet     | Kinesis KAG Live   | https://kag-mainnet.kinesisgroup.io |
| GOLD       | TKAU       | Testnet     | Kinesis UAT        | https://kau-testnet.kinesisgroup.io |
| SILVER     | TKAG       | Testnet     | Kinesis KAG UAT    | https://kag-testnet.kinesisgroup.io |

If you're reading this we assume you want to setup your own node. Let go through the code structure:

## Ports

For sysadmin, here are list of known ports used by each service:

| Port  | Service      | Description                                                                  |
| ----- | ------------ | ---------------------------------------------------------------------------- |
| 5432  | postgresql   | database access port                                                         |
| 8000  | horizon      | main http port                                                               |
| 6060  | horizon      | admin port **must be blocked from public access**                            |
| 11625 | stellar-core | peer node port                                                               |
| 11626 | stellar-core | main http port **block all public access and allow connection from Horizon** |

## Bootstrap a Network

To bootstrap an environment simply type:

```bash
# NETWORK_CODE = [kag-testnet | kag-mainnet | kau-testnet | kau-mainnet]
./setup.sh <NETWORK_CODE> <HORIZON_HTTP_PORT>
```

This script will setup postgres, stellar-core & horizon service. However, both stellar-core and horizon service are started in standby mode.
This is intentional because you will need to perform ONE TIME catchup before both services are ready to serve.

```bash
# create stellar-core and horizon database
# AND run migration commands against each database
# !!IMPORTANT!! this script will wipe out stellar-core db each time it runs.
./db-init.sh <NETWORK_CODE>
```

If you want to stop the network use this script:

```bash
./stop.sh <NETWORK_CODE>
```

Before we move on there is another helper script which shorthand your docker command:

```bash
# SERVICE_NAME = core | horizon | db
./exec.sh <NETWORK_CODE> <SERVICE_NAME>
```

## Catching up

First, use the following resources to extract `LEDGER_MAX` published ledger number (`currentLedger`):

| Fiat Asset | Asset Code | Environment | History Archive State (HAS)                                                                                             |
| ---------- | ---------- | ----------- | ----------------------------------------------------------------------------------------------------------------------- |
| GOLD       | KAU        | Mainnet     | [.well-known/stellar-history.json](https://kau-mainnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |
| SILVER     | KAG        | Mainnet     | [.well-known/stellar-history.json](https://kag-mainnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |
| GOLD       | TKAU       | Testnet     | [.well-known/stellar-history.json](https://kau-testnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |
| SILVER     | TKAG       | Testnet     | [.well-known/stellar-history.json](https://kag-testnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |

Second, use `./exec.sh` script to drop into each service `bash` shell and run appropriate command.

Finally, use the following command to catchup/ingest Kinesis Blockchain ledgers.

| Component | Command                                                                                                     |
| --------- | ----------------------------------------------------------------------------------------------------------- |
| Core      | `stellar-core catchup 512/<LEDGER_MAX>`                                                                     |
| Horizon   | `horizon db reingest range <LEDGER_MIN> <LEDGER_MAX> --parallel-workers 4 --log-file horizon-ingestion.log` |

Usage:

- `<LEDGER_MAX>` should be the value of `currentLedger` extracted from the HAS
- `<LEDGER_MIN>` if you want to host full ledger use `2`, otherwise `512` should be sufficient

For `Horizon`, if you've got a super machine you can cut down ingestion time by bump up `--parallel-workers <NUMBER_CORE>`. However, if the `Horizon` crash in this stage use this command `horizon db detect-gaps` to detect ingestion gap. If gaps detected it will print out commands that you can copy/paste to backfill those missing ledger.

## Live

Use the following command to start each component in live mode.

| Component | Command                                 | Description                          |
| --------- | --------------------------------------- | ------------------------------------ |
| Core      | `stellar-core run --wait-for-consensus` |                                      |
| Horizon   | `horizon serve`                         | http://localhost:<HORIZON_HTTP_PORT> |

**Note:** On first run both components will enter pending state because it wait for the known peers to publish its' state to history archive (HAS) which ocurr every 5 minutes (or 64 ledgers).
Your `core` will be ready between `3-5 minutes` and your `horizon` will follow suite.

**!!!CAUTION!!!** If you want to expose your horizon server to public make sure you put it behind reverse proxy with proper SSL.

## Health Probe

For production, it is highly recommend that you detect your `horizon` server health. This guide doesn't do health probe because we start `stellar-core` and `horizon` in standby mode. However, probe script is provided [scripts/horizon-health-probe.sh](./scripts/horizon-health-probe.sh).

## Connect to Horizon Server

If you expose your horizon server through domain (`HTTPS`) then you can start connecting to your server simply replace the our official url with your own. However, if your server is deploy in private network and not serve behind `HTTPS` you'll need to adjust your client script like so:

```javascript
// npm i --save @abxit/js-kinesis-sdk
const { Server } = require("@abx/js-kinesis-sdk");

// Configure KinesisSdk to talk to the horizon instance
const server = new Server("http://localhost:<HORIZON_HTTP_PORT>", {
  allowHttp: true,
  v1: false,
});
```

ref. https://github.com/bullioncapital/js-kinesis-sdk/blob/main/docs/reference/Kinesis.md

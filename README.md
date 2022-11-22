# Kinesis Blockchain Node

For simplicity, we are going to use `docker-compose` to orchestrate all components. If you want to deploy node to your production please consult with your system admin.

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

If you're reading this we assume you want to setup your own node. Let's go through the code structure 

```bash
.
├── config              # stellar-core config files for each network
│   ├── kag-mainnet_stellar-core.cfg
│   ├── kag-testnet_stellar-core.cfg
│   ├── kau-mainnet_stellar-core.cfg
│   └── kau-testnet_stellar-core.cfg
├── db-init.sh
├── docker-compose.yml  # minimal setup to make stellar-core & horizon work
├── exec.sh             # docker exec shorthand script
├── README.md
├── scripts             # containers init/ helper scripts
│   ├── core-init.sh
│   └── horizon-health-probe.sh
├── setup.sh            
├── stop.sh
└── teardown.sh
```

### Services

Each network has three services running **db, core and horizon** in `docker-compose`. Following are the images of these services:

1. db      : `postgres:13` is used for storing both stellar-core and horizon data
2. core    : `abxit/kinesis-core:v17.4.0-kinesis.2` Stellar-core forked
3. horizon :`abxit/kinesis-horizon:v2.8.3-kinesis.2` Horizon forked


### Ports

For sysadmin, here are list of known ports used by each service:

| Port  | Service      | Description                                                                  |
| ----- | ------------ | ---------------------------------------------------------------------------- |
| 5432  | postgresql   | database access port                                                         |
| 8000  | horizon      | main http port                                                               |
| 6060  | horizon      | admin port **must be blocked from public access**                            |
| 11625 | stellar-core | peer node port                                                               |
| 11626 | stellar-core | main http port **block all public access and allow connection from Horizon** |

## Bootstrap a Network

To start a network, the following steps are executed through bash scripts:-
1. Starting the services 
2. Initializing databases and migrating commands for each database
3. Node catch-up to download the latest ledger
4. Going live 

`./exec.sh` is a common helper script which starts the container of the given SERVICE_NAME for the given NETWORK_CODE passed as parameters.

```bash
# NETWORK_CODE = kau-mainnet | kag-mainnet | kau-testnet | kag-testnet 
# SERVICE_NAME = core | horizon | db
./exec.sh <NETWORK_CODE> <SERVICE_NAME>
````
 following explains NETWORK_CODES 
| Fiat Asset | Asset Code | Environment | NETWORK_CODE  | 
| ---------- | ---------- | ----------- | --------------| 
| GOLD       | KAU        | Mainnet     | kau-mainnet   | 
| SILVER     | KAG        | Mainnet     | kag-mainnet   | 
| GOLD       | TKAU       | Testnet     | kau-testnet   | 
| SILVER     | TKAG       | Testnet     | kag-testnet   | 



### 1. Starting the services
To bootstrap each of the four environments , simply type:

```bash
# HORIZON_HTTP_PORT = unique horizon http port for the network
./setup.sh <NETWORK_CODE> <HORIZON_HTTP_PORT>
```

This script will setup postgres, stellar-core & horizon service. However, both stellar-core and horizon service are started in standby mode.
This is intentional because you will need to perform ONE TIME catchup before both services are ready to serve. 

### 2. Database Initialization
After setting up the network, run following:

```bash
# This script 
# 1. creates stellar-core and horizon database
# 2. run migration commands against each database 
# !!IMPORTANT!! this script will wipe out stellar-core db each time it runs.
./db-init.sh <NETWORK_CODE>
```

To verify if database is correctly initialised, run
````bash
./exec.sh <NETWORK_CODE> db
````
Inside the container run
````bash
psql -h localhost --username=postgres --command="\l" | grep <NETWORK_CODE>
````
This will give you the db of core and horizon for NETWORK_CODE if db has been created.


### 3. Catching up

Each network node needs to catchup to its respective LEDGER_MAX.

First, use the following HAS, (Historical Archive State), urls to extract `currentLedger` for the network. This value will be used as `LEDGER_MAX` in catchup commands.

| Fiat Asset | Asset Code | Environment | History Archive State (HAS)                                                                                             |
| ---------- | ---------- | ----------- | ----------------------------------------------------------------------------------------------------------------------- |
| GOLD       | KAU        | Mainnet     | [.well-known/stellar-history.json](https://kau-mainnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |
| SILVER     | KAG        | Mainnet     | [.well-known/stellar-history.json](https://kag-mainnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |
| GOLD       | TKAU       | Testnet     | [.well-known/stellar-history.json](https://kau-testnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |
| SILVER     | TKAG       | Testnet     | [.well-known/stellar-history.json](https://kag-testnet-arch-syd-node1.kinesisgroup.io/.well-known/stellar-history.json) |

Second, use `./exec.sh` script to drop into each service `bash` shell through $SERVICE_NAME

```bash
# SERVICE_NAME = core | horizon | db
./exec.sh <NETWORK_CODE> <SERVICE_NAME>
```

Run the following command to catchup/ingest Kinesis Blockchain ledgers inside the Core and Horizon services. 

| Service | Command                                             | 
| --------| --------------------------------------------------| 
| Core      | `stellar-core catchup <LEDGER_MAX>/512` ||                                          |
| Horizon   | `horizon db reingest range <LEDGER_MIN> <LEDGER_MAX> --parallel-workers 4 --log-file horizon-ingestion.log` |           


Usage:

- `<LEDGER_MAX>` should be the value of `currentLedger` extracted from the HAS. ie: "currentLedger": 16514687
- `<LEDGER_MIN>` if you want to host full ledger use `2`, otherwise substract `LEDGER_MAX` by `512` should be sufficient to get your horizon up and running.

```bash
# horizon data ingestion
LEDGER_MAX=10000
LEDGER_MIN=$$(LEDGER_MAX - 512))
horizon db reingest range $LEDGER_MIN $LEDGER_MAX ...
```

For `Horizon`, if you've got a super machine you can cut down ingestion time by bump up `--parallel-workers <NUMBER_CORE>`. However, if the `Horizon` server crashes at this stage then use the command `horizon db detect-gaps`, this will detect any ingestion gaps. If gaps are detected it will print out commands that you can copy/paste in order to backfill any missing ledgers.

Once the catchup is successful on **core**, the status reported in json format in logs
````bash
    "state" : "Joining SCP",
    "status" : [ "Catching up to ledger 512: Succeeded: catchup-seq" ]
  ````
On a successful catchup on **horizon**, the generated log file `horizon-ingestion.log` will have log indicating `successfully reingested range`

You can also check through db container by executing the below script:
````bash
./exec.sh <NETWORK_CODE> db
````
Once inside the db container, verify the kinesis-core ingested the ledgers with the below script:
````bash
# NETWORK_CODE = kau-mainnet | kag-mainnet | kau-testnet | kag-testnet 
psql -h localhost -U postgres -d <NETWORK_CODE>-core -c "select max(ledgerseq), count(ledgerseq) from ledgerheaders"
````

### 4. Live

Use the following command to start each component in live mode in the `./exec.sh` script.

| Service | Command                                 | Description                          |
| --------- | --------------------------------------- | ------------------------------------ |
| Core      | `stellar-core run --wait-for-consensus` |                                      |
| Horizon   | `horizon serve`                         | http://localhost:<HORIZON_HTTP_PORT> |

**Note:** On first run, both the components will enter pending state because they wait for the known peers to publish its' state to history archive (HAS), which occurs every 5 minutes (or 64 ledgers).
Your `core` will be ready between `3-5 minutes` and your `horizon` will follow suite.

When the **core** is live, the live logs will contain closing ledger entries with `Closed ledger:` and `Got consensus:` every 3-5 seconds.

The **horizon** is live at `http://localhost:<HORIZON_HTTP_PORT>` for the network.  Around every 64 ledgers, the `currentLedger`, in the History Archive (from HAS url), will be synced with `core_latest_ledger` from live horizon.

**!!!CAUTION!!!** If you want to expose your horizon server to the public make sure you put it behind reverse proxy with proper SSL security.

## Health Probe

For production, it is highly recommend that you detect your `horizon` server health. This guide doesn't do health probe because we start `stellar-core` and `horizon` in standby mode. However, the probe script is provided @ [scripts/horizon-health-probe.sh](./scripts/horizon-health-probe.sh).

## Connect to Horizon Server

If you expose your horizon server through the (`HTTPS`) domain then you can start connecting to your server simply by replacing our official url with your own. However, if your server is deployed in a private network and not served behind `HTTPS` security then you'll need to adjust your client script like so:

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


## Additional Info
If you want to stop the network use this script:

```bash
./stop.sh <NETWORK_CODE>
```

## Troubleshoot

In case if setting up the network gives you the following error: 
```bash
could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network
```

then uncomment the `networks` section of the `docker-compose.yaml` and provide a unique subnet mask to each of the four networks by replacing `NNN` with number `2+`.

```bash
networks:
  default:
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.NNN.0/24
````

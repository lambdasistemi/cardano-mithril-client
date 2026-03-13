# cardano-mithril-client

Haskell client library for downloading, verifying, and extracting UTxO
snapshots from [Mithril](https://mithril.network/) aggregators.

## Features

- Fetch snapshot metadata from Mithril aggregator API
- Download snapshots via HTTP with streaming progress
- Ed25519 verification of ancillary files (ledger state)
- Incremental CBOR extraction of UTxOs from ledger state
- MemPack to CBOR encoding conversion (matching chain sync format)
- CLI option parser for Mithril configuration

## Environment Variables

Each Cardano network has its own Mithril aggregator and verification keys.
Set the following environment variables for the network you want to bootstrap from.

Source: [Mithril Network Configurations](https://mithril.network/doc/manual/getting-started/network-configurations)

### Preprod

```bash
export MITHRIL_AGGREGATOR_ENDPOINT=https://aggregator.release-preprod.api.mithril.network/aggregator
export MITHRIL_GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/genesis.vkey)
export MITHRIL_ANCILLARY_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/ancillary.vkey)
```

### Preview

```bash
export MITHRIL_AGGREGATOR_ENDPOINT=https://aggregator.pre-release-preview.api.mithril.network/aggregator
export MITHRIL_GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preview/genesis.vkey)
export MITHRIL_ANCILLARY_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preview/ancillary.vkey)
```

### Mainnet

```bash
export MITHRIL_AGGREGATOR_ENDPOINT=https://aggregator.release-mainnet.api.mithril.network/aggregator
export MITHRIL_GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/genesis.vkey)
export MITHRIL_ANCILLARY_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/ancillary.vkey)
```

## How It Works

1. Download the latest Mithril snapshot for the target network
2. Verify the Ed25519 signature on the ancillary manifest
3. Incrementally extract UTxOs from the ledger state (CBOR streaming)
4. Convert MemPack format to CBOR (matching chain sync format)

## Configuration Options

| Option | Env Variable | Description |
|--------|-------------|-------------|
| `--mithril-bootstrap` | | Enable Mithril-based bootstrapping |
| `--mithril-bootstrap-only` | | Exit after bootstrap (don't start chain sync) |
| `--mithril-network` | | Network: `mainnet`, `preprod`, `preview` |
| `--mithril-aggregator-endpoint` | `MITHRIL_AGGREGATOR_ENDPOINT` | Aggregator URL |
| `--mithril-genesis-verification-key` | `MITHRIL_GENESIS_VERIFICATION_KEY` | Genesis verification key |
| `--mithril-ancillary-verification-key` | `MITHRIL_ANCILLARY_VERIFICATION_KEY` | Ed25519 ancillary verification key |
| `--mithril-client-path` | | Path to mithril-client binary (default: `mithril-client`) |
| `--mithril-download-dir` | | Directory for snapshot downloads |
| `--mithril-skip-ancillary-verification` | | Skip Ed25519 verification (not recommended) |

## Building

```bash
nix develop --quiet -c just build
```

## Testing

```bash
nix develop --quiet -c just unit
```

## License

Apache-2.0

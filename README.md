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

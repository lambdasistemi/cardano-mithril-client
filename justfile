# shellcheck shell=bash

set unstable := true

# List available recipes
default:
    @just --list

# Format all source files
format:
    #!/usr/bin/env bash
    set -euo pipefail
    for i in {1..3}; do
        fourmolu -i lib test
    done
    cabal-fmt -i *.cabal
    nixfmt *.nix nix/*.nix

# Check formatting (CI mode)
format-check:
    #!/usr/bin/env bash
    set -euo pipefail
    fourmolu -m check lib test
    cabal-fmt -c *.cabal

# Run hlint
hlint:
    #!/usr/bin/env bash
    hlint lib test

# Build all components
build:
    #!/usr/bin/env bash
    cabal build all -O0 -fdev --enable-tests

# Run unit tests
unit match="":
    #!/usr/bin/env bash
    if [[ '{{ match }}' == "" ]]; then
        cabal test unit-tests -O0 -fdev --test-show-details=direct
    else
        cabal test unit-tests -O0 -fdev \
            --test-show-details=direct \
            --test-option=--match \
            --test-option="{{ match }}"
    fi

# Full CI pipeline
ci:
    #!/usr/bin/env bash
    set -euo pipefail
    just build
    just unit "AncillaryVerifier"
    just format-check
    just hlint

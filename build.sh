#!/usr/bin/env bash
set -ue
export COMMIT=$(git rev-parse HEAD | cut -c 1-7)$(git diff-index --quiet HEAD || echo -dirty)
exec nix-build "$@"

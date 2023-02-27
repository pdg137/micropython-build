#!/usr/bin/env bash
set -ue
if [ -z "$POLOLU_VCS" ]; then
  export POLOLU_VCS="https://github.com/pololu/"
fi
export COMMIT=$(git rev-parse HEAD)
exec nix-build "$@"

#!/usr/bin/env bash
if [ -z "$POLOLU_VCS" ]; then
  export POLOLU_VCS="https://github.com/pololu/"
fi
set -ue
export COMMIT=$(git rev-parse HEAD)
exec nix-build "$@"

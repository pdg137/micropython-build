#!/usr/bin/env bash
if [ -z "$POLOLU_VCS" ]; then
  export POLOLU_VCS="https://github.com/pololu/"
fi
set -ue
export COMMIT=$(git rev-parse HEAD | cut -c 1-7)$(git diff-index --quiet HEAD || echo -dirty)
exec nix-build "$@"

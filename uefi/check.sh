#!/bin/sh
set -eu
: "${NELUA:?Set NELUA to the pinned compiler executable}"
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ "$(uname -m)" != x86_64 ]; then
  printf 'UEFI producer ABI fixture requires an x86-64 host.\n' >&2
  exit 1
fi
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT HUP INT TERM
"$NELUA" --cache-dir "$d" -L "$src/lib" -L "$src/../wire" "$src/test/protocol.nelua"

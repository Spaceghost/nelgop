#!/bin/sh
set -eu
: "${NELUA:?Set NELUA to the pinned compiler executable}"
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
case "$(uname -m)" in
  x86_64|aarch64) ;;
  *) printf 'UEFI fixture requires an x86-64 or AArch64 host.\n' >&2; exit 1 ;;
esac
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT HUP INT TERM
"$NELUA" --cache-dir "$d" -L "$src/lib" -L "$src/../wire" "$src/test/protocol.nelua"

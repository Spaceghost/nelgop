#!/bin/sh
set -eu
: "${NELUA:?Use the pinned Nelua compiler executable}"
: "${ZIG:?Use pinned Zig}"
out=${1:-nelgop-wire.wasm}
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT HUP INT TERM
export ZIG_GLOBAL_CACHE_DIR="$d/zig" ZIG_LOCAL_CACHE_DIR="$d/ziglocal"
"$NELUA" --cache-dir "$d/nelua" -r --cc "$ZIG cc" --target wasm32-freestanding -L "$src" \
  --print-code "$src/abi.nelua" > "$d/abi.wasm.c"
"$ZIG" cc -target wasm32-freestanding -std=c11 -Os -ffreestanding -fno-builtin -fno-stack-protector -nostdlib \
  -Wl,--no-entry -Wl,--export=nelgop_wire_header -Wl,--export=nelgop_wire_rgba -Wl,--export=__heap_base -Wl,--export-memory \
  "$d/abi.wasm.c" -o "$out"
node "$src/wasm-test.cjs" "$out"

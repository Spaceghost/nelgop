#!/bin/sh
set -eu
: "${NELUA:?Set NELUA to pinned compiler executable}"
: "${CC:=cc}"
src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT HUP INT TERM
"$NELUA" -r -L "$src" --print-code "$src/abi.nelua" > "$d/abi.c"
"$NELUA" -r -L "$src" --print-code "$src/abi.nelua" > "$d/repeat.c"
cmp "$d/abi.c" "$d/repeat.c"
set -- -std=c11 -Os -Wall -Wextra -Werror -ffreestanding -fno-builtin -fno-stack-protector
"$CC" "$@" -c "$d/abi.c" -o "$d/abi.o"
[ -z "$(nm -u "$d/abi.o")" ]
[ "$(nm -g --defined-only "$d/abi.o" | awk '{print $NF}' | sort)" = "$(printf 'nelgop_wire_header\nnelgop_wire_rgba\n')" ]
"$CC" "$@" -DGOP_HOSTED "$d/abi.c" "$src/host.c" -o "$d/host"
"$d/host"
printf 'Hosted C ABI and deterministic zero-import object: PASS\n'
if [ "$(uname -s -m)" = 'Linux x86_64' ]; then
  "$CC" "$@" -fno-pie -static -nostdlib -Wl,-e,_start "$d/abi.c" "$src/host.c" "$src/start_linux_x86_64.S" -o "$d/no-crt"
  [ -z "$(nm -u "$d/no-crt")" ]
  ! readelf -l "$d/no-crt" | grep -q INTERP
  ! readelf -d "$d/no-crt" | grep -Eq '\((NEEDED|INIT|INIT_ARRAY)\)'
  "$d/no-crt"
  printf 'Linux x86-64 C ABI, static no-CRT execution: PASS\n'
fi
if [ "${SANITIZE:-0}" = 1 ]; then
  "$CC" "$@" -DGOP_HOSTED -fsanitize=address,undefined -fno-omit-frame-pointer "$d/abi.c" "$src/host.c" -o "$d/san"
  ASAN_OPTIONS=detect_leaks=0 "$d/san"
  printf 'Hosted ASan/UBSan ABI: PASS\n'
fi
if [ -n "${ZIG:-}" ]; then
  ZIG_GLOBAL_CACHE_DIR="$d/zig" ZIG_LOCAL_CACHE_DIR="$d/ziglocal" \
    "$NELUA" --cache-dir "$d/nelua" -r --cc "$ZIG cc" --target wasm32-freestanding -L "$src" --print-code "$src/abi.nelua" > "$d/abi.wasm.c"
  ZIG_GLOBAL_CACHE_DIR="$d/zig" ZIG_LOCAL_CACHE_DIR="$d/ziglocal" \
    "$ZIG" cc -target wasm32-freestanding -std=c11 -Os -ffreestanding -fno-builtin -fno-stack-protector -nostdlib \
    -Wl,--no-entry -Wl,--export=nelgop_wire_header -Wl,--export=nelgop_wire_rgba -Wl,--export=__heap_base -Wl,--export-memory \
    "$d/abi.wasm.c" -o "$d/nelgop-wire.wasm"
  node "$src/wasm-test.cjs" "$d/nelgop-wire.wasm"
fi

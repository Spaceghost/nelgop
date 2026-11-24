# Neboot GOP serial capture decoder

This is a small allocation-free Nelua library. It decodes a bounded,
complete capture from a firmware sender into caller-provided RGBA bytes.
It does not implement transport, a graphics compositor, EFI boot, or GPU
acceleration. The transport should only collect captures the caller requests.

## Wire format v1

- Exact 24-byte ASCII header: `NEBOOT-GOP/1 wwww hhhh\r\n`. The two fields
  each contain exactly four lowercase hexadecimal digits. Width is 1..4096
  and height 1..2160; the Neboot browser consumer should constrain these
  to its configured 160 × 100 and 96,240 bytes.
- Exactly one row per image row, top down, each with `width * 6` lowercase
  hex digits, two per byte in RGB order, and binary CRLF. No extra bytes,
  prefixes or unframed serial data inside the frame.
- Exact 16-byte ASCII trailer `NEBOOT-GOP/END\r\n`. Only one entire
  frame is accepted by the decoder. Alpha is always set to 255.

The transport peeks at the exact 24-byte header using `wire.header` to
compute an expected capture length. It should enforce its own length and
timeouts. The decoder separately verifies all lengths, dimensions, row
delimiters, every digit, and the trailer before making any output writes.
An absent, short or damaged frame leaves the output unchanged. Buffers must
be valid and disjoint. Extra bytes in a larger output buffer are untouched.

## APIs and verification

Use `require 'gop_wire'` for the native Nelua `header` and `rgba` methods.
`abi.nelua` supplies C ABI entry points in `gop_wire.h`; allocation,
alignment, pointer lifetime and non-overlap remain caller responsibilities.

```sh
NELUA=/path/to/nelua ZIG=/path/to/zig CC=gcc SANITIZE=1 ./check.sh
NELUA=/path/to/nelua ZIG=/path/to/zig ./build-wasm.sh ./nelgop-wire.wasm
```

Tested with Nelua source at `d5be57955fe8551934db403e5faed3852536ab7a`,
GCC 14.2, Zig 0.15.2, and Node 24. Hosted ABI, sanitizers, deterministic
C and zero imports were verified. The no-CRT execution proof is specific
to Linux x86-64. The Wasm is freestanding (no imports or WASI), exports
`memory`, `__heap_base`, and the two C ABI functions. In wasm32, width,
height and frame length outputs are each little-endian 32-bit values.
Reserve a 16-byte metadata area from the aligned heap base; put source
and RGBA storage in disjoint following regions. Grow memory first if needed
and rebuild typed-array views after growing. Check both calls' return value
before using output. The wasm test checks all 64,000 output bytes for a
synthetic exact-size frame and a malformed-last-row case. It is not an
EFI/GOP capture witness; use separate device/browser evidence for that.

For a separately captured native QEMU witness, verify against its independent
full-resolution HMP P6 screenshot (the script center-samples that reference):

```sh
node wire/compare-capture.cjs nelgop-wire.wasm frame.serial hmp-before.ppm
```

Pass bytes captured directly from the virtual serial port, not visual lines
copied from a terminal. This repository does not distribute captures.

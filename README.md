# nelgop

Capture a bounded UEFI Graphics Output Protocol (GOP) frame and decode it
outside the guest. The producer and decoder are both written in Nelua and
avoid heap allocation. The v1 ASCII wire can travel through serial or
any other byte sink. It is a snapshot protocol, not a GPU emulator, graphics
driver, compositor, or interactive boot demo.

- [UEFI producer](uefi/): independent protocol lookup and RGB sampling;
  a caller supplies the UEFI context; GOP rows are delivered to callbacks,
  and an optional sender uses standard UEFI Serial I/O.
- [Host decoder](wire/): native Nelua, C ABI, and zero-import wasm32 support.
  It validates the full frame before changing the output.
- [Wire format and build commands](wire/README.md): lowercase hexadecimal
  RGB888 with exact CRLF framing and fixed bounds.

No Neboot application, firmware blob, disk image, compiled Wasm, toolchain,
or third-party binary is distributed here. The library does not implement
or configure the serial transport. Reusable unit and ABI verification
does not by itself prove a particular firmware/browser path exercised it.

## Verify

Use Nelua built from source at
`d5be57955fe8551934db403e5faed3852536ab7a`; Zig 0.15.2 is needed only
for the optional Wasm checks.

```sh
NELUA=/absolute/path/to/nelua ZIG=/absolute/path/to/zig CC=gcc SANITIZE=1 ./wire/check.sh
NELUA=/absolute/path/to/nelua ./uefi/check.sh
```

Set `ZIG` only when Node and Zig are available. Do not treat the hosted or
no-CRT test as proof that firmware on a physical board works.

## Verification scope

A private native x86-64 QEMU/OVMF witness emitted a real 160×100 GOP
capture with 31 colors. The Wasm decoder's RGB output matched the
center-sampled, independently captured 1280×800 HMP screenshot in all
48,000 channel bytes. The capture is not included. This verifies the
firmware producer and real wire decoding, not end-to-end browser boot.

# UEFI GOP producer

The modules define the small subset of x86-64 and AArch64 UEFI Graphics Output
Protocol (GOP) and Serial I/O Protocol used by this library. They do not
depend on Neboot or a complete UEFI system table binding. UEFI method types
use the Microsoft x64 calling convention on x86-64 and the platform
calling convention on AArch64. Use them before `ExitBootServices`.
The caller supplies the live `LocateProtocol` method,
typed or explicitly aliased to `gop.Locate`. Prefer sharing `gop.Guid` in
the caller's declarations instead of casting an incompatible callback.

```nelua
require 'gop'
require 'gop_serial'
-- Inside a verified x86-64 or AArch64 UEFI application.
-- local ok = gop_serial.capture(boot_services.locate)
```

- `gop.open(locate)` locates GOP, returning a borrowed pointer or null.
- `gop.sample(protocol, rows, consumer, context)` takes up to 100
  centered vertical samples using standard GOP BLT. It passes one
  borrowed row at a time, with up to 4096 native-width pixels. The row is
  valid only during its callback.
- `gop_serial.capture(locate)` center-samples 160×100 RGB pixels and
  emits the exact v1 stream over UEFI Serial I/O. Display modes under
  160×100 or over 4096 native pixels wide are rejected. Locate, BLT,
  partial-write and zero-progress handling are exercised in the fixture.
  A failure may have already sent an incomplete frame and returns false;
  the receiver must drop incomplete frames.

The producer has no heap allocation; budget at least the 16 KiB GOP row
plus the 962-byte serial line and normal firmware call stack. A valid
firmware context, a usable display mode, and Serial I/O are prerequisites.
Do not persist the borrowed row or protocol pointer after its valid
lifetime. No runtime mode switch, firmware update, or network is used.

```sh
NELUA=/absolute/path/to/nelua ./uefi/check.sh
```

On x86-64 and AArch64, the hosted test exercises mock firmware method calls,
structural offsets, retry and error handling, and full-frame interoperability
with the Nelua wire decoder.

## AArch64 firmware smoke test

In the x86-64 Fedora Incus guest, install `clang`, `edk2-aarch64`, `mtools`,
`python3`, `qemu-system-aarch64-core`, `qemu-device-display-virtio-gpu-pci`
and `util-linux`. Use a Nelua compiler for the build host and Nelinker
with AArch64 EFI support, such as the build from revision `46c05bb`.

```sh
NELUA=/absolute/path/to/nelua NELINKER=/absolute/path/to/nelinker \
  CAPTURE="$PWD/gop-frame.txt" ./uefi/check-aarch64.sh
```

The test builds a freestanding `BOOTAA64.EFI`, boots it with AArch64 EDK2
under QEMU TCG, paints the VirtIO GOP display red and green, and checks
all 96,240 serial bytes of the resulting 160×100 frame. Set `CAPTURE`
to keep the verified wire frame. Set `EDK2_CODE` and `EDK2_VARS` if your
matching firmware pair lives outside Fedora's default directory.
